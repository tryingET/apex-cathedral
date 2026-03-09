defmodule Apex.Audit.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Apex.Audit.Registry},
      Apex.Audit.Store
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Audit.Supervisor)
  end
end
