#!/usr/bin/env bash
# Cria LXC dedicados Hermes (188), EvoNexus (189) e OpenHuman (190) no Proxmox AGLSRV1.
# Executar no nó como root: bash scripts/proxmox/pct-create-agl-hermes-evonexus-openhuman.sh
#
# Variáveis: scripts/proxmox/agl-hermes-evonexus-openhuman-lxc.env.example

set -euo pipefail

: "${CT_HERMES_VMID:=188}"
: "${CT_EVONEXUS_VMID:=189}"
: "${CT_OPENHUMAN_VMID:=190}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-zfs}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"

: "${CT_HERMES_MEMORY_MB:=8192}"
: "${CT_HERMES_SWAP_MB:=1024}"
: "${CT_HERMES_CORES:=4}"
: "${CT_HERMES_DISK_GB:=32}"
: "${CT_HERMES_HOSTNAME:=agl-hermes}"

: "${CT_EVONEXUS_MEMORY_MB:=16384}"
: "${CT_EVONEXUS_SWAP_MB:=2048}"
: "${CT_EVONEXUS_CORES:=8}"
: "${CT_EVONEXUS_DISK_GB:=64}"
: "${CT_EVONEXUS_HOSTNAME:=agl-evonexus}"

: "${CT_OPENHUMAN_MEMORY_MB:=8192}"
: "${CT_OPENHUMAN_SWAP_MB:=1024}"
: "${CT_OPENHUMAN_CORES:=4}"
: "${CT_OPENHUMAN_DISK_GB:=48}"
: "${CT_OPENHUMAN_HOSTNAME:=agl-openhuman}"

die() {
  echo "ERRO: $*" >&2
  exit 1
}

command -v pct >/dev/null || die "pct não encontrado — executar no nó Proxmox."

LXC_FEATURES="nesting=1,keyctl=1,fuse=1,mknod=1"

for id in "${CT_HERMES_VMID}" "${CT_EVONEXUS_VMID}" "${CT_OPENHUMAN_VMID}"; do
  if pct config "${id}" &>/dev/null; then
    die "VMID ${id} já existe. Ajuste CT_*_VMID ou destrua o CT manualmente."
  fi
done

create_ct() {
  local vmid="$1" hostname="$2" memory="$3" swap="$4" cores="$5" disk_gb="$6" tag="$7"
  echo "=== Criar CT ${vmid} (${hostname}) ==="
  pct create "${vmid}" "${PROXMOX_TEMPLATE}" \
    --hostname "${hostname}" \
    --memory "${memory}" --swap "${swap}" \
    --cores "${cores}" \
    --rootfs "${PROXMOX_ROOTFS_STORAGE}:${disk_gb}" \
    --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
    --features "${LXC_FEATURES}" \
    --unprivileged 1 \
    --onboot 1 \
    --tags "agl,${tag}"
}

create_ct "${CT_HERMES_VMID}" "${CT_HERMES_HOSTNAME}" "${CT_HERMES_MEMORY_MB}" "${CT_HERMES_SWAP_MB}" \
  "${CT_HERMES_CORES}" "${CT_HERMES_DISK_GB}" "hermes"

create_ct "${CT_EVONEXUS_VMID}" "${CT_EVONEXUS_HOSTNAME}" "${CT_EVONEXUS_MEMORY_MB}" "${CT_EVONEXUS_SWAP_MB}" \
  "${CT_EVONEXUS_CORES}" "${CT_EVONEXUS_DISK_GB}" "evonexus"

create_ct "${CT_OPENHUMAN_VMID}" "${CT_OPENHUMAN_HOSTNAME}" "${CT_OPENHUMAN_MEMORY_MB}" "${CT_OPENHUMAN_SWAP_MB}" \
  "${CT_OPENHUMAN_CORES}" "${CT_OPENHUMAN_DISK_GB}" "openhuman"

echo "=== Arrancar CTs ==="
pct start "${CT_HERMES_VMID}"
pct start "${CT_EVONEXUS_VMID}"
pct start "${CT_OPENHUMAN_VMID}"

echo ""
echo "OK: CT ${CT_HERMES_VMID} (${CT_HERMES_HOSTNAME}), ${CT_EVONEXUS_VMID} (${CT_EVONEXUS_HOSTNAME}), ${CT_OPENHUMAN_VMID} (${CT_OPENHUMAN_HOSTNAME}) criados."
echo "Próximo:"
echo "  1. pct-set-static-ip-agl-188-190.sh (inclui .191 se existir)"
echo "  2. pct-apply-agldv03-lxc-profile.sh --with-apparmor ${CT_HERMES_VMID} ${CT_EVONEXUS_VMID} ${CT_OPENHUMAN_VMID}"
echo "  3. bootstraps — docs/HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md"
