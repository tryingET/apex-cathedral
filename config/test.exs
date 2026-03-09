import Config

storage_root = Path.expand("../tmp/apex-test", __DIR__)
audit_log_path = Path.join([storage_root, "audit", "events.jsonl"])

config :apex,
  storage_root: storage_root,
  audit_log_path: audit_log_path,
  approval_timeout_ms: 5_000,
  execution_timeout_ms: 2_000

config :logger,
  level: :warning
