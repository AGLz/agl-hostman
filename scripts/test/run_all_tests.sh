#!/usr/bin/env bash
# Suite agregada de testes agl-hostman (API Node + Laravel).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0

run() {
  echo "==> $*"
  if "$@"; then
    echo "[OK] $*"
  else
    echo "[FAIL] $*" >&2
    FAIL=1
  fi
}

if [[ -f package.json ]] && grep -q '"test"' package.json 2>/dev/null; then
  run npm test
else
  echo "[SKIP] npm test (sem script)"
fi

if [[ -f src/artisan ]]; then
  run bash -c 'cd src && php artisan test --parallel'
else
  echo "[SKIP] php artisan test (src/artisan em falta)"
fi

exit "$FAIL"
