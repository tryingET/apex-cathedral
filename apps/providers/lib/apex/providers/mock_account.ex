defmodule Apex.Providers.MockAccount do
  alias Apex.Resources.AccountSession
  alias Apex.Resources.Supervisor, as: ResourceSupervisor

  def capability_names do
    ["mock.account.get_profile", "mock.account.update_profile"]
  end

  def get_profile(workspace_id, args, ctx \\ %{}) do
    with {:ok, pid} <- ResourceSupervisor.ensure_resource(AccountSession, workspace_id) do
      AccountSession.get_profile(pid, args, ctx)
    end
  end

  def update_profile(workspace_id, args, ctx \\ %{}) do
    with {:ok, pid} <- ResourceSupervisor.ensure_resource(AccountSession, workspace_id) do
      AccountSession.update_profile(pid, args, ctx)
    end
  end
end
