#!/usr/bin/env bash
# Orquestra a bateria paralela LiteLLM (health, model list, chats).
# Uso:
#   ./scripts/litellm/run-litellm-battery.sh [URL] [--tier quick|standard|full] [--concurrency N] [--json] [--dry-probe]
#   ./scripts/litellm/run-litellm-battery.sh [URL] --export-dir docs/litellm-battery [--filter-provider ollama]
# Env: LITELLM_MASTER_KEY, LITELLM_GATEWAY_URL, LITELLM_BATTERY_EXPORT_DIR
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == http://* || "${1:-}" == https://* ]]; then
  GATEWAY="$1"
  shift
else
  GATEWAY="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
fi

DEFAULT_EXPORT="${LITELLM_BATTERY_EXPORT_DIR:-$REPO_ROOT/docs/litellm-battery}"
HAS_EXPORT=0
for arg in "$@"; do
  if [[ "$arg" == "--no-export" || "$arg" == "--dry-probe" ]]; then
    HAS_EXPORT=1
    break
  fi
  if [[ "$arg" == "--export-dir" ]]; then
    HAS_EXPORT=1
    break
  fi
done

EXTRA=()
if [[ "$HAS_EXPORT" -eq 0 ]]; then
  EXTRA=(--export-dir "$DEFAULT_EXPORT")
fi

exec node "$REPO_ROOT/scripts/litellm/litellm-full-battery.js" --base "${GATEWAY%/}" "${EXTRA[@]}" "$@"
