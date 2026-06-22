#!/usr/bin/env bash
# Liga storages AGLSRV3 no AGLSRV1 (host Proxmox + CT PBS local).
#
# - NFS via aglfs3 (CT338) Tailscale — shares, overpower, power, storage
# - PBS remoto via aglsrv3-pbs (CT318) Tailscale — datastores aglsrv3-tb, backups
# - Bind mounts no aglsrv1-pbs (CT240) para o PBS aceder aos exports NFS
#
# Uso (agldv03 ou local no AGLSRV1):
#   bash scripts/proxmox/aglsrv3-remote-storage-link.sh --dry-run
#   bash scripts/proxmox/aglsrv3-remote-storage-link.sh --apply
#   bash scripts/proxmox/aglsrv3-remote-storage-link.sh --apply --remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

APPLY=false
REMOTE=false
DRY_RUN=true

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
AGLFS3_SERVER="${AGLSRV3_AGLFS3_TS_IP:-100.89.170.85}"
PBS_SERVER="${AGLSRV3_PBS_TS_IP:-100.70.155.60}"
PBS_PORT="${AGLSRV3_PBS_PORT:-8007}"
PBS_USER="${PBS_USER:-root@pam}"
AGLSRV1_PBS_VMID="${AGLSRV1_PBS_VMID:-240}"

NFS_EXPORTS=(
  "aglfs3-shares|/mnt/shares"
  "aglfs3-overpower|/mnt/overpower"
  "aglfs3-power|/mnt/power"
  "aglfs3-storage|/mnt/storage"
)

PBS_DATASTORES=(
  "pbs-aglsrv3-tb|aglsrv3-tb"
)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true; DRY_RUN=false ;;
    --dry-run) DRY_RUN=true ;;
    --remote) REMOTE=true ;;
    -h | --help) usage; exit 0 ;;
    *) die "Opção desconhecida: $arg" ;;
  esac
done

run_aglsrv1() {
  if [[ "${REMOTE}" == true ]]; then
    scp -q "${SCRIPT_DIR}/aglsrv3-remote-storage-link.sh" \
      "${SCRIPT_DIR}/aglsrv-vmid-map.env" \
      "${AGLSRV1_SSH}:/root/"
  fi

  local inner="bash /root/aglsrv3-remote-storage-link.sh"
  [[ "${APPLY}" == true ]] && inner+=" --apply"

  if [[ "${REMOTE}" == true ]]; then
  ssh -o BatchMode=yes -o ConnectTimeout=60 "${AGLSRV1_SSH}" "${inner}"
  else
    bash "${SCRIPT_DIR}/aglsrv3-remote-storage-link.sh" $([[ "${APPLY}" == true ]] && echo --apply)
  fi
}

add_nfs_storage() {
  local sid="$1" export_path="$2"
  local host_path="/mnt/pve/${sid}"

  if grep -qE "^nfs: ${sid}$" /etc/pve/storage.cfg 2>/dev/null; then
    log "NFS já existe: ${sid}"
    pvesm set "${sid}" --disable 0 2>/dev/null || true
    return 0
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: pvesm add nfs ${sid} server=${AGLFS3_SERVER} export=${export_path}"
    return 0
  fi

  mkdir -p "${host_path}"
  pvesm add nfs "${sid}" \
    --server "${AGLFS3_SERVER}" \
    --export "${export_path}" \
    --path "${host_path}" \
    --content backup,iso,vztmpl,images,snippets \
    --options nfsvers=3 \
    && log "NFS: ${sid}" \
    || log "AVISO: pvesm add nfs ${sid} falhou"
}

get_pbs_fingerprint() {
  local fp
  fp="$(curl -sk "https://${PBS_SERVER}:${PBS_PORT}/api2/json/config/certificates/info" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['fingerprint'])" 2>/dev/null || true)"
  if [[ -n "${fp}" ]]; then
    echo "${fp}"
    return 0
  fi
  fp="$(echo | openssl s_client -connect "${PBS_SERVER}:${PBS_PORT}" 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
    | sed 's/^sha256 Fingerprint=//' | tr '[:upper:]' '[:lower:]')"
  [[ -n "${fp}" ]] || return 1
  echo "${fp}"
}

