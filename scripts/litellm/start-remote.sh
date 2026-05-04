#!/usr/bin/env bash
# Inicia LiteLLM Proxy remoto (conecta ao gateway central)
# Uso: ./scripts/litellm/start-remote.sh
# Requer: config/litellm/.env com OPENROUTER_API_KEY

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/litellm"
ENV_FILE="$CONFIG_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Crie $ENV_FILE a partir de $CONFIG_DIR/.env.example"
  exit 1
fi

# Gateway central (agldv03)
export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"

cd "$REPO_ROOT"

# Usa healthcheck com /health/readiness (sem auth)
docker compose -f docker/litellm/docker-compose.yml up -d

echo ""
echo "LiteLLM Proxy iniciado - conectando ao gateway: $LITELLM_GATEWAY_URL"
echo ""
echo "Configure o Claude Code:"
echo "  export ANTHROPIC_BASE_URL=http://localhost:4000"
echo "  export ANTHROPIC_AUTH_TOKEN=\$(grep LITELLM_MASTER_KEY \$ENV_FILE | cut -d= -f2)"
