#!/usr/bin/env bash
# Migração incremental spark (dir) → PBS local (pbs-spark) no AGLSRV1.
# Requer Fase 0 concluída: PBS com datastore único em spark/pbs.
#
# Uso:
#   bash pbs-migrate-spark-wave.sh --wave 1 --dry-run
#   bash pbs-migrate-spark-wave.sh --wave 1 --vmid 117 --apply
#   bash pbs-migrate-spark-wave.sh --wave 1 --apply   # todos da leva (sequencial)

set -euo pipefail

PBS_VMID="${PBS_VMID:-240}"
STORAGE_PBS="${STORAGE_PBS:-pbs-spark}"
STORAGE_LEGACY="${STORAGE_LEGACY:-spark}"
PBS_DATASTORE="${PBS_DATASTORE:-spark}"
COMPRESS="${COMPRESS:-zstd}"
MODE="${MODE:-snapshot}"

WAVE=""
VMID=""
APPLY=false
DRY_RUN=true

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: $0 --wave <1|2|3> [--vmid ID] [--apply] [--dry-run]

  --wave N     Leva de migração (ver docs/AGLSRV1-PBS-SPARK-MIGRATION-PLAN.md)
  --vmid ID    Apenas este guest (recomendado)
  --apply      Executa backup/verify/prune (default: dry-run)
  --dry-run    Só mostra acções (default se --apply omitido)

Leva 1: 117,176,111,112,102,101
Leva 2: 151,152,153,154,155,156,157,182
Leva 3: 120,122,123,124,126,132,137,139,159,161,162,163,165,170,171,172,178,201
EOF
}

wave_vmids() {
  case "$1" in
    1) echo "117 176 111 112 102 101" ;;
    2) echo "151 152 153 154 155 156 157 182" ;;
    3) echo "120 122 123 124 126 132 137 139 159 161 162 163 165 170 171 172 178 201" ;;
    *) die "Leva inválida: $1" ;;
  esac
}

guest_type() {
  local id="$1"
  if pct status "${id}" &>/dev/null; then
    echo "lxc"
  elif qm status "${id}" &>/dev/null; then
    echo "qemu"
  else
    echo "unknown"
  fi
}

latest_spark_backup_vol() {
  local id="$1" typ="$2"
  pvesm list "${STORAGE_LEGACY}" --content backup 2>/dev/null \
    | grep -E "vzdump-${typ}-${id}-" | tail -1 | awk '{print $1}' || true
}

count_spark_backups() {
  local id="$1" typ="$2"
  pvesm list "${STORAGE_LEGACY}" --content backup 2>/dev/null \
    | grep -c -E "vzdump-${typ}-${id}-" || echo 0
}

verify_pbs_snapshot() {
  local id="$1" typ="$2"
  local prefix="ct"
  [[ "${typ}" == "qemu" ]] && prefix="vm"
  local base="/spark/pbs/${prefix}/${id}"
  [[ -d "${base}" ]] && [[ -n "$(ls -A "${base}" 2>/dev/null)" ]] && return 0
  return 1
}

migrate_one() {
  local id="$1"
  local typ
  typ="$(guest_type "${id}")"
  [[ "${typ}" != "unknown" ]] || die "VMID ${id} não encontrado"

  log "=== VMID ${id} (${typ}) ==="
  local cnt latest
  cnt="$(count_spark_backups "${id}" "${typ}")"
  latest="$(latest_spark_backup_vol "${id}" "${typ}")"
  log "Backups spark: ${cnt}; mais recente: ${latest:-nenhum}"

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: vzdump ${id} --storage ${STORAGE_PBS} --mode ${MODE} --compress ${COMPRESS}"
    log "DRY-RUN: verify + prune spark (manter 1: ${latest:-n/a})"
    return 0
  fi

  log "Backup PBS..."
  vzdump "${id}" --storage "${STORAGE_PBS}" --mode "${MODE}" --compress "${COMPRESS}"

  log "Verify PBS snapshot..."
  if ! verify_pbs_snapshot "${id}" "${typ}"; then
    die "Snapshot PBS não listado para ${id} — não fazer prune em spark"
  fi

  log "Verify integridade datastore..."
  if ! pct exec "${PBS_VMID}" -- proxmox-backup-manager verify "${PBS_DATASTORE}" --ignore-verified true; then
    die "Verify falhou no datastore — não fazer prune em spark"
  fi

  log "Prune spark (manter apenas o mais recente)..."
  if [[ -n "${latest}" ]]; then
    pvesm list "${STORAGE_LEGACY}" --content backup 2>/dev/null \
      | grep -E "vzdump-${typ}-${id}-" | awk '{print $1}' | while read -r vol; do
        if [[ "${vol}" != "${latest}" ]]; then
          log "  free ${vol}"
          pvesm free "${vol}"
        fi
      done
    log "Mantido em spark (rollback): ${latest}"
  else
    log "Sem backups legados para ${id}"
  fi

  log "OK: ${id} migrado (PBS activo; 1 legado em spark até 2º ciclo PBS)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wave) WAVE="${2:-}"; shift 2 ;;
    --vmid) VMID="${2:-}"; shift 2 ;;
    --apply) APPLY=true; DRY_RUN=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

[[ -n "${WAVE}" ]] || die "Indicar --wave"

if ! pvesm status 2>/dev/null | grep -q "^${STORAGE_PBS}.*active"; then
  die "Storage ${STORAGE_PBS} não activo — concluir Fase 0 do plano"
fi

ids="${VMID:-$(wave_vmids "${WAVE}")}"
for id in ${ids}; do
  migrate_one "${id}"
done

log "=== Leva ${WAVE} concluída ==="
