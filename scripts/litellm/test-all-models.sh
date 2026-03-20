#!/usr/bin/env bash
# =============================================================================
# Testa todos os modelos LiteLLM: Composer, GLM, DeepSeek, Qwen (DashScope), Ollama
# Uso: ./scripts/litellm/test-all-models.sh [gateway_url]
#      gateway_url default: http://localhost:4000 (ou LITELLM_GATEWAY_URL)
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${1:-${LITELLM_GATEWAY_URL:-http://localhost:4000}}"
KEY="$("$REPO_ROOT/.claude/helpers/get-litellm-key.sh" 2>/dev/null)"
KEY="${KEY:-sk-litellm-default}"

# Modelos a testar (grupos: Composer, Cloud, Ollama leve)
# cursor-gpt-4o requer OPENAI_API_KEY em /opt/litellm/.env
# Timeout por modelo: Cloud ~45s, Ollama leve ~60s
declare -a MODELS=(
  # Composer 2 Fast (proxy GPT-5.3 Instant)
  "cursor-composer"
  "cursor-composer-2-fast"
  "cursor-claude-sonnet"
  "cursor-claude-opus"
  "cursor-glm-5"
  "cursor-deepseek"
  "cursor-gpt-4o"
  # Cloud
  "glm"
  "glm-flash"
  "deepseek"
  "qwen3.5-plus"
  "qwen3-max"
  "qwen-plus"
  # Ollama leves (phi3, llama, qwen3-4b)
  "phi3-local"
  "llama-local"
  "qwen3-4b"
)

PASS=0
FAIL=0
declare -a FAILED_MODELS

echo "=== Teste LiteLLM - Todos os modelos ==="
echo "Gateway: $GATEWAY"
echo ""

for model in "${MODELS[@]}"; do
  # Timeout: Ollama 60s, Cloud 45s
  case "$model" in
    phi3-local|llama-local|qwen3-4b) timeout=60 ;;
    *) timeout=45 ;;
  esac

  start=$(date +%s)
  resp=$(curl -s --max-time "$timeout" -X POST "$GATEWAY/chat/completions" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas: OK\"}],\"max_tokens\":10}" 2>/dev/null)
  end=$(date +%s)
  elapsed=$((end - start))

  if echo "$resp" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    content=$(echo "$resp" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 80)
    echo "  ✅ $model (${elapsed}s): $content"
    ((PASS++)) || true
  else
    err=$(echo "$resp" | jq -r '.error.message // .' 2>/dev/null | head -c 100)
    echo "  ❌ $model: $err"
    ((FAIL++)) || true
    FAILED_MODELS+=("$model")
  fi
done

echo ""
echo "=== Resumo: $PASS passaram, $FAIL falharam ==="
if [[ ${#FAILED_MODELS[@]} -gt 0 ]]; then
  echo "Falharam: ${FAILED_MODELS[*]}"
fi
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
