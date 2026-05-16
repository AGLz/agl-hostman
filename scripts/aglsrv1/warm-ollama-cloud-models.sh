#!/usr/bin/env bash
# Pré-aquece o único modelo Ollama local no CT200 (qwen3:4b).
# Nome do ficheiro mantido por compatibilidade com ollama-warm-cloud.service (pode renomear o unit depois).
set -euo pipefail

OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
MODEL="qwen3:4b"

echo "warm: $MODEL"
curl -sS -m 120 -X POST "${OLLAMA_URL}/api/generate" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"${MODEL}\",\"prompt\":\"ping\",\"stream\":false,\"options\":{\"num_predict\":8}}" \
  >/dev/null

echo "Concluído."
