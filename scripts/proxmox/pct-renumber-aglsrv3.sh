#!/usr/bin/env bash
# Wrapper legado → pct-renumber.sh --host aglsrv3
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/pct-renumber.sh" --host aglsrv3 "$@"
