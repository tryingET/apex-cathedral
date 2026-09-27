---
summary: "Architecture v1 baseline and why it was too complex."
read_when:
  - "When tracing the architecture evolution"
  - "When evaluating why forwarding layers were removed"
---

# Architecture v1

## Intent

The first pass designed Apex Cathedral as a **full execution operating system** for agents. The design deliberately chose explicit domain objects and explicit state machines, but it also accumulated too much control-plane machinery too early.

## Shape

### Control plane

- Capability registry
- Policy engine
- Approval manager
- Execution manager
- Command router
- Event bus
- Audit event store
- Provider supervisor
- Resource supervisor
- Recovery worker

### Data flow

```text
Agent
  -> Gateway
  -> Command Router
  -> Policy Engine
  -> Approval Manager
  -> Execution Manager
  -> Provider Router
  -> Resource Lease Manager
  -> External System
```

## Strengths

- strong domain language from day one
- event audit spine was explicit
- approvals and policy were first-class
- resource ownership was process-oriented

## Weaknesses discovered by internal review

### Architect

The design preserved invariants well, but it introduced too many layers between request and execution.

### Skeptic

The command router and provider router looked suspiciously like indirection for its own sake. Recovery and replay were discussed but not specified enough to be dependable.

### Simplifier

The architecture exceeded the complexity budget. Engineers would need too much time to understand why every message was routed through multiple brokers.

### Builder

The implementation surface was too large for a solid v1 repository.

## Main critique

- too many forwarding layers
- hidden authority risk through implicit provider routing
- unclear persistence boundary for execution state
- too many core modules for a cathedral-style foundation

## Outcome

Keep the domain model, the state machine, the policy/approval ordering, and the audit spine.

Remove any layer whose only job is message forwarding.
