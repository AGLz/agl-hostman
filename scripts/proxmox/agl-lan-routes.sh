#!/usr/bin/env bash
# CTs AGL na LAN local (188–191, etc.): garantir tráfego 192.168.0.0/24 via eth0.
#
# Documentação: docs/troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md
# Problema: com tailscale --accept-routes=true, peers (ex. man6d) injectam
#   192.168.0.0/24 dev tailscale0 na table 52 → LAN local inacessível.
# Solução primária: accept-routes=false (ver docs/troubleshooting/CT181-DNS-ROUTING-FIX.md)
# Fallback: se a subnet LAN ainda aparecer via tailscale0 na table 52, forçar eth0.
#
# Uso no CT: agl-lan-routes.sh
# Env: LAN_IF=eth0  AGL_LAN_CIDR=192.168.0.0/24  AGL_LAN_ROUTE_IPS="ip1 ip2"

set -euo pipefail

LAN_IF="${LAN_IF:-eth0}"
AGL_LAN_CIDR="${AGL_LAN_CIDR:-192.168.0.0/24}"

if command -v tailscale >/dev/null 2>&1; then
  tailscale set --accept-routes=false 2>/dev/null || true
fi

if ip route show table 52 2>/dev/null | grep -qE "${AGL_LAN_CIDR//./\\.}.*tailscale0"; then
  ip route replace "${AGL_LAN_CIDR}" dev "${LAN_IF}" table 52
fi

if [[ -n "${AGL_LAN_ROUTE_IPS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=(${AGL_LAN_ROUTE_IPS})
elif [[ -f /etc/agl-lan-routes.conf ]]; then
  # shellcheck disable=SC2207
  mapfile -t extra < <(grep -vE '^\s*(#|$)' /etc/agl-lan-routes.conf)
else
  extra=(
    192.168.0.1    # gateway
    192.168.0.102  # Pi-hole CT102
    192.168.0.186  # LiteLLM CT186
    192.168.0.192  # Honcho CT192
  )
fi

for ip in "${extra[@]}"; do
  [[ -n "${ip}" ]] || continue
  # Se o IP já é alcançável noutra interface (ex. eth2 em 192.168.1.0/24), não forçar eth0 na table 52.
  main_dev="$(ip -4 route get "${ip}" 2>/dev/null | awk '/ dev / { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
  if [[ -n "${main_dev}" && "${main_dev}" != "${LAN_IF}" ]]; then
    ip route del "${ip}" table 52 2>/dev/null || true
    continue
  fi
  ip route replace "${ip}" dev "${LAN_IF}" table 52 2>/dev/null || true
done
