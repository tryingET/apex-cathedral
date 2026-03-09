#!/usr/bin/env bash
set -euo pipefail

ROOT="${APEX_STORAGE_ROOT:-var/apex}"
mkdir -p "$ROOT/workspaces/demo/fs"
cat > "$ROOT/workspaces/demo/mock_account.json" <<'JSON'
{"id":"demo","name":"Demo User","plan":"free"}
JSON

echo "seeded demo workspace at $ROOT/workspaces/demo"
