defmodule Apex.Runtime.Application do
  use Application

  def start(_type, _args) do
    children = [
      Apex.Runtime.CapabilityRegistry,
      Apex.Runtime.ExecutionStore,
      {Task.Supervisor, name: Apex.Runtime.ExecutionTaskSupervisor},
      Apex.Runtime.ApprovalManager,
      Apex.Runtime.ExecutionManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Apex.Runtime.Supervisor)
  end
end
