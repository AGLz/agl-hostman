#!/usr/bin/env bash
# Bateria full + export de tempos (CSV, JSONL history, MD).
# VM310 fora → Ollama entra como WARN/timeout (optional). Repetir Ollama: run-litellm-battery-ollama-retry.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${LITELLM_BATTERY_GATEWAY:-http://100.125.249.8:4000}"
EXPORT_DIR="${LITELLM_BATTERY_EXPORT_DIR:-$REPO_ROOT/docs/litellm-battery}"
ENV_FILE="${LITELLM_ENV_FILE:-$REPO_ROOT/config/litellm/.env}"

if [[ -r "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

python3 "$REPO_ROOT/scripts/litellm/generate-battery-manifest.py" \
  --out "$REPO_ROOT/scripts/litellm/litellm-battery-manifest.json"

echo "=== Bateria full — $GATEWAY — export: $EXPORT_DIR ==="
echo "Nota: VM310 offline → aliases ollama/* esperam timeout/WARN"

exec "$REPO_ROOT/scripts/litellm/run-litellm-battery.sh" "$GATEWAY" \
  --tier full \
  --concurrency "${LITELLM_BATTERY_CONCURRENCY:-6}" \
  --export-dir "$EXPORT_DIR" \
  "$@"
