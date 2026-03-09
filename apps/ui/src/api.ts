export const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "http://localhost:4100";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(API_BASE_URL + path, init);
  const payload = (await response.json()) as { data?: T; error?: unknown };

  if (!response.ok) {
    throw new Error(JSON.stringify(payload.error ?? { status: response.status }));
  }

  return payload.data as T;
}

export interface Capability {
  name: string;
  description: string;
  effect_type: string;
  resource_scope: string;
  approval_requirement: string;
}

export interface Execution {
  id: string;
  capability: string;
  state: string;
  approval_id?: string | null;
  requested_by: string;
  workspace_id: string;
  result?: unknown;
  error?: unknown;
}

export interface Approval {
  approval_id: string;
  execution_id: string;
  capability: string;
  status: string;
}

export interface AuditEvent {
  id: string;
  type: string;
  payload: Record<string, unknown>;
  inserted_at: string;
}

export async function listCapabilities(): Promise<Capability[]> {
  return request<Capability[]>("/capabilities");
}

export async function listExecutions(): Promise<Execution[]> {
  return request<Execution[]>("/executions");
}

export async function runExecution(body: Record<string, unknown>): Promise<Execution> {
  return request<Execution>("/executions", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
}

export async function listApprovals(): Promise<Approval[]> {
  return request<Approval[]>("/approvals");
}

export async function approve(approvalId: string): Promise<Approval> {
  return request<Approval>(`/approvals/${approvalId}/approve`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ approved_by: "ui:operator" })
  });
}

export function subscribeEvents(onEvent: (event: AuditEvent) => void): () => void {
  const source = new EventSource(API_BASE_URL + "/events/stream");
  source.addEventListener("audit", (message) => {
    onEvent(JSON.parse((message as MessageEvent<string>).data) as AuditEvent);
  });
  return () => source.close();
}
