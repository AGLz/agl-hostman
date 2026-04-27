#!/bin/bash
################################################################################
# Forensic Suite Validation Script
# Purpose: Validate installation and readiness of the forensic suite
################################################################################

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Forensic Suite Validation"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

check_file() {
    local file=$1
    local description=$2

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (MISSING)"
        ((ERRORS++))
        return 1
    fi
}

check_executable() {
    local file=$1
    local description=$2

    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓${NC} $description: $file (executable)"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (NOT executable)"
        ((ERRORS++))
        return 1
    fi
}

check_command() {
    local cmd=$1
    local package=$2

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Command available: $cmd"
        return 0
    else
        echo -e "${YELLOW}!${NC} Command missing: $cmd (install: apt-get install -y $package)"
        ((WARNINGS++))
        return 1
    fi
}

check_directory() {
    local dir=$1
    local description=$2

    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✓${NC} $description: $dir (writable: $(test -w "$dir" && echo YES || echo NO))"
        return 0
    else
        echo -e "${YELLOW}!${NC} $description: $dir (will be auto-created)"
        ((WARNINGS++))
        return 1
    fi
}

echo "=== Checking Core Scripts ==="
check_executable "/root/host-admin/disk_forensic_analyzer.sh" "Master orchestrator"
check_executable "/root/host-admin/smart_health_check.sh" "SMART health check"
check_executable "/root/host-admin/zfs_pool_analyzer.sh" "ZFS pool analyzer"
check_executable "/root/host-admin/forensic_collector.sh" "Forensic collector"
check_executable "/root/host-admin/recovery_planner.sh" "Recovery planner"

echo ""
echo "=== Checking Documentation ==="
check_file "/root/host-admin/FORENSIC_SUITE_README.md" "Full documentation"
check_file "/root/host-admin/FORENSIC_QUICK_REFERENCE.md" "Quick reference"
check_file "/root/host-admin/FORENSIC_DEPLOYMENT_SUMMARY.md" "Deployment summary"

echo ""
echo "=== Checking Dependencies ==="
check_command "smartctl" "smartmontools"
check_command "jq" "jq"
check_command "nvme" "nvme-cli"
check_command "lspci" "pciutils"
check_command "lsusb" "usbutils"

echo ""
echo "=== Checking ZFS Availability ==="
if command -v zpool >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ZFS tools installed"
    if lsmod | grep -q zfs; then
        echo -e "${GREEN}✓${NC} ZFS module loaded"
    else
        echo -e "${YELLOW}!${NC} ZFS module not loaded (run: modprobe zfs)"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}!${NC} ZFS not installed (install: apt-get install -y zfsutils-linux)"
    echo -e "${BLUE}  Note: ZFS scripts will be skipped if not available${NC}"
    ((WARNINGS++))
fi

echo ""
echo "=== Checking Output Directories ==="
check_directory "/root/forensic-reports" "Reports directory"
check_directory "/root/forensic-data" "Forensic data directory"
check_directory "/var/log/disk-forensics" "Log directory"

echo ""
echo "=== Testing Script Syntax ==="
for script in disk_forensic_analyzer smart_health_check zfs_pool_analyzer forensic_collector recovery_planner; do
    if bash -n "/root/host-admin/${script}.sh" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Syntax valid: ${script}.sh"
    else
        echo -e "${RED}✗${NC} Syntax error: ${script}.sh"
        ((ERRORS++))
    fi
done

echo ""
echo "=== Checking Disk Devices ==="
DISK_COUNT=$(ls -1 /dev/sd? /dev/nvme?n? 2>/dev/null | wc -l || echo 0)
if [[ $DISK_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $DISK_COUNT disk device(s)"
    ls -1 /dev/sd? /dev/nvme?n? 2>/dev/null | while read dev; do
        echo "  - $dev"
    done
else
    echo -e "${YELLOW}!${NC} No disk devices detected"
    ((WARNINGS++))
fi

echo ""
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Uptime: $(uptime -p)"

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS: Forensic suite is fully operational${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run initial diagnostic: /root/host-admin/disk_forensic_analyzer.sh"
    echo "2. Review documentation: /root/host-admin/FORENSIC_SUITE_README.md"
    echo "3. Set up monitoring: /root/host-admin/FORENSIC_QUICK_REFERENCE.md"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}READY WITH WARNINGS: $WARNINGS warning(s)${NC}"
    echo ""
    echo "The suite is functional but some optional features may be unavailable."
    echo "Review warnings above and install missing dependencies if needed."
    echo ""
    echo "You can still run: /root/host-admin/disk_forensic_analyzer.sh"
else
    echo -e "${RED}ERRORS DETECTED: $ERRORS error(s), $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before using the forensic suite."
    exit 1
fi

echo ""
echo "=========================================="
echo "Quick Start Commands"
echo "=========================================="
echo ""
echo "# Full diagnostic run"
echo "/root/host-admin/disk_forensic_analyzer.sh"
echo ""
echo "# SMART check only"
echo "/root/host-admin/smart_health_check.sh"
echo ""
echo "# ZFS analysis only"
echo "/root/host-admin/zfs_pool_analyzer.sh"
echo ""
echo "# View latest results"
echo "ls -lht /root/forensic-reports/ | head"
echo ""

exit 0
