---
summary: "Operational storage model, environment variables, and runtime stance."
read_when:
  - "When running Apex Cathedral locally"
  - "When checking storage locations or operational assumptions"
---

# Operations

## Storage

By default, Apex Cathedral writes to `var/apex`.

### Audit

- `var/apex/audit/events.jsonl`

### Per-workspace state

- `var/apex/workspaces/<workspace-id>/fs/`
- `var/apex/workspaces/<workspace-id>/workspace.sqlite`
- `var/apex/workspaces/<workspace-id>/mock_account.json`

## Environment variables

- `PORT` - gateway port, default `4100`
- `APEX_STORAGE_ROOT` - local runtime storage root

## Auditing

Audit events are:

- persisted to JSONL
- queryable through the audit store
- streamable through server-sent events

## Policy updates

The policy engine loads rules from application config. In tests and development you can replace them through `Apex.Policy.Engine.put_rules/1`.

## Operational stance

This runtime is local-first and single-node by default. It is designed to be understandable before it is distributed.
