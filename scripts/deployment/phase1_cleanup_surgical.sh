#!/bin/bash
# AGLSRV1 Phase 1 - Surgical Cleanup (Skip recovery-full)
# Free ~1 TB immediately without touching recovery data
# Execute: ssh AGLSRV1 'bash -s' < phase1_cleanup_surgical.sh

set -e
echo "=================================="
echo "PHASE 1: SURGICAL CLEANUP"
echo "=================================="
echo ""

# Check current space
echo ">>> Current Spark Storage Status:"
zfs list -o name,used,avail,refer spark
echo ""

# Item 2: Remove stale ZFS snapshot (1 TB)
echo ">>> [2/3] Removing stale ZFS snapshot (1 TB)..."
if zfs list -t snapshot spark@autosnap_2025-09-17_02:15:03_daily &>/dev/null; then
    zfs destroy spark@autosnap_2025-09-17_02:15:03_daily
    echo "✓ Snapshot removed successfully"
else
    echo "ℹ Snapshot already removed or not found"
fi
echo ""

# Item 3: Clean old VM 105 backups (~24 GB)
echo ">>> [3/3] Cleaning old VM 105 backups (~24 GB)..."
REMOVED_COUNT=0
if ls /spark/base/dump/vzdump-qemu-105-2025_04_25-*.vma.zst &>/dev/null; then
    rm -fv /spark/base/dump/vzdump-qemu-105-2025_04_25-*.vma.zst
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
fi
if ls /spark/base/dump/vzdump-qemu-105-2025_05_22-*.vma.zst &>/dev/null; then
    rm -fv /spark/base/dump/vzdump-qemu-105-2025_05_22-*.vma.zst
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
fi
echo "✓ Removed $REMOVED_COUNT old backup files"
echo ""

# Item 4: Clear temp directories
echo ">>> [4/4] Clearing temporary directories..."
TEMP_DIRS=$(find /spark/base/dump -name "*.tmp" -type d 2>/dev/null | wc -l)
if [ "$TEMP_DIRS" -gt 0 ]; then
    find /spark/base/dump -name "*.tmp" -type d -exec rm -rf {} \; 2>/dev/null || true
    echo "✓ Cleaned $TEMP_DIRS temporary directories"
else
    echo "ℹ No temporary directories found"
fi
echo ""

# Show recovered space
echo ">>> Space Recovery Summary:"
zfs list -o name,used,avail,refer spark
df -h /spark/base
echo ""

echo "=================================="
echo "PHASE 1: COMPLETE"
echo "Estimated space freed: ~1 TB"
echo "=================================="
