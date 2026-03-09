# Apex Cathedral TypeScript SDK

```ts
import { ApexClient } from "@apex-cathedral/ts-sdk";

const client = new ApexClient({ baseUrl: "http://localhost:4100" });

const capabilities = await client.capabilities.list();

const execution = await client.executions.run({
  workspace_id: "demo",
  requested_by: "agent:sdk",
  capability: "workspace.sqlite.query",
  arguments: { sql: "SELECT 1 AS ok", params: [] }
});

const approvals = await client.approvals.list();

const unsubscribe = client.events.subscribe((event) => {
  console.log(event.type, event.payload);
});
```

The SDK intentionally mirrors the thin gateway surface. Runtime logic remains in Elixir.
