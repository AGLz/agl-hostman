#!/bin/bash
#
# Batch Switch Verification
# Verify multiple potential switches in parallel
#

set -euo pipefail

# High-priority candidates from scan
CANDIDATES=(
    "192.168.0.1"
    "192.168.0.131"
    "192.168.0.132"
    "192.168.0.133"
    "192.168.0.137"
    "192.168.0.139"
    "192.168.0.161"
    "192.168.0.162"
    "192.168.0.254"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

echo "Starting batch verification of ${#CANDIDATES[@]} devices..."
echo "Results will be saved to: ${RESULTS_DIR}/batch_verify_${TIMESTAMP}.txt"
echo ""

for ip in "${CANDIDATES[@]}"; do
    echo "═══════════════════════════════════════"
    echo "Verifying: $ip"
    echo "═══════════════════════════════════════"
    
    "${SCRIPT_DIR}/verify-omay-switch.sh" "$ip" 2>&1 | tee -a "${RESULTS_DIR}/batch_verify_${TIMESTAMP}.txt"
    echo ""
done

echo "Batch verification complete!"
echo "Results saved to: ${RESULTS_DIR}/batch_verify_${TIMESTAMP}.txt"
