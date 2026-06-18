#!/usr/bin/env bash
# Instalar cloudflared via EnvironmentFile (evita token na linha de comando / ps).
# Uso no nó Proxmox: source este ficheiro e chamar cloudflared_install_from_envfile.
# shellcheck shell=bash

cloudflared_install_from_envfile() {
    local vmid="$1"
    local env_file="$2"
    local description="${3:-cloudflared tunnel}"

    if [[ ! -f "$env_file" ]]; then
        echo "ERRO: ficheiro env inexistente: ${env_file}" >&2
        return 1
    fi

    pct status "${vmid}" | grep -qi running || pct start "${vmid}"
    sleep 2

    pct push "${vmid}" "${env_file}" /etc/default/cloudflared
    pct exec "${vmid}" -- chmod 600 /etc/default/cloudflared

    pct exec "${vmid}" -- bash -s -- "$description" <<'REMOTE'
set -euo pipefail
desc="$1"
cat > /etc/systemd/system/cloudflared.service <<UNIT
[Unit]
Description=${desc}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/default/cloudflared
ExecStart=/usr/bin/cloudflared tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable cloudflared
systemctl restart cloudflared
REMOTE
}

cloudflared_verify_active() {
    local vmid="$1"
    sleep 3
    pct exec "${vmid}" -- systemctl is-active cloudflared
    pct exec "${vmid}" -- journalctl -u cloudflared -n 3 --no-pager | grep -E 'Registered|ERR|invalid' || true
}
