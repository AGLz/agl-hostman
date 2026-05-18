#!/usr/bin/env bash
# cclitellm — Configura Claude Code / Claude-Flow para usar LiteLLM
# Uso: source scripts/cclitellm.sh   ou   . scripts/cclitellm.sh
# Ref: docs/LITELLM-TROUBLESHOOTING.md

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$("$REPO_ROOT/.claude/helpers/get-litellm-key.sh")"

if [[ -z "$KEY" ]]; then
  echo "⚠️  cclitellm: LITELLM_MASTER_KEY não encontrado em config/litellm/.env ou /opt/litellm/.env"
  echo "   Usando fallback sk-litellm-default (pode falhar com 401)"
  KEY="sk-litellm-default"
fi

export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
export ANTHROPIC_BASE_URL="${LITELLM_GATEWAY_URL}"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_API_KEY="$KEY"

echo "✓ Claude Code/Claude-Flow → LiteLLM ($LITELLM_GATEWAY_URL)"
