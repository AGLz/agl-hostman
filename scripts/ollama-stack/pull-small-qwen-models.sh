#!/usr/bin/env bash
# Puxa SOMENTE modelos com reasoning (thinking mode) para o CT200.
# GPU do CT200: GeForce GTX 1650 — 4096 MiB (4GB VRAM).
#
# Uso na máquina com ollama no PATH:
#   ./scripts/ollama-stack/pull-small-qwen-models.sh
#
# Reason: GTX 1650 4GB (CT200) — só reasoning models que cabem em VRAM.
# - Qwen3 0.6B: ~523MB (thinking mode)
# - Qwen3 1.7B: ~1.4GB (thinking mode)
# - DeepSeek-R1 1.5B: ~1.1GB (reasoning puro)

set -euo pipefail

if ! command -v ollama &>/dev/null; then
  echo "ERRO: comando ollama não encontrado. Instalar no host ou usar pct exec CT200 -- ollama ..." >&2
  exit 1
fi

pull() {
  echo ">>> ollama pull $1"
  ollama pull "$1"
}

# Qwen3 — thinking mode nativo (--think)
pull qwen3:0.6b
pull qwen3:1.7b

# DeepSeek-R1 — reasoning puro
pull deepseek-r1:1.5b

echo ""
echo "Concluído. Todos os modelos são reasoning (thinking mode)."
echo "Ver: ollama list"
echo "Usar com --think: ollama run qwen3:1.7b --think"
exit 0
