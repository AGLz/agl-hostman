#!/usr/bin/env bash
set -euo pipefail
M="${1:?model id}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$("$DIR/_litellm-master-key.sh")"
CURL_AUTH=()
if [[ -n "$K" ]]; then
  CURL_AUTH=(-H "Authorization: Bearer ${K}")
fi
curl -sS --max-time 120 -X POST "http://127.0.0.1:4000/v1/chat/completions" \
  "${CURL_AUTH[@]}" -H "Content-Type: application/json" \
  -d "{\"model\":\"${M}\",\"messages\":[{\"role\":\"user\",\"content\":\"x\"}],\"max_tokens\":4}"
