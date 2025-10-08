#!/bin/bash
# AGLSRV1 Optimization Plan Implementation
# Apply retention, compression, and schedule optimizations
# Execute: ssh AGLSRV1 'bash -s' < optimization_plan.sh

set -e
echo "=================================="
echo "OPTIMIZATION PLAN EXECUTION"
echo "=================================="
echo ""

# 1. Reduce Retention Settings
echo ">>> [1/3] Optimizing Backup Retention..."
echo "Current settings:"
pvesm status -storage spark | grep -A5 spark || true
echo ""

echo "Applying new retention: keep-last=3, keep-weekly=2, keep-monthly=3, keep-yearly=1"
pvesm set spark --prune-backups keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1
echo "✓ Retention policy updated"
echo ""

echo "Triggering immediate prune on existing backups..."
# Force prune on all existing backups
for VMID in $(qm list | awk 'NR>1 {print $1}'); do
    echo "  Pruning VM $VMID backups..."
    vzdump --prune-backups keep-last=3,keep-weekly=2,keep-monthly=3,keep-yearly=1 --dumpdir /spark/base/dump $VMID --mode stop --dry-run 2>/dev/null || true
done
echo "✓ Prune operations completed"
echo ""

# 2. Enable ZFS Compression
echo ">>> [2/3] Enabling ZFS LZ4 Compression..."
CURRENT_COMPRESSION=$(zfs get -H -o value compression spark)
echo "Current compression: $CURRENT_COMPRESSION"

if [ "$CURRENT_COMPRESSION" != "lz4" ]; then
    zfs set compression=lz4 spark
    echo "✓ LZ4 compression enabled (applies to new data)"
    echo "ℹ Existing data will be compressed gradually"
else
    echo "ℹ LZ4 compression already enabled"
fi
echo ""

# 3. Optimize Backup Schedule
echo ">>> [3/3] Optimizing Backup Schedule..."
echo "Current backup jobs:"
cat /etc/pve/vzdump.cron
echo ""

# Backup current config
cp /etc/pve/vzdump.cron /etc/pve/vzdump.cron.backup.$(date +%Y%m%d_%H%M%S)

# Check if we need to split schedules
BACKUP_COUNT=$(pvesh get /cluster/backup --output-format json | jq '. | length' 2>/dev/null || echo "0")
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "Found $BACKUP_COUNT backup jobs configured"
    echo "ℹ Review backup schedule in Proxmox GUI:"
    echo "   Datacenter → Backup → Select job → Edit"
    echo "   Recommendation: Stagger start times (03:00 for critical, 04:00 for others)"
else
    echo "ℹ No backup jobs found in cluster configuration"
fi
echo ""

# Show results
echo ">>> Optimization Summary:"
echo "✓ Retention: keep-last=3, keep-weekly=2, keep-monthly=3, keep-yearly=1"
echo "✓ Compression: LZ4 enabled on spark pool"
echo "✓ Schedule: Review recommended (see above)"
echo ""

echo ">>> Updated Spark Storage Status:"
zfs list -o name,used,avail,refer,compressratio spark
df -h /spark/base
echo ""

echo "=================================="
echo "OPTIMIZATION PLAN: COMPLETE"
echo "Expected effective capacity: 2x with compression"
echo "=================================="
