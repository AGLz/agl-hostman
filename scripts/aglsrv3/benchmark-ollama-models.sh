#!/usr/bin/env bash
# Benchmark de modelos Ollama na VM310 (RX 580 ~8 GB VRAM, AMD).
# Métricas: load/total ms, tokens/s, ollama ps (GPU vs CPU), VRAM rocm-smi se disponível.
#
# Uso na VM310 (root ou user com ollama):
#   bash scripts/aglsrv3/benchmark-ollama-models.sh
#   PULL=1 bash scripts/aglsrv3/benchmark-ollama-models.sh
#   MODELS="mistral:7b llama3.1:8b" bash scripts/aglsrv3/benchmark-ollama-models.sh
#   OLLAMA_BENCH_MODELS="qwen3:8b" bash ...
#
# Desde agldv03 / qualquer host com Tailscale (sem SSH — só API):
#   bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only
#   PULL=1 bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only --pull
#
# Desde o host AGLSRV3 via SSH:
#   VM310_HOST=agladmin@100.86.209.11 bash scripts/aglsrv3/benchmark-ollama-models.sh --remote
#
# Opções:
#   --pull       fazer ollama pull antes de cada modelo
#   --dry-run    mostrar plano sem executar inferência
#   --api-only   só HTTP (Tailscale); não requer ollama CLI local
#   --remote     correr via ssh (VM310_HOST default agladmin@100.86.209.11)
#   --output F   ficheiro CSV (default: /tmp/ollama-vm310-bench.csv)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="${OLLAMA_HOST:-http://100.86.209.11:11434}"
VM310_HOST="${VM310_HOST:-agladmin@100.86.209.11}"
VM310_TS_IP="${VM310_TS_IP:-100.86.209.11}"
OUT_CSV="${OUT_CSV:-/tmp/ollama-vm310-bench.csv}"
PULL="${PULL:-0}"
DRY_RUN="${DRY_RUN:-0}"
REMOTE="${REMOTE:-0}"
API_ONLY="${API_ONLY:-0}"
NUM_PREDICT="${NUM_PREDICT:-128}"
KEEP_ALIVE="${KEEP_ALIVE:-5m}"

# Reason: lista curada para 8 GB VRAM (disco Ollama ≤ ~6.6 GB confortável)
DEFAULT_MODELS=(
  qwen3:8b
  qwen3.5:9b
  llama3.1:8b
  gemma2:9b
  deepseek-r1:8b
  qwen2.5:7b
  qwen2.5-coder:7b
  mistral:7b
  command-r7b
  granite3.3:8b
)

PROMPT_PT="Responde numa frase curta em português europeu: para que serve um balanceador de carga?"
PROMPT_JSON='Return ONLY compact JSON {"ok":true,"n":42}. No markdown.'

