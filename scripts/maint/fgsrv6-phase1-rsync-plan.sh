#!/usr/bin/env bash
# Fase 1 — plano de cópia (não executa por defeito). Rever DEST antes de correr.
# Uso: DEST=root@FGSRV7:/srv/migrate/fgsrv6 ./scripts/maint/fgsrv6-phase1-rsync-plan.sh
set -euo pipefail

FGSRV6="${FGSRV6:-root@100.83.51.9}"
DEST="${DEST:?Definir DEST=utilizador@host:/caminho}"

RSYNC=(rsync -aHAX --info=progress2 -e "ssh -o BatchMode=yes")

echo "Destino: $DEST"
echo "Origem:  $FGSRV6"
echo ""
echo "1) NFS export (~7 GB no host FGSRV6):"
echo "   ${RSYNC[*]} $FGSRV6:/storage/nfs-export/ $DEST/nfs-export/"
echo ""
echo "2) APIs /var/www (~8+ GB):"
echo "   ${RSYNC[*]} $FGSRV6:/var/www/ $DEST/var-www/"
echo ""
echo "3) Nginx + SSL:"
echo "   ${RSYNC[*]} $FGSRV6:/etc/nginx/ $DEST/nginx/"
echo ""
echo "4) AGLSRV1 — disco Proxmox em fgsrv6-wg (CT241 agldv07, stopped no FGSRV7):"
echo "   Copiar a partir do mount AGLSRV1 ou parar CT e migrar storage:"
echo "   rsync -aH /mnt/pve/fgsrv6-wg/images/241/ \$DEST/agldv07-disk/"
echo "   (executar no AGLSRV1: ssh root@100.107.113.33)"
echo ""
echo "5) Após migração validada — AGLSRV1:"
echo "   umount /mnt/pve/fgsrv6-wg  # só quando CT241/storage movidos"
echo "   pvesm remove fgsrv6-wg      # com cuidado"
