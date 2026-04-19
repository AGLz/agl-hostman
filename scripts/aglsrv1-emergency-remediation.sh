#!/bin/bash
#
# AGLSRV1 Emergency Remediation Script
# Date: 2025-10-21
# Purpose: Fix critical issues identified in service diagnostics
#
# CRITICAL ISSUES ADDRESSED:
# 1. /tmp filesystem at 100% (63GB rclone-gd cache)
# 2. Vzdump stale lock
# 3. Failed mount services
# 4. Orphaned container 999 service
# 5. Corrupted storage configs
#
# Usage: ./aglsrv1-emergency-remediation.sh [--dry-run]
#

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY RUN MODE] No changes will be made${NC}\n"
fi

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

run_cmd() {
    local cmd="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would execute: $cmd"
    else
        log "Executing: $cmd"
        eval "$cmd"
    fi
}

# Confirm execution
if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "${RED}WARNING: This script will make system changes!${NC}"
    echo "Press Ctrl+C to abort, or Enter to continue..."
    read -r
fi

log "Starting AGLSRV1 Emergency Remediation"

# ==============================================================================
# STEP 1: Clear /tmp filesystem (CRITICAL - 100% full)
# ==============================================================================

log "STEP 1: Analyzing /tmp filesystem usage"

# Root cause: /tmp/rclone-gd is 63GB (100% of /tmp)
RCLONE_TMP="/tmp/rclone-gd"
RCLONE_PID=$(pgrep -f "rclone mount.*gdrive" || echo "")

if [[ -d "$RCLONE_TMP" ]]; then
    RCLONE_SIZE=$(du -sh "$RCLONE_TMP" 2>/dev/null | cut -f1)
    warn "/tmp/rclone-gd is consuming $RCLONE_SIZE"

    if [[ -n "$RCLONE_PID" ]]; then
        warn "rclone process is running (PID: $RCLONE_PID)"
        echo "Options:"
        echo "  1. Stop rclone and clear cache (safest)"
        echo "  2. Clear cache while rclone running (risky, may corrupt)"
        echo "  3. Skip this step (not recommended)"

        if [[ "$DRY_RUN" == "false" ]]; then
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    run_cmd "systemctl stop rclone-wg.service || kill $RCLONE_PID"
                    sleep 2
                    run_cmd "rm -rf $RCLONE_TMP/*"
                    log "Cleared rclone cache, restart with: systemctl start rclone-wg.service"
                    ;;
                2)
                    warn "Clearing cache while rclone is running..."
                    run_cmd "find $RCLONE_TMP -type f -mtime +1 -delete"
                    ;;
                3)
                    warn "Skipping rclone cache cleanup"
                    ;;
            esac
        else
            echo "[DRY RUN] Would prompt for rclone cache cleanup option"
        fi
    else
        log "rclone not running, safe to clear cache"
        run_cmd "rm -rf $RCLONE_TMP/*"
    fi
else
    log "/tmp/rclone-gd not found, skipping"
fi

# Clear old temporary files
log "Cleaning up old temporary files..."
run_cmd "find /tmp -type f -mtime +7 -delete 2>/dev/null || true"
run_cmd "find /tmp -type d -empty -delete 2>/dev/null || true"

# Verify /tmp space
if [[ "$DRY_RUN" == "false" ]]; then
    TMP_USAGE=$(df -h /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $TMP_USAGE -lt 90 ]]; then
        log "/tmp usage now at ${TMP_USAGE}% (below 90% threshold)"
    else
        warn "/tmp still at ${TMP_USAGE}% - manual intervention may be needed"
    fi
fi

# ==============================================================================
# STEP 2: Clear vzdump stale lock
# ==============================================================================

log "STEP 2: Checking vzdump lock status"

VZDUMP_LOCK="/var/run/vzdump.lock"
VZDUMP_PID=$(ps aux | grep -E 'task UPID.*vzdump' | grep -v grep | awk '{print $2}' || echo "")

if [[ -f "$VZDUMP_LOCK" ]]; then
    LOCK_SIZE=$(ls -lh "$VZDUMP_LOCK" | awk '{print $5}')

    if [[ "$LOCK_SIZE" == "0" ]] && [[ -n "$VZDUMP_PID" ]]; then
        warn "Vzdump lock exists (0 bytes) but backup task is running (PID: $VZDUMP_PID)"
        log "This is normal during backup, skipping lock removal"
    elif [[ "$LOCK_SIZE" == "0" ]] && [[ -z "$VZDUMP_PID" ]]; then
        warn "Stale vzdump lock found, no backup running"
        run_cmd "rm -f $VZDUMP_LOCK"
        log "Stale lock removed"
    else
        log "Vzdump lock present, backup task running normally"
    fi
else
    log "No vzdump lock present"
fi

# ==============================================================================
# STEP 3: Clean up failed mount services
# ==============================================================================

log "STEP 3: Cleaning up obsolete NFS mount services"

FAILED_MOUNTS=(
    "mnt-pve-fgsrv5\\x2dnfs.mount"
    "mnt-pve-fgsrv6\\x2dnfs.mount"
)

