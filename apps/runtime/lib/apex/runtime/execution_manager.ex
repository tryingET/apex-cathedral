defmodule Apex.Runtime.ExecutionManager do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Policy.Engine
  alias Apex.Runtime.ApprovalManager
  alias Apex.Runtime.CapabilityRegistry
  alias Apex.Runtime.ExecutionStore
  alias Apex.Runtime.ExecutionWorker
  alias Apex.Runtime.Types
  alias Apex.Runtime.Types.{ExecutionRequest, ExecutionResult, ExecutionRun}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def request_execution(attrs) when is_map(attrs) do
    GenServer.call(__MODULE__, {:request_execution, attrs}, :infinity)
  end

  def init(_opts) do
    {:ok, %{running: %{}}}
  end

  def handle_call({:request_execution, attrs}, _from, state) do
    with {:ok, capability} <- fetch_capability(attrs),
         {:ok, request} <- build_request(attrs),
         :ok <- validate_workspace(request.workspace_id) do
      run = ExecutionRun.new(request, capability)
      ExecutionStore.put(run)

      Audit.emit(
        :execution_requested,
        %{capability: run.capability, arguments: run.arguments, mode: run.mode},
        entity_type: "execution",
        entity_id: run.id,
        workspace_id: run.workspace_id,
        actor: run.requested_by
      )

      decision = Engine.evaluate(capability, request)
      {:ok, run} = ExecutionRun.transition(run, :policy_evaluated, %{policy_decision: decision})
      ExecutionStore.put(run)

      Audit.emit(
        :policy_evaluated,
        %{capability: run.capability, decision: decision.decision, matched_rule: decision.matched_rule},
        entity_type: "execution",
        entity_id: run.id,
        workspace_id: run.workspace_id,
        actor: run.requested_by
      )

      {reply_run, next_state} =
        case decision.decision do
          :allow ->
            approve_and_start(run, capability, state)

          :approval_required ->
            {:ok, approval} = ApprovalManager.request(run)
            {:ok, pending} = ExecutionRun.transition(run, :pending_approval, %{approval_id: approval.approval_id})
            ExecutionStore.put(pending)
            {pending, state}

          :dry_run_only ->
            if request.mode == :dry_run do
              approve_and_start(run, capability, state)
            else
              {:ok, denied} =
                ExecutionRun.transition(run, :denied, %{
                  error: %{message: "policy requires DRY_RUN mode for this capability"}
                })

              ExecutionStore.put(denied)

              Audit.emit(
                :execution_denied,
                %{reason: "dry_run_only"},
                entity_type: "execution",
                entity_id: denied.id,
                workspace_id: denied.workspace_id,
                actor: denied.requested_by
              )

              {denied, state}
            end

          :deny ->
            {:ok, denied} =
              ExecutionRun.transition(run, :denied, %{
                error: %{message: decision.rationale, matched_rule: decision.matched_rule}
              })

            ExecutionStore.put(denied)

            Audit.emit(
              :execution_denied,
              %{reason: decision.rationale, matched_rule: decision.matched_rule},
              entity_type: "execution",
              entity_id: denied.id,
              workspace_id: denied.workspace_id,
              actor: denied.requested_by
            )

            {denied, state}
        end

      {:reply, {:ok, reply_run}, next_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info({:approval_decision, execution_id, :approved, _approval}, state) do
    run = ExecutionStore.get(execution_id)

    if run && run.state == :pending_approval do
      capability = CapabilityRegistry.get(run.capability)
      {_updated, next_state} = approve_and_start(run, capability, state)
      {:noreply, next_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:approval_decision, execution_id, :denied, approval}, state) do
    run = ExecutionStore.get(execution_id)

    if run && run.state == :pending_approval do
      {:ok, denied} =
        ExecutionRun.transition(run, :denied, %{
          approval_id: approval.approval_id,
          error: %{message: approval.reason || "approval denied"}
        })

      ExecutionStore.put(denied)

      Audit.emit(
        :execution_denied,
        %{reason: "approval_denied"},
        entity_type: "execution",
        entity_id: denied.id,
        workspace_id: denied.workspace_id
      )
    end

    {:noreply, state}
  end

  def handle_info({:approval_decision, execution_id, :timed_out, approval}, state) do
    run = ExecutionStore.get(execution_id)

    if run && run.state == :pending_approval do
      {:ok, timed_out} =
        ExecutionRun.transition(run, :timed_out, %{
          approval_id: approval.approval_id,
          error: %{message: "approval timed out"}
        })

      ExecutionStore.put(timed_out)

      Audit.emit(
        :execution_timed_out,
        %{reason: "approval_timeout"},
        entity_type: "execution",
        entity_id: timed_out.id,
        workspace_id: timed_out.workspace_id
      )
    end

    {:noreply, state}
  end

  def handle_info({:execution_completed, execution_id, output, duration_ms, dry_run}, state) do
    run = ExecutionStore.get(execution_id)

    if run && run.state == :running do
      result = %ExecutionResult{
        status: :completed,
        output: output,
        duration_ms: duration_ms,
        dry_run: dry_run,
        completed_at: Types.timestamp()
      }

      {:ok, completed} = ExecutionRun.transition(run, :completed, %{result: result})
      ExecutionStore.put(completed)

      Audit.emit(
        :execution_completed,
        %{duration_ms: duration_ms, dry_run: dry_run},
        entity_type: "execution",
        entity_id: completed.id,
        workspace_id: completed.workspace_id
      )

      {:noreply, cleanup_running(execution_id, state)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:execution_failed, execution_id, error, duration_ms}, state) do
    run = ExecutionStore.get(execution_id)

    if run && run.state == :running do
      {:ok, failed} =
        ExecutionRun.transition(run, :failed, %{
          error: Map.put(error, :duration_ms, duration_ms)
        })

      ExecutionStore.put(failed)

      Audit.emit(
        :execution_failed,
        %{error: error, duration_ms: duration_ms},
        entity_type: "execution",
        entity_id: failed.id,
        workspace_id: failed.workspace_id
      )

      {:noreply, cleanup_running(execution_id, state)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:execution_timeout, execution_id}, state) do
    case Map.get(state.running, execution_id) do
      %{pid: pid} ->
        Process.exit(pid, :kill)

        run = ExecutionStore.get(execution_id)

        if run && run.state == :running do
          {:ok, timed_out} =
            ExecutionRun.transition(run, :timed_out, %{
              error: %{message: "execution timed out"}
            })

          ExecutionStore.put(timed_out)

          Audit.emit(
            :execution_timed_out,
            %{reason: "execution_timeout"},
            entity_type: "execution",
            entity_id: timed_out.id,
            workspace_id: timed_out.workspace_id
          )
        end

        {:noreply, cleanup_running(execution_id, state)}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Enum.find(state.running, fn {_execution_id, info} -> info.monitor_ref == ref end) do
      {_execution_id, _info} when reason in [:normal, :shutdown] ->
        {:noreply, state}

      {execution_id, _info} ->
        run = ExecutionStore.get(execution_id)

        if run && run.state == :running do
          {:ok, failed} =
            ExecutionRun.transition(run, :failed, %{
              error: %{message: "worker exited unexpectedly", reason: inspect(reason)}
            })

          ExecutionStore.put(failed)

          Audit.emit(
            :execution_failed,
            %{error: %{reason: inspect(reason)}},
            entity_type: "execution",
            entity_id: failed.id,
            workspace_id: failed.workspace_id
          )
        end

        {:noreply, cleanup_running(execution_id, state)}

      nil ->
        {:noreply, state}
    end
  end

  defp fetch_capability(attrs) do
    capability_name = Map.get(attrs, :capability) || Map.get(attrs, "capability")

    case CapabilityRegistry.get(capability_name) do
      nil -> {:error, %{message: "unknown capability", capability: capability_name}}
      capability -> {:ok, capability}
    end
  end

  defp build_request(attrs) do
    try do
      {:ok, ExecutionRequest.new(Map.put_new(attrs, "arguments", %{}))}
    rescue
      error -> {:error, %{message: Exception.message(error)}}
    end
  end

  defp validate_workspace(workspace_id) do
    try do
      Apex.Resources.Supervisor.validate_workspace_id!(workspace_id)
      :ok
    rescue
      error -> {:error, %{message: Exception.message(error)}}
    end
  end

  defp approve_and_start(run, capability, state) do
    {:ok, approved} = ExecutionRun.transition(run, :approved)
    ExecutionStore.put(approved)
    start_execution(approved, capability, state)
  end

  defp start_execution(run, capability, state) do
    {:ok, running} = ExecutionRun.transition(run, :running)
    ExecutionStore.put(running)

    Audit.emit(
      :execution_started,
      %{capability: running.capability},
      entity_type: "execution",
      entity_id: running.id,
      workspace_id: running.workspace_id,
      actor: running.requested_by
    )

    manager = self()

    {:ok, pid} =
      Task.Supervisor.start_child(Apex.Runtime.ExecutionTaskSupervisor, fn ->
        ExecutionWorker.run(running, capability, manager)
      end)

    monitor_ref = Process.monitor(pid)

    timer_ref =
      Process.send_after(
        self(),
        {:execution_timeout, running.id},
        Application.fetch_env!(:apex, :execution_timeout_ms)
      )

    next_state =
      put_in(state.running[running.id], %{
        pid: pid,
        monitor_ref: monitor_ref,
        timer_ref: timer_ref
      })

    {running, next_state}
  end

  defp cleanup_running(execution_id, state) do
    case Map.get(state.running, execution_id) do
      %{monitor_ref: monitor_ref, timer_ref: timer_ref} ->
        Process.cancel_timer(timer_ref)
        Process.demonitor(monitor_ref, [:flush])
        %{state | running: Map.delete(state.running, execution_id)}

      nil ->
        state
    end
  end
end
