export type EffectType = "READ" | "WRITE" | "DESTRUCTIVE" | "EXTERNAL_SIDE_EFFECT";
export type ExecutionState =
  | "REQUESTED"
  | "POLICY_EVALUATED"
  | "PENDING_APPROVAL"
  | "APPROVED"
  | "RUNNING"
  | "COMPLETED"
  | "FAILED"
  | "DENIED"
  | "TIMED_OUT";

export interface Capability {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
  output_schema: Record<string, unknown>;
  effect_type: EffectType;
  destructive_flag: boolean;
  resource_scope: string;
  approval_requirement: string;
  provider?: string | null;
}

export interface PolicyDecision {
  decision: string;
  matched_rule: string;
  rationale: string;
  effect_type: EffectType;
}

export interface ExecutionResult {
  status: string;
  output: unknown;
  duration_ms: number;
  dry_run: boolean;
  completed_at: string;
}

export interface Execution {
  id: string;
  request_id: string;
  workspace_id: string;
  capability: string;
  arguments: Record<string, unknown>;
  requested_by: string;
  mode: string;
  state: ExecutionState;
  policy_decision?: PolicyDecision | null;
  approval_id?: string | null;
  resource_scope: string;
  started_at?: string | null;
  completed_at?: string | null;
  updated_at: string;
  result?: ExecutionResult | null;
  error?: unknown;
  transitions: Array<Record<string, unknown>>;
}

export interface Approval {
  approval_id: string;
  execution_id: string;
  capability: string;
  arguments: Record<string, unknown>;
  requested_by: string;
  status: string;
  timestamp: string;
  updated_at: string;
  approved_by?: string | null;
  denied_by?: string | null;
  expires_at?: string | null;
}

export interface AuditEvent {
  id: string;
  type: string;
  entity_type: string;
  entity_id?: string | null;
  workspace_id?: string | null;
  actor?: string | null;
  payload: Record<string, unknown>;
  inserted_at: string;
}

export interface Resource {
  id: string;
  type: string;
  scope: string;
  workspace_id: string;
  owner_pid: string;
  status: string;
  metadata?: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export interface CreateExecutionRequest {
  workspace_id: string;
  requested_by: string;
  capability: string;
  mode?: "EXECUTE" | "DRY_RUN";
  arguments?: Record<string, unknown>;
}

export interface ClientOptions {
  baseUrl?: string;
  fetchImpl?: typeof fetch;
}

class HttpClient {
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;

  constructor(options: ClientOptions = {}) {
    this.baseUrl = options.baseUrl ?? "http://localhost:4100";
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async get<T>(path: string): Promise<T> {
    const response = await this.fetchImpl(this.baseUrl + path);
    return this.decode<T>(response);
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    const response = await this.fetchImpl(this.baseUrl + path, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: body ? JSON.stringify(body) : undefined
    });
    return this.decode<T>(response);
  }

  eventSource(path: string): EventSource {
    return new EventSource(this.baseUrl + path);
  }

  private async decode<T>(response: Response): Promise<T> {
    const payload = (await response.json()) as { data?: T; error?: unknown };

    if (!response.ok) {
      throw new Error(JSON.stringify(payload.error ?? { status: response.status }));
    }

    return payload.data as T;
  }
}

export class ApexClient {
  private readonly http: HttpClient;

  constructor(options: ClientOptions = {}) {
    this.http = new HttpClient(options);
  }

  readonly capabilities = {
    list: async (): Promise<Capability[]> => this.http.get<Capability[]>("/capabilities"),
    get: async (name: string): Promise<Capability> =>
      this.http.get<Capability>(`/capabilities/${encodeURIComponent(name)}`)
  };

  readonly executions = {
    run: async (request: CreateExecutionRequest): Promise<Execution> =>
      this.http.post<Execution>("/executions", request),
    list: async (): Promise<Execution[]> => this.http.get<Execution[]>("/executions"),
    get: async (id: string): Promise<Execution> => this.http.get<Execution>(`/executions/${id}`)
  };

  readonly approvals = {
    list: async (): Promise<Approval[]> => this.http.get<Approval[]>("/approvals"),
    approve: async (id: string, approvedBy = "operator"): Promise<Approval> =>
      this.http.post<Approval>(`/approvals/${id}/approve`, { approved_by: approvedBy }),
    deny: async (id: string, deniedBy = "operator", reason?: string): Promise<Approval> =>
      this.http.post<Approval>(`/approvals/${id}/deny`, {
        denied_by: deniedBy,
        reason
      })
  };

  readonly resources = {
    list: async (): Promise<Resource[]> => this.http.get<Resource[]>("/resources")
  };

  readonly events = {
    list: async (): Promise<AuditEvent[]> => this.http.get<AuditEvent[]>("/events"),
    subscribe: (
      onEvent: (event: AuditEvent) => void,
      onError?: (error: Event) => void
    ): (() => void) => {
      const source = this.http.eventSource("/events/stream");

      source.addEventListener("audit", (message) => {
        const event = JSON.parse((message as MessageEvent<string>).data) as AuditEvent;
        onEvent(event);
      });

      if (onError) {
        source.addEventListener("error", onError);
      }

      return () => source.close();
    }
  };
}
