#!/usr/bin/env bash
# Diagnóstico OpenClaw agldv03: Telegram, LiteLLM, env.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

OC=/root/.openclaw/openclaw.json
echo "=== WS CLI (handshake gateway, OpenClaw 2026.3.x) ==="
echo "Se 'openclaw gateway call health' falhar (handshake timeout / 1000):"
echo "  bash $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply-openclaw-gateway-ws-handshake-timeout.sh 30000"
echo "  systemctl --user restart openclaw-gateway"
echo ""
echo "=== systemctl --user openclaw-gateway ==="
systemctl --user is-active openclaw-gateway 2>/dev/null || true

echo ""
echo "=== port 18789 (gateway) ==="
ss -tlnp 2>/dev/null | grep 18789 || echo "(ss sem 18789)"

echo ""
echo "=== LiteLLM local GET /v1/models ==="
if [[ -r /opt/litellm/.env ]]; then
  K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')"
  K="${K//\"/}"
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models)"
  echo "HTTP $code"
else
  echo "sem /opt/litellm/.env"
fi

echo ""
echo "=== openclaw litellm-gateway.env (só keys presentes) ==="
ENV=/root/.openclaw/litellm-gateway.env
if [[ -f "$ENV" ]]; then
  grep -E '^(LITELLM_GATEWAY_URL|LITELLM_MASTER_KEY)=' "$ENV" | sed 's/=.*/=***/'
else
  echo "sem $ENV"
fi

echo ""
echo "=== agent main: openai provider ==="
MP=/root/.openclaw/agents/main/agent/models.json
if [[ -f "$MP" ]]; then
  jq '{baseUrl: .providers.openai.baseUrl, apiKeyPrefix: (.providers.openai.apiKey|tostring|.[:18])}' "$MP" 2>/dev/null
else
  echo "sem models.json"
fi

echo ""
echo "=== Telegram getMe + getWebhookInfo (sem token) ==="
if [[ -f "$OC" ]]; then
  TOK="$(jq -r '.channels.telegram.botToken // empty' "$OC")"
  if [[ -n "$TOK" ]]; then
    curl -sS "https://api.telegram.org/bot${TOK}/getMe" | jq '{ok, username: .result.username, id: .result.id}'
    curl -sS "https://api.telegram.org/bot${TOK}/getWebhookInfo" | jq '{url: .result.url, pending: .result.pending_update_count, last_error: .result.last_error_message}' 2>/dev/null || true
  else
    echo "(sem botToken)"
  fi
else
  echo "sem openclaw.json"
fi

echo ""
echo "=== últimas linhas config-audit ==="
tail -5 /root/.openclaw/logs/config-audit.jsonl 2>/dev/null || echo "(sem audit)"

echo ""
echo "=== sessões main (ficheiros recentes) ==="
find /root/.openclaw/agents/main -name '*.jsonl' -mmin -120 2>/dev/null | head -5 || true
