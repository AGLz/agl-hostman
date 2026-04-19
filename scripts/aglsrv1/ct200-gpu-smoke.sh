#!/bin/bash
set -euo pipefail
curl -sS -m 180 -X POST http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3:0.6b","prompt":"Reply with exactly: OK","stream":false}' | head -c 400
echo
ollama ps
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null || true
