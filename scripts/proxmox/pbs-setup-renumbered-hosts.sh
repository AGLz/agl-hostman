#!/usr/bin/env bash
# pbs-link + jobs vzdump nos hosts já renumerados (SRV3, SRV5, FGSRV7, SRV6).
#
# Uso local (no host Proxmox):
#   bash pbs-setup-renumbered-hosts.sh --host aglsrv5 [--apply]
#   bash pbs-setup-renumbered-hosts.sh --host fgsrv7 [--apply]
#   bash pbs-setup-renumbered-hosts.sh --host aglsrv6 [--apply]
#
# Remoto (agldv03):
#   bash pbs-setup-renumbered-hosts.sh --host all --apply --remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

APPLY=false
REMOTE=false
HOST=""

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

strip_cidr() { echo "${1%%/*}"; }

usage() {
  cat <<EOF
Uso: $0 --host aglsrv3|aglsrv5|fgsrv7|aglsrv6|all [--apply] [--remote]

  --apply   Executa alterações (default: dry-run nos jobs; pbs-link sempre apply se remoto)
  --remote  SSH para o host Tailscale definido em aglsrv-vmid-map.env
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --apply) APPLY=true; shift ;;
    --remote) REMOTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

[[ -n "${HOST}" ]] || die "Indicar --host"

run_on() {
  local ssh_target="$1"
  shift
  if [[ "${REMOTE}" == true ]]; then
    ssh -o ConnectTimeout=20 "${ssh_target}" "$@"
  else
    bash -c "$*"
  fi
}

# Restringe storages pbs-* partilhados no cluster ao nó FGSRV7 (server 191.252.93.245).
fix_cluster_pbs_nodes_fgsrv7() {
  log "Cluster: marcar pbs-* existentes com nodes=fgsrv7"
  for sid in $(pvesm status 2>/dev/null | awk '/^pbs-/ && $2=="pbs" {print $1}'); do
    if grep -A20 "^pbs: ${sid}$" /etc/pve/storage.cfg | grep -q '^nodes '; then
      log "  ${sid}: nodes já definido"
    else
      pvesm set "${sid}" --nodes fgsrv7 2>/dev/null && log "  ${sid}: nodes=fgsrv7" || log "  AVISO: pvesm set ${sid}"
    fi
  done
}

apply_pbs_link() {
  local pbs_vmid="$1" pbs_ip="$2" pbs_root="$3" pbs_nodes="${4:-}" pbs_prefix="${5:-pbs-}"

  export PBS_VMID="${pbs_vmid}"
  export PBS_IP="$(strip_cidr "${pbs_ip}")"
  export PBS_STORES_ROOT="${pbs_root}"
  export PBS_NODES="${pbs_nodes}"
  export PBS_ID_PREFIX="${pbs_prefix}"
  export DRY_RUN=false

  bash "${SCRIPT_DIR}/pbs-link-host-storages.sh"
}

# Actualiza ou cria job vzdump via pvesh
upsert_backup_job() {
  local job_id="$1" comment="$2" node="$3" storage="$4" schedule="$5" vmids="$6" enabled="${7:-1}"

  if pvesh get "/cluster/backup/${job_id}" &>/dev/null; then
    log "Job ${job_id}: actualizar vmid/storage"
    pvesh set "/cluster/backup/${job_id}" \
      --comment "${comment}" \
      --storage "${storage}" \
      --vmid "${vmids}" \
      --schedule "${schedule}" \
      --enabled "${enabled}" \
      --node "${node}" \
      --mailnotification always \
      --mode snapshot \
      --prune-backups 'keep-daily=7,keep-weekly=4,keep-monthly=3,keep-yearly=1'
  else
    log "Job ${job_id}: criar"
    pvesh create /cluster/backup \
      --id "${job_id}" \
      --comment "${comment}" \
      --storage "${storage}" \
      --vmid "${vmids}" \
      --schedule "${schedule}" \
      --enabled "${enabled}" \
      --node "${node}" \
      --mailnotification always \
      --mode snapshot \
      --prune-backups 'keep-daily=7,keep-weekly=4,keep-monthly=3,keep-yearly=1'
  fi
}

setup_aglsrv5() {
  fix_cluster_pbs_nodes_fgsrv7
  apply_pbs_link "${AGLSRV5_PBS_VMID}" "${AGLSRV5_PBS_IP}" "${AGLSRV5_PBS_BACKUP_ROOT}" "aglsrv5" "pbs5-"

  # CTs 530-539 + VMs 528,531 (excl. 540 PBS, 127 passthrough manual)
  local vmids="528,531,530,532,533,534,535,536,538,539"
  if [[ "${APPLY}" == true ]]; then
    upsert_backup_job "backup-aglsrv5-pbs-daily" "AGLSRV5 daily PBS (renumbered)" "aglsrv5" "pbs5-bkp" "04:30" "${vmids}" 1
    # Desactivar job legado com IDs antigos
    pvesh set /cluster/backup/backup-72234aa3-0a0b --enabled 0 2>/dev/null || true
  else
    log "DRY-RUN aglsrv5 job vmid=${vmids} storage=pbs5-bkp"
  fi
}

