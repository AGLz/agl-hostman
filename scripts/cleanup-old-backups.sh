#!/bin/bash
# Emergency Backup Cleanup Script
# Keeps only 2 most recent backups per CT/VM
# Prioritizes cleanup of large backups (>10GB)

set -e

BACKUP_DIR="/spark/base/dump"
KEEP_COUNT=2

echo "=== Proxmox Backup Cleanup ==="
echo "Directory: $BACKUP_DIR"
echo "Retention: Keep $KEEP_COUNT most recent backups per CT/VM"
echo ""

# Function to cleanup backups for a specific CT/VM
cleanup_ct() {
    local ct_id=$1
    local ct_type=$2  # lxc or qemu

    echo "Processing ${ct_type}-${ct_id}..."

    # Find all backups for this CT, sorted by date (oldest first)
    cd "$BACKUP_DIR"
    backups=($(ls -1t vzdump-${ct_type}-${ct_id}-*.tar.zst 2>/dev/null | tac))

    if [ ${#backups[@]} -eq 0 ]; then
        echo "  No backups found"
        return
    fi

    echo "  Found ${#backups[@]} backups"

    # Calculate how many to delete
    to_delete=$((${#backups[@]} - $KEEP_COUNT))

    if [ $to_delete -le 0 ]; then
        echo "  Keeping all ${#backups[@]} backups (within retention)"
        return
    fi

    echo "  Deleting $to_delete old backups..."

    # Delete old backups (keep newest $KEEP_COUNT)
    for ((i=0; i<$to_delete; i++)); do
        backup_file="${backups[$i]}"
        log_file="${backup_file%.tar.zst}.log"
        notes_file="${backup_file}.notes"

        size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
        echo "    Removing: $backup_file ($size)"

        rm -f "$backup_file" "$log_file" "$notes_file"
    done

    # Show what's kept
    echo "  Kept backups:"
    for ((i=$to_delete; i<${#backups[@]}; i++)); do
        backup_file="${backups[$i]}"
        size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
        date=$(stat -c %y "$backup_file" | cut -d' ' -f1)
        echo "    ✓ $backup_file ($size, $date)"
    done

    echo ""
}

# Get list of all unique CT/VM IDs from backup filenames
echo "Scanning for backed up containers..."
cd "$BACKUP_DIR"

# Extract unique CT IDs (LXC containers)
lxc_ids=$(ls vzdump-lxc-*.tar.zst 2>/dev/null | sed -E 's/vzdump-lxc-([0-9]+)-.*/\1/' | sort -u)

# Extract unique VM IDs (QEMU VMs)
qemu_ids=$(ls vzdump-qemu-*.tar.zst 2>/dev/null | sed -E 's/vzdump-qemu-([0-9]+)-.*/\1/' | sort -u)

echo ""
echo "=== Cleaning LXC Container Backups ==="
for ct_id in $lxc_ids; do
    cleanup_ct "$ct_id" "lxc"
done

echo "=== Cleaning QEMU VM Backups ==="
for vm_id in $qemu_ids; do
    cleanup_ct "$vm_id" "qemu"
done

echo "=== Cleanup Summary ==="
df -h | grep spark
echo ""
echo "✓ Backup cleanup complete!"
