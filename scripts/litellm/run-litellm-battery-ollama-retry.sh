#!/usr/bin/env bash
# Re-teste só modelos Ollama (VM310 / VM110) e acrescenta tempos ao histórico.
# Uso:
#   ./scripts/litellm/run-litellm-battery-ollama-retry.sh
#   ./scripts/litellm/run-litellm-battery-ollama-retry.sh --wait-minutes 20
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${LITELLM_BATTERY_GATEWAY:-http://100.125.249.8:4000}"
EXPORT_DIR="${LITELLM_BATTERY_EXPORT_DIR:-$REPO_ROOT/docs/litellm-battery}"
WAIT_MIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait-minutes)
      WAIT_MIN="${2:-0}"
      shift 2
      ;;
    *)
      echo "Opção desconhecida: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$WAIT_MIN" -gt 0 ]]; then
  echo "Aguardar ${WAIT_MIN} min (janela VM110/VM310)..."
  sleep "$((WAIT_MIN * 60))"
fi

echo "=== Ollama-only battery — $GATEWAY ==="
exec "$REPO_ROOT/scripts/litellm/run-litellm-battery.sh" "$GATEWAY" \
  --tier full \
  --filter-provider ollama \
  --concurrency 2 \
  --export-dir "$EXPORT_DIR"
