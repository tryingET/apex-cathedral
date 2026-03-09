#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4100}"

response="$(curl -s "$BASE_URL/executions" \
  -H 'content-type: application/json' \
  -d '{
    "workspace_id": "demo",
    "requested_by": "agent:writer",
    "capability": "workspace.fs.write_file",
    "arguments": {
      "path": "notes/hello.txt",
      "content": "hello from apex"
    }
  }')"

echo "$response"

approval_id="$(printf '%s' "$response" | jq -r '.data.approval_id')"

curl -s "$BASE_URL/approvals/$approval_id/approve" \
  -X POST \
  -H 'content-type: application/json' \
  -d '{"approved_by":"human:operator"}'
echo
