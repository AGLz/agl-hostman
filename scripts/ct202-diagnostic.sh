#!/bin/bash
# CT202 (n8n) Comprehensive Diagnostic Script
# Usage: ./ct202-diagnostic.sh [--output /path/to/report.txt]

CTID=202
OUTPUT_FILE="${1:-/root/host-admin/claudedocs/CT202_diagnostic_$(date +%Y%m%d_%H%M%S).txt}"

exec > >(tee -a "$OUTPUT_FILE") 2>&1

echo "============================================"
echo "CT202 N8N DIAGNOSTIC REPORT"
echo "Generated: $(date)"
echo "============================================"
echo ""

# Function: Section header
section() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
}

# Function: Command with timeout
run_cmd() {
    local desc="$1"
    local cmd="$2"
    echo "### $desc"
    timeout 30 bash -c "$cmd" 2>&1 || echo "Command timed out or failed"
    echo ""
}

# Phase 1: Container Status
section "PHASE 1: CONTAINER STATUS"
run_cmd "Container List" "pct list | grep -E 'VMID|$CTID'"
run_cmd "Container Status" "pct status $CTID"
run_cmd "Container Config" "pct config $CTID"
run_cmd "Container Disk Usage" "pct df $CTID"

# Phase 2: Resource Utilization
section "PHASE 2: RESOURCE UTILIZATION"
run_cmd "CPU Usage" "pct exec $CTID -- top -b -n 2 -d 5 | tail -20"
run_cmd "Memory Status" "pct exec $CTID -- free -m"
run_cmd "Memory Details" "pct exec $CTID -- cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Cached|Swap'"
run_cmd "Disk Usage" "pct exec $CTID -- df -h"
run_cmd "Inode Usage" "pct exec $CTID -- df -i"
run_cmd "Top Processes by CPU" "pct exec $CTID -- ps aux --sort=-%cpu | head -15"
run_cmd "Top Processes by Memory" "pct exec $CTID -- ps aux --sort=-%mem | head -15"

# Phase 3: n8n Application
section "PHASE 3: N8N APPLICATION"
run_cmd "n8n Service Status" "pct exec $CTID -- systemctl status n8n --no-pager -l"
run_cmd "n8n Process Tree" "pct exec $CTID -- pstree -p \$(pgrep -f n8n)"
run_cmd "n8n Port Binding" "pct exec $CTID -- netstat -tlnp | grep 5678"
run_cmd "n8n Version" "pct exec $CTID -- n8n --version 2>/dev/null || npm list -g n8n 2>/dev/null || echo 'Version check failed'"
run_cmd "n8n Recent Logs (50 lines)" "pct exec $CTID -- journalctl -u n8n -n 50 --no-pager"
run_cmd "n8n Recent Errors" "pct exec $CTID -- journalctl -u n8n -p err -n 30 --no-pager"

# Phase 4: Storage
section "PHASE 4: STORAGE ANALYSIS"
run_cmd "Large Directories" "pct exec $CTID -- du -sh /* 2>/dev/null | sort -h | tail -10"
run_cmd "n8n Data Directory" "pct exec $CTID -- du -sh /root/.n8n/* 2>/dev/null | sort -h"
run_cmd "Large Files (>100M)" "pct exec $CTID -- find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10"
run_cmd "Log Directory Size" "pct exec $CTID -- du -sh /var/log/* 2>/dev/null"

# Phase 5: Network
section "PHASE 5: NETWORK DIAGNOSTICS"
run_cmd "Network Interfaces" "pct exec $CTID -- ip addr show"
run_cmd "Network Routes" "pct exec $CTID -- ip route show"
run_cmd "DNS Configuration" "pct exec $CTID -- cat /etc/resolv.conf"
run_cmd "Internet Connectivity" "pct exec $CTID -- ping -c 4 8.8.8.8"
run_cmd "DNS Resolution" "pct exec $CTID -- nslookup google.com"
run_cmd "Active Connections" "pct exec $CTID -- ss -s"

# Phase 6: System Errors
section "PHASE 6: SYSTEM ERROR ANALYSIS"
run_cmd "OOM Events" "pct exec $CTID -- dmesg | grep -i 'out of memory' | tail -10"
run_cmd "System Errors (dmesg)" "pct exec $CTID -- dmesg | grep -i 'error' | tail -20"
run_cmd "Kernel Messages" "pct exec $CTID -- journalctl -k -n 30 --no-pager"

# Phase 7: Proxmox Host Context
section "PHASE 7: PROXMOX HOST CONTEXT"
run_cmd "Host Resource Summary" "free -m && echo '' && df -h | head -10"
run_cmd "Container LXC Config" "cat /etc/pve/lxc/$CTID.conf"
run_cmd "Storage Backend" "pvesm status"
run_cmd "All Containers Overview" "pct list"

# Summary
section "DIAGNOSTIC SUMMARY"
echo "Report completed: $(date)"
echo "Output saved to: $OUTPUT_FILE"
echo ""
echo "Next Steps:"
echo "1. Review resource utilization (Phase 2)"
echo "2. Check n8n service errors (Phase 3)"
echo "3. Analyze storage capacity (Phase 4)"
echo "4. Verify network connectivity (Phase 5)"
echo ""
echo "For detailed analysis, run:"
echo "  cat $OUTPUT_FILE | less"
