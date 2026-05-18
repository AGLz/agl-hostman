#!/usr/bin/env bash
set -euo pipefail
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')"
K="${K//\"/}"
body='{"model":"zai/glm-5","messages":[{"role":"user","content":"Diz olá numa palavra."}],"max_tokens":60}'
curl -sS --max-time 90 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
  http://127.0.0.1:4000/v1/chat/completions -d "$body" \
  | jq '{err: .error, finish: .choices[0].finish_reason, text: .choices[0].message.content, usage: .usage}'
