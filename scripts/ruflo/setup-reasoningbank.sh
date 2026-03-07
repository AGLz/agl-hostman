#!/usr/bin/env bash
# Configura ReasoningBank + AgentDB em agldv03
# Uso: ./scripts/ruflo/setup-reasoningbank.sh [host]

set -e
HOST="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

run_cmd() {
  if [[ -n "$HOST" ]]; then
    ssh "$HOST" "$@"
  else
    "$@"
  fi
}

echo "=== ReasoningBank + AgentDB Setup ==="
echo "Host: ${HOST:-local}"
echo ""

# 1. Memory init
echo "1. Memory/ReasoningBank init..."
if run_cmd "npx claude-flow@alpha memory init" 2>/dev/null; then
  echo "  OK: memory init"
elif run_cmd "npx ruflo@latest memory init" 2>/dev/null; then
  echo "  OK: memory init"
else
  echo "  SKIP: memory init não encontrado"
fi
echo ""

# 2. ReasoningBank status
echo "2. ReasoningBank status..."
if run_cmd "npx claude-flow@alpha memory status --reasoningbank" 2>/dev/null; then
  echo "  OK: ReasoningBank operacional"
else
  echo "  WARN: ReasoningBank pode precisar de init"
  echo "  Database: .swarm/memory.db (SQLite)"
fi
echo ""

# 3. Teste store/query
echo "3. Teste store/query..."
run_cmd "npx claude-flow@alpha memory store agl_test 'AGL infrastructure config' --namespace infra --reasoningbank" 2>/dev/null || true
run_cmd "npx claude-flow@alpha memory query 'infra config' --namespace infra --reasoningbank" 2>/dev/null || true
echo "  OK: teste executado"
echo ""

# 4. AgentDB (se disponível)
echo "4. AgentDB..."
if run_cmd sh -c "npm list agentdb 2>/dev/null" || run_cmd sh -c "npm list @agentdb/core 2>/dev/null"; then
  echo "  OK: AgentDB instalado"
else
  echo "  SKIP: AgentDB opcional (skills reasoningbank-agentdb)"
fi
echo ""

echo "=== ReasoningBank setup concluído ==="
echo "Uso:"
echo "  npx claude-flow@alpha memory store <key> <value> --namespace <ns> --reasoningbank"
echo "  npx claude-flow@alpha memory query <query> --namespace <ns> --reasoningbank"
echo "  npx claude-flow@alpha memory status --reasoningbank"
