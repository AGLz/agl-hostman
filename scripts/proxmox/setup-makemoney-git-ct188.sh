#!/usr/bin/env bash
# Configura GITHUB_TOKEN no Jarvis .env para push automático makemoney01.
# Uso (root no CT188): bash setup-makemoney-git-ct188.sh
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
ENV_FILE="${HERMES_ROOT}/data/.env"
MAKEMONEY_DIR="${MAKEMONEY_NFS:-/mnt/overpower/apps/dev/agl/makemoney01}"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "ERRO: gh autenticado em falta no host" >&2
  exit 1
fi

TOKEN="$(gh auth token)"
touch "${ENV_FILE}"
if grep -q '^GITHUB_TOKEN=' "${ENV_FILE}" 2>/dev/null; then
  sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${TOKEN}|" "${ENV_FILE}"
else
  echo "GITHUB_TOKEN=${TOKEN}" >>"${ENV_FILE}"
fi
chmod 600 "${ENV_FILE}" 2>/dev/null || true

git config --global --add safe.directory "${MAKEMONEY_DIR}" 2>/dev/null || true
echo "OK GITHUB_TOKEN em ${ENV_FILE} (push makemoney01)"
