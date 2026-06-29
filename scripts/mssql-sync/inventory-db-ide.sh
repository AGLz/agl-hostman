#!/usr/bin/env bash
# Fase 0: inventário DB_IDE_Associacao em CT610 e VM620
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_both_nodes
load_mssql_sync_env

SQL_FILE="${SCRIPT_DIR}/sql/db-ide-inventory.sql"
OUT_DIR="${REPO_ROOT}/docs/maint/reconcile"
DATE_STAMP="$(date +%Y%m%d)"
mkdir -p "${OUT_DIR}"

run_inventory() {
  local node="$1"
  local outfile="${OUT_DIR}/db-ide-inventory-${node}-${DATE_STAMP}.txt"

  echo "=== ${node} (${MSSQL_IDE_DATABASE}) ==="
  if [[ "${node}" == "ct610" ]]; then
    run_sql_file_ct610 "${SQL_FILE}" | tee "${outfile}"
  else
    run_sql_file_vm620 "${SQL_FILE}" | tee "${outfile}"
  fi
  echo "Gravado: ${outfile}"
}

echo "Verificar bases existem..."
CHECK_DB="$(mktemp)"
trap 'rm -f "${CHECK_DB}"' EXIT
cat > "${CHECK_DB}" <<EOF
SET NOCOUNT ON;
SELECT name FROM sys.databases WHERE name = N'${MSSQL_IDE_DATABASE}';
EOF
echo -n "CT610: "
run_sql_file_ct610 "${CHECK_DB}" | tr -d '\r' | tail -3
echo -n "VM620: "
run_sql_file_vm620 "${CHECK_DB}" | tr -d '\r' | tail -3

run_inventory ct610
run_inventory vm620

echo ""
echo "Próximo passo: ./scripts/mssql-sync/compare-rowcounts-db-ide.sh"
