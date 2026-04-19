#!/usr/bin/env bash
set -euo pipefail
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')"
K="${K//\"/}"
body='{"model":"anthropic/claude-sonnet-4-6","messages":[{"role":"user","content":"Diz OK"}],"max_tokens":20}'
curl -sS --max-time 120 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
  http://127.0.0.1:4000/v1/chat/completions -d "$body" \
  | jq '{err: .error, text: .choices[0].message.content}'
