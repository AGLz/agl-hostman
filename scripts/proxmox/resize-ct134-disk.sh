#!/usr/bin/env bash
# Redimensiona rootfs do CT134 (agl-hostman prod) no AGLSRV1.
#
# Uso:
#   bash scripts/proxmox/resize-ct134-disk.sh              # +64G (default)
#   ADD_GB=32 bash scripts/proxmox/resize-ct134-disk.sh    # incremento custom
#   TARGET_GB=128 bash scripts/proxmox/resize-ct134-disk.sh # tamanho alvo absoluto
set -euo pipefail

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"
ADD_GB="${ADD_GB:-64}"
TARGET_GB="${TARGET_GB:-}"

log() { printf '[resize-ct134] %s\n' "$*"; }

current_cfg="$(ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct config ${CT134_VMID} | awk -F'[=,]' '/^rootfs:/ {print \$3}'")"
current_gb="${current_cfg%G}"

if [[ -z "${current_gb}" || ! "${current_gb}" =~ ^[0-9]+$ ]]; then
  echo "Erro: não foi possível ler tamanho actual do CT${CT134_VMID}" >&2
  exit 1
fi

if [[ -n "${TARGET_GB}" ]]; then
  if (( TARGET_GB <= current_gb )); then
    log "CT${CT134_VMID} já tem ${current_gb}G (alvo ${TARGET_GB}G) — nada a fazer."
    exit 0
  fi
  delta=$((TARGET_GB - current_gb))
else
  delta="${ADD_GB}"
fi

log "CT${CT134_VMID}: ${current_gb}G → +${delta}G"
ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct resize ${CT134_VMID} rootfs +${delta}G"

new_cfg="$(ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct config ${CT134_VMID} | awk -F'[=,]' '/^rootfs:/ {print \$3}'")"
ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct exec ${CT134_VMID} -- df -h /"
log "OK: rootfs Proxmox=${new_cfg}"
