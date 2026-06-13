#!/usr/bin/env bash
# Plan C — VM110 GTX 1650 4 GB: Gemma 4 E2B QAT text-only via GGUF Hugging Face + ollama create.
# Executar como root na guest agl-ollama (192.168.0.200 / TS 100.116.57.111).
#
# Não usa gemma4:e2b-it-qat do registry Ollama (inclui mmproj ~987 MB → OOM em 4 GB).
# Usa só google/gemma-4-E2B-it-qat-q4_0-gguf/gemma-4-E2B_q4_0-it.gguf
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_SRC="${SCRIPT_DIR}/vm110-ollama-override.conf"
MODELFILE_TEMPLATE="${SCRIPT_DIR}/vm110-gemma4-qat-modelfile"
MODEL_ALIAS="${OLLAMA_MODEL_ALIAS:-gemma4-qat}"
FALLBACK_MODEL="${OLLAMA_FALLBACK_MODEL:-qwen3:4b}"
IMPORT_DIR="${OLLAMA_IMPORT_DIR:-/var/lib/ollama/import/gemma4-qat}"
HF_REPO="${HF_GEMMA4_QAT_REPO:-google/gemma-4-E2B-it-qat-q4_0-gguf}"
HF_FILE="${HF_GEMMA4_QAT_FILE:-gemma-4-E2B_q4_0-it.gguf}"
HF_URL="https://huggingface.co/${HF_REPO}/resolve/main/${HF_FILE}"
NUM_CTX="${OLLAMA_CONTEXT_LENGTH:-8192}"

log() { echo "[vm110-plan-c] $*"; }

require_root() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root na VM110." >&2
    exit 1
  fi
}

ensure_nvidia() {
  if nvidia-smi >/dev/null 2>&1; then
    log "GPU: $(nvidia-smi -L | head -1)"
    nvidia-smi --query-gpu=memory.total,memory.free --format=csv,noheader
    return 0
  fi
  log "ERRO: nvidia-smi indisponível — instalar driver e reboot antes do Plan C."
  exit 2
}

ensure_ollama() {
  if ! command -v ollama >/dev/null 2>&1; then
    log "Instalar Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  local ver
  ver="$(ollama --version 2>/dev/null || true)"
  log "Ollama: ${ver:-desconhecido}"
  install -d /etc/systemd/system/ollama.service.d
  if [[ -f "$OVERRIDE_SRC" ]]; then
    cp -a "$OVERRIDE_SRC" /etc/systemd/system/ollama.service.d/override.conf
  fi
  # Reason: ctx menor reduz KV cache se 8192 falhar em 4 GB
  if [[ "$NUM_CTX" != "8192" ]]; then
    sed -i "s/OLLAMA_CONTEXT_LENGTH=.*/OLLAMA_CONTEXT_LENGTH=${NUM_CTX}/" \
      /etc/systemd/system/ollama.service.d/override.conf
  fi
  systemctl daemon-reload
  systemctl enable ollama
  systemctl restart ollama
  sleep 3
  systemctl is-active --quiet ollama
}

download_gguf() {
  install -d "$IMPORT_DIR"
  local dest="${IMPORT_DIR}/${HF_FILE}"
  if [[ -f "$dest" ]] && [[ "$(stat -c%s "$dest" 2>/dev/null || echo 0)" -gt 3000000000 ]]; then
    log "GGUF já presente: $dest ($(du -h "$dest" | awk '{print $1}'))"
    echo "$dest"
    return 0
  fi
  log "Download HF (~3,35 GB): $HF_URL"
  if command -v huggingface-cli >/dev/null 2>&1; then
    huggingface-cli download "$HF_REPO" "$HF_FILE" --local-dir "$IMPORT_DIR" --local-dir-use-symlinks False
    dest="${IMPORT_DIR}/${HF_FILE}"
  else
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates
    curl -fL --retry 3 --continue-at - -o "$dest.part" "$HF_URL"
    mv -f "$dest.part" "$dest"
  fi
  log "Download OK: $(du -h "$dest" | awk '{print $1}')"
  echo "$dest"
}

create_model() {
  local gguf_path="$1"
  local modelfile="/tmp/vm110-gemma4-qat-modelfile"
  if [[ ! -f "$MODELFILE_TEMPLATE" ]]; then
    echo "ERRO: falta $MODELFILE_TEMPLATE" >&2
    exit 3
  fi
  sed "s|{{GGUF_PATH}}|${gguf_path}|g" "$MODELFILE_TEMPLATE" > "$modelfile"
  log "ollama create ${MODEL_ALIAS}..."
  ollama rm "${MODEL_ALIAS}" 2>/dev/null || true
  ollama create "${MODEL_ALIAS}" -f "$modelfile"
  ollama show "${MODEL_ALIAS}" | head -20
}

warm_model() {
  local model="$1"
  log "Warm ${model} (keep_alive 30m)..."
  curl -sf "http://127.0.0.1:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"prompt\":\"Responde apenas: ok\",\"stream\":false,\"keep_alive\":\"30m\"}" \
    >/dev/null || return 1
  ollama ps
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
  nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
}

ensure_fallback() {
  if ollama list | grep -q "${FALLBACK_MODEL}"; then
    log "Fallback ${FALLBACK_MODEL} já instalado"
    return 0
  fi
  log "Pull fallback ${FALLBACK_MODEL}..."
  ollama pull "${FALLBACK_MODEL}"
}

main() {
  require_root
  ensure_nvidia
  ensure_ollama
  local gguf
  gguf="$(download_gguf)"
  create_model "$gguf"
  ensure_fallback

  if ! warm_model "${MODEL_ALIAS}"; then
    log "AVISO: warm falhou com num_ctx=${NUM_CTX} — tentar OLLAMA_CONTEXT_LENGTH=4096"
    if [[ "$NUM_CTX" == "8192" ]]; then
      NUM_CTX=4096
      ensure_ollama
      warm_model "${MODEL_ALIAS}" || {
        log "ERRO: OOM provável — usar só ${FALLBACK_MODEL} como primário temporário"
        exit 4
      }
    else
      exit 4
    fi
  fi

  log "Smoke tags:"
  curl -sf http://127.0.0.1:11434/api/tags | python3 -m json.tool 2>/dev/null | head -30 || true
  log "Plan C concluído: ${MODEL_ALIAS} @ :11434"
}

main "$@"
