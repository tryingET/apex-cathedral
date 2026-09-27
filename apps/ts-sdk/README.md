---
summary: "TypeScript SDK usage for the Apex Cathedral gateway."
read_when:
  - "When integrating with Apex Cathedral from TypeScript"
  - "When checking the SDK surface against the HTTP API"
---

# Apex Cathedral TypeScript SDK

Install the published package:

```bash
npm install @tryinget/apex-cathedral-sdk
```

```ts
import { ApexClient } from "@tryinget/apex-cathedral-sdk";

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

## Notes

- The default gateway base URL is `http://localhost:4100`.
- `events.subscribe(...)` uses `EventSource`; in Node.js you may need an EventSource-compatible runtime or polyfill.
- Runtime authority remains in Elixir; the SDK is a thin typed client over the HTTP API.
