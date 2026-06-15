#!/usr/bin/env bash
# Propaga dotfiles + live sync para aglwk45 (VM104) via AGLSRV1 + qm guest exec.
#
# Pré-requisito: git pull no NFS overpower (todos os hosts vêem o mesmo repo).
#
# Uso:
#   bash scripts/dotfiles/propagate-dotfiles-wk45-qemu.sh
#   DRY_RUN=1 bash scripts/dotfiles/propagate-dotfiles-wk45-qemu.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
WK45_REPO="${WK45_REPO_WIN:-C:/Users/Administrator/apps/dev/agl/agl-hostman}"
HOME_SYNC="${WK45_HOME_SYNC:-Z:/apps/dev/agl/agl-home-sync}"
HOME_USER="${AGL_HOME_USER:-linux-root}"

PS1_GUEST="$REPO_ROOT/scripts/dotfiles/wk45-propagate-dotfiles-guest.ps1"
INSTALL_PS1="$REPO_ROOT/scripts/dotfiles/install-agl-home-sync.ps1"
HELPER="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"

for f in "$PS1_GUEST" "$INSTALL_PS1" "$HELPER"; do
  [[ -f "$f" ]] || { echo "Erro: em falta $f" >&2; exit 1; }
done

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "=== DRY_RUN propagate-dotfiles-wk45-qemu ==="
  echo "AGLSRV=$AGLSRV VMID=$VMID"
  echo "Guest: wk45-propagate-dotfiles-guest.ps1"
  echo "RepoRoot=$WK45_REPO HomeSync=$HOME_SYNC HomeUser=$HOME_USER"
  exit 0
fi

echo "=== AGLSRV1 $AGLSRV — dotfiles VM $VMID (guest agent) ==="
ssh -o BatchMode=yes -o ConnectTimeout=25 "$AGLSRV" "qm agent ${VMID} ping" >/dev/null

scp -q "$PS1_GUEST" "$INSTALL_PS1" "$HELPER" "${AGLSRV}:/tmp/"

ssh -o BatchMode=yes "$AGLSRV" bash -s "$VMID" "$WK45_REPO" "$HOME_SYNC" "$HOME_USER" <<'REMOTE'
set -euo pipefail
VMID="$1"
WK45_REPO="$2"
HOME_SYNC="$3"
HOME_USER="$4"

python3 /tmp/vm104_guest_exec_ps1.py "$VMID" /tmp/wk45-propagate-dotfiles-guest.ps1 \
  -RepoRoot "$WK45_REPO" -HomeSyncRoot "$HOME_SYNC" -HomeUser "$HOME_USER"
REMOTE

echo ""
echo "=== A aguardar dotfiles no guest (poll até 20 min) ==="
deadline=$((SECONDS + 1200))
while (( SECONDS < deadline )); do
  out=$(ssh -o BatchMode=yes "$AGLSRV" \
    "qm guest exec ${VMID} -- powershell -NoProfile -Command \"if (Test-Path C:/Users/Administrator/wk45-dotfiles-result.txt) { Get-Content C:/Users/Administrator/wk45-dotfiles-result.txt -Tail 6 } else { Write-Output WAITING }\"" \
    2>&1) || true
  if echo "$out" | grep -q "concluído\|concluido"; then
    echo "Guest reportou conclusão."
    break
  fi
  if echo "$out" | grep -q "FAIL install exit=\|FAIL verify exit="; then
    echo "Guest dotfiles falhou."
    break
  fi
  sleep 20
done

echo ""
echo "=== Resultado guest (tail) ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"Get-Content C:/Users/Administrator/wk45-dotfiles-result.txt -Tail 30\"" \
  2>&1 | tail -40

echo ""
echo "=== Verificação rápida symlinks ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"\$c=Get-Item C:\\Users\\Administrator\\.cursor\\chats -ErrorAction SilentlyContinue; if (\$c.LinkType) { Write-Output ('CHATS_SYMLINK ' + \$c.Target) } else { Write-Output CHATS_MISSING }\"" \
  2>&1 | tail -5

echo ""
echo "=== Concluído: dotfiles propagado para aglwk45 (VM${VMID}) ==="
