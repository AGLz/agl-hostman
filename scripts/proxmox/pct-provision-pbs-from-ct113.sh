#!/usr/bin/env bash
# Provisiona Proxmox Backup Server clonando AGLSRV6 **CT613** man6-pbs (ex. CT113).
# Cria PBS local em AGLSRV1 (VMID 240) e AGLSRV3 (VMID 318) para vzdump antes do cluster.
#
# Uso (a partir de agl-hostman, com SSH aos hosts):
#   bash scripts/proxmox/pct-provision-pbs-from-ct113.sh --dry-run
#   bash scripts/proxmox/pbs-from-ct113.sh --target aglsrv3
#   bash scripts/proxmox/pct-provision-pbs-from-ct113.sh --target aglsrv1
#   bash scripts/proxmox/pct-provision-pbs-from-ct113.sh --target all
#
# Nota: CT113 no AGLSRV1 é Plex — template canónico = AGLSRV6 **CT613** (PBS_SOURCE_VMID em aglsrv-vmid-map.env).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv3-vmid-map.env
source "${SCRIPT_DIR}/aglsrv3-vmid-map.env"

DRY_RUN=false
TARGET="all"
DUMP_DIR="/var/lib/vz/dump"
SHARED_DUMP="/tmp/vzdump-lxc-113-pbs-template.tar.zst"

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
AGLSRV6_SSH="${AGLSRV6_SSH:-root@${PBS_SOURCE_HOST}}"

AGLSRV5_SSH="${AGLSRV5_SSH:-root@100.119.223.113}"
FGSRV7_SSH="${FGSRV7_SSH:-root@100.109.181.93}"

usage() {
  echo "Uso: $0 [--dry-run] [--target aglsrv1|aglsrv3|aglsrv5|fgsrv7|all]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --target)
      shift
      TARGET="${1:-all}"
      ;;
    --target=*) TARGET="${1#--target=}" ;;
    -h | --help) usage ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      usage
      ;;
  esac
  shift
done

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

remote() {
  local host=$1
  shift
  ssh -o ConnectTimeout=20 "${host}" "$@"
}

ensure_template_dump() {
  log "Template vzdump CT${PBS_SOURCE_VMID} @ AGLSRV6..."
  if remote "${AGLSRV6_SSH}" "test -s ${SHARED_DUMP}"; then
    log "Template já existe: ${SHARED_DUMP}"
    return 0
  fi
  local existing
  existing="$(remote "${AGLSRV6_SSH}" "ls -t /tmp/vzdump-lxc-${PBS_SOURCE_VMID}-*.tar.zst 2>/dev/null | head -1" || true)"
  if [[ -n "${existing}" ]]; then
    log "Reutilizar dump existente: ${existing}"
    if [[ "${DRY_RUN}" != true ]]; then
      remote "${AGLSRV6_SSH}" "cp '${existing}' ${SHARED_DUMP} && ls -lh ${SHARED_DUMP}"
    fi
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: vzdump ${PBS_SOURCE_VMID} no AGLSRV6"
    return 0
  fi
  remote "${AGLSRV6_SSH}" "set -e
    pct status ${PBS_SOURCE_VMID} | grep -q running
    vzdump ${PBS_SOURCE_VMID} --dumpdir /tmp --mode snapshot --compress zstd
    f=\$(ls -t /tmp/vzdump-lxc-${PBS_SOURCE_VMID}-*.tar.zst /tmp/vzdump-lxc-${PBS_SOURCE_VMID}-*.vma.zst 2>/dev/null | head -1)
    cp \"\${f}\" ${SHARED_DUMP}
    ls -lh ${SHARED_DUMP}"
}

copy_dump_to() {
  local dest_ssh=$1
  local dest_path=$2
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: scp template → ${dest_ssh}:${dest_path}"
    return 0
  fi
  remote "${dest_ssh}" "mkdir -p $(dirname "${dest_path}")"
  remote "${dest_ssh}" "scp -o StrictHostKeyChecking=no ${AGLSRV6_SSH}:${SHARED_DUMP} ${dest_path} && ls -lh ${dest_path}"
}

provision_aglsrv3() {
  local vmid=${AGLSRV3_PBS_VMID}
  local ip=${AGLSRV3_PBS_IP}
  local gw=${AGLSRV3_PBS_GW}
  local hn=${AGLSRV3_PBS_HOSTNAME}
  local dump_on_target="/var/lib/vz/dump/pbs-from-ct113.tar.zst"
  local ns="${AGLSRV3_DNS:-192.168.15.117}"

  log "=== AGLSRV3 CT${vmid} (${hn}) ==="
  if remote "${AGLSRV3_SSH}" "pct config ${vmid}" &>/dev/null; then
    log "CT${vmid} já existe — skip"
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: restore ${vmid} storage aglsrv3-tb ip ${ip}"
    return 0
  fi

  copy_dump_to "${AGLSRV3_SSH}" "${dump_on_target}"
  remote "${AGLSRV3_SSH}" "set -e
    zfs list aglsrv3-tb/backups >/dev/null 2>&1 || zfs create aglsrv3-tb/backups
    mkdir -p /aglsrv3-tb/backups
    pct restore ${vmid} ${dump_on_target} --storage aglsrv3-tb --hostname ${hn} --unique 1
    pct set ${vmid} -net0 name=eth0,bridge=vmbr0,gw=${gw},ip=${ip},type=veth
    pct set ${vmid} -nameserver ${ns}
    pct set ${vmid} -searchdomain aglz.io
    pct set ${vmid} -mp0 /aglsrv3-tb/backups,mp=/mnt/backups
    pct set ${vmid} -onboot 1
    pct set ${vmid} -tags 'agl;backup;pbs;aglsrv3'
    pct set ${vmid} -description 'PBS AGLSRV3 — clone AGLSRV6 CT113; datastore /mnt/backups'
    pct start ${vmid}
    sleep 8
    pct exec ${vmid} -- hostnamectl set-hostname ${hn} || true
    pct exec ${vmid} -- bash -c 'proxmox-backup-manager datastore create aglsrv3-local /mnt/backups 2>/dev/null || true'
    pct list | grep ${vmid}"
}

