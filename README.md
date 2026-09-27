---
summary: "Project overview, architecture, and local development commands for Apex Cathedral."
read_when:
  - "When onboarding to the repo"
  - "When you need architecture context or local run/test commands"
---

# Apex Cathedral

Apex Cathedral is a **local-first execution runtime for AI agents on the BEAM**. It is built as an Elixir umbrella application with a small Plug gateway, a TypeScript SDK, a local UI, and a repository generator that can critique and re-emit the repository through iterative architecture passes.

The runtime is intentionally opinionated:

- agents request **capabilities**, not tools
- capabilities operate on supervised **resources**
- every execution passes through **policy evaluation**
- high-risk actions can pause for **approval**
- every meaningful state transition emits an **audit event**
- runtime logic stays in Elixir; TypeScript is only UI, SDK, and adapter-facing

## Why this repository exists

This repository is the **v3 implementation** of a three-pass architecture loop:

1. **Architecture v1** drafted the system.
2. **Architecture v2** absorbed skeptical review and removed hidden authority.
3. **Architecture v3** simplified the control plane into fewer than 20 core runtime modules while preserving the execution model.

See:

- `docs/architecture/architecture_v1.md`
- `docs/architecture/architecture_v2.md`
- `docs/architecture/architecture_v3.md`
- `docs/generator_design.md`
- `docs/failure_analysis.md`
- `docs/openapi.yaml`

## System model

```text
Agent
  -> capability request
  -> execution runtime
  -> policy evaluation
  -> approval (if required)
  -> resource process
  -> provider / external system
```

The runtime enforces:

- explicit authority boundaries
- a visible execution state machine
- structured audit events
- OTP supervision
- resource ownership by processes
- no hidden tool access

## Repository layout

```text
.
├── apps/
│   ├── audit/
│   ├── gateway/
│   ├── policy/
│   ├── providers/
│   ├── resources/
│   ├── runtime/
│   ├── ts-sdk/
│   └── ui/
├── config/
├── docker/
├── docs/
├── examples/
├── scripts/
└── var/
```

## Core domain objects

The runtime defines clear schemas for:

- Capability
- Resource
- Provider
- ExecutionRequest
- ExecutionRun
- ApprovalRequest
- PolicyDecision
- ExecutionResult
- AuditEvent
- Workspace

The control plane uses these execution states:

```text
REQUESTED
POLICY_EVALUATED
PENDING_APPROVAL
APPROVED
RUNNING
COMPLETED
FAILED
DENIED
TIMED_OUT
```

Approval is the main pause/resume boundary in the current design.

## Runtime components

The v3 runtime keeps the core understandable:

- `Apex.Runtime.CapabilityRegistry`
- `Apex.Policy.Engine`
- `Apex.Runtime.ExecutionManager`
- `Apex.Runtime.ApprovalManager`
- `Apex.Audit.Store`
- `Apex.Resources.Supervisor`
- `Apex.Resources.WorkspaceFS`
- `Apex.Resources.WorkspaceSQLite`
- `Apex.Resources.AccountSession`
- `Apex.Providers.Registry`
- `Apex.Providers.MockAccount`
- `Apex.Gateway.Router`

The rest of the code is support scaffolding around these modules.

## Quick start

### Prerequisites

- Elixir 1.17+
- Erlang/OTP 27+
- Node.js 20+
- SQLite toolchain required by `exqlite`

### Start the runtime

```bash
mix deps.get
mix run --no-halt
```

The gateway listens on `http://localhost:4100`.

### Start the UI

```bash
cd apps/ui
npm install
npm run dev
```

The UI listens on `http://localhost:5173`.

### Build the SDK

```bash
cd apps/ts-sdk
npm install
npm run build
```

## Demo flows

### 1) File write requiring approval

```bash
curl -s http://localhost:4100/executions   -H 'content-type: application/json'   -d '{
    "workspace_id": "demo",
    "requested_by": "agent:writer",
    "capability": "workspace.fs.write_file",
    "arguments": { "path": "notes/hello.txt", "content": "hello from apex" }
  }'
```

The execution will enter `PENDING_APPROVAL`.

Approve it:

```bash
curl -s http://localhost:4100/approvals/<approval-id>/approve   -X POST   -H 'content-type: application/json'   -d '{ "approved_by": "human:operator" }'
```

### 2) SQLite query automatically allowed

```bash
curl -s http://localhost:4100/executions   -H 'content-type: application/json'   -d '{
    "workspace_id": "demo",
    "requested_by": "agent:analyst",
    "capability": "workspace.sqlite.query",
    "arguments": { "sql": "SELECT 1 AS ok", "params": [] }
  }'
```

### 3) Policy denial example

The default policy marks `mock.account.update_profile` as `DRY_RUN_ONLY`. A normal execution is denied:

```bash
curl -s http://localhost:4100/executions   -H 'content-type: application/json'   -d '{
    "workspace_id": "demo",
    "requested_by": "agent:profile",
    "capability": "mock.account.update_profile",
    "mode": "EXECUTE",
    "arguments": { "patch": { "plan": "enterprise" } }
  }'
```

## OpenAPI

The gateway serves the OpenAPI document at:

- `GET /openapi.yaml`

The source lives in `docs/openapi.yaml` and is mirrored into `apps/gateway/priv/openapi.yaml`.

## Self-improving repository generator

The repository includes a generator that performs the four internal roles and writes iteration artifacts:

```bash
python3 scripts/cathedral_generator.py --out generated
```

It:

1. drafts v1
2. critiques with Skeptic
3. revises to v2
4. critiques with Simplifier
5. finalizes v3
6. validates invariants
7. emits a regenerated repository snapshot

See `docs/generator_design.md`.

## Testing

```bash
mix test
```

The test suite covers:

- policy evaluation
- execution lifecycle
- approval pause/resume
- provider execution
- gateway API integration

## Storage layout

By default, runtime data is stored under `var/apex`:

```text
var/apex/
├── audit/events.jsonl
└── workspaces/<workspace-id>/
    ├── fs/
    ├── workspace.sqlite
    └── mock_account.json
```

Use `APEX_STORAGE_ROOT` to relocate storage.

## Notes

This repository was authored to be runnable and cohesive, but the Elixir toolchain was not available in this execution environment, so the code could not be compiled here. The repository includes Docker and test scaffolding intended for normal local verification.
