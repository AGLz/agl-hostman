#!/usr/bin/env bash
# =============================================================================
# Smoke test dos modelos expostos no LiteLLM (Composer, GLM, DashScope, OpenRouter :free)
# Uso: ./scripts/litellm/test-all-models.sh [gateway_url]
#      gateway_url default: http://localhost:4000 (ou LITELLM_GATEWAY_URL)
# OpenRouter :free: timeouts longos; 429/rate limit conta como aviso (não falha dura).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATEWAY="${1:-${LITELLM_GATEWAY_URL:-http://localhost:4000}}"
KEY="$("$REPO_ROOT/.claude/helpers/get-litellm-key.sh" 2>/dev/null)"
KEY="${KEY:-sk-litellm-default}"

BASE="${GATEWAY%/}"
if [[ "$BASE" == *"/v1" ]]; then
  CHAT_URL="${BASE}/chat/completions"
else
  CHAT_URL="${BASE}/v1/chat/completions"
fi

# Modelos a testar
declare -a MODELS=(
  "cursor-composer"
  "cursor-composer-2-fast"
  "cursor-claude-sonnet"
  "cursor-claude-opus"
  "cursor-glm-5"
  "cursor-deepseek"
  "openrouter-free"
  "or-qwen3-coder-free"
  "or-gemma-3-4b-free"
  "glm"
  "glm-flash"
  "deepseek"
  "qwen3.5-plus"
  "qwen3-max"
  "qwen-plus"
)

PASS=0
FAIL=0
WARN=0
FAILED_MODELS=()
WARNED_MODELS=()

is_rate_limit() {
  local blob="$1"
  grep -qiE '429|rate.?limit|rate-?limited|temporarily rate|too many requests|provider returned error.*429' <<<"$blob"
}

# Resposta OK: sem .error, com choice e texto em content ou reasoning_content (OpenRouter :free com reasoning)
smoke_ok() {
  local json="$1"
  echo "$json" | jq -e '
    (.error == null) and (.choices | length > 0) and (
      ((.choices[0].message.content // "") | length > 0)
      or ((.choices[0].message.reasoning_content // "") | length > 2)
    )
  ' >/dev/null 2>&1
}

snippet() {
  local json="$1"
  echo "$json" | jq -r '
    .choices[0].message.content // .choices[0].message.reasoning_content // empty
  ' 2>/dev/null | head -c 80
}

echo "=== Teste LiteLLM - Smoke dos modelos ==="
echo "Gateway: $CHAT_URL"
echo ""

for model in "${MODELS[@]}"; do
  case "$model" in
    openrouter-free) timeout=150; maxtok=256 ;;
    or-*-free) timeout=120; maxtok=256 ;;
    *) timeout=50; maxtok=16 ;;
  esac
  case "$model" in
    cursor-claude-opus) timeout=75 ;;
  esac

  start=$(date +%s)
  resp=$(curl -sS --max-time "$timeout" -X POST "$CHAT_URL" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas com a palavra OK, sem explicação.\"}],\"max_tokens\":$maxtok}" 2>/dev/null || true)
  end=$(date +%s)
  elapsed=$((end - start))

  if smoke_ok "$resp"; then
    content=$(snippet "$resp")
    echo "  ✅ $model (${elapsed}s): $content"
    ((PASS++)) || true
  else
    err=$(echo "$resp" | jq -r '.error.message // .error // empty' 2>/dev/null | head -c 200)
    [[ -z "$err" || "$err" == "empty" ]] && err=$(head -c 200 <<<"$resp")
    combined="$err $resp"
    if is_rate_limit "$combined"; then
      echo "  ⚠️  $model (${elapsed}s): rate limit / 429 (comum em :free OpenRouter)"
      ((WARN++)) || true
      WARNED_MODELS+=("$model")
    else
      echo "  ❌ $model (${elapsed}s): $err"
      ((FAIL++)) || true
      FAILED_MODELS+=("$model")
    fi
  fi
done

echo ""
echo "=== Resumo: $PASS OK | $FAIL falha(s) grave(s) | $WARN aviso(s) (429/rate limit) ==="
if [[ ${#WARNED_MODELS[@]} -gt 0 ]]; then
  echo "Avisos: ${WARNED_MODELS[*]}"
fi
if [[ ${#FAILED_MODELS[@]} -gt 0 ]]; then
  echo "Falharam: ${FAILED_MODELS[*]}"
fi
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
