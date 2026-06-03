#!/usr/bin/env bash
# Verifica conectividade hermes-desktop → gateway Jarvis (CT188 :8642).
# Correr no PC com hermes-desktop (Windows/Linux/macOS) ou no CT188.
#
# Uso:
#   bash verify-hermes-desktop-remote.sh
#   HERMES_URL=http://100.81.225.22:8642 HERMES_API_KEY=... bash verify-hermes-desktop-remote.sh

set -euo pipefail

HERMES_URL="${HERMES_URL:-http://192.168.0.188:8642}"
HERMES_API_KEY="${HERMES_API_KEY:-}"

# Normalizar como hermes-desktop (strip /v1 e slashes finais)
HERMES_URL="${HERMES_URL%/}"
HERMES_URL="${HERMES_URL%/v1}"
HERMES_URL="${HERMES_URL%/V1}"

FAIL=0
ok() { echo "OK  $*"; }
fail() { echo "FAIL $*" >&2; FAIL=1; }

echo "=== Hermes remote (hermes-desktop) ==="
echo "URL base: ${HERMES_URL}"

echo ""
echo "=== 1. /health (sem auth — teste de rede) ==="
if curl -sf -m8 "${HERMES_URL}/health" | grep -q hermes-agent; then
  ok "${HERMES_URL}/health"
else
  fail "${HERMES_URL}/health — rede/firewall/Tailscale?"
fi

if [[ -z "${HERMES_API_KEY}" ]]; then
  echo ""
  echo "WARN: HERMES_API_KEY não definida — saltar testes autenticados."
  echo "      No CT188: grep ^API_SERVER_KEY= /opt/agl-hermes/.env"
  if [[ "${FAIL}" -eq 0 ]]; then
    echo ""
    echo "Rede OK. Configure a chave no hermes-desktop (Settings → Remote → API Key)."
    exit 0
  fi
  exit 1
fi

echo ""
echo "=== 2. /v1/models (Bearer — como hermes-desktop) ==="
code="$(curl -sS -m8 -o /tmp/hermes-models.json -w '%{http_code}' \
  -H "Authorization: Bearer ${HERMES_API_KEY}" \
  "${HERMES_URL}/v1/models")"
if [[ "${code}" == "200" ]] && grep -q hermes-agent /tmp/hermes-models.json 2>/dev/null; then
  ok "/v1/models HTTP ${code}"
else
  fail "/v1/models HTTP ${code} — chave errada? (use API_SERVER_KEY, não sk-litellm-...)"
fi

echo ""
echo "=== 3. /v1/chat/completions (smoke) ==="
code="$(curl -sS -m30 -o /tmp/hermes-chat.json -w '%{http_code}' \
  -H "Authorization: Bearer ${HERMES_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"ping"}],"max_tokens":8}' \
  "${HERMES_URL}/v1/chat/completions")"
if [[ "${code}" == "200" ]] && grep -q '"content"' /tmp/hermes-chat.json 2>/dev/null; then
  ok "/v1/chat/completions HTTP ${code}"
else
  fail "/v1/chat/completions HTTP ${code}"
fi

rm -f /tmp/hermes-models.json /tmp/hermes-chat.json

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "hermes-desktop remote: PASS"
  echo ""
  echo "No app: Settings → Connection → Remote"
  echo "  URL:  ${HERMES_URL}"
  echo "  Key:  (valor de API_SERVER_KEY no CT188)"
else
  echo "hermes-desktop remote: FAIL"
  exit 1
fi
