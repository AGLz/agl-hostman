#!/usr/bin/env bash
# Adiciona bind-mount do pool host overpower aos CTs de download (AGLSRV1).
# Alinha CT121/157/141 com CT123 (Radarr): /overpower/base → /mnt/overpower
#
# NOTA: Não altera quota/espaço no pool — reorganização aguarda AGLSRV3.
#
# Uso:
#   bash scripts/media/ct-download-mounts-apply.sh           # dry-run
#   bash scripts/media/ct-download-mounts-apply.sh --apply

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
for a in "$@"; do [[ "$a" == --apply ]] && APPLY=true; done

MP_LINE='mp0: /overpower/base,mp=/mnt/overpower'
VMIDS=(121 157 141)

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

echo "Mounts planeados (igual Radarr CT123 mp1):"
for v in "${VMIDS[@]}"; do
  echo "  CT${v}: ${MP_LINE}"
done

if [[ "$APPLY" != true ]]; then
  echo ""
  echo "Dry-run. Aplicar: bash scripts/media/ct-download-mounts-apply.sh --apply"
  exit 0
fi

run "bash -s" <<REMOTE
set -euo pipefail
MP_LINE='$MP_LINE'
for VMID in ${VMIDS[*]}; do
  if pct config "\$VMID" | grep -q '^mp0:.*overpower'; then
    echo "CT\${VMID}: mp0 overpower já configurado"
    continue
  fi
  echo "CT\${VMID}: stop + mp0 + start"
  pct stop "\$VMID"
  pct set "\$VMID" -mp0 /overpower/base,mp=/mnt/overpower
  pct start "\$VMID"
  sleep 3
  pct exec "\$VMID" -- df -h /mnt/overpower | tail -1
done
REMOTE

echo "Concluído."
