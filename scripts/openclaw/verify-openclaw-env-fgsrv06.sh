#!/usr/bin/env bash
# Verificação openclaw.conf (sem ${) + GET /v1/models no LITELLM_GATEWAY_URL de litellm-gateway.env.
# Uso em qualquer host (fgsrv06, agldv03, etc.).
set -euo pipefail
CONF=/root/.config/environment.d/openclaw.conf
ENV=/root/.openclaw/litellm-gateway.env
if grep -qF '${' "$CONF" 2>/dev/null; then
  echo "ERRO: $CONF contem sintaxe shell \${ — systemd nao expande."
  exit 1
fi
echo "OK: $CONF sem \${"
if [[ -f "$ENV" ]]; then
  # shellcheck source=/dev/null
  source "$ENV"
  BASE="${LITELLM_GATEWAY_URL:-http://127.0.0.1:4000}"
  BASE="${BASE%/}"
  K="${LITELLM_MASTER_KEY:-}"
  K="${K#\"}"
  K="${K%\"}"
  echo -n "Probe GET ${BASE}/v1/models HTTP "
  curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${K}" "${BASE}/v1/models" || echo "curl_fail"
  echo
else
  echo "AVISO: falta $ENV"
fi
systemctl --user is-active openclaw-gateway 2>&1 | sed 's/^/gateway: /'
