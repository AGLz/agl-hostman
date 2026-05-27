#!/usr/bin/env bash
# git pull (NFS Linux) + mirror Z:\ → C:\ na aglwk45 (VM104) via AGLSRV1 guest agent.
#
# Fluxo recomendado:
#   git -C /mnt/overpower/apps/dev/agl/agl-hostman pull --ff-only   # no host com NFS
#   bash scripts/skills/propagate-sync-agl-hostman-wk45-qemu.sh
#
# Uso:
#   bash scripts/skills/propagate-sync-agl-hostman-wk45-qemu.sh
#   USE_GIT_PULL=1 bash ...   # tenta git pull no Windows (lento; pode timeout)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
PS1_GUEST="${1:-$REPO_ROOT/scripts/skills/wk45-mirror-agl-hostman-repo.ps1}"
if [[ "${USE_GIT_PULL:-0}" == "1" ]]; then
  PS1_GUEST="$REPO_ROOT/scripts/skills/wk45-sync-agl-hostman-repo.ps1"
fi
HELPER="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"

[[ -f "$PS1_GUEST" && -f "$HELPER" ]] || { echo "Erro: script em falta ($PS1_GUEST)" >&2; exit 1; }

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "=== DRY_RUN propagate-sync-agl-hostman-wk45-qemu ==="
  echo "AGLSRV=$AGLSRV VMID=$VMID"
  echo "Executa wk45-sync-agl-hostman-repo.ps1 no guest"
  exit 0
fi

echo "=== AGLSRV1 $AGLSRV — sync repo agl-hostman VM $VMID ==="
ssh -o BatchMode=yes -o ConnectTimeout=25 "$AGLSRV" "qm agent ${VMID} ping" >/dev/null

scp -q "$PS1_GUEST" "$HELPER" "${AGLSRV}:/tmp/"

ssh -o BatchMode=yes "$AGLSRV" \
  "python3 /tmp/vm104_guest_exec_ps1.py ${VMID} /tmp/$(basename "$PS1_GUEST")"

echo ""
echo "=== A aguardar mirror (poll até 30 min) ==="
deadline=$((SECONDS + 1800))
while (( SECONDS < deadline )); do
  out=$(ssh -o BatchMode=yes "$AGLSRV" \
    "qm guest exec ${VMID} -- powershell -NoProfile -Command \"Get-Content C:/Users/Administrator/wk45-repo-sync-result.txt -Tail 4 -ErrorAction SilentlyContinue\"" \
    2>&1) || true
  if echo "$out" | grep -q "concluído\|concluido\|FAIL robocopy"; then
    break
  fi
  sleep 45
done

echo ""
echo "=== Resultado (tail) ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"Get-Content C:/Users/Administrator/wk45-repo-sync-result.txt -Tail 25\"" \
  2>&1 | tail -35

echo ""
echo "=== Verificação karpathy + sync script ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- cmd /c \"if exist C:\\Users\\Administrator\\apps\\dev\\agl\\agl-hostman\\.cursor\\rules\\karpathy-skills.mdc (echo KARPATHY_OK) else (echo KARPATHY_MISSING) & if exist C:\\Users\\Administrator\\apps\\dev\\agl\\agl-hostman\\scripts\\skills\\sync-six-repos.sh (echo SYNC_OK) else (echo SYNC_MISSING)\""
