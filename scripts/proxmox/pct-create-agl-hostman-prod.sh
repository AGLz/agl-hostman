#!/usr/bin/env bash
# Cria LXC CT134 (agl-hostman produção) no AGLSRV1.
# Executar no nó Proxmox como root.
#
# Antes: confirmar VMID 134 livre (ipmitool5 foi renumerado para 534 — ver docs/PROXMOX-VMID-RENUMBER-2026-06.md)
#
#   set -a && source pct-create-agl-hostman-prod.env && set +a
#   bash pct-create-agl-hostman-prod.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/pct-create-agl-hostman-prod.env}"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a && source "${ENV_FILE}" && set +a
fi

: "${CT_HOSTMAN_PROD_VMID:=134}"
: "${CT_HOSTMAN_PROD_HOSTNAME:=agl-hostman}"
: "${CT_HOSTMAN_PROD_MEMORY_MB:=16384}"
: "${CT_HOSTMAN_PROD_SWAP_MB:=2048}"
: "${CT_HOSTMAN_PROD_CORES:=8}"
: "${CT_HOSTMAN_PROD_DISK_GB:=64}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${PROXMOX_ROOTFS_STORAGE:=local-zfs}"
: "${PROXMOX_TEMPLATE:=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"

if pct status "${CT_HOSTMAN_PROD_VMID}" &>/dev/null; then
  echo "AVISO: CT ${CT_HOSTMAN_PROD_VMID} já existe" >&2
  pct status "${CT_HOSTMAN_PROD_VMID}"
  exit 0
fi

NET_ARG="name=eth0,bridge=${PROXMOX_BRIDGE},ip=dhcp"
if [[ -n "${CT_HOSTMAN_PROD_IP:-}" ]]; then
  GW="${CT_HOSTMAN_PROD_GW:-192.168.0.1}"
  NET_ARG="name=eth0,bridge=${PROXMOX_BRIDGE},ip=${CT_HOSTMAN_PROD_IP},gw=${GW}"
fi

pct create "${CT_HOSTMAN_PROD_VMID}" "${PROXMOX_TEMPLATE}" \
  --hostname "${CT_HOSTMAN_PROD_HOSTNAME}" \
  --memory "${CT_HOSTMAN_PROD_MEMORY_MB}" \
  --swap "${CT_HOSTMAN_PROD_SWAP_MB}" \
  --cores "${CT_HOSTMAN_PROD_CORES}" \
  --rootfs "${PROXMOX_ROOTFS_STORAGE}:${CT_HOSTMAN_PROD_DISK_GB}" \
  --net0 "${NET_ARG}" \
  --features nesting=1,keyctl=1,fuse=1,mknod=1 \
  --unprivileged 0 \
  --onboot 1 \
  --tags hostman,production,agl-hostman

pct start "${CT_HOSTMAN_PROD_VMID}"
echo "OK: CT ${CT_HOSTMAN_PROD_VMID} (${CT_HOSTMAN_PROD_HOSTNAME}) criado e arrancado."
echo "  pct passwd ${CT_HOSTMAN_PROD_VMID}"
echo "  pct-apply-agldv03-lxc-profile.sh --with-apparmor ${CT_HOSTMAN_PROD_VMID}   # se aplicável"
echo "  pct exec ${CT_HOSTMAN_PROD_VMID} -- bash -s < bootstrap-ct134-agl-hostman-prod.sh"
