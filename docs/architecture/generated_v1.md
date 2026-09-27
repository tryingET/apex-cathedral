---
summary: "Generated v1 architecture snapshot emitted by the repository generator."
read_when:
  - "When comparing generator output to the authored architecture docs"
  - "When debugging architecture iteration artifacts"
---

# Generated architecture v1

A full control plane with event sourcing, command routing, provider indirection, and resource leases.

## Strengths

- clear separation between capabilities, policies, approvals, and resources
- strong audit spine
- explicit domain models

## Weaknesses

- too many moving parts for a first implementation
- too much indirection between capability and execution
- recovery design is underspecified

## Decisions

- use an append-only audit log
- model execution as a visible state machine
- make resources supervised processes
