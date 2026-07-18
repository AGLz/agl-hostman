#!/usr/bin/env bash
# Cold tier AGLSRV6 — histórico no USB exFAT (PBS sync nativo exige ext4/xfs/zfs).
#
# Modelo:
#   Hot  = PBS datastore backups (ZFS) — keep-last=1
#   Cold = vzdump → /mnt/usb4tb-direct/cold (exFAT) — retenção por guest
#
# Uso (host man6):
#   bash aglsrv6-usb-cold-export.sh [--apply] [--dry-run] [--include-weekly]
#
# Env:
#   AGLSRV6_USB_CAP_PCT (70)  AGLSRV6_USB_TARGET_PCT (65)
#   AGLSRV6_USB_KEEP_CT (7)   AGLSRV6_USB_KEEP_VM (2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
[[ -f "${SCRIPT_DIR}/aglsrv-vmid-map.env" ]] && source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

APPLY=false
DRY_RUN=false
INCLUDE_WEEKLY=false
USB_MOUNT="${AGLSRV6_USB_MOUNT:-/mnt/usb4tb-direct}"
COLD_DIR="${AGLSRV6_USB_COLD_DIR:-${USB_MOUNT}/cold}"
USB_CAP_PCT="${AGLSRV6_USB_CAP_PCT:-70}"
USB_TARGET_PCT="${AGLSRV6_USB_TARGET_PCT:-65}"
KEEP_CT="${AGLSRV6_USB_KEEP_CT:-7}"
KEEP_VM="${AGLSRV6_USB_KEEP_VM:-2}"

# Guests da política PBS (tiers) — CTs diários; VMs grandes só com --include-weekly
CTS_DAILY=(601 602 604 608 609 610 611 614 617 621)
VMS_WEEKLY=(620)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --include-weekly) INCLUDE_WEEKLY=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--apply] [--dry-run] [--include-weekly]"
      exit 0
      ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

usb_use_pct() {
  df -P "${USB_MOUNT}" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}' || echo 100
}

usb_probe() {
  [[ -d "${USB_MOUNT}" ]] || return 1
  local probe="${USB_MOUNT}/.agl-healthcheck"
  echo ok >"${probe}" 2>/dev/null && rm -f "${probe}"
}

prune_guest_cold() {
  local vmid="$1" keep="$2"
  shopt -s nullglob
  local files=()
  # vzdump-{qemu|lxc}-VMID-DATE.{zst,tar.zst,vma.zst,...} (+ .notes/.log opcional)
  mapfile -t files < <(ls -1t "${COLD_DIR}"/vzdump-*-"${vmid}"-*.{tar.zst,vma.zst,tar.gz,vma.gz,tar.lzo,vma.lzo,tgz} 2>/dev/null || true)
  local n=${#files[@]}
  local i
  for ((i=keep; i<n; i++)); do
    local f="${files[$i]}"
    log "Prune cold ${f}"
    if [[ "${APPLY}" == true && "${DRY_RUN}" != true ]]; then
      rm -f -- "${f}" "${f}.notes" "${f%.tar.zst}.log" "${f%.vma.zst}.log" 2>/dev/null || true
    fi
  done
}

prune_until_target() {
  local use
  use=$(usb_use_pct)
  while [[ "${use}" -gt "${USB_TARGET_PCT}" ]]; do
    log "USB ${use}% > alvo ${USB_TARGET_PCT}% — a podar cold mais antigo"
    if [[ "${APPLY}" != true || "${DRY_RUN}" == true ]]; then
      log "DRY-RUN: parar prune (cap)"
      return 0
    fi
    local oldest
    oldest=$(ls -1tr "${COLD_DIR}"/vzdump-* 2>/dev/null | head -1 || true)
    [[ -n "${oldest}" ]] || break
    rm -f -- "${oldest}" "${oldest}.notes" 2>/dev/null || true
    use=$(usb_use_pct)
  done
}

export_vmid() {
  local vmid="$1"
  local use
  use=$(usb_use_pct)
  if [[ "${use}" -ge "${USB_CAP_PCT}" ]]; then
    log "SKIP ${vmid} — USB ${use}% >= cap ${USB_CAP_PCT}%"
    prune_until_target
    use=$(usb_use_pct)
    [[ "${use}" -ge "${USB_CAP_PCT}" ]] && return 0
  fi

  log "Cold vzdump ${vmid} → ${COLD_DIR}"
  if [[ "${APPLY}" != true || "${DRY_RUN}" == true ]]; then
    log "DRY-RUN vzdump ${vmid}"
    return 0
  fi

  # --remove 0: retenção gerida por este script (não pelo vzdump)
  vzdump "${vmid}" \
    --dumpdir "${COLD_DIR}" \
    --mode snapshot \
    --compress zstd \
    --remove 0 \
    --quiet 0

  if [[ -f "/etc/pve/qemu-server/${vmid}.conf" ]]; then
    prune_guest_cold "${vmid}" "${KEEP_VM}"
  else
    prune_guest_cold "${vmid}" "${KEEP_CT}"
  fi
}

log "=== USB cold export (apply=${APPLY} weekly=${INCLUDE_WEEKLY} cap=${USB_CAP_PCT}%) ==="

mountpoint -q "${USB_MOUNT}" || die "USB ${USB_MOUNT} não montado"
usb_probe || die "USB ${USB_MOUNT} inacessível (I/O) — abortar"
mkdir -p "${COLD_DIR}"

use=$(usb_use_pct)
log "USB uso: ${use}%"
if [[ "${use}" -ge "${USB_CAP_PCT}" ]]; then
  prune_until_target
  use=$(usb_use_pct)
  [[ "${use}" -ge "${USB_CAP_PCT}" ]] && die "USB ainda >= ${USB_CAP_PCT}% — libertar espaço"
fi

for vmid in "${CTS_DAILY[@]}"; do
  if [[ -f "/etc/pve/lxc/${vmid}.conf" ]]; then
    export_vmid "${vmid}"
  else
    log "SKIP CT ${vmid} — conf ausente"
  fi
done

if [[ "${INCLUDE_WEEKLY}" == true ]]; then
  for vmid in "${VMS_WEEKLY[@]}"; do
    if [[ -f "/etc/pve/qemu-server/${vmid}.conf" ]]; then
      export_vmid "${vmid}"
    else
      log "SKIP VM ${vmid} — conf ausente"
    fi
  done
else
  log "VMs semanais (${VMS_WEEKLY[*]}) — omitidas (usar --include-weekly ou cron Domingo)"
fi

log "=== Concluído (USB $(usb_use_pct)%) ==="
ls -lah "${COLD_DIR}" 2>/dev/null | tail -20 || true
