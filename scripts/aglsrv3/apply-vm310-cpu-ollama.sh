#!/usr/bin/env bash
# Aplica modo CPU-only ao Ollama VM310 (sem GPU) e opcionalmente redeploy LiteLLM.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
VM310="${VM310_SSH:-root@100.67.253.52}"
SRC="${REPO}/scripts/aglsrv3/vm310-ollama-cpu-override.conf"
DEPLOY_LITELLM="${DEPLOY_LITELLM:-1}"

log() { echo "[vm310-cpu] $*"; }

[[ -f "$SRC" ]] || { log "ERRO: falta $SRC"; exit 1; }

log "Copiar zz-cpu.conf → VM310 ($VM310)..."
for d in ollama.service.d ollama-gpu1.service.d; do
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$VM310" "mkdir -p /etc/systemd/system/$d"
  sed 's/\r$//' "$SRC" | ssh "$VM310" "cat > /etc/systemd/system/$d/zz-cpu.conf"
done

log "daemon-reload + restart ollama..."
ssh "$VM310" 'systemctl daemon-reload && systemctl restart ollama.service ollama-gpu1.service && sleep 3 && systemctl is-active ollama.service ollama-gpu1.service'

if [[ "$DEPLOY_LITELLM" == "1" ]]; then
  log "Patch LiteLLM (CPU: agl-primary → llama3.1:8b) + deploy CT186..."
  VM310_CPU_MODE=1 bash "${REPO}/scripts/litellm/apply-litellm-vm310-ollama.sh"
else
  log "Skip deploy LiteLLM (DEPLOY_LITELLM=0)"
fi

log "Concluído. Benchmark: docs/litellm-battery/ollama-vm310-cpu-*.md"
