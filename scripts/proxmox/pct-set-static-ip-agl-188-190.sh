#!/usr/bin/env bash
# Define IP estático LAN para CT188–191 (evita colisão DHCP com CT187).
# Executar no nó Proxmox AGLSRV1 como root.
#
# Uso: bash pct-set-static-ip-agl-188-190.sh [gateway]
# Ex.: GW=192.168.0.1 bash pct-set-static-ip-agl-188-190.sh

set -euo pipefail

GW="${1:-${GW:-192.168.0.1}}"

command -v pct >/dev/null || { echo "ERRO: executar no Proxmox" >&2; exit 1; }

declare -A IPS=(
  [188]="192.168.0.188/24"
  [189]="192.168.0.189/24"
  [190]="192.168.0.190/24"
  [191]="192.168.0.191/24"
)

for id in "${!IPS[@]}"; do
  pct set "${id}" -net0 "name=eth0,bridge=vmbr0,ip=${IPS[$id]},gw=${GW}"
  pct reboot "${id}" || pct start "${id}"
done

echo "OK: IPs estáticos aplicados (gw=${GW}). Aguardar ~10s e verificar com pct exec <id> -- ip -4 -br addr show eth0"
