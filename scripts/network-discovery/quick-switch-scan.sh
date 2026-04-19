#!/bin/bash
#
# Quick Switch Scanner
# Fast scan for devices with switch management interfaces
#
# Usage: ./quick-switch-scan.sh [subnet]
# Example: ./quick-switch-scan.sh 192.168.0.0/24
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect subnet if not provided
if [ $# -eq 0 ]; then
    SUBNET=$(ip -4 addr show | grep "inet.*scope global" | grep -v "docker\|tailscale" | head -1 | awk '{print $2}' | sed 's/\.[0-9]\+\//.0\//')
    echo -e "${BLUE}Auto-detected subnet: $SUBNET${NC}"
else
    SUBNET="$1"
fi

echo -e "${BLUE}Scanning $SUBNET for switch devices...${NC}\n"

# Quick nmap scan for common switch ports
echo -e "${YELLOW}Running fast port scan (this may take 30-60 seconds)...${NC}"

nmap -Pn -sT -p 80,443,23,22 --open \
     --min-rate 1000 \
     --max-retries 1 \
     --host-timeout 5s \
     "$SUBNET" 2>/dev/null | \
while IFS= read -r line; do
    if [[ "$line" =~ ^Nmap\ scan\ report\ for\ (.+)$ ]]; then
        current_host="${BASH_REMATCH[1]}"
        echo -e "\n${GREEN}Potential switch: $current_host${NC}"
    elif [[ "$line" =~ ^([0-9]+)/tcp.*open ]]; then
        echo "  - Port ${BASH_REMATCH[1]} open"
    fi
done

echo -e "\n${BLUE}Scan complete!${NC}"
echo -e "To verify a specific device, run:"
echo -e "  ./verify-omay-switch.sh <IP_ADDRESS>"