log() { printf '[ollama-bench] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Uso: $(basename "$0") [--pull] [--dry-run] [--remote] [--output FILE] [modelo ...]

Variáveis:
  OLLAMA_HOST   URL Ollama (default: http://127.0.0.1:11434)
  OLLAMA_BENCH_MODELS  lista de modelos (espaço-separado; alias de positional)
  PULL=1        equivalente a --pull
  OUT_CSV       destino CSV

Modelos default (8 GB VRAM):
  ${DEFAULT_MODELS[*]}
EOF
}

parse_args() {
  BENCH_MODELS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pull) PULL=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --remote) REMOTE=1; shift ;;
      --api-only) API_ONLY=1; shift ;;
      --output)
        OUT_CSV="${2:?--output requer ficheiro}"
        shift 2
        ;;
      -h|--help) usage; exit 0 ;;
      --) shift; while [[ $# -gt 0 ]]; do BENCH_MODELS+=("$1"); shift; done; break ;;
      -*) log "opção desconhecida: $1"; usage; exit 1 ;;
      *) BENCH_MODELS+=("$1"); shift ;;
    esac
  done

  if [[ ${#BENCH_MODELS[@]} -eq 0 ]]; then
    if [[ -n "${OLLAMA_BENCH_MODELS:-}" ]]; then
      # shellcheck disable=SC2206
      BENCH_MODELS=($OLLAMA_BENCH_MODELS)
    else
      BENCH_MODELS=("${DEFAULT_MODELS[@]}")
    fi
  fi
}

require_tools() {
  local missing=0
  local cmds=(curl python3)
  if [[ "$DRY_RUN" != "1" && "$API_ONLY" != "1" ]]; then
    cmds+=(ollama)
  fi
  for cmd in "${cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "ERRO: '$cmd' não encontrado no PATH"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

gpu_snapshot() {
  local label="${1:-}"
  [[ -n "$label" ]] && log "GPU snapshot: $label"
  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi --showmeminfo vram 2>/dev/null | head -5 || true
  fi
  if [[ "$API_ONLY" == "1" ]]; then
    curl -sf "${API}/api/ps" | python3 -m json.tool 2>/dev/null | head -20 || true
  else
    ollama ps 2>/dev/null || true
  fi
}

stop_model() {
  local model="$1"
  if [[ "$API_ONLY" == "1" ]]; then
    api_unload_model "$model"
    return 0
  fi
  ollama stop "$model" >/dev/null 2>&1 || true
  sleep 2
}

api_unload_model() {
  local model="$1"
  curl -sf "${API}/api/chat" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"messages\":[],\"keep_alive\":0}" >/dev/null 2>&1 || true
  sleep 2
}

model_present() {
  local model="$1"
  if [[ "$API_ONLY" == "1" ]]; then
    local tags_json
    tags_json=$(curl -sf "${API}/api/tags" || echo '{}')
    python3 - "$model" "$tags_json" <<'PY'
import json, sys
target, raw = sys.argv[1], sys.argv[2]
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    raise SystemExit(1)
names = {m.get("name") for m in data.get("models", [])}
raise SystemExit(0 if target in names else 1)
PY
    return $?
  fi
  ollama list 2>/dev/null | awk -v m="$model" '$1 == m { found=1 } END { exit !found }'
}

api_pull_model() {
  local model="$1"
  log "Pull (API) $model..."
  curl -sf "${API}/api/pull" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${model}\",\"stream\":false}" >/dev/null
}

pull_model() {
  local model="$1"
  if [[ "$PULL" != "1" ]] && model_present "$model"; then
    log "Skip pull (já presente): $model"
    return 0
  fi
  if [[ "$PULL" != "1" ]]; then
    log "AVISO: $model não está local; use --pull ou PULL=1"
    return 1
  fi
  if [[ "$API_ONLY" == "1" ]]; then
    api_pull_model "$model"
  else
    log "Pull $model..."
    ollama pull "$model"
  fi
}

chat_benchmark() {
  local model="$1"
  local prompt="$2"
  python3 - "$API" "$model" "$prompt" "$NUM_PREDICT" "$KEEP_ALIVE" <<'PY'
import json, sys, urllib.request

api, model, prompt, num_predict, keep_alive = sys.argv[1:6]
body = {
    "model": model,
    "messages": [{"role": "user", "content": prompt}],
    "stream": False,
    "keep_alive": keep_alive,
    "options": {"num_predict": int(num_predict)},
}
data = json.dumps(body).encode("utf-8")
req = urllib.request.Request(
    api.rstrip("/") + "/api/chat",
    data=data,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=600) as resp:
        print(resp.read().decode("utf-8"))
except Exception as exc:
    print(json.dumps({"error": str(exc), "model": model}))
PY
}

json_has_error() {
  local payload="$1"
  printf '%s' "$payload" | python3 <<'PY'
import json, sys
try:
    d = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(1)
raise SystemExit(1 if d.get("error") else 0)
PY
}

json_get_error() {
  local payload="$1"
  printf '%s' "$payload" | python3 <<'PY'
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("error") or "warm failed")
except json.JSONDecodeError:
    print("invalid json")
PY
}

parse_ollama_ps() {
  local model="$1"
  local ps_json
  ps_json=$(curl -sf "${API}/api/ps" || echo '{}')
  python3 - "$model" "$ps_json" <<'PY'
import json, sys

target, raw = sys.argv[1], sys.argv[2]
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print("|")
    raise SystemExit(0)

for entry in data.get("models") or []:
    name = entry.get("name") or entry.get("model") or ""
    if name != target and not name.startswith(target + ":"):
        continue
    size = entry.get("size_vram") or entry.get("size") or ""
    if isinstance(size, int):
        size = f"{size / (1024**3):.1f} GB"
    proc = entry.get("size_vram") and "GPU" or ""
    details = entry.get("details") or {}
    if not proc and size:
        proc = "GPU"
    print(f"{proc}|{size}")
    break
else:
    print("|")
PY
}

run_one_model() {
  local model="$1"
  log "========== $model =========="

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] pull=$PULL benchmark chat + ollama ps"
    return 0
  fi

  stop_model "$model"
  if ! pull_model "$model"; then
    printf '%s\n' "$model,SKIP,missing,not local,,,,,,,use --pull," >>"$OUT_CSV"
    return 0
  fi

  gpu_snapshot "antes warm-load"

  local warm_out
  warm_out=$(chat_benchmark "$model" "ok" || true)
  if json_has_error "$warm_out"; then
    local err
    err=$(json_get_error "$warm_out")
    log "Warm-load falhou: $err"
    printf '%s\n' "$model,FAIL,warm,$err,,,,,,,," >>"$OUT_CSV"
    stop_model "$model"
    return 0
  fi

  local ps_warm
  ps_warm=$(parse_ollama_ps "$model")
  local processor_warm="${ps_warm%%|*}"
  local size_warm="${ps_warm#*|}"

  gpu_snapshot "após warm-load"

  local wall0 wall1 body body_file
  wall0=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
  body=$(chat_benchmark "$model" "$PROMPT_PT")
  wall1=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")

  body_file=$(mktemp)
  trap 'rm -f "$body_file"' RETURN
  printf '%s' "$body" >"$body_file"

  local row
  row=$(python3 - "$model" "$wall0" "$wall1" "$processor_warm" "$size_warm" "$body_file" <<'PY'
import json, sys

model, w0, w1, proc, vram, body_path = sys.argv[1:7]
with open(body_path, encoding="utf-8") as f:
    body = f.read()

def ns_ms(x):
    if x is None:
        return ""
    return round(x / 1e6, 1)

try:
    d = json.loads(body)
except json.JSONDecodeError:
    print(f"{model},FAIL,json,,,,,,,{proc},{vram},invalid response")
    raise SystemExit(0)

if d.get("error"):
    err = str(d.get("error")).replace(",", ";")
    print(f"{model},FAIL,chat,{err},,,,,,{proc},{vram},")
    raise SystemExit(0)

msg = d.get("message") or {}
content = (msg.get("content") or "")[:80].replace(",", ";").replace("\n", " ")
if not content.strip():
    think = msg.get("thinking") or d.get("thinking") or ""
    if isinstance(think, str) and think.strip():
        content = think[:80].replace(",", ";").replace("\n", " ")
think = msg.get("thinking") or d.get("thinking") or ""
think_len = len(think) if isinstance(think, str) else 0

ev = d.get("eval_count") or 0
ed = d.get("eval_duration") or 0
tps = round(ev / (ed / 1e9), 2) if ed and ev else ""

try:
    wf = float(w0) if "." in str(w0) else int(w0) * 1000
    wt = float(w1) if "." in str(w1) else int(w1) * 1000
    wall_ms = int(wt - wf)
except Exception:
    wall_ms = ""

print(
    f"{model},OK,chat,{content},"
    f"{wall_ms},"
    f"{ns_ms(d.get('load_duration'))},"
    f"{ns_ms(d.get('total_duration'))},"
    f"{ev},"
    f"{tps},"
    f"{think_len},"
    f"{proc},"
    f"{vram}"
)
PY
)
  rm -f "$body_file"
  trap - RETURN
  printf '%s\n' "$row" >>"$OUT_CSV"

  body=$(chat_benchmark "$model" "$PROMPT_JSON")
  body_file=$(mktemp)
  printf '%s' "$body" >"$body_file"
  python3 - "$model" "$body_file" <<'PY' >>"$OUT_CSV"
import json, sys
model, body_path = sys.argv[1], sys.argv[2]
with open(body_path, encoding="utf-8") as f:
    body = f.read()
try:
    d = json.loads(body)
except json.JSONDecodeError:
    print(f"{model},FAIL,json,,,,,,,,")
    raise SystemExit(0)
if d.get("error"):
    print(f"{model},FAIL,json,{str(d.get('error')).replace(',', ';')},,,,,,,")
    raise SystemExit(0)
msg = d.get("message") or {}
content = (msg.get("content") or "")[:80].replace(",", ";").replace("\n", " ")
if not content.strip():
    think = msg.get("thinking") or ""
    if isinstance(think, str) and think.strip():
        content = think[:80].replace(",", ";").replace("\n", " ")
ev = d.get("eval_count") or 0
ed = d.get("eval_duration") or 0
tps = round(ev / (ed / 1e9), 2) if ed and ev else ""
print(
    f"{model},OK,json,{content},,"
    f"{round((d.get('load_duration') or 0)/1e6, 1)},"
    f"{round((d.get('total_duration') or 0)/1e6, 1)},"
    f"{ev},"
    f"{tps},"
    f"{len(msg.get('thinking') or '')},,"
)
PY
  rm -f "$body_file"

  stop_model "$model"
  log "Concluído: $model ($processor_warm)"
}

print_summary() {
  [[ ! -f "$OUT_CSV" ]] && return 0
  python3 - "$OUT_CSV" <<'PY'
import csv, sys
from pathlib import Path

path = Path(sys.argv[1])
rows = list(csv.reader(path.read_text(encoding="utf-8").splitlines()))
if len(rows) <= 1:
    print("Sem resultados.")
    raise SystemExit(0)

header = rows[0]
data = [r for r in rows[1:] if r and r[0] != "model"]
print()
print("=== Resumo VM310 Ollama benchmark ===")
fmt = f"{{:<22}} {{:<6}} {{:<5}} {{:>8}} {{:>10}} {{:>8}} {{:>12}}"
print(fmt.format("model", "status", "case", "wall_ms", "total_ms", "tok_out", "processor"))
print("-" * 88)
for r in data:
    while len(r) < 12:
        r.append("")
    model, status, case = r[0], r[1], r[2]
    wall, total, tok, proc = r[4], r[6], r[7], r[10]
    print(fmt.format(model[:22], status, case, wall or "-", total or "-", tok or "-", proc or "-"))
print()
print(f"CSV completo: {path}")
print("Objetivo RX580: processor = '100% GPU' (evitar CPU/GPU misto ou 100% CPU).")
PY
}

run_local() {
  require_tools
  mkdir -p "$(dirname "$OUT_CSV")"
  printf '%s\n' \
    "model,status,case,preview,wall_ms,load_ms,total_ms,eval_count,tok_per_s,thinking_len,processor,vram_size" \
    >"$OUT_CSV"

  log "API=$API modelos=${#BENCH_MODELS[@]} pull=$PULL dry_run=$DRY_RUN out=$OUT_CSV"
  for m in "${BENCH_MODELS[@]}"; do
    run_one_model "$m"
  done
  print_summary
}

run_remote() {
  log "Remoto via SSH: $VM310_HOST"
  local remote_dir="/tmp/agl-ollama-bench"
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$VM310_HOST" "mkdir -p '$remote_dir'"
  sed 's/\r$//' "$SCRIPT_DIR/benchmark-ollama-models.sh" | \
    ssh "$VM310_HOST" "cat > '$remote_dir/benchmark-ollama-models.sh' && chmod +x '$remote_dir/benchmark-ollama-models.sh'"

  local pull_flag=""
  [[ "$PULL" == "1" ]] && pull_flag="--pull"
  local dry_flag=""
  [[ "$DRY_RUN" == "1" ]] && dry_flag="--dry-run"
  local models_shell
  models_shell=$(printf '%q ' "${BENCH_MODELS[@]}")

  ssh -t "$VM310_HOST" "bash '$remote_dir/benchmark-ollama-models.sh' $pull_flag $dry_flag --output '$OUT_CSV' $models_shell"

  scp -q "${VM310_HOST}:${OUT_CSV}" "${OUT_CSV}.remote" 2>/dev/null || true
  if [[ -f "${OUT_CSV}.remote" ]]; then
    mv "${OUT_CSV}.remote" "$OUT_CSV"
    print_summary
  fi
}

main() {
  parse_args "$@"
  if [[ "$API_ONLY" == "1" ]]; then
    API="${OLLAMA_HOST:-http://${VM310_TS_IP}:11434}"
  fi
  if [[ "$REMOTE" == "1" ]]; then
    run_remote
  else
    run_local
  fi
}

main "$@"
