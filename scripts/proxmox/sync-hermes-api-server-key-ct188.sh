#!/usr/bin/env bash
# Garante API_SERVER_KEY em /opt/agl-hermes/data/.env (env_file do Jarvis).
# A chave canónica vive em /opt/agl-hermes/.env (compose); o desktop precisa da mesma.
#
# Uso (root no CT188):
#   bash sync-hermes-api-server-key-ct188.sh [--restart-jarvis]

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ROOT_ENV="${HERMES_ROOT}/.env"
DATA_ENV="${HERMES_ROOT}/data/.env"
RESTART=0

if [[ "${1:-}" == "--restart-jarvis" ]]; then
  RESTART=1
fi

for f in "${ROOT_ENV}" "${DATA_ENV}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERRO: falta ${f}" >&2
    exit 1
  fi
done

KEY="$(grep -E '^API_SERVER_KEY=' "${ROOT_ENV}" | head -1 | cut -d= -f2- | tr -d '\r' || true)"
if [[ -z "${KEY}" ]]; then
  KEY="$(openssl rand -hex 16)"
  echo "API_SERVER_KEY=${KEY}" >>"${ROOT_ENV}"
  echo "OK: gerada nova API_SERVER_KEY em ${ROOT_ENV}"
fi

grep -q '^API_SERVER_ENABLED=' "${DATA_ENV}" || echo 'API_SERVER_ENABLED=true' >>"${DATA_ENV}"
grep -q '^API_SERVER_HOST=' "${DATA_ENV}" || echo 'API_SERVER_HOST=0.0.0.0' >>"${DATA_ENV}"

if grep -q '^API_SERVER_KEY=' "${DATA_ENV}"; then
  sed -i "s|^API_SERVER_KEY=.*|API_SERVER_KEY=${KEY}|" "${DATA_ENV}"
else
  echo "API_SERVER_KEY=${KEY}" >>"${DATA_ENV}"
fi

echo "OK: API_SERVER_KEY sincronizada em ${DATA_ENV}"
echo "    (mostrar: grep ^API_SERVER_KEY= ${ROOT_ENV})"

if [[ "${RESTART}" -eq 1 ]]; then
  cd "${HERMES_ROOT}"
  docker compose -f docker-compose.aglz-quartet.ct188.yml up -d hermes-jarvis
  echo "OK: hermes-jarvis reiniciado"
fi
