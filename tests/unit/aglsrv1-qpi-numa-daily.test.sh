#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/monitoring/aglsrv1-qpi-numa-daily.sh"

test -x "${SCRIPT}" || chmod +x "${SCRIPT}"

out="$("${SCRIPT}" --dry-run)"
echo "${out}" | grep -q 'AGLSRV1'
echo "${out}" | grep -q 'meshagent LEAK'

silent="$("${SCRIPT}" --dry-run-ok || true)"
test -z "${silent}"

echo "OK aglsrv1-qpi-numa-daily (alert + silent modes)"
