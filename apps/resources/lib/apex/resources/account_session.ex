defmodule Apex.Resources.AccountSession do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Resources.Supervisor

  def resource_scope, do: "mock.account"
  def resource_type, do: "AccountSession"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def get_profile(pid, _args \\ %{}, _ctx \\ %{}) do
    GenServer.call(pid, :get_profile)
  end

  def update_profile(pid, args, ctx \\ %{}) do
    patch = fetch(args, :patch) || %{}
    GenServer.call(pid, {:update_profile, patch, ctx})
  end

  def init(opts) do
    workspace_id = Keyword.fetch!(opts, :workspace_id)
    path = Supervisor.account_path(workspace_id)
    File.mkdir_p!(Path.dirname(path))
    profile = load_profile(path, workspace_id)

    resource =
      Supervisor.new_resource(__MODULE__, workspace_id, %{path: path})

    Supervisor.register(resource)

    {:ok,
     %{
       path: path,
       profile: profile,
       workspace_id: workspace_id,
       resource_id: resource.id
     }}
  end

  def handle_call(:get_profile, _from, state) do
    Audit.emit(
      :provider_profile_read,
      %{resource: resource_scope()},
      entity_type: "resource",
      entity_id: state.resource_id,
      workspace_id: state.workspace_id
    )

    {:reply, {:ok, state.profile}, state}
  end

  def handle_call({:update_profile, patch, ctx}, _from, state) do
    next_profile = Map.merge(state.profile, stringify_keys(patch))

    if Map.get(ctx, :dry_run, false) do
      {:reply,
       {:ok,
        %{
          dry_run: true,
          previous: state.profile,
          next: next_profile
        }}, state}
    else
      File.write!(state.path, Jason.encode!(next_profile, pretty: true))

      Audit.emit(
        :provider_profile_updated,
        %{resource: resource_scope(), patch: patch},
        entity_type: "resource",
        entity_id: state.resource_id,
        workspace_id: state.workspace_id
      )

      {:reply, {:ok, next_profile}, %{state | profile: next_profile}}
    end
  end

  def terminate(_reason, state) do
    Supervisor.unregister(state.resource_id)
    :ok
  end

  defp load_profile(path, workspace_id) do
    cond do
      File.exists?(path) ->
        path |> File.read!() |> Jason.decode!()

      true ->
        profile = %{"id" => workspace_id, "name" => "Demo User", "plan" => "free"}
        File.write!(path, Jason.encode!(profile, pretty: true))
        profile
    end
  end

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
