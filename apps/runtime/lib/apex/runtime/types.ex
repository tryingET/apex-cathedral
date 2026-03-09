defmodule Apex.Runtime.Types do
  def timestamp do
    DateTime.utc_now() |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()
  end

  def normalize_mode(nil), do: :execute
  def normalize_mode(:execute), do: :execute
  def normalize_mode(:dry_run), do: :dry_run
  def normalize_mode("EXECUTE"), do: :execute
  def normalize_mode("execute"), do: :execute
  def normalize_mode("DRY_RUN"), do: :dry_run
  def normalize_mode("dry_run"), do: :dry_run
  def normalize_mode(other), do: raise(ArgumentError, "invalid mode: #{inspect(other)}")

  defmodule Workspace do
    @enforce_keys [:id, :root_path, :created_at]
    defstruct [:id, :root_path, :created_at]
  end

  defmodule Capability do
    @enforce_keys [
      :name,
      :description,
      :input_schema,
      :output_schema,
      :effect_type,
      :destructive_flag,
      :resource_scope,
      :approval_requirement,
      :handler
    ]
    defstruct [
      :name,
      :description,
      :input_schema,
      :output_schema,
      :effect_type,
      :destructive_flag,
      :resource_scope,
      :approval_requirement,
      :provider,
      :handler
    ]
  end

  defmodule ExecutionRequest do
    alias Apex.Runtime.Id
    alias Apex.Runtime.Types

    @enforce_keys [:id, :workspace_id, :capability, :arguments, :requested_by, :mode, :inserted_at]
    defstruct [:id, :workspace_id, :capability, :arguments, :requested_by, :mode, :inserted_at]

    def new(attrs) do
      %__MODULE__{
        id: Id.generate(),
        workspace_id: fetch(attrs, :workspace_id),
        capability: fetch(attrs, :capability),
        arguments: fetch(attrs, :arguments) || %{},
        requested_by: fetch(attrs, :requested_by),
        mode: Types.normalize_mode(fetch(attrs, :mode)),
        inserted_at: Types.timestamp()
      }
    end

    defp fetch(map, key) do
      Map.get(map, key) || Map.get(map, Atom.to_string(key))
    end
  end

  defmodule ExecutionResult do
    @enforce_keys [:status, :output, :duration_ms, :dry_run, :completed_at]
    defstruct [:status, :output, :duration_ms, :dry_run, :completed_at]
  end

  defmodule ApprovalRequest do
    @enforce_keys [
      :approval_id,
      :execution_id,
      :capability,
      :arguments,
      :requested_by,
      :status,
      :timestamp,
      :updated_at,
      :expires_at
    ]
    defstruct [
      :approval_id,
      :execution_id,
      :capability,
      :arguments,
      :requested_by,
      :status,
      :timestamp,
      :updated_at,
      :approved_by,
      :denied_by,
      :expires_at,
      :reason
    ]
  end

  defmodule ExecutionRun do
    alias Apex.Runtime.Id
    alias Apex.Runtime.Types

    @states [
      :requested,
      :policy_evaluated,
      :pending_approval,
      :approved,
      :running,
      :completed,
      :failed,
      :denied,
      :timed_out
    ]

    @allowed %{
      requested: [:policy_evaluated],
      policy_evaluated: [:pending_approval, :approved, :denied],
      pending_approval: [:approved, :denied, :timed_out],
      approved: [:running],
      running: [:completed, :failed, :timed_out],
      completed: [],
      failed: [],
      denied: [],
      timed_out: []
    }

    @enforce_keys [
      :id,
      :request_id,
      :workspace_id,
      :capability,
      :arguments,
      :requested_by,
      :mode,
      :state,
      :resource_scope,
      :updated_at,
      :transitions
    ]
    defstruct [
      :id,
      :request_id,
      :workspace_id,
      :capability,
      :arguments,
      :requested_by,
      :mode,
      :state,
      :policy_decision,
      :approval_id,
      :resource_scope,
      :started_at,
      :completed_at,
      :updated_at,
      :result,
      :error,
      :transitions
    ]

    def states, do: @states

    def terminal?(%__MODULE__{state: state}), do: terminal?(state)
    def terminal?(state), do: state in [:completed, :failed, :denied, :timed_out]

    def new(request, capability) do
      now = Types.timestamp()

      %__MODULE__{
        id: Id.generate(),
        request_id: request.id,
        workspace_id: request.workspace_id,
        capability: request.capability,
        arguments: request.arguments,
        requested_by: request.requested_by,
        mode: request.mode,
        state: :requested,
        policy_decision: nil,
        approval_id: nil,
        resource_scope: capability.resource_scope,
        started_at: nil,
        completed_at: nil,
        updated_at: now,
        result: nil,
        error: nil,
        transitions: [%{from: nil, to: :requested, at: now}]
      }
    end

    def transition(%__MODULE__{} = run, next_state, attrs \\ %{}) do
      if next_state in Map.fetch!(@allowed, run.state) do
        now = Types.timestamp()

        updated =
          run
          |> struct(attrs)
          |> Map.put(:state, next_state)
          |> Map.put(:updated_at, now)
          |> Map.update!(:transitions, &(&1 ++ [%{from: run.state, to: next_state, at: now}]))

        updated =
          if next_state == :running and is_nil(updated.started_at) do
            %{updated | started_at: now}
          else
            updated
          end

        updated =
          if next_state in [:completed, :failed, :denied, :timed_out] and is_nil(updated.completed_at) do
            %{updated | completed_at: now}
          else
            updated
          end

        {:ok, updated}
      else
        {:error, {:invalid_transition, run.state, next_state}}
      end
    end
  end
end
