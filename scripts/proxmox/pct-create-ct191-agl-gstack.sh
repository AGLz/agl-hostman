#!/usr/bin/env bash
# Cria LXC CT191 agl-gstack (OpenClaw + GStack / Jarvis O — AGLz AI Agency).
# Executar no AGLSRV1 como root.
#
# Variáveis: scripts/proxmox/agl-gstack-lxc.env.example

set -euo pipefail

: "${CT_GSTACK_VMID:=191}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-zfs}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"
: "${CT_GSTACK_MEMORY_MB:=16384}"
: "${CT_GSTACK_SWAP_MB:=2048}"
: "${CT_GSTACK_CORES:=8}"
: "${CT_GSTACK_DISK_GB:=64}"
: "${CT_GSTACK_HOSTNAME:=agl-gstack}"

die() {
  echo "ERRO: $*" >&2
  exit 1
}

command -v pct >/dev/null || die "pct não encontrado — executar no nó Proxmox."

if pct config "${CT_GSTACK_VMID}" &>/dev/null; then
  die "VMID ${CT_GSTACK_VMID} já existe."
fi

echo "=== Criar CT ${CT_GSTACK_VMID} (${CT_GSTACK_HOSTNAME}) ==="
pct create "${CT_GSTACK_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_GSTACK_HOSTNAME}" \
  --memory "${CT_GSTACK_MEMORY_MB}" --swap "${CT_GSTACK_SWAP_MB}" \
  --cores "${CT_GSTACK_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_GSTACK_DISK_GB}" \
  --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags "agl,gstack,openclaw,aglz-agency"

pct start "${CT_GSTACK_VMID}"

echo ""
echo "OK: CT ${CT_GSTACK_VMID} (${CT_GSTACK_HOSTNAME}) criado e iniciado."
echo "Próximo:"
echo "  1. bash scripts/proxmox/pct-set-static-ip-ct191.sh"
echo "  2. bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor ${CT_GSTACK_VMID}"
echo "  3. bootstrap-ct191-openclaw-gstack.sh (docs/AGL-GSTACK-CT191-DEDICATED-LXC.md)"
