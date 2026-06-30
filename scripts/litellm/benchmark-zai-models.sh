#!/usr/bin/env bash
# Wrapper fino do benchmark Z.AI (Ruflo via LiteLLM).
# Resolve a master key via helper canónico e invoca o harness Python.
#
# Uso:
#   ./scripts/litellm/benchmark-zai-models.sh                 # lista curada Z.AI
#   ./scripts/litellm/benchmark-zai-models.sh --include-traps # + aliases não-Z.AI (contraste)
#   ZAI_MODELS="zai-glm-5,glm-5" ./scripts/litellm/benchmark-zai-models.sh
#
# Env úteis: LITELLM_URL, BENCH_REPEATS, BENCH_PROMPTS, OUT_JSON, OUT_MD
# Resultados (default): docs/litellm-battery/zai-benchmark-<TS>.{json,md}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export LITELLM_URL="${LITELLM_URL:-http://100.125.249.8:4000}"

if [[ -z "${LITELLM_KEY:-}" ]]; then
  LITELLM_KEY="$(sh "$REPO_ROOT/.claude/helpers/get-litellm-key.sh" 2>/dev/null || true)"
  export LITELLM_KEY
fi
if [[ -z "${LITELLM_KEY:-}" ]]; then
  echo "ERRO: não consegui resolver LITELLM_KEY (.claude/helpers/get-litellm-key.sh)." >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --include-traps) export ZAI_INCLUDE_TRAPS=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

exec python3 "$SCRIPT_DIR/benchmark-zai-models.py"