setup_fgsrv7() {
  fix_cluster_pbs_nodes_fgsrv7
  apply_pbs_link "${FGSRV7_PBS_VMID}" "${FGSRV7_PBS_IP}" "${FGSRV7_PBS_BACKUP_ROOT}" "fgsrv7" "pbs-"

  local vmids="546,547,548,549,550,561,562,570,571"
  if [[ "${APPLY}" == true ]]; then
    upsert_backup_job "backup-fgsrv7-pbs-daily" "FGSRV7 daily PBS (renumbered)" "fgsrv7" "pbs-bkp" "05:00" "${vmids}" 1
    pvesh set /cluster/backup/backup-72234aa3-0a0b --enabled 0 2>/dev/null || true
  else
    log "DRY-RUN fgsrv7 job vmid=${vmids} storage=pbs-bkp"
  fi
}

setup_aglsrv6() {
  apply_pbs_link "${AGLSRV6_PBS_VMID}" "${AGLSRV6_PBS_IP}" "${AGLSRV6_PBS_BACKUP_ROOT}" "man6" "pbs-"

  if [[ "${APPLY}" == true ]]; then
    # Tier jobs — VMIDs pós-renumber (excl. 613 PBS, 107 kuber601 legacy, 616 wgtest-priv)
    upsert_backup_job "backup-pbs-tier1-sql-6h" "PBS-Tier1-SQL-6h" "man6" "man6-pbs" "*/6" "610,620" 1
    upsert_backup_job "backup-pbs-tier2-infra-12h" "PBS-Tier2-Infra-12h" "man6" "man6-pbs" "2,14" "601,602,609,614" 1
    upsert_backup_job "backup-pbs-tier3-daily" "PBS-Tier3-Daily" "man6" "man6-pbs" "04:00" "604,603,611,608,612,600,606" 1
    upsert_backup_job "backup-vm200-production" "VM620 Production - PBS" "man6" "man6-pbs" "02:00" "620" 1
    # Desactivar jobs USB/legado com IDs antigos
    for jid in backup-197c33fb-3f3e backup-f6f377ec-857a backup-44340b80-f7e5 backup-14eaa1e1-8aef backup-4487932b-284a backup-d129d288-6fc2; do
      pvesh set "/cluster/backup/${jid}" --enabled 0 2>/dev/null || true
    done
  else
    log "DRY-RUN aglsrv6 tier jobs com VMIDs 600-622"
  fi
}

setup_aglsrv3() {
  local pbs_root="${AGLSRV3_PBS_STORES_ROOT:-/aglsrv3-tb}"
  apply_pbs_link "${AGLSRV3_PBS_VMID}" "${AGLSRV3_PBS_IP}" "${pbs_root}" "aglsrv3" "pbs-"

  # VMs 301-303,305,308,310 + CTs 304,306,317,338 (excl. 318 PBS)
  local vmids="301,302,303,305,308,310,304,306,317,338"
  if [[ "${APPLY}" == true ]]; then
    upsert_backup_job "backup-aglsrv3-pbs-daily" "AGLSRV3 daily PBS -> aglsrv3-tb" "aglsrv3" "pbs-aglsrv3-tb" "04:15" "${vmids}" 1
    if [[ -x /usr/local/sbin/aglsrv3-host-root-backup.sh ]]; then
      log "Host root backup: /usr/local/sbin/aglsrv3-host-root-backup.sh (cron aglsrv3-host-root-backup)"
    else
      log "AVISO: instalar host root backup: bash scripts/proxmox/aglsrv3-host-backup-install.sh --remote"
    fi
  else
    log "DRY-RUN aglsrv3 job vmid=${vmids} storage=pbs-aglsrv3-tb"
  fi
}

dispatch_host() {
  local h="$1"
  case "${h}" in
    aglsrv3) setup_aglsrv3 ;;
    aglsrv5) setup_aglsrv5 ;;
    fgsrv7) setup_fgsrv7 ;;
    aglsrv6) setup_aglsrv6 ;;
    *) die "Host desconhecido: ${h}" ;;
  esac
}

remote_wrap() {
  local h="$1"
  local ssh_target
  case "${h}" in
    aglsrv3) ssh_target="${AGLSRV3_SSH}" ;;
    aglsrv5) ssh_target="${AGLSRV5_SSH}" ;;
    fgsrv7) ssh_target="${FGSRV7_SSH}" ;;
    aglsrv6) ssh_target="${AGLSRV6_SSH}" ;;
    *) die "Host remoto desconhecido: ${h}" ;;
  esac

  log "=== Remoto ${h} via ${ssh_target} ==="
  scp -q "${SCRIPT_DIR}/pbs-link-host-storages.sh" "${SCRIPT_DIR}/aglsrv-vmid-map.env" "${SCRIPT_DIR}/pbs-setup-renumbered-hosts.sh" "${ssh_target}:/root/"
  local apply_flag=""
  [[ "${APPLY}" == true ]] && apply_flag="--apply"
  ssh -o ConnectTimeout=120 "${ssh_target}" "bash /root/pbs-setup-renumbered-hosts.sh --host ${h} ${apply_flag}"
}

main() {
  if [[ "${HOST}" == "all" ]]; then
    for h in aglsrv3 aglsrv5 fgsrv7 aglsrv6; do
      if [[ "${REMOTE}" == true ]]; then
        remote_wrap "${h}"
      else
        dispatch_host "${h}"
      fi
    done
    exit 0
  fi

  if [[ "${REMOTE}" == true ]]; then
    remote_wrap "${HOST}"
  else
    dispatch_host "${HOST}"
  fi
}

main
