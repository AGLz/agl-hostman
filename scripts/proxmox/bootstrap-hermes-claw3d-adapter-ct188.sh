#!/usr/bin/env bash
# Sobe o adaptador Claw3D (WS :18789 → Hermes HTTP :8642) no CT188.
#
# Uso (root no CT188, /opt/agl-hermes):
#   bash /opt/agl-hostman/scripts/proxmox/bootstrap-hermes-claw3d-adapter-ct188.sh /opt/agl-hostman
#
# Requer API_SERVER_KEY em /opt/agl-hermes/.env (compose lê via env_file do Jarvis).

set -euo pipefail

AGL_HOSTMAN="${1:-/opt/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
COMPOSE_SRC="${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml"

test -f "${COMPOSE_SRC}" || { echo "ERRO: falta ${COMPOSE_SRC}" >&2; exit 1; }
test -f "${HERMES_ROOT}/.env" || { echo "ERRO: falta ${HERMES_ROOT}/.env" >&2; exit 1; }

# Sincronizar chave API para data/.env (env_file Jarvis)
if [[ -x "${AGL_HOSTMAN}/scripts/proxmox/sync-hermes-api-server-key-ct188.sh" ]]; then
  bash "${AGL_HOSTMAN}/scripts/proxmox/sync-hermes-api-server-key-ct188.sh"
fi

export API_SERVER_KEY
API_SERVER_KEY="$(grep -E '^API_SERVER_KEY=' "${HERMES_ROOT}/.env" | head -1 | cut -d= -f2- | tr -d '\r')"
if [[ -z "${API_SERVER_KEY}" ]]; then
  echo "ERRO: API_SERVER_KEY vazia em ${HERMES_ROOT}/.env" >&2
  exit 1
fi

cd "${HERMES_ROOT}"
install -m 0644 "${COMPOSE_SRC}" "${HERMES_ROOT}/docker-compose.aglz-quartet.ct188.yml"
mkdir -p "${HERMES_ROOT}/claw3d-adapter"
cp -a "${AGL_HOSTMAN}/docker/hermes/claw3d-adapter/." "${HERMES_ROOT}/claw3d-adapter/"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/Dockerfile.claw3d-adapter" "${HERMES_ROOT}/Dockerfile.claw3d-adapter"

echo "=== Build + up hermes-claw3d-adapter ==="
docker compose -f docker-compose.aglz-quartet.ct188.yml build hermes-claw3d-adapter
docker compose -f docker-compose.aglz-quartet.ct188.yml up -d hermes-claw3d-adapter

echo ""
echo "=== Smoke WS adapter :18789 ==="
sleep 2
curl -sf -m5 http://127.0.0.1:18789 >/dev/null && echo "OK  http://127.0.0.1:18789 (upgrade WS no browser/Claw3D)" || echo "WARN http probe (adapter é WebSocket; usar hermes-desktop/Claw3D)"

LAN_IP="$(hostname -I | awk '{print $1}')"
TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
echo ""
echo "Claw3D / hermes-desktop Office:"
echo "  LAN:       ws://${LAN_IP}:18789"
if [[ -n "${TS_IP}" ]]; then
  echo "  Tailscale: ws://${TS_IP}:18789"
fi
echo "  Token:     API_SERVER_KEY (mesma do Remote HTTP :8642)"
echo "  Backend:   Hermes → http://127.0.0.1:8642 (dentro do stack Docker)"
