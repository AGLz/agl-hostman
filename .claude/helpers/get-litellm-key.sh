#!/bin/sh
# apiKeyHelper para Claude Code + LiteLLM
# Retorna LITELLM_MASTER_KEY do config/litellm/.env
# Ref: docs/CLAUDE-FLOW-LITELLM.md
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/config/litellm/.env"
if [ -f "$ENV_FILE" ]; then
  grep "^LITELLM_MASTER_KEY=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-
fi
