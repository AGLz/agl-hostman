#!/usr/bin/env bash
# Deploy produção CT134: rolling update docker compose + opcional audit Dokploy API.
set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
CT134_PCT="${CT134_PCT:-134}"
IMAGE="${IMAGE:-harbor.aglz.io/agl-hostman-prod/hostman:prod-latest}"
IMAGE_TAG="${IMAGE_TAG:-prod-latest}"
FULL_IMAGE="${FULL_IMAGE:-${IMAGE%:*}:${IMAGE_TAG}}"
APP_ID="${DOKPLOY_APP_ID:-app_prod_123456789}"
DOKPLOY_URL="${DOKPLOY_URL:-http://192.168.0.180:3000/api}"
DOKPLOY_API_KEY="${DOKPLOY_API_KEY:-}"
COMPOSE_DIR="${CT134_COMPOSE_DIR:-/opt/agl-hostman-prod}"

if [[ -n "${DOKPLOY_API_KEY}" ]]; then
  curl -fsS -X POST "${DOKPLOY_URL%/}/trpc/application.deploy?batch=1" \
    -H "x-api-key: ${DOKPLOY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"0\":{\"json\":{\"applicationId\":\"${APP_ID}\"}}}" \
    >/dev/null 2>&1 || echo "Aviso: application.deploy Dokploy falhou (deploy SSH continua)" >&2
fi

ssh -o BatchMode=yes "${AGLSRV1}" "pct exec ${CT134_PCT} -- bash -s" <<EOF
set -euo pipefail
cd "${COMPOSE_DIR}"
if grep -q '^IMAGE=' .env 2>/dev/null; then
  sed -i "s|^IMAGE=.*|IMAGE=${FULL_IMAGE}|" .env
else
  echo "IMAGE=${FULL_IMAGE}" >> .env
fi
docker compose pull
docker compose up -d
curl -sf http://127.0.0.1/health/ || curl -sf http://127.0.0.1/up
EOF

echo "OK: CT134 deploy ${FULL_IMAGE}"
