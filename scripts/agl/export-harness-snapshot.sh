#!/usr/bin/env bash
# Exporta snapshot harness para Laravel Mission Control (storage/app/harness).
#
# Uso:
#   bash scripts/agl/export-harness-snapshot.sh
#   bash scripts/agl/export-harness-snapshot.sh --run-governor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STORAGE_DIR="${HARNESS_STORAGE_DIR:-$REPO_ROOT/src/storage/app/harness}"
STATE_FILE="${HARNESS_STATE_FILE:-$STORAGE_DIR/quota-governor-state.json}"
RUN_GOVERNOR=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-governor) RUN_GOVERNOR=1; shift ;;
    -h|--help)
      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$STORAGE_DIR"

if [[ "$RUN_GOVERNOR" -eq 1 ]]; then
  GOVERNOR_ENV="${GOVERNOR_ENV:-/etc/agl-hostman/quota-governor.env}" \
    GOVERNOR_STATE_FILE="$STATE_FILE" \
    bash "$REPO_ROOT/scripts/litellm/quota-governor.sh" --json >/dev/null || true
elif [[ ! -f "$STATE_FILE" ]]; then
  cp "$REPO_ROOT/config/monitoring/quota-governor-state.example.json" "$STATE_FILE"
  echo "[export-harness] seed example state → $STATE_FILE"
fi

echo "[export-harness] OK state=$STATE_FILE"
echo "[export-harness] UI: /mission-control/harness · API: /api/harness/snapshot"
