#!/usr/bin/env bash
# Puxa Qwen pequenos / rápidos + Gemma 4 na library Ollama (foco custo-latência em GPU modesta).
# Ref: https://ollama.com/library/qwen3 — qwen3:4b ~2.5GB, 256K context; qwen3:0.6b ~523MB.
# Ref: https://ollama.com/library/gemma4 — gemma4:e4b ~2.8GB; gemma4:e2b ~1.5GB (Google 2026-03-31).
# Qwen2.5 legado: qwen2.5:3b, qwen2.5:7b, qwen2.5-coder:7b (código).
#
# Uso na máquina com ollama no PATH:
#   ./scripts/ollama-stack/pull-small-qwen-models.sh
#   ./scripts/ollama-stack/pull-small-qwen-models.sh --minimal   # só 0.6b + 1.7b + 4b + gemma4:e2b
#
# Reason: RTX 3060 12GB (CT200) — evitar três modelos 32B+ carregados em paralelo.

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
pull qwen3:4b

# Gemma 4 (Google 2026-03-31; coding/razão superiores a Qwen3 de tamanho similar)
pull gemma4:e2b

if [[ "$MINIMAL" -eq 0 ]]; then
  pull qwen3:8b
  pull gemma4:e4b
  # Qwen2.5: ainda útil para compat e benchmarks conhecidos
  pull qwen2.5:3b
  pull qwen2.5:7b
  pull qwen2.5-coder:7b
fi

echo ""
echo "Concluído. Ver: ollama list"
exit 0
