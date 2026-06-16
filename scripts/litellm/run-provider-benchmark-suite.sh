#!/usr/bin/env bash
# Regenera manifest + opcionalmente corre bateria ou benchmark comparativo.
# Uso:
#   ./scripts/litellm/run-provider-benchmark-suite.sh manifest
#   ./scripts/litellm/run-provider-benchmark-suite.sh battery [--tier full] [--json]
#   ./scripts/litellm/run-provider-benchmark-suite.sh compare [--providers groq,openrouter,zai]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
ENV_FILE="${LITELLM_ENV_FILE:-/opt/agl-litellm/.env}"

cmd="${1:-manifest}"
shift || true

case "$cmd" in
  manifest)
    exec python3 "$REPO_ROOT/scripts/litellm/generate-battery-manifest.py" \
      --out "$REPO_ROOT/scripts/litellm/litellm-battery-manifest.json" "$@"
    ;;
  battery)
    python3 "$REPO_ROOT/scripts/litellm/generate-battery-manifest.py" \
      --out "$REPO_ROOT/scripts/litellm/litellm-battery-manifest.json"
    exec "$REPO_ROOT/scripts/litellm/run-litellm-battery.sh" "$GATEWAY" "$@"
    ;;
  compare)
    export LITELLM_URL="${LITELLM_URL:-$GATEWAY}"
    if [[ -f "$ENV_FILE" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$ENV_FILE"
      set +a
    fi
    export LITELLM_KEY="${LITELLM_KEY:-${LITELLM_MASTER_KEY:-}}"
    exec python3 "$REPO_ROOT/scripts/litellm/benchmark-provider-comparison.py" "$@"
    ;;
  *)
    echo "Uso: $0 {manifest|battery|compare} [args...]" >&2
    exit 2
    ;;
esac
