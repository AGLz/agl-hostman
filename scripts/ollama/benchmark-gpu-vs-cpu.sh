#!/usr/bin/env bash
# Benchmark Ollama GPU vs CPU — tokens/s, latência, processor (/api/ps).
#
# Uso (API remota, só GPU):
#   OLLAMA_GPU_URL=http://100.74.118.51:11434 \
#   MODELS="qwen3:4b" \
#   bash scripts/ollama/benchmark-gpu-vs-cpu.sh
#
# GPU + CPU na VM110 (SSH — arranca Ollama temporário OLLAMA_NUM_GPU=0 :11436):
#   BENCH_SSH=root@100.74.118.51 \
#   OLLAMA_GPU_URL=http://100.74.118.51:11434 \
#   MODELS="qwen3:4b" \
#   bash scripts/ollama/benchmark-gpu-vs-cpu.sh
#
# VM310 dual-GPU:
#   OLLAMA_GPU_URL=http://100.67.253.52:11434 \
#   OLLAMA_GPU1_URL=http://100.67.253.52:11435 \
#   MODELS="gemma4-qat qwen3:8b qwen3:4b" \
#   bash scripts/ollama/benchmark-gpu-vs-cpu.sh
#
# Saída: OUT_DIR/ollama-gpu-cpu-YYYYMMDD-HHMMSS.{csv,md}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/docs/litellm-battery}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_CSV="$OUT_DIR/ollama-gpu-cpu-${STAMP}.csv"
OUT_MD="$OUT_DIR/ollama-gpu-cpu-${STAMP}.md"

OLLAMA_GPU_URL="${OLLAMA_GPU_URL:-http://100.67.253.52:11434}"
OLLAMA_GPU1_URL="${OLLAMA_GPU1_URL:-}"
BENCH_SSH="${BENCH_SSH:-}"
CPU_PORT="${CPU_BENCH_PORT:-11436}"
NUM_PREDICT="${NUM_PREDICT:-128}"
OLLAMA_THINK="${OLLAMA_THINK:-false}"
KEEP_ALIVE="${KEEP_ALIVE:-5m}"

if [[ -n "${MODELS:-}" ]]; then
  # shellcheck disable=SC2206
  BENCH_MODELS=($MODELS)
else
  BENCH_MODELS=(qwen3:4b gemma4-qat qwen3:8b llama3.1:8b)
fi

PROMPT_PT="Responde numa frase curta em português europeu: para que serve um balanceador de carga?"
PROMPT_JSON='Return ONLY compact JSON {"ok":true,"n":42}. No markdown.'

log() { printf '[gpu-cpu-bench] %s\n' "$*" >&2; }

