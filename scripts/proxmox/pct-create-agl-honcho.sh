#!/usr/bin/env bash
# Cria LXC CT192 (agl-honcho) no AGLSRV1 — Honcho self-hosted.
# Executar no nó como root.
#
# set -a && source agl-honcho-lxc.env && set +a && bash pct-create-agl-honcho.sh

set -euo pipefail

: "${CT_HONCHO_VMID:=192}"
: "${CT_HONCHO_HOSTNAME:=agl-honcho}"
: "${CT_HONCHO_MEMORY_MB:=8192}"
: "${CT_HONCHO_SWAP_MB:=1024}"
: "${CT_HONCHO_CORES:=4}"
: "${CT_HONCHO_DISK_GB:=48}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-zfs}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"

if pct status "${CT_HONCHO_VMID}" &>/dev/null; then
  echo "AVISO: CT ${CT_HONCHO_VMID} já existe" >&2
  pct status "${CT_HONCHO_VMID}"
  exit 0
fi

pct create "${CT_HONCHO_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_HONCHO_HOSTNAME}" \
  --memory "${CT_HONCHO_MEMORY_MB}" \
  --swap "${CT_HONCHO_SWAP_MB}" \
  --cores "${CT_HONCHO_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_HONCHO_DISK_GB}" \
  --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags honcho,agl-agency

pct start "${CT_HONCHO_VMID}"
echo "OK: CT ${CT_HONCHO_VMID} (${CT_HONCHO_HOSTNAME}) criado e arrancado."
echo "  pct passwd ${CT_HONCHO_VMID}"
echo "  pct-apply-agldv03-lxc-profile.sh --with-apparmor ${CT_HONCHO_VMID}"
echo "  bootstrap-ct192-honcho.sh"
