defmodule Apex.Providers.Application do
  use Application

  def start(_type, _args) do
    children = [
      Apex.Providers.Registry
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Providers.Supervisor)
  end
end
