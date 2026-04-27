#!/bin/bash
################################################################################
# Forensic Data Collector
# Purpose: Non-destructive collection of system state for recovery analysis
# Safety: READ-ONLY operations, no modifications to system state
################################################################################

set -euo pipefail

# Configuration
FORENSIC_DIR="/root/forensic-data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
COLLECTION_DIR="${FORENSIC_DIR}/collection_${TIMESTAMP}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "${COLLECTION_DIR}"

################################################################################
# Logging
################################################################################

LOG_FILE="${COLLECTION_DIR}/collection.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

################################################################################
# Safe Collection Functions
################################################################################

collect_system_state() {
    log "Collecting system state..."

    local state_dir="${COLLECTION_DIR}/system_state"
    mkdir -p "${state_dir}"

    # Hostname and uptime
    {
        echo "=== System Identity ==="
        echo "Hostname: $(hostname)"
        echo "FQDN: $(hostname -f 2>/dev/null || echo 'N/A')"
        echo "Date: $(date -Iseconds)"
        echo "Uptime: $(uptime -p)"
        echo "Boot time: $(who -b | awk '{print $3, $4}')"
        echo ""

        echo "=== Kernel Information ==="
        uname -a
        echo ""

        echo "=== OS Release ==="
        cat /etc/os-release 2>/dev/null || echo "N/A"
        echo ""

        echo "=== Running Kernel ==="
        cat /proc/cmdline 2>/dev/null || echo "N/A"
    } > "${state_dir}/system_info.txt"

    # Process list
    ps auxf > "${state_dir}/process_list.txt" 2>/dev/null || log "Failed to collect process list"

    # System resource usage
    {
        echo "=== CPU Info ==="
        lscpu 2>/dev/null || echo "N/A"
        echo ""

        echo "=== Memory Info ==="
        free -h
        echo ""

        echo "=== Load Average ==="
        uptime
    } > "${state_dir}/resources.txt"

    log "System state collected"
}

collect_storage_topology() {
    log "Collecting storage topology..."

    local storage_dir="${COLLECTION_DIR}/storage_topology"
    mkdir -p "${storage_dir}"

    # Block devices
    {
        echo "=== Block Devices (lsblk) ==="
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL,STATE,PHY-SEC 2>/dev/null || echo "lsblk failed"
        echo ""

        echo "=== Block Devices (JSON) ==="
        lsblk -J 2>/dev/null || echo "lsblk JSON failed"
    } > "${storage_dir}/block_devices.txt"

    # Disk by-id mappings
    ls -la /dev/disk/by-id/ > "${storage_dir}/disk_by_id.txt" 2>/dev/null || log "Could not list /dev/disk/by-id/"

    # Disk by-uuid mappings
    ls -la /dev/disk/by-uuid/ > "${storage_dir}/disk_by_uuid.txt" 2>/dev/null || log "Could not list /dev/disk/by-uuid/"

    # Disk by-path mappings
    ls -la /dev/disk/by-path/ > "${storage_dir}/disk_by_path.txt" 2>/dev/null || log "Could not list /dev/disk/by-path/"

    # Partition information
    {
        echo "=== Partition Table Information ==="
        for disk in /dev/sd? /dev/nvme?n?; do
            if [[ -b "$disk" ]]; then
                echo "--- $disk ---"
                fdisk -l "$disk" 2>/dev/null || echo "fdisk failed for $disk"
                echo ""
            fi
        done
    } > "${storage_dir}/partitions.txt"

    # Mount points
    {
        echo "=== Current Mounts ==="
        mount
        echo ""

        echo "=== /etc/fstab ==="
        cat /etc/fstab 2>/dev/null || echo "/etc/fstab not accessible"
        echo ""

        echo "=== Disk Space Usage ==="
        df -h
    } > "${storage_dir}/mounts.txt"

    log "Storage topology collected"
}

