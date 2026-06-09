#!/usr/bin/env bash
# Monitorização rápida sync MSSQL AGLSRV6
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_ct610_sa

echo "=== Proxmox ==="
ssh -o ConnectTimeout=10 "root@${PVE_HOST}" "qm status ${PVE_VM620_VMID} 2>/dev/null; pct status ${PVE_CT610_CTID}"

echo ""
echo "=== Portas 1433 ==="
ssh "root@${PVE_HOST}" "nc -zv -w 3 ${MSSQL_CT610_HOST} 1433 2>&1; nc -zv -w 3 ${MSSQL_VM620_HOST} 1433 2>&1"

echo ""
echo "=== CT610 SQL Agent ==="
pct610_exec "grep sqlagent /var/opt/mssql/mssql.conf 2>/dev/null || true"
pct610_exec "systemctl is-active mssql-server 2>/dev/null || true"

echo ""
echo "=== SymmetricDS (se deployado) ==="
pct610_exec "docker ps --filter name=symmetricds-mssql6 --format '{{.Status}}' 2>/dev/null || echo 'não instalado'"

echo ""
echo "=== Login repl_mssql (CT610) ==="
ct610_sqlcmd localhost "SELECT name, type_desc FROM sys.server_principals WHERE name='repl_mssql';"
