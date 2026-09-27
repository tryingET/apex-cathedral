---
summary: "Failure scenarios and mitigation choices for Apex Cathedral."
read_when:
  - "When reviewing runtime failure handling"
  - "When deciding whether a failure mode is intentional"
---

# Failure analysis

Apex Cathedral treats failure handling as part of the architecture, not as an afterthought.

## Provider crash

### Scenario

A provider function or execution worker crashes while an execution is running.

### Mitigation

- the execution worker is monitored
- the execution manager converts the crash into `FAILED`
- the audit log records the failure and reason
- no hidden retry occurs

## Resource contention

### Scenario

Many agents hit the same filesystem or SQLite workspace resource concurrently.

### Mitigation

- each resource is a process boundary
- resource state is serialized at the process boundary
- SQLite uses one connection per workspace resource process
- filesystem writes are performed atomically via temp file and rename

## Approval timeout

### Scenario

A high-risk execution waits for approval and no human responds.

### Mitigation

- each approval gets a timer
- the approval manager marks it timed out
- the execution transitions to `TIMED_OUT`
- the audit log records the timeout

## Policy misconfiguration

### Scenario

A capability is not covered by a sane rule set.

### Mitigation

- policy evaluation is first-match-wins and deterministic
- unmatched capabilities fall into the explicit deny-by-default rule
- the matched rule id is returned in the policy decision

## Partial execution failure

### Scenario

An effectful operation changes part of the world and then fails.

### Mitigation

- partial failure is surfaced as `FAILED`
- audit events preserve the narrative
- dry-run mode exists for sensitive adapters
- resource-specific compensating action is left explicit, not hidden

## Runtime restart

### Scenario

The BEAM node restarts while executions or approvals are live.

### Mitigation

- the audit log persists durable history
- hot state is rebuilt empty on restart today
- in-flight work fails visibly rather than silently resuming without operator awareness

That trade-off is deliberate in v3: clarity beats ambiguous recovery.

## Cathedral judgment

The architecture prefers visible failure over clever hidden recovery.
