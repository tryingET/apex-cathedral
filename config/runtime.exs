import Config

storage_root =
  System.get_env("APEX_STORAGE_ROOT") ||
    Application.get_env(:apex, :storage_root) ||
    Path.expand("../var/apex", __DIR__)

config :apex,
  storage_root: storage_root,
  audit_log_path: Path.join([storage_root, "audit", "events.jsonl"]),
  gateway_port: String.to_integer(System.get_env("PORT") || Integer.to_string(Application.get_env(:apex, :gateway_port, 4100)))
