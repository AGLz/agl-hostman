#!/usr/bin/env bash
# Sync BRAD: CT549 /var/www/fg_antigo/BRAD → agl-hostman projects/Implementacao_BRAD
#
# Uso (agldv):
#   bash scripts/proxmox/sync-brad-fg-legacy-ct549.sh
set -euo pipefail

FGSRV7_HOST="${FGSRV7_HOST:-root@100.109.181.93}"
CT_VMID="${CT_VMID:-549}"
REMOTE_BRAD="${REMOTE_BRAD:-/var/www/fg_antigo/BRAD}"
LOCAL_DEST="${LOCAL_DEST:-$(cd "$(dirname "$0")/../.." && pwd)/projects/Implementacao_BRAD}"

log() { printf '[sync-brad] %s\n' "$*"; }

mkdir -p "$LOCAL_DEST"
log "remoto CT${CT_VMID}:${REMOTE_BRAD} → ${LOCAL_DEST}"

ssh -o BatchMode=yes -o ConnectTimeout=120 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'tar --owner=0 --group=0 -C $(dirname "$REMOTE_BRAD") --exclude=$(basename "$REMOTE_BRAD")/.venv -cf - $(basename "$REMOTE_BRAD")'" \
  | tar --no-same-owner --transform="s|^$(basename "$REMOTE_BRAD")/||" -xf - -C "$LOCAL_DEST"

rm -rf "${LOCAL_DEST}/BRAD" 2>/dev/null || true
log "OK $(find "$LOCAL_DEST" -type f ! -path '*/.venv/*' | wc -l) ficheiros — $(du -sh "$LOCAL_DEST" | cut -f1)"
