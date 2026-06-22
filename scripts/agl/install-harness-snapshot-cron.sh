#!/usr/bin/env bash
# Instala cron para exportar snapshot Harness → Laravel Mission Control (agldv03).
#
# Uso:
#   sudo bash scripts/agl/install-harness-snapshot-cron.sh
#   sudo bash scripts/agl/install-harness-snapshot-cron.sh --test-run
#   sudo bash scripts/agl/install-harness-snapshot-cron.sh --uninstall
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
EXPORT_SCRIPT="$REPO_ROOT/scripts/agl/export-harness-snapshot.sh"
GOVERNOR_SCRIPT="$REPO_ROOT/scripts/litellm/quota-governor.sh"
CRON_FILE="/etc/cron.d/agl-hostman-harness-snapshot"
LOG_DIR="/var/log/hostman"
ENV_DIR="/etc/agl-hostman"
ENV_FILE="${ENV_DIR}/quota-governor.env"
SCHEDULE="${HARNESS_SNAPSHOT_CRON_SCHEDULE:-*/10 * * * *}"

TEST_RUN=0
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-run) TEST_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  rm -f "$CRON_FILE"
  echo "OK removido $CRON_FILE"
  exit 0
fi

[[ -f "$EXPORT_SCRIPT" ]] || { echo "ERRO: falta $EXPORT_SCRIPT" >&2; exit 1; }
[[ -f "$GOVERNOR_SCRIPT" ]] || { echo "ERRO: falta $GOVERNOR_SCRIPT" >&2; exit 1; }
chmod +x "$EXPORT_SCRIPT" "$GOVERNOR_SCRIPT" 2>/dev/null || true

mkdir -p "$LOG_DIR" "$ENV_DIR" "$REPO_ROOT/src/storage/app/harness"

if [[ ! -f "$ENV_FILE" && -f "$REPO_ROOT/config/monitoring/quota-governor.env.example" ]]; then
  install -m 0600 "$REPO_ROOT/config/monitoring/quota-governor.env.example" "$ENV_FILE"
  echo "AVISO: editar $ENV_FILE (LITELLM_MASTER_KEY, GOVERNOR_*)"
fi

cat >"$CRON_FILE" <<EOF
# AGL Hostman — Harness snapshot + quota governor (Mission Control)
# Repo: $REPO_ROOT
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
GOVERNOR_ENV=$ENV_FILE
HARNESS_STORAGE_DIR=$REPO_ROOT/src/storage/app/harness
$SCHEDULE root cd $REPO_ROOT && bash $EXPORT_SCRIPT --run-governor >> $LOG_DIR/harness-snapshot.log 2>&1
EOF

chmod 644 "$CRON_FILE"
echo "OK cron instalado: $CRON_FILE"
echo "Schedule: $SCHEDULE (override: HARNESS_SNAPSHOT_CRON_SCHEDULE)"
echo "Log: $LOG_DIR/harness-snapshot.log"
echo "State: $REPO_ROOT/src/storage/app/harness/quota-governor-state.json"
echo "UI: /mission-control/harness"

if [[ "$TEST_RUN" -eq 1 ]]; then
  echo ""
  echo "=== Test run (export + governor skip-probe se env em falta) ==="
  cd "$REPO_ROOT"
  HARNESS_STORAGE_DIR="$REPO_ROOT/src/storage/app/harness" bash "$EXPORT_SCRIPT" --run-governor
  echo ""
  echo "=== Snapshot head ==="
  head -c 400 "$REPO_ROOT/src/storage/app/harness/quota-governor-state.json" 2>/dev/null || true
  echo ""
fi
