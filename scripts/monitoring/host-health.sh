#!/bin/bash
# Quick health check for all AGL hosts via ping
# Usage: ./host-health.sh [--tailscale-only]
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

declare -A HOSTS=(
  ["aglsrv1"]="100.107.113.33"
  ["agldv03"]="100.94.221.87"
  ["aglsrv6"]="100.98.108.66"
  ["fgsrv3"]="100.67.99.115"
  ["fgsrv5"]="100.71.107.26"
  ["fgsrv6"]="100.83.51.9"
  ["fgsrv7"]="100.109.181.93"
)

REACHABLE=0
TOTAL=${#HOSTS[@]}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "--- AGL Host Reachability Check: ${TIMESTAMP} ---"
printf "%-12s %-18s %s\n" "HOST" "IP" "STATUS"
printf "%-12s %-18s %s\n" "----" "--" "------"

for host in "${!HOSTS[@]}"; do
    ip="${HOSTS[$host]}"
    if ping -c1 -W2 "${ip}" &>/dev/null; then
        printf "${GREEN}%-12s %-18s OK${NC}\n" "${host}" "${ip}"
        (( REACHABLE++ )) || true
    else
        printf "${RED}%-12s %-18s FAIL${NC}\n" "${host}" "${ip}"
    fi
done

echo ""
if [[ "${REACHABLE}" -eq "${TOTAL}" ]]; then
    echo -e "${GREEN}Summary: ${REACHABLE}/${TOTAL} hosts reachable${NC}"
else
    echo -e "${RED}Summary: ${REACHABLE}/${TOTAL} hosts reachable${NC}"
fi

[[ "${REACHABLE}" -eq "${TOTAL}" ]]
