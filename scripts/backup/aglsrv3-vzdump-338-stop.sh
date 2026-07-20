#!/usr/bin/env bash
# Backup CT338 (aglfs3) em mode stop — mounts NFS/Samba falham com snapshot.
#
# Uso (no host aglsrv3):
#   ./scripts/backup/aglsrv3-vzdump-338-stop.sh --apply
#   AGLSRV3_SSH=root@100.123.5.81 ./scripts/backup/aglsrv3-vzdump-338-stop.sh --apply --remote
set -euo pipefail
# Reason: cron.d usa PATH mínimo sem /usr/sbin → pct/vzdump falham após o backup
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
STORAGE="${AGLSRV3_PBS_STORAGE:-pbs-aglsrv3-tb}"
NODE="${AGLSRV3_NODE:-aglsrv3}"
LOG_DIR="${AGLSRV3_BACKUP_LOG_DIR:-/var/log/hostman}"
PRUNE="${AGLSRV3_BACKUP_PRUNE:-keep-daily=7,keep-monthly=3,keep-weekly=4,keep-yearly=1}"
VMID=338
APPLY=false
REMOTE=false

log() { echo "[$(date +%H:%M:%S)] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --remote) REMOTE=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--apply] [--remote]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

run_on_host() {
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "$@"
  else
    "$@"
  fi
}

wait_vzdump_idle() {
  log "Aguardar vzdump global lock livre..."
  while run_on_host pgrep -x vzdump >/dev/null; do sleep 15; done
}

prepare_338() {
  log "Desbloquear CT${VMID} (snapshot vzdump órfão)..."
  run_on_host pct unlock "$VMID" 2>/dev/null || true
  if run_on_host pct listsnapshot "$VMID" 2>/dev/null | grep -q vzdump; then
    log "Remover snapshot vzdump órfão..."
    run_on_host pct delsnapshot "$VMID" vzdump 2>/dev/null || true
  fi
}

backup_338_stop() {
  local logfile="${LOG_DIR}/vzdump-338-stop-$(date +%Y%m%d-%H%M%S).log"
  run_on_host mkdir -p "$LOG_DIR"

  prepare_338

  log "Parar CT${VMID} (aglfs3)..."
  if run_on_host pct status "$VMID" 2>/dev/null | grep -q running; then
    run_on_host pct stop "$VMID"
  else
    log "CT${VMID} já parado"
  fi

  log "vzdump ${VMID} mode=stop → ${STORAGE}"
  if run_on_host vzdump "$VMID" --node "$NODE" --storage "$STORAGE" --mode stop \
    --compress zstd --prune-backups "$PRUNE" >>"$logfile" 2>&1; then
    log "OK CT${VMID} → ${logfile}"
    RC=0
  else
    log "FALHA CT${VMID} — ver ${logfile}"
    RC=1
  fi

  log "Reiniciar CT${VMID}..."
  if ! run_on_host pct start "$VMID"; then
    log "AVISO: pct start falhou — tentar pct unlock + start"
    run_on_host pct unlock "$VMID" 2>/dev/null || true
    run_on_host pct start "$VMID" || log "AVISO: CT${VMID} requer intervenção manual"
  fi

  return "$RC"
}

main() {
  if [[ "$APPLY" != true ]]; then
    log "[dry-run] backup CT${VMID} mode=stop storage=${STORAGE}"
    exit 0
  fi

  wait_vzdump_idle
  backup_338_stop
}

if [[ "$REMOTE" == true && "$APPLY" == true ]]; then
  scp -q "$0" "${AGLSRV3_SSH}:/root/aglsrv3-vzdump-338-stop.sh"
  ssh -o BatchMode=yes "$AGLSRV3_SSH" "bash /root/aglsrv3-vzdump-338-stop.sh --apply"
else
  main
fi