add_pbs_remote() {
  local pvesm_id="$1" datastore="$2"

  if grep -qE "^pbs: ${pvesm_id}$" /etc/pve/storage.cfg 2>/dev/null; then
    log "PBS remoto já existe: ${pvesm_id}"
    return 0
  fi

  [[ -f /root/.pbs-link-password ]] || die "Criar /root/.pbs-link-password no AGLSRV1"
  local pass
  pass="$(cat /root/.pbs-link-password)"

  local fingerprint
  fingerprint="$(get_pbs_fingerprint)" || die "Fingerprint PBS ${PBS_SERVER} indisponível"

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: pvesm add pbs ${pvesm_id} server=${PBS_SERVER} datastore=${datastore}"
    return 0
  fi

  pvesm add pbs "${pvesm_id}" \
    --server "${PBS_SERVER}" \
    --port "${PBS_PORT}" \
    --username "${PBS_USER}" \
    --password "${pass}" \
    --fingerprint "${fingerprint}" \
    --datastore "${datastore}" \
    --content backup \
    --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=3' \
    && log "PBS remoto: ${pvesm_id} → ${datastore}" \
    || log "AVISO: pvesm add pbs ${pvesm_id} falhou"
}

link_pbs_ct_mounts() {
  local vmid="${AGLSRV1_PBS_VMID}"
  if ! pct status "${vmid}" &>/dev/null; then
    log "AVISO: CT${vmid} (aglsrv1-pbs) não existe — skip bind mounts"
    return 0
  fi

  local pending=()
  local mp_idx=1
  for entry in "${NFS_EXPORTS[@]}"; do
    local sid="${entry%%|*}"
    local host_path="/mnt/pve/${sid}"
    local ct_mp="/mnt/${sid}"
    if pct config "${vmid}" | grep -qF "${host_path},mp=${ct_mp}"; then
      log "CT${vmid} mp já existe: ${ct_mp}"
      continue
    fi
  pending+=("${mp_idx}:${host_path},mp=${ct_mp}")
    mp_idx=$((mp_idx + 1))
  done

  if [[ ${#pending[@]} -eq 0 ]]; then
    return 0
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: CT${vmid} bind mounts: ${pending[*]}"
    return 0
  fi

  # Garantir NFS activo no host antes de bind
  for entry in "${NFS_EXPORTS[@]}"; do
    local sid="${entry%%|*}"
    pvesm set "${sid}" --disable 0 2>/dev/null || true
    mountpoint -q "/mnt/pve/${sid}" || pvesm scan nfs "${sid}" 2>/dev/null || true
  done

  pct stop "${vmid}" 2>/dev/null || true
  sleep 4
  for spec_entry in "${pending[@]}"; do
    local idx="${spec_entry%%:*}"
    local spec="${spec_entry#*:}"
    pct set "${vmid}" -mp"${idx}" "${spec}"
    log "CT${vmid} mp${idx}: ${spec}"
  done
  pct start "${vmid}" || true
  sleep 8
}

main_local() {
  log "=== AGLSRV1 ← AGLSRV3 storages (dry=${DRY_RUN}) ==="
  log "aglfs3 NFS: ${AGLFS3_SERVER} | PBS: ${PBS_SERVER}:${PBS_PORT}"

  if ! ping -c1 -W3 "${AGLFS3_SERVER}" &>/dev/null; then
    die "Sem ping a aglfs3 ${AGLFS3_SERVER}"
  fi

  for entry in "${NFS_EXPORTS[@]}"; do
    add_nfs_storage "${entry%%|*}" "${entry#*|}"
  done

  for entry in "${PBS_DATASTORES[@]}"; do
    add_pbs_remote "${entry%%|*}" "${entry#*|}"
  done

  link_pbs_ct_mounts

  if [[ "${DRY_RUN}" == false ]]; then
    log "=== pvesm (aglfs3 + pbs-aglsrv3) ==="
    pvesm status 2>/dev/null | grep -E 'aglfs3|pbs-aglsrv3' || true
  fi
}

if [[ "${REMOTE}" == true ]] && [[ "$(hostname -s)" != "aglsrv1" ]]; then
  run_aglsrv1
else
  main_local
fi
