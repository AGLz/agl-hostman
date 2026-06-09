#!/usr/bin/env bash
# =============================================================================
# Benchmark de múltiplos modelos em todos os hosts — mede latência e ordena
# Inclui modelos gratuitos: glm-flash, glm-air, qwen-turbo, qwen-plus, qwen3.5-plus
# Uso: ./scripts/litellm/benchmark-models-all-hosts.sh
#      ./scripts/litellm/benchmark-models-all-hosts.sh --free  # apenas gratuitos
# Consolidado (tabela comparativa): ./scripts/litellm/benchmark-consolidate.sh [--free]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

# Modelos: pagos + gratuitos (qwen, glm-air, glm-flash)
MODELS_FULL="glm-flash glm deepseek claude-haiku gemini-2.0 qwen-turbo qwen-plus glm-air qwen3.5-plus"
MODELS_FREE="glm-flash glm-air qwen-turbo qwen-plus qwen3.5-plus"

[[ "${1:-}" == "--free" ]] && MODELS="$MODELS_FREE" || MODELS="$MODELS_FULL"

echo "=== Benchmark multi-model em todos os hosts ==="
echo "Modelos: $MODELS"
echo ""

for host in ct186 agldv04 agldv12 fgsrv06; do
  ip="${LITELLM_HOST_IPS[$host]}"
  env_dir="$(litellm_remote_dir "$host")"
  echo "--- $host ($ip) ---"

  ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" "ENV_DIR=${env_dir} bash -s" -- $MODELS <<'REMOTE'
    KEY=$(grep "^LITELLM_MASTER_KEY=" "${ENV_DIR}/.env" 2>/dev/null | cut -d= -f2-)
    KEY="${KEY:-sk-litellm-default}"
    tmp=$(mktemp)
    for m in "$@"; do
      p="{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas: OK\"}],\"max_tokens\":10}"
      start=$(date +%s%3N)
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 45 -X POST http://localhost:4000/chat/completions \
        -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d "$p" 2>/dev/null)
      end=$(date +%s%3N)
      elapsed=$((end - start))
      if [[ "$code" == "200" ]]; then
        printf "%d %s\n" $elapsed "$m" >> "$tmp"
      else
        printf "999999 %s %s\n" "$m" "$code" >> "$tmp"
      fi
    done
    sort -n "$tmp" | while read ms name rest; do
      [[ "$ms" -lt 999999 ]] 2>/dev/null && echo "  $name: ${ms}ms" || echo "  $name: falhou (HTTP ${rest:-?})"
    done
    rm -f "$tmp"
REMOTE

  echo ""
done

echo "=== Resumo: modelos listados por latência (ms) — menor = mais rápido ==="
