#!/usr/bin/env bash
# Verificacao rapida OpenClaw + LiteLLM no agldv03 (SSH a partir do repo).
# Uso: bash scripts/openclaw/verify-openclaw-agldv03-remote.sh
set -euo pipefail
HOST="${AGLDV03:-root@100.94.221.87}"

ssh -o BatchMode=yes -o ConnectTimeout=25 "$HOST" bash <<'REMOTE'
set -euo pipefail
echo "=== systemctl --user openclaw-gateway ==="
systemctl --user is-active openclaw-gateway
systemctl --user show openclaw-gateway -p ActiveState,SubState,MainPID --no-pager

echo ""
echo "=== openclaw --version ==="
openclaw --version 2>&1 || true

echo ""
echo "=== openclaw.json (canais / telegram / gateway) ==="
jq '{channels: (.channels | keys), has_telegram_token: (.channels.telegram.botToken != null), gateway: {mode: .gateway.mode}}' /root/.openclaw/openclaw.json

echo ""
echo "=== agents.list (ids) ==="
jq -r '.agents.list[]? | .id' /root/.openclaw/openclaw.json 2>/dev/null || echo "(sem agents.list)"

echo ""
echo "=== ficheiros env / perms ==="
ls -la /root/.openclaw/litellm-gateway.env /root/.openclaw/zshrc-openclaw.env 2>&1 | sed -n '1,4p'
stat -c 'openclaw.json %a %U:%G' /root/.openclaw/openclaw.json

echo  ""
echo "=== LiteLLM /v1/models (com chave) ==="
if [[ -r /opt/litellm/.env ]]; then
  K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
  if [[ -n "${K:-}" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models)"
    echo "HTTP $code (esperado 200)"
  else
    echo "LITELLM_MASTER_KEY vazia em /opt/litellm/.env"
  fi
else
  echo "sem /opt/litellm/.env"
fi

echo ""
echo "=== logs (.openclaw/logs mais recente, se existir) ==="
if [[ -d /root/.openclaw/logs ]]; then
  latest="$(ls -t /root/.openclaw/logs 2>/dev/null | head -1)"
  if [[ -n "${latest:-}" ]]; then
    tail -n 15 "/root/.openclaw/logs/$latest" 2>/dev/null || true
  else
    echo "(pasta logs vazia)"
  fi
else
  echo "(sem pasta logs)"
fi

echo ""
echo "=== journalctl --user (pode estar vazio se journald user nao persistido) ==="
journalctl --user -u openclaw-gateway -n 12 --no-pager 2>&1 || true
REMOTE

echo ""
echo "=== OK (fim verificacao remota) ==="
