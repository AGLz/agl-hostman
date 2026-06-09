#!/usr/bin/env bash
# Funções partilhadas — sync MSSQL AGLSRV6
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${MSSQL_SYNC_ENV:-${REPO_ROOT}/config/mssql-sync/mssql-sync.env}"
ALD_SYS8_ENV="${ALD_SYS8_ENV:-/mnt/overpower/apps/dev/ald/ald-sys8/src/.env}"

load_mssql_sync_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a && source "${ENV_FILE}" && set +a
  fi

  if [[ -z "${MSSQL_CT610_SA_PASSWORD:-}" && -f "${ALD_SYS8_ENV}" ]]; then
    MSSQL_CT610_SA_PASSWORD="$(grep -E '^DB_PASSWORD_SYS=' "${ALD_SYS8_ENV}" | cut -d= -f2- | tr -d '"')"
    export MSSQL_CT610_SA_PASSWORD
  fi

  if [[ -z "${MSSQL_CT610_SA_USER:-}" ]]; then
    export MSSQL_CT610_SA_USER=sa
  fi

  : "${MSSQL_CT610_HOST:=192.168.0.110}"
  : "${MSSQL_CT610_PORT:=1433}"
  : "${MSSQL_VM620_HOST:=192.168.0.200}"
  : "${MSSQL_VM620_PORT:=1433}"
  : "${MSSQL_VM620_SA_USER:=sa}"
  : "${MSSQL_REPL_USER:=repl_mssql}"
  : "${PVE_HOST:=100.98.108.66}"
  : "${PVE_VM620_VMID:=620}"
  : "${PVE_CT610_CTID:=610}"
}

require_ct610_sa() {
  load_mssql_sync_env
  if [[ -z "${MSSQL_CT610_SA_PASSWORD:-}" ]]; then
    echo "ERRO: MSSQL_CT610_SA_PASSWORD vazio. Definir em ${ENV_FILE} ou usar ald-sys8/src/.env" >&2
    exit 1
  fi
}

pct610_exec() {
  ssh -o ConnectTimeout=15 "root@${PVE_HOST}" "pct exec ${PVE_CT610_CTID} -- $*"
}

ct610_sqlcmd() {
  local server="${1:-localhost}"
  shift
  local query="$*"
  pct610_exec "bash -c '/opt/mssql-tools18/bin/sqlcmd -S ${server} -U ${MSSQL_CT610_SA_USER} -P \"${MSSQL_CT610_SA_PASSWORD}\" -C -Q \"${query}\" -W'"
}
