#!/usr/bin/env bash
# Testar modelos FREE diretamente nos providers (SEM LiteLLM)
# Uso: ./scripts/test-direct-providers.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testando ACESSO DIRETO aos Providers FREE ===${NC}"
echo ""

# Verificar API keys
if [[ -z "$ZAI_API_KEY" ]]; then
  echo -e "${RED}ERRO: ZAI_API_KEY não definida${NC}"
  echo "  export ZAI_API_KEY='sua-chave'"
  exit 1
fi

if [[ -z "$DASHSCOPE_API_KEY" ]]; then
  echo -e "${RED}ERRO: DASHSCOPE_API_KEY não definida${NC}"
  echo "  export DASHSCOPE_API_KEY='sua-chave'"
  exit 1
fi

if [[ -z "$OPENROUTER_API_KEY" ]]; then
  echo -e "${RED}ERRO: OPENROUTER_API_KEY não definida${NC}"
  echo "  export OPENROUTER_API_KEY='sua-chave'"
  exit 1
fi

# Função de teste
test_provider() {
  local name=$1
  local url=$2
  local api_key=$3
  local model=$4
  local api_type=$5

  echo -e "${BLUE}=== $name ===${NC}"
  echo -n "  Testando $model... "

  if [[ "$api_type" == "anthropic" ]]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
      -H "x-api-key: $api_key" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"$model\",
        \"max_tokens\": 20,
        \"messages\": [{\"role\": \"user\", \"content\": \"Say 'OK'\"}]
      }" 2>&1)
  else
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"$model\",
        \"max_tokens\": 20,
        \"messages\": [{\"role\": \"user\", \"content\": \"Say 'OK'\"}]
      }" 2>&1)
  fi

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    if [[ "$api_type" == "anthropic" ]]; then
      content=$(echo "$body" | jq -r '.content[0].text' 2>/dev/null || echo "parse error")
    else
      content=$(echo "$body" | jq -r '.choices[0].message.content' 2>/dev/null || echo "parse error")
    fi
    echo -e "${GREEN}OK${NC} - $content"
    return 0
  elif [[ "$http_code" == "401" ]]; then
    echo -e "${RED}FAIL${NC} - Auth error (check API key)"
    return 1
  elif [[ "$http_code" == "429" ]]; then
    echo -e "${YELLOW}RATE LIMITED${NC}"
    return 2
  else
    error=$(echo "$body" | jq -r '.error.message // .error // "unknown error"' 2>/dev/null || echo "$body")
    echo -e "${RED}FAIL${NC} - $error"
    return 1
  fi
}

# Testar ZAI GLM-4.7-Flash (FREE)
test_provider \
  "ZAI (GLM-4.7-Flash FREE)" \
  "https://api.z.ai/api/anthropic/v1/messages" \
  "$ZAI_API_KEY" \
  "glm-4.7-flash" \
  "anthropic"

echo ""

# Testar Qwen via DashScope Singapore (FREE)
test_provider \
  "DashScope Singapore (Qwen-Coder FREE)" \
  "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
  "$DASHSCOPE_API_KEY" \
  "qwen3-coder-plus" \
  "openai"

test_provider \
  "DashScope Singapore (Qwen3.5-Plus FREE)" \
  "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
  "$DASHSCOPE_API_KEY" \
  "qwen3.5-plus" \
  "openai"

test_provider \
  "DashScope Singapore (Qwen-Turbo FREE)" \
  "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
  "$DASHSCOPE_API_KEY" \
  "qwen-turbo" \
  "openai"

echo ""

# Testar OpenRouter :free models
test_provider \
  "OpenRouter (Llama 3.3 70B :free)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "meta-llama/llama-3.3-70b-instruct:free" \
  "openai"

test_provider \
  "OpenRouter (Nemotron 3 Super :free)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "nvidia/nemotron-3-super-120b-a12b:free" \
  "openai"

test_provider \
  "OpenRouter (MiniMax M2.5 :free)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "minimax/minimax-m2.5:free" \
  "openai"

test_provider \
  "OpenRouter (Step 3.5 Flash :free)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "stepfun/step-3.5-flash:free" \
  "openai"

test_provider \
  "OpenRouter (Gemma 3 4B :free)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "google/gemma-3-4b-it:free" \
  "openai"

test_provider \
  "OpenRouter (Free Router)" \
  "https://openrouter.ai/api/v1/chat/completions" \
  "$OPENROUTER_API_KEY" \
  "openrouter/free" \
  "openai"

echo ""
echo -e "${BLUE}=== Resumo ===${NC}"
echo ""
echo "✅ Testados providers com ACESSO DIRETO (SEM LiteLLM)"
echo ""
echo "Endpoints testados:"
echo "  1. ZAI: https://api.z.ai/api/anthropic"
echo "  2. DashScope: https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
echo "  3. OpenRouter: https://openrouter.ai/api/v1"
echo ""
echo "📋 Próximos passos:"
echo "   - Se todos passaram: OpenClaw deve funcionar com acesso direto"
echo "   - Testar OpenClaw: openclaw 'Hello'"
