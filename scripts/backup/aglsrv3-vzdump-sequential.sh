#!/usr/bin/env bash
# Backup sequencial seguro — AGLSRV3 → PBS remoto.
#
# Evita vzdump massivo (crash Jun 2026): um guest de cada vez, pré-checks de RAM/ZFS,
# VM310 parada por defeito, pausa entre jobs.
#
# Uso (no host aglsrv3 ou via SSH):
#   ./scripts/backup/aglsrv3-vzdump-sequential.sh --dry-run
#   ./scripts/backup/aglsrv3-vzdump-sequential.sh --apply
#   ./scripts/backup/aglsrv3-vzdump-sequential.sh --apply --skip 301
#   ./scripts/backup/aglsrv3-vzdump-sequential.sh --apply --keep-vm310-running  # não recomendado
#
# Remoto (agldv03):
#   AGLSRV3_SSH=root@100.123.5.81 ./scripts/backup/aglsrv3-vzdump-sequential.sh --apply --remote
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../proxmox/aglsrv-vmid-map.env
[[ -f "${SCRIPT_DIR}/../proxmox/aglsrv-vmid-map.env" ]] && source "${SCRIPT_DIR}/../proxmox/aglsrv-vmid-map.env"

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
STORAGE="${AGLSRV3_PBS_STORAGE:-pbs-aglsrv3-tb}"
NODE="${AGLSRV3_NODE:-aglsrv3}"
MIN_MEM_AVAIL_MB="${AGLSRV3_BACKUP_MIN_MEM_MB:-4096}"
MIN_PAUSE_SEC="${AGLSRV3_BACKUP_PAUSE_SEC:-45}"
LOG_DIR="${AGLSRV3_BACKUP_LOG_DIR:-/var/log/hostman}"
PRUNE="${AGLSRV3_BACKUP_PRUNE:-keep-daily=7,keep-monthly=3,keep-weekly=4,keep-yearly=1}"

# Ordem: CTs leves → VMs paradas → VM310 (pesada) → VM301 (TPM/NVMe) por último
DEFAULT_ORDER=(304 306 317 338 303 302 305 308 310 301)
EXCLUDE=(318)

APPLY=false
DRY_RUN=true
REMOTE=false
STOP_VM310=true
SKIP_IDS=()

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "ERRO: $*"; exit 1; }

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  echo ""
  echo "Opções:"
  echo "  --apply                 Executa vzdump (default: dry-run)"
  echo "  --dry-run               Só mostra plano (default)"
  echo "  --remote                Corre via SSH no AGLSRV3"
  echo "  --skip VMID             Exclui VMID (repetível)"
  echo "  --only VMID,...         Só estes IDs"
  echo "  --keep-vm310-running    Não para VM310 antes do backup"
  echo "  --min-mem-mb N          RAM livre mínima (default: $MIN_MEM_AVAIL_MB)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; DRY_RUN=false; shift ;;
    --dry-run) DRY_RUN=true; APPLY=false; shift ;;
    --remote) REMOTE=true; shift ;;
    --keep-vm310-running) STOP_VM310=false; shift ;;
    --skip) SKIP_IDS+=("$2"); shift 2 ;;
    --only)
      IFS=',' read -ra DEFAULT_ORDER <<< "$2"
      shift 2
      ;;
    --min-mem-mb) MIN_MEM_AVAIL_MB="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1 (use --help)" ;;
  esac
done

should_skip() {
  local id="$1"
  for e in "${EXCLUDE[@]}"; do
    [[ "$id" == "$e" ]] && return 0
  done
  for s in "${SKIP_IDS[@]}"; do
    [[ "$id" == "$s" ]] && return 0
  done
  return 1
}

run_on_host() {
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "$@"
  else
    "$@"
  fi
}

preflight() {
  log "Pré-checks no nó ${NODE}..."
  if ! run_on_host bash -s <<EOF
set -euo pipefail
if pgrep -x vzdump >/dev/null 2>&1; then
  echo "vzdump já em execução"; exit 1
fi
avail=\$(awk '/MemAvailable/ {print int(\$2/1024)}' /proc/meminfo)
if [[ "\$avail" -lt ${MIN_MEM_AVAIL_MB} ]]; then
  echo "MemAvailable=\${avail}MB < ${MIN_MEM_AVAIL_MB}MB"; exit 1
fi
health=\$(zpool list -H -o health aglsrv3-tb 2>/dev/null || echo UNKNOWN)
if [[ "\$health" != "ONLINE" ]]; then
  echo "ZFS aglsrv3-tb health=\$health"; exit 1
fi
if ! pvesm status -storage ${STORAGE} &>/dev/null; then
  echo "Storage ${STORAGE} indisponível"; exit 1
fi
echo "OK mem=\${avail}MB zfs=\$health storage=${STORAGE}"
EOF
  then
    if [[ "$DRY_RUN" == true ]]; then
      log "AVISO: pré-check falhou (ex.: RAM baixa com VM310 activa) — plano mostrado na mesma"
      return 0
    fi
    die "Pré-check falhou"
  fi
}

