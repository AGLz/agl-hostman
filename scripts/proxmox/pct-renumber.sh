#!/usr/bin/env bash
# Renumera CTs/VMs num host Proxmox (vzdump → restore → destroy).
# Mapas em aglsrv-vmid-map.env (faixas: SRV3 300–399, SRV5/FGSRV7 500–599, SRV6 600–699).
#
# Uso local no host:
#   bash pct-renumber.sh --host aglsrv3 --dry-run
#   bash pct-renumber.sh --host aglsrv3 --apply
#
# Uso remoto (a partir de agl-hostman):
#   bash scripts/proxmox/pct-renumber.sh --host aglsrv3 --dry-run --remote
#   bash scripts/proxmox/pct-renumber.sh --host aglsrv6 --apply --remote --only 113

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

HOST=""
DRY_RUN=false
APPLY=false
REMOTE=false
ONLY=""

usage() {
  echo "Uso: $0 --host aglsrv3|aglsrv5|aglsrv6|fgsrv7 --dry-run|--apply [--remote] [--only id1,id2,...]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) shift; HOST="${1:-}" ;;
    --host=*) HOST="${1#--host=}" ;;
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true ;;
    --remote) REMOTE=true ;;
    --only) shift; ONLY="${1:-}" ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h | --help) usage ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      usage
      ;;
  esac
  shift
done

[[ -n "${HOST}" ]] || usage
if [[ "${DRY_RUN}" != true && "${APPLY}" != true ]]; then
  usage
