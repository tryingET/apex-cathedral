defmodule Apex.Resources.WorkspaceFS do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Resources.Supervisor

  def resource_scope, do: "workspace.fs"
  def resource_type, do: "WorkspaceFS"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def read_file(pid, args, _ctx \\ %{}) do
    path = fetch(args, :path)
    GenServer.call(pid, {:read_file, path})
  end

  def write_file(pid, args, ctx \\ %{}) do
    path = fetch(args, :path)
    content = fetch(args, :content)
    GenServer.call(pid, {:write_file, path, content, ctx})
  end

  def init(opts) do
    workspace_id = Keyword.fetch!(opts, :workspace_id)
    root = Supervisor.fs_root(workspace_id)
    File.mkdir_p!(root)

    resource =
      Supervisor.new_resource(__MODULE__, workspace_id, %{
        root: root
      })

    Supervisor.register(resource)

    {:ok,
     %{
       workspace_id: workspace_id,
       root: root,
       resource_id: resource.id
     }}
  end

  def handle_call({:read_file, path}, _from, state) do
    absolute = Supervisor.normalize_path!(state.root, path)

    reply =
      case File.read(absolute) do
        {:ok, content} ->
          Audit.emit(
            :resource_read,
            %{resource: resource_scope(), path: path, bytes: byte_size(content)},
            entity_type: "resource",
            entity_id: state.resource_id,
            workspace_id: state.workspace_id
          )

          {:ok, %{path: path, content: content, bytes: byte_size(content)}}

        {:error, reason} ->
          {:error, %{message: :file.format_error(reason)}}
      end

    {:reply, reply, state}
  end

  def handle_call({:write_file, path, content, ctx}, _from, state) do
    if Map.get(ctx, :dry_run, false) do
      {:reply, {:ok, %{dry_run: true, path: path, bytes: byte_size(content)}}, state}
    else
      absolute = Supervisor.normalize_path!(state.root, path)
      File.mkdir_p!(Path.dirname(absolute))
      tmp = absolute <> ".tmp-" <> unique_suffix()

      reply =
        with :ok <- File.write(tmp, content),
             :ok <- File.rename(tmp, absolute) do
          Audit.emit(
            :resource_write,
            %{resource: resource_scope(), path: path, bytes: byte_size(content)},
            entity_type: "resource",
            entity_id: state.resource_id,
            workspace_id: state.workspace_id
          )

          {:ok, %{path: path, bytes: byte_size(content)}}
        else
          {:error, reason} ->
            File.rm(tmp)
            {:error, %{message: :file.format_error(reason)}}
        end

      {:reply, reply, state}
    end
  end

  def terminate(_reason, state) do
    Supervisor.unregister(state.resource_id)
    :ok
  end

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp unique_suffix do
    System.unique_integer([:positive, :monotonic]) |> Integer.to_string()
  end
end
