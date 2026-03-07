#!/usr/bin/env bash
# Configura RuVector para memória vetorial em agldv03
# Uso: ./scripts/ruflo/setup-ruvector.sh [host]

set -e
HOST="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/ruflo"
RUVECTOR_ENV="$CONFIG_DIR/ruvector.env"

run_cmd() {
  if [[ -n "$HOST" ]]; then
    ssh "$HOST" "$@"
  else
    "$@"
  fi
}

echo "=== RuVector Setup ==="
echo "Host: ${HOST:-local}"
echo ""

# 1. Criar diretório de storage
echo "1. Criando diretório de storage..."
HOME="${HOME:-/root}"
STORAGE="${RUVECTOR_STORAGE_PATH:-$HOME/.ruflo/ruvector}"
run_cmd mkdir -p "$STORAGE"
echo "  OK: $STORAGE"
echo ""

# 2. Copiar config
echo "2. Configuração..."
if [[ -f "$RUVECTOR_ENV" ]]; then
  if [[ -n "$HOST" ]]; then
    scp "$RUVECTOR_ENV" "$HOST:~/.ruflo/ruvector.env" 2>/dev/null || true
    run_cmd "mkdir -p ~/.ruflo"
    run_cmd "cat > ~/.ruflo/ruvector.env" < "$RUVECTOR_ENV" 2>/dev/null || true
  else
    mkdir -p "$HOME/.ruflo"
    cp "$RUVECTOR_ENV" "$HOME/.ruflo/ruvector.env" 2>/dev/null || true
  fi
  echo "  OK: ruvector.env"
else
  echo "  WARN: $RUVECTOR_ENV não encontrado"
fi
echo ""

# 3. RuVector init (se comando existir)
echo "3. RuVector init..."
if run_cmd "npx ruflo@latest ruvector --help" 2>/dev/null; then
  run_cmd "npx ruflo@latest ruvector init --database agl_ruvector" 2>/dev/null || echo "  WARN: init falhou (pode precisar de PostgreSQL)"
else
  echo "  SKIP: ruvector CLI não disponível nesta versão"
  echo "  RuVector pode estar em @ruvector/sona ou módulo separado"
fi
echo ""

# 4. Benchmark (opcional)
echo "4. Benchmark..."
if run_cmd "npx ruflo@latest ruvector benchmark --iterations 10" 2>/dev/null; then
  echo "  OK: benchmark executado"
else
  echo "  SKIP: benchmark não disponível"
fi
echo ""

echo "=== RuVector setup concluído ==="
echo "Próximo: ./scripts/ruflo/setup-background-workers.sh"
