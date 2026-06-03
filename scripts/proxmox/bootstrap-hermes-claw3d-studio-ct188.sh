#!/usr/bin/env bash
# Sobe Claw3D Studio (hermes-office) no CT188.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-claw3d-studio-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/opt/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
COMPOSE_SRC="${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml"
LAN_IP="$(hostname -I | awk '{print $1}')"
TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
GATEWAY_WS="${HERMES_STUDIO_GATEWAY_URL:-ws://${LAN_IP}:18789}"

test -f "${COMPOSE_SRC}" || { echo "ERRO: falta ${COMPOSE_SRC}" >&2; exit 1; }

if [[ -z "${HERMES_STUDIO_ACCESS_TOKEN:-}" ]]; then
  if [[ -f "${HERMES_ROOT}/.env" ]]; then
    HERMES_STUDIO_ACCESS_TOKEN="$(grep -E '^HERMES_STUDIO_ACCESS_TOKEN=' "${HERMES_ROOT}/.env" | cut -d= -f2- || true)"
  fi
  if [[ -z "${HERMES_STUDIO_ACCESS_TOKEN:-}" ]]; then
    HERMES_STUDIO_ACCESS_TOKEN="$(openssl rand -hex 24)"
    echo "HERMES_STUDIO_ACCESS_TOKEN=${HERMES_STUDIO_ACCESS_TOKEN}" >> "${HERMES_ROOT}/.env"
    echo "==> Gerado HERMES_STUDIO_ACCESS_TOKEN em ${HERMES_ROOT}/.env"
  fi
fi

export HERMES_STUDIO_GATEWAY_URL="${GATEWAY_WS}"
export HERMES_STUDIO_ACCESS_TOKEN
export HERMES_STUDIO_HOST_PORT="${HERMES_STUDIO_HOST_PORT:-3003}"

cd "${HERMES_ROOT}"
install -m 0644 "${COMPOSE_SRC}" "${HERMES_ROOT}/docker-compose.aglz-quartet.ct188.yml"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/Dockerfile.claw3d-studio" "${HERMES_ROOT}/Dockerfile.claw3d-studio"

echo "=== Build + up hermes-claw3d-studio (gateway ${GATEWAY_WS}, host :${HERMES_STUDIO_HOST_PORT}) ==="
docker compose -f docker-compose.aglz-quartet.ct188.yml build hermes-claw3d-studio
docker compose -f docker-compose.aglz-quartet.ct188.yml up -d hermes-claw3d-studio

echo ""
echo "=== Smoke Studio :${HERMES_STUDIO_HOST_PORT} ==="
sleep 8
curl -sf -m20 -o /dev/null -w "HTTP %{http_code}\n" -H "Cookie: studio_access=${HERMES_STUDIO_ACCESS_TOKEN}" "http://127.0.0.1:${HERMES_STUDIO_HOST_PORT}/" || echo "WARN aguardar build/health"

echo ""
echo "Claw3D Studio:"
echo "  LAN:       http://${LAN_IP}:${HERMES_STUDIO_HOST_PORT}"
if [[ -n "${TS_IP}" ]]; then
  echo "  Tailscale: http://${TS_IP}:${HERMES_STUDIO_HOST_PORT}"
fi
echo "  Cookie:    studio_access=${HERMES_STUDIO_ACCESS_TOKEN}"
echo "  Nota: Langfuse usa 127.0.0.1:3000 — Studio publicado em :${HERMES_STUDIO_HOST_PORT}"
