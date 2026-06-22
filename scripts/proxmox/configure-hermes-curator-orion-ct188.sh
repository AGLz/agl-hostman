#!/usr/bin/env bash
# Integra Curator + Orion na agência Hermes CT188 (contentores dedicados).
#
# Pré-requisito: quartet configurado (configure-ct188-hermes-quartet.sh).
# Tokens opcionais em tokens.env: TELEGRAM_TOKEN_CURATOR, TELEGRAM_TOKEN_ORION
#
# Uso:
#   bash configure-hermes-curator-orion-ct188.sh /path/agl-hostman [/path/tokens.env]

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/agl-hostman [/path/tokens.env]}"
TOKENS_FILE="${2:-}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-1272190248}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: ${AGL_HOSTMAN}" >&2; exit 1; }
test -f "${HERMES_ROOT}/data/config.yaml" || { echo "ERRO: quartet não bootstrap — configure-ct188-hermes-quartet.sh primeiro" >&2; exit 1; }

if [[ -n "${TOKENS_FILE}" ]] && [[ -f "${TOKENS_FILE}" ]]; then
  chmod 600 "${TOKENS_FILE}" 2>/dev/null || true
  # shellcheck disable=SC1090
  source "${TOKENS_FILE}"
fi

write_telegram_env() {
  local agent="$1"
  local pdir="${HERMES_ROOT}/profiles/${agent}"
  local var="TELEGRAM_TOKEN_${agent^^}"
  local token="${!var:-}"
  install -d -m 0700 "${pdir}"
  if [[ -z "${token}" ]]; then
    echo "AVISO: ${var} ausente — ${agent} sem bot Telegram até tokens configurados"
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" 2>/dev/null && return 0
    token="PLACEHOLDER_${agent}"
  fi
  if [[ -f "${pdir}/.env" ]]; then
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" && \
      sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${token}|" "${pdir}/.env" || \
      echo "TELEGRAM_BOT_TOKEN=${token}" >>"${pdir}/.env"
    grep -q '^TELEGRAM_ALLOWED_USERS=' "${pdir}/.env" || \
      echo "TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}" >>"${pdir}/.env"
  else
    cat >"${pdir}/.env" <<EOF
TELEGRAM_BOT_TOKEN=${token}
TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}
API_SERVER_ENABLED=false
EOF
  fi
  chmod 600 "${pdir}/.env"
  chown -R 10000:10000 "${pdir}" 2>/dev/null || true
}

migrate_curator_legacy() {
  local legacy="${HERMES_ROOT}/data/profiles/curator"
  local target="${HERMES_ROOT}/profiles/curator"
  if [[ -d "${legacy}" ]] && [[ ! -f "${target}/config.yaml" ]]; then
    echo "=== Migrar curator data/profiles → profiles/curator ==="
    install -d -m 0700 "${target}"
    cp -a "${legacy}/." "${target}/"
    chown -R 10000:10000 "${target}" 2>/dev/null || true
  fi
}

echo "=== 1/5 Migrar curator legado ==="
migrate_curator_legacy

echo "=== 2/5 Bootstrap Curator ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/bootstrap-hermes-curator-profile-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 3/5 Bootstrap Orion ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/bootstrap-hermes-orion-profile-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 4/5 Telegram .env ==="
write_telegram_env curator
write_telegram_env orion

echo "=== 5/5 Compose up curator + orion ==="
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml" \
  "${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-curator hermes-orion 2>/dev/null || \
  docker compose -f docker-compose.aglz-quartet.yml up -d

echo ""
echo "=== Agency extensions ==="
docker compose -f docker-compose.aglz-quartet.yml ps hermes-curator hermes-orion 2>/dev/null || docker ps --filter name=agl-hermes-curator --filter name=agl-hermes-orion
echo "Doc: docs/HERMES-AGENCY-AGENTS.md"
echo "Bots (quando tokens): @hermes_jarvis_h_curator_bot @hermes_jarvis_h_orion_bot (nomes sugeridos — configurar no BotFather)"
