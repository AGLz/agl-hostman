#!/usr/bin/env bash
# Diagnóstico: 404 em modelo OpenRouter :free obsoleto (ex.: gemini-*:free) no Telegram/OpenClaw.
set -euo pipefail
OC=/root/.openclaw/openclaw.json
ENV=/opt/litellm/.env

echo "=== google provider (openclaw) ==="
jq '.models.providers.google | {baseUrl, api, apiKey: (.apiKey | tostring | .[0:12] + "...")}' "$OC" 2>/dev/null || true

echo ""
echo "=== agents.defaults.model ==="
jq '.agents.defaults.model' "$OC" 2>/dev/null || true

echo ""
echo "=== LiteLLM models matching flash-lite (localhost) ==="
K="$(grep -m1 '^LITELLM_MASTER_KEY=' "$ENV" | cut -d= -f2-)"
K="${K//\"/}"
curl -sS "http://127.0.0.1:4000/v1/models" -H "Authorization: Bearer ${K}" \
  | jq -r '.data[]?.id? | select(test("flash-lite"))' 2>/dev/null || echo "(jq falhou)"

echo ""
echo "=== POST /v1/chat/completions (stream off, min tokens) ==="
payload='{"model":"openrouter/meta-llama/llama-3.3-70b-instruct:free","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'
code="$(curl -sS -o /tmp/llm_resp.txt -w "%{http_code}" -X POST "http://127.0.0.1:4000/v1/chat/completions" \
  -H "Authorization: Bearer ${K}" -H "Content-Type: application/json" -d "$payload")"
echo "HTTP $code"
head -c 400 /tmp/llm_resp.txt; echo
