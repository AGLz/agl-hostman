#!/usr/bin/env bash
# Cria LXC dedicados LiteLLM + OpenClaw no Proxmox (por omissão CT186 e CT187).
# Executar na AGLSRV1 como root: bash scripts/proxmox/pct-create-agl-litellm-openclaw.sh
#
# Nota: em AGLSRV1 os VMIDs 150/151 estão frequentemente ocupados por **VMs QEMU**;
# o par canónico no agl-hostman passou a ser **186** (LiteLLM) e **187** (OpenClaw).
# Variáveis (opcional): ver scripts/proxmox/agl-litellm-openclaw-lxc.env.example

set -euo pipefail

: "${CT_LITELLM_VMID:=186}"
: "${CT_OPENCLAW_VMID:=187}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-lvm}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_amd64.tar.zst}"
: "${CT_MEMORY_MB:=8192}"
: "${CT_SWAP_MB:=1024}"
: "${CT_CORES:=4}"
: "${CT_DISK_GB:=32}"
: "${CT_LITELLM_HOSTNAME:=agl-litellm}"
: "${CT_OPENCLAW_HOSTNAME:=agl-openclaw}"

die() {
  echo "ERRO: $*" >&2
  exit 1
}

command -v pct >/dev/null || die "pct não encontrado — executar no nó Proxmox."

for id in "${CT_LITELLM_VMID}" "${CT_OPENCLAW_VMID}"; do
  if pct config "${id}" &>/dev/null; then
    die "VMID ${id} já existe. Ajuste CT_*_VMID ou destrua o CT manualmente."
  fi
done

echo "=== Criar CT ${CT_LITELLM_VMID} (${CT_LITELLM_HOSTNAME}) ==="
pct create "${CT_LITELLM_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_LITELLM_HOSTNAME}" \
  --memory "${CT_MEMORY_MB}" --swap "${CT_SWAP_MB}" \
  --cores "${CT_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_DISK_GB}" \
  --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags "agl,litellm"

echo "=== Criar CT ${CT_OPENCLAW_VMID} (${CT_OPENCLAW_HOSTNAME}) ==="
pct create "${CT_OPENCLAW_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_OPENCLAW_HOSTNAME}" \
  --memory "${CT_MEMORY_MB}" --swap "${CT_SWAP_MB}" \
  --cores "${CT_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_DISK_GB}" \
  --net0 "name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags "agl,openclaw"

echo "=== Arrancar CTs ==="
pct start "${CT_LITELLM_VMID}"
pct start "${CT_OPENCLAW_VMID}"

echo ""
echo "OK: CT ${CT_LITELLM_VMID} (${CT_LITELLM_HOSTNAME}) e ${CT_OPENCLAW_VMID} (${CT_OPENCLAW_HOSTNAME}) criados e iniciados."
echo "Próximo: definir password/SSH, depois dentro de cada CT executar os scripts bootstrap (ver docs/LITELLM-OPENCLAW-DEDICATED-LXC.md)."
