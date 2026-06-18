#!/usr/bin/env bash
# Cria CTs 572 (fg-apis), 573 (n8n7), 576 (wireguard6) no FGSRV7 — Fase A migração FGSRV6.
#
# Uso (root no FGSRV7):
#   bash /path/agl-hostman/scripts/maint/fgsrv07/provision-fgsrv6-migration-cts.sh
#
# Variáveis opcionais:
#   EXPECT_HOSTNAME=fgsrv7
#   STORAGE=bkp
#   TEMPLATE=local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst
#   BRIDGE=vmbr70 GATEWAY=192.168.70.1

set -euo pipefail

EXPECT_HOSTNAME="${EXPECT_HOSTNAME:-fgsrv7}"
STORAGE="${STORAGE:-bkp}"
TEMPLATE="${TEMPLATE:-local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"
BRIDGE="${BRIDGE:-vmbr70}"
GATEWAY="${GATEWAY:-192.168.70.1}"

TUN_LINES=$'lxc.cgroup2.devices.allow: c 10:200 rwm\nlxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file'

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if ! command -v pct >/dev/null 2>&1; then
    echo 'Erro: pct não encontrado — correr como root no FGSRV7.' >&2
    exit 1
fi

if [[ -n "${EXPECT_HOSTNAME}" ]] && [[ "$(hostname -s)" != "${EXPECT_HOSTNAME}" ]]; then
    echo "Erro: hostname ($(hostname -s)) != EXPECT_HOSTNAME=${EXPECT_HOSTNAME}" >&2
    exit 1
fi

_create_ct() {
    local vmid="$1" hostname="$2" ip="$3" memory="$4" swap="$5" cores="$6" disk_gb="$7"
    local features="$8" extra_conf="${9:-}"

    if pct status "${vmid}" &>/dev/null; then
        log "VMID ${vmid} (${hostname}) já existe — skip create"
        return 0
    fi

    log "Criar CT ${vmid} ${hostname} @ ${ip}/24"
    local -a create_args=(
        create "${vmid}" "${TEMPLATE}"
        --hostname "${hostname}"
        --memory "${memory}" --swap "${swap}"
        --cores "${cores}"
        --rootfs "${STORAGE}:${disk_gb}"
        --net0 "name=eth0,bridge=${BRIDGE},ip=${ip}/24,gw=${GATEWAY},type=veth"
        --unprivileged 1
        --onboot 1
        --ostype debian
        --tags "agl,fgsrv6-migrate"
    )
    if [[ -n "${features}" ]]; then
        create_args+=(--features "${features}")
    fi
    pct "${create_args[@]}"

    if [[ -n "${extra_conf}" ]]; then
        local conf="/etc/pve/lxc/${vmid}.conf"
        printf '%s\n' "${extra_conf}" >> "${conf}"
    fi

    pct start "${vmid}"
    sleep 4
}

log "=== CT572 fg-apis ==="
_create_ct 572 fg-apis 192.168.70.246 1024 512 2 32 "" ""

log "=== CT573 n8n7 (Docker) ==="
_create_ct 573 n8n7 192.168.70.247 1536 512 2 16 "nesting=1,keyctl=1" ""

log "=== CT576 wireguard6 (tun) ==="
_create_ct 576 wireguard6 192.168.70.250 1024 512 1 8 "" "${TUN_LINES}"

log "Concluído. Próximo: bootstrap-fgsrv6-migration-cts.sh"
