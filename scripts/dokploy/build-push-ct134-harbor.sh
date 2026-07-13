#!/usr/bin/env bash
# Build + push imagem produção CT134 para Harbor (runner com acesso à rede AGL).
# Uso: IMAGE_TAG=prod-abc1234 bash scripts/dokploy/build-push-ct134-harbor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.aglz.io}"
HARBOR_PROJECT="${HARBOR_PROJECT:-agl-hostman-prod}"
IMAGE_NAME="${IMAGE_NAME:-hostman}"
IMAGE_TAG="${IMAGE_TAG:-prod-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
FULL_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:prod-latest"

log() { printf '[build-push-ct134] %s\n' "$*"; }

# ponytail: Dockerfile usa RUN --mount=cache; requer BuildKit
export DOCKER_BUILDKIT=1

harbor_login() {
  local creds_file="${HARBOR_CREDS_FILE:-}"
  local tmp=""
  if [[ -z "${creds_file}" ]]; then
    tmp="$(mktemp)" || exit 1
    ssh -o BatchMode=yes "${AGLSRV1:-root@100.107.113.33}" \
      "pct exec 182 -- cat /root/robot-ct134-credentials.txt" > "${tmp}"
    creds_file="${tmp}"
  fi
  local user pass
  user="$(sed -n '1p' "${creds_file}" | tr -d '\r\n')"
  pass="$(sed -n '2p' "${creds_file}" | tr -d '\r\n')"
  [[ -n "${user}" && -n "${pass}" ]] || {
    echo "Erro: credenciais Harbor inválidas" >&2
    exit 1
  }
  # ponytail: printf evita expansão de $ no username robot$project+name
  printf '%s' "${pass}" | docker login "${HARBOR_REGISTRY}" -u "${user}" --password-stdin
  [[ -n "${tmp}" ]] && rm -f "${tmp}"
}

log "Build ${FULL_IMAGE}"
docker build --target production \
  -t "${FULL_IMAGE}" -t "${LATEST_IMAGE}" \
  -f "${REPO_ROOT}/src/Dockerfile" "${REPO_ROOT}/src"

harbor_login
log "Push ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"
docker push "${LATEST_IMAGE}"
log "OK: ${FULL_IMAGE} + prod-latest"
