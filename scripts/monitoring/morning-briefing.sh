#!/bin/bash
# AGL Infrastructure morning briefing
# Run via cron at 08:00: 0 8 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/morning-briefing.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/hostman"
ALERTS_LOG="${LOG_DIR}/storage-alerts.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m'

section() {
    echo ""
    echo -e "${BOLD}${CYAN}=== $* ===${NC}"
}

mkdir -p "${LOG_DIR}"

echo -e "${BOLD}AGL Infrastructure Morning Briefing — ${TIMESTAMP}${NC}"
echo "========================================================"

section "Storage Status"
bash "${SCRIPT_DIR}/storage-alert.sh" || true

section "Host Reachability"
bash "${SCRIPT_DIR}/host-health.sh" || true

section "AI Stack Status"
bash "${SCRIPT_DIR}/ai-stack-health.sh" || true

section "WireGuard Mesh"
bash "${SCRIPT_DIR}/wireguard-mesh.sh" || true

section "Recent Alerts (last 20 lines)"
if [[ -f "${ALERTS_LOG}" ]]; then
    tail -n 20 "${ALERTS_LOG}"
else
    echo "No alert log found at ${ALERTS_LOG}"
fi

echo ""
echo "========================================================"
echo "Briefing complete — ${TIMESTAMP}"
