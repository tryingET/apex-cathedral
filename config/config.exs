import Config

storage_root =
  System.get_env("APEX_STORAGE_ROOT") ||
    Path.expand("../var/apex", __DIR__)

audit_log_path = Path.join([storage_root, "audit", "events.jsonl"])

config :apex,
  storage_root: storage_root,
  audit_log_path: audit_log_path,
  gateway_port: String.to_integer(System.get_env("PORT") || "4100"),
  approval_timeout_ms: 60_000,
  execution_timeout_ms: 30_000,
  policy_rules: [
    %{
      id: "allow-workspace-fs-read",
      capability_pattern: "workspace.fs.read_file",
      effect_types: [:read],
      workspace_scope: "*",
      resource_scope: "workspace.fs",
      decision: :allow,
      rationale: "Read-only file access is allowed by default."
    },
    %{
      id: "approve-workspace-fs-write",
      capability_pattern: "workspace.fs.write_file",
      effect_types: [:write],
      workspace_scope: "*",
      resource_scope: "workspace.fs",
      decision: :approval_required,
      rationale: "Workspace file writes require human approval."
    },
    %{
      id: "allow-workspace-sqlite-query",
      capability_pattern: "workspace.sqlite.query",
      effect_types: [:read],
      workspace_scope: "*",
      resource_scope: "workspace.sqlite",
      decision: :allow,
      rationale: "Read-only SQL queries are allowed."
    },
    %{
      id: "approve-workspace-sqlite-execute",
      capability_pattern: "workspace.sqlite.execute",
      effect_types: [:write],
      workspace_scope: "*",
      resource_scope: "workspace.sqlite",
      decision: :approval_required,
      rationale: "State-changing SQL requires approval."
    },
    %{
      id: "allow-mock-account-get-profile",
      capability_pattern: "mock.account.get_profile",
      effect_types: [:read],
      workspace_scope: "*",
      resource_scope: "mock.account",
      decision: :allow,
      rationale: "Profile reads are allowed."
    },
    %{
      id: "dry-run-only-mock-account-update",
      capability_pattern: "mock.account.update_profile",
      effect_types: [:external_side_effect],
      workspace_scope: "*",
      resource_scope: "mock.account",
      decision: :dry_run_only,
      rationale: "Account updates must be rehearsed before a real adapter is enabled."
    },
    %{
      id: "deny-by-default",
      capability_pattern: "*",
      effect_types: [:read, :write, :destructive, :external_side_effect],
      workspace_scope: "*",
      resource_scope: "*",
      decision: :deny,
      rationale: "Unknown or ungoverned capabilities are denied."
    }
  ]

config :logger,
  level: :info

import_config "#{config_env()}.exs"
