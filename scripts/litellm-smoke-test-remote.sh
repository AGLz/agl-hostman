#!/usr/bin/env bash
# Executar no agldv03: lê api_key de ~/.hermes/config.yaml (sem imprimir).
set -euo pipefail
KEY=$(awk '/^[[:space:]]*api_key:/{gsub(/"/,"",$2); print $2; exit}' "${HERMES_CONFIG:-/root/.hermes/config.yaml}")
BASE="${LITELLM_URL:-http://127.0.0.1:4000}/v1/chat/completions"
# Aliases conforme GET /v1/models no LiteLLM do agldv03 (podem mudar com deploy).
MODELS=(
  qwen-coder
  glm-flash
  gemini-lite
  agl-primary
  ollama-nemotron-3-nano-4b
  or-hermes-free
  or-nemotron-super-free
  or-llama-3.3-70b-free
  or-minimax-m2.5-free
  or-gemma-3-4b-free
  openrouter-free
  openrouter/openrouter/free
)
for m in "${MODELS[@]}"; do
  code=$(curl -sS -o /tmp/lm-smoke.json -w "%{http_code}" -X POST "$BASE" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply exactly: PONG\"}],\"max_tokens\":32}" || echo "000")
  if command -v jq >/dev/null 2>&1; then
    err=$(jq -r '.error.message // empty' /tmp/lm-smoke.json 2>/dev/null | head -c 200)
    content=$(jq -r '.choices[0].message.content // empty' /tmp/lm-smoke.json 2>/dev/null | head -c 120)
  else
    err=$(python3 -c "import json;print((json.load(open('/tmp/lm-smoke.json')).get('error')or{}).get('message','')[:200])")
    content=$(python3 -c "import json;d=json.load(open('/tmp/lm-smoke.json'));print(((d.get('choices')or[{}])[0].get('message')or{}).get('content','')[:120])")
  fi
  if [ "$code" = "200" ] && [ -z "$err" ]; then
    echo "OK  $m  HTTP=$code  content=${content//$'\n'/ }"
  else
    echo "BAD $m  HTTP=$code  err=${err//$'\n'/ }  content=${content//$'\n'/ }"
  fi
done
