#!/usr/bin/env bash
# Valida que o cliente está configurado corretamente para LiteLLM
# Erro 401 "expected to start with sk-" = ANTHROPIC_* está com ZAI_API_KEY (896f...)
# Uso: ./scripts/litellm/validate-client-auth.sh

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$REPO_ROOT/config/litellm/.env"

echo "=== Validação LiteLLM Client Auth ==="
echo ""

# 1. LITELLM_MASTER_KEY
MASTER_KEY=""
if [[ -f "$ENV_FILE" ]]; then
  MASTER_KEY=$(grep "^LITELLM_MASTER_KEY=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
fi
MASTER_KEY="${MASTER_KEY:-sk-litellm-default}"

if [[ "$MASTER_KEY" != sk-* ]]; then
  echo "❌ LITELLM_MASTER_KEY deve começar com 'sk-' (atual: ${MASTER_KEY:0:8}...)"
  echo "   Edite config/litellm/.env e defina LITELLM_MASTER_KEY=sk-sua-chave"
  exit 1
fi
echo "✓ LITELLM_MASTER_KEY OK (sk-...)"

# 2. Variáveis do cliente
if [[ -n "$ANTHROPIC_API_KEY" && "$ANTHROPIC_API_KEY" != sk-* ]]; then
  echo "❌ ANTHROPIC_API_KEY está com formato errado (${ANTHROPIC_API_KEY:0:8}...)"
  echo "   Para LiteLLM use: export ANTHROPIC_API_KEY=\"$MASTER_KEY\""
  echo "   NÃO use ZAI_API_KEY/GLM_AUTH aqui!"
  exit 1
fi

if [[ -n "$ANTHROPIC_AUTH_TOKEN" && "$ANTHROPIC_AUTH_TOKEN" != sk-* ]]; then
  echo "❌ ANTHROPIC_AUTH_TOKEN está com formato errado"
  echo "   Para LiteLLM use: export ANTHROPIC_AUTH_TOKEN=\"$MASTER_KEY\""
  exit 1
fi

echo "✓ ANTHROPIC_* OK (ou não definido)"
echo ""
echo "Para configurar o shell:"
echo "  export ANTHROPIC_BASE_URL=http://localhost:4000"
echo "  export ANTHROPIC_AUTH_TOKEN=\"$MASTER_KEY\""
echo "  export ANTHROPIC_API_KEY=\"$MASTER_KEY\""
echo ""
echo "Ou: source $REPO_ROOT/config/openclaw/zshrc-openclaw.env"
echo ""
