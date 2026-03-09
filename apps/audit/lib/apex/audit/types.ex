defmodule Apex.Audit.Types do
  defmodule Event do
    @enforce_keys [:id, :type, :entity_type, :payload, :inserted_at]
    defstruct [
      :id,
      :type,
      :entity_type,
      :entity_id,
      :workspace_id,
      :actor,
      :payload,
      :inserted_at
    ]
  end
end
