#!/usr/bin/env bash
# Integra Composio (Integrations Operator) na agência Hermes CT188.
#
# Pré-requisito: quartet + curator/orion/argus configurados.
# Token opcional: TELEGRAM_TOKEN_COMPOSIO em tokens.env
# OAuth Composio (após deploy): HERMES_CONTAINER=agl-hermes-composio bash composio-oauth-hermes-ct188.sh configure
#
# Uso:
#   bash configure-hermes-composio-ct188.sh /path/agl-hostman [/path/tokens.env]

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/agl-hostman [/path/tokens.env]}"
TOKENS_FILE="${2:-}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-1272190248}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: ${AGL_HOSTMAN}" >&2; exit 1; }
test -f "${HERMES_ROOT}/data/config.yaml" || {
  echo "ERRO: quartet não bootstrap — configure-ct188-hermes-quartet.sh primeiro" >&2
  exit 1
}

if [[ -n "${TOKENS_FILE}" ]] && [[ -f "${TOKENS_FILE}" ]]; then
  chmod 600 "${TOKENS_FILE}" 2>/dev/null || true
  # shellcheck disable=SC1090
  source "${TOKENS_FILE}"
fi

write_telegram_env() {
  local agent="composio"
  local pdir="${HERMES_ROOT}/profiles/${agent}"
  local token="${TELEGRAM_TOKEN_COMPOSIO:-}"
  install -d -m 0700 "${pdir}"
  if [[ -z "${token}" ]]; then
    echo "AVISO: TELEGRAM_TOKEN_COMPOSIO ausente — composio sem bot Telegram até tokens configurados"
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" 2>/dev/null && return 0
    token="PLACEHOLDER_composio"
  fi
  if [[ -f "${pdir}/.env" ]]; then
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" && \
      sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${token}|" "${pdir}/.env" || \
      echo "TELEGRAM_BOT_TOKEN=${token}" >>"${pdir}/.env"
    grep -q '^TELEGRAM_ALLOWED_USERS=' "${pdir}/.env" || \
      echo "TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}" >>"${pdir}/.env"
    grep -q '^API_SERVER_ENABLED=' "${pdir}/.env" || \
      echo "API_SERVER_ENABLED=false" >>"${pdir}/.env"
  else
    cat >"${pdir}/.env" <<EOF
TELEGRAM_BOT_TOKEN=${token}
TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}
API_SERVER_ENABLED=false
WIKI_PATH=/opt/llm-wiki/wiki
EOF
  fi
  chmod 600 "${pdir}/.env"
  chown -R 10000:10000 "${pdir}" 2>/dev/null || true
}

echo "=== 1/4 Bootstrap Composio ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/bootstrap-hermes-composio-profile-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 2/4 Second brain (9 agentes incl. composio) ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 3/4 Telegram .env ==="
write_telegram_env

echo "=== 4/4 Compose up hermes-composio ==="
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml" \
  "${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-composio 2>/dev/null || \
  docker compose -f docker-compose.aglz-quartet.yml up -d

echo ""
echo "=== Composio ==="
docker compose -f docker-compose.aglz-quartet.yml ps hermes-composio 2>/dev/null || docker ps --filter name=agl-hermes-composio
echo "Doc: docs/HERMES-AGENCY-AGENTS.md (secção Composio)"
echo "Bot sugerido: @hermes_jarvis_h_composio_bot (BotFather + TELEGRAM_TOKEN_COMPOSIO)"
echo "OAuth MCP: HERMES_CONTAINER=agl-hermes-composio HERMES_DATA=/opt/agl-hermes/profiles/composio \\"
echo "  bash ${AGL_HOSTMAN}/scripts/proxmox/composio-oauth-hermes-ct188.sh configure"
