#!/usr/bin/env bash
# Garante que o Pi-hole LAN (192.168.0.102) usa eth0 e não tailscale0 (table 52).
# Necessário em LXC com Tailscale + accept-routes quando o DNS LAN está no mesmo /24 anunciado.
#
# Uso dentro do CT (root):
#   bash pihole-lan-route-fix.sh
#   bash pihole-lan-route-fix.sh --install   # systemd oneshot + path unit
#
set -euo pipefail

PIHOLE_IP="${PIHOLE_IP:-192.168.0.102}"
LAN_DEV="${LAN_DEV:-eth0}"
TS_TABLE="${TS_TABLE:-52}"

apply_route() {
  if ! ip link show "${LAN_DEV}" >/dev/null 2>&1; then
    echo "ERRO: interface ${LAN_DEV} inexistente" >&2
    return 1
  fi
  ip route replace "${PIHOLE_IP}/32" dev "${LAN_DEV}" table "${TS_TABLE}" 2>/dev/null \
    || ip route replace "${PIHOLE_IP}/32" dev "${LAN_DEV}"
  echo "Rota: $(ip route get "${PIHOLE_IP}" | head -1)"
}

install_systemd() {
  local script_path="/usr/local/sbin/pihole-lan-route-fix.sh"
  install -m 0755 "$0" "${script_path}"
  cat > /etc/systemd/system/pihole-lan-route-fix.service <<UNIT
[Unit]
Description=Rota LAN directa para Pi-hole (evita hijack Tailscale table ${TS_TABLE})
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${script_path}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now pihole-lan-route-fix.service
  systemctl is-active pihole-lan-route-fix.service
}

case "${1:-}" in
  --install) apply_route; install_systemd ;;
  *) apply_route ;;
esac
