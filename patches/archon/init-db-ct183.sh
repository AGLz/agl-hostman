#!/usr/bin/env bash
# Aplica schema PostgreSQL do Archon v0.4 (000_combined.sql) no CT183.
# Idempotente — seguro reexecutar após upgrades se a doc Archon indicar novas migrations.
set -euo pipefail

COMPOSE_DIR="${ARCHON_COMPOSE_DIR:-/opt/archon}"
MIGRATION_FILE="${COMPOSE_DIR}/migrations/000_combined.sql"

require_root() {
    [[ "${EUID}" -eq 0 ]] || { echo "Executar como root." >&2; exit 1; }
}

main() {
    require_root
    [[ -f "${MIGRATION_FILE}" ]] || {
        echo "Falta ${MIGRATION_FILE} — copiar de patches/archon/migrations/" >&2
        exit 1
    }

    cd "${COMPOSE_DIR}"
    docker compose up -d postgres
    docker compose exec -T postgres pg_isready -U postgres -d remote_coding_agent

    docker compose exec -T postgres psql -U postgres -d remote_coding_agent -v ON_ERROR_STOP=1 \
        < "${MIGRATION_FILE}"

    echo "OK: schema aplicado"
    docker compose exec -T postgres psql -U postgres -d remote_coding_agent -c '\dt'
    curl -sf -o /dev/null -w "codebases HTTP %{http_code}\n" "http://127.0.0.1:${PORT:-3000}/api/codebases"
}

main "$@"
