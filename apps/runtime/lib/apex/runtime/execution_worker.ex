defmodule Apex.Runtime.ExecutionWorker do
  alias Apex.Resources.Supervisor, as: ResourceSupervisor
  alias Apex.Runtime.Types

  def run(execution, capability, manager) do
    started = System.monotonic_time(:millisecond)

    ctx = %{
      dry_run: execution.mode == :dry_run,
      execution_id: execution.id,
      workspace: %Types.Workspace{
        id: execution.workspace_id,
        root_path: ResourceSupervisor.workspace_root(execution.workspace_id),
        created_at: Types.timestamp()
      }
    }

    try do
      result =
        case capability.handler do
          {:resource, module, operation} ->
            with {:ok, pid} <- ResourceSupervisor.ensure_resource(module, execution.workspace_id) do
              apply(module, operation, [pid, execution.arguments, ctx])
            end

          {:provider, module, operation} ->
            apply(module, operation, [execution.workspace_id, execution.arguments, ctx])
        end

      duration_ms = System.monotonic_time(:millisecond) - started

      case result do
        {:ok, output} ->
          send(manager, {:execution_completed, execution.id, output, duration_ms, ctx.dry_run})

        {:error, error} ->
          send(manager, {:execution_failed, execution.id, normalize_error(error), duration_ms})
      end
    rescue
      error ->
        duration_ms = System.monotonic_time(:millisecond) - started
        send(manager, {:execution_failed, execution.id, normalize_exception(error), duration_ms})
    catch
      kind, reason ->
        duration_ms = System.monotonic_time(:millisecond) - started

        send(
          manager,
          {:execution_failed,
           execution.id,
           %{
             kind: to_string(kind),
             reason: inspect(reason)
           }, duration_ms}
        )
    end
  end

  defp normalize_error(error) when is_map(error), do: error
  defp normalize_error(error), do: %{message: inspect(error)}

  defp normalize_exception(exception) do
    %{message: Exception.message(exception), type: inspect(exception.__struct__)}
  end
end
