#!/usr/bin/env bash
# Pre-warm qwen3:4b (GPU0 primário ctx-long) + gemma4-qat (fast) + qwen3:8b (GPU1 se activa).
set -euo pipefail

GPU0="${OLLAMA_GPU0:-http://100.67.253.52:11434}"
GPU1="${OLLAMA_GPU1:-http://100.67.253.52:11435}"
KEEP_ALIVE="${KEEP_ALIVE:-30m}"
VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"

log() { printf '[prewarm-vm310] %s\n' "$*" >&2; }

warm_one() {
  local base="$1" model="$2"
  log "warm $model @ $base"
  curl -sf --max-time 300 "${base}/api/chat" \
    -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}],\"stream\":false,\"think\":false,\"keep_alive\":\"${KEEP_ALIVE}\",\"options\":{\"num_predict\":8}}" \
    >/dev/null
}

warm_remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$AGLSRV3" bash -s -- "$VMID" "$KEEP_ALIVE" <<'REMOTE'
set -euo pipefail
VMID="$1"
KEEP="$2"
qm guest exec "$VMID" -- bash -lc "
set -e
warm() { curl -sf --max-time 300 \"\$1/api/chat\" -d \"{\\\"model\\\":\\\"\$2\\\",\\\"messages\\\":[{\\\"role\\\":\\\"user\\\",\\\"content\\\":\\\"ok\\\"}],\\\"stream\\\":false,\\\"think\\\":false,\\\"keep_alive\\\":\\\"\$3\\\",\\\"options\\\":{\\\"num_predict\\\":8}}\" >/dev/null; }
warm http://127.0.0.1:11434 qwen3:4b '$KEEP'
warm http://127.0.0.1:11434 gemma4-qat '$KEEP'
if curl -sf --max-time 3 http://127.0.0.1:11435/api/tags >/dev/null 2>&1; then
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
  if [[ "${1:-}" == "--remote" ]]; then
    warm_remote
    return
  fi
  warm_one "$GPU0" "qwen3:4b"
  warm_one "$GPU0" "gemma4-qat"
  if curl -sf --max-time 3 "${GPU1}/api/tags" >/dev/null 2>&1; then
    warm_one "$GPU1" "qwen3:8b"
    log "GPU1: $(curl -sf --max-time 10 "${GPU1}/api/ps" | python3 -c "import json,sys;print([m['name'] for m in json.load(sys.stdin).get('models',[])])")"
  else
    log "GPU1 inactiva — só gemma4-qat em :11434 (evita eviction do primário)"
  fi
  log "GPU0: $(curl -sf --max-time 10 "${GPU0}/api/ps" | python3 -c "import json,sys;print([m['name'] for m in json.load(sys.stdin).get('models',[])])")"
}

main "$@"
