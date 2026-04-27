#!/bin/bash
# WireGuard mesh connectivity check
# Tests all mesh nodes from current host
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

declare -A WG_NODES=(
  ["fgsrv6-hub"]="10.6.0.5"
  ["aglsrv1"]="10.6.0.10"
  ["fgsrv5"]="10.6.0.11"
  ["aglsrv6"]="10.6.0.12"
  ["fgsrv4"]="10.6.0.16"
  ["aglsrv5"]="10.6.0.17"
  ["fgsrv3"]="10.6.0.18"
  ["ct179"]="10.6.0.19"
  ["ct111"]="10.6.0.20"
)

REACHABLE=0
TOTAL=${#WG_NODES[@]}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "--- WireGuard Mesh Check: ${TIMESTAMP} ---"
printf "%-14s %-14s %-8s %s\n" "NODE" "IP" "STATUS" "LATENCY"
printf "%-14s %-14s %-8s %s\n" "----" "--" "------" "-------"

for node in "${!WG_NODES[@]}"; do
    ip="${WG_NODES[$node]}"
    ping_out=$(ping -c1 -W1 "${ip}" 2>/dev/null || true)
    if echo "${ping_out}" | grep -q "1 received"; then
        latency=$(echo "${ping_out}" | grep -oP 'time=\K[0-9.]+' || echo "?")
        printf "${GREEN}%-14s %-14s %-8s %s ms${NC}\n" "${node}" "${ip}" "OK" "${latency}"
        (( REACHABLE++ )) || true
    else
        printf "${RED}%-14s %-14s %-8s -%s\n${NC}" "${node}" "${ip}" "FAIL" ""
    fi
done

echo ""
if [[ "${REACHABLE}" -eq "${TOTAL}" ]]; then
    echo -e "${GREEN}WireGuard: ${REACHABLE}/${TOTAL} nodes reachable${NC}"
else
    echo -e "${RED}WireGuard: ${REACHABLE}/${TOTAL} nodes reachable${NC}"
fi
