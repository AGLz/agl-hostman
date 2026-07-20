#!/usr/bin/env bash
# Verify pack AGL — projeto niche CRM/ERP makemoney01.
# Uso: verify-makemoney-niche-pack.sh [ROOT] [SLUG]
set -euo pipefail

ROOT="${1:-$(pwd)}"
SLUG="${2:-$(basename "$ROOT")}"
fail=0

check() {
  if [[ -e "$1" ]]; then
    echo "  OK $1"
  else
    echo "  FAIL $1" >&2
    fail=1
  fi
}

echo "=== verify ${SLUG} @ ${ROOT} ==="
check "$ROOT/README.md"
check "$ROOT/AGENTS.md"
check "$ROOT/CLAUDE.md"
check "$ROOT/.cursor/mcp.json"
check "$ROOT/.cursor/rules/ponytail.mdc"
check "$ROOT/.cursor/rules/mandatory-delivery-pipeline.mdc"
check "$ROOT/.cursor/rules/${SLUG}-project.mdc"
check "$ROOT/src/public/index.php"
check "$ROOT/config/niche.json"
check "$ROOT/.github/workflows/ci.yml"

if [[ "$fail" -ne 0 ]]; then
  echo "ERRO: verify ${SLUG} falhou" >&2
  exit 1
fi
echo "OK verify ${SLUG}"
