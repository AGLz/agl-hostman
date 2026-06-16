#!/usr/bin/env bash
# Liberta espaço em disco no CT188 (Hermes + Docker).
#
# Uso (root no CT188):
#   bash cleanup-hermes-disk-ct188.sh
#   bash cleanup-hermes-disk-ct188.sh --dry-run

set -euo pipefail

DRY="${1:-}"
INSTALL_CRON=""
if [[ "${DRY}" == "--install-cron" ]]; then
  INSTALL_CRON="--install-cron"
  DRY=""
elif [[ "${1:-}" == "--dry-run" ]]; then
  DRY="--dry-run"
fi
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATA="${HERMES_ROOT}/data"
DAYS_CRON="${DAYS_CRON:-14}"

run() {
  if [[ "${DRY}" == "--dry-run" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

echo "=== Antes ==="
df -h / | tail -1

echo "=== 1/6 /tmp nos contentores Hermes (GGUF órfãos) ==="
for c in agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner; do
  if docker ps --format '{{.Names}}' | grep -qx "${c}"; then
    sz_before="$(docker exec "${c}" du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)"
    run docker exec "${c}" bash -c 'rm -f /tmp/*.gguf /tmp/*.bin /tmp/*.safetensors 2>/dev/null; find /tmp -maxdepth 1 -type f -size +500M -mtime +1 -delete 2>/dev/null || true'
    sz_after="$(docker exec "${c}" du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)"
    echo "  ${c}: /tmp ${sz_before}MB → ${sz_after}MB"
  fi
done

echo "=== 2/6 Cron output antigo (>${DAYS_CRON}d) ==="
find "${DATA}/cron/output" -type f -mtime +"${DAYS_CRON}" -print 2>/dev/null | wc -l | xargs -I{} echo "  ficheiros a apagar: {}"
run find "${DATA}/cron/output" -type f -mtime +"${DAYS_CRON}" -delete 2>/dev/null || true
run find "${DATA}/cron/output" -type d -empty -delete 2>/dev/null || true

echo "=== 3/6 Backups zip antigos em data/home ==="
run find "${DATA}/home" -maxdepth 1 -name 'hermes-backup-*.zip' -mtime +7 -delete 2>/dev/null || true
run rm -rf "${DATA}/backup-hermes-v015-"* 2>/dev/null || true

echo "=== 4/6 node_modules duplicado em agl-hostman-work ==="
if [[ -d "${DATA}/agl-hostman-work/node_modules" ]]; then
  run rm -rf "${DATA}/agl-hostman-work/node_modules"
  echo "  removido agl-hostman-work/node_modules (~100MB+)"
fi

echo "=== 5/6 Docker build cache + imagens dangling ==="
if [[ "${DRY}" != "--dry-run" ]]; then
  docker builder prune -af --filter 'until=72h' 2>/dev/null || docker builder prune -af 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
fi

echo "=== 6/6 SQLite WAL checkpoint (state.db) ==="
if [[ -f "${DATA}/state.db" ]] && [[ "${DRY}" != "--dry-run" ]]; then
  sqlite3 "${DATA}/state.db" 'PRAGMA wal_checkpoint(TRUNCATE);' 2>/dev/null || true
fi

echo ""
echo "=== Depois ==="
df -h / | tail -1
du -sh "${DATA}" /var/lib/docker 2>/dev/null | head -5

if [[ "${INSTALL_CRON}" == "--install-cron" ]]; then
  SCRIPT_PATH="$(readlink -f "$0")"
  LINE="0 3 * * 0 root ${SCRIPT_PATH} >/var/log/hermes-disk-cleanup.log 2>&1"
  if ! grep -qF "${SCRIPT_PATH}" /etc/cron.d/hermes-disk-cleanup 2>/dev/null; then
    printf '%s\n' "${LINE}" > /etc/cron.d/hermes-disk-cleanup
    chmod 644 /etc/cron.d/hermes-disk-cleanup
    echo "OK cron semanal /etc/cron.d/hermes-disk-cleanup (domingo 03:00)"
  fi
fi
