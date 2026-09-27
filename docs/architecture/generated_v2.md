---
summary: "Generated v2 architecture snapshot emitted by the repository generator."
read_when:
  - "When comparing generator output to the authored architecture docs"
  - "When debugging architecture iteration artifacts"
---

# Generated architecture v2

The control plane is collapsed into a registry, a policy engine, an approval manager, an execution manager, and supervised resources.

## Strengths

- much smaller surface area
- no hidden tool access
- approvals are now the primary pause/resume edge

## Weaknesses

- single execution manager may be a hotspot
- generator still needs repository invariants

## Decisions

- first-match-wins policy rules
- ETS for hot execution state
- disk-backed JSONL audit for persistence