fi
if [[ -n "${ONLY}" && ! "${ONLY}" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
  echo "ERRO: --only aceita apenas IDs numéricos separados por vírgula" >&2
  exit 1
fi

HOST_KEY="$(echo "${HOST}" | tr '[:lower:]' '[:upper:]')"
RENAMES_VAR="RENAMES_${HOST_KEY}"
SSH_VAR="${HOST_KEY}_SSH"

if [[ -z "${!RENAMES_VAR:-}" ]]; then
  echo "ERRO: host desconhecido ou sem mapa RENAMES_${HOST_KEY}" >&2
  exit 1
fi

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

should_migrate() {
  local old_id=$1
  if [[ -z "${ONLY}" ]]; then
    return 0
  fi
  [[ ",${ONLY}," == *",${old_id},"* ]]
}

migrate_lxc() {
  local old_id=$1
  local new_id=$2
  local name=$3
  local dump_storage=$4
  local restore_storage=$5

  if [[ "${old_id}" == "${new_id}" ]]; then
    log "SKIP CT${old_id} (${name}): já no VMID alvo"
    return 0
  fi
  if ! pct config "${old_id}" &>/dev/null; then
    log "SKIP CT${old_id} (${name}): não existe"
    return 0
  fi
  if pct config "${new_id}" &>/dev/null || qm config "${new_id}" &>/dev/null; then
    echo "ERRO: destino VMID ${new_id} já ocupado" >&2
    exit 1
  fi
  if ! should_migrate "${old_id}"; then
    log "SKIP CT${old_id} (--only)"
    return 0
  fi

  log "PLAN CT${old_id} → CT${new_id} (${name})"
  if [[ "${DRY_RUN}" == true ]]; then
    pct config "${old_id}" 2>/dev/null | head -3
    return 0
  fi

  local was_running=false
  if pct status "${old_id}" | grep -q running; then
    was_running=true
    log "Parar CT${old_id} para clone..."
    pct stop "${old_id}"
  fi

  # Reason: vzdump em LXC unprivileged falha (tar Permission denied em /run, journal, etc.)
  log "pct clone CT${old_id} → CT${new_id} (storage ${restore_storage})..."
  pct clone "${old_id}" "${new_id}" --hostname "${name}" --storage "${restore_storage}"

  log "Remover CT${old_id}..."
  pct destroy "${old_id}"

  if [[ "${was_running}" == true ]]; then
    log "Arrancar CT${new_id}..."
    pct start "${new_id}"
    sleep 3
    if ! pct status "${new_id}" 2>/dev/null | grep -q running; then
      log "WARN: CT${new_id} não está running após start — verificar manualmente"
    fi
  fi

  log "OK CT${old_id} → CT${new_id}"
}

migrate_vm() {
  local old_id=$1
  local new_id=$2
  local name=$3
  local dump_storage=$4
  local restore_storage=$5

  if [[ "${old_id}" == "${new_id}" ]]; then
    log "SKIP VM${old_id} (${name}): já no VMID alvo"
    return 0
  fi
  if ! qm config "${old_id}" &>/dev/null; then
    log "SKIP VM${old_id} (${name}): não existe"
    return 0
  fi
  if pct config "${new_id}" &>/dev/null || qm config "${new_id}" &>/dev/null; then
    echo "ERRO: destino VMID ${new_id} já ocupado" >&2
    exit 1
  fi
  if ! should_migrate "${old_id}"; then
    log "SKIP VM${old_id} (--only)"
    return 0
  fi

  log "PLAN VM${old_id} → VM${new_id} (${name})"
  if [[ "${DRY_RUN}" == true ]]; then
    qm config "${old_id}" 2>/dev/null | head -3
    return 0
  fi

  if qm config "${old_id}" 2>/dev/null | grep -qE '^scsi[0-9]+: /dev/'; then
    log "SKIP VM${old_id} (${name}): discos passthrough — migrar manualmente"
    return 0
  fi

  local was_running=false
  if qm status "${old_id}" | grep -q running; then
    was_running=true
    log "Parar VM${old_id}..."
    qm stop "${old_id}"
  fi

  # Reason: ISOs sem media=cdrom impedem vzdump (ex. hackintosh AGLMAC07)
  for slot in ide0 ide1 ide2 ide3; do
    local line iso_val
    line="$(qm config "${old_id}" 2>/dev/null | grep -E "^${slot}:" || true)"
    if [[ "${line}" == *iso/* && "${line}" != *media=cdrom* ]]; then
      iso_val="$(echo "${line}" | sed "s/^${slot}: //")"
      log "Ajustar ${slot} media=cdrom em VM${old_id}..."
      qm set "${old_id}" -"${slot}" "${iso_val},media=cdrom"
    fi
  done

  log "vzdump VM${old_id} (storage ${dump_storage})..."
  vzdump "${old_id}" --dumpdir /var/lib/vz/dump --mode stop --compress zstd >/dev/null

  local dump_file
  dump_file="$(ls -t /var/lib/vz/dump/vzdump-qemu-"${old_id}"-*.vma.zst 2>/dev/null | head -1)"
  [[ -n "${dump_file}" && -f "${dump_file}" ]] || {
    echo "ERRO: vzdump VM${old_id} falhou" >&2
    exit 1
  }

  log "Restore VM${new_id}..."
  qmrestore "${dump_file}" "${new_id}" --storage "${restore_storage}"

  log "Remover VM${old_id}..."
  qm destroy "${old_id}"

  if [[ -f "${dump_file}" ]]; then
    rm -f "${dump_file}" "${dump_file%.vma.zst}.log" 2>/dev/null || true
    log "Dump removido: ${dump_file}"
  fi

  if [[ "${was_running}" == true ]]; then
    log "Arrancar VM${new_id}..."
    qm start "${new_id}"
    sleep 5
    if ! qm status "${new_id}" 2>/dev/null | grep -q running; then
      log "WARN: VM${new_id} não está running após start — verificar manualmente"
    fi
  fi

  log "OK VM${old_id} → VM${new_id}"
}

run_on_host() {
  local dump_storage restore_ct restore_vm
  local dump_var ct_var vm_var
  dump_var="${HOST_KEY}_DUMP_STORAGE"
  ct_var="${HOST_KEY}_RESTORE_CT_STORAGE"
  vm_var="${HOST_KEY}_RESTORE_VM_STORAGE"
  dump_storage="${!dump_var}"
  restore_ct="${!ct_var}"
  restore_vm="${!vm_var}"

  local mode="APPLY"
  [[ "${DRY_RUN}" == true ]] && mode="DRY-RUN"
  log "=== ${HOST} renumber (${mode}) dump=${dump_storage} ct=${restore_ct} vm=${restore_vm} ==="

  # VMs primeiro, depois LXC (ordem estável no mapa)
  local -a vms=()
  local -a lxcs=()
  local -a renames=()
  local entry kind old new name
  # shellcheck disable=SC1083,SC2154
  eval "renames=(\"\${${RENAMES_VAR}[@]}\")"
  for entry in "${renames[@]}"; do
    IFS=: read -r kind old new name <<< "${entry}"
    if [[ "${kind}" == vm ]]; then
      vms+=("${entry}")
    else
      lxcs+=("${entry}")
    fi
  done

  for entry in "${vms[@]}"; do
    IFS=: read -r _ old new name <<< "${entry}"
    migrate_vm "${old}" "${new}" "${name}" "${dump_storage}" "${restore_vm}"
  done
  for entry in "${lxcs[@]}"; do
    IFS=: read -r _ old new name <<< "${entry}"
    migrate_lxc "${old}" "${new}" "${name}" "${dump_storage}" "${restore_ct}"
  done

  log "=== Concluído ${HOST} ==="
  pct list 2>/dev/null || true
  qm list 2>/dev/null || true
}

if [[ "${REMOTE}" == true ]]; then
  ssh_target="${!SSH_VAR:-}"
  [[ -n "${ssh_target}" ]] || {
    echo "ERRO: ${SSH_VAR} não definido" >&2
    exit 1
  }
  log "Remoto: ${ssh_target}"
  scp -q "${SCRIPT_DIR}/aglsrv-vmid-map.env" "${SCRIPT_DIR}/pct-renumber.sh" "${ssh_target}:/root/"
  ssh "${ssh_target}" "sed -i 's/\r$//' /root/pct-renumber.sh; chmod +x /root/pct-renumber.sh; bash /root/pct-renumber.sh --host ${HOST} $( [[ ${DRY_RUN} == true ]] && echo --dry-run || echo --apply ) ${ONLY:+--only ${ONLY}}"
else
  command -v pct >/dev/null || {
    echo "ERRO: executar no Proxmox ou usar --remote" >&2
    exit 1
  }
  run_on_host
fi
