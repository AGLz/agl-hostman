#!/usr/bin/env bash
# Configura CT134 produção no Dokploy via API tRPC (CT180).
# Ver scripts/dokploy/setup-ct134-production.md para detalhes UI.
#
# Uso:
#   DOKPLOY_URL=http://192.168.0.180:3000/api \
#   DOKPLOY_API_KEY=... \
#   bash scripts/dokploy/setup-ct134-via-api.sh
set -euo pipefail

DOKPLOY_URL="${DOKPLOY_URL:-http://192.168.0.180:3000/api}"
DOKPLOY_API_KEY="${DOKPLOY_API_KEY:-}"
AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
ORG_ID="${DOKPLOY_ORG_ID:-3MfNHnTdnNsZveKkjKsMy}"
ENV_PROD="${DOKPLOY_ENV_PROD:-w7EumvSDLYorq1fjruuSR}"
APP_ID="${DOKPLOY_APP_ID:-app_prod_123456789}"
CT134_TS_IP="${CT134_TS_IP:-100.109.204.59}"
COMPOSE_FILE="${COMPOSE_FILE:-docker/dokploy/docker-compose.ct134.production.yml}"
OUT="${DOKPLOY_SETUP_OUT:-/tmp/dokploy-ct134-ids.json}"

[[ -n "${DOKPLOY_API_KEY}" ]] || { echo "Erro: DOKPLOY_API_KEY obrigatório" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOKPLOY_URL DOKPLOY_API_KEY ORG_ID ENV_PROD APP_ID CT134_TS_IP COMPOSE_FILE ROOT OUT AGLSRV1

python3 "${ROOT}/scripts/dokploy/setup-ct134-via-api.py"
echo "OK: IDs em ${OUT}"
