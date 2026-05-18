#!/usr/bin/env bash
# Valida Ruflo/Claude-Flow + 3-tier router em agldv03
# Uso: ./scripts/ruflo/validate-ruflo.sh [host]
# Host default: local (ou root@100.94.221.87 para remoto)

set -e
HOST="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/ruflo"

run_cmd() {
  if [[ -n "$HOST" ]]; then
    ssh "$HOST" "$@"
  else
    "$@"
  fi
}

echo "=== Ruflo/Claude-Flow Validation ==="
echo "Host: ${HOST:-local}"
echo ""

# 1. Node/npm
echo "1. Node.js/npm..."
run_cmd node --version 2>/dev/null || { echo "  FAIL: Node.js não encontrado"; exit 1; }
run_cmd npm --version 2>/dev/null || { echo "  FAIL: npm não encontrado"; exit 1; }
echo "  OK"
echo ""

# 2. Ruflo ou claude-flow
echo "2. Ruflo/Claude-Flow..."
if run_cmd npx ruflo@latest --help 2>/dev/null; then
  echo "  OK: ruflo@latest disponível"
  RUFLO_CMD="npx ruflo@latest"
elif run_cmd npx claude-flow@alpha --help 2>/dev/null; then
  echo "  OK: claude-flow@alpha disponível"
  RUFLO_CMD="npx claude-flow@alpha"
elif run_cmd npx agentic-flow@alpha --help 2>/dev/null; then
  echo "  OK: agentic-flow@alpha disponível"
  RUFLO_CMD="npx agentic-flow@alpha"
else
  echo "  WARN: ruflo/claude-flow não encontrado. Instale: npm install -g ruflo@latest"
  RUFLO_CMD="npx ruflo@latest"
fi
echo ""

# 3. LiteLLM gateway (agldv03)
echo "3. LiteLLM gateway..."
if [[ -z "$HOST" ]] || [[ "$HOST" == *"100.94.221.87"* ]]; then
  GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://localhost:4000}"
  # /health/readiness não exige auth (endpoint público)
  if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health/readiness" 2>/dev/null | grep -q 200; then
    echo "  OK: LiteLLM em $GATEWAY_URL"
  else
    echo "  WARN: LiteLLM não responde em $GATEWAY_URL (iniciar com ./scripts/litellm/start.sh)"
  fi
else
  echo "  SKIP: verificar LiteLLM manualmente no host"
fi
echo ""

# 4. 3-tier router (hooks intel route)
echo "4. 3-tier router (intel route)..."
if run_cmd "$RUFLO_CMD hooks intel route 'test task' --top-k 1" 2>/dev/null; then
  echo "  OK: 3-tier router funcional"
else
  echo "  WARN: hooks intel route não disponível (versão pode não suportar)"
  echo "  Alternativa: npx agentic-flow@alpha hooks intel route 'task' --top-k 3"
fi
echo ""

# 5. MCP (opcional)
echo "5. MCP server..."
if run_cmd "$RUFLO_CMD mcp --help" 2>/dev/null || run_cmd "$RUFLO_CMD mcp start --help" 2>/dev/null; then
  echo "  OK: MCP disponível"
  echo "  Adicionar: claude mcp add ruflo -- npx -y ruflo@latest mcp start"
else
  echo "  SKIP: MCP não verificado"
fi
echo ""

echo "=== Validação concluída ==="
echo "Próximo: ./scripts/ruflo/setup-ruvector.sh"
