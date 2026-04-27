#!/bin/bash
# AGLSRV1 Backup System Verification
# Verify cleanup success and backup system operational
# Execute: ssh AGLSRV1 'bash -s' < verify_backup_system.sh

echo "=================================="
echo "BACKUP SYSTEM VERIFICATION"
echo "=================================="
echo ""

# Storage Status
echo ">>> Storage Capacity:"
echo "Spark ZFS Pool:"
zfs list -o name,used,avail,refer,compressratio spark
echo ""
echo "Spark Mountpoint:"
df -h /spark/base | grep -v Filesystem
echo ""

AVAIL_GB=$(df -BG /spark/base | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAIL_GB" -gt 500 ]; then
    echo "✓ GOOD: ${AVAIL_GB}GB available (>500GB threshold)"
else
    echo "⚠ WARNING: Only ${AVAIL_GB}GB available"
fi
echo ""

# Backup Configuration
echo ">>> Backup Configuration:"
echo "Storage settings:"
pvesm status -storage spark
echo ""
echo "Retention policy:"
pvesh get /storage/spark | grep prune || echo "Default retention"
echo ""

# Recent Backup Status
echo ">>> Recent Backup Jobs (last 24h):"
pvesh get /cluster/tasks --limit 20 | grep -i vzdump | head -10 || echo "No recent backup tasks"
echo ""

# Running Tasks
echo ">>> Currently Running Tasks:"
RUNNING=$(pvesh get /cluster/tasks --running 1 | grep -i vzdump | wc -l)
if [ "$RUNNING" -gt 0 ]; then
    echo "⚠ $RUNNING backup task(s) currently running"
    pvesh get /cluster/tasks --running 1 | grep -i vzdump
else
    echo "✓ No backup tasks currently running"
fi
echo ""

# Lock Files
echo ">>> Backup Lock Files:"
LOCKS=$(find /var/lock -name "vzdump*" 2>/dev/null | wc -l)
if [ "$LOCKS" -gt 0 ]; then
    echo "⚠ Found $LOCKS lock file(s):"
    find /var/lock -name "vzdump*" -ls 2>/dev/null
else
    echo "✓ No stale lock files"
fi
echo ""

# Recent Backup Files
echo ">>> Recent Backup Files (last 10):"
ls -lhtr /spark/base/dump/vzdump-* 2>/dev/null | tail -10 || echo "No backup files found"
echo ""

# Space Projection
echo ">>> Space Projection:"
BACKUP_COUNT=$(ls /spark/base/dump/vzdump-*.{vma,tar}* 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh /spark/base/dump 2>/dev/null | awk '{print $1}')
echo "Total backups: $BACKUP_COUNT files"
echo "Total backup size: $TOTAL_SIZE"
echo ""

# Health Check
echo ">>> System Health:"
echo -n "Proxmox version: "
pveversion | head -1
echo -n "ZFS pool status: "
zpool status spark | grep state | awk '{print $2}'
echo ""

# Final Summary
echo "=================================="
echo "VERIFICATION SUMMARY"
echo "=================================="
if [ "$AVAIL_GB" -gt 500 ] && [ "$LOCKS" -eq 0 ]; then
    echo "✓ System Status: HEALTHY"
    echo "✓ Storage: Adequate space available"
    echo "✓ No blocking issues detected"
    echo ""
    echo ">>> Ready for next backup cycle"
else
    echo "⚠ System Status: NEEDS ATTENTION"
    [ "$AVAIL_GB" -le 500 ] && echo "  - Low storage space"
    [ "$LOCKS" -gt 0 ] && echo "  - Stale lock files present"
fi
echo "=================================="
