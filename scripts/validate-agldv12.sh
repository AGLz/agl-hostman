#!/usr/bin/env bash
# =============================================================================
# Validação completa agl-hostman — agldv12 (CT185)
# Executa: Turbo Flow, inits, segurança, testes, code quality
# Uso: ./scripts/validate-agldv12.sh [--skip-docker]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_DOCKER=false
REPORT="${PROJECT_ROOT}/.validation-report-$(date +%Y%m%d-%H%M%S).txt"

for arg in "$@"; do
  [[ "$arg" == "--skip-docker" ]] && SKIP_DOCKER=true
done

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }
ok() { log "✅ $*"; }
warn() { log "⚠️  $*"; }
fail() { log "❌ $*"; }

cd "$PROJECT_ROOT"
: > "$REPORT"
log "=== Validação agl-hostman — agldv12 (CT185) ==="
log "Host: $(hostname)"
log ""

# 1. Turbo Flow
log "--- 1. Turbo Flow ---"
if command -v turbo-status &>/dev/null; then
  turbo-status 2>&1 | tee -a "$REPORT" || true
  ok "Turbo Flow disponível"
else
  warn "turbo-status não encontrado (Turbo Flow opcional)"
fi
log ""

# 2. Inits
log "--- 2. Inits ---"
if command -v bd &>/dev/null; then
  (cd "$PROJECT_ROOT" && bd init 2>&1) | tee -a "$REPORT" && ok "Beads init" || warn "Beads init falhou"
else
  warn "Beads não instalado (npm i -g beads-cli)"
fi
log ""

# 3. Segurança
log "--- 3. Segurança ---"
if npm audit 2>&1 | tee -a "$REPORT"; then
  ok "npm audit: sem vulnerabilidades críticas"
else
  warn "npm audit: verificar vulnerabilidades"
fi

if [[ "$SKIP_DOCKER" != true ]] && command -v docker &>/dev/null; then
  log "Executando security-check (Trivy)..."
  ./scripts/security-check.sh 2>&1 | tee -a "$REPORT" || warn "security-check falhou (DNS/rede?)"
else
  warn "Pulando Trivy (--skip-docker ou Docker indisponível)"
fi
log ""

# 4. Testes
log "--- 4. Testes ---"
if npm test 2>&1 | tee -a "$REPORT"; then
  ok "Testes unitários: passaram"
else
  fail "Testes unitários: falharam"
  exit 1
fi
log ""

# 5. Build e Lint
log "--- 5. Code Quality ---"
npm run build 2>&1 | tee -a "$REPORT" && ok "Build OK"
npm run lint 2>&1 | tee -a "$REPORT" || warn "Lint não configurado"
log ""

log "=== Relatório salvo em: $REPORT ==="
