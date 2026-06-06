#!/usr/bin/env bash
# Instala monitorização diária AGLSRV1 no Hermes Werner (CT188):
#   script em profiles/werner/scripts + cron --no-agent → Telegram
#
# Uso (root no CT188 ou via pct exec 188):
#   bash deploy-hermes-werner-aglsrv1-monitor-ct188.sh
#   bash deploy-hermes-werner-aglsrv1-monitor-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
#   bash deploy-hermes-werner-aglsrv1-monitor-ct188.sh /path/agl-hostman --test-run
#
# Pré-requisitos:
#   - agl-hermes-werner a correr
#   - SSH do contentor Werner → AGLSRV1 (Tailscale 100.107.113.33)
#   - TELEGRAM_BOT_TOKEN em profiles/werner/.env

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
TEST_RUN="${2:-}"
JOB_NAME="aglsrv1-qpi-numa-daily"
SCRIPT_NAME="aglsrv1-qpi-numa-daily.sh"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
WERNER_DIR="${HERMES_ROOT}/profiles/werner"
WERNER_SCRIPTS="${WERNER_DIR}/scripts"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 8 * * *}"
CONTAINER="${HERMES_WERNER_CONTAINER:-agl-hermes-werner}"

SRC="${AGL_HOSTMAN}/scripts/monitoring/${SCRIPT_NAME}"
DST="${WERNER_SCRIPTS}/${SCRIPT_NAME}"
WERNER_CFG="${WERNER_DIR}/config.yaml"

test -f "${SRC}" || { echo "ERRO: falta ${SRC}" >&2; exit 1; }
test -f "${WERNER_CFG}" || { echo "ERRO: falta ${WERNER_CFG} — bootstrap Hermes primeiro" >&2; exit 1; }

echo "=== 1/4 Instalar script em ${DST} ==="
# Hermes resolve --script em ${HERMES_HOME}/scripts (= profiles/werner/scripts no host)
install -d -m 0755 -o "${HERMES_UID}" -g "${HERMES_GID}" "${WERNER_SCRIPTS}"
sed 's/\r$//' "${SRC}" > "${DST}.tmp" && mv "${DST}.tmp" "${DST}"
chmod 0755 "${DST}"
chown "${HERMES_UID}:${HERMES_GID}" "${DST}"

echo "=== 2/4 approvals.cron_mode=allow (Werner) ==="
python3 - "${WERNER_CFG}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
ap = cfg.setdefault("approvals", {})
if ap.get("cron_mode") != "allow":
    ap["cron_mode"] = "allow"
    path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
    print("OK cron_mode=allow")
else:
    print("OK cron_mode já allow")
PY

echo "=== 3/4 Cron job Hermes (${CRON_SCHEDULE}) ==="
docker exec -e HERMES_HOME=/opt/data -e HERMES_ACCEPT_HOOKS=1 "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron list 2>/dev/null | grep -q "${JOB_NAME}" && JOB_EXISTS=1 || JOB_EXISTS=0

if [[ "${JOB_EXISTS}" -eq 1 ]]; then
  echo "OK job ${JOB_NAME} já existe — remover para recriar:"
  docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron remove "${JOB_NAME}" 2>/dev/null || true
fi

docker exec -e HERMES_HOME=/opt/data -e HERMES_ACCEPT_HOOKS=1 "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron create \
  --name "${JOB_NAME}" \
  --no-agent \
  --script "${SCRIPT_NAME}" \
  --deliver "telegram:${TELEGRAM_CHAT}" \
  "${CRON_SCHEDULE}"

chown -R "${HERMES_UID}:${HERMES_GID}" "${WERNER_DIR}/cron" 2>/dev/null || true
chmod 600 "${WERNER_DIR}/cron/jobs.json" 2>/dev/null || true

echo "=== 4/4 Reiniciar Werner (reload cron) ==="
docker restart "${CONTAINER}"
sleep 25
docker exec "${CONTAINER}" curl -sf http://127.0.0.1:8642/health >/dev/null 2>&1 \
  || docker exec "${CONTAINER}" pgrep -f 'hermes gateway run' >/dev/null \
  || { echo "WARN: Werner health pendente" >&2; }

docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
  /opt/hermes/.venv/bin/hermes cron list

if [[ "${TEST_RUN}" == "--test-run" ]]; then
  echo "=== Test run (envia Telegram agora) ==="
  docker exec -e HERMES_HOME=/opt/data "${CONTAINER}" \
    /opt/hermes/.venv/bin/hermes cron run "${JOB_NAME}" || true
  sleep 15
  echo "Verificar Telegram @hermes_jarvis_h_werner_bot"
fi

echo ""
echo "OK monitor AGLSRV1 no Werner: ${JOB_NAME}"
echo "Schedule: ${CRON_SCHEDULE} (08:00 diário, America/Sao_Paulo no host)"
echo "Manual: docker exec -e HERMES_HOME=/opt/data ${CONTAINER} /opt/hermes/.venv/bin/hermes cron run ${JOB_NAME}"
