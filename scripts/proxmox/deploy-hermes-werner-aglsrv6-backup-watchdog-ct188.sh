#!/usr/bin/env bash
# Deploy watchdog backups AGLSRV6 no Hermes Werner (CT188).
#
# Uso:
#   bash deploy-hermes-werner-aglsrv6-backup-watchdog-ct188.sh
#   bash deploy-hermes-werner-aglsrv6-backup-watchdog-ct188.sh /path/agl-hostman --test-run

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
TEST_RUN="${2:-}"
JOB_NAME="aglsrv6-backup-watchdog"
SCRIPT_NAME="aglsrv6-backup-watchdog.sh"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
WERNER_DIR="${HERMES_ROOT}/profiles/werner"
WERNER_SCRIPTS="${WERNER_DIR}/scripts"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
CRON_SCHEDULE="${CRON_SCHEDULE:-30 */2 * * *}"
CONTAINER="${HERMES_WERNER_CONTAINER:-agl-hermes-werner}"

SRC="${AGL_HOSTMAN}/scripts/monitoring/${SCRIPT_NAME}"
LIB="${AGL_HOSTMAN}/scripts/monitoring/hermes-notify-lib.sh"
DST="${WERNER_SCRIPTS}/${SCRIPT_NAME}"
WERNER_CFG="${WERNER_DIR}/config.yaml"

test -f "${SRC}" || { echo "ERRO: falta ${SRC}" >&2; exit 1; }
test -f "${LIB}" || { echo "ERRO: falta ${LIB}" >&2; exit 1; }
test -f "${WERNER_CFG}" || { echo "ERRO: falta ${WERNER_CFG}" >&2; exit 1; }

echo "=== 1/4 Scripts Werner ==="
install -d -m 0755 -o "${HERMES_UID}" -g "${HERMES_GID}" "${WERNER_SCRIPTS}"
for f in "${SCRIPT_NAME}" hermes-notify-lib.sh; do
  sed 's/\r$//' "${AGL_HOSTMAN}/scripts/monitoring/${f}" > "${WERNER_SCRIPTS}/${f}.tmp"
  mv "${WERNER_SCRIPTS}/${f}.tmp" "${WERNER_SCRIPTS}/${f}"
  chmod 0755 "${WERNER_SCRIPTS}/${f}"
  chown "${HERMES_UID}:${HERMES_GID}" "${WERNER_SCRIPTS}/${f}"
done

echo "=== 2/4 cron_mode=allow ==="
python3 - "${WERNER_CFG}" <<'PY'
import sys
from pathlib import Path
import yaml
path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
cfg.setdefault("approvals", {})["cron_mode"] = "allow"
path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("OK")
PY

echo "=== 3/4 Cron ${JOB_NAME} (${CRON_SCHEDULE}) ==="
docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron list 2>/dev/null | grep -q "${JOB_NAME}" && \
  docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron remove "${JOB_NAME}" 2>/dev/null || true

docker exec -e HERMES_HOME=/opt/data -e HERMES_ACCEPT_HOOKS=1 "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron create \
  --name "${JOB_NAME}" \
  --no-agent \
  --script "${SCRIPT_NAME}" \
  --deliver "telegram:${TELEGRAM_CHAT}" \
  "${CRON_SCHEDULE}"

chown -R "${HERMES_UID}:${HERMES_GID}" "${WERNER_DIR}/cron" 2>/dev/null || true
chmod 600 "${WERNER_DIR}/cron/jobs.json" 2>/dev/null || true

echo "=== 4/4 Restart Werner ==="
docker restart "${CONTAINER}"
sleep 20
docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" /opt/hermes/.venv/bin/hermes cron list

if [[ "${TEST_RUN}" == "--test-run" ]]; then
  docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron run "${JOB_NAME}" || true
fi

echo "OK ${JOB_NAME} — schedule ${CRON_SCHEDULE}"
