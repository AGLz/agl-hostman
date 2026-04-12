#!/usr/bin/env bash
# Corre wk45-diagnostics-gateway.ps1 na VM104 via AGLSRV1 (sem RDP).
# Uso (na raiz do repo): bash scripts/openclaw/run-wk45-gateway-diagnostics.sh [--no-repair]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PS1="$REPO_ROOT/scripts/openclaw/wk45-diagnostics-gateway.ps1"
PY="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
# Menor que o default 25s do .ps1 para o qm guest exec nao expirar no SSH intermedio
CAP_SEC="${WK45_DIAG_CAPTURE_SECONDS:-15}"
EXTRA=( -Repair "-CaptureSeconds" "$CAP_SEC" )
if [[ "${1:-}" == "--no-repair" ]]; then
  EXTRA=( "-CaptureSeconds" "$CAP_SEC" )
  shift || true
fi

OPENCLAW_SSH=(ssh -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)
OPENCLAW_SCP=(scp -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new)

[[ -f "$PS1" ]] && [[ -f "$PY" ]] || { echo "Erro: ficheiros em falta"; exit 1; }

echo "=== SCP → $AGLSRV ==="
"${OPENCLAW_SCP[@]}" -q "$PS1" "$AGLSRV:/tmp/wk45-diagnostics-gateway.ps1"
"${OPENCLAW_SCP[@]}" -q "$PY" "$AGLSRV:/tmp/vm104_guest_exec_ps1.py"

echo "=== vm104_guest_exec_ps1 VMID=$VMID ==="
REMOTE_PY="chmod +x /tmp/vm104_guest_exec_ps1.py && python3 /tmp/vm104_guest_exec_ps1.py $VMID /tmp/wk45-diagnostics-gateway.ps1"
if [[ ${#EXTRA[@]} -gt 0 ]]; then
  REMOTE_PY+=" ${EXTRA[*]}"
fi
"${OPENCLAW_SSH[@]}" "$AGLSRV" "$REMOTE_PY"
