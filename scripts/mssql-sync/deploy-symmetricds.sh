#!/usr/bin/env bash
# Deploy SymmetricDS no CT610 via docker compose
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

load_mssql_sync_env
COMPOSE_DIR="${REPO_ROOT}/docker/mssql-sync"
REMOTE_DIR="/opt/mssql-sync"

echo "A sincronizar ficheiros para CT610..."
ssh "root@${PVE_HOST}" "pct exec ${PVE_CT610_CTID} -- mkdir -p ${REMOTE_DIR}/engines"
tar -C "${COMPOSE_DIR}" -cf - . | ssh "root@${PVE_HOST}" "pct exec ${PVE_CT610_CTID} -- tar -C ${REMOTE_DIR} -xf -"

echo "A iniciar SymmetricDS..."
ssh "root@${PVE_HOST}" "pct exec ${PVE_CT610_CTID} -- bash -c 'cd ${REMOTE_DIR} && docker compose up -d'"

echo "SymmetricDS: http://${MSSQL_CT610_HOST}:${SYMMETRICDS_HTTP_PORT:-31415}/"
