#!/usr/bin/env bash
# FGSRV7: garante /dev/net/tun no CT243 (LXC unprivileged) para tailscaled.

set -euo pipefail

CT_VMID="${CT_VMID:-243}"
CONF="/etc/pve/lxc/${CT_VMID}.conf"
EXPECT_HOSTNAME="${EXPECT_HOSTNAME:-fgsrv7}"

if ! command -v pct >/dev/null 2>&1; then
    echo "Erro: pct não encontrado." >&2
    exit 1
fi

if [[ -n "${EXPECT_HOSTNAME}" ]] && [[ "$(hostname -s)" != "${EXPECT_HOSTNAME}" ]]; then
    echo "Erro: hostname ($(hostname -s)) != EXPECT_HOSTNAME=${EXPECT_HOSTNAME}" >&2
    exit 1
fi

if [[ ! -f "${CONF}" ]]; then
    echo "Erro: ${CONF} não existe." >&2
    exit 1
fi

_add_line() {
    local line="$1"
    grep -qF "${line}" "${CONF}" 2>/dev/null && return 0
    echo "${line}" >>"${CONF}"
    echo "   + ${line}"
}

_add_line 'lxc.cgroup2.devices.allow: c 10:200 rwm'
_add_line 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file'

echo "==> Reiniciar CT${CT_VMID} para aplicar LXC (interrupção breve)"
pct reboot "${CT_VMID}" || { pct stop "${CT_VMID}"; sleep 2; pct start "${CT_VMID}"; }
sleep 5
pct exec "${CT_VMID}" -- ls -la /dev/net/tun
echo "OK LXC tailscale tun CT${CT_VMID}"
