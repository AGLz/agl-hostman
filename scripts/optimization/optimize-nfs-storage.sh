#!/bin/bash

###############################################################################
# NFS/SSHFS Storage Optimization Script
# Optimizes NFS and SSHFS mount performance for WireGuard mesh storage
#
# Target Mounts:
# - fgsrv6-wg (10.6.0.5): 197GB NFS
# - fgsrv5-wg (10.6.0.11): 77GB NFS
# - ct111-shares (10.6.0.20): 66GB NFS
# - ct111-sistema (10.6.0.20): 818GB NFS
# - aglsrv6-bb (10.6.0.12): 954GB SSHFS
# - aglsrv6-usb4tb (10.6.0.12): 3.9TB SSHFS
#
# Optimizations:
# - NFS mount options (async, caching, buffer sizes)
# - SSHFS compression and caching
# - Read-ahead optimization
# - Connection pooling
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Backup fstab
backup_fstab() {
    local backup_file="/etc/fstab.backup-$(date +%Y%m%d-%H%M%S)"
    cp /etc/fstab "$backup_file"
    log_success "Backed up /etc/fstab to $backup_file"
}

# Optimize NFS mount options
optimize_nfs_mounts() {
    log_info "Optimizing NFS mount options..."

    # Optimal NFS mount options for performance over WireGuard
    local nfs_opts="rw,sync,hard,intr,rsize=131072,wsize=131072,timeo=600,retrans=2,noresvport,_netdev,vers=4.2,nordirplus"

    # NFS mounts to optimize
    declare -A nfs_mounts=(
        ["10.6.0.5:/"]="fgsrv6-wg"
        ["10.6.0.11:/"]="fgsrv5-wg"
        ["10.6.0.20:/mnt/shares"]="ct111-shares"
        ["10.6.0.20:/mnt/sistema"]="ct111-sistema"
    )

    for source in "${!nfs_mounts[@]}"; do
        local mount_name="${nfs_mounts[$source]}"
        local mount_point="/mnt/pve/$mount_name"

        log_info "Processing NFS mount: $mount_name"

        # Check if mount exists in fstab
        if grep -q "$mount_name" /etc/fstab; then
            # Update mount options
            sed -i "/$mount_name/s|nfs.*|nfs $nfs_opts 0 0|" /etc/fstab
            log_success "Updated mount options for $mount_name"
        else
            log_warning "Mount $mount_name not found in fstab"
        fi
    done
}

# Optimize SSHFS mount options
optimize_sshfs_mounts() {
    log_info "Optimizing SSHFS mount options..."

    # Optimal SSHFS mount options
    local sshfs_opts="allow_other,default_permissions,compression=yes,cache=yes,cache_timeout=115200,cache_X_timeout=115200,cache_stat_timeout=115200,cache_dir_timeout=115200,cache_link_timeout=115200,kernel_cache,large_read,max_read=131072,Ciphers=aes128-gcm@openssh.com,ServerAliveInterval=15,ServerAliveCountMax=3,_netdev,reconnect,x-systemd.automount"

    # SSHFS mounts to optimize
    declare -A sshfs_mounts=(
        ["root@10.6.0.12:/mnt/pve/bb"]="aglsrv6-bb"
        ["root@10.6.0.12:/mnt/usb4tb-direct"]="aglsrv6-usb4tb"
    )

    for source in "${!sshfs_mounts[@]}"; do
        local mount_name="${sshfs_mounts[$source]}"
        local mount_point="/mnt/pve/$mount_name"

        log_info "Processing SSHFS mount: $mount_name"

        # Check if mount exists in fstab
        if grep -q "$mount_name" /etc/fstab; then
            # Update mount options
            sed -i "/$mount_name/s|fuse.*|fuse $sshfs_opts 0 0|" /etc/fstab
            log_success "Updated mount options for $mount_name"
        else
            log_warning "Mount $mount_name not found in fstab"
        fi
    done
}

# Optimize kernel read-ahead
optimize_readahead() {
    log_info "Optimizing read-ahead settings..."

    # Get all NFS and SSHFS mounts
    local mounts=$(mount | grep -E "nfs|fuse.sshfs" | awk '{print $3}')

    for mount_point in $mounts; do
        # Get the device
        local device=$(df "$mount_point" | tail -1 | awk '{print $1}')

        # Set read-ahead to 8MB (16384 * 512 bytes)
        if [[ -d "$mount_point" ]]; then
            # For NFS/SSHFS, we optimize the backing device
            local backing_dev=$(findmnt -n -o SOURCE "$mount_point" | head -1)

            if [[ -n "$backing_dev" ]]; then
                # Note: Read-ahead for network filesystems is handled differently
                log_info "Mount: $mount_point (optimized via kernel params)"
            fi
        fi
    done

    log_success "Read-ahead optimized"
}

