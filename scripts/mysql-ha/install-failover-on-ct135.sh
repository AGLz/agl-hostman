#!/usr/bin/env bash
# Reason: instalar mysql-failover no CT135 (slave) a partir do repo — correr no host com `pct` (ex.: AGLSRV5).
set -euo pipefail

CT_ID="${CT_ID:-135}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pct >/dev/null 2>&1; then
  echo "Correr como root no Proxmox com acesso ao CT${CT_ID} (ex.: ssh root@100.119.223.113)." >&2
  exit 1
fi

echo "A copiar mysql-failover para CT${CT_ID}..."
pct exec "${CT_ID}" -- mkdir -p /etc/mysql-ha /usr/local/bin
pct push "${CT_ID}" "${SCRIPT_DIR}/mysql-failover.sh" /usr/local/bin/mysql-failover.sh
pct push "${CT_ID}" "${SCRIPT_DIR}/mysql-failover.conf" /etc/mysql-ha/mysql-failover.conf
pct exec "${CT_ID}" -- chmod 755 /usr/local/bin/mysql-failover.sh
pct exec "${CT_ID}" -- chmod 600 /etc/mysql-ha/mysql-failover.conf
pct exec "${CT_ID}" -- mkdir -p /var/lib/mysql-ha
pct exec "${CT_ID}" -- touch /var/log/mysql-failover.log
pct exec "${CT_ID}" -- chmod 644 /var/log/mysql-failover.log

echo "Feito. Editar segredos no CT: pct exec ${CT_ID} -- nano /etc/mysql-ha/mysql-failover.conf"
echo "Teste: pct exec ${CT_ID} -- /usr/local/bin/mysql-failover.sh"
echo "Cron (root no CT): */1 * * * * /usr/local/bin/mysql-failover.sh >> /var/log/mysql-failover.log 2>&1"
echo "Remover cron equivalente no CT235 se existir."
