---
summary: "Provenance and transition notes for the imported Apex Cathedral archives."
read_when:
  - "When you need to know where the current repo contents came from"
  - "When reconciling the imported runtime with the tpl-project-repo scaffold"
---

# Transition Summary

## Source archives

The repo was created after inspecting the two newest ZIP files in `~/Downloads`:

1. `apex-cathedral-generated.zip`
2. `apex-cathedral.zip`

## What they are

Both archives represent the same project: **Apex Cathedral**, a local-first AI-agent execution runtime on the BEAM.

- `apex-cathedral.zip` is the base repository snapshot.
- `apex-cathedral-generated.zip` is a deterministic generated snapshot of that same repo.
- All overlapping files in the two archives were byte-identical.

## Naming decision

The canonical repo name was taken from the non-generated archive root and the project title in `README.md`: **`apex-cathedral`**.

The `-generated` archive was treated as a derived artifact, not as the canonical repo name.

## Transition strategy used

1. Scaffold a new repo from `tpl-project-repo` as `apex-cathedral`.
2. Keep the template governance/documentation structure (`AGENTS.md`, `governance/`, `ontology/`, `docs/_core/`, ROCS tooling, etc.).
3. Import `apex-cathedral-generated.zip` as the primary source snapshot.
4. Union in the original-only paths from `apex-cathedral.zip`.

## Resulting merge behavior

This preserved:

- generated-only metadata: `.apex-cathedral/manifest.json`
- generated-only architecture docs: `docs/architecture/generated_v1.md`, `generated_v2.md`, `generated_v3.md`
- original-only container assets: `docker/runtime.Dockerfile`, `docker/ui.Dockerfile`

## Template metadata note

`tpl-project-repo` does not currently expose an `elixir` language option, so the scaffold metadata was created with `language: bash` and `enable_software_pack: false`.

That metadata choice is only about template compatibility. The imported project itself is primarily **Elixir + TypeScript**.
