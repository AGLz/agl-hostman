#!/bin/bash
# Storage usage alerting for AGL infrastructure
# Run via cron every 15 min: */15 * * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/storage-alert.sh
set -euo pipefail

THRESHOLD="${STORAGE_ALERT_THRESHOLD:-${1:-90}}"
LOG_DIR="/var/log/hostman"
LOG_FILE="${LOG_DIR}/storage-alerts.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

mkdir -p "${LOG_DIR}"

log_alert() {
    local level="$1"
    local msg="$2"
    echo "[${TIMESTAMP}] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

check_zfs_pools() {
    if ! command -v zpool &>/dev/null; then
        return 0
    fi
    while IFS=$'\t' read -r pool capacity; do
        local pct="${capacity//%/}"
        if [[ "${pct}" -ge "${THRESHOLD}" ]]; then
            log_alert "WARN" "ZFS pool '${pool}' at ${capacity} (threshold: ${THRESHOLD}%)"
            echo -e "${YELLOW}[WARN] ZFS pool '${pool}': ${capacity}${NC}"
            EXIT_CODE=1
        else
            echo -e "${GREEN}[OK]   ZFS pool '${pool}': ${capacity}${NC}"
        fi
    done < <(zpool list -H -o name,capacity 2>/dev/null)
}

check_disk_mounts() {
    local -a PATHS=("/mnt/spark" "/mnt/overpower" "/")
    for mount_path in "${PATHS[@]}"; do
        [[ -d "${mount_path}" ]] || continue
        local usage
        usage=$(df -h "${mount_path}" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
        [[ -z "${usage}" ]] && continue
        if [[ "${usage}" -ge "${THRESHOLD}" ]]; then
            log_alert "WARN" "Mount '${mount_path}' at ${usage}% (threshold: ${THRESHOLD}%)"
            echo -e "${YELLOW}[WARN] Mount '${mount_path}': ${usage}%${NC}"
            EXIT_CODE=1
        else
            echo -e "${GREEN}[OK]   Mount '${mount_path}': ${usage}%${NC}"
        fi
    done
}

echo "--- Storage check at ${TIMESTAMP} (threshold: ${THRESHOLD}%) ---"
check_zfs_pools
check_disk_mounts

if [[ "${EXIT_CODE}" -eq 0 ]]; then
    echo -e "${GREEN}All storage within threshold.${NC}"
fi

exit "${EXIT_CODE}"