collect_zfs_state() {
    log "Collecting ZFS state..."

    if ! command -v zpool >/dev/null 2>&1; then
        log "ZFS not installed, skipping ZFS collection"
        return
    fi

    local zfs_dir="${COLLECTION_DIR}/zfs_state"
    mkdir -p "${zfs_dir}"

    # Pool status
    {
        echo "=== ZFS Pool List ==="
        zpool list -v 2>/dev/null || echo "No pools found"
        echo ""

        echo "=== ZFS Pool Status (All Pools) ==="
        for pool in $(zpool list -H -o name 2>/dev/null); do
            echo "========== Pool: ${pool} =========="
            zpool status -v "${pool}" 2>/dev/null || echo "Failed to get status"
            echo ""
        done
    } > "${zfs_dir}/pool_status.txt"

    # Pool properties
    {
        echo "=== ZFS Pool Properties ==="
        for pool in $(zpool list -H -o name 2>/dev/null); do
            echo "--- Pool: ${pool} ---"
            zpool get all "${pool}" 2>/dev/null || echo "Failed to get properties"
            echo ""
        done
    } > "${zfs_dir}/pool_properties.txt"

    # Datasets
    {
        echo "=== ZFS Datasets ==="
        zfs list -r 2>/dev/null || echo "Failed to list datasets"
        echo ""

        echo "=== ZFS Dataset Properties ==="
        for dataset in $(zfs list -H -o name 2>/dev/null); do
            echo "--- Dataset: ${dataset} ---"
            zfs get all "${dataset}" 2>/dev/null || echo "Failed to get properties"
            echo ""
        done
    } > "${zfs_dir}/datasets.txt"

    # Snapshots
    {
        echo "=== ZFS Snapshots ==="
        zfs list -t snapshot 2>/dev/null || echo "No snapshots found"
    } > "${zfs_dir}/snapshots.txt"

    # ZFS events (if available)
    if [[ -f /proc/spl/kstat/zfs/dbgmsg ]]; then
        tail -1000 /proc/spl/kstat/zfs/dbgmsg > "${zfs_dir}/zfs_debug_messages.txt" 2>/dev/null || true
    fi

    # ARC stats
    if [[ -f /proc/spl/kstat/zfs/arcstats ]]; then
        cp /proc/spl/kstat/zfs/arcstats "${zfs_dir}/arc_stats.txt" 2>/dev/null || true
    fi

    # Importable pools
    {
        echo "=== Importable ZFS Pools ==="
        zpool import 2>/dev/null || echo "No importable pools or command failed"
    } > "${zfs_dir}/importable_pools.txt"

    log "ZFS state collected"
}

collect_boot_state() {
    log "Collecting boot configuration..."

    local boot_dir="${COLLECTION_DIR}/boot_state"
    mkdir -p "${boot_dir}"

    # GRUB configuration
    if [[ -f /boot/grub/grub.cfg ]]; then
        cp /boot/grub/grub.cfg "${boot_dir}/grub.cfg" 2>/dev/null || log "Failed to copy grub.cfg"
    fi

    # Boot loader entries
    if [[ -d /boot/loader/entries ]]; then
        cp -r /boot/loader/entries "${boot_dir}/" 2>/dev/null || log "Failed to copy loader entries"
    fi

    # Initramfs/initrd info
    ls -lah /boot/initrd* /boot/initramfs* > "${boot_dir}/initramfs_list.txt" 2>/dev/null || log "No initramfs found"

    # Kernel info
    ls -lah /boot/vmlinuz* > "${boot_dir}/kernel_list.txt" 2>/dev/null || log "No kernels found"

    # EFI variables (if available)
    if command -v efibootmgr >/dev/null 2>&1; then
        efibootmgr -v > "${boot_dir}/efi_boot_manager.txt" 2>/dev/null || log "efibootmgr failed"
    fi

    log "Boot configuration collected"
}

