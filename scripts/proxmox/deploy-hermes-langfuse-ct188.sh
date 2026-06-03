#!/usr/bin/env bash
# Langfuse v3 mínimo no CT188 — observabilidade de custo/traces para Hermes Quartet.
#
# Uso (root no CT188):
#   bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/proxmox/deploy-hermes-langfuse-ct188.sh

set -euo pipefail

AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
LANGFUSE_ROOT="${LANGFUSE_ROOT:-/opt/agl-langfuse}"
ENV_FILE="${LANGFUSE_ROOT}/.env.langfuse"
COMPOSE_FILE="${LANGFUSE_ROOT}/langfuse-stack.yml"
KEYS_FILE="/root/.aglz-langfuse.env"

install -d -m 0755 "${LANGFUSE_ROOT}"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/langfuse-stack.yml" "${COMPOSE_FILE}"

gen_secret() {
  openssl rand -hex 32
}

gen_salt() {
  openssl rand -base64 24 | tr -d '\n'
}

gen_langfuse_key() {
  local prefix="$1"
  echo "${prefix}$(openssl rand -hex 16)"
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "=== Gerar ${ENV_FILE} ==="
  admin_pw="$(gen_secret)"
  pub_key="$(gen_langfuse_key pk-lf-)"
  sec_key="$(gen_langfuse_key sk-lf-)"
  cat >"${ENV_FILE}" <<EOF
NEXTAUTH_URL=http://127.0.0.1:3000
NEXTAUTH_SECRET=$(gen_secret)
SALT=$(gen_salt)
ENCRYPTION_KEY=$(gen_secret)
POSTGRES_PASSWORD=$(gen_secret)
CLICKHOUSE_PASSWORD=$(gen_secret)
REDIS_PASSWORD=$(gen_secret)
MINIO_ROOT_USER=langfuse
MINIO_ROOT_PASSWORD=$(gen_secret)
LANGFUSE_INIT_USER_PASSWORD=${admin_pw}
LANGFUSE_INIT_PROJECT_PUBLIC_KEY=${pub_key}
LANGFUSE_INIT_PROJECT_SECRET_KEY=${sec_key}
EOF
  chmod 600 "${ENV_FILE}"

  cat >"${KEYS_FILE}" <<EOF
HERMES_LANGFUSE_PUBLIC_KEY=${pub_key}
HERMES_LANGFUSE_SECRET_KEY=${sec_key}
HERMES_LANGFUSE_BASE_URL=http://langfuse-web:3000
HERMES_LANGFUSE_ENV=production
EOF
  chmod 600 "${KEYS_FILE}"
  echo "Admin Langfuse: admin@agl.local / password em ${ENV_FILE} (LANGFUSE_INIT_USER_PASSWORD)"
else
  chmod 600 "${ENV_FILE}"
fi

# Remover stack antiga se foi criada no projecto agl-hermes por engano
if [[ -f /opt/agl-hermes/langfuse-stack.yml ]]; then
  docker compose -f /opt/agl-hermes/langfuse-stack.yml --env-file /opt/agl-hermes/.env.langfuse down -v 2>/dev/null || true
fi

echo "=== Langfuse stack up (${LANGFUSE_ROOT}) ==="
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull -q
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d

echo "=== Aguardar UI (até ~120s) ==="
for i in $(seq 1 24); do
  if curl -sf "http://127.0.0.1:3000/api/public/health" >/dev/null 2>&1; then
    echo "Langfuse healthy."
    break
  fi
  sleep 5
  if [[ "${i}" -eq 24 ]]; then
    echo "WARN: health check falhou — logs: docker compose -f ${COMPOSE_FILE} logs langfuse-web" >&2
  fi
done

docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps

if [[ -f "${KEYS_FILE}" ]]; then
  echo ""
  echo "Keys Hermes: ${KEYS_FILE}"
  echo "Aplicar nos gateways:"
  echo "  bash ${AGL_HOSTMAN}/scripts/proxmox/apply-langfuse-hermes-env.sh"
fi
