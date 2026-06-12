#!/usr/bin/env bash
# Cria LXC CT193 (agl-obsidian) no AGLSRV1 — hub Obsidian + CouchDB + Git bridge.
# Executar no nó Proxmox como root.
set -euo pipefail

: "${CT_OBSIDIAN_VMID:=193}"
: "${CT_OBSIDIAN_HOSTNAME:=agl-obsidian}"
: "${CT_OBSIDIAN_MEMORY_MB:=2048}"
: "${CT_OBSIDIAN_SWAP_MB:=512}"
: "${CT_OBSIDIAN_CORES:=2}"
: "${CT_OBSIDIAN_DISK_GB:=32}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-zfs}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"
: "${CT_OBSIDIAN_IP:=192.168.0.193/24}"
: "${CT_OBSIDIAN_GW:=192.168.0.1}"

command -v pct >/dev/null || { echo "ERRO: executar no Proxmox (pct não encontrado)" >&2; exit 1; }

if pct status "${CT_OBSIDIAN_VMID}" &>/dev/null; then
  echo "AVISO: CT ${CT_OBSIDIAN_VMID} já existe" >&2
  pct status "${CT_OBSIDIAN_VMID}"
  exit 0
fi

pct create "${CT_OBSIDIAN_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_OBSIDIAN_HOSTNAME}" \
  --memory "${CT_OBSIDIAN_MEMORY_MB}" \
  --swap "${CT_OBSIDIAN_SWAP_MB}" \
  --cores "${CT_OBSIDIAN_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_OBSIDIAN_DISK_GB}" \
  --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags obsidian,llm-wiki,agl-infra

pct start "${CT_OBSIDIAN_VMID}"
sleep 5
pct set "${CT_OBSIDIAN_VMID}" -net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=${CT_OBSIDIAN_IP},gw=${CT_OBSIDIAN_GW}"

echo "OK: CT ${CT_OBSIDIAN_VMID} (${CT_OBSIDIAN_HOSTNAME}) criado, IP ${CT_OBSIDIAN_IP}"
echo "Próximos passos (AGLSRV1):"
echo "  bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor ${CT_OBSIDIAN_VMID}"
echo "  pct reboot ${CT_OBSIDIAN_VMID}"
echo "  pct exec ${CT_OBSIDIAN_VMID} -- bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/proxmox/bootstrap-ct193-obsidian.sh"
