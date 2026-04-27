#!/usr/bin/env bash
set -euo pipefail
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')"
K="${K//\"/}"
run() {
  local m="$1"
  echo "=== $m ==="
  curl -sS --max-time 45 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    http://127.0.0.1:4000/v1/chat/completions \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"max_tokens\":30}" \
    | jq '{err: .error, t: .choices[0].message.content}' 2>/dev/null || echo fail
}
run "zai/glm-4.7-flash"
run "deepseek/deepseek-chat"
