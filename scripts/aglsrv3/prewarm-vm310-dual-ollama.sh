#!/usr/bin/env bash
# Pre-warm Ollama VM310. Por defeito: só o primário em :11434 quando GPU1 down
# (MAX_LOADED=1). Com GPU1 activa: gemma opcional + primary @11434, qwen3:8b @11435.
# Uso: bash scripts/aglsrv3/prewarm-vm310-dual-ollama.sh [--primary-only|--remote]
set -euo pipefail

GPU0="${OLLAMA_GPU0:-http://100.67.253.52:11434}"
GPU1="${OLLAMA_GPU1:-http://100.67.253.52:11435}"
KEEP_ALIVE="${KEEP_ALIVE:-24h}"
VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"
# Reason: benchmark CPU 2026-06-30 — llama3.1:8b ~3× mais rápido que qwen3:4b
PRIMARY_MODEL="${VM310_PRIMARY_MODEL:-$([ "${VM310_CPU_MODE:-}" = 1 ] && echo llama3.1:8b || echo qwen3:4b)}"
PRIMARY_ONLY=0

log() { printf '[prewarm-vm310] %s\n' "$*" >&2; }

warm_one() {
  local base="$1" model="$2"
  log "warm $model @ $base (keep_alive=$KEEP_ALIVE)"
  curl -sf --max-time 300 "${base}/api/chat" \
    -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}],\"stream\":false,\"think\":false,\"keep_alive\":\"${KEEP_ALIVE}\",\"options\":{\"num_predict\":8,\"temperature\":0}}" \
    >/dev/null
}

warm_remote() {
  local primary_only_flag="${1:-0}"
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$AGLSRV3" bash -s -- "$VMID" "$KEEP_ALIVE" "$PRIMARY_MODEL" "$primary_only_flag" <<'REMOTE'
set -euo pipefail
VMID="$1"
KEEP="$2"
PRIMARY="$3"
PRIMARY_ONLY="$4"
qm guest exec "$VMID" -- bash -lc "
set -e
warm() { curl -sf --max-time 300 \"\$1/api/chat\" -d \"{\\\"model\\\":\\\"\$2\\\",\\\"messages\\\":[{\\\"role\\\":\\\"user\\\",\\\"content\\\":\\\"ok\\\"}],\\\"stream\\\":false,\\\"think\\\":false,\\\"keep_alive\\\":\\\"\$3\\\",\\\"options\\\":{\\\"num_predict\\\":8,\\\"temperature\\\":0}}\" >/dev/null; }
GPU1_UP=0
curl -sf --max-time 3 http://127.0.0.1:11435/api/tags >/dev/null 2>&1 && GPU1_UP=1
if [[ '$PRIMARY_ONLY' != 1 && \$GPU1_UP -eq 1 ]]; then
  warm http://127.0.0.1:11434 gemma4-qat '$KEEP'
fi
warm http://127.0.0.1:11434 '$PRIMARY' '$KEEP'
if [[ \$GPU1_UP -eq 1 ]]; then
  warm http://127.0.0.1:11435 qwen3:8b '$KEEP'
  echo GPU1_WARM_OK
else
  echo GPU1_SKIP_PREWARM
fi
echo '=== GPU0 ps ==='
curl -sf --max-time 10 http://127.0.0.1:11434/api/ps | python3 -c \"import json,sys;d=json.load(sys.stdin);print([m['name'] for m in d.get('models',[])])\"
"
REMOTE
}

main() {
  local mode="${1:-}"
  if [[ "$mode" == "--primary-only" ]]; then
    PRIMARY_ONLY=1
  fi
  if [[ "$mode" == "--remote" ]]; then
    warm_remote 0
    return
  fi
  if [[ "$mode" == "--remote-primary-only" ]]; then
    warm_remote 1
    return
  fi

  local gpu1_up=0
  if curl -sf --max-time 3 "${GPU1}/api/tags" >/dev/null 2>&1; then
    gpu1_up=1
  fi

  # Reason: com MAX_LOADED=1, aquecer gemma em :11434 sem GPU1 evicta o primário.
  if [[ "$PRIMARY_ONLY" -eq 0 && "$gpu1_up" -eq 1 ]]; then
    warm_one "$GPU0" "gemma4-qat"
  elif [[ "$PRIMARY_ONLY" -eq 0 && "$gpu1_up" -eq 0 ]]; then
    log "GPU1 inactiva — mode pin: só $PRIMARY_MODEL (evita eviction)"
    PRIMARY_ONLY=1
  fi

  warm_one "$GPU0" "$PRIMARY_MODEL"

  if [[ "$gpu1_up" -eq 1 ]]; then
    warm_one "$GPU1" "qwen3:8b"
    log "GPU1: $(curl -sf --max-time 10 "${GPU1}/api/ps" | python3 -c "import json,sys;print([m['name'] for m in json.load(sys.stdin).get('models',[])])")"
  fi
  log "GPU0: $(curl -sf --max-time 10 "${GPU0}/api/ps" | python3 -c "import json,sys;print([m['name'] for m in json.load(sys.stdin).get('models',[])])")"
}

main "${1:-}"