for mount in "${FAILED_MOUNTS[@]}"; do
    if systemctl list-unit-files | grep -q "$(echo $mount | sed 's/\\\\x2d/-/g')"; then
        log "Disabling obsolete mount: $mount"
        run_cmd "systemctl disable $mount || true"
        run_cmd "systemctl stop $mount || true"
    fi
done

run_cmd "systemctl reset-failed"

# ==============================================================================
# STEP 4: Remove orphaned container 999 service
# ==============================================================================

log "STEP 4: Checking container 999 service"

if systemctl list-unit-files | grep -q "pve-container@999.service"; then
    if [[ ! -f "/etc/pve/lxc/999.conf" ]]; then
        log "Container 999 config missing, disabling orphaned service"
        run_cmd "systemctl disable pve-container@999.service || true"
        run_cmd "systemctl stop pve-container@999.service || true"
    else
        warn "Container 999 exists but service failed - manual investigation needed"
    fi
else
    log "No orphaned container 999 service found"
fi

# ==============================================================================
# STEP 5: Remove corrupted storage configs
# ==============================================================================

log "STEP 5: Checking for corrupted storage configs"

# Test pvesm status for errors
PVESM_ERROR=$(pvesm status 2>&1 | grep -E "type check|verification failed" || echo "")

if [[ -n "$PVESM_ERROR" ]]; then
    warn "Detected pvesm corruption: $PVESM_ERROR"

    # Check if obsolete NFS storages exist
    OBSOLETE_STORAGES=("fgsrv5-nfs" "fgsrv6-nfs")

    for storage in "${OBSOLETE_STORAGES[@]}"; do
        if pvesm status | grep -q "^$storage"; then
            log "Removing obsolete storage config: $storage"
            run_cmd "pvesm remove $storage || true"
        fi
    done

    # Verify fix
    if [[ "$DRY_RUN" == "false" ]]; then
        if pvesm status 2>&1 | grep -q "type check"; then
            error "pvesm still showing errors after cleanup - manual intervention required"
        else
            log "pvesm storage status now clean"
        fi
    fi
else
    log "No pvesm corruption detected"
fi

# ==============================================================================
# STEP 6: Fix ZFS snapshot manager
# ==============================================================================

log "STEP 6: Checking ZFS snapshot manager"

if systemctl is-failed zfs-snapshot-manager.service &>/dev/null; then
    warn "ZFS snapshot manager is failed"
    log "Checking service logs..."
    run_cmd "journalctl -u zfs-snapshot-manager.service --since today --no-pager | tail -20"

    echo "Options:"
    echo "  1. Restart service"
    echo "  2. Disable service"
    echo "  3. Skip"

    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Choose option [1-3]: " choice
        case $choice in
            1) run_cmd "systemctl restart zfs-snapshot-manager.service" ;;
            2) run_cmd "systemctl disable zfs-snapshot-manager.service" ;;
            3) log "Skipping ZFS snapshot manager" ;;
        esac
    else
        echo "[DRY RUN] Would prompt for ZFS snapshot manager action"
    fi
fi

# ==============================================================================
# STEP 7: Restart container 200 (ollama)
# ==============================================================================

log "STEP 7: Checking container 200 (ollama) status"

CT200_STATUS=$(pct status 200 || echo "error")

if [[ "$CT200_STATUS" == *"stopped"* ]]; then
    warn "Container 200 (ollama) is stopped"

    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Start container 200? [y/N]: " start_ct200
        if [[ "$start_ct200" == "y" ]]; then
            run_cmd "pct start 200"
            sleep 5
            pct status 200
        fi
    else
        echo "[DRY RUN] Would prompt to start container 200"
    fi
elif [[ "$CT200_STATUS" == *"running"* ]]; then
    log "Container 200 is running"
else
    error "Container 200 status unknown: $CT200_STATUS"
fi

# ==============================================================================
# Final Summary
# ==============================================================================

log "Remediation complete!"
echo ""
echo "Summary of actions:"
echo "  [✓] Analyzed /tmp filesystem usage"
echo "  [✓] Checked vzdump lock status"
echo "  [✓] Cleaned up failed mount services"
echo "  [✓] Checked container 999 service"
echo "  [✓] Verified storage configuration"
echo "  [✓] Checked ZFS snapshot manager"
echo "  [✓] Verified container 200 status"
echo ""

if [[ "$DRY_RUN" == "false" ]]; then
    log "Generating post-remediation report..."

    echo ""
    echo "=== SYSTEM STATUS ==="
    df -h /tmp | tail -1
    free -h | grep Mem
    systemctl --failed --no-pager | head -10

    echo ""
    echo "Recommended next steps:"
    echo "  1. Monitor /tmp usage: watch -n 60 'df -h /tmp'"
    echo "  2. Review memory pressure: htop or ps aux --sort=-%mem"
    echo "  3. Check Proxmox WebUI: https://192.168.0.245:8006"
    echo "  4. Verify backups: pvesm status && pct list"
fi

log "Script finished"
