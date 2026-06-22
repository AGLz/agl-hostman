#!/usr/bin/env bash
# Proxy TCP 8007 no host AGLSRV3 → CT318 aglsrv3-pbs (LAN).
# Necessário enquanto CT318 partilha identidade Tailscale clone (aglsrv6-pbs).
#
# Uso:
#   bash scripts/proxmox/aglsrv3-pbs-host-proxy.sh --install
#   bash scripts/proxmox/aglsrv3-pbs-host-proxy.sh --status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
PBS_LAN_IP="$(echo "${AGLSRV3_PBS_IP:-192.168.15.118/24}" | cut -d/ -f1)"
LISTEN_PORT="${AGLSRV3_PBS_PROXY_PORT:-8007}"
SERVICE_NAME="aglsrv3-pbs-proxy"

log() { echo "[$(date +%H:%M:%S)] $*"; }

install_remote() {
  ssh -o BatchMode=yes "${AGLSRV3_SSH}" "bash -s" <<EOF
set -euo pipefail
PBS_IP='${PBS_LAN_IP}'
PORT='${LISTEN_PORT}'
cat > /etc/systemd/system/${SERVICE_NAME}.service <<UNIT
[Unit]
Description=Proxy PBS aglsrv3-pbs (CT318) para acesso remoto via host
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:\${PORT},fork,reuseaddr TCP:\${PBS_IP}:8007
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}
systemctl is-active ${SERVICE_NAME}
ss -tlnp | grep ":${LISTEN_PORT}" || true
EOF
}

status_remote() {
  ssh -o BatchMode=yes "${AGLSRV3_SSH}" \
    "systemctl is-active ${SERVICE_NAME} 2>/dev/null || echo inactive; ss -tlnp | grep ':${LISTEN_PORT}' || true"
}

case "${1:-}" in
  --install) install_remote ;;
  --status) status_remote ;;
  *)
    echo "Uso: $0 --install | --status"
    exit 1
    ;;
esac
