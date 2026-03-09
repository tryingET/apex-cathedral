#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4100}"

curl -s "$BASE_URL/executions" \
  -H 'content-type: application/json' \
  -d '{
    "workspace_id": "demo",
    "requested_by": "agent:analyst",
    "capability": "workspace.sqlite.query",
    "arguments": {
      "sql": "SELECT 1 AS ok",
      "params": []
    }
  }'
echo
