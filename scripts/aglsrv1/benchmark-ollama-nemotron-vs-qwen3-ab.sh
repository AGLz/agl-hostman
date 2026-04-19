#!/usr/bin/env bash
# A/B: nemotron-3-nano:4b vs qwen3:4b no Ollama (CT200 ou local).
# Métricas: total_duration, load_duration, prompt_eval_count, eval_count.
# Uso: OLLAMA_HOST=http://127.0.0.1:11434 bash benchmark-ollama-nemotron-vs-qwen3-ab.sh
# Reason: prompts fixos para comparar PT/EN/JSON antes de mudar LiteLLM.

set -uo pipefail

API="${OLLAMA_HOST:-http://127.0.0.1:11434}"
OUT_JSON="${OUT_JSON:-/tmp/ollama-ab-results.json}"

stop_all() {
  ollama stop nemotron-3-nano:4b 2>/dev/null || true
  ollama stop qwen3:4b 2>/dev/null || true
  sleep 2
}

chat_once() {
  local model="$1"
  local think="$2"
  local prompt_file="$3"
  python3 - "$API" "$model" "$think" "$prompt_file" <<'PY'
import json, sys, urllib.request
api, model, think, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
think_b = think.lower() in ("1", "true", "yes")
with open(path, encoding="utf-8") as f:
    content = f.read().strip()
body = {
    "model": model,
    "messages": [{"role": "user", "content": content}],
    "stream": False,
    "think": think_b,
}
data = json.dumps(body).encode("utf-8")
req = urllib.request.Request(
    api.rstrip("/") + "/api/chat",
    data=data,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=240) as resp:
        print(resp.read().decode("utf-8"))
except Exception as e:
    print(json.dumps({"error": str(e), "model": model}))
PY
}

run_case() {
  local name="$1"
  local model="$2"
  local think="$3"
  local prompt_file="$4"

  echo ">>> ${name}" >&2
  stop_all
  chat_once "${model}" "${think}" "${prompt_file}" >/dev/null 2>&1 || true
  # Reason: não voltar a parar o modelo aqui — a medição usa a mesma carga em VRAM.

  local wall0 wall1 body
  wall0=$(date +%s%3N 2>/dev/null || date +%s)
  body=$(chat_once "${model}" "${think}" "${prompt_file}") || body='{"error":"chat_failed"}'
  wall1=$(date +%s%3N 2>/dev/null || date +%s)

  python3 - "$name" "$model" "$think" "$wall0" "$wall1" "$body" <<'PY'
import json, sys
name, model, think, w0, w1, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
think_b = think.lower() == "true"
try:
    d = json.loads(body)
except json.JSONDecodeError:
    print(json.dumps({"case": name, "model": model, "think": think_b, "error": "invalid_json"}))
    raise SystemExit(0)

err = d.get("error")
if err:
    print(json.dumps({"case": name, "model": model, "think": think_b, "error": str(err)}))
    raise SystemExit(0)

msg = d.get("message") or {}
think_txt = msg.get("thinking") or d.get("thinking") or ""
row = {
    "case": name,
    "model": model,
    "think": think_b,
    "wall_ms_approx": None,
    "total_duration_ns": d.get("total_duration"),
    "load_duration_ns": d.get("load_duration"),
    "prompt_eval_count": d.get("prompt_eval_count"),
    "eval_count": d.get("eval_count"),
    "content_len": len((msg.get("content") or "")),
    "thinking_len": len(think_txt) if isinstance(think_txt, str) else 0,
}
try:
    wf = float(w0) if "." in str(w0) else int(w0) * 1000
    wt = float(w1) if "." in str(w1) else int(w1) * 1000
    row["wall_ms_approx"] = int(wt - wf)
except Exception:
    pass
print(json.dumps(row, ensure_ascii=False))
PY
}

main() {
  command -v python3 >/dev/null || {
    echo "python3 necessário" >&2
    exit 1
  }
  command -v ollama >/dev/null || {
    echo "ollama CLI necessário para ollama stop" >&2
    exit 1
  }

  local d
  d=$(mktemp -d)
  # Prompts fixos
  cat >"${d}/pt.txt" <<'EOF'
Responde numa única frase em português europeu: o que é um balanceador de carga em cloud?
EOF
  cat >"${d}/en.txt" <<'EOF'
In one English sentence: what does idempotent mean for an HTTP POST API?
EOF
  cat >"${d}/json.txt" <<'EOF'
Return ONLY compact JSON with keys ok (boolean) and n (integer 42). No markdown, no explanation.
EOF

  : >"${OUT_JSON}"
  echo "[" >"${OUT_JSON}.tmp"
  local first=1
  emit() {
    if [[ "$first" -eq 1 ]]; then
      first=0
    else
      echo "," >>"${OUT_JSON}.tmp"
    fi
    echo "$1" >>"${OUT_JSON}.tmp"
  }

  emit "$(run_case "nemotron_PT_thinkfalse" "nemotron-3-nano:4b" "false" "${d}/pt.txt")"
  emit "$(run_case "nemotron_PT_thinktrue" "nemotron-3-nano:4b" "true" "${d}/pt.txt")"
  emit "$(run_case "nemotron_JSON_thinkfalse" "nemotron-3-nano:4b" "false" "${d}/json.txt")"
  emit "$(run_case "qwen3_PT" "qwen3:4b" "false" "${d}/pt.txt")"
  emit "$(run_case "qwen3_EN" "qwen3:4b" "false" "${d}/en.txt")"
  emit "$(run_case "qwen3_JSON" "qwen3:4b" "false" "${d}/json.txt")"

  echo "]" >>"${OUT_JSON}.tmp"
  mv "${OUT_JSON}.tmp" "${OUT_JSON}"
  rm -rf "${d}"

  echo "=== Resultados (${OUT_JSON}) ===" >&2
  python3 - <<'PY'
import json
from pathlib import Path

p = Path("/tmp/ollama-ab-results.json")
rows = json.loads(p.read_text(encoding="utf-8"))


def ns_to_ms(x):
    if x is None:
        return None
    return round(x / 1e6, 1)


print(f"{'case':<28} {'model':<22} {'think':<5} {'total_ms':>10} {'load_ms':>9} {'tok_out':>7} {'think_len':>9}")
print("-" * 100)
for r in rows:
    if r.get("error"):
        print(f"{r.get('case', '?'):<28} ERROR: {r['error']}")
        continue
    tl = r.get("thinking_len", 0)
    print(
        f"{r.get('case', ''):<28} {r.get('model', ''):<22} {str(r.get('think')):<5} "
        f"{str(ns_to_ms(r.get('total_duration_ns'))):>10} {str(ns_to_ms(r.get('load_duration_ns'))):>9} "
        f"{str(r.get('eval_count')):>7} {str(tl):>9}"
    )
PY
}

main "$@"
