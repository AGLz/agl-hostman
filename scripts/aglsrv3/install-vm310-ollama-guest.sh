#!/usr/bin/env bash
# Instala drivers AMD + Ollama na VM310 (Ubuntu 24.04, RX 580 passthrough).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_SRC="${OVERRIDE_SRC:-${SCRIPT_DIR}/vm310-ollama-override.conf}"
MODEL="${OLLAMA_MODEL:-qwen3:8b}"

log() { echo "[vm310-guest] $*"; }

install_amd() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "linux-modules-extra-$(uname -r)" \
    linux-firmware \
    mesa-vulkan-drivers
  echo amdgpu > /etc/modules-load.d/amdgpu.conf
  modprobe amdgpu 2>/dev/null || true
  if [[ -d /dev/dri ]] && ls /dev/dri/renderD* &>/dev/null; then
    log "DRI devices presentes:"
    ls -la /dev/dri/ || true
  fi
  if command -v rocm-smi &>/dev/null; then
    rocm-smi || log "rocm-smi sem GPU ROCm visível (normal antes do Ollama)"
  fi
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    log "Ollama já instalado: $(ollama --version 2>/dev/null || true)"
  else
    log "Instalar Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  install -d /etc/systemd/system/ollama.service.d
  if [[ -f "$OVERRIDE_SRC" ]]; then
    cp -a "$OVERRIDE_SRC" /etc/systemd/system/ollama.service.d/override.conf
  else
    log "AVISO: override não encontrado em $OVERRIDE_SRC"
  fi
  systemctl daemon-reload
  systemctl enable ollama
  systemctl restart ollama
  sleep 5
  systemctl is-active ollama
}

pull_model() {
  log "Pull ${MODEL}..."
  ollama pull "$MODEL"
  log "Warm load..."
  curl -sf "http://127.0.0.1:11434/api/generate" \
    -d "{\"model\":\"${MODEL}\",\"prompt\":\"ok\",\"stream\":false,\"keep_alive\":\"30m\"}" >/dev/null
  ollama ps
  journalctl -u ollama -n 30 --no-pager | grep -iE 'gpu|offload|vram|layer|rocm|amd' || true
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: root na VM." >&2
    exit 1
  fi
  install_amd
  install_ollama
  pull_model
  curl -sf http://127.0.0.1:11434/api/tags | head -c 600
  echo
}

main "$@"
