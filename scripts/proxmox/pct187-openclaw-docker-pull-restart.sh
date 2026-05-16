#!/usr/bin/env bash
# Actualiza a imagem OpenClaw no CT187 (docker compose pull + up -d) e reinicia o stack.
# Lê variáveis de /opt/agl-openclaw/.env (ex.: OPENCLAW_IMAGE). Variáveis extra tipo
# TELEGRAM_BOT_TOKEN_OLD= não são passadas ao contentor — só as referenciadas no compose.
#
# Proxmox AGLSRV1:
#   bash /caminho/agl-hostman/scripts/proxmox/pct187-openclaw-docker-pull-restart.sh
#
set -euo pipefail

CT="${CT:-187}"

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no AGLSRV1." >&2
  exit 1
}

pct exec "$CT" -- bash <<'REMOTE'
set -euo pipefail
cd /opt/agl-openclaw
test -f docker-compose.yml || {
  echo "ERRO: falta /opt/agl-openclaw/docker-compose.yml" >&2
  exit 1
}
echo "=== docker compose pull ==="
docker compose -f docker-compose.yml pull
echo "=== docker compose up -d ==="
docker compose -f docker-compose.yml up -d
echo "OK: stack actualizada. Imagens:"
docker compose -f docker-compose.yml images
REMOTE

echo "Health (host): pct exec ${CT} -- curl -sf http://127.0.0.1:28789/healthz | head -c 200 || true"
echo "Logs: pct exec ${CT} -- docker logs agl-openclaw-openclaw-gateway-1 --tail 50"