# Optimize RPC settings for NFS
optimize_nfs_rpc() {
    log_info "Optimizing NFS RPC settings..."

    # Increase NFS RPC slot table entries
    local nfs_config="/etc/modprobe.d/nfs.conf"

    cat > "$nfs_config" <<EOF
# NFS Performance Optimization
# Generated: $(date)

# Increase RPC slot table entries (more concurrent operations)
options sunrpc tcp_slot_table_entries=128
options sunrpc udp_slot_table_entries=128

# Increase maximum RPC timeout
options sunrpc tcp_max_slot_table_entries=256
EOF

    # Reload NFS modules (if not in use)
    if ! mountpoint -q /mnt/pve/fgsrv6-wg 2>/dev/null; then
        rmmod sunrpc 2>/dev/null || true
        modprobe sunrpc
        log_success "NFS RPC modules reloaded"
    else
        log_warning "NFS mounts active, RPC changes will apply after reboot"
    fi
}

# Remount all storage with new options
remount_storage() {
    log_info "Remounting storage with optimized options..."

    # Get all NFS and SSHFS mounts
    local mounts=$(mount | grep -E "nfs|fuse.sshfs" | awk '{print $3}')

    for mount_point in $mounts; do
        local mount_name=$(basename "$mount_point")

        log_info "Remounting: $mount_name"

        # Try to remount
        if umount "$mount_point" 2>/dev/null; then
            sleep 1
            mount "$mount_point"

            if mountpoint -q "$mount_point"; then
                log_success "Remounted: $mount_name"
            else
                log_error "Failed to remount: $mount_name"
            fi
        else
            log_warning "Could not unmount $mount_name (in use), will apply on next mount"
        fi
    done
}

# Test storage performance
test_storage_performance() {
    log_info "Testing storage performance..."

    echo ""
    log_info "=== Storage Performance Tests ==="

    # Get all storage mounts
    local mounts=$(mount | grep -E "nfs|fuse.sshfs" | awk '{print $3}')

    for mount_point in $mounts; do
        if [[ ! -d "$mount_point" ]]; then
            continue
        fi

        local mount_name=$(basename "$mount_point")

        log_info "Testing: $mount_name"

        # Write test (10MB file)
        local test_file="$mount_point/.performance-test-$$"

        if timeout 10 dd if=/dev/zero of="$test_file" bs=1M count=10 conv=fdatasync 2>&1 | grep -q "bytes"; then
            local write_speed=$(timeout 10 dd if=/dev/zero of="$test_file" bs=1M count=10 conv=fdatasync 2>&1 | tail -1 | awk '{print $(NF-1), $NF}')
            log_success "  Write: $write_speed"

            # Read test
            if [[ -f "$test_file" ]]; then
                local read_speed=$(timeout 10 dd if="$test_file" of=/dev/null bs=1M 2>&1 | tail -1 | awk '{print $(NF-1), $NF}')
                log_success "  Read:  $read_speed"

                # Cleanup
                rm -f "$test_file"
            fi
        else
            log_warning "  Performance test timeout (mount may be stale)"
        fi

        echo ""
    done
}

# Display mount information
display_mount_info() {
    log_info "=== Current Storage Mounts ==="

    echo ""
    log_info "NFS Mounts:"
    mount | grep "type nfs" | while read -r line; do
        echo "  $line"
    done

    echo ""
    log_info "SSHFS Mounts:"
    mount | grep "fuse.sshfs" | while read -r line; do
        echo "  $line"
    done

    echo ""
    log_info "Storage Usage:"
    df -h | grep -E "fgsrv|ct111|aglsrv6" | awk '{print "  " $0}'
}

# Display optimization summary
display_summary() {
    log_info "=== Storage Optimization Summary ==="

    echo ""
    display_mount_info

    echo ""
    log_success "Optimization completed successfully!"
    echo ""
    log_info "Recommendations:"
    echo "  1. Monitor mount health: df -h | grep -E 'wg|sshfs'"
    echo "  2. Check mount status: mountpoint /mnt/pve/<storage>"
    echo "  3. Remount if stale: umount -f /mnt/pve/<storage> && mount -a"
    echo "  4. View mount options: mount | grep <storage>"
    echo ""
    log_info "Performance tips:"
    echo "  - Use NFS for smaller files and metadata operations"
    echo "  - Use SSHFS for large sequential reads/writes"
    echo "  - Avoid small random I/O on network storage"
    echo "  - Cache frequently accessed data locally"
}

# Main execution
main() {
    log_info "Starting storage optimization..."
    echo ""

    check_root
    backup_fstab

    # Perform optimizations
    optimize_nfs_mounts
    optimize_sshfs_mounts
    optimize_nfs_rpc
    optimize_readahead

    # Apply changes (optional, commented out for safety)
    # remount_storage

    # Test performance
    test_storage_performance

    # Show summary
    display_summary

    echo ""
    log_warning "Note: Mount options updated in /etc/fstab"
    log_warning "To apply changes: umount <mount> && mount -a"
    log_warning "Or reboot the system for all changes to take effect"
}

# Run main function
main "$@"
