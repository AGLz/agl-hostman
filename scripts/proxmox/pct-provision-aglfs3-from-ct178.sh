#!/usr/bin/env bash
# Provisiona fileserver AGLSRV3 (CT538 aglfs3) inspirado em AGLSRV1 CT178 (aglfs1).
# Fase posterior ao PBS + renumber — NÃO executar sem autorização (mounts locais SRV3).
#
# Uso:
#   bash scripts/proxmox/pct-provision-aglfs3-from-ct178.sh --dry-run
#   bash scripts/proxmox/pct-provision-aglfs3-from-ct178.sh --apply
#
# CT178 usa mp0-mp9 para shares/overpower/spark — no SRV3 mapear para aglsrv3-tb + local.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv3-vmid-map.env
source "${SCRIPT_DIR}/aglsrv3-vmid-map.env"

DRY_RUN=true
APPLY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --apply) APPLY=true; DRY_RUN=false ;;
    -h | --help)
      echo "Uso: $0 [--dry-run|--apply]" >&2
      exit 0
      ;;
  esac
done

VMID="${AGLSRV3_AGLFS3_VMID:-338}"
HOSTNAME="${AGLSRV3_AGLFS3_HOSTNAME:-aglfs3}"
IP="${AGLSRV3_AGLFS3_IP}"
GW="${AGLSRV3_PBS_GW}"
STORAGE="${AGLSRV3_FS_STORAGE:-aglsrv3-tb}"
TEMPLATE="${AGLSRV3_TEMPLATE:-local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

if ! command -v pct >/dev/null; then
  echo "ERRO: executar no AGLSRV3." >&2
  exit 1
fi

if pct config "${VMID}" &>/dev/null; then
  log "CT${VMID} já existe"
  exit 0
fi

log "PLAN CT${VMID} ${HOSTNAME} @ ${IP} (base CT178 aglfs1)"
log "  rootfs: ${STORAGE}:64G"
log "  mp0: aglsrv3-tb/shares → /mnt/shares"
log "  mp1: aglsrv3-tb/data → /mnt/data"
log "  features: fuse,nesting,nfs,cifs,keyctl (como CT178)"

if [[ "${DRY_RUN}" == true ]]; then
  log "DRY-RUN — usar --apply no AGLSRV3 após PBS + renumber"
  exit 0
fi

zfs list "aglsrv3-tb/shares" >/dev/null 2>&1 || zfs create "aglsrv3-tb/shares"
zfs list "aglsrv3-tb/data" >/dev/null 2>&1 || zfs create "aglsrv3-tb/data"
mkdir -p "/aglsrv3-tb/shares" "/aglsrv3-tb/data"

pct create "${VMID}" "${TEMPLATE}" \
  --hostname "${HOSTNAME}" \
  --memory 8192 --swap 2048 \
  --cores 8 \
  --rootfs "${STORAGE}:64" \
  --net0 "name=eth0,bridge=vmbr0,gw=${GW},ip=${IP},type=veth" \
  --nameserver 192.168.15.117 \
  --searchdomain aglz.io \
  --features nesting=1,fuse=1,mknod=1,keyctl=1 \
  --mp0 "/aglsrv3-tb/shares,mp=/mnt/shares" \
  --mp1 "/aglsrv3-tb/data,mp=/mnt/data" \
  --onboot 1 \
  --tags "agl;fileserver;aglsrv3" \
  --description "Fileserver AGLSRV3 — perfil CT178 (aglfs1); storage local ZFS"

pct set "${VMID}" -lxc.mount.entry "/dev/net/tun dev/net/tun none bind,create=file" 2>/dev/null \
  || echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> "/etc/pve/lxc/${VMID}.conf"

pct start "${VMID}"
log "OK CT${VMID} criado — instalar Samba/NFS/Tailscale manualmente (ver docs/CT178_*.md)"
