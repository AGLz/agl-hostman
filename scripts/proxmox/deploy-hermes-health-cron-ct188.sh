#!/usr/bin/env bash
# Substitui cron LLM "Health Check" (truncamento/rate limit) por script --no-agent.
#
# Uso (root no CT188):
#   bash deploy-hermes-health-cron-ct188.sh
#   bash deploy-hermes-health-cron-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman --test-run

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
TEST_RUN="${2:-}"
JOB_OLD_ID="5fdb6a3c6674"
JOB_NAME="hermes-ct188-health-check"
SCRIPT_NAME="hermes-ct188-health-check.sh"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATA_SCRIPTS="${HERMES_ROOT}/data/scripts"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
CONTAINER="${HERMES_JARVIS_CONTAINER:-agl-hermes-jarvis}"
CRON_SCHEDULE="${CRON_SCHEDULE:-*/30 7-23 * * *}"

SRC="${AGL_HOSTMAN}/scripts/monitoring/${SCRIPT_NAME}"
DST="${DATA_SCRIPTS}/${SCRIPT_NAME}"

test -f "${SRC}" || { echo "ERRO: falta ${SRC}" >&2; exit 1; }

install -d -m 0755 -o "${HERMES_UID}" -g "${HERMES_GID}" "${DATA_SCRIPTS}"
sed 's/\r$//' "${SRC}" > "${DST}.tmp" && mv "${DST}.tmp" "${DST}"
chmod 0755 "${DST}"
chown "${HERMES_UID}:${HERMES_GID}" "${DST}"

python3 - "${HERMES_ROOT}/data/cron/jobs.json" "${JOB_OLD_ID}" <<'PY'
import json, sys
from pathlib import Path

path, old_id = sys.argv[1:3]
p = Path(path)
if not p.is_file():
    sys.exit(0)
data = json.loads(p.read_text())
jobs = data if isinstance(data, list) else data.get("jobs", [])
new_jobs = [j for j in jobs if j.get("id") != old_id and "Health Check Hermes" not in (j.get("name") or "")]
if isinstance(data, list):
    p.write_text(json.dumps(new_jobs, indent=2))
else:
    data["jobs"] = new_jobs
    p.write_text(json.dumps(data, indent=2))
print(f"OK removido job LLM antigo ({old_id}), restam {len(new_jobs)} jobs")
PY
chown "${HERMES_UID}:${HERMES_GID}" "${HERMES_ROOT}/data/cron/jobs.json" 2>/dev/null || true
chmod 644 "${HERMES_ROOT}/data/cron/jobs.json" 2>/dev/null || true

docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron list 2>/dev/null | grep -q "${JOB_NAME}" && \
  docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron remove "${JOB_NAME}" 2>/dev/null || true

docker exec -u hermes -e HERMES_HOME=/opt/data -e HERMES_ACCEPT_HOOKS=1 "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron create \
  --name "${JOB_NAME}" \
  --no-agent \
  --script "${SCRIPT_NAME}" \
  --deliver "telegram:${TELEGRAM_CHAT}" \
  "${CRON_SCHEDULE}"

chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_ROOT}/data/cron" 2>/dev/null || true
chmod 640 "${HERMES_ROOT}/data/cron/jobs.json" 2>/dev/null || true

docker restart "${CONTAINER}"
sleep 20

docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" /opt/hermes/.venv/bin/hermes cron list

if [[ "${TEST_RUN}" == "--test-run" ]]; then
  docker exec -u hermes -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron run "${JOB_NAME}" || true
fi

echo "OK health cron no-agent (${CRON_SCHEDULE})"
