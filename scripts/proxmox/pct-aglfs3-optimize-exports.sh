#!/usr/bin/env bash
# NFS/Samba exports CT338 aglfs3 — padrão aglfs1 + Tailscale (100.64.0.0/10).
#
# Uso:
#   bash scripts/proxmox/pct-aglfs3-optimize-exports.sh --dry-run
#   bash scripts/proxmox/pct-aglfs3-optimize-exports.sh --apply
#   bash scripts/proxmox/pct-aglfs3-optimize-exports.sh --apply --remote
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

VMID="${AGLSRV3_AGLFS3_VMID:-338}"
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
APPLY=false
REMOTE=false

log() { echo "[$(date +%H:%M:%S)] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --dry-run) APPLY=false; shift ;;
    --remote) REMOTE=true; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

run_ct() {
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "pct exec ${VMID} -- $*"
  else
    pct exec "${VMID}" -- bash -c "$*"
  fi
}

inner_script() {
  cat <<'INNER'
set -euo pipefail
BACKUP="/root/exports.bak.$(date +%Y%m%d%H%M%S)"
cp -a /etc/exports "$BACKUP" 2>/dev/null || true

cat >/etc/exports <<'EOF'
# aglfs3 — local ZFS (/mnt/*) + Tailscale
/mnt/shares    *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=13,nohide)
/mnt/overpower *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=10,nohide)
/mnt/power     *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=11,nohide)
/mnt/storage   *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=12,nohide)
EOF

# Gateway aglfs1 — exportar só se mount existir
for p in /mnt/aglfs1-shares /mnt/aglfs1-overpower /mnt/aglfs1-power /mnt/aglfs1-storage; do
  if [[ -d "$p" ]]; then
    fsid="${p##*/aglfs1-}"
    case "$fsid" in
      shares) fid=23 ;; overpower) fid=20 ;; power) fid=21 ;; storage) fid=22 ;; *) fid=99 ;;
    esac
    echo "${p} *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=${fid},nohide)" >> /etc/exports
  fi
done

exportfs -ra
systemctl restart nfs-server 2>/dev/null || systemctl restart nfs-kernel-server
systemctl is-active smbd nfs-server nfs-kernel-server 2>/dev/null | paste -sd' ' -
exportfs -v | grep -E '^/mnt/' | head -12
INNER
}

if [[ "$APPLY" == true ]]; then
  log "Aplicar exports CT${VMID}..."
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "pct exec ${VMID} -- bash -s" <<< "$(inner_script)"
  else
    inner_script | pct exec "${VMID}" -- bash -s
  fi
  log "OK"
else
  log "DRY-RUN: actualizar /etc/exports CT${VMID} (/mnt/* + aglfs1 gateway paths)"
fi
