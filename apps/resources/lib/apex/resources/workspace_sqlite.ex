defmodule Apex.Resources.WorkspaceSQLite do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Resources.Supervisor
  alias Exqlite.Sqlite3

  def resource_scope, do: "workspace.sqlite"
  def resource_type, do: "WorkspaceSQLite"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def query(pid, args, ctx \\ %{}) do
    sql = fetch(args, :sql)
    params = fetch(args, :params) || []
    GenServer.call(pid, {:query, sql, params, ctx}, :infinity)
  end

  def execute(pid, args, ctx \\ %{}) do
    sql = fetch(args, :sql)
    params = fetch(args, :params) || []
    GenServer.call(pid, {:execute, sql, params, ctx}, :infinity)
  end

  def init(opts) do
    workspace_id = Keyword.fetch!(opts, :workspace_id)
    path = Supervisor.sqlite_path(workspace_id)
    File.mkdir_p!(Path.dirname(path))

    {:ok, conn} = Sqlite3.open(path)
    :ok = Sqlite3.execute(conn, "PRAGMA journal_mode=WAL;")
    :ok = Sqlite3.execute(conn, "PRAGMA synchronous=NORMAL;")

    resource =
      Supervisor.new_resource(__MODULE__, workspace_id, %{
        path: path
      })

    Supervisor.register(resource)

    {:ok,
     %{
       conn: conn,
       path: path,
       workspace_id: workspace_id,
       resource_id: resource.id
     }}
  end

  def handle_call({:query, sql, params, _ctx}, _from, state) do
    reply =
      with {:ok, result} <- run_query(state.conn, sql, params) do
        Audit.emit(
          :resource_query,
          %{resource: resource_scope(), sql: sql, row_count: result.row_count},
          entity_type: "resource",
          entity_id: state.resource_id,
          workspace_id: state.workspace_id
        )

        {:ok, result}
      end

    {:reply, reply, state}
  end

  def handle_call({:execute, sql, params, ctx}, _from, state) do
    if Map.get(ctx, :dry_run, false) do
      {:reply, {:ok, %{dry_run: true, sql: sql, params: params}}, state}
    else
      reply =
        with {:ok, _result} <- run_query(state.conn, sql, params),
             {:ok, changes} <- Sqlite3.changes(state.conn),
             {:ok, rowid} <- Sqlite3.last_insert_rowid(state.conn) do
          Audit.emit(
            :resource_execute,
            %{resource: resource_scope(), sql: sql, changes: changes},
            entity_type: "resource",
            entity_id: state.resource_id,
            workspace_id: state.workspace_id
          )

          {:ok, %{changes: changes, last_insert_rowid: rowid}}
        end

      {:reply, reply, state}
    end
  end

  def terminate(_reason, state) do
    Supervisor.unregister(state.resource_id)
    Sqlite3.close(state.conn)
  end

  defp run_query(conn, sql, params) do
    case Sqlite3.prepare(conn, sql) do
      {:ok, statement} ->
        try do
          with :ok <- Sqlite3.bind(statement, params),
               {:ok, columns} <- Sqlite3.columns(conn, statement),
               {:ok, rows} <- Sqlite3.fetch_all(conn, statement) do
            mapped =
              Enum.map(rows, fn row ->
                Enum.zip(columns, row)
                |> Enum.into(%{})
              end)

            {:ok, %{columns: columns, rows: mapped, row_count: length(mapped)}}
          end
        after
          Sqlite3.release(conn, statement)
        end

      {:error, reason} ->
        {:error, %{message: inspect(reason)}}
    end
  end

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
