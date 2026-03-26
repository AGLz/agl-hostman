#!/usr/bin/env bash
# Smoke zai/glm-4.7-flash no host LiteLLM (correr no CT como root). Enc: LF.
set -euo pipefail
K=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')
K=${K//\"/}
echo -n "readiness: "
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 http://127.0.0.1:4000/health/readiness
BODY=$(jq -nc '{model:"zai/glm-4.7-flash",messages:[{role:"user",content:"ping"}],max_tokens:8}')
curl -sS --max-time 35 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
  http://127.0.0.1:4000/v1/chat/completions -d "$BODY" | jq '{model_used:.model,content:(.choices[0].message.content//null),err:(.error.message//null)}'
