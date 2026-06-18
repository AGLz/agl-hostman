#!/usr/bin/env bash
# Cutover WireGuard hub FGSRV6 → CT576 wireguard6 no FGSRV7.
# 1) Deploy wg0.conf  2) DNAT host 51823  3) Stop WG FGSRV6  4) Start WG576  5) Test handshakes
#
# Uso (root FGSRV7):
#   BACKUP_WG=/root/fgsrv6-backup/wireguard/wg0.conf \
#     bash scripts/maint/fgsrv07/cutover-wireguard6.sh
#
# Variáveis:
#   FGSRV6=root@100.83.51.9
#   FGSRV7_PUBLIC=191.252.93.227
#   WG_CT_IP=192.168.70.250
#   WG_PORT=51823
#   SKIP_FGSRV6_STOP=1 — não parar WG no FGSRV6 (só teste interno)
set -euo pipefail

FGSRV6="${FGSRV6:-root@100.83.51.9}"
FGSRV7_PUBLIC="${FGSRV7_PUBLIC:-191.252.93.227}"
WG_CT_IP="${WG_CT_IP:-192.168.70.250}"
WG_PORT="${WG_PORT:-51823}"
VMID=576
BACKUP_WG="${BACKUP_WG:-/root/fgsrv6-backup/wireguard/wg0.conf}"
SKIP_FGSRV6_STOP="${SKIP_FGSRV6_STOP:-0}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if [[ ! -f "${BACKUP_WG}" ]]; then
    echo "Erro: ${BACKUP_WG} não encontrado" >&2
    exit 1
fi

log "Instalar wireguard + wg0.conf no CT${VMID}"
pct status "${VMID}" | grep -qi running || pct start "${VMID}"
sleep 3
pct exec "${VMID}" -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq wireguard wireguard-tools iptables iproute2
    sysctl -w net.ipv4.ip_forward=1
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
'

pct mount "${VMID}"
mnt="/var/lib/lxc/${VMID}/rootfs"
mkdir -p "${mnt}/etc/wireguard"
install -m 600 "${BACKUP_WG}" "${mnt}/etc/wireguard/wg0.conf"
chown 100000:100000 "${mnt}/etc/wireguard/wg0.conf"
pct unmount "${VMID}"

log "DNAT UDP ${WG_PORT} → ${WG_CT_IP}:${WG_PORT} no host FGSRV7"
sysctl -w net.ipv4.ip_forward=1
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf

if ! iptables -t nat -C PREROUTING -p udp --dport "${WG_PORT}" -j DNAT --to-destination "${WG_CT_IP}:${WG_PORT}" 2>/dev/null; then
    iptables -t nat -A PREROUTING -p udp --dport "${WG_PORT}" -j DNAT --to-destination "${WG_CT_IP}:${WG_PORT}"
fi
# Não MASQUERADE inbound para o CT (quebra endpoint/handshake). Outbound já coberto por MASQUERADE vmbr70→vmbr0.

# Persistir regras (debian/proxmox)
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save 2>/dev/null || true
elif [[ -d /etc/iptables ]]; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

if [[ "${SKIP_FGSRV6_STOP}" != "1" ]]; then
    log "Parar WireGuard no FGSRV6"
    ssh -o BatchMode=yes "${FGSRV6}" 'systemctl stop wg-quick@wg0 2>/dev/null || wg-quick down wg0 2>/dev/null || true; systemctl disable wg-quick@wg0 2>/dev/null || true'
fi

log "Activar wg0 no CT${VMID}"
pct exec "${VMID}" -- systemctl enable wg-quick@wg0
pct exec "${VMID}" -- systemctl restart wg-quick@wg0
sleep 5

log "Handshakes (CT${VMID}):"
pct exec "${VMID}" -- wg show wg0 | grep -E 'interface|listening|peer|handshake|transfer' || pct exec "${VMID}" -- wg show

log "Endpoint público para peers: ${FGSRV7_PUBLIC}:${WG_PORT}"
log "Actualizar em cada client: Endpoint = ${FGSRV7_PUBLIC}:${WG_PORT}"
