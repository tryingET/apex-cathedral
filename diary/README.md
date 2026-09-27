---
summary: "Repo-local session diary format and crystallization flow."
read_when:
  - "When capturing a work session in this repo"
  - "When promoting raw notes into learnings or decisions"
---

# Diary

Repo-local session capture for KES (Knowledge Evolution System).

## Rule

Use `./diary/` as the canonical raw log for this repository.

- Entry file: `YYYY-MM-DD--type-scope-summary.md`
- Multiple sessions/day: `YYYY-MM-DD--type-scope-summary--2.md`
- Crystallize to: `docs/learnings/` and TIP proposals when patterns generalize

Filename convention:
- Start from a commit-style header: `type(scope): summary`
- Slug it into filename-safe form: `type-scope-summary`

## Entry template

```markdown
# YYYY-MM-DD — [Session Focus]

## What I Did
- [Actions]

## What Surprised Me
- [Unexpected outcomes]

## Patterns
- [Repeated structures]

## Crystallization Candidates
- → docs/learnings/
- → TIP proposal
```
