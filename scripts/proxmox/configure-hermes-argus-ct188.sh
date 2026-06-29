#!/usr/bin/env bash
# Integra Argus na agência Hermes CT188 (contentor dedicado).
#
# Pré-requisito: quartet + curator/orion configurados.
# Token opcional em tokens.env: TELEGRAM_TOKEN_ARGUS
#
# Uso:
#   bash configure-hermes-argus-ct188.sh /path/agl-hostman [/path/tokens.env]

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
  local agent="argus"
  local pdir="${HERMES_ROOT}/profiles/${agent}"
  local token="${TELEGRAM_TOKEN_ARGUS:-}"
  install -d -m 0700 "${pdir}"
  if [[ -z "${token}" ]]; then
    echo "AVISO: TELEGRAM_TOKEN_ARGUS ausente — argus sem bot Telegram até tokens configurados"
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" 2>/dev/null && return 0
    token="PLACEHOLDER_argus"
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

echo "=== 1/4 Bootstrap Argus ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/bootstrap-hermes-argus-profile-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 2/4 Second brain (7 agentes incl. argus) ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 3/4 Telegram .env ==="
write_telegram_env

echo "=== 4/4 Compose up hermes-argus ==="
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml" \
  "${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-argus 2>/dev/null || \
  docker compose -f docker-compose.aglz-quartet.yml up -d

echo ""
echo "=== Argus ==="
docker compose -f docker-compose.aglz-quartet.yml ps hermes-argus 2>/dev/null || docker ps --filter name=agl-hermes-argus
echo "Doc: docs/HERMES-AGENCY-AGENTS.md (secção Argus)"
echo "Bot sugerido: @hermes_jarvis_h_argus_bot (criar no BotFather + TELEGRAM_TOKEN_ARGUS)"
