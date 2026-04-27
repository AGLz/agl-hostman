#!/usr/bin/env bash
# Verifica via qm guest exec (AGLSRV1) se existe o clone agl-hostman no caminho Windows.
#
# Por defeito assume U:\ espelhando /mnt/overpower/... no Linux:
#   U:\apps\dev\agl\agl-hostman  <->  /mnt/overpower/apps/dev/agl/agl-hostman
#
# Limitação: guest exec corre sem sessão interativa — drives mapeados só no login
# (ex.: net use U:) podem NÃO existir aqui; nesse caso o script falha mesmo com U: OK no RDP.
# Opções: mapear U: para "todos os utilizadores" / persistente ao arranque, ou definir
# WK45_REPO_WIN com caminho local (ex. C:\work\agl-hostman) ou UNC.
#
# Uso:
#   bash scripts/openclaw/vm104-verify-overpower-repo.sh
#   WK45_REPO_WIN='C:\\Users\\Administrator\\source\\agl-hostman' VMID=104 bash ...

set -euo pipefail

AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${VMID:-104}"
# Caminho no guest (cmd): barras invertidas; por defeito espelho overpower → U:
WK45_REPO_WIN="${WK45_REPO_WIN:-U:\\apps\\dev\\agl\\agl-hostman}"
PS1_REL="scripts\\openclaw\\wk45-patch-gateway-nodeopts.ps1"
TARGET="${WK45_REPO_WIN}\\${PS1_REL}"

echo "=== vm104-verify-overpower-repo (VMID=$VMID) ==="
echo "AGLSRV=$AGLSRV"
echo "TARGET=$TARGET"
echo ""

# cmd /c: if exist precisa de caminho com \ — escapar para ssh remoto
OUT=$(ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV" \
  "qm guest exec $VMID -- cmd /c \"if exist \\\"$TARGET\\\" (echo REPO_PS1_OK) else (echo REPO_PS1_MISSING)\"" 2>&1) || true

echo "$OUT"
if echo "$OUT" | grep -q REPO_PS1_OK; then
  echo ""
  echo "[OK] Ficheiro patch encontrado no guest."
  exit 0
fi

echo ""
echo "[WARN ou FAIL] Ficheiro não encontrado ou guest indisponível."
echo "  - Confirma o caminho real na VM (Explorador / onde fizeste git clone)."
echo "  - Se só existe U: após login, corre o patch na consola interativa ou define WK45_REPO_WIN."
exit 1
