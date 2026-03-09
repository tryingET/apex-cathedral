defmodule Apex.Resources.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Apex.Resources.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Apex.Resources.DynamicSupervisor},
      %{
        id: Apex.Resources.Catalog,
        start: {Agent, :start_link, [fn -> %{} end, [name: Apex.Resources.Catalog]]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Resources.RootSupervisor)
  end
end
