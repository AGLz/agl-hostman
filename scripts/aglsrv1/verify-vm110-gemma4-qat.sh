#!/usr/bin/env bash
# Smoke Plan C — VM110 Ollama gemma4-qat + VRAM (GTX 1650).
# Guest: bash verify-vm110-gemma4-qat.sh
# Remoto: OLLAMA_HOST=http://100.116.57.111:11434 bash verify-vm110-gemma4-qat.sh
set -euo pipefail

API="${OLLAMA_HOST:-http://127.0.0.1:11434}"
PRIMARY="${OLLAMA_PRIMARY:-gemma4-qat}"
FALLBACK="${OLLAMA_FALLBACK:-qwen3:4b}"

log() { echo "[verify-vm110] $*"; }
fail() { echo "[verify-vm110] FALHA: $*" >&2; exit 1; }

log "API=$API primary=$PRIMARY fallback=$FALLBACK"

curl -sf "${API}/api/tags" >/dev/null || fail "Ollama inacessível em ${API}"

if command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU baseline:"
  nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
fi

for M in "$PRIMARY" "$FALLBACK"; do
  log "Generate smoke: $M"
  out="$(curl -sf "${API}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${M}\",\"prompt\":\"Diz apenas a palavra smoke.\",\"stream\":false,\"options\":{\"num_predict\":8}}")" \
    || fail "generate falhou para $M"
  echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); print('response:', (d.get('response') or '')[:80])" \
    || fail "resposta inválida para $M"
done

if command -v nvidia-smi >/dev/null 2>&1; then
  log "VRAM após warm:"
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
  nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
fi

curl -sf "${API}/api/ps" | python3 -m json.tool 2>/dev/null || ollama ps || true
log "OK"
