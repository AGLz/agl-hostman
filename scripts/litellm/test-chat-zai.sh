#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$("$DIR/_litellm-master-key.sh")"
CURL_AUTH=()
[[ -n "$K" ]] && CURL_AUTH=(-H "Authorization: Bearer ${K}")
curl -sS --max-time 60 -X POST "http://127.0.0.1:4000/v1/chat/completions" \
  "${CURL_AUTH[@]}" -H "Content-Type: application/json" \
  -d '{"model":"glm-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' | head -c 400; echo
