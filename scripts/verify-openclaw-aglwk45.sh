#!/usr/bin/env bash
# Verificação OpenClaw - AGLWK45 (Windows / Git Bash)
# Executar no Git Bash: bash scripts/verify-openclaw-aglwk45.sh

echo "=== OpenClaw - AGLWK45 ==="
echo ""

# Carregar env
[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env
[[ -f ~/.bashrc ]] && source ~/.bashrc 2>/dev/null

# Versão
if command -v openclaw >/dev/null 2>&1; then
  echo "Versao: $(openclaw --version 2>/dev/null)"
else
  echo "OpenClaw nao encontrado. Instale: npm install -g openclaw"
  exit 1
fi

echo ""
echo "--- Status ---"
openclaw status 2>&1 | head -25

echo ""
echo "--- Modelos (primeiros 12) ---"
openclaw models list 2>&1 | head -12

echo ""
echo "--- LiteLLM Gateway (agldv03) ---"
curl -s -o /dev/null -w "%{http_code}" http://100.94.221.87:4000/health && echo " OK" || echo " Falha"

echo ""
echo "--- Auth /v1/models (401 = chave errada; usar wk45-sync) ---"
K="${LITELLM_MASTER_KEY:-}"
if [[ -z "$K" || "$K" == "sk-litellm-default" ]]; then
  echo "WARN: LITELLM_MASTER_KEY ausente ou sk-litellm-default — esperado 401 no proxy real."
  echo "      Correr: bash scripts/openclaw/wk45-sync-openclaw-litellm.sh"
else
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $K" http://100.94.221.87:4000/v1/models || echo "000")
  echo "HTTP $code (esperado 200 com chave de /opt/litellm/.env no agldv03)"
fi
