#!/usr/bin/env bash
# Gera token aglsrv5e via CT117 (AGLSRV1) e instala no CT575 cloudflared6.
set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
CT117=117
TUNNEL_ID="${AGLSRV5E_TUNNEL_ID:-863fd93d-73c5-4c3e-90b5-7cbd37643f70}"
VMID=575

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

log "Gerar token aglsrv5e no CT117"
TOKEN=$(ssh -o BatchMode=yes "${AGLSRV1}" "pct exec ${CT117} -- cloudflared tunnel token ${TUNNEL_ID}" | tr -d '\r\n')
if [[ ${#TOKEN} -lt 100 ]]; then
    echo "Erro: token inválido (len=${#TOKEN})" >&2
    exit 1
fi

log "Instalar token no CT575 (via pct mount)"
ssh -o BatchMode=yes "${FGSRV7}" bash -s <<REMOTE
set -euo pipefail
printf 'TUNNEL_TOKEN=%s\n' '${TOKEN}' > /tmp/cloudflared575.env
chmod 600 /tmp/cloudflared575.env
pct status ${VMID} | grep -qi running || pct start ${VMID}
sleep 2
pct mount ${VMID}
mnt="/var/lib/lxc/${VMID}/rootfs"
mkdir -p "\${mnt}/etc/default" "\${mnt}/etc/systemd/system"
install -m 600 /tmp/cloudflared575.env "\${mnt}/etc/default/cloudflared"
cat > "\${mnt}/etc/systemd/system/cloudflared.service" <<'UNIT'
[Unit]
Description=cloudflared tunnel aglsrv5e (FGSRV7)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/default/cloudflared
ExecStart=/usr/bin/cloudflared tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
chown 100000:100000 "\${mnt}/etc/default/cloudflared" "\${mnt}/etc/systemd/system/cloudflared.service"
pct unmount ${VMID}
pct exec ${VMID} -- systemctl daemon-reload
pct exec ${VMID} -- systemctl enable cloudflared
pct exec ${VMID} -- systemctl restart cloudflared
sleep 5
pct exec ${VMID} -- systemctl is-active cloudflared
pct exec ${VMID} -- journalctl -u cloudflared -n 3 --no-pager | grep -E 'Registered|ERR|invalid' || true
REMOTE

log "Concluído — validar: pct exec 575 -- journalctl -u cloudflared -n 5"
