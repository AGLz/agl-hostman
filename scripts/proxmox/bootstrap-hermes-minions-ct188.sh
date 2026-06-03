#!/usr/bin/env bash
# Sobe Minions (Mission Control Kanban) no CT188 — partilha /opt/data com Jarvis.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-minions-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/opt/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
COMPOSE_SRC="${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml"

test -f "${COMPOSE_SRC}" || { echo "ERRO: falta ${COMPOSE_SRC}" >&2; exit 1; }

cd "${HERMES_ROOT}"
install -m 0644 "${COMPOSE_SRC}" "${HERMES_ROOT}/docker-compose.aglz-quartet.ct188.yml"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/Dockerfile.minions" "${HERMES_ROOT}/Dockerfile.minions"
mkdir -p "${HERMES_ROOT}/minions/data" "${HERMES_ROOT}/minions/workspace" "${HERMES_ROOT}/minions/logs" "${HERMES_ROOT}/minions/skills"
chmod -R 777 "${HERMES_ROOT}/minions" 2>/dev/null || true

echo "=== Build + up hermes-minions ==="
docker compose -f docker-compose.aglz-quartet.ct188.yml build hermes-minions
docker compose -f docker-compose.aglz-quartet.ct188.yml up -d hermes-minions

echo ""
echo "=== Smoke Minions :6969 ==="
sleep 5
curl -sf -m15 http://127.0.0.1:6969/ >/dev/null && echo "OK  http://127.0.0.1:6969" || echo "WARN aguardar healthcheck (worker Hermes)"

LAN_IP="$(hostname -I | awk '{print $1}')"
TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
echo ""
echo "Minions Mission Control:"
echo "  LAN:       http://${LAN_IP}:6969"
if [[ -n "${TS_IP}" ]]; then
  echo "  Tailscale: http://${TS_IP}:6969"
fi
