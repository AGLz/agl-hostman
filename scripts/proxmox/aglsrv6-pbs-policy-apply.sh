#!/usr/bin/env bash
# Política PBS-only AGLSRV6 (man6):
#   vzdump → man6-pbs (datastore backups / ZFS)
#   prune hot: keep-last=1 (1x no ZFS/rpool)
#   prune cold + sync push → usb4tb-direct (activado só se USB saudável)
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
    pct status "${PBS_VMID}" 2>/dev/null | grep -q running || return 1
    pbs_exec ls /mnt/usb4tb-direct/ &>/dev/null
  }

  log "=== AGLSRV6 PBS-only policy (apply=${APPLY}) ==="

  upsert_job "backup-vm620-production" "VM620 Production - PBS" "02:00" "620" 4 1
  upsert_job "backup-pbs-tier1-sql-6h" "PBS-Tier1-SQL-6h" "*/6" "610,620" 2 1
  upsert_job "backup-pbs-tier2-infra-12h" "PBS-Tier2-Infra-12h" "2,14" "601,602,609,614,617,621" 3 1
  upsert_job "backup-pbs-tier3-daily" "PBS-Tier3-Daily" "04:00" "604,605,608,611" 4 1

  for jid in backup-197c33fb-3f3e backup-f6f377ec-857a backup-44340b80-f7e5 \
    backup-14eaa1e1-8aef backup-4487932b-284a backup-d129d288-6fc2 \
    backup-vm100-rpool-fleecing backup-vm100-bb backup-vm100-optimized; do
    disable_job "${jid}"
  done

  if [[ "${APPLY}" != true ]]; then
    log "DRY-RUN PBS prune/sync no CT${PBS_VMID}"
    log "=== Fim dry-run ==="
    return 0
  fi

  local usb_ok=0
  if usb_healthy; then usb_ok=1; else log "AVISO: USB /mnt/usb4tb-direct com I/O errors ou inacessível"; fi
  [[ "${FORCE_USB_SYNC}" == true ]] && usb_ok=1

  local hot_keep=1
  if [[ "${usb_ok}" != 1 ]]; then
    hot_keep=2
    log "AVISO: sync cold OFF — hot keep-last=2 até USB ext4 (evita perder histórico sem cold)"
  fi

  if pbs_exec proxmox-backup-manager prune-job show prune-hot-backups &>/dev/null; then
    pbs_exec proxmox-backup-manager prune-job update prune-hot-backups \
      --schedule "08:00" --store "${HOT_STORE}" \
      --keep-last "${hot_keep}" \
      --comment "Hot tier ZFS — ${hot_keep} snapshot(s) por guest"
  else
    pbs_exec proxmox-backup-manager prune-job create prune-hot-backups \
      --schedule "08:00" --store "${HOT_STORE}" \
      --keep-last "${hot_keep}" \
      --comment "Hot tier ZFS — ${hot_keep} snapshot(s) por guest"
  fi
  log "Prune hot: keep-last=${hot_keep} @ 08:00"

  if pbs_exec proxmox-backup-manager prune-job show prune-cold-usb &>/dev/null; then
    pbs_exec proxmox-backup-manager prune-job update prune-cold-usb \
      --schedule weekly --store "${COLD_STORE}" \
      --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 1 \
      --comment "Cold tier — retenção longa pós-sync"
  else
    pbs_exec proxmox-backup-manager prune-job create prune-cold-usb \
      --schedule weekly --store "${COLD_STORE}" \
      --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 1 \
      --comment "Cold tier — retenção longa pós-sync"
  fi

  local fp pass
  fp=$(pbs_exec proxmox-backup-manager cert info 2>/dev/null | awk -F': ' '/Fingerprint \(sha256\)/ {print $2; exit}')
  pass=$(cat /root/.pbs-link-password 2>/dev/null || true)

  if [[ -n "${fp}" && -n "${pass}" ]]; then
    if ! pbs_exec proxmox-backup-manager remote show local-push &>/dev/null; then
      pbs_exec proxmox-backup-manager remote create local-push \
        --host 127.0.0.1 --port 8007 --auth-id root@pam \
        --password "${pass}" --fingerprint "${fp}" \
        --comment "Loopback sync hot→cold"
    fi

    if pbs_exec proxmox-backup-manager sync-job show sync-hot-to-cold &>/dev/null; then
      pbs_exec proxmox-backup-manager sync-job update sync-hot-to-cold \
        --store "${HOT_STORE}" --remote local-push --remote-store "${COLD_STORE}" \
        --schedule "06:30" --sync-direction push \
        --comment "Push hot ZFS → cold tier"
    else
      pbs_exec proxmox-backup-manager sync-job create sync-hot-to-cold \
        --store "${HOT_STORE}" --remote local-push --remote-store "${COLD_STORE}" \
        --schedule "06:30" --sync-direction push \
        --comment "Push hot ZFS → cold tier"
    fi

    if [[ "${usb_ok}" == 1 ]]; then
      pbs_exec proxmox-backup-manager sync-job update sync-hot-to-cold \
        --schedule "06:30" --sync-direction push
      pbs_exec proxmox-backup-manager prune-job update prune-cold-usb --disable 0
      log "Sync hot→cold ACTIVADO (schedule 06:30)"
    else
      pbs_exec proxmox-backup-manager sync-job update sync-hot-to-cold --delete schedule 2>/dev/null || true
      pbs_exec proxmox-backup-manager prune-job update prune-cold-usb --disable 1
      log "Sync hot→cold DESACTIVADO (USB degradado — corrigir hardware antes)"
    fi
  else
    log "AVISO: fingerprint/password PBS em falta — prune hot OK, sync ignorado"
  fi

  log "=== Concluído ==="
}

if [[ "${REMOTE}" == true ]]; then
  log "Remoto ${AGLSRV6_SSH}"
  scp -q "${SCRIPT_DIR}/aglsrv6-pbs-policy-apply.sh" "${SCRIPT_DIR}/aglsrv-vmid-map.env" "${AGLSRV6_SSH}:/root/"
  local_flag=""
  [[ "${APPLY}" == true ]] && local_flag="--apply"
  force_flag=""
  [[ "${FORCE_USB_SYNC}" == true ]] && force_flag="--force-usb-sync"
  ssh -o ConnectTimeout=120 "${AGLSRV6_SSH}" "bash /root/aglsrv6-pbs-policy-apply.sh ${local_flag} ${force_flag}"
else
  run_policy
fi