chat_once() {
  local api="$1" model="$2" prompt="$3"
  python3 - "$api" "$model" "$prompt" "$NUM_PREDICT" "$KEEP_ALIVE" "$OLLAMA_THINK" <<'PY'
import json, sys, urllib.request

api, model, prompt, num_predict, keep_alive, think_flag = sys.argv[1:7]
body = {
    "model": model,
    "messages": [{"role": "user", "content": prompt}],
    "stream": False,
    "keep_alive": keep_alive,
    "options": {"num_predict": int(num_predict)},
}
if think_flag.lower() not in ("1", "true", "yes", "on"):
    body["think"] = False
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

unload_model() {
  local api="$1" model="$2"
  curl -sf "${api%/}/api/chat" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"messages\":[],\"keep_alive\":0}" >/dev/null 2>&1 || true
  sleep 2
}

parse_ps() {
  local api="$1" model="$2"
  local raw
  raw="$(curl -sf "${api%/}/api/ps" 2>/dev/null || echo '{}')"
  python3 - "$model" "$raw" <<'PY'
import json, sys
target, raw = sys.argv[1], sys.argv[2]
try:
    data = json.loads(raw or "{}")
except json.JSONDecodeError:
    print("|")
    raise SystemExit(0)
for entry in data.get("models") or []:
    name = entry.get("name") or entry.get("model") or ""
    if name != target and not name.startswith(target + ":"):
        continue
    vram = entry.get("size_vram") or 0
    total = entry.get("size") or 0
    if vram and total:
        pct = round(100 * vram / total) if total else 100
        proc = f"{pct}% GPU"
    elif vram:
        proc = "GPU"
    else:
        proc = "CPU"
    gb = f"{total / (1024**3):.1f} GB" if total else ""
    print(f"{proc}|{gb}")
    break
else:
    print("|")
PY
}

parse_metrics() {
  local model="$1" mode="$2" target="$3" case="$4" wall_ms="$5" ps_info="$6" body="$7"
  python3 - "$model" "$mode" "$target" "$case" "$wall_ms" "$ps_info" "$body" <<'PY'
import json, sys

model, mode, target, case, wall_ms, ps_info, body = sys.argv[1:8]
proc, vram = (ps_info.split("|", 1) + [""])[:2]

try:
    d = json.loads(body or "")
except json.JSONDecodeError:
    print(f"{model},{mode},{target},{case},FAIL,,,,,,invalid json,{proc},{vram}")
    raise SystemExit(0)

if d.get("error"):
    err = str(d.get("error")).replace(",", ";")[:120]
    print(f"{model},{mode},{target},{case},FAIL,,,,,,{err},{proc},{vram}")
    raise SystemExit(0)

msg = d.get("message") or {}
content = (msg.get("content") or "")[:60].replace(",", ";").replace("\n", " ")
if not content.strip():
    think = msg.get("thinking") or ""
    if isinstance(think, str) and think.strip():
        content = think[:60].replace(",", ";")

ev = d.get("eval_count") or 0
ed = d.get("eval_duration") or 0
tps = round(ev / (ed / 1e9), 2) if ed and ev else ""
load_ms = round((d.get("load_duration") or 0) / 1e6, 1)
total_ms = round((d.get("total_duration") or 0) / 1e6, 1)

print(
    f"{model},{mode},{target},{case},OK,{wall_ms},{load_ms},{total_ms},{ev},{tps},{content},{proc},{vram}"
)
PY
}

bench_target() {
  local api="$1" mode="$2" label="$3" model="$4"
  log "  [$mode] $label — $model"

  unload_model "$api" "$model"

  local warm
  warm=$(chat_once "$api" "$model" "ok" || true)
  if ! echo "$warm" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(1 if d.get('error') else 0)" 2>/dev/null; then
    log "    warm-load falhou"
    printf '%s\n' "$model,$mode,$label,warm,FAIL,,,,,,warm failed,," >>"$OUT_CSV"
    return 0
  fi

  local ps_info wall0 wall1 body
  ps_info=$(parse_ps "$api" "$model")

  wall0=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
  body=$(chat_once "$api" "$model" "$PROMPT_PT")
  wall1=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
  local wall_ms=$((wall1 - wall0))
  parse_metrics "$model" "$mode" "$label" "chat" "$wall_ms" "$ps_info" "$body" >>"$OUT_CSV"

  body=$(chat_once "$api" "$model" "$PROMPT_JSON")
  parse_metrics "$model" "$mode" "$label" "json" "" "$(parse_ps "$api" "$model")" "$body" >>"$OUT_CSV"

  unload_model "$api" "$model"
}

start_cpu_server() {
  [[ -z "$BENCH_SSH" ]] && return 1
  log "Arrancar Ollama CPU temporário em $BENCH_SSH:$CPU_PORT ..."
  ssh -o BatchMode=yes "$BENCH_SSH" bash -s -- "$CPU_PORT" <<'REMOTE'
set -euo pipefail
PORT="$1"
if curl -sf "http://127.0.0.1:${PORT}/api/tags" >/dev/null 2>&1; then
  echo "cpu-server-already-running"
  exit 0
fi
pkill -f "OLLAMA_HOST=127.0.0.1:${PORT}" 2>/dev/null || true
sleep 1
sudo -u ollama env HOME=/usr/share/ollama \
  OLLAMA_HOST="127.0.0.1:${PORT}" \
  OLLAMA_NUM_GPU=0 \
  OLLAMA_MAX_LOADED_MODELS=1 \
  OLLAMA_KEEP_ALIVE=5m \
  nohup ollama serve >>"/tmp/ollama-cpu-bench-${PORT}.log" 2>&1 &
echo $! > "/tmp/ollama-cpu-bench-${PORT}.pid"
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:${PORT}/api/tags" >/dev/null 2>&1 && exit 0
  sleep 1
done
echo "cpu-server-failed"
exit 1
REMOTE
}

stop_cpu_server() {
  [[ -z "$BENCH_SSH" ]] && return 0
  ssh -o BatchMode=yes "$BENCH_SSH" bash -s -- "$CPU_PORT" <<'REMOTE' || true
PORT="$1"
if [[ -f "/tmp/ollama-cpu-bench-${PORT}.pid" ]]; then
  kill "$(cat "/tmp/ollama-cpu-bench-${PORT}.pid")" 2>/dev/null || true
  rm -f "/tmp/ollama-cpu-bench-${PORT}.pid"
fi
pkill -f "OLLAMA_HOST=127.0.0.1:${PORT}" 2>/dev/null || true
REMOTE
}

write_report() {
  python3 - "$OUT_CSV" "$OUT_MD" "$OLLAMA_GPU_URL" "$OLLAMA_GPU1_URL" "$BENCH_SSH" "$CPU_PORT" <<'PY'
import csv, sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

csv_path, md_path, gpu0, gpu1, ssh, cpu_port = sys.argv[1:7]
rows = list(csv.reader(Path(csv_path).read_text(encoding="utf-8").splitlines()))
header, data = rows[0], [r for r in rows[1:] if r]

def idx(name):
    return header.index(name)

by_key = defaultdict(dict)
for r in data:
    while len(r) < len(header):
        r.append("")
    key = (r[idx("model")], r[idx("case")])
    mode = r[idx("mode")]
    by_key[key][mode] = r

lines = [
    "# Ollama GPU vs CPU — tokens/s",
    "",
    f"**Gerado:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
    f"**GPU0:** `{gpu0}`",
]
if gpu1:
    lines.append(f"**GPU1:** `{gpu1}`")
if ssh:
    lines.append(f"**CPU (SSH):** `{ssh}` port `{cpu_port}` (`OLLAMA_NUM_GPU=0`)")
lines += ["", "## Comparativo (chat PT)", "", "| Modelo | GPU tok/s | CPU tok/s | GPU ms | CPU ms | GPU proc | CPU proc |", "|--------|-----------|-----------|--------|--------|----------|----------|"]

gpu_cpu_only = []
for (model, case), modes in sorted(by_key.items()):
    if case != "chat":
        continue
    g = modes.get("gpu-g0") or modes.get("gpu") or modes.get("gpu-g1") or []
    c = modes.get("cpu") or []
    if not isinstance(g, list):
        g = []
    if not isinstance(c, list):
        c = []
    def get(row, col):
        if not row:
            return "-"
        try:
            v = row[idx(col)]
            return v if v else "-"
        except (IndexError, ValueError):
            return "-"
    g_proc = get(g, "processor")
    if g and g_proc == "CPU":
        gpu_cpu_only.append(model)
    lines.append(
        f"| `{model}` | {get(g,'tok_per_s')} | {get(c,'tok_per_s')} | {get(g,'wall_ms')} | {get(c,'wall_ms')} | {get(g,'processor')} | {get(c,'processor')} |"
    )

if gpu_cpu_only:
    lines += [
        "",
        "> **Aviso:** endpoint GPU reportou `processor=CPU` em `/api/ps` — passthrough/driver pode estar indisponível; comparativo GPU vs CPU pode estar invalidado.",
        "",
    ]

lines += ["", "## JSON", "", "| Modelo | GPU tok/s | CPU tok/s |", "|--------|-----------|-----------|"]
for (model, case), modes in sorted(by_key.items()):
    if case != "json":
        continue
    g = modes.get("gpu-g0") or modes.get("gpu") or modes.get("gpu-g1") or []
    c = modes.get("cpu") or []
    if not isinstance(g, list):
        g = []
    if not isinstance(c, list):
        c = []
    def get(row, col):
        if not row:
            return "-"
        try:
            return row[idx(col)] or "-"
        except (IndexError, ValueError):
            return "-"
    lines.append(f"| `{model}` | {get(g,'tok_per_s')} | {get(c,'tok_per_s')} |")

lines.append("")
lines.append(f"CSV: `{csv_path}`")
Path(md_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Relatório: {md_path}")
PY
}

main() {
  mkdir -p "$OUT_DIR"
  printf '%s\n' \
    "model,mode,target,case,status,wall_ms,load_ms,total_ms,eval_count,tok_per_s,preview,processor,vram" \
    >"$OUT_CSV"

  local cpu_url=""
  if [[ -n "$BENCH_SSH" ]]; then
    if start_cpu_server; then
      cpu_url="http://127.0.0.1:${CPU_PORT}"
      # tunnel not needed if we run CPU bench via SSH subprocess — use ssh curl instead
    fi
  fi

  for model in "${BENCH_MODELS[@]}"; do
    log "=== $model ==="

    if curl -sf --max-time 5 "${OLLAMA_GPU_URL%/}/api/tags" >/dev/null 2>&1; then
      bench_target "$OLLAMA_GPU_URL" "gpu-g0" "$OLLAMA_GPU_URL" "$model"
    else
      log "  SKIP GPU0 (inacessível): $OLLAMA_GPU_URL"
    fi

    if [[ -n "$OLLAMA_GPU1_URL" ]] && curl -sf --max-time 5 "${OLLAMA_GPU1_URL%/}/api/tags" >/dev/null 2>&1; then
      bench_target "$OLLAMA_GPU1_URL" "gpu-g1" "$OLLAMA_GPU1_URL" "$model"
    fi

    if [[ -n "$BENCH_SSH" ]]; then
      export OUT_CSV
      ssh -o BatchMode=yes "$BENCH_SSH" bash -s -- "$CPU_PORT" "$model" "$NUM_PREDICT" "$KEEP_ALIVE" "$OLLAMA_THINK" "$PROMPT_PT" "$PROMPT_JSON" <<'REMOTE' | while IFS= read -r line; do printf '%s\n' "$line" >>"$OUT_CSV"; done
set -euo pipefail
PORT="$1" MODEL="$2" NUM_PREDICT="$3" KEEP_ALIVE="$4" THINK="$5" PROMPT_PT="$6" PROMPT_JSON="$7"
API="http://127.0.0.1:${PORT}"

chat() {
  local prompt="$1"
  python3 - "$API" "$MODEL" "$prompt" "$NUM_PREDICT" "$KEEP_ALIVE" "$THINK" <<'PY'
import json, sys, urllib.request
api, model, prompt, num_predict, keep_alive, think_flag = sys.argv[1:7]
body = {"model": model, "messages": [{"role": "user", "content": prompt}], "stream": False, "keep_alive": keep_alive, "options": {"num_predict": int(num_predict)}}
if think_flag.lower() not in ("1", "true", "yes", "on"):
    body["think"] = False
req = urllib.request.Request(api.rstrip("/") + "/api/chat", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(req, timeout=600) as resp:
    print(resp.read().decode())
PY
}

curl -sf "${API}/api/chat" -H "Content-Type: application/json" -d "{\"model\":\"${MODEL}\",\"messages\":[],\"keep_alive\":0}" >/dev/null 2>&1 || true
sleep 2
chat "$PROMPT_PT" >/dev/null || true
ps_info=$(curl -sf "${API}/api/ps" | python3 -c "import json,sys;d=json.load(sys.stdin);e=(d.get('models')or[{}])[0];v=e.get('size_vram')or 0;t=e.get('size')or 0;print('CPU|'+(f'{t/(1024**3):.1f} GB' if t else ''))" 2>/dev/null || echo "CPU|")

w0=$(date +%s%3N 2>/dev/null || echo 0)
body=$(chat "$PROMPT_PT")
w1=$(date +%s%3N 2>/dev/null || echo 0)
wall=$((w1 - w0))
python3 - "$MODEL" "cpu" "127.0.0.1:${PORT}" "chat" "$wall" "$ps_info" "$body" <<'PY'
import json, sys
model, mode, target, case, wall_ms, ps_info, body = sys.argv[1:8]
proc, vram = (ps_info.split("|", 1) + [""])[:2]
try:
    d = json.loads(body or "")
except json.JSONDecodeError:
    print(f"{model},{mode},{target},{case},FAIL,,,,,,invalid json,{proc},{vram}")
    raise SystemExit(0)
if d.get("error"):
    print(f"{model},{mode},{target},{case},FAIL,,,,,,{d['error']},{proc},{vram}")
else:
    msg = d.get("message") or {}
    ev, ed = d.get("eval_count") or 0, d.get("eval_duration") or 0
    tps = round(ev / (ed / 1e9), 2) if ed and ev else ""
    preview = (msg.get("content") or "")[:60].replace(",", ";")
    print(f"{model},{mode},{target},{case},OK,{wall_ms},{round((d.get('load_duration') or 0)/1e6,1)},{round((d.get('total_duration') or 0)/1e6,1)},{ev},{tps},{preview},{proc},{vram}")
PY

body=$(chat "$PROMPT_JSON")
python3 - "$MODEL" "cpu" "127.0.0.1:${PORT}" "json" "" "$ps_info" "$body" <<'PY'
import json, sys
model, mode, target, case, wall_ms, ps_info, body = sys.argv[1:8]
proc, vram = (ps_info.split("|", 1) + [""])[:2]
try:
    d = json.loads(body or "")
except json.JSONDecodeError:
    print(f"{model},{mode},{target},{case},FAIL,,,,,,invalid json,{proc},{vram}")
    raise SystemExit(0)
if d.get("error"):
    print(f"{model},{mode},{target},{case},FAIL,,,,,,{d['error']},{proc},{vram}")
else:
    ev, ed = d.get("eval_count") or 0, d.get("eval_duration") or 0
    tps = round(ev / (ed / 1e9), 2) if ed and ev else ""
    preview = ((d.get("message") or {}).get("content") or "")[:60].replace(",", ";")
    print(f"{model},{mode},{target},{case},OK,,{round((d.get('load_duration') or 0)/1e6,1)},{round((d.get('total_duration') or 0)/1e6,1)},{ev},{tps},{preview},{proc},{vram}")
PY
REMOTE
    fi
  done

  stop_cpu_server
  write_report
  log "CSV: $OUT_CSV"
  column -t -s, "$OUT_CSV" 2>/dev/null | head -40 || cat "$OUT_CSV"
}

trap 'stop_cpu_server' EXIT
main "$@"
