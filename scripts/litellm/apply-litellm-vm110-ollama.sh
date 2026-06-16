#!/usr/bin/env bash
# Aponta aliases Ollama LiteLLM para VM110 (qwen3:4b) e deploy CT186.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SRC="${REPO}/config/litellm/config.yaml"
BACKUP="${REPO}/config/litellm/config.yaml.bak.vm310-ollama"
PATCHED="${REPO}/config/litellm/config.yaml.vm110-qwen3"
VM110_BASE="${VM110_OLLAMA_BASE:-http://100.74.118.51:11434}"

log() { echo "[litellm-vm110] $*"; }

if [[ ! -f "$SRC" ]]; then
  echo "ERRO: falta $SRC" >&2
  exit 1
fi

if [[ ! -f "$BACKUP" ]]; then
  log "Backup VM310 → $BACKUP"
  cp -a "$SRC" "$BACKUP"
fi

curl -sf --max-time 10 "${VM110_BASE}/api/tags" >/dev/null || {
  log "ERRO: Ollama indisponível em $VM110_BASE"
  exit 1
}

export VM110_OLLAMA_BASE="$VM110_BASE"
python3 "${REPO}/scripts/litellm/patch_config_vm110_qwen3.py" "$SRC" "$PATCHED"
cp -a "$PATCHED" "$SRC"

bash "${REPO}/scripts/litellm/deploy-litellm-callbacks-ct186.sh"

log "Smoke Ollama via LiteLLM..."
ssh root@100.125.249.8 "LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh agl-primary"
ssh root@100.125.249.8 "LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh agl-primary-strong"
ssh root@100.125.249.8 "LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh ollama-qwen3-4b"

log "Concluído — VM110 @ $VM110_BASE"
