#!/usr/bin/env bash
# Um pedido de teste ao LiteLLM local (modelo como 1º arg).
set -euo pipefail
M="${1:-anthropic/claude-sonnet-4-6}"
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
body="$(jq -nc --arg m "$M" '{model:$m,messages:[{role:"user",content:"Diz só OK."}],max_tokens:20}')"
curl -sS --max-time 90 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
  http://127.0.0.1:4000/v1/chat/completions -d "$body" \
  | jq '{finish:.choices[0].finish_reason,content:.choices[0].message.content,err:.error}'
