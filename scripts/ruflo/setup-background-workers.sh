#!/usr/bin/env bash
# Configura background workers para specs de infra em agldv03
# Uso: ./scripts/ruflo/setup-background-workers.sh [host]

set -e
HOST="${1:-}"
HOME="${HOME:-/root}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/ruflo"
WORKERS_JSON="$CONFIG_DIR/background-workers.json"
RUFLO_DIR="$HOME/.ruflo"

run_cmd() {
  if [[ -n "$HOST" ]]; then
    ssh "$HOST" "$@"
  else
    "$@"
  fi
}

echo "=== Background Workers Setup ==="
echo "Host: ${HOST:-local}"
echo ""

# 1. Copiar config
echo "1. Configuração de workers..."
if [[ -f "$WORKERS_JSON" ]]; then
  run_cmd mkdir -p "$RUFLO_DIR"
  if [[ -n "$HOST" ]]; then
    scp "$WORKERS_JSON" "$HOST:$RUFLO_DIR/background-workers.json" 2>/dev/null || true
  else
    cp "$WORKERS_JSON" "$RUFLO_DIR/background-workers.json" 2>/dev/null || true
  fi
  echo "  OK: background-workers.json"
else
  echo "  WARN: $WORKERS_JSON não encontrado"
fi
echo ""

# 2. Daemon init (se disponível)
echo "2. Daemon/workers..."
if run_cmd npx claude-flow@alpha daemon --help 2>/dev/null; then
  run_cmd npx claude-flow@alpha daemon init 2>/dev/null || true
  echo "  OK: daemon configurado"
elif run_cmd npx ruflo@latest daemon --help 2>/dev/null; then
  run_cmd npx ruflo@latest daemon init 2>/dev/null || true
  echo "  OK: daemon configurado"
else
  echo "  SKIP: daemon CLI não disponível"
  echo "  Workers: ultralearn, consolidate, deepdive, testgaps, refactor, benchmark"
  echo "  Config em ~/.ruflo/background-workers.json"
fi
echo ""

# 3. Tool groups
echo "3. Tool groups (ENV)..."
TOOL_GROUPS="implement,test,fix,memory"
ZSHRC_MARKER="# --- Ruflo tool groups (agl-hostman) ---"
ZSHRC="${HOME}/.zshrc"
if [[ -n "$HOST" ]]; then
  run_cmd sh -c "grep -q CLAUDE_FLOW_TOOL_GROUPS $ZSHRC 2>/dev/null || (echo '' >> $ZSHRC && echo '$ZSHRC_MARKER' >> $ZSHRC && echo 'export CLAUDE_FLOW_TOOL_GROUPS=$TOOL_GROUPS' >> $ZSHRC)"
else
  grep -q CLAUDE_FLOW_TOOL_GROUPS "$ZSHRC" 2>/dev/null || (echo "" >> "$ZSHRC" && echo "$ZSHRC_MARKER" >> "$ZSHRC" && echo "export CLAUDE_FLOW_TOOL_GROUPS=$TOOL_GROUPS" >> "$ZSHRC")
fi
echo "  OK: CLAUDE_FLOW_TOOL_GROUPS=$TOOL_GROUPS"
echo ""

echo "=== Background workers setup concluído ==="
echo "Próximo: ./scripts/ruflo/setup-hive-mind.sh"
