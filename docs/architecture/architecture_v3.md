# Architecture v3

## Final design

Apex Cathedral v3 is a **local-first BEAM execution runtime for AI agents** built around one simple invariant:

> Agents do not call tools directly. They request governed capabilities that execute against supervised resources.

## Core architecture

```text
Agent
  -> capability request
  -> runtime control plane
      -> capability registry
      -> policy engine
      -> approval manager (if required)
      -> execution manager
  -> supervised resource or provider handler
  -> external system
  -> audit event store / stream
```

## Design principles

- clarity over cleverness
- explicit state transitions
- deny by default
- resource ownership by processes
- local state is owned where it is used
- audit is append-only and queryable
- the TypeScript layer never owns runtime authority

## Core modules

The v3 architecture is intentionally small:

1. `Apex.Runtime.CapabilityRegistry`
2. `Apex.Policy.Engine`
3. `Apex.Runtime.ExecutionManager`
4. `Apex.Runtime.ApprovalManager`
5. `Apex.Audit.Store`
6. `Apex.Resources.Supervisor`
7. `Apex.Resources.WorkspaceFS`
8. `Apex.Resources.WorkspaceSQLite`
9. `Apex.Resources.AccountSession`
10. `Apex.Providers.Registry`
11. `Apex.Providers.MockAccount`
12. `Apex.Gateway.Router`

Application modules, type containers, and tests exist around these, but the architecture's reasoning lives here.

## Domain schemas

### Capability

- `name`
- `description`
- `input_schema`
- `output_schema`
- `effect_type`
- `destructive_flag`
- `resource_scope`
- `approval_requirement`
- `provider`
- `handler`

### Resource

- `id`
- `type`
- `scope`
- `workspace_id`
- `owner_pid`
- `status`
- `metadata`
- `inserted_at`
- `updated_at`

### Provider

- `name`
- `description`
- `capabilities`
- `adapter_module`

### ExecutionRequest

- `id`
- `workspace_id`
- `capability`
- `arguments`
- `requested_by`
- `mode`
- `inserted_at`

### ExecutionRun

- `id`
- `request_id`
- `workspace_id`
- `capability`
- `arguments`
- `requested_by`
- `mode`
- `state`
- `policy_decision`
- `approval_id`
- `resource_scope`
- `started_at`
- `completed_at`
- `updated_at`
- `result`
- `error`
- `transitions`

### ApprovalRequest

- `approval_id`
- `execution_id`
- `capability`
- `arguments`
- `requested_by`
- `status`
- `timestamp`
- `updated_at`
- `approved_by`
- `denied_by`
- `expires_at`

### PolicyDecision

- `decision`
- `matched_rule`
- `rationale`
- `effect_type`

### ExecutionResult

- `status`
- `output`
- `duration_ms`
- `dry_run`
- `completed_at`

### AuditEvent

- `id`
- `type`
- `entity_type`
- `entity_id`
- `workspace_id`
- `actor`
- `payload`
- `inserted_at`

### Workspace

- `id`
- `root_path`
- `created_at`

## Execution lifecycle

```text
REQUESTED
  -> POLICY_EVALUATED
    -> PENDING_APPROVAL
      -> APPROVED
        -> RUNNING
          -> COMPLETED
          -> FAILED
          -> TIMED_OUT
    -> APPROVED
      -> RUNNING
        -> COMPLETED
        -> FAILED
        -> TIMED_OUT
    -> DENIED
```

Approval is the current pause/resume edge.

## Policy model

Policies support:

- capability pattern matching
- wildcard rules
- effect-type rules
- workspace scope rules
- resource scope rules

Evaluation is deterministic and first-match-wins.

## Resource model

Resources are stateful processes supervised under OTP:

- `WorkspaceFS` owns file access under a workspace root
- `WorkspaceSQLite` owns a SQLite connection per workspace
- `AccountSession` owns mock account session state per workspace

This keeps authority local and concurrency explicit.

## Failure handling

- provider crash -> monitored execution fails visibly
- resource contention -> serialized by the resource process
- approval timeout -> execution moves to `TIMED_OUT`
- policy misconfiguration -> deny by default
- partial execution failure -> terminal failure with audit trail

## Why v3 is the cathedral version

The final design is small enough to understand, explicit enough to trust, and extensible enough to grow.
