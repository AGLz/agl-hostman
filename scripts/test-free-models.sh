#!/usr/bin/env bash
# Testar modelos gratuitos via LiteLLM Gateway (localhost:4000)
# Uso: ./scripts/test-free-models.sh

set -e

GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
API_KEY="${LITELLM_API_KEY:-sk-litellm-default}"

echo "=== Testando modelos GRATUITOS via LiteLLM Gateway ==="
echo "Gateway: $GATEWAY_URL"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_model() {
  local model=$1
  local provider=$2
  echo -n "  $model ($provider)... "

  response=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY_URL/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$model\",
      \"messages\": [{\"role\": \"user\", \"content\": \"Say 'OK' in one word\"}],
      \"max_tokens\": 5
    }" 2>&1)

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    content=$(echo "$body" | jq -r '.choices[0].message.content' 2>/dev/null || echo "parse error")
    echo -e "${GREEN}OK${NC} - $content"
    return 0
  elif [[ "$http_code" == "401" ]]; then
    echo -e "${RED}FAIL${NC} - Auth error (check API key)"
    return 1
  elif [[ "$http_code" == "429" ]]; then
    echo -e "${YELLOW}RATE LIMITED${NC}"
    return 2
  elif [[ "$http_code" == "502" ]] || [[ "$http_code" == "503" ]]; then
    echo -e "${RED}FAIL${NC} - Service unavailable"
    return 1
  else
    error=$(echo "$body" | jq -r '.error.message // .error // "unknown error"' 2>/dev/null || echo "$body")
    echo -e "${RED}FAIL${NC} - $error"
    return 1
  fi
}

echo "=== ZAI/GLM (FREE) ==="
test_model "zai/glm-4.7-flash" "ZAI"
test_model "glm-4.7-flash" "ZAI"
test_model "glm-flash" "ZAI"
echo ""

echo "=== Qwen/DashScope Singapore (FREE) ==="
test_model "qwen/qwen-coder" "DashScope"
test_model "qwen/qwen3.5-plus" "DashScope"
test_model "qwen/qwen-turbo" "DashScope"
test_model "qwen-coder" "DashScope"
test_model "qwen3.5-plus" "DashScope"
test_model "qwen-turbo" "DashScope"
echo ""

echo "=== OpenRouter :free (NVIDIA) ==="
test_model "openrouter/nvidia/nemotron-3-super-120b-a12b:free" "OpenRouter"
test_model "openrouter/nvidia/nemotron-nano-12b-v2-vl:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (MiniMax) ==="
test_model "openrouter/minimax/minimax-m2.5:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (Meta Llama) ==="
test_model "openrouter/meta-llama/llama-3.3-70b-instruct:free" "OpenRouter"
test_model "openrouter/meta-llama/llama-3.2-3b-instruct:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (StepFun) ==="
test_model "openrouter/stepfun/step-3.5-flash:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (Google Gemma) ==="
test_model "openrouter/google/gemma-3-4b-it:free" "OpenRouter"
test_model "openrouter/google/gemma-3-12b-it:free" "OpenRouter"
test_model "openrouter/google/gemma-3-27b-it:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (Mistral) ==="
test_model "openrouter/mistralai/mistral-small-3.1-24b-instruct:free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (NousResearch) ==="
test_model "openrouter/nousresearch/hermes-3-llama-3.1-405b:free" "OpenRouter"
echo ""

echo "=== OpenRouter FREE Router (inteligente) ==="
test_model "openrouter/openrouter/free" "OpenRouter"
echo ""

echo "=== OpenRouter :free (Z.AI GLM Air) ==="
test_model "openrouter/z-ai/glm-4.5-air:free" "OpenRouter"
echo ""

echo "=== Resumo ==="
echo "Modelos FREE recomendados para agldv03, fgsrv06, aglwk45:"
echo ""
echo "  PRIMÁRIO (rápido, bom contexto):"
echo "    1. zai/glm-4.7-flash (GLM 4.7 Flash - FREE via ZAI)"
echo "    2. qwen/qwen-coder (Qwen3 Coder Plus - FREE via DashScope Singapore)"
echo "    3. qwen/qwen3.5-plus (Qwen3.5 Plus 1M ctx - FREE via DashScope Singapore)"
echo ""
echo "  FALLBACK (OpenRouter :free):"
echo "    4. openrouter/nvidia/nemotron-3-super-120b-a12b:free (262K ctx)"
echo "    5. openrouter/minimax/minimax-m2.5:free (196K ctx)"
echo "    6. openrouter/meta-llama/llama-3.3-70b-instruct:free (64K ctx)"
echo "    7. openrouter/stepfun/step-3.5-flash:free"
echo "    8. openrouter/google/gemma-3-27b-it:free"
echo ""
echo "  ROUTER INTELIGENTE:"
echo "    9. openrouter/openrouter/free (seleciona automaticamente)"
