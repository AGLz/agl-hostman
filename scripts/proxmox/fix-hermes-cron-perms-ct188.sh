#!/usr/bin/env bash
# Corrige permissões de cron Hermes no CT188 (UID 10000 = hermes no contentor).
# jobs.json escrito como root no host quebra o scheduler do gateway.
#
# Uso (root no CT188):
#   bash fix-hermes-cron-perms-ct188.sh
#   bash fix-hermes-cron-perms-ct188.sh --install-cron   # corre a cada 15 min

set -euo pipefail

HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
CRON_DIR="${HERMES_ROOT}/data/cron"
JOBS_FILE="${CRON_DIR}/jobs.json"
INSTALL_CRON="${1:-}"

fix_once() {
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CRON_DIR}"
  if [[ -f "${JOBS_FILE}" ]]; then
    chown "${HERMES_UID}:${HERMES_GID}" "${JOBS_FILE}"
    chmod 600 "${JOBS_FILE}"
  fi
  if [[ -d "${CRON_DIR}/output" ]]; then
    chown -R "${HERMES_UID}:${HERMES_GID}" "${CRON_DIR}/output"
  fi
  echo "OK cron perms: ${JOBS_FILE} ($(stat -c '%U:%G %a' "${JOBS_FILE}" 2>/dev/null || echo missing))"

  # agent.log criado como root (ex. docker exec -u root) quebra escrita do gateway
  for logs_dir in "${HERMES_ROOT}/data/logs" "${HERMES_ROOT}/profiles"/*/logs; do
    [[ -d "${logs_dir}" ]] || continue
    chown -R "${HERMES_UID}:${HERMES_GID}" "${logs_dir}" 2>/dev/null || true
    find "${logs_dir}" -maxdepth 1 -type f -name '*.log' -exec chmod 644 {} \; 2>/dev/null || true
  done
  echo "OK logs perms (UID ${HERMES_UID})"
}

fix_once

if [[ "${INSTALL_CRON}" == "--install-cron" ]]; then
  SCRIPT_PATH="$(readlink -f "$0")"
  LINE="*/15 * * * * root ${SCRIPT_PATH} >/var/log/hermes-cron-perms.log 2>&1"
  if ! grep -qF "${SCRIPT_PATH}" /etc/cron.d/hermes-cron-perms 2>/dev/null; then
    printf '%s\n' "${LINE}" > /etc/cron.d/hermes-cron-perms
    chmod 644 /etc/cron.d/hermes-cron-perms
    echo "OK instalado /etc/cron.d/hermes-cron-perms (cada 15 min)"
  else
    echo "OK cron.d já instalado"
  fi
fi
