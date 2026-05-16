#!/usr/bin/env bash
# Smoke: LiteLLM local (ex. CT186) com modelo zai-coding-glm-4.7.
# Uso: LITELLM_URL=http://127.0.0.1:4000 LITELLM_MASTER_KEY=... bash scripts/litellm/test-zai-coding-litellm-local.sh
set -euo pipefail
BASE="${LITELLM_URL:-http://127.0.0.1:4000}"
KEY="${LITELLM_MASTER_KEY:-}"
if [ -z "$KEY" ]; then
  echo "Defina LITELLM_MASTER_KEY." >&2
  exit 2
fi
curl -sS "${BASE%/}/v1/chat/completions" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"zai-coding-glm-4.7","messages":[{"role":"user","content":"Output only: OK"}],"max_tokens":512,"temperature":0}' \
  | python3 -c "import sys,json;d=json.load(sys.stdin);e=d.get('error');assert not e,e;c=(d.get('choices')or[{}])[0].get('message',{}).get('content','');print('OK' if c.strip()=='OK' else repr(c[:120]))"
