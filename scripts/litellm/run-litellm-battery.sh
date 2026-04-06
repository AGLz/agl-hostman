#!/usr/bin/env bash
# Orquestra a bateria paralela LiteLLM (health, model list, chats).
# Uso:
#   ./scripts/litellm/run-litellm-battery.sh [URL] [--tier quick|standard|full] [--concurrency N] [--json] [--dry-probe]
# Env: LITELLM_MASTER_KEY, LITELLM_GATEWAY_URL (default base se não passar URL)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == http://* || "${1:-}" == https://* ]]; then
  GATEWAY="$1"
  shift
else
  GATEWAY="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
fi

exec node "$REPO_ROOT/scripts/litellm/litellm-full-battery.js" --base "${GATEWAY%/}" "$@"
