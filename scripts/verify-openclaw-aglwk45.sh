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
