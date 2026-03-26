#!/usr/bin/env bash
set -euo pipefail
M="${1:?model id}"
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
K="${K//\"/}"
curl -sS -X POST "http://127.0.0.1:4000/v1/chat/completions" \
  -H "Authorization: Bearer ${K}" -H "Content-Type: application/json" \
  -d "{\"model\":\"${M}\",\"messages\":[{\"role\":\"user\",\"content\":\"x\"}],\"max_tokens\":4}"