guest_type() {
  local id="$1"
  if run_on_host qm config "$id" &>/dev/null; then
    echo vm
  elif run_on_host pct config "$id" &>/dev/null; then
    echo lxc
  else
    echo unknown
  fi
}

guest_name() {
  local id="$1"
  run_on_host bash -c "qm config '$id' 2>/dev/null | awk -F: '/^name:/ {gsub(/^ +/,\"\",\$2); print \$2; exit} || pct config '$id' 2>/dev/null | awk -F: '/^hostname:/ {gsub(/^ +/,\"\",\$2); print \$2; exit}'" 2>/dev/null || echo "?"
}

guest_status() {
  local id="$1"
  run_on_host pvesh get "/nodes/${NODE}/qemu/${id}/status/current" --output-format json 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null \
    || run_on_host pvesh get "/nodes/${NODE}/lxc/${id}/status/current" --output-format json 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null \
    || echo unknown
}

backup_one() {
  local id="$1" gtype="$2" gname="$3"
  local mode="snapshot"
  local extra=()

  if [[ "$gtype" == "vm" && "$id" == "301" ]]; then
    mode="stop"
    log "VM301: modo stop (TPM/NVMe passthrough)"
  fi

  if [[ "$id" == "310" && "$STOP_VM310" == true ]]; then
    log "VM310: a parar Ollama antes do backup..."
    if [[ "$DRY_RUN" == true ]]; then
      log "[dry-run] qm shutdown 310 --timeout 120"
    else
      run_on_host qm shutdown 310 --timeout 120 || run_on_host qm stop 310
      sleep 10
    fi
    mode="stop"
  fi

  local cmd=(
    vzdump "$id"
    --node "$NODE"
    --storage "$STORAGE"
    --mode "$mode"
    --compress zstd
    --prune-backups "$PRUNE"
  )

  log "Backup VMID=${id} (${gname}, ${gtype}, mode=${mode})"
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] ${cmd[*]}"
    return 0
  fi

  run_on_host mkdir -p "$LOG_DIR"
  local logfile="${LOG_DIR}/vzdump-sequential-${id}-$(date +%Y%m%d-%H%M%S).log"
  if run_on_host "${cmd[@]}" >>"$logfile" 2>&1; then
    log "OK VMID=${id} → log remoto ${logfile}"
    return 0
  fi
  log "FALHA VMID=${id} — ver ${logfile}"
  return 1
}

main() {
  local plan=()
  for id in "${DEFAULT_ORDER[@]}"; do
    should_skip "$id" && continue
    plan+=("$id")
  done

  [[ ${#plan[@]} -gt 0 ]] || die "Nenhum VMID no plano"

  log "Plano sequencial (${#plan[@]} guests): ${plan[*]}"
  log "Storage=${STORAGE} min_mem=${MIN_MEM_AVAIL_MB}MB pause=${MIN_PAUSE_SEC}s stop_vm310=${STOP_VM310}"

  preflight

  local failed=0 ok=0
  for id in "${plan[@]}"; do
    if [[ "$DRY_RUN" == false ]]; then
      preflight || die "Pré-check falhou antes de VMID=${id} — abortar"
    fi

    local gtype gname
    gtype="$(guest_type "$id")"
    [[ "$gtype" != "unknown" ]] || { log "SKIP VMID=${id} (não existe)"; continue; }
    gname="$(guest_name "$id")"

    if backup_one "$id" "$gtype" "$gname"; then
      ((ok++)) || true
    else
      ((failed++)) || true
      log "Continuar com próximo guest (failed=${failed})"
    fi

    if [[ "$DRY_RUN" == false && "$id" != "${plan[-1]}" ]]; then
      log "Pausa ${MIN_PAUSE_SEC}s..."
      sleep "$MIN_PAUSE_SEC"
    fi
  done

  if [[ "$STOP_VM310" == true && "$DRY_RUN" == false ]]; then
    if printf '%s\n' "${plan[@]}" | grep -qx 310; then
      log "A religar VM310 (Ollama)..."
      run_on_host qm start 310 2>/dev/null || log "AVISO: qm start 310 falhou — verificar manualmente"
    fi
  fi

  log "Concluído: ok=${ok} failed=${failed}"
  [[ "$failed" -eq 0 ]]
}

if [[ "$REMOTE" == true && "$DRY_RUN" == false ]]; then
  scp -q "$0" "${AGLSRV3_SSH}:/root/aglsrv3-vzdump-sequential.sh"
  ssh -o BatchMode=yes "$AGLSRV3_SSH" "bash /root/aglsrv3-vzdump-sequential.sh --apply $(
    [[ "$STOP_VM310" == false ]] && echo --keep-vm310-running
    for s in "${SKIP_IDS[@]}"; do echo --skip "$s"; done
  )"
else
  main "$@"
fi
