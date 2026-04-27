#!/usr/bin/env bash
# Testes de multi-model no agldv03: OpenClaw + Claude-Flow (LiteLLM)
# Uso: ./scripts/test-multi-model.sh
# Requer: source ~/.openclaw/zshrc-openclaw.env (ou novo shell)

set -e
source ~/.openclaw/zshrc-openclaw.env 2>/dev/null || true

echo "=== Testes Multi-Model (agldv03) ==="
echo ""

# 1. LiteLLM health
echo "1. LiteLLM Health"
if curl -sf http://localhost:4000/models -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" >/dev/null; then
  echo "   ✅ LiteLLM: UP (porta 4000)"
else
  echo "   ❌ LiteLLM: DOWN - rode: ./scripts/litellm/start.sh"
  exit 1
fi

# 2. Modelos disponíveis
echo ""
echo "2. Modelos LiteLLM"
curl -sf http://localhost:4000/models -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq -r '.data[].id' 2>/dev/null | head -10
echo "   ... (total: $(curl -sf http://localhost:4000/models -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq '.data | length' 2>/dev/null))"

# 3. Teste GLM via LiteLLM (Claude-Flow)
echo ""
echo "3. Claude-Flow/LiteLLM: modelo glm"
resp=$(curl -s -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "glm", "messages": [{"role": "user", "content": "Diga apenas: GLM"}], "max_tokens": 20}' 2>/dev/null)
if echo "$resp" | jq -e '.choices[0]' >/dev/null 2>&1; then
  echo "   ✅ glm: $(echo "$resp" | jq -r '.model')"
else
  echo "   ❌ glm: $(echo "$resp" | jq -r '.error.message // .')"
fi

# 4. Teste Kimi via LiteLLM
echo ""
echo "4. Claude-Flow/LiteLLM: modelo kimi"
resp=$(curl -s -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "kimi", "messages": [{"role": "user", "content": "Diga apenas: Kimi"}], "max_tokens": 15}' 2>/dev/null)
if echo "$resp" | jq -e '.choices[0]' >/dev/null 2>&1; then
  content=$(echo "$resp" | jq -r '.choices[0].message.content // "(vazio)"')
  echo "   ✅ kimi: $content"
else
  echo "   ❌ kimi: $(echo "$resp" | jq -r '.error.message // .')"
fi

# 5. OpenClaw models list
echo ""
echo "5. OpenClaw: modelos configurados"
if command -v openclaw >/dev/null 2>&1; then
  openclaw models list 2>/dev/null | head -8
  echo "   ✅ OpenClaw: $(openclaw models list 2>/dev/null | grep -c 'yes' || echo 0) modelos com auth"
else
  echo "   ⚠️ OpenClaw não instalado"
fi

# 6. Claude CLI (se disponível)
echo ""
echo "6. Claude CLI via LiteLLM"
if command -v claude >/dev/null 2>&1; then
  echo "   Teste manual: claude --model glm \"Olá\""
  echo "   Teste manual: claude --model kimi \"Olá\""
  echo "   Teste manual: claude --model claude-sonnet \"Olá\""
else
  echo "   ⚠️ claude CLI não encontrado"
fi

echo ""
echo "=== Concluído ==="
