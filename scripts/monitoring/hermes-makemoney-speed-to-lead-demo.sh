#!/usr/bin/env bash
# Demo Speed-to-Lead para Telegram / briefing Hermes (sem LLM se DRY_RUN=1).
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
CLIENT="${SPEED_TO_LEAD_CLIENT:-demo-clinica}"
MESSAGE="${SPEED_TO_LEAD_MESSAGE:-Quanto custa uma limpeza? Vocês atendem hoje à tarde?}"
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -d "${MAKEMONEY_DIR}/scripts" ]]; then
  echo "ERRO: makemoney01 em falta: ${MAKEMONEY_DIR}" >&2
  exit 1
fi

cd "${MAKEMONEY_DIR}"
set -a
[[ -f .env ]] && source .env
set +a

args=(--client "${CLIENT}" --message "${MESSAGE}")
[[ "${DRY_RUN}" == "1" ]] && args+=(--dry-run)

echo "⚡ Speed-to-Lead — cliente: ${CLIENT}"
python3 scripts/lead_reply.py "${args[@]}"
