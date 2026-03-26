#!/usr/bin/env bash
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
K="${K//\"/}"
curl -sS "http://127.0.0.1:4000/v1/models" -H "Authorization: Bearer ${K}" \
  | jq -r '.data[]?.id?' | grep -E '^zai/|^glm' | head -25
