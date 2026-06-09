#!/usr/bin/env bash
# Activa SQL Server Agent no CT610 (mssql6)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_ct610_sa

echo "A verificar sqlagent.enabled..."
current="$(pct610_exec "grep -E '^sqlagent.enabled' /var/opt/mssql/mssql.conf 2>/dev/null || echo 'sqlagent.enabled = false'")"
echo "  Actual: ${current}"

if echo "${current}" | grep -q 'true'; then
  echo "SQL Agent já activo."
  pct610_exec "systemctl is-active mssql-server || true"
  exit 0
fi

echo "A activar sqlagent.enabled=true..."
pct610_exec "/opt/mssql/bin/mssql-conf set sqlagent.enabled true"
echo "A reiniciar mssql-server (pode demorar ~30s)..."
pct610_exec "systemctl restart mssql-server"
sleep 15

pct610_exec "grep sqlagent /var/opt/mssql/mssql.conf"
pct610_exec "systemctl is-active mssql-server"
echo "OK: SQL Agent activado no CT610."
