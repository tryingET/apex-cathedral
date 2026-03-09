defmodule Apex.Gateway.Application do
  use Application

  def start(_type, _args) do
    port = Application.fetch_env!(:apex, :gateway_port)

    children = [
      {Bandit, plug: Apex.Gateway.Router, scheme: :http, port: port}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Gateway.Supervisor)
  end
end