collect_logs() {
    log "Collecting system logs..."

    local logs_dir="${COLLECTION_DIR}/logs"
    mkdir -p "${logs_dir}"

    # System journal (last 1000 lines)
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -n 1000 > "${logs_dir}/journalctl_recent.txt" 2>/dev/null || log "journalctl failed"
        journalctl -b > "${logs_dir}/journalctl_current_boot.txt" 2>/dev/null || log "journalctl boot log failed"
        journalctl -p err > "${logs_dir}/journalctl_errors.txt" 2>/dev/null || log "journalctl errors failed"
    fi

    # Kernel messages
    dmesg > "${logs_dir}/dmesg.txt" 2>/dev/null || log "dmesg failed"

    # ZFS-specific logs
    dmesg | grep -i zfs > "${logs_dir}/dmesg_zfs.txt" 2>/dev/null || log "No ZFS kernel messages"

    # System logs (if available)
    for logfile in /var/log/syslog /var/log/messages; do
        if [[ -f "$logfile" ]]; then
            tail -1000 "$logfile" > "${logs_dir}/$(basename "$logfile")_recent.txt" 2>/dev/null || log "Failed to tail $logfile"
        fi
    done

    log "System logs collected"
}

collect_hardware_info() {
    log "Collecting hardware information..."

    local hw_dir="${COLLECTION_DIR}/hardware"
    mkdir -p "${hw_dir}"

    # PCI devices
    lspci -vvv > "${hw_dir}/lspci.txt" 2>/dev/null || log "lspci failed"

    # USB devices
    lsusb -v > "${hw_dir}/lsusb.txt" 2>/dev/null || log "lsusb failed"

    # SCSI/SATA devices
    if [[ -d /sys/class/scsi_host ]]; then
        ls -la /sys/class/scsi_host/ > "${hw_dir}/scsi_hosts.txt" 2>/dev/null || true
    fi

    # NVMe info
    if command -v nvme >/dev/null 2>&1; then
        nvme list > "${hw_dir}/nvme_list.txt" 2>/dev/null || log "nvme list failed"
    fi

    # DMI/SMBIOS info
    if command -v dmidecode >/dev/null 2>&1; then
        dmidecode > "${hw_dir}/dmidecode.txt" 2>/dev/null || log "dmidecode failed (may require root)"
    fi

    # CPU info
    cp /proc/cpuinfo "${hw_dir}/cpuinfo.txt" 2>/dev/null || log "Failed to copy cpuinfo"

    # Memory info
    cp /proc/meminfo "${hw_dir}/meminfo.txt" 2>/dev/null || log "Failed to copy meminfo"

    log "Hardware information collected"
}

collect_network_state() {
    log "Collecting network configuration..."

    local net_dir="${COLLECTION_DIR}/network"
    mkdir -p "${net_dir}"

    # Network interfaces
    ip addr show > "${net_dir}/ip_addr.txt" 2>/dev/null || log "ip addr failed"
    ip route show > "${net_dir}/ip_route.txt" 2>/dev/null || log "ip route failed"

    # Network configuration files
    if [[ -d /etc/network ]]; then
        cp -r /etc/network "${net_dir}/" 2>/dev/null || log "Failed to copy /etc/network"
    fi

    if [[ -d /etc/netplan ]]; then
        cp -r /etc/netplan "${net_dir}/" 2>/dev/null || log "Failed to copy /etc/netplan"
    fi

    log "Network configuration collected"
}

collect_service_state() {
    log "Collecting service states..."

    local svc_dir="${COLLECTION_DIR}/services"
    mkdir -p "${svc_dir}"

    # Systemd services
    if command -v systemctl >/dev/null 2>&1; then
        systemctl list-units --all > "${svc_dir}/systemctl_all_units.txt" 2>/dev/null || log "systemctl list-units failed"
        systemctl list-unit-files > "${svc_dir}/systemctl_unit_files.txt" 2>/dev/null || log "systemctl list-unit-files failed"
        systemctl status > "${svc_dir}/systemctl_status.txt" 2>/dev/null || log "systemctl status failed"

        # Failed services
        systemctl --failed > "${svc_dir}/systemctl_failed.txt" 2>/dev/null || log "systemctl --failed failed"
    fi

    log "Service states collected"
}

