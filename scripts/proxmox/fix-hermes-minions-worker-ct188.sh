#!/usr/bin/env bash
# Minions: rebuild (timeout worker 60s) + recreate + smoke.
set -euo pipefail

AGL_HOSTMAN="${1:-/opt/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
COMPOSE="${HERMES_ROOT}/docker-compose.aglz-quartet.yml"

cd "${HERMES_ROOT}"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/Dockerfile.minions" "${HERMES_ROOT}/Dockerfile.minions"

echo "=== Build hermes-minions (worker timeout 60s) ==="
docker compose -f "${COMPOSE}" build hermes-minions

echo "=== Recreate hermes-minions ==="
docker compose -f "${COMPOSE}" up -d --force-recreate hermes-minions

echo "=== Aguardar worker (até 90s) ==="
for i in $(seq 1 18); do
  if curl -sf -m5 http://127.0.0.1:6969/api/agent/defaults >/dev/null 2>&1; then
    echo "OK worker respondeu (${i}0s)"
    curl -sS http://127.0.0.1:6969/api/agent/defaults
    echo ""
    exit 0
  fi
  sleep 5
done
echo "WARN: worker timeout — ver docker logs agl-hermes-minions --tail 30"
exit 1
