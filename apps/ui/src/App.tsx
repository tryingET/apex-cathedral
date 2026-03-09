import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  approve,
  listApprovals,
  listCapabilities,
  listExecutions,
  runExecution,
  subscribeEvents,
  type Approval,
  type AuditEvent,
  type Capability,
  type Execution
} from "./api";
import "./styles.css";

const DEFAULT_REQUEST = JSON.stringify(
  {
    workspace_id: "demo",
    requested_by: "agent:ui",
    capability: "workspace.sqlite.query",
    arguments: { sql: "SELECT 1 AS ok", params: [] }
  },
  null,
  2
);

export default function App() {
  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [executions, setExecutions] = useState<Execution[]>([]);
  const [approvals, setApprovals] = useState<Approval[]>([]);
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [requestBody, setRequestBody] = useState<string>(DEFAULT_REQUEST);
  const [error, setError] = useState<string>("");

  const pendingApprovals = useMemo(
    () => approvals.filter((approval) => approval.status === "PENDING"),
    [approvals]
  );

  async function refresh(): Promise<void> {
    const [capabilityData, executionData, approvalData] = await Promise.all([
      listCapabilities(),
      listExecutions(),
      listApprovals()
    ]);

    setCapabilities(capabilityData);
    setExecutions(executionData);
    setApprovals(approvalData);
  }

  useEffect(() => {
    void refresh().catch((err) => setError(String(err)));

    const unsubscribe = subscribeEvents((event) => {
      setEvents((current) => [event, ...current].slice(0, 25));
      void refresh().catch((err) => setError(String(err)));
    });

    return () => unsubscribe();
  }, []);

  async function onSubmit(event: FormEvent): Promise<void> {
    event.preventDefault();

    try {
      setError("");
      const body = JSON.parse(requestBody) as Record<string, unknown>;
      await runExecution(body);
      await refresh();
    } catch (err) {
      setError(String(err));
    }
  }

  async function onApprove(approvalId: string): Promise<void> {
    try {
      setError("");
      await approve(approvalId);
      await refresh();
    } catch (err) {
      setError(String(err));
    }
  }

  return (
    <main className="page">
      <header className="hero">
        <h1>Apex Cathedral</h1>
        <p>Governed BEAM-native execution runtime for AI agents.</p>
      </header>

      {error ? <div className="error">{error}</div> : null}

      <section className="card">
        <h2>Run execution</h2>
        <form onSubmit={onSubmit}>
          <textarea
            value={requestBody}
            onChange={(event) => setRequestBody(event.target.value)}
            rows={14}
          />
          <button type="submit">Submit execution</button>
        </form>
      </section>

      <section className="grid">
        <article className="card">
          <h2>Capabilities</h2>
          <ul>
            {capabilities.map((capability) => (
              <li key={capability.name}>
                <strong>{capability.name}</strong>
                <div>{capability.description}</div>
                <small>
                  {capability.effect_type} · {capability.resource_scope} ·{" "}
                  {capability.approval_requirement}
                </small>
              </li>
            ))}
          </ul>
        </article>

        <article className="card">
          <h2>Executions</h2>
          <ul>
            {executions.map((execution) => (
              <li key={execution.id}>
                <strong>{execution.capability}</strong>
                <div>
                  {execution.state} · workspace={execution.workspace_id}
                </div>
                <small>{execution.id}</small>
              </li>
            ))}
          </ul>
        </article>

        <article className="card">
          <h2>Approvals</h2>
          <ul>
            {approvals.map((approval) => (
              <li key={approval.approval_id}>
                <strong>{approval.capability}</strong>
                <div>{approval.status}</div>
                {approval.status === "PENDING" ? (
                  <button onClick={() => void onApprove(approval.approval_id)}>
                    Approve
                  </button>
                ) : null}
              </li>
            ))}
          </ul>

          <p className="muted">Pending approvals: {pendingApprovals.length}</p>
        </article>
      </section>

      <section className="card">
        <h2>Audit stream</h2>
        <ul>
          {events.map((event) => (
            <li key={event.id}>
              <strong>{event.type}</strong> <small>{event.inserted_at}</small>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