provision_host_pbs() {
  local ssh_host=$1
  local vmid=$2
  local ip=$3
  local gw=$4
  local hn=$5
  local backup_mp=$6
  local storage=$7
  local ns=$8
  local tag=$9

  log "=== ${hn} CT${vmid} @ ${ssh_host} ==="
  if remote "${ssh_host}" "pct config ${vmid}" &>/dev/null; then
    log "CT${vmid} já existe — skip"
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: restore ${vmid} ip ${ip}"
    return 0
  fi

  local dump_on_target="/var/lib/vz/dump/pbs-from-ct113.tar.zst"
  copy_dump_to "${ssh_host}" "${dump_on_target}"
  remote "${ssh_host}" "set -e
    mkdir -p ${backup_mp}
    pct restore ${vmid} ${dump_on_target} --storage ${storage} --hostname ${hn} --unique 1
    pct set ${vmid} -net0 name=eth0,bridge=vmbr0,gw=${gw},ip=${ip},type=veth
    pct set ${vmid} -nameserver ${ns}
    pct set ${vmid} -searchdomain aglz.io
    pct set ${vmid} -mp0 ${backup_mp},mp=/mnt/backups
    pct set ${vmid} -onboot 1
    pct set ${vmid} -tags '${tag}'
    pct set ${vmid} -description 'PBS — clone AGLSRV6 CT113'
    pct start ${vmid}
    sleep 8
    pct exec ${vmid} -- hostnamectl set-hostname ${hn} || true
    pct list | grep ${vmid}"
}

provision_aglsrv5() {
  provision_host_pbs "${AGLSRV5_SSH}" "${AGLSRV5_PBS_VMID}" "${AGLSRV5_PBS_IP}" "${AGLSRV5_PBS_GW}" \
    "${AGLSRV5_PBS_HOSTNAME}" "${AGLSRV5_PBS_BACKUP_ROOT}" "local-lvm" "192.168.15.102" "agl;backup;pbs;aglsrv5"
}

provision_fgsrv7() {
  # FGSRV7: storage 'local' não suporta rootdir; usar 'bkp' (/base/bkp).
  provision_host_pbs "${FGSRV7_SSH}" "${FGSRV7_PBS_VMID}" "${FGSRV7_PBS_IP}" "${FGSRV7_PBS_GW}" \
    "${FGSRV7_PBS_HOSTNAME}" "${FGSRV7_PBS_BACKUP_ROOT}" "bkp" "192.168.15.102" "agl;backup;pbs;fgsrv7"
}

provision_aglsrv1() {
  local vmid=${AGLSRV1_PBS_VMID}
  local ip=${AGLSRV1_PBS_IP}
  local gw=${AGLSRV1_PBS_GW}
  local hn=${AGLSRV1_PBS_HOSTNAME}
  local dump_on_target="/var/lib/vz/dump/pbs-from-ct113.tar.zst"
  local ns="192.168.0.102"
  local backup_mp="/mnt/overpower/pbs-backups"

  log "=== AGLSRV1 CT${vmid} (${hn}) ==="
  if remote "${AGLSRV1_SSH}" "pct config ${vmid}" &>/dev/null; then
    log "CT${vmid} já existe — skip"
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: restore ${vmid} storage local-zfs ip ${ip}"
    return 0
  fi

  copy_dump_to "${AGLSRV1_SSH}" "${dump_on_target}"
  remote "${AGLSRV1_SSH}" "set -e
    mkdir -p ${backup_mp}
    pct restore ${vmid} ${dump_on_target} --storage local-zfs --hostname ${hn} --unique 1
    pct set ${vmid} -net0 name=eth0,bridge=vmbr0,gw=${gw},ip=${ip},type=veth
    pct set ${vmid} -nameserver ${ns}
    pct set ${vmid} -searchdomain aglz.io
    pct set ${vmid} -mp0 ${backup_mp},mp=/mnt/backups
    pct set ${vmid} -onboot 1
    pct set ${vmid} -tags 'agl;backup;pbs;aglsrv1'
    pct set ${vmid} -description 'PBS AGLSRV1 — clone AGLSRV6 CT113; datastore /mnt/backups (overpower path)'
    pct start ${vmid}
    sleep 8
    pct exec ${vmid} -- hostnamectl set-hostname ${hn} || true
    pct exec ${vmid} -- bash -c 'proxmox-backup-manager datastore create aglsrv1-local /mnt/backups 2>/dev/null || true'
    pct list | grep ${vmid}"
}

ensure_template_dump

case "${TARGET}" in
  aglsrv1) provision_aglsrv1 ;;
  aglsrv3) provision_aglsrv3 ;;
  aglsrv5) provision_aglsrv5 ;;
  fgsrv7) provision_fgsrv7 ;;
  all)
    provision_aglsrv3
    provision_aglsrv1
    provision_aglsrv5
    provision_fgsrv7
    ;;
  *)
    echo "TARGET inválido: ${TARGET}" >&2
    usage
    ;;
esac

log "=== PBS provision done (${TARGET}) ==="
log "Próximo: pvesm add pbs no host Proxmox; criar jobs vzdump; depois pct-renumber-aglsrv3.sh --apply"
