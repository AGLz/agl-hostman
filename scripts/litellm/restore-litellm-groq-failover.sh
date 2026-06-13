#!/usr/bin/env bash
# Restaura config LiteLLM Groq/OpenRouter (failover VM310 suspenso).
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SRC="${REPO}/config/litellm/config.yaml"
BACKUP="${REPO}/config/litellm/config.yaml.bak.groq-failover"

if [[ ! -f "$BACKUP" ]]; then
  echo "ERRO: backup não encontrado: $BACKUP" >&2
  echo "Restaurar manualmente a partir de git ou config.yaml.vm110-plan-c invertido." >&2
  exit 1
fi

cp -a "$BACKUP" "$SRC"
echo "OK: config.yaml restaurado de $BACKUP"
echo "Deploy: bash scripts/litellm/deploy-litellm-callbacks-ct186.sh"
