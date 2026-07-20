#!/usr/bin/env bash
# Fix Docker/runc CVE-2025-52881 em CT LXC unprivileged (Ubuntu + Harbor CT182).
# Erro: open sysctl net.ipv4.ip_unprivileged_port_start ... permission denied
# Ref: https://github.com/opencontainers/runc/issues/4968
set -euo pipefail

CTID="${1:-182}"
CONF="/etc/pve/lxc/${CTID}.conf"

[ -f "$CONF" ] || { echo "CT $CTID não encontrado: $CONF"; exit 1; }

grep -q 'lxc.apparmor.profile: unconfined' "$CONF" || \
  echo 'lxc.apparmor.profile: unconfined' >> "$CONF"

grep -q 'apparmor/parameters/enabled' "$CONF" || \
  echo 'lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind 0 0' >> "$CONF"

echo "OK: $CONF atualizado. Reinicie o CT: pct reboot $CTID"
