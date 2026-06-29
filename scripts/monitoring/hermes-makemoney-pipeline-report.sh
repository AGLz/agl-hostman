#!/usr/bin/env bash
# Relatório pipeline makemoney01 para Telegram (pós-crons matinais).
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
STATUS="${MAKEMONEY_DIR}/scripts/status.py"

if [[ ! -d "${MAKEMONEY_DIR}" ]]; then
  echo "ERRO: makemoney01 em falta: ${MAKEMONEY_DIR}" >&2
  exit 1
fi

if [[ -f "${STATUS}" ]]; then
  python3 "${STATUS}"
else
  echo "makemoney01: project OK, status.py em falta"
  ls -la "${MAKEMONEY_DIR}/data/opportunities/" 2>/dev/null | tail -5 || true
fi
