defmodule Apex.Runtime do
  alias Apex.Audit.Store, as: AuditStore
  alias Apex.Resources.Supervisor, as: ResourceSupervisor
  alias Apex.Runtime.{ApprovalManager, CapabilityRegistry, ExecutionManager, ExecutionStore}
  alias Apex.Runtime.Types.Workspace

  def list_capabilities do
    CapabilityRegistry.list()
  end

  def get_capability(name) do
    CapabilityRegistry.get(name)
  end

  def request_execution(attrs) do
    ExecutionManager.request_execution(attrs)
  end

  def list_executions do
    ExecutionStore.list()
  end

  def get_execution(id) do
    ExecutionStore.get(id)
  end

  def list_approvals do
    ApprovalManager.list()
  end

  def get_approval(id) do
    ApprovalManager.get(id)
  end

  def approve(id, approved_by \\ "operator") do
    ApprovalManager.approve(id, approved_by)
  end

  def deny(id, denied_by \\ "operator", reason \\ nil) do
    ApprovalManager.deny(id, denied_by, reason)
  end

  def list_resources do
    ResourceSupervisor.list_resources()
  end

  def list_events(filters \\ %{}) do
    AuditStore.query(filters)
  end

  def subscribe_events do
    AuditStore.subscribe()
  end

  def workspace(workspace_id) do
    %Workspace{
      id: workspace_id,
      root_path: ResourceSupervisor.workspace_root(workspace_id),
      created_at: Apex.Runtime.Types.timestamp()
    }
  end

  def reset_state do
    ExecutionStore.clear()
    ApprovalManager.clear()
    ResourceSupervisor.reset()
  end
end
