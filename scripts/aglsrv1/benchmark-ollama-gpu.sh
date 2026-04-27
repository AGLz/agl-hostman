#!/usr/bin/env bash
# Validação: inferência Ollama + uso de GPU (nvidia-smi / ollama ps).
# Executar no CT200: bash benchmark-ollama-gpu.sh
# Ou desde o host: pct exec 200 -- bash -s < benchmark-ollama-gpu.sh

set -uo pipefail

API="${OLLAMA_HOST:-http://127.0.0.1:11434}"
MODELS="${MODELS:-qwen3:0.6b deepseek-r1:1.5b qwen3:4b}"

echo "=== Ollama / GPU ==="
ollama --version || true
echo
nvidia-smi -L
echo
echo "=== Baseline VRAM (MiB used) ==="
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader
echo

sample_gpu() {
  echo "--- nvidia-smi (processos na GPU) ---"
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || nvidia-smi | sed -n '/Processes:/,$p' | head -20
  echo "--- ollama ps ---"
  ollama ps || true
  echo "--- VRAM total usada ---"
  nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader
  echo
}

for M in $MODELS; do
  echo "############################################"
  echo "### Modelo: $M ###"
  echo "############################################"

  printf '%s' "{\"model\":\"${M}\",\"prompt\":\"Explain in 3 short sentences why GPUs accelerate matrix math.\",\"stream\":false,\"options\":{\"num_predict\":160}}" > /tmp/ollama-bench.json

  echo "[$(date -Iseconds)] Amostra GPU antes do pedido"
  sample_gpu

  echo "[$(date -Iseconds)] POST /api/generate (num_predict=160)..."
  rm -f /tmp/gpu-samples.txt
  (
    i=0
    while [ "$i" -lt 40 ]; do
      date -Iseconds 2>/dev/null || date
      nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
      nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader 2>/dev/null || true
      echo "---"
      sleep 0.25
      i=$((i + 1))
    done
  ) >> /tmp/gpu-samples.txt &
  SAMPLER_PID=$!

  START=$(date +%s)
  if ! curl -sS -m 300 -X POST "${API}/api/generate" \
    -H "Content-Type: application/json" \
    -d @/tmp/ollama-bench.json -o /tmp/ollama-bench-out.json; then
    echo "curl falhou para $M"
    kill "$SAMPLER_PID" 2>/dev/null || true
    continue
  fi
  END=$(date +%s)
  WALL=$((END - START))
  kill "$SAMPLER_PID" 2>/dev/null || true
  wait "$SAMPLER_PID" 2>/dev/null || true

  echo "[$(date -Iseconds)] Pedido concluído (wall ~${WALL}s)"
  echo "--- Amostras GPU durante inferência (trecho) ---"
  head -60 /tmp/gpu-samples.txt || true
  echo

  python3 << 'PY'
import json
with open("/tmp/ollama-bench-out.json") as f:
    d = json.load(f)
if "error" in d:
    print("ERRO:", d["error"])
    raise SystemExit(0)
# durações em nanosegundos
def ns_to_s(n):
    return round(n / 1e9, 3) if n else None
ev = d.get("eval_count") or 0
ed = d.get("eval_duration") or 0
tps = None
if ed and ev:
    tps = round(ev / (ed / 1e9), 2)
print("response_preview:", (d.get("response") or "")[:120].replace("\n", " "))
print("load_duration_s:", ns_to_s(d.get("load_duration")))
print("prompt_eval_duration_s:", ns_to_s(d.get("prompt_eval_duration")))
print("eval_duration_s:", ns_to_s(ed))
print("eval_count:", ev)
print("total_duration_s:", ns_to_s(d.get("total_duration")))
print("eval_tokens_per_s (aprox):", tps)
PY

  echo "[$(date -Iseconds)] Amostra GPU após o pedido (modelo pode ficar residente)"
  sample_gpu
  echo
done

echo "=== Resumo ==="
echo "Se a GPU está a ser usada: nvidia-smi mostra VRAM >> 1 MiB durante/após carga e/ou processos em 'GPU Memory Usage'."
echo "ollama ps: coluna PROCESSOR deve indicar GPU (ex.: 100% GPU) com modelo carregado."
echo "Se tudo corre só em CPU: VRAM quase nula e PROCESSOR CPU (ou ausência de processo na GPU)."
