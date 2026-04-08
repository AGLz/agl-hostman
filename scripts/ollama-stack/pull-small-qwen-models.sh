#!/usr/bin/env bash
# Puxa Qwen pequenos + Gemma 4 na library Ollama (foco custo-latência em GPU modesta).
# GPU do CT200: GeForce GTX 1650 — 4096 MiB (4GB VRAM).
# Ref: https://ollama.com/library/qwen3 — qwen3:0.6b ~523MB; qwen3:1.7b ~1.4GB.
# Ref: https://ollama.com/library/gemma4 — gemma4:e2b ~1.5GB (Google 2026-03-31).
#
# Uso na máquina com ollama no PATH:
#   ./scripts/ollama-stack/pull-small-qwen-models.sh
#   ./scripts/ollama-stack/pull-small-qwen-models.sh --minimal   # só 0.6b + 1.7b + gemma4:e2b
#
# Reason: GTX 1650 4GB (CT200) — evitar modelos >3GB que exigem offload CPU lento.

set -euo pipefail

MINIMAL=0
[[ "${1:-}" == "--minimal" ]] && MINIMAL=1

if ! command -v ollama &>/dev/null; then
  echo "ERRO: comando ollama não encontrado. Instalar no host ou usar pct exec CT200 -- ollama ..." >&2
  exit 1
fi

pull() {
  echo ">>> ollama pull $1"
  ollama pull "$1"
}

# Qwen3 (geração atual; desempenho forte por tamanho — ver readme library)
pull qwen3:0.6b
pull qwen3:1.7b

# Gemma 4 (Google 2026-03-31; qualidade superior a Qwen3 de tamanho similar)
pull gemma4:e2b

if [[ "$MINIMAL" -eq 0 ]]; then
  # qwen3:4b ~2.5GB — borderline em 4GB; ok se não houver outro modelo carregado
  pull qwen3:4b
fi

echo ""
echo "Concluído. Ver: ollama list"
exit 0
