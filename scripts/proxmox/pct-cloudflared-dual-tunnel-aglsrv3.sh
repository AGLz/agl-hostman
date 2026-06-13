#!/usr/bin/env bash
# CT304 + CT306 (cloudflared3a / cloudflared3b) — dois conectores cloudflared no AGLSRV3.
# Um túnel continua activo enquanto o outro CT está parado para backup.
#
# Uso (no host aglsrv3 ou via SSH):
#   bash scripts/proxmox/pct-cloudflared-dual-tunnel-aglsrv3.sh
#   bash scripts/proxmox/pct-cloudflared-dual-tunnel-aglsrv3.sh --check-only
#
# Pré-requisitos: pct, CT306 (cloudflared3b) running com cloudflared OK.
# Fix conhecido CT304: /etc/resolv.conf com chattr +i impede arranque Proxmox.

set -euo pipefail

CT_PRIMARY=306
CT_SECONDARY=304
CHECK_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    -h | --help)
      echo "Uso: $0 [--check-only]" >&2
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      exit 1
      ;;
  esac
done

command -v pct >/dev/null || {
  echo "ERRO: executar no Proxmox (pct)." >&2
  exit 1
}

ensure_resolv_mutable() {
  local vmid=$1
  if pct status "${vmid}" | grep -q running; then
    return 0
  fi
  pct mount "${vmid}" || true
  local rootfs="/var/lib/lxc/${vmid}/rootfs/etc/resolv.conf"
  if [[ -f "${rootfs}" ]]; then
    chattr -i "${rootfs}" 2>/dev/null || true
    echo "OK: chattr -i em CT${vmid} resolv.conf"
  fi
  pct unmount "${vmid}" 2>/dev/null || true
}

cloudflared_active() {
  local vmid=$1
  pct exec "${vmid}" -- systemctl is-active cloudflared 2>/dev/null | grep -q '^active$'
}

if [[ "${CHECK_ONLY}" == true ]]; then
  pct list | grep -E "^\s*(${CT_PRIMARY}|${CT_SECONDARY})\s" || true
  for vmid in "${CT_PRIMARY}" "${CT_SECONDARY}"; do
    if pct status "${vmid}" 2>/dev/null | grep -q running; then
      echo "CT${vmid} cloudflared: $(pct exec "${vmid}" -- systemctl is-active cloudflared 2>/dev/null || echo unknown)"
      pct exec "${vmid}" -- ip -4 -o addr show dev eth0 2>/dev/null || true
    else
      echo "CT${vmid}: stopped"
    fi
  done
  exit 0
fi

echo "=== Estado inicial ==="
pct list | grep -E "^\s*(${CT_PRIMARY}|${CT_SECONDARY})\s" || true

ensure_resolv_mutable "${CT_SECONDARY}"

echo "=== Rede CT${CT_SECONDARY} (cloudflared3a — IP estático via aglsrv3-dual-lan-static.sh) ==="
# Rede gerida por scripts/proxmox/aglsrv3-dual-lan-static.sh; não forçar DHCP aqui.

pct set "${CT_SECONDARY}" --onboot 1
pct set "${CT_SECONDARY}" --description "cloudflared3a — HA com CT306 (cloudflared3b); túnel aglsrv3"

echo "=== Arranque CT${CT_SECONDARY} ==="
if pct status "${CT_SECONDARY}" | grep -q stopped; then
  pct start "${CT_SECONDARY}"
  sleep 5
fi

pct exec "${CT_SECONDARY}" -- systemctl enable cloudflared
pct exec "${CT_SECONDARY}" -- systemctl restart cloudflared
sleep 3

echo "=== Verificação ==="
for vmid in "${CT_PRIMARY}" "${CT_SECONDARY}"; do
  if ! pct status "${vmid}" | grep -q running; then
    echo "ERRO: CT${vmid} não está running." >&2
    exit 1
  fi
  if ! cloudflared_active "${vmid}"; then
    echo "ERRO: cloudflared inactivo no CT${vmid}." >&2
    pct exec "${vmid}" -- systemctl status cloudflared --no-pager -l | head -25 || true
    exit 1
  fi
  echo "OK: CT${vmid} cloudflared active — $(pct exec "${vmid}" -- ip -4 -o addr show dev eth0 | awk '{print $4}')"
done

echo "Feito. Dois conectores activos (304 cloudflared3a + 306 cloudflared3b). Não usar chattr +i em /etc/resolv.conf nos CTs Proxmox."
