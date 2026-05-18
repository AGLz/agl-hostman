#!/bin/bash
# Health check for AI stack components
# LiteLLM, Ruflo daemon, OpenClaw
set -euo pipefail

LOG_DIR="/var/log/hostman"
LOG_FILE="${LOG_DIR}/ai-stack-health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

EXIT_CODE=0

mkdir -p "${LOG_DIR}"

log() {
    echo "[${TIMESTAMP}] $*" >> "${LOG_FILE}"
}

print_status() {
    local component="$1" status="$2" detail="${3:-}"
    if [[ "${status}" == "OK" ]]; then
        echo -e "${GREEN}[OK]   ${component}${detail:+ — ${detail}}${NC}"
    elif [[ "${status}" == "WARN" ]]; then
        echo -e "${YELLOW}[WARN] ${component}${detail:+ — ${detail}}${NC}"
    else
        echo -e "${RED}[FAIL] ${component}${detail:+ — ${detail}}${NC}"
    fi
}

echo "--- AI Stack Health: ${TIMESTAMP} ---"

# 1. LiteLLM
if curl -sf --max-time 5 http://localhost:4000/health/readiness &>/dev/null; then
    print_status "LiteLLM" "OK" "http://localhost:4000"
    log "[OK] LiteLLM healthy"
else
    print_status "LiteLLM" "FAIL" "http://localhost:4000 unreachable"
    log "[FAIL] LiteLLM unreachable"
    EXIT_CODE=1
fi

# 2. Ruflo daemon
RUFLO_OUT=$(npx ruflo@latest daemon status 2>/dev/null || echo "")
if echo "${RUFLO_OUT}" | grep -qi "running"; then
    print_status "Ruflo daemon" "OK"
    log "[OK] Ruflo daemon running"
else
    print_status "Ruflo daemon" "WARN" "not running — attempting restart"
    log "[WARN] Ruflo daemon stopped — restarting"
    if npx ruflo@latest daemon start &>/dev/null; then
        sleep 2
        RUFLO_VERIFY=$(npx ruflo@latest daemon status 2>/dev/null || echo "")
        if echo "${RUFLO_VERIFY}" | grep -qi "running"; then
            print_status "Ruflo daemon" "OK" "restarted successfully"
            log "[OK] Ruflo daemon restarted"
        else
            print_status "Ruflo daemon" "FAIL" "restart attempted but still not running"
            log "[FAIL] Ruflo daemon restart failed"
            EXIT_CODE=1
        fi
    else
        print_status "Ruflo daemon" "FAIL" "restart command failed"
        log "[FAIL] Ruflo daemon restart command failed"
        EXIT_CODE=1
    fi
fi

# 3. OpenClaw
if pgrep -f openclaw &>/dev/null; then
    print_status "OpenClaw" "OK" "process running"
    log "[OK] OpenClaw process found"
else
    print_status "OpenClaw" "WARN" "process not found"
    log "[WARN] OpenClaw not running"
fi

echo ""
[[ "${EXIT_CODE}" -eq 0 ]] && \
    echo -e "${GREEN}All critical AI stack components healthy.${NC}" || \
    echo -e "${RED}One or more critical components are down.${NC}"

exit "${EXIT_CODE}"
