#!/usr/bin/env bash
# Aplica OLLAMA_CONTEXT_LENGTH na VM310 e regenera LiteLLM config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VM310_HOST="${VM310_HOST:-100.67.253.52}"
SSH_USER="${VM310_SSH_USER:-root}"
CTX_GPU0="${OLLAMA_CONTEXT_LENGTH:-${VM310_AGL_PRIMARY_CTX:-32768}}"
CTX_GPU1="${OLLAMA_CONTEXT_LENGTH_GPU1:-${VM310_AGL_PRIMARY_STRONG_CTX:-16384}}"

RUN_TUNE="${RUN_TUNE:-0}"

log() { printf '[apply-ollama-ctx] %s\n' "$*"; }

ssh_vm310() {
  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "${SSH_USER}@${VM310_HOST}" "$@"
}

patch_override() {
  local file="$1"
  local ctx="$2"
  if [[ -f "$file" ]]; then
    if grep -q '^OLLAMA_CONTEXT_LENGTH=' "$file"; then
      sed -i "s/^OLLAMA_CONTEXT_LENGTH=.*/OLLAMA_CONTEXT_LENGTH=${ctx}/" "$file"
    else
      echo "OLLAMA_CONTEXT_LENGTH=${ctx}" >> "$file"
    fi
    log "Atualizado $file → OLLAMA_CONTEXT_LENGTH=${ctx}"
  fi
}

main() {
  patch_override "$REPO_ROOT/scripts/aglsrv3/vm310-ollama-override.conf" "$CTX_GPU0"
  patch_override "$REPO_ROOT/scripts/aglsrv3/vm310-ollama-gpu1-override.conf" "$CTX_GPU1"

  if [[ "$RUN_TUNE" == "1" ]]; then
    bash "$REPO_ROOT/scripts/aglsrv3/tune-vm310-ollama-context.sh" || true
  fi

  if ssh_vm310 'systemctl is-active ollama' &>/dev/null; then
    log "Aplicar override na VM310 e reiniciar ollama..."
    ssh_vm310 "grep -q OLLAMA_CONTEXT_LENGTH /etc/systemd/system/ollama.service.d/override.conf 2>/dev/null && \
      sed -i 's/^OLLAMA_CONTEXT_LENGTH=.*/OLLAMA_CONTEXT_LENGTH=${CTX_GPU0}/' /etc/systemd/system/ollama.service.d/override.conf || \
      echo 'OLLAMA_CONTEXT_LENGTH=${CTX_GPU0}' >> /etc/systemd/system/ollama.service.d/override.conf; \
      systemctl daemon-reload && systemctl restart ollama" || log "WARN: não foi possível reiniciar ollama GPU0"
    ssh_vm310 "systemctl restart ollama-gpu1 2>/dev/null || true" || true
  else
    log "VM310 offline — override guardado no repo apenas."
  fi

  export VM310_AGL_PRIMARY_CTX="$CTX_GPU0"
  export VM310_AGL_PRIMARY_STRONG_CTX="$CTX_GPU1"
  python3 "$REPO_ROOT/scripts/litellm/patch_config_vm310_ollama.py" \
    "$REPO_ROOT/config/litellm/config.yaml" \
    "$REPO_ROOT/config/litellm/config.yaml"

  log "Feito. Deploy LiteLLM: bash scripts/litellm/deploy-litellm-callbacks-ct186.sh"
}

main "$@"
