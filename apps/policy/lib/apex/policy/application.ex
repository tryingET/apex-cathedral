defmodule Apex.Policy.Application do
  use Application

  def start(_type, _args) do
    children = [
      Apex.Policy.Engine
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Policy.Supervisor)
  end
end
