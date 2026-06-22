#!/usr/bin/env bash
# Benchmark Ollama num_ctx / OLLAMA_CONTEXT_LENGTH na VM310.
# Descobre o maior contexto estável por modelo (load + prompt curto + opcional longo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VM310_HOST="${VM310_HOST:-100.67.253.52}"
GPU0_PORT="${VM310_GPU0_PORT:-11434}"
GPU1_PORT="${VM310_GPU1_PORT:-11435}"
SSH_USER="${VM310_SSH_USER:-root}"

# Contextos a testar (ordem crescente)
CTX_LEVELS="${CTX_LEVELS:-8192 16384 32768 49152 65536}"

# modelos: nome_ollama:porta
MODELS="${TUNE_MODELS:-qwen3:4b:${GPU0_PORT} qwen3:8b:${GPU1_PORT} gemma4-qat:${GPU0_PORT}}"

log() { printf '[tune-ollama] %s\n' "$*"; }

ssh_vm310() {
  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "${SSH_USER}@${VM310_HOST}" "$@"
}

curl_ollama() {
  local port="$1"
  shift
  curl -sf --connect-timeout 10 --max-time "${CURL_TIMEOUT:-120}" \
    "http://${VM310_HOST}:${port}/api/$*"
}

probe_health() {
  local port="$1"
  curl -sf --connect-timeout 5 --max-time 10 "http://${VM310_HOST}:${port}/api/tags" >/dev/null
}

test_ctx() {
  local model="$1"
  local port="$2"
  local ctx="$3"

  local payload
  payload=$(jq -nc \
    --arg m "$model" \
    --argjson ctx "$ctx" \
    '{
      model: $m,
      stream: false,
      options: { num_ctx: $ctx, num_predict: 32 },
      messages: [{ role: "user", content: "Responde apenas: OK" }]
    }')

  local t0 t1 elapsed
  t0=$(date +%s)
  if ! curl -sf --connect-timeout 10 --max-time "${GEN_TIMEOUT:-180}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "http://${VM310_HOST}:${port}/api/chat" >/tmp/tune-ollama-last.json 2>/tmp/tune-ollama-err.txt; then
    log "FAIL model=$model port=$port ctx=$ctx — $(head -c 200 /tmp/tune-ollama-err.txt)"
    return 1
  fi
  t1=$(date +%s)
  elapsed=$((t1 - t0))
  log "OK   model=$model port=$port ctx=$ctx elapsed=${elapsed}s"
  return 0
}

report_vram() {
  ssh_vm310 'nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader 2>/dev/null || true' \
    | while read -r line; do log "VRAM: $line"; done
}

main() {
  log "Host VM310: ${VM310_HOST}"
  if ! probe_health "$GPU0_PORT" 2>/dev/null; then
    log "ERRO: GPU0 :${GPU0_PORT} inacessível — VM310 offline ou firewall?"
    log "Configs no repo ficam prontas; correr de novo quando online."
    exit 2
  fi

  report_vram
  echo "model,port,max_stable_ctx,notes" > /tmp/vm310-ctx-tune.csv

  for spec in $MODELS; do
    IFS=: read -r model port <<< "$spec"
    max_ok=0
    for ctx in $CTX_LEVELS; do
      if test_ctx "$model" "$port" "$ctx"; then
        max_ok=$ctx
        report_vram
      else
        log "Parar em $model após ctx=$ctx (último OK=$max_ok)"
        break
      fi
    done
    echo "${model},${port},${max_ok}," >> /tmp/vm310-ctx-tune.csv
    log "RESULTADO $model @ :$port → max_stable_ctx=${max_ok}"
  done

  log "CSV: /tmp/vm310-ctx-tune.csv"
  cat /tmp/vm310-ctx-tune.csv

  # Sugestão env para deploy
  q4b_max=$(awk -F, '$1=="qwen3:4b"{print $3}' /tmp/vm310-ctx-tune.csv | tail -1)
  q8b_max=$(awk -F, '$1=="qwen3:8b"{print $3}' /tmp/vm310-ctx-tune.csv | tail -1)
  log "Sugestão deploy:"
  log "  export VM310_AGL_PRIMARY_CTX=${q4b_max:-32768}"
  log "  export VM310_AGL_PRIMARY_STRONG_CTX=${q8b_max:-16384}"
}

main "$@"
