#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$("$DIR/_litellm-master-key.sh")"
CURL_AUTH=()
[[ -n "$K" ]] && CURL_AUTH=(-H "Authorization: Bearer ${K}")
curl -sS --max-time 30 "http://127.0.0.1:4000/v1/models" "${CURL_AUTH[@]}" \
  | jq -r '.data[]?.id?' | grep -E '^zai/|^glm' | head -25
