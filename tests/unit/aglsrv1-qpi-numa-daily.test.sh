#!/usr/bin/env bash
# Teste mínimo: dry-run do relatório AGLSRV1 (sem SSH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/monitoring/aglsrv1-qpi-numa-daily.sh"

test -x "${SCRIPT}" || chmod +x "${SCRIPT}"
out="$("${SCRIPT}" --dry-run)"
echo "${out}" | grep -q 'AGLSRV1'
echo "${out}" | grep -q 'VM104'
echo "OK aglsrv1-qpi-numa-daily dry-run"