create_collection_manifest() {
    log "Creating collection manifest..."

    cat > "${COLLECTION_DIR}/manifest.json" <<EOF
{
    "collection_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "collection_id": "${TIMESTAMP}",
    "collector_version": "1.0",
    "collection_mode": "READ-ONLY",
    "collected_data": {
        "system_state": true,
        "storage_topology": true,
        "zfs_state": $(command -v zpool >/dev/null 2>&1 && echo true || echo false),
        "boot_state": true,
        "logs": true,
        "hardware": true,
        "network": true,
        "services": true
    },
    "collection_directory": "${COLLECTION_DIR}",
    "total_size": "$(du -sh "${COLLECTION_DIR}" | awk '{print $1}')"
}
EOF

    log "Manifest created"
}

generate_collection_summary() {
    local summary_file="${COLLECTION_DIR}/SUMMARY.txt"

    {
        echo "=========================================="
        echo "FORENSIC DATA COLLECTION SUMMARY"
        echo "=========================================="
        echo ""
        echo "Collection ID: ${TIMESTAMP}"
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        echo "Collection Directory: ${COLLECTION_DIR}"
        echo "Total Size: $(du -sh "${COLLECTION_DIR}" | awk '{print $1}')"
        echo ""
        echo "=========================================="
        echo "COLLECTED DATA"
        echo "=========================================="
        echo ""

        for dir in "${COLLECTION_DIR}"/*; do
            if [[ -d "$dir" ]]; then
                local dir_name=$(basename "$dir")
                local file_count=$(find "$dir" -type f | wc -l)
                local dir_size=$(du -sh "$dir" | awk '{print $1}')
                echo "- ${dir_name}: ${file_count} files, ${dir_size}"
            fi
        done

        echo ""
        echo "=========================================="
        echo "NEXT STEPS"
        echo "=========================================="
        echo ""
        echo "1. Review manifest.json for collection details"
        echo "2. Analyze logs/journalctl_errors.txt for critical issues"
        echo "3. Check storage_topology/block_devices.txt for disk status"
        echo "4. Review zfs_state/pool_status.txt if ZFS is used"
        echo "5. Run recovery_planner.sh to generate action plan"
        echo ""
        echo "Collection complete: $(date)"
    } > "${summary_file}"

    cat "${summary_file}"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "=========================================="
    echo "FORENSIC DATA COLLECTOR v1.0"
    echo "=========================================="
    echo ""
    echo -e "${YELLOW}Mode: READ-ONLY (No system modifications)${NC}"
    echo -e "${BLUE}Collection Directory: ${COLLECTION_DIR}${NC}"
    echo ""

    log "Starting forensic data collection..."

    # Execute collection phases
    collect_system_state
    collect_storage_topology
    collect_zfs_state
    collect_boot_state
    collect_logs
    collect_hardware_info
    collect_network_state
    collect_service_state
    create_collection_manifest

    echo ""
    echo "=========================================="
    echo "COLLECTION COMPLETE"
    echo "=========================================="
    echo ""

    generate_collection_summary

    echo ""
    echo -e "${GREEN}Forensic data collected successfully${NC}"
    echo -e "${GREEN}Location:${NC} ${COLLECTION_DIR}"
    echo -e "${GREEN}Summary:${NC} ${COLLECTION_DIR}/SUMMARY.txt"
    echo -e "${GREEN}Log:${NC} ${LOG_FILE}"

    # Create archive
    echo ""
    echo -e "${BLUE}Creating archive...${NC}"
    local archive_file="${FORENSIC_DIR}/forensic_collection_${TIMESTAMP}.tar.gz"
    tar -czf "${archive_file}" -C "${FORENSIC_DIR}" "collection_${TIMESTAMP}" 2>/dev/null && \
        echo -e "${GREEN}Archive created:${NC} ${archive_file}" || \
        echo -e "${YELLOW}Warning: Archive creation failed${NC}"
}

main "$@"
