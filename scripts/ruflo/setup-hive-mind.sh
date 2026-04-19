#!/usr/bin/env bash
# Configura Hive Mind para coordenação multi-agente em agldv03
# Uso: ./scripts/ruflo/setup-hive-mind.sh [host]

set -e
HOST="${1:-}"
HOME="${HOME:-/root}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/ruflo"
HIVE_ENV="$CONFIG_DIR/hive-mind.env"
RUFLO_DIR="$HOME/.ruflo"

run_cmd() {
  if [[ -n "$HOST" ]]; then
    ssh "$HOST" "$@"
  else
    "$@"
  fi
}

echo "=== Hive Mind Setup ==="
echo "Host: ${HOST:-local}"
echo ""

# 1. Copiar config
echo "1. Configuração..."
if [[ -f "$HIVE_ENV" ]]; then
  run_cmd mkdir -p "$RUFLO_DIR"
  if [[ -n "$HOST" ]]; then
    scp "$HIVE_ENV" "$HOST:$RUFLO_DIR/hive-mind.env" 2>/dev/null || true
  else
    cp "$HIVE_ENV" "$RUFLO_DIR/hive-mind.env" 2>/dev/null || true
  fi
  echo "  OK: hive-mind.env"
  [[ -f "$HIVE_ENV" ]] && source "$HIVE_ENV" 2>/dev/null || true
fi
echo ""

# 2. Hive init
echo "2. Hive Mind init..."
if run_cmd "npx ruflo@latest hive-mind init" 2>/dev/null; then
  echo "  OK: hive-mind inicializado"
elif run_cmd "npx claude-flow@alpha hive init --topology mesh --agents 5" 2>/dev/null; then
  echo "  OK: hive init (claude-flow)"
else
  echo "  Tentando hive-mind init alternativo..."
  run_cmd "npx claude-flow@alpha hive-mind init" 2>/dev/null || echo "  WARN: hive-mind init não disponível"
fi
echo ""

# 3. Verificar comandos
echo "3. Comandos disponíveis..."
echo "  npx ruflo hive-mind spawn \"Build API\" --queen-type tactical"
echo "  npx ruflo hive-mind spawn \"Research AI\" --consensus byzantine --claude"
echo "  npx claude-flow@alpha hive init --topology hierarchical --agents 8"
echo ""

echo "=== Hive Mind setup concluído ==="
echo "Próximo: ./scripts/ruflo/setup-reasoningbank.sh"
