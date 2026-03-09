defmodule Apex.Resources.Types do
  defmodule Resource do
    @enforce_keys [:id, :type, :scope, :workspace_id, :owner_pid, :status, :inserted_at, :updated_at]
    defstruct [
      :id,
      :type,
      :scope,
      :workspace_id,
      :owner_pid,
      :status,
      :metadata,
      :inserted_at,
      :updated_at
    ]
  end
end
