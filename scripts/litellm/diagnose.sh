#!/usr/bin/env bash
# Diagnóstico LiteLLM — verifica health, auth, chat
# Uso: ./scripts/litellm/diagnose.sh [gateway_url]
# gateway_url default: http://localhost:4000 (ou LITELLM_GATEWAY_URL)

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${1:-${LITELLM_GATEWAY_URL:-http://localhost:4000}}"
KEY="$("$REPO_ROOT/.claude/helpers/get-litellm-key.sh" 2>/dev/null)"

echo "=== Diagnóstico LiteLLM ==="
echo "Gateway: $GATEWAY"
echo "Host: $(hostname)"
echo ""

echo "1. Health (readiness):"
curl -s -w " HTTP %{http_code}\n" --max-time 5 "$GATEWAY/health/readiness" 2>/dev/null || echo "  FALHOU"
echo ""

echo "2. Models (auth):"
code=$(curl -s -o /tmp/litellm-models.json -w "%{http_code}" --max-time 10 -H "Authorization: Bearer $KEY" "$GATEWAY/v1/models" 2>/dev/null)
echo "  HTTP $code"
[[ "$code" == "200" ]] && echo "  Modelos: $(jq -r '.data | length' /tmp/litellm-models.json 2>/dev/null || echo "?")" || echo "  Resposta: $(head -c 200 /tmp/litellm-models.json 2>/dev/null)"
echo ""

echo "3. Chat (qwen3-4b, 15s timeout):"
resp=$(curl -s --max-time 15 -X POST "$GATEWAY/chat/completions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"1"}],"max_tokens":2}' 2>/dev/null)
if echo "$resp" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
  echo "  OK: $(echo "$resp" | jq -r '.choices[0].message.content')"
else
  echo "  FALHOU: $(echo "$resp" | jq -r '.error.message // .' 2>/dev/null | head -c 150)"
fi
echo ""

echo "4. Docker logs (últimas 5 linhas):"
docker logs litellm-proxy 2>&1 | tail -5 2>/dev/null || echo "  Container não encontrado"
echo ""
echo "=== Fim ==="
