#!/usr/bin/env bash
# Instala agl-lan-routes.service nos CTs agency (188–191 por defeito).
#
# Uso no AGLSRV1:
#   bash scripts/proxmox/pct-install-agl-lan-routes.sh
#   bash scripts/proxmox/pct-install-agl-lan-routes.sh 188 189

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${REPO_ROOT}/scripts/proxmox/agl-lan-routes.sh"
VMIDS=("$@")
if [[ ${#VMIDS[@]} -eq 0 ]]; then
  VMIDS=(188 189 190 191)
fi

command -v pct >/dev/null || {
  echo "ERRO: executar no Proxmox AGLSRV1." >&2
  exit 1
}

[[ -f "${SRC}" ]] || {
  echo "ERRO: ${SRC} não encontrado." >&2
  exit 1
}

for vmid in "${VMIDS[@]}"; do
  echo "=== CT${vmid}: agl-lan-routes ==="
  pct status "${vmid}" 2>/dev/null | grep -q running || {
    echo "  SKIP: CT não running"
    continue
  }
  pct push "${vmid}" "${SRC}" /usr/local/sbin/agl-lan-routes.sh
  pct exec "${vmid}" -- chmod 0755 /usr/local/sbin/agl-lan-routes.sh
  pct exec "${vmid}" -- bash -c 'cat >/etc/systemd/system/agl-lan-routes.service <<'\''UNIT'\''
[Unit]
Description=AGL LAN routes (Tailscale table 52 → eth0)
After=tailscaled.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/agl-lan-routes.sh

[Install]
WantedBy=multi-user.target
UNIT'
  pct exec "${vmid}" -- systemctl daemon-reload
  pct exec "${vmid}" -- systemctl enable --now agl-lan-routes.service
  pct exec "${vmid}" -- /usr/local/sbin/agl-lan-routes.sh
  echo "  OK"
done

echo ""
echo "Verificar: pct exec 188 -- tailscale debug prefs | grep RouteAll"
echo "           pct exec 188 -- curl -sf http://192.168.0.186:4000/health/liveliness"
