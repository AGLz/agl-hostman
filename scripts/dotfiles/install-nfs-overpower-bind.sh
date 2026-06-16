#!/usr/bin/env bash
# Monta overpower (aglfs1) no host Proxmox e faz bind-mount no CT agldv* satélite.
#
# Pré-requisitos: pct no host, CT desbloqueado, espaço em disco no host.
# aglfs1 exporta 100.69.187.105:/mnt/overpower (NFS v3).
#
# Uso (no host Proxmox):
#   CT_VMID=608 PCT_HOST=root@100.98.108.66 bash scripts/dotfiles/install-nfs-overpower-bind.sh
#   CT_VMID=547 PCT_HOST=root@100.109.181.93 bash scripts/dotfiles/install-nfs-overpower-bind.sh
#
# Depois no CT: AGL_HOME_SYNC_ROOT=/mnt/overpower/apps/dev/agl/agl-home-sync \
#   ./scripts/dotfiles/install-agl-home-sync.sh

set -euo pipefail

AGLFS1_NFS="${AGLFS1_NFS:-100.69.187.105:/mnt/overpower}"
HOST_MOUNT="${HOST_MOUNT:-/var/lib/agl-nfs-overpower}"
CT_VMID="${CT_VMID:?Definir CT_VMID (ex. 608)}"
PCT_HOST="${PCT_HOST:?Definir PCT_HOST (ex. root@100.98.108.66)}"
CT_MP="${CT_MP:-/mnt/overpower}"

FSTAB_LINE="${AGLFS1_NFS%%:*}:/mnt/overpower ${HOST_MOUNT} nfs vers=3,nolock,hard,_netdev 0 0"

log() { echo "[INFO] $*"; }

ssh -o BatchMode=yes "$PCT_HOST" bash -s <<REMOTE
set -euo pipefail
command -v pct >/dev/null || { echo "pct em falta" >&2; exit 1; }
mkdir -p "${HOST_MOUNT}"
grep -qF "${HOST_MOUNT}" /etc/fstab 2>/dev/null || echo "${FSTAB_LINE}" >> /etc/fstab
mountpoint -q "${HOST_MOUNT}" || mount "${HOST_MOUNT}"
stat -c "inode_canonical=%i" "${HOST_MOUNT}/apps/dev/agl/agl-home-sync/linux-root/claude/history.jsonl"
pct set "${CT_VMID}" -mp0 "${HOST_MOUNT},mp=${CT_MP},replicate=0,shared=1"
pct reboot "${CT_VMID}"
sleep 10
pct exec "${CT_VMID}" -- stat -c "inode_ct=%i" "${CT_MP}/apps/dev/agl/agl-home-sync/linux-root/claude/history.jsonl"
REMOTE

log "Bind mount OK — correr install-agl-home-sync no CT${CT_VMID}"
