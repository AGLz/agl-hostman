#!/usr/bin/env bash
# Arranca reparacao + gateway OpenClaw na VM104 (aglwk45) via AGLSRV1 guest agent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGLSRV="${AGLSRV1_HOST:-root@192.168.0.245}"
VMID="${AGLWK45_VMID:-104}"

PS1="$REPO_ROOT/scripts/openclaw/wk45-fix-and-start-gateway.ps1"
CJS="$REPO_ROOT/scripts/openclaw/wk45-prune-invalid-plugin-entries.cjs"
HELPER="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"

for f in "$PS1" "$CJS" "$HELPER"; do
  [[ -f "$f" ]] || { echo "Falta: $f" >&2; exit 1; }
done

scp -q "$PS1" "$CJS" "$HELPER" "${AGLSRV}:/tmp/"

ssh -o BatchMode=yes "$AGLSRV" bash -s "$VMID" <<'REMOTE'
set -euo pipefail
VMID="$1"
python3 - "$VMID" <<'PY'
import pathlib
import sys

sys.path.insert(0, "/tmp")
from vm104_guest_exec_ps1 import upload_b64_file

vmid = sys.argv[1]
cjs = pathlib.Path("/tmp/wk45-prune-invalid-plugin-entries.cjs").read_bytes()
guest = "C:/Users/Administrator/AppData/Local/Temp/wk45-prune-invalid-plugin-entries.cjs"
guest_b64 = guest + ".b64"
upload_b64_file(vmid, cjs, guest_b64, guest)
print("OK uploaded prune cjs")
PY
python3 /tmp/vm104_guest_exec_ps1.py "$VMID" /tmp/wk45-fix-and-start-gateway.ps1
REMOTE

echo "Aguardar build (2-8 min); depois:"
echo "  ssh $AGLSRV \"qm guest exec $VMID -- powershell -NoProfile -Command \\\"Get-Content C:\\\\Users\\\\Administrator\\\\wk45-result.txt -Tail 15\\\"\""
