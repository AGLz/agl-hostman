#!/usr/bin/env bash
# Regista todos os storages activos do host Proxmox no PBS local (datastores + pvesm add pbs).
# Executar NO host Proxmox (root), com CT PBS já a correr.
#
# Cada storage recebe dataset/dir próprio no host + bind mount dedicado no CT (evita nested datastores).
#
# Uso:
#   PBS_VMID=518 PBS_IP=192.168.15.118 PBS_STORES_ROOT=/aglsrv3-tb \
#     bash pbs-link-host-storages.sh

set -euo pipefail

PBS_VMID="${PBS_VMID:-}"
PBS_IP="${PBS_IP:-}"
PBS_STORES_ROOT="${PBS_STORES_ROOT:-${BACKUP_ROOT:-}}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_USER="${PBS_USER:-root@pam}"
DRY_RUN="${DRY_RUN:-false}"
MP_INDEX_START="${MP_INDEX_START:-1}"
# Cluster: restringir pvesm a um nó; prefixo evita colisão pbs-local entre nós (ex. pbs5-local)
PBS_NODES="${PBS_NODES:-}"
PBS_ID_PREFIX="${PBS_ID_PREFIX:-pbs-}"

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

die() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ -n "${PBS_VMID}" && -n "${PBS_IP}" && -n "${PBS_STORES_ROOT}" ]] || die "Definir PBS_VMID, PBS_IP e PBS_STORES_ROOT"

if ! pct status "${PBS_VMID}" &>/dev/null; then
  die "CT${PBS_VMID} não existe"
fi
if ! pct status "${PBS_VMID}" 2>/dev/null | grep -q running; then
  pct start "${PBS_VMID}"
  sleep 8
fi

if [[ -f /root/.pbs-link-password ]]; then
  PBS_PASSWORD="${PBS_PASSWORD:-$(cat /root/.pbs-link-password)}"
fi
[[ -n "${PBS_PASSWORD:-}" ]] || die "Definir PBS_PASSWORD ou criar /root/.pbs-link-password"

FINGERPRINT="$(pct exec "${PBS_VMID}" -- proxmox-backup-manager cert info 2>/dev/null | awk -F': ' '/Fingerprint \(sha256\)/ {print $2; exit}')"
[[ -n "${FINGERPRINT}" ]] || die "Não foi possível obter fingerprint do PBS CT${PBS_VMID}"

log "PBS CT${PBS_VMID} @ ${PBS_IP}:${PBS_PORT}"

mapfile -t STORAGES < <(
  pvesm status 2>/dev/null | awk 'NR>1 && $3=="active" && $2!="pbs" {print $1}'
)

[[ ${#STORAGES[@]} -gt 0 ]] || die "Nenhum storage activo"

log "Storages (${#STORAGES[@]}): ${STORAGES[*]}"

mp_idx=${MP_INDEX_START}
pending_mps=()

for sid in "${STORAGES[@]}"; do
  if [[ ${#sid} -lt 3 ]]; then
    ds_name="ds-${sid}"
  else
    ds_name="${sid}"
  fi
  host_path="${PBS_STORES_ROOT}/pbs-${sid}"
  ct_mp="/mnt/pbs-${sid}"
  pvesm_id="${PBS_ID_PREFIX}${sid}"

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: ${ds_name} host=${host_path} ct=${ct_mp} pvesm=${pvesm_id}"
    continue
  fi

  zfs_ds="${host_path#/}"
  root_ds="${PBS_STORES_ROOT#/}"
  if zfs list "${zfs_ds}" &>/dev/null; then
    :
  elif zfs list "${root_ds}" &>/dev/null; then
    zfs create "${zfs_ds}"
  else
    mkdir -p "${host_path}"
  fi

  if ! pct config "${PBS_VMID}" | grep -qF "${host_path},mp=${ct_mp}"; then
    pending_mps+=("${mp_idx}:${host_path},mp=${ct_mp}")
    mp_idx=$((mp_idx + 1))
  fi
done

if [[ ${#pending_mps[@]} -gt 0 ]]; then
  pct stop "${PBS_VMID}" 2>/dev/null || true
  sleep 3
  for entry in "${pending_mps[@]}"; do
    idx="${entry%%:*}"
    spec="${entry#*:}"
    pct set "${PBS_VMID}" -mp"${idx}" "${spec}"
    log "mp${idx}: ${spec}"
  done
fi

pct start "${PBS_VMID}" || true
sleep 12

for sid in "${STORAGES[@]}"; do
  if [[ ${#sid} -lt 3 ]]; then
    ds_name="ds-${sid}"
  else
    ds_name="${sid}"
  fi
  ct_mp="/mnt/pbs-${sid}"
  pvesm_id="${PBS_ID_PREFIX}${sid}"

  if [[ "${DRY_RUN}" == true ]]; then
    continue
  fi

  if ! pct exec "${PBS_VMID}" -- proxmox-backup-manager datastore list 2>/dev/null | grep -qE "^│ ${ds_name} │"; then
    pct exec "${PBS_VMID}" -- proxmox-backup-manager datastore create "${ds_name}" "${ct_mp}" \
      --comment "vzdump target for PVE storage ${sid}" || true
    log "Datastore: ${ds_name} @ ${ct_mp}"
  elif ! pct exec "${PBS_VMID}" -- test -d "${ct_mp}/.chunks" 2>/dev/null; then
    # Mount novo sem chunk store — recriar datastore
    pct exec "${PBS_VMID}" -- proxmox-backup-manager datastore remove "${ds_name}" 2>/dev/null || true
    pct exec "${PBS_VMID}" -- proxmox-backup-manager datastore create "${ds_name}" "${ct_mp}" \
      --comment "vzdump target for PVE storage ${sid}" || true
    log "Datastore reinicializado: ${ds_name} @ ${ct_mp}"
  fi

  if grep -qE "^pbs: ${pvesm_id}$" /etc/pve/storage.cfg 2>/dev/null; then
    log "pvesm existe: ${pvesm_id}"
    continue
  fi

  pvesm_args=(
    add pbs "${pvesm_id}"
    --server "${PBS_IP}"
    --port "${PBS_PORT}"
    --username "${PBS_USER}"
    --password "${PBS_PASSWORD}"
    --fingerprint "${FINGERPRINT}"
    --datastore "${ds_name}"
    --content backup
    --prune-backups 'keep-last=7,keep-weekly=4,keep-monthly=3'
  )
  if [[ -n "${PBS_NODES}" ]]; then
    pvesm_args+=(--nodes "${PBS_NODES}")
  fi
  pvesm "${pvesm_args[@]}" \
    && log "pvesm: ${pvesm_id} nodes=${PBS_NODES:-all}" \
    || log "AVISO: pvesm add ${pvesm_id} falhou"
done

log "=== $(hostname -s) done ==="
pvesm status 2>/dev/null | grep '^pbs-' || true
