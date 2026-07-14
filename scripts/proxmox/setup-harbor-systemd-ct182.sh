#!/usr/bin/env bash
# Instala unit systemd no CT182 para garantir Harbor compose após boot/rearranque Docker.
#
# Uso (rede AGL):
#   bash scripts/proxmox/setup-harbor-systemd-ct182.sh
set -euo pipefail

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT182_VMID="${CT182_VMID:-182}"
HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"

log() { printf '[setup-harbor-systemd] %s\n' "$*"; }

ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct exec ${CT182_VMID} -- bash -s" <<REMOTE
set -euo pipefail
cat > /etc/systemd/system/harbor.service <<UNIT
[Unit]
Description=Harbor container registry (compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${HARBOR_DIR}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose stop
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable harbor.service
systemctl start harbor.service
docker compose -f ${HARBOR_DIR}/docker-compose.yml ps --format 'table {{.Name}}\t{{.Status}}'
REMOTE

log "OK: harbor.service enabled no CT${CT182_VMID}"
