#!/usr/bin/env bash
# Política PBS-only AGLSRV6 (man6):
#   Hot:  vzdump → man6-pbs (ZFS backups) + prune keep-last=1
#   Cold: aglsrv6-usb-cold-export.sh → /mnt/usb4tb-direct/cold (exFAT)
#   PBS sync nativo hot→usb4tb-direct NÃO — exFAT não serve de datastore PBS
#
# Uso:
#   bash aglsrv6-pbs-policy-apply.sh [--apply] [--remote] [--force-usb-sync]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

APPLY=false
REMOTE=false
FORCE_USB_SYNC=false

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --remote) REMOTE=true; shift ;;
    --force-usb-sync) FORCE_USB_SYNC=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--apply] [--remote] [--force-usb-sync]"
      exit 0
      ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

run_policy() {
  local PBS_VMID=613
  local HOT_STORE=backups
  local COLD_STORE=usb4tb-direct
  local PVE_PBS_STORAGE=man6-pbs

  upsert_job() {
    local id="$1" comment="$2" schedule="$3" vmids="$4" workers="$5" enabled="${6:-1}"
    if [[ "${APPLY}" != true ]]; then
      log "DRY-RUN ${id} → ${PVE_PBS_STORAGE} vmid=${vmids} enabled=${enabled}"
      return 0
    fi
    if pvesh get "/cluster/backup/${id}" &>/dev/null; then
      pvesh set "/cluster/backup/${id}" \
        --comment "${comment}" \
        --storage "${PVE_PBS_STORAGE}" \
        --vmid "${vmids}" \
        --schedule "${schedule}" \
        --enabled "${enabled}" \
        --node man6 \
        --mailnotification always \
        --mode snapshot \
        --performance "max-workers=${workers}" \
        --prune-backups 'keep-last=1'
    else
      pvesh create /cluster/backup \
        --id "${id}" \
        --comment "${comment}" \
        --storage "${PVE_PBS_STORAGE}" \
        --vmid "${vmids}" \
        --schedule "${schedule}" \
        --enabled "${enabled}" \
        --node man6 \
        --mailnotification always \
        --mode snapshot \
        --performance "max-workers=${workers}" \
        --prune-backups 'keep-last=1'
    fi
    log "Job ${id} → ${PVE_PBS_STORAGE}"
  }

  disable_job() {
    local jid="$1"
    if [[ "${APPLY}" == true ]]; then
      pvesh set "/cluster/backup/${jid}" --enabled 0 2>/dev/null || true
    else
      log "DRY-RUN disable ${jid}"
    fi
  }

  pbs_exec() { pct exec "${PBS_VMID}" -- "$@"; }

  usb_healthy() {
    mountpoint -q /mnt/usb4tb-direct || return 1
    local probe=/mnt/usb4tb-direct/.agl-healthcheck
    echo ok >"${probe}" 2>/dev/null && rm -f "${probe}"
  }

  usb_is_ext4() {
    findmnt -no FSTYPE /mnt/usb4tb-direct 2>/dev/null | grep -qx ext4
  }

  ensure_cold_cron() {
    local cron=/etc/cron.d/aglsrv6-usb-cold-export
    local script=/root/aglsrv6-usb-cold-export.sh
    if [[ ! -x "${script}" ]]; then
      log "AVISO: ${script} ausente — copiar aglsrv6-usb-cold-export.sh para /root"
      return 0
    fi
    cat >"${cron}" <<'EOF'
# Cold USB AGLSRV6 — após backups PBS; antes do prune hot 08:00
0 7 * * * root /root/aglsrv6-usb-cold-export.sh --apply >> /var/log/aglsrv6-usb-cold-export.log 2>&1
30 7 * * 0 root /root/aglsrv6-usb-cold-export.sh --apply --include-weekly >> /var/log/aglsrv6-usb-cold-export.log 2>&1
EOF
    rm -f "${cron}.disabled"
    log "Cron cold-export: diário 07:00 + Domingo 07:30 (VM620)"
  }

  log "=== AGLSRV6 PBS-only policy (apply=${APPLY}) ==="

  upsert_job "backup-vm620-production" "VM620 Production - PBS" "02:00" "620" 4 1
  # Schedules desfasados; 605 fora do auto
  upsert_job "backup-pbs-tier1-sql-6h" "PBS-Tier1-SQL-6h" "0,6,12,18" "610,620" 2 1
  upsert_job "backup-pbs-tier2-infra-12h" "PBS-Tier2-Infra-12h" "3,15" "601,602,609,614,617,621" 3 1
  upsert_job "backup-pbs-tier3-daily" "PBS-Tier3-Daily" "05:00" "604,608,611" 4 1

  for jid in backup-197c33fb-3f3e backup-f6f377ec-857a backup-44340b80-f7e5 \
    backup-14eaa1e1-8aef backup-4487932b-284a backup-d129d288-6fc2 \
    backup-vm100-rpool-fleecing backup-vm100-bb backup-vm100-optimized; do
    disable_job "${jid}"
  done

  if [[ "${APPLY}" != true ]]; then
    log "DRY-RUN PBS prune + cold cron (sem sync PBS→exFAT)"
    log "=== Fim dry-run ==="
    return 0
  fi

  local usb_ok=0
  if usb_healthy; then usb_ok=1; else log "AVISO: USB /mnt/usb4tb-direct inacessível"; fi

  local hot_keep=1
  if [[ "${usb_ok}" != 1 ]]; then
    hot_keep=2
    log "AVISO: USB cold OFF — hot keep-last=2 até USB voltar"
  fi

  if pbs_exec proxmox-backup-manager prune-job show prune-hot-backups &>/dev/null; then
    pbs_exec proxmox-backup-manager prune-job update prune-hot-backups \
      --schedule "08:00" --store "${HOT_STORE}" \
      --keep-last "${hot_keep}" \
      --delete keep-daily --delete keep-hourly --delete keep-weekly \
      --delete keep-monthly --delete keep-yearly \
      --comment "Hot tier ZFS — ${hot_keep} snapshot(s) por guest (cold=USB exFAT export)"
  else
    pbs_exec proxmox-backup-manager prune-job create prune-hot-backups \
      --schedule "08:00" --store "${HOT_STORE}" \
      --keep-last "${hot_keep}" \
      --comment "Hot tier ZFS — ${hot_keep} snapshot(s) por guest (cold=USB exFAT export)"
  fi
  log "Prune hot: keep-last=${hot_keep} @ 08:00 (sem keep-daily)"

  if pbs_exec proxmox-backup-manager prune-job show prune-cold-usb &>/dev/null; then
    pbs_exec proxmox-backup-manager prune-job update prune-cold-usb --disable 1 \
      --comment "Desactivado — cold real é /mnt/usb4tb-direct/cold (exFAT vzdump)"
  fi

  if pbs_exec proxmox-backup-manager sync-job show sync-hot-to-cold &>/dev/null; then
    pbs_exec proxmox-backup-manager sync-job update sync-hot-to-cold --delete schedule 2>/dev/null || true
    log "Sync PBS hot→cold DESACTIVADO (exFAT; usar cold-export)"
  fi

  if [[ "${FORCE_USB_SYNC}" == true ]]; then
    if usb_is_ext4; then
      log "FORCE: USB ext4 — activar sync PBS (repoint datastore manual)"
      pbs_exec proxmox-backup-manager sync-job update sync-hot-to-cold \
        --schedule "06:30" --sync-direction push 2>/dev/null || true
      pbs_exec proxmox-backup-manager prune-job update prune-cold-usb --disable 0 2>/dev/null || true
    else
      log "FORCE ignorado: USB não é ext4 ($(findmnt -no FSTYPE /mnt/usb4tb-direct 2>/dev/null || echo absent))"
    fi
  fi

  if [[ "${usb_ok}" == 1 ]]; then
    ensure_cold_cron
  else
    [[ -f /etc/cron.d/aglsrv6-usb-cold-export ]] && \
      mv -f /etc/cron.d/aglsrv6-usb-cold-export /etc/cron.d/aglsrv6-usb-cold-export.disabled
    log "Cron cold-export desactivado (USB off)"
  fi

  log "=== Concluído ==="
}

if [[ "${REMOTE}" == true ]]; then
  log "Remoto ${AGLSRV6_SSH}"
  scp -q "${SCRIPT_DIR}/aglsrv6-pbs-policy-apply.sh" \
    "${SCRIPT_DIR}/aglsrv6-usb-cold-export.sh" \
    "${SCRIPT_DIR}/aglsrv-vmid-map.env" \
    "${AGLSRV6_SSH}:/root/"
  ssh -o ConnectTimeout=120 "${AGLSRV6_SSH}" "chmod 755 /root/aglsrv6-usb-cold-export.sh /root/aglsrv6-pbs-policy-apply.sh"
  local_flag=""
  [[ "${APPLY}" == true ]] && local_flag="--apply"
  force_flag=""
  [[ "${FORCE_USB_SYNC}" == true ]] && force_flag="--force-usb-sync"
  ssh -o ConnectTimeout=120 "${AGLSRV6_SSH}" "bash /root/aglsrv6-pbs-policy-apply.sh ${local_flag} ${force_flag}"
else
  run_policy
fi
