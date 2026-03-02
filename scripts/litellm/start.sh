#!/usr/bin/env bash
# Inicia LiteLLM Proxy para Claude-Flow
# Uso: ./scripts/litellm/start.sh
# Requer: config/litellm/.env (copiar de .env.example)

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/litellm"
ENV_FILE="$CONFIG_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "⚠️  Crie $ENV_FILE a partir de $CONFIG_DIR/.env.example"
  echo "   cp $CONFIG_DIR/.env.example $ENV_FILE"
  echo "   # Edite e adicione suas API keys"
  exit 1
fi

cd "$REPO_ROOT"
docker compose -f docker/litellm/docker-compose.yml up -d

echo ""
echo "✅ LiteLLM Proxy iniciado em http://localhost:4000"
echo ""
echo "Configure o Claude Code / Claude-Flow:"
echo "  export ANTHROPIC_BASE_URL=http://localhost:4000"
echo "  export ANTHROPIC_AUTH_TOKEN=\$(grep LITELLM_MASTER_KEY $ENV_FILE | cut -d= -f2)"
echo ""
echo "Teste:"
echo "  claude --model claude-sonnet \"Hello, world!\""
echo "  claude --model glm \"Hello, world!\""
echo "  curl -s http://localhost:4000/models -H \"Authorization: Bearer \$(grep LITELLM_MASTER_KEY $ENV_FILE | cut -d= -f2)\" | jq ."
echo ""
