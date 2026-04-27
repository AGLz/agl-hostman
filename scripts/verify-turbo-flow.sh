#!/usr/bin/env bash
# =============================================================================
# Verifica funções do Turbo Flow v4.0
# Executar dentro do DevPod ou CT com Turbo Flow instalado
# Uso: ./scripts/verify-turbo-flow.sh
# =============================================================================
set -euo pipefail

# Carregar aliases Turbo Flow (funções turbo-status, rf-doctor, etc.)
# Nota: não source .bashrc aqui — pode falhar em zsh; aliases são suficientes
[[ -f ~/.turboflow_aliases ]] && . ~/.turboflow_aliases 2>/dev/null || true

PASS=0
FAIL=0

check() {
  if eval "$1" &>/dev/null; then
    echo "✅ $2"
    ((PASS++)) || true
    return 0
  else
    echo "❌ $2"
    ((FAIL++)) || true
    return 1
  fi
}

echo "=== Verificação Turbo Flow v4.0 ==="
echo ""

echo "--- Core ---"
check "command -v turbo-status" "turbo-status"
check "command -v turbo-help" "turbo-help"
turbo-status 2>/dev/null | head -25 || true
echo ""

echo "--- Ruflo ---"
check "command -v rf-doctor || command -v npx" "rf-doctor/npx"
(rf-doctor 2>/dev/null || npx ruflo@latest doctor 2>/dev/null) | tail -5 || echo "  (rf-doctor pode falhar com Invalid Version)"
echo ""

echo "--- Beads ---"
check "command -v bd" "bd (beads)"
(bd ready 2>/dev/null || bd init 2>/dev/null) || true
echo ""

echo "--- GitNexus ---"
check "command -v gnx-analyze || command -v gitnexus" "gnx-analyze/gitnexus"
echo ""

echo "--- Worktrees ---"
check "command -v wt-list || command -v wt-add" "wt-* (worktrees)"
echo ""

echo "--- Plugins ---"
(rf-plugins 2>/dev/null | head -15) || echo "  rf-plugins não disponível"
echo ""

echo "=== Resumo: $PASS passaram, $FAIL falharam ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
