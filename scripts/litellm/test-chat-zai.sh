#!/usr/bin/env bash
set -euo pipefail
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
K="${K//\"/}"
curl -sS -X POST "http://127.0.0.1:4000/v1/chat/completions" \
  -H "Authorization: Bearer ${K}" -H "Content-Type: application/json" \
  -d '{"model":"glm-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' | head -c 400; echo
