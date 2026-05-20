#!/usr/bin/env bash
# Instala NVIDIA + Ollama + qwen3:4b na VM110 (Ubuntu 24.04).
# Executar como root dentro da VM agl-ollama (192.168.0.200).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_SRC="${SCRIPT_DIR}/vm110-ollama-override.conf"
MODEL="${OLLAMA_MODEL:-qwen3:4b}"

log() { echo "[vm110-guest] $*"; }

install_nvidia() {
  if nvidia-smi >/dev/null 2>&1; then
    log "nvidia-smi OK"
    nvidia-smi -L
    return 0
  fi
  log "Instalar driver NVIDIA (ubuntu-drivers)..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-drivers-common
  ubuntu-drivers install --gpgpu 2>/dev/null || ubuntu-drivers autoinstall || true
  modprobe nvidia || true
  nvidia-smi -L
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    log "Ollama já instalado: $(ollama --version)"
  else
    log "Instalar Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  install -d /etc/systemd/system/ollama.service.d
  if [[ -f "$OVERRIDE_SRC" ]]; then
    cp -a "$OVERRIDE_SRC" /etc/systemd/system/ollama.service.d/override.conf
  fi
  systemctl daemon-reload
  systemctl enable ollama
  systemctl restart ollama
  sleep 3
  systemctl is-active ollama
}

pull_model() {
  log "Pull ${MODEL}..."
  ollama pull "$MODEL"
  log "Warm load..."
  curl -sf "http://127.0.0.1:11434/api/generate" \
    -d "{\"model\":\"${MODEL}\",\"prompt\":\"ok\",\"stream\":false,\"keep_alive\":\"30m\"}" >/dev/null
  ollama ps
  journalctl -u ollama -n 20 --no-pager | grep -iE 'gpu|offload|vram|layer' || true
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: root na VM." >&2
    exit 1
  fi
  install_nvidia
  install_ollama
  pull_model
  log "Smoke: curl http://127.0.0.1:11434/api/tags"
  curl -sf http://127.0.0.1:11434/api/tags | head -c 500
  echo
}

main "$@"
