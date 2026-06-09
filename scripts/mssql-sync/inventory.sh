#!/usr/bin/env bash
# Inventário SQL CT610 (+ VM620 se credenciais disponíveis)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_ct610_sa
load_mssql_sync_env

echo "=== CT610 (${MSSQL_CT610_HOST}) ==="
ct610_sqlcmd localhost "SELECT @@VERSION"
ct610_sqlcmd localhost "SELECT name, recovery_model_desc, state_desc FROM sys.databases WHERE database_id > 4 ORDER BY name"

echo ""
echo "=== VM620 (${MSSQL_VM620_HOST}) ==="
if [[ -n "${MSSQL_VM620_SA_PASSWORD:-}" ]]; then
  pct610_exec "bash -c 'SQLCMDPASSWORD=\"${MSSQL_VM620_SA_PASSWORD}\" /opt/mssql-tools18/bin/sqlcmd -S ${MSSQL_VM620_HOST} -U ${MSSQL_VM620_SA_USER} -C -Q \"SELECT @@VERSION; SELECT name FROM sys.databases WHERE database_id>4 ORDER BY name\" -W -l 10'" || true
else
  echo "SKIP: MSSQL_VM620_SA_PASSWORD não definido em mssql-sync.env"
fi

echo ""
echo "=== Rede (man6) ==="
ssh -o ConnectTimeout=10 "root@${PVE_HOST}" "nc -zv -w 3 ${MSSQL_CT610_HOST} 1433 2>&1; nc -zv -w 3 ${MSSQL_VM620_HOST} 1433 2>&1"
