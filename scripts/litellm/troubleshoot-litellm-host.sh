#!/usr/bin/env bash
# Diagnóstico LiteLLM num host (correr como root no CT/VPS).
set -euo pipefail
echo "======== $(hostname) @ $(date -Iseconds) ========"
echo "=== Docker ==="
docker ps -a --filter name=litellm --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "(docker indisponível)"

echo ""
echo "=== Últimos logs litellm-proxy (80) ==="
docker logs litellm-proxy --tail 80 2>&1 || echo "(sem logs)"

echo ""
echo "=== .env: presença de chaves (comprimento valor) ==="
if [[ -f /opt/litellm/.env ]]; then
  while IFS= read -r key; do
    line=$(grep -m1 "^${key}=" /opt/litellm/.env 2>/dev/null || true)
    val="${line#*=}"
    echo "$key len=${#val}"
  done <<'KEYS'
LITELLM_MASTER_KEY
DATABASE_URL
OPENAI_API_KEY
ANTHROPIC_API_KEY
GEMINI_API_KEY
ZAI_API_KEY
DEEPSEEK_API_KEY
MOONSHOT_API_KEY
KEYS
else
  echo "(sem /opt/litellm/.env)"
fi

echo ""
echo "=== Readiness + modelos (Bearer master) ==="
if [[ -f /opt/litellm/.env ]]; then
  K=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')
  K=${K//\"/}
  echo -n "GET /health/readiness: "
  curl -sS -o /dev/null -w '%{http_code}\n' --max-time 10 http://127.0.0.1:4000/health/readiness || echo "fail"
  echo -n "GET /v1/models: "
  curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models || echo "fail"
else
  echo "(sem .env)"
fi

echo ""
echo "=== Chat smoke (3 modelos, 25s cada) ==="
if [[ -f /opt/litellm/.env ]]; then
  K=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')
  K=${K//\"/}
  smoke() {
    local m="$1"
    local b
    b=$(jq -nc --arg m "$m" '{model:$m,messages:[{role:"user",content:"ping"}],max_tokens:8}')
    local out
    out=$(curl -sS --max-time 25 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
      http://127.0.0.1:4000/v1/chat/completions -d "$b" 2>&1) || out="curl_err:$?"
    local em
    em=$(echo "$out" | jq -r 'if .error then (.error.message//.error|tostring)[0:200] else (.choices[0].message.content//"")[0:80] end' 2>/dev/null || echo "jq_fail")
    echo "$m => $em"
  }
  smoke "zai/glm-4.7-flash"
  smoke "deepseek/deepseek-chat"
  smoke "anthropic/claude-haiku-4-5-20251001" || true
fi

echo ""
echo "=== postgres litellm-db (se existir) ==="
docker exec litellm-db pg_isready -U litellm -d litellm 2>&1 || true

echo "======== fim $(hostname) ========"
