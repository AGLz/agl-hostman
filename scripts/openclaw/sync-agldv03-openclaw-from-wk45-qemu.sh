#!/usr/bin/env bash
# Empacota ~/.openclaw na aglwk45 via AGLSRV1 (qm guest exec VM104) e aplica no agldv03
# (merge: so Telegram + gateway PVE; resto wk45 — ver apply-wk45-bundle-on-agldv03.sh).
#
# Requer (maquina onde corre): ssh ao Proxmox, ssh ao agldv03; no PVE: python3, qm.
# Requer na VM104: QEMU guest agent, tar.exe, pasta C:\Users\Administrator\.openclaw
#
# No agldv03 o repo costuma estar em: /mnt/overpower/apps/dev/agl/agl-hostman
#
# Uso (raiz do repo):
#   bash scripts/openclaw/sync-agldv03-openclaw-from-wk45-qemu.sh
#   AGLSRV1_HOST=root@192.168.0.245 AGLDV03=root@100.94.221.87 AGLWK45_VMID=104 bash ...
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACK="$REPO_ROOT/scripts/openclaw/vm104_guest_pack_openclaw.py"
APPLY="$REPO_ROOT/scripts/openclaw/apply-wk45-bundle-on-agldv03.sh"

AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
DEST="${AGLDV03:-root@100.94.221.87}"

REMOTE_TGZ="/tmp/openclaw-wk45-for-agldv03-$$.tgz"

[[ -f "$PACK" ]] || { echo "Erro: $PACK"; exit 1; }
[[ -f "$APPLY" ]] || { echo "Erro: $APPLY"; exit 1; }

echo "=== 1) Copiar vm104_guest_pack_openclaw.py -> $AGLSRV ==="
scp -q "$PACK" "$AGLSRV:/tmp/vm104_guest_pack_openclaw.py"

echo "=== 2) Empacotar no guest (VMID=$VMID) e gravar $REMOTE_TGZ no PVE ==="
TGZ_ON_PVE=$(ssh -o BatchMode=yes -o ConnectTimeout=30 "$AGLSRV" \
  "chmod +x /tmp/vm104_guest_pack_openclaw.py 2>/dev/null; python3 /tmp/vm104_guest_pack_openclaw.py $VMID $REMOTE_TGZ" | tail -n 1)

[[ -n "$TGZ_ON_PVE" ]] || { echo "Erro: caminho .tgz vazio"; exit 1; }
echo "  Bundle PVE: $TGZ_ON_PVE"

echo "=== 3) Enviar bundle + apply -> $DEST ==="
REMOTE_BUNDLE="/tmp/openclaw-wk45-bundle-$$.tgz"
scp -q "$AGLSRV:$TGZ_ON_PVE" "$DEST:$REMOTE_BUNDLE"
scp -q "$APPLY" "$DEST:/tmp/apply-wk45-bundle-on-agldv03.sh"

echo "=== 4) Aplicar no agldv03 e reiniciar gateway ==="
ssh -o BatchMode=yes -o ConnectTimeout=30 "$DEST" \
  "bash /tmp/apply-wk45-bundle-on-agldv03.sh $REMOTE_BUNDLE && systemctl --user restart openclaw-gateway 2>/dev/null; systemctl --user is-active openclaw-gateway || true"

echo "=== 5) Limpar .tgz no PVE (opcional) ==="
ssh -o BatchMode=yes -o ConnectTimeout=15 "$AGLSRV" "rm -f $REMOTE_TGZ" || true

echo ""
echo "=== Concluido ==="
echo "  Destino OpenClaw: $DEST"
echo "  Repo agldv03: /mnt/overpower/apps/dev/agl/agl-hostman"
echo "  Logs: ssh $DEST 'journalctl --user -u openclaw-gateway -n 40 --no-pager'"
