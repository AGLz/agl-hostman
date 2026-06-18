#!/usr/bin/env bash
# Para serviços migrados no FGSRV6 (sem formatar o host).
# Ordem: cloudflared Docker → n8n/traefik Docker → nginx (opcional) → wireguard (após cutover WG576).
#
# Uso:
#   bash scripts/maint/fgsrv07/stop-fgsrv6-migrated-services.sh
#   SKIP_NGINX=1 bash scripts/maint/fgsrv07/stop-fgsrv6-migrated-services.sh
set -euo pipefail

FGSRV6="${FGSRV6:-root@100.83.51.9}"
SKIP_NGINX="${SKIP_NGINX:-0}"
SKIP_WG="${SKIP_WG:-1}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

ssh -o BatchMode=yes "${FGSRV6}" bash -s <<REMOTE
set -euo pipefail
log() { printf '[FGSRV6] %s\n' "\$*"; }

if docker ps --format '{{.Names}}' | grep -qx cloudflared-tunnel; then
  log "Parar cloudflared-tunnel Docker"
  docker stop cloudflared-tunnel
  docker update --restart=no cloudflared-tunnel 2>/dev/null || true
fi

for c in n8n-n8n-1 traefik; do
  if docker ps -a --format '{{.Names}}' | grep -qx "\$c"; then
    log "Parar container \$c"
    docker stop "\$c" 2>/dev/null || true
    docker update --restart=no "\$c" 2>/dev/null || true
  fi
done

if [[ "${SKIP_NGINX}" != "1" ]]; then
  if systemctl is-active nginx &>/dev/null; then
    log "Parar nginx"
    systemctl stop nginx
    systemctl disable nginx 2>/dev/null || true
  fi
fi

if [[ "${SKIP_WG}" != "1" ]]; then
  log "Parar wg-quick@wg0"
  systemctl stop wg-quick@wg0 2>/dev/null || wg-quick down wg0 2>/dev/null || true
  systemctl disable wg-quick@wg0 2>/dev/null || true
fi

log "Estado actual:"
docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | head -10 || true
systemctl is-active nginx 2>/dev/null || echo nginx=stopped
systemctl is-active wg-quick@wg0 2>/dev/null || echo wg=stopped
REMOTE

log "FGSRV6: serviços migrados parados (host intacto)."
