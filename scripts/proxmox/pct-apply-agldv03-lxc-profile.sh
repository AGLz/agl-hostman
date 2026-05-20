#!/usr/bin/env bash
# Alinha LXC ao perfil do CT179 (agldv03): bind mounts NFS/overpower + Tailscale /dev/net/tun.
# Mantém unprivileged=1 (igual CT179/186/187) — NÃO converter para privileged.
#
# Uso no AGLSRV1 (root):
#   bash pct-apply-agldv03-lxc-profile.sh 188 189 190 191
#   bash pct-apply-agldv03-lxc-profile.sh --with-apparmor 188 189 190 191
#
# --with-apparmor: adiciona lxc.apparmor.profile: unconfined (recomendado para Docker-in-LXC, como CT186/187).

set -euo pipefail

WITH_APPARMOR=0
VMIDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-apparmor) WITH_APPARMOR=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) VMIDS+=("$1"); shift ;;
  esac
done

if [[ ${#VMIDS[@]} -eq 0 ]]; then
  VMIDS=(188 189 190 191)
fi

command -v pct >/dev/null || { echo "ERRO: executar no nó Proxmox." >&2; exit 1; }

ensure_conf_line() {
  local conf="$1" line="$2"
  if grep -qF "${line}" "${conf}" 2>/dev/null; then
    return 0
  fi
  echo "${line}" >> "${conf}"
}

apply_one() {
  local vmid="$1"
  local conf="/etc/pve/lxc/${vmid}.conf"

  pct config "${vmid}" >/dev/null || { echo "ERRO: CT${vmid} inexistente" >&2; return 1; }

  echo "=== CT${vmid}: parar (se a correr) ==="
  if pct status "${vmid}" 2>/dev/null | grep -q running; then
    pct stop "${vmid}"
  fi

  echo "=== CT${vmid}: mount points (perfil CT179) ==="
  pct set "${vmid}" -mp0 /mnt/shares,mp=/mnt/shares
  pct set "${vmid}" -mp1 /overpower/base,mp=/mnt/overpower
  pct set "${vmid}" -mp2 /spark/base,mp=/mnt/power
  pct set "${vmid}" -mp5 /mnt/storage,mp=/mnt/storage
  pct set "${vmid}" -mp6 /mnt/storage/Extracted,mp=/mnt/disks/gd/BB/Extracted
  pct set "${vmid}" -mp7 /mnt/storage/Extracted,mp=/mnt/pve/common/media/Extracted
  pct set "${vmid}" -mp8 /mnt/storage/Extracted_New,mp=/mnt/disks/gd/BB/Extracted_New
  pct set "${vmid}" -mp9 /mnt/storage/Extracted_New,mp=/mnt/pve/common/media/Extracted_New

  echo "=== CT${vmid}: DNS (CT179) ==="
  pct set "${vmid}" -nameserver 192.168.0.102 -searchdomain localdomain

  echo "=== CT${vmid}: LXC tun + dispositivos (Tailscale / GPU cgroup) ==="
  ensure_conf_line "${conf}" 'lxc.cgroup2.devices.allow: c 226:* rwm'
  ensure_conf_line "${conf}" 'lxc.cgroup2.devices.allow: c 10:200 rwm'
  ensure_conf_line "${conf}" 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file'
  ensure_conf_line "${conf}" 'lxc.mount.entry: /proc/sys/net/ipv4/ip_unprivileged_port_start proc/sys/net/ipv4/ip_unprivileged_port_start none bind,create=file,ro 0 0'

  if [[ "${WITH_APPARMOR}" -eq 1 ]]; then
    ensure_conf_line "${conf}" 'lxc.apparmor.profile: unconfined'
  fi

  # unprivileged: 1 é definido na criação (pct create --unprivileged 1); não alterar aqui (opção read-only).

  echo "=== CT${vmid}: arrancar ==="
  pct start "${vmid}"

  echo "=== CT${vmid}: verificação rápida ==="
  pct exec "${vmid}" -- test -c /dev/net/tun && echo "  OK /dev/net/tun"
  pct exec "${vmid}" -- test -d /mnt/overpower && echo "  OK /mnt/overpower"
  pct config "${vmid}" | grep -E '^(unprivileged|mp0|mp1|lxc\.(mount|cgroup|apparmor))' || true
  echo ""
}

echo "Perfil agldv03 (CT179): mounts + tun; unprivileged=1; apparmor_unconfined=${WITH_APPARMOR}"
echo ""

for vmid in "${VMIDS[@]}"; do
  apply_one "${vmid}"
done

echo "OK: ${#VMIDS[@]} CT(s) alinhados. Instalar tailscaled no CT e: tailscale up --accept-dns=false --ssh …"
