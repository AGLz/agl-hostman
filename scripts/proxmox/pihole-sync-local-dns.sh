#!/usr/bin/env bash
# Sincroniza registos DNS locais do Pi-hole CT102 a partir dos LXC no Proxmox.
# Corrige: domínio localdomain (alinha com PVE), hosts em falta, revServer para router sem DNS.
#
# Uso no AGLSRV1 (root):
#   bash scripts/proxmox/pihole-sync-local-dns.sh
#   bash scripts/proxmox/pihole-sync-local-dns.sh --dry-run
#
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

VMID=102
DOMAIN=localdomain
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="/tmp/pihole-hosts-sync.txt"
UPDATE_PY="${SCRIPT_DIR}/pihole-update-dns.py"

command -v pct >/dev/null || { echo "ERRO: executar no nó Proxmox (pct não encontrado)." >&2; exit 1; }
[[ -f "${UPDATE_PY}" ]] || { echo "ERRO: falta ${UPDATE_PY}" >&2; exit 1; }

{
  echo "192.168.0.245 aglsrv1"
  for conf in /etc/pve/lxc/*.conf; do
    [[ -f "${conf}" ]] || continue
    hostname=$(grep -m1 '^hostname:' "${conf}" | awk '{print $2}')
    ip=$(grep -m1 '^net0:' "${conf}" | grep -oE 'ip=([0-9]+\.){3}[0-9]+' | head -1 | cut -d= -f2)
    [[ -n "${hostname}" && -n "${ip}" ]] && echo "${ip} ${hostname}"
  done
} | sort -u -k2,2 > "${HOSTS_FILE}"

echo "=== Registos DNS ($(wc -l < "${HOSTS_FILE}")) ==="
head -8 "${HOSTS_FILE}"
echo "  ..."

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: sem alterações no Pi-hole."
  exit 0
fi

pct push "${VMID}" "${HOSTS_FILE}" /tmp/pihole-hosts-sync.txt
pct push "${VMID}" "${UPDATE_PY}" /tmp/pihole-update-dns.py
pct exec "${VMID}" -- python3 /tmp/pihole-update-dns.py "${DOMAIN}" /tmp/pihole-hosts-sync.txt
pct exec "${VMID}" -- systemctl restart pihole-FTL
sleep 2
pct exec "${VMID}" -- systemctl is-active pihole-FTL
rm -f "${HOSTS_FILE}"

echo "=== Testes DNS ==="
for q in aglfs1 agldv03 aglfs1.localdomain google.com; do
  printf '  %-22s ' "${q}:"
  dig +short +time=2 +tries=1 @192.168.0.102 "${q}" 2>/dev/null | tr '\n' ' ' || true
  echo
done
