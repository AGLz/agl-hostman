#!/bin/sh
# apiKeyHelper para Claude Code + LiteLLM
# Retorna LITELLM_MASTER_KEY de config/litellm/.env ou /opt/litellm/.env
# Ref: docs/CLAUDE-FLOW-LITELLM.md
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Prioridade: /opt/litellm (LiteLLM em execução) > config do repo (dev/bootstrap)
for ENV_FILE in /opt/litellm/.env "$REPO_ROOT/config/litellm/.env"; do
  if [ -f "$ENV_FILE" ]; then
    KEY=$(grep "^LITELLM_MASTER_KEY=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
    if [ -n "$KEY" ]; then
      printf '%s' "$KEY"
      exit 0
    fi
  fi
done
