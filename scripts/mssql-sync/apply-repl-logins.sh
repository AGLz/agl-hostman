#!/usr/bin/env bash
# Aplica login repl_mssql no CT610 (e VM620 se password SA disponível)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_ct610_sa

if [[ -z "${MSSQL_REPL_PASSWORD:-}" ]]; then
  echo "ERRO: definir MSSQL_REPL_PASSWORD em ${ENV_FILE}" >&2
  exit 1
fi

SQL_TEMPLATE="${SCRIPT_DIR}/create-repl-logins.sql"
SQL_TMP="$(mktemp)"
export MSSQL_REPL_PASSWORD
envsubst '${MSSQL_REPL_PASSWORD}' < "${SQL_TEMPLATE}" > "${SQL_TMP}"

echo "=== CT610 ==="
ct610_sqlcmd_stdin localhost < "${SQL_TMP}"

if [[ -n "${MSSQL_VM620_SA_PASSWORD:-}" ]]; then
  echo "=== VM620 ==="
  ct610_sqlcmd_stdin "${MSSQL_VM620_HOST}" "${MSSQL_VM620_SA_USER}" "${MSSQL_VM620_SA_PASSWORD}" < "${SQL_TMP}" || echo "WARN: falhou no VM620"
else
  echo "SKIP VM620: MSSQL_VM620_SA_PASSWORD não definido"
fi

rm -f "${SQL_TMP}"
echo "Concluído."
