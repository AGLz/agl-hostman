#!/usr/bin/env bash
# Merge agents.list na VM104 (aglwk45) via Python em AGLSRV1 + qm guest exec.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRAG="$REPO_ROOT/config/openclaw/openclaw-agents-list.fragment.json"
PY="$REPO_ROOT/scripts/openclaw/vm104_guest_merge.py"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"

scp -q "$FRAG" "$PY" "$AGLSRV:/tmp/"
ssh "$AGLSRV" "python3 /tmp/vm104_guest_merge.py $VMID /tmp/openclaw-agents-list.fragment.json"

echo "=== Concluído (aglwk45 VM$VMID) ==="
