#!/usr/bin/env bash
# Bootstrap CT134 agl-hostman — Docker, login Harbor, stack produção (pull-only).
# Executar DENTRO do CT134 como root (ou via pct exec 134).
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/agl-hostman-prod}"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.aglz.io}"
HARBOR_PROJECT="${HARBOR_PROJECT:-agl-hostman-prod}"
IMAGE_NAME="${IMAGE_NAME:-hostman}"
COMPOSE_FILE="${COMPOSE_FILE:-/opt/agl-hostman-prod/docker-compose.yml}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates gnupg jq

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli docker-compose-plugin
fi

systemctl enable --now docker

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled
  echo "AVISO: correr 'tailscale up' com auth key AGL" >&2
fi

mkdir -p "${DEPLOY_DIR}"
if [[ -f "${COMPOSE_SOURCE:-}" ]]; then
  cp "${COMPOSE_SOURCE}" "${COMPOSE_FILE}"
elif [[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docker/dokploy/docker-compose.ct134.production.yml ]]; then
  cp /mnt/overpower/apps/dev/agl/agl-hostman/docker/dokploy/docker-compose.ct134.production.yml "${COMPOSE_FILE}"
else
  echo "ERRO: docker-compose.ct134.production.yml não encontrado — copiar manualmente para ${COMPOSE_FILE}" >&2
  exit 1
fi

ENV_EXAMPLE="${ENV_EXAMPLE:-}"
if [[ -z "${ENV_EXAMPLE}" && -f /mnt/overpower/apps/dev/agl/agl-hostman/docker/dokploy/env.ct134.example ]]; then
  ENV_EXAMPLE=/mnt/overpower/apps/dev/agl/agl-hostman/docker/dokploy/env.ct134.example
fi
if [[ ! -f "${DEPLOY_DIR}/.env" ]]; then
  if [[ -f "${DEPLOY_DIR}/.env.example" ]]; then
    cp "${DEPLOY_DIR}/.env.example" "${DEPLOY_DIR}/.env"
  elif [[ -n "${ENV_EXAMPLE}" && -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${DEPLOY_DIR}/.env"
  else
    cat > "${DEPLOY_DIR}/.env" <<ENV
APP_ENV=production
APP_DEBUG=false
APP_URL=https://ah.aglz.io
IMAGE=${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:prod-latest
DB_HOST=192.168.0.149
DB_PORT=5432
DB_DATABASE=agl_hostman_prod
DB_USERNAME=agl_hostman
DB_PASSWORD=change-me
REDIS_HOST=192.168.0.137
REDIS_PORT=6379
REDIS_PASSWORD=change-me
ENV
    echo "AVISO: editar ${DEPLOY_DIR}/.env antes de arrancar" >&2
  fi
fi

if [[ -n "${HARBOR_USERNAME:-}" && -n "${HARBOR_PASSWORD:-}" ]]; then
  echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_REGISTRY}" -u "${HARBOR_USERNAME}" --password-stdin
fi

cd "${DEPLOY_DIR}"
docker compose pull || echo "AVISO: pull Harbor falhou — projecto/imagem pode ainda não existir (Fase 2)" >&2
if ! docker compose up -d; then
  echo "AVISO: stack não arrancou (normal até imagem prod existir no Harbor)" >&2
fi

echo ""
echo "=== CT134 bootstrap concluído ==="
echo "  Deploy dir: ${DEPLOY_DIR}"
echo "  Próximo: registar CT134 como Server no Dokploy (CT180) — scripts/dokploy/setup-ct134-production.md"
echo "  Health: curl -sf http://127.0.0.1/health || curl -sf http://127.0.0.1:8080/health"
