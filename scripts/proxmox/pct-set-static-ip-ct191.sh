#!/usr/bin/env bash
# IP estático 192.168.0.191 para CT191 (agl-gstack).
set -euo pipefail

GW="${1:-${GW:-192.168.0.1}}"
ID="${CT_GSTACK_VMID:-191}"

command -v pct >/dev/null || { echo "ERRO: executar no Proxmox" >&2; exit 1; }

pct set "${ID}" -net0 "name=eth0,bridge=vmbr0,ip=192.168.0.191/24,gw=${GW}"
pct reboot "${ID}" || pct start "${ID}"

echo "OK: CT${ID} → 192.168.0.191/24 (gw=${GW})"
