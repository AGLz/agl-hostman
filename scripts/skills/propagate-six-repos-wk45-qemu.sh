#!/usr/bin/env bash
# Propaga Six Repos para aglwk45 (VM104) via SSH AGLSRV1 + qm guest exec / virtio guest agent.
#
# Uso (a partir da raiz agl-hostman):
#   bash scripts/skills/propagate-six-repos-wk45-qemu.sh
#   DRY_RUN=1 bash scripts/skills/propagate-six-repos-wk45-qemu.sh
#
# Variáveis:
#   AGLSRV1_HOST      default root@100.107.113.33
#   AGLWK45_VMID      default 104
#   WK45_REPO_WIN     default C:\Users\Administrator\apps\dev\agl\agl-hostman

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
WK45_REPO="${WK45_REPO_WIN:-C:/Users/Administrator/apps/dev/agl/agl-hostman}"
GUEST_TEMP="C:/Windows/Temp/agl-six-repos"

PS1_GUEST="$REPO_ROOT/scripts/skills/wk45-propagate-six-repos-guest.ps1"
SYNC_SH="$REPO_ROOT/scripts/skills/sync-six-repos.sh"
VERIFY_SH="$REPO_ROOT/scripts/skills/verify-six-repos.sh"
HELPER="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"

for f in "$PS1_GUEST" "$SYNC_SH" "$VERIFY_SH" "$HELPER"; do
  [[ -f "$f" ]] || { echo "Erro: em falta $f" >&2; exit 1; }
done

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "=== DRY_RUN propagate-six-repos-wk45-qemu ==="
  echo "AGLSRV=$AGLSRV VMID=$VMID"
  echo "Upload: sync-six-repos.sh, verify-six-repos.sh → guest $GUEST_TEMP"
  echo "Execute: wk45-propagate-six-repos-guest.ps1 (RepoRoot=$WK45_REPO)"
  exit 0
fi

echo "=== AGLSRV1 $AGLSRV — guest agent VM $VMID ==="
ssh -o BatchMode=yes -o ConnectTimeout=25 "$AGLSRV" "qm agent ${VMID} ping" >/dev/null

scp -q "$PS1_GUEST" "$SYNC_SH" "$VERIFY_SH" "$HELPER" "${AGLSRV}:/tmp/"

ssh -o BatchMode=yes "$AGLSRV" bash -s "$VMID" "$GUEST_TEMP" "$WK45_REPO" <<'REMOTE'
set -euo pipefail
VMID="$1"
GUEST_TEMP="$2"
WK45_REPO="$3"

python3 - "$VMID" "$GUEST_TEMP" <<'PY'
import pathlib
import sys

sys.path.insert(0, "/tmp")
from vm104_guest_exec_ps1 import qm_powershell, upload_b64_file

vmid, guest_temp = sys.argv[1], sys.argv[2]
guest_temp = guest_temp.replace("\\", "/")

qm_powershell(vmid, f"New-Item -ItemType Directory -Force -Path '{guest_temp}' | Out-Null")

for name in ("sync-six-repos.sh", "verify-six-repos.sh"):
    local = pathlib.Path("/tmp") / name
    out = f"{guest_temp}/{name}"
    b64 = f"{out}.b64"
    upload_b64_file(vmid, local.read_bytes(), b64, out)
    print(f"OK uploaded {name} -> {out}")
PY

python3 /tmp/vm104_guest_exec_ps1.py "$VMID" /tmp/wk45-propagate-six-repos-guest.ps1 \
  -RepoRoot "$WK45_REPO" -ScriptsDir "C:/Windows/Temp/agl-six-repos"
REMOTE

echo ""
echo "=== A aguardar sync no guest (poll até 45 min) ==="
deadline=$((SECONDS + 2700))
while (( SECONDS < deadline )); do
  out=$(ssh -o BatchMode=yes "$AGLSRV" \
    "qm guest exec ${VMID} -- powershell -NoProfile -Command \"if (Test-Path C:/Users/Administrator/wk45-six-repos-result.txt) { Get-Content C:/Users/Administrator/wk45-six-repos-result.txt -Tail 5 } else { Write-Output WAITING }\"" \
    2>&1) || true
  if echo "$out" | grep -q "concluído"; then
    echo "Guest reportou conclusão."
    break
  fi
  if echo "$out" | grep -q "FAIL sync exit="; then
    echo "Guest sync falhou."
    break
  fi
  if echo "$out" | grep -q "FAIL verify exit="; then
    echo "Guest verify falhou."
    break
  fi
  sleep 30
done

echo ""
echo "=== Resultado guest (tail) ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"Get-Content C:/Users/Administrator/wk45-six-repos-result.txt -Tail 25\"" \
  2>&1 | tail -35

echo ""
echo "=== Concluído: Six Repos propagado para aglwk45 (VM${VMID}) ==="
