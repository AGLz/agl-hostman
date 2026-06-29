#!/usr/bin/env bash
# Aplica TELEGRAM_TOKEN_ARGUS e reinicia gateway Argus (CT188).
#
# Pré-requisito: criar bot no BotFather (@hermes_jarvis_h_argus_bot sugerido)
# e adicionar ao ficheiro tokens:
#   TELEGRAM_TOKEN_ARGUS=<token>
#
# Uso (root no CT188):
#   bash setup-hermes-argus-telegram-ct188.sh
#   bash setup-hermes-argus-telegram-ct188.sh /root/.aglz-telegram-tokens.env

set -euo pipefail

TOKENS_FILE="${1:-/root/.aglz-telegram-tokens.env}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ARGUS_ENV="${HERMES_ROOT}/profiles/argus/.env"
ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-1272190248}"

[[ -f "${TOKENS_FILE}" ]] || { echo "ERRO: ${TOKENS_FILE} em falta" >&2; exit 1; }
chmod 600 "${TOKENS_FILE}" 2>/dev/null || true
# shellcheck disable=SC1090
source "${TOKENS_FILE}"

[[ -n "${TELEGRAM_TOKEN_ARGUS:-}" ]] || {
  echo "ERRO: TELEGRAM_TOKEN_ARGUS ausente em ${TOKENS_FILE}" >&2
  echo "Criar bot no BotFather e adicionar a linha TELEGRAM_TOKEN_ARGUS=..." >&2
  exit 1
}

install -d -m 0700 "${HERMES_ROOT}/profiles/argus"
if [[ -f "${ARGUS_ENV}" ]]; then
  grep -q '^TELEGRAM_BOT_TOKEN=' "${ARGUS_ENV}" && \
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_ARGUS}|" "${ARGUS_ENV}" || \
    echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_ARGUS}" >>"${ARGUS_ENV}"
  grep -q '^TELEGRAM_ALLOWED_USERS=' "${ARGUS_ENV}" || \
    echo "TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}" >>"${ARGUS_ENV}"
else
  cat >"${ARGUS_ENV}" <<EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_ARGUS}
TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}
API_SERVER_ENABLED=false
EOF
fi
chmod 600 "${ARGUS_ENV}"
chown 10000:10000 "${ARGUS_ENV}" 2>/dev/null || true

echo "OK ${ARGUS_ENV} actualizado"
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart hermes-argus 2>/dev/null || \
  docker restart agl-hermes-argus
echo "OK agl-hermes-argus reiniciado — enviar /new no Telegram se thread antiga"
