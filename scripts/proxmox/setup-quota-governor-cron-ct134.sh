#!/usr/bin/env bash
# Instala quota-governor no CT134 (cron host) + sync estado → CT188 (Argus).
#
# Uso (root no agldv03 ou host com repo + ssh AGLSRV1):
#   bash scripts/proxmox/setup-quota-governor-cron-ct134.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"
CT188_VMID="${CT188_VMID:-188}"
GOVERNOR_DIR="${GOVERNOR_DIR:-/opt/agl-hostman-governor}"
STATE_FILE="/var/log/hostman/quota-governor-state.json"
LITELLM_GATEWAY="${LITELLM_GATEWAY_URL:-http://192.168.0.186:4000}"
CRON_GOVERNOR="${CRON_GOVERNOR:-*/10 * * * *}"
CRON_SYNC="${CRON_SYNC:-*/15 * * * *}"

log() { echo "[setup-governor-ct134] $*" >&2; }

pct_exec() {
  local vmid="$1"
  shift
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${vmid} -- $*"
}

log "Sync scripts governor para CT134..."
tar -C "${REPO_ROOT}" -czf /tmp/agl-governor-scripts.tgz \
  scripts/litellm/quota-governor.sh \
  scripts/litellm/_litellm-master-key.sh \
  config/monitoring/quota-governor.env.example
scp -o BatchMode=yes /tmp/agl-governor-scripts.tgz "${AGLSRV1_SSH}:/tmp/agl-governor-scripts.tgz"
ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct push ${CT134_VMID} /tmp/agl-governor-scripts.tgz /tmp/agl-governor-scripts.tgz"
pct_exec "${CT134_VMID}" "bash -lc 'set -euo pipefail; mkdir -p ${GOVERNOR_DIR}/scripts/litellm ${GOVERNOR_DIR}/config/monitoring /var/log/hostman; tar -xzf /tmp/agl-governor-scripts.tgz -C ${GOVERNOR_DIR}; chmod +x ${GOVERNOR_DIR}/scripts/litellm/*.sh; rm -f /tmp/agl-governor-scripts.tgz'"

log "Obter LITELLM_MASTER_KEY do CT186..."
LITELLM_KEY="$(ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec 186 -- grep '^LITELLM_MASTER_KEY=' /opt/agl-litellm/.env 2>/dev/null | cut -d= -f2- | tr -d '\"'" || true)"
if [[ -n "${LITELLM_KEY}" ]]; then
  pct_exec "${CT134_VMID}" "bash -lc 'touch ${GOVERNOR_DIR}/config/monitoring/governor.env; sed -i \"/^LITELLM_MASTER_KEY=/d\" ${GOVERNOR_DIR}/config/monitoring/governor.env; echo LITELLM_MASTER_KEY=${LITELLM_KEY} >> ${GOVERNOR_DIR}/config/monitoring/governor.env; chmod 600 ${GOVERNOR_DIR}/config/monitoring/governor.env'"
fi
pct_exec "${CT134_VMID}" "bash -lc 'touch ${GOVERNOR_DIR}/config/monitoring/governor.env; sed -i \"/^LITELLM_GATEWAY_URL=/d\" ${GOVERNOR_DIR}/config/monitoring/governor.env; echo LITELLM_GATEWAY_URL=${LITELLM_GATEWAY} >> ${GOVERNOR_DIR}/config/monitoring/governor.env'"

WRAPPER="${GOVERNOR_DIR}/run-quota-governor.sh"
pct_exec "${CT134_VMID}" "bash -lc 'cat > ${WRAPPER} <<\"WRAP\"
#!/usr/bin/env bash
set -euo pipefail
export GOVERNOR_STATE_FILE=\"${STATE_FILE}\"
export LITELLM_GATEWAY_URL=\"${LITELLM_GATEWAY}\"
export GOVERNOR_ENV=\"${GOVERNOR_DIR}/config/monitoring/governor.env\"
export LITELLM_ENV_FILE=\"${GOVERNOR_DIR}/config/monitoring/governor.env\"
cd \"${GOVERNOR_DIR}\"
bash scripts/litellm/quota-governor.sh --json >> /var/log/hostman/quota-governor.log 2>&1
WRAP
chmod +x ${WRAPPER}'"

log "Instalar crons no host AGLSRV1 (pct push CT134→CT188)..."
ssh -o BatchMode=yes "$AGLSRV1_SSH" "bash -lc '
  set -euo pipefail
  pct exec ${CT188_VMID} -- mkdir -p /var/log/hostman
  MARKER=\"# agl-quota-governor-ct134\"
  (crontab -l 2>/dev/null | grep -v \"\$MARKER\" | grep -v run-quota-governor || true
   echo \"${CRON_GOVERNOR} \$MARKER pct exec ${CT134_VMID} -- ${WRAPPER}\"
   echo \"${CRON_SYNC} \$MARKER pct exec ${CT134_VMID} -- cat ${STATE_FILE} 2>/dev/null | pct exec ${CT188_VMID} -- tee ${STATE_FILE} >/dev/null\"
  ) | crontab -
'"

log "Smoke run governor..."
if pct_exec "${CT134_VMID}" "bash -lc '${WRAPPER}'"; then
  log "Governor OK — estado em ${STATE_FILE}"
else
  log "AVISO: smoke governor falhou — ver /var/log/hostman/quota-governor.log no CT134"
fi

pct_exec "${CT134_VMID}" "bash -lc 'head -c 200 ${STATE_FILE} 2>/dev/null || true'" | head -3
log "OK crons instalados no AGLSRV1"
