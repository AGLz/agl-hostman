#!/usr/bin/env bash
# Timezone America/Sao_Paulo (GMT-3) — idempotente, dentro do CT (root).
# Evita timedatectl quando dbus/timedated falha em LXC.

set -euo pipefail

TZ_NAME="${TZ_NAME:-America/Sao_Paulo}"
ZONE_FILE="/usr/share/zoneinfo/${TZ_NAME}"

if [[ ! -f "${ZONE_FILE}" ]]; then
    echo "Erro: zona ${TZ_NAME} não encontrada em ${ZONE_FILE}" >&2
    exit 1
fi

rm -f /etc/localtime
ln -sf "${ZONE_FILE}" /etc/localtime
echo "${TZ_NAME}" >/etc/timezone

if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone "${TZ_NAME}" 2>/dev/null || true
fi

echo "OK timezone: $(date '+%Y-%m-%d %H:%M:%S %Z') ($(readlink -f /etc/localtime))"
