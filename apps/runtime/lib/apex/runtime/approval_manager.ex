defmodule Apex.Runtime.ApprovalManager do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Runtime.Id
  alias Apex.Runtime.Types.{ApprovalRequest, ExecutionRun}

  @table :apex_approval_requests

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def request(%ExecutionRun{} = run) do
    GenServer.call(__MODULE__, {:request, run})
  end

  def approve(approval_id, approved_by \\ "operator") do
    GenServer.call(__MODULE__, {:approve, approval_id, approved_by})
  end

  def deny(approval_id, denied_by \\ "operator", reason \\ nil) do
    GenServer.call(__MODULE__, {:deny, approval_id, denied_by, reason})
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, approval}] -> approval
      [] -> nil
    end
  end

  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, approval} -> approval end)
    |> Enum.sort_by(& &1.updated_at, :desc)
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{timers: %{}}}
  end

  def handle_call({:request, %ExecutionRun{} = run}, _from, state) do
    timeout_ms = Application.fetch_env!(:apex, :approval_timeout_ms)
    now = Apex.Runtime.Types.timestamp()
    approval_id = Id.generate()

    approval =
      %ApprovalRequest{
        approval_id: approval_id,
        execution_id: run.id,
        capability: run.capability,
        arguments: run.arguments,
        requested_by: run.requested_by,
        status: :pending,
        timestamp: now,
        updated_at: now,
        approved_by: nil,
        denied_by: nil,
        expires_at: expires_at(timeout_ms),
        reason: nil
      }

    :ets.insert(@table, {approval.approval_id, approval})
    timer_ref = Process.send_after(self(), {:approval_timeout, approval.approval_id}, timeout_ms)

    Audit.emit(
      :approval_requested,
      %{capability: run.capability, execution_id: run.id},
      entity_type: "approval",
      entity_id: approval.approval_id,
      workspace_id: run.workspace_id,
      actor: run.requested_by
    )

    {:reply, {:ok, approval}, put_in(state.timers[approval.approval_id], timer_ref)}
  end

  def handle_call({:approve, approval_id, approved_by}, _from, state) do
    with %ApprovalRequest{status: :pending} = approval <- get(approval_id) do
      cancel_timer(state.timers[approval_id])

      updated = %ApprovalRequest{
        approval
        | status: :approved,
          approved_by: approved_by,
          updated_at: Apex.Runtime.Types.timestamp()
      }

      :ets.insert(@table, {approval_id, updated})
      send(Apex.Runtime.ExecutionManager, {:approval_decision, approval.execution_id, :approved, updated})

      Audit.emit(
        :approval_approved,
        %{execution_id: approval.execution_id},
        entity_type: "approval",
        entity_id: approval_id,
        actor: approved_by
      )

      {:reply, {:ok, updated}, %{state | timers: Map.delete(state.timers, approval_id)}}
    else
      nil -> {:reply, {:error, :not_found}, state}
      %ApprovalRequest{} = approval -> {:reply, {:error, {:invalid_status, approval.status}}, state}
    end
  end

  def handle_call({:deny, approval_id, denied_by, reason}, _from, state) do
    with %ApprovalRequest{status: :pending} = approval <- get(approval_id) do
      cancel_timer(state.timers[approval_id])

      updated = %ApprovalRequest{
        approval
        | status: :denied,
          denied_by: denied_by,
          reason: reason,
          updated_at: Apex.Runtime.Types.timestamp()
      }

      :ets.insert(@table, {approval_id, updated})
      send(Apex.Runtime.ExecutionManager, {:approval_decision, approval.execution_id, :denied, updated})

      Audit.emit(
        :approval_denied,
        %{execution_id: approval.execution_id, reason: reason},
        entity_type: "approval",
        entity_id: approval_id,
        actor: denied_by
      )

      {:reply, {:ok, updated}, %{state | timers: Map.delete(state.timers, approval_id)}}
    else
      nil -> {:reply, {:error, :not_found}, state}
      %ApprovalRequest{} = approval -> {:reply, {:error, {:invalid_status, approval.status}}, state}
    end
  end

  def handle_call(:clear, _from, state) do
    Enum.each(state.timers, fn {_id, timer_ref} -> cancel_timer(timer_ref) end)
    :ets.delete_all_objects(@table)
    {:reply, :ok, %{state | timers: %{}}}
  end

  def handle_info({:approval_timeout, approval_id}, state) do
    case get(approval_id) do
      %ApprovalRequest{status: :pending} = approval ->
        updated = %ApprovalRequest{
          approval
          | status: :timed_out,
            updated_at: Apex.Runtime.Types.timestamp()
        }

        :ets.insert(@table, {approval_id, updated})
        send(Apex.Runtime.ExecutionManager, {:approval_decision, approval.execution_id, :timed_out, updated})

        Audit.emit(
          :approval_timed_out,
          %{execution_id: approval.execution_id},
          entity_type: "approval",
          entity_id: approval_id
        )

        {:noreply, %{state | timers: Map.delete(state.timers, approval_id)}}

      _ ->
        {:noreply, %{state | timers: Map.delete(state.timers, approval_id)}}
    end
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(ref) do
    Process.cancel_timer(ref)
    :ok
  end

  defp expires_at(timeout_ms) do
    DateTime.utc_now()
    |> DateTime.add(timeout_ms, :millisecond)
    |> DateTime.truncate(:millisecond)
    |> DateTime.to_iso8601()
  end
end
