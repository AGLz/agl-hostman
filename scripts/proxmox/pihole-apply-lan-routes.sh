#!/usr/bin/env bash
# Aplica rota LAN para Pi-hole em LXC onde Tailscale table 52 desvia 192.168.0.102.
# Correr no AGLSRV1 após tailscaled arrancar nos CTs.
#
# Uso: bash pihole-apply-lan-routes.sh
#
set -euo pipefail

PIHOLE_IP="${PIHOLE_IP:-192.168.0.102}"
LAN_DEV="${LAN_DEV:-eth0}"
TS_TABLE="${TS_TABLE:-52}"
FIX_SCRIPT="/usr/local/sbin/pihole-lan-route-fix.sh"
LOCAL_FIX="${0%/*}/pihole-lan-route-fix.sh"

command -v pct >/dev/null || { echo "ERRO: executar no AGLSRV1." >&2; exit 1; }

for conf in /etc/pve/lxc/*.conf; do
  vmid=$(basename "${conf}" .conf)
  [[ "${vmid}" == "102" ]] && continue
  pct status "${vmid}" 2>/dev/null | grep -q running || continue
  pct exec "${vmid}" -- sh -c "command -v tailscale >/dev/null" 2>/dev/null || continue

  route=$(pct exec "${vmid}" -- ip route get "${PIHOLE_IP}" 2>/dev/null | head -1 || true)
  if echo "${route}" | grep -qE "dev (${LAN_DEV}|lo)"; then
    continue
  fi

  echo "CT${vmid}: corrigir rota Pi-hole (${route})"
  pct push "${vmid}" "${LOCAL_FIX}" /tmp/pihole-lan-route-fix.sh
  pct exec "${vmid}" -- bash /tmp/pihole-lan-route-fix.sh --install
done

echo "=== Verificação ==="
for conf in /etc/pve/lxc/*.conf; do
  vmid=$(basename "${conf}" .conf)
  pct status "${vmid}" 2>/dev/null | grep -q running || continue
  pct exec "${vmid}" -- sh -c "command -v tailscale >/dev/null" 2>/dev/null || continue
  echo -n "CT${vmid}: "
  pct exec "${vmid}" -- ip route get "${PIHOLE_IP}" 2>/dev/null | head -1
done
