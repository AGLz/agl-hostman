#!/usr/bin/env bash
# Aplica config LiteLLM Plan C (VM110 Ollama) e deploy CT186.
# Pré-requisito: verify-vm110-gemma4-qat.sh OK na VM110.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SRC="${REPO}/config/litellm/config.yaml"
BACKUP="${REPO}/config/litellm/config.yaml.bak.groq-failover"
PATCHED="${REPO}/config/litellm/config.yaml.vm110-plan-c"
VM110_BASE="${VM110_OLLAMA_BASE:-http://100.116.57.111:11434}"

log() { echo "[litellm-vm110-plan-c] $*"; }

if [[ ! -f "$SRC" ]]; then
  echo "ERRO: falta $SRC" >&2
  exit 1
fi

if [[ ! -f "$BACKUP" ]]; then
  log "Backup Groq failover → $BACKUP"
  cp -a "$SRC" "$BACKUP"
fi

export VM110_OLLAMA_BASE="$VM110_BASE"
python3 "${REPO}/scripts/litellm/patch_config_vm110_plan_c.py" "$SRC" "$PATCHED"

# Deploy patched config (temporário na janela VM110)
cp -a "$PATCHED" "$SRC"
bash "${REPO}/scripts/litellm/deploy-litellm-callbacks-ct186.sh"

log "Smoke CT186:"
LITELLM_ENV_FILE="${LITELLM_ENV_FILE:-/opt/agl-litellm/.env}" \
  LITELLM_URL="${LITELLM_URL:-http://127.0.0.1:4000}" \
  bash "${REPO}/scripts/litellm/test-ollama-litellm-content.sh" agl-primary || true

log "Concluído. Reverter: bash scripts/litellm/restore-litellm-groq-failover.sh"
