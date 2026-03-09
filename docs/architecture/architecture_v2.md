# Architecture v2

## What changed

The second pass absorbed the Skeptic review and collapsed the control plane into fewer explicit managers.

## Shape

```text
Gateway
  -> Capability Registry
  -> Policy Engine
  -> Approval Manager (if needed)
  -> Execution Manager
  -> Resource / Provider Handler
  -> Audit Store
```

## Major decisions

- **first-match-wins** policy evaluation
- **append-only audit log** as the durable narrative of the system
- **ETS** for hot execution state
- **supervised resources** as the concurrency boundary
- **approval** becomes the visible pause/resume edge

## Improvements over v1

- no generic command router
- no provider router as an extra hop
- capability handlers resolve directly to either a resource-backed action or a provider module
- the gateway stays thin and stateless
- the execution manager is responsible for only orchestration and state transitions

## Remaining weaknesses

### Architect

The design was now coherent, but still needed a stronger statement of where persistence lives.

### Skeptic

A single execution manager could become a hot spot.

### Simplifier

Some cross-app type sharing was still noisy. The final version needed clearer boundaries and fewer moving parts.

### Builder

The design was implementable, but needed one more simplification pass to feel durable ten years from now.

## Outcome

Retain the simplified control plane.

Push persistence into the audit log and local resource state.

Keep the core runtime under the module budget.
