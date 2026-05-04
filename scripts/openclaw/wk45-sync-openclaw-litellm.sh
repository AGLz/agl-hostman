#!/usr/bin/env bash
# Sincroniza OpenClaw na aglwk45 (Git Bash / Linux) com o LiteLLM do agldv03:
# - substitui apiKey "sk-litellm-default" pela LITELLM_MASTER_KEY real
# - substitui baseUrl localhost/127.0.0.1:4000 pelo URL do proxy (Tailscale por defeito)
#
# Uso:
#   bash scripts/openclaw/wk45-sync-openclaw-litellm.sh
#   LITELLM_MASTER_KEY='sk-...' bash scripts/openclaw/wk45-sync-openclaw-litellm.sh
#   LITELLM_PROXY_BASE_URL='http://100.125.249.8:4000' bash scripts/openclaw/wk45-sync-openclaw-litellm.sh
#
# Se LITELLM_MASTER_KEY não estiver definida, tenta SSH ao agldv03 (requer chave SSH).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JQ_FILTER="$REPO_ROOT/config/openclaw/wk45-sync-openclaw-litellm.jq"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
GATEWAY_HOST="${LITELLM_SSH_HOST:-root@100.94.221.87}"
PROXY_URL="${LITELLM_PROXY_BASE_URL:-http://100.125.249.8:4000}"

[[ ! -f "$JQ_FILTER" ]] && { echo "Erro: $JQ_FILTER não encontrado"; exit 1; }
[[ ! -f "$OPENCLAW_JSON" ]] && { echo "Erro: $OPENCLAW_JSON não existe"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Erro: jq não está no PATH"; exit 1; }

KEY="${LITELLM_MASTER_KEY:-}"
if [[ -z "$KEY" ]]; then
  echo "A obter LITELLM_MASTER_KEY via SSH ($GATEWAY_HOST)…"
  KEY="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$GATEWAY_HOST" "grep ^LITELLM_MASTER_KEY= /opt/litellm/.env 2>/dev/null | cut -d= -f2-" || true)"
fi

if [[ -z "$KEY" ]]; then
  echo "Defina LITELLM_MASTER_KEY ou configure SSH ao agldv03."
  echo "Ex.: export LITELLM_MASTER_KEY=\"\$(ssh root@100.94.221.87 'grep ^LITELLM_MASTER_KEY= /opt/litellm/.env | cut -d= -f2-')\""
  exit 1
fi

BACKUP="${OPENCLAW_JSON}.bak.$(date +%Y%m%d%H%M)"
cp -a "$OPENCLAW_JSON" "$BACKUP"
echo "Backup: $BACKUP"

jq --arg k "$KEY" --arg url "$PROXY_URL" -f "$JQ_FILTER" "$OPENCLAW_JSON" > "${OPENCLAW_JSON}.new"
mv "${OPENCLAW_JSON}.new" "$OPENCLAW_JSON"

echo "OK: openclaw.json atualizado (apiKey + baseUrl → proxy)."
echo "Teste: curl -s -o /dev/null -w '%{http_code}' -H \"Authorization: Bearer \$LITELLM_MASTER_KEY\" ${PROXY_URL}/v1/models"
echo "Reiniciar: openclaw gateway restart"
