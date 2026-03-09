#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4100}"

curl -s "$BASE_URL/executions" \
  -H 'content-type: application/json' \
  -d '{
    "workspace_id": "demo",
    "requested_by": "agent:profile",
    "capability": "mock.account.update_profile",
    "mode": "EXECUTE",
    "arguments": {
      "patch": { "plan": "enterprise" }
    }
  }'
echo
