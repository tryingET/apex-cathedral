defmodule Apex.Audit.Logger do
  alias Apex.Audit.Store
  alias Apex.Audit.Types.Event

  def emit(type, payload, opts \\ []) do
    event = %Event{
      id: new_id(),
      type: normalize_atom(type),
      entity_type: Keyword.get(opts, :entity_type, "system"),
      entity_id: Keyword.get(opts, :entity_id),
      workspace_id: Keyword.get(opts, :workspace_id),
      actor: Keyword.get(opts, :actor),
      payload: payload || %{},
      inserted_at: timestamp()
    }

    Store.append(event)
  end

  defp new_id do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower, padding: false)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()
  end

  defp normalize_atom(value) when is_atom(value), do: value
  defp normalize_atom(value) when is_binary(value), do: String.to_atom(value)
end
