#!/usr/bin/env bash
# Restaura entradas Ollama VM310 no config LiteLLM e deploy CT186.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SRC="${REPO}/config/litellm/config.yaml"
BACKUP="${REPO}/config/litellm/config.yaml.bak.groq-failover"
PATCHED="${REPO}/config/litellm/config.yaml.vm310-ollama"

log() { echo "[litellm-vm310] $*"; }

if [[ ! -f "$SRC" ]]; then
  echo "ERRO: falta $SRC" >&2
  exit 1
fi

if [[ ! -f "$BACKUP" ]] && grep -q "model: groq/llama-3.1-8b-instant" "$SRC" 2>/dev/null; then
  log "Backup Groq → $BACKUP"
  cp -a "$SRC" "$BACKUP"
fi

python3 "${REPO}/scripts/litellm/patch_config_vm310_ollama.py" "$SRC" "$PATCHED"
cp -a "$PATCHED" "$SRC"

log "Pre-warm VM310 (best effort)..."
bash "${REPO}/scripts/aglsrv3/prewarm-vm310-dual-ollama.sh" || log "AVISO: pre-warm falhou — continuar deploy"

bash "${REPO}/scripts/litellm/deploy-litellm-callbacks-ct186.sh"

log "Smoke Ollama via LiteLLM..."
ssh root@100.125.249.8 'LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh agl-primary'
ssh root@100.125.249.8 'LITELLM_ENV_FILE=/opt/agl-litellm/.env LITELLM_URL=http://127.0.0.1:4000 bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh agl-primary-strong'

log "Concluído."
