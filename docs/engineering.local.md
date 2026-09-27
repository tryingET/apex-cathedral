---
summary: "Repo-local engineering-core adoption for apex-cathedral."
read_when:
  - "You are selecting engineering lanes, disciplines, or validation evidence for apex-cathedral work."
  - "You need repo-local deviations from shared engineering-core guidance."
type: "reference"
---

# apex-cathedral engineering guidance

## Upstream owner

Shared engineering lane and discipline guidance comes from `/home/tryinget/ai-society/core/engineering-core`.
This file records the repo-local selected subset for apex-cathedral, a Elixir/Phoenix-style umbrella with TypeScript SDK/UI surfaces. The repo `AGENTS.md` remains the operating authority for repo-specific workflow, source-owner boundaries, and read order.

Machine-readable selection lives in `policy/engineering-lane.json`.
Release pin: `v0.12.1` (`5be0f0a294014f2f7aee1ca5adcb6f3c76553e11`).

## Selected lanes

- `elixir`
- `ts`
- `ts-frontend`

```bash
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core show elixir
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core show ts
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core show ts-frontend
```

## Selected disciplines

- `validation`
- `testing`
- `security-privacy`
- `documentation`
- `dependency-governance`
- `local-first-data`
- `observability`
- `specification-and-dsls`
- `engineering-reasoning`
- `design-system`
- `accessibility`

Catalog/list commands:

```bash
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core catalog --pretty
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core list-disciplines
uv tool -n run --from 'git+https://github.com/tryingET/core_engineering-core.git@5be0f0a294014f2f7aee1ca5adcb6f3c76553e11' engineering-core list-templates
```

## Repo-local deviations and emphasis

- Prefer repo-local deterministic wrappers, workspace commands, `Justfile` targets, and package/app-local scripts over ad-hoc commands.
- Keep package/app-local validation and release behavior in the owning package or app surface.
- Treat this file as a selector and override note, not a replacement for `AGENTS.md` or runtime task/evidence authority.
- When local practice intentionally diverges from engineering-core guidance, record the reason here or in the owning project/decision document.
- The UI and SDK retain npm/package-local scripts instead of migrating to Bun: the existing npm lockfiles and CI workflow are the repo's local package-management contract; switching managers is outside this pin update.
- The UI typechecks with exactly pinned TypeScript 7.0.2 (`tsc --noEmit`). The SDK remains on its pre-existing TypeScript 5 pin in uncommitted package/publish work: that work renames a public package and needs a separate owner decision before its manifest can be committed or migrated to TypeScript 7.
- Elixir validation remains the repo's existing `just ci`/`scripts/ci/full.sh` smoke, ROCS build/validate, and structural checks rather than introducing Credo, Dialyzer, or `mix ci` in this metadata upgrade; full runtime tests are available separately via `just test`.
- No Biome, tsgo/native-preview, or Bun config is currently present to migrate; adopting an additional formatter/linter is a separate tooling decision.

## Canonical local commands

- `Use Mix commands for Elixir umbrella work and npm commands in TypeScript app/package folders.`

## Validation evidence expectations

For engineering-core adoption metadata changes:

```bash
python -m json.tool policy/engineering-lane.json >/tmp/apex-cathedral-engineering-lane.json
node /home/tryinget/ai-society/core/agent-scripts/scripts/docs-list.mjs --docs . --strict
```

For code/runtime changes, follow `AGENTS.md` and run the smallest truthful local validation command for the touched surface.

## Repo loop validation

This repo adopts `repo-loop-validation-v1` as an evidence-producing command surface for agent/orchestration loops. These commands do not replace AK task scope, CI, release approval, merge approval, BEAM runtime deployment approval, or production activation authority.

| Phase | Local command | Notes |
|---|---|---|
| `loop-doctor` | `just loop-doctor` | Non-failing diagnostic for tool versions, git state, AK binding, and obvious blockers. |
| `loop-verify-fast` | `just loop-verify-fast` | Runs metadata/docs and repo structural validation. |
| `loop-impact-plan` | `just loop-impact-plan` | Reports changed-file impact and the next bounded/wide check. |
| `loop-impact-run` | `just loop-impact-run` | Runs the bounded validation selected by the plan. |
| `loop-impact-wide` | `just loop-impact-wide` | Runs the full local gate when wide validation is accepted. |
| `loop-landing-check` | `just loop-landing-check` | Runs the repo-declared landing gate before handoff/commit finalization. |

Runtime launch, approval-policy behavior, provider integration, and production readiness remain separately scoped evidence. Loop validation can report local command evidence but must not by itself claim deployment or activation readiness.
