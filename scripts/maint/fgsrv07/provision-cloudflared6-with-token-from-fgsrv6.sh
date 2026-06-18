#!/usr/bin/env bash
# Obtém CLOUDFLARE_TUNNEL_TOKEN do FGSRV6 e configura CT575 (túnel aglsrv5e).
# Usa `cloudflared tunnel run` + EnvironmentFile (igual Docker FGSRV6).
# Nota: se o token no FGSRV6 estiver revogado, regenerar em Zero Trust antes do cutover.
set -euo pipefail

FGSRV6="${FGSRV6:-root@100.83.51.9}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
ENV_TMP="/tmp/cf-tunnel-aglsrv5e.env"

if ssh -o BatchMode=yes "${FGSRV7}" 'pct status 575 2>/dev/null | grep -qi running && [[ "$(pct exec 575 -- systemctl is-active cloudflared 2>/dev/null)" == "active" ]]'; then
    echo "CT575 cloudflared já activo — skip"
    exit 0
fi

ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${FGSRV6}" \
    'grep -E "^CLOUDFLARE_TUNNEL_TOKEN=" /opt/docker/cloudflared/.env' > "${ENV_TMP}"
if [[ ! -s "${ENV_TMP}" ]]; then
    echo "Erro: token não encontrado em ${FGSRV6}" >&2
    exit 1
fi

scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${ENV_TMP}" "${FGSRV7}:/root/cf-tunnel-aglsrv5e.env"
rm -f "${ENV_TMP}"

ssh -o BatchMode=yes "${FGSRV7}" bash -s <<'REMOTE'
set -euo pipefail
pct status 575 | grep -qi running || pct start 575
sleep 3

python3 - <<'PY'
from pathlib import Path
src = Path("/root/cf-tunnel-aglsrv5e.env")
dst = Path("/tmp/cloudflared575.env")
for line in src.read_text().splitlines():
    if line.startswith("CLOUDFLARE_TUNNEL_TOKEN="):
        token = line.split("=", 1)[1].strip().strip('"').strip("'")
        dst.write_text(f"TUNNEL_TOKEN={token}\n")
        break
else:
    raise SystemExit("CLOUDFLARE_TUNNEL_TOKEN ausente")
PY
chmod 600 /tmp/cloudflared575.env

pct mount 575
mnt="/var/lib/lxc/575/rootfs"
mkdir -p "${mnt}/etc/default" "${mnt}/etc/systemd/system"
install -m 600 /tmp/cloudflared575.env "${mnt}/etc/default/cloudflared"
cat > "${mnt}/etc/systemd/system/cloudflared.service" <<'UNIT'
[Unit]
Description=cloudflared tunnel aglsrv5e (migrado FGSRV6)
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
chown 100000:100000 "${mnt}/etc/default/cloudflared" "${mnt}/etc/systemd/system/cloudflared.service"
pct unmount 575

pct exec 575 -- systemctl daemon-reload
pct exec 575 -- systemctl enable cloudflared
pct exec 575 -- systemctl restart cloudflared
sleep 3
pct exec 575 -- systemctl is-active cloudflared || {
  pct exec 575 -- journalctl -u cloudflared -n 5 --no-pager
  exit 1
}
REMOTE
