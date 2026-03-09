---
summary: "Project model overview (purpose/mission/vision/goals)."
read_when:
  - "When onboarding or aligning scope"
---

# Project Model

Apex Cathedral is a polyglot project centered on an **Elixir umbrella runtime** with:

- `apps/runtime` for execution orchestration
- `apps/policy` for policy evaluation
- `apps/resources` for supervised resources
- `apps/audit` for audit storage/events
- `apps/providers` for provider integration
- `apps/gateway` for the HTTP/SSE surface
- `apps/ts-sdk` and `apps/ui` for TypeScript-facing surfaces

The architectural intent is captured in:

- `docs/architecture/architecture_v1.md`
- `docs/architecture/architecture_v2.md`
- `docs/architecture/architecture_v3.md`
- `docs/generator_design.md`
- `docs/failure_analysis.md`
- `docs/operations.md`

The repository was bootstrapped from `tpl-project-repo` and then populated from the two downloaded Apex Cathedral archives. See `docs/project/transition-summary.md` for provenance and merge details.
