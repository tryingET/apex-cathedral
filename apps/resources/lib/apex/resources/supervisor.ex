defmodule Apex.Resources.Supervisor do
  alias Apex.Resources.Types.Resource

  def ensure_resource(module, workspace_id) do
    key = {module.resource_scope(), workspace_id}

    case Registry.lookup(Apex.Resources.Registry, key) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        name = {:via, Registry, {Apex.Resources.Registry, key}}

        spec = {module, [workspace_id: workspace_id, name: name]}

        case DynamicSupervisor.start_child(Apex.Resources.DynamicSupervisor, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  def register(%Resource{} = resource) do
    Agent.update(Apex.Resources.Catalog, &Map.put(&1, resource.id, resource))
  end

  def unregister(resource_id) do
    Agent.update(Apex.Resources.Catalog, &Map.delete(&1, resource_id))
  end

  def update(resource_id, fun) do
    Agent.get_and_update(Apex.Resources.Catalog, fn state ->
      case Map.fetch(state, resource_id) do
        {:ok, resource} ->
          updated = fun.(resource)
          {updated, Map.put(state, resource_id, updated)}

        :error ->
          {nil, state}
      end
    end)
  end

  def list_resources do
    Apex.Resources.Catalog
    |> Agent.get(&Map.values/1)
    |> Enum.sort_by(& &1.inserted_at, :desc)
  end

  def reset do
    DynamicSupervisor.which_children(Apex.Resources.DynamicSupervisor)
    |> Enum.each(fn
      {_id, pid, _type, _modules} when is_pid(pid) ->
        DynamicSupervisor.terminate_child(Apex.Resources.DynamicSupervisor, pid)

      _ ->
        :ok
    end)

    Agent.update(Apex.Resources.Catalog, fn _ -> %{} end)
    :ok
  end

  def workspace_root(workspace_id) do
    validate_workspace_id!(workspace_id)

    Path.join([Application.fetch_env!(:apex, :storage_root), "workspaces", workspace_id])
    |> Path.expand()
  end

  def fs_root(workspace_id) do
    workspace_id
    |> workspace_root()
    |> Path.join("fs")
  end

  def sqlite_path(workspace_id) do
    workspace_id
    |> workspace_root()
    |> Path.join("workspace.sqlite")
  end

  def account_path(workspace_id) do
    workspace_id
    |> workspace_root()
    |> Path.join("mock_account.json")
  end

  def timestamp do
    DateTime.utc_now() |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()
  end

  def new_resource(module, workspace_id, metadata \\ %{}) do
    %Resource{
      id: "#{module.resource_scope()}:#{workspace_id}",
      type: module.resource_type(),
      scope: module.resource_scope(),
      workspace_id: workspace_id,
      owner_pid: self(),
      status: :ready,
      metadata: metadata,
      inserted_at: timestamp(),
      updated_at: timestamp()
    }
  end

  def normalize_path!(root, relative_path) do
    expanded = Path.expand(relative_path, root)

    cond do
      expanded == root ->
        expanded

      String.starts_with?(expanded, root <> "/") ->
        expanded

      true ->
        raise ArgumentError, "path escapes workspace root"
    end
  end

  def validate_workspace_id!(workspace_id) do
    unless Regex.match?(~r/^[A-Za-z0-9._-]+$/, workspace_id) do
      raise ArgumentError, "invalid workspace id"
    end

    workspace_id
  end
end
