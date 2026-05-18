#!/bin/bash
# Proxmox Backup Server (PBS) Setup Script for FGSRV07
# Configures FGSRV07 as a backup target and off-site disaster recovery destination
#
# Usage: sudo ./pbs-setup-fgsrv07.sh [--init] [--sync] [--verify]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBS_HOST="${PBS_HOST:-fgsrv07}"
PBS_DATASTORE="${PBS_DATASTORE:-local-backup}"
DATASTORE_PATH="${DATASTORE_PATH:-/var/lib/proxmox-backup/local-backup}"
SOURCE_PBS="${SOURCE_PBS:-10.6.0.14}"
SOURCE_DATASTORE="${SOURCE_DATASTORE:-aglsrv6-pbs}"
SOURCE_HOSTNAME="${SOURCE_HOSTNAME:-aglsrv6}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@agl.io}"

# Options
INIT_PBS=false
CONFIGURE_SYNC=false
VERIFY_SETUP=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --init)
            INIT_PBS=true
            shift
            ;;
        --sync)
            CONFIGURE_SYNC=true
            shift
            ;;
        --verify)
            VERIFY_SETUP=true
            shift
            ;;
        --all)
            INIT_PBS=true
            CONFIGURE_SYNC=true
            VERIFY_SETUP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--init] [--sync] [--verify] [--all]"
            echo ""
            echo "Options:"
            echo "  --init      Initialize PBS on FGSRV07"
            echo "  --sync      Configure remote sync from AGLSRV6"
            echo "  --verify    Verify PBS setup and connectivity"
            echo "  --all       Run all steps"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if running on FGSRV07
check_host() {
    local hostname=$(hostname)
    if [[ ! "$hostname" =~ fgsrv07|vps64306 ]]; then
        log_warn "This script is designed for FGSRV07. Current host: $hostname"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."

    # Check RAM (minimum 4GB recommended)
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 2048 ]]; then
        log_error "Insufficient memory: ${total_mem}MB (minimum: 2048MB)"
        return 1
    fi
    log_info "Memory: ${total_mem}MB OK"

    # Check disk space
    local disk_space=$(df -BG /var | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $disk_space -lt 100 ]]; then
        log_error "Insufficient disk space: ${disk_space}GB (minimum: 100GB)"
        return 1
    fi
    log_info "Disk space: ${disk_space}GB OK"

    # Check if proxmox-backup-server is installed
    if ! command -v proxmox-backup-manager &> /dev/null; then
        log_warn "proxmox-backup-server not found"
        log_info "Install with: apt install proxmox-backup-server"
        return 1
    fi
    log_info "Proxmox Backup Server: installed"

    return 0
}

# Initialize PBS on FGSRV07
init_pbs() {
    log_info "=== Initializing Proxmox Backup Server on FGSRV07 ==="

    # Create datastore directory
    log_info "Creating datastore directory: $DATASTORE_PATH"
    mkdir -p "$DATASTORE_PATH"

    # Initialize datastore
    log_info "Initializing datastore: $PBS_DATASTORE"
    proxmox-backup-manager datastore create \
        --name "$PBS_DATASTORE" \
        --path "$DATASTORE_PATH" \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --notify-user "root@pam" \
        --notify-gc true \
        --notify-verify true

    # Create backup user
    log_info "Creating backup user..."
    if ! proxmox-backup-manager user list | grep -q "backup"; then
        proxmox-backup-manager user create backup@pve
        log_info "Created user: backup@pve"
    else
        log_info "User backup@pve already exists"
    fi

    # Create authentication ticket for backups
    log_info "Creating authentication ticket for backup user..."
    TICKET_INFO=$(proxmox-backup-manager user token create backup@pve backup-token || echo "")

    if [[ -n "$TICKET_INFO" ]]; then
        log_info "Backup token created. Store this securely:"
        echo "$TICKET_INFO"
    fi

    # Configure garbage collection
    log_info "Configuring garbage collection schedule..."
    proxmox-backup-manager datastore update \
        --datastore "$PBS_DATASTORE" \
        --gc-schedule "mon,wed,fri 02:00" \
        --prune-schedule "sat 04:00"

    # Verify datastore
    log_info "Verifying datastore configuration..."
    proxmox-backup-manager datastore info --datastore "$PBS_DATASTORE"

    log_info "PBS initialization completed successfully"
    return 0
}

# Configure remote sync from AGLSRV6
configure_sync() {
    log_info "=== Configuring Remote Sync from AGLSRV6 ==="

    # Check connectivity to source PBS
    log_info "Testing connectivity to source PBS: $SOURCE_PBS"
    if ! ping -c 1 -W 2 "$SOURCE_PBS" >/dev/null 2>&1; then
        log_error "Cannot reach source PBS at $SOURCE_PBS"
        log_info "Ensure FGSRV07 is connected to Tailscale network"
        return 1
    fi
    log_info "Source PBS reachable"

    # Get fingerprint of source PBS
    log_info "Retrieving source PBS fingerprint..."
    SOURCE_FINGERPRINT=$(ssh -o StrictHostKeyChecking=no root@"$SOURCE_PBS" \
        "cat /etc/proxmox-backup/fingerprint.json 2>/dev/null | jq -r '.fingerprint'" || echo "")

    if [[ -z "$SOURCE_FINGERPRINT" ]]; then
        log_error "Failed to retrieve source PBS fingerprint"
        return 1
    fi

    log_info "Source PBS fingerprint: $SOURCE_FINGERPRINT"

    # Create remote connection
    log_info "Creating remote connection to $SOURCE_HOSTNAME..."
    if ! proxmox-backup-manager remote list | grep -q "$SOURCE_HOSTNAME"; then
        proxmox-backup-manager remote create "$SOURCE_HOSTNAME" \
            --host "$SOURCE_PBS" \
            --port 8007 \
            --auth-id "root@pam" \
            --fingerprint "$SOURCE_FINGERPRINT"
        log_info "Remote connection created: $SOURCE_HOSTNAME"
    else
        log_info "Remote connection already exists: $SOURCE_HOSTNAME"
    fi

    # Create sync job
    log_info "Creating sync job from $SOURCE_HOSTNAME:$SOURCE_DATASTORE..."
    if ! proxmox-backup-manager sync-job list --datastore "$PBS_DATASTORE" | grep -q "$SOURCE_HOSTNAME"; then
        proxmox-backup-manager sync-job create "$PBS_DATASTORE" "$SOURCE_HOSTNAME" \
            --remote-store "$SOURCE_DATASTORE" \
            --schedule "daily 06:00" \
            --remove-vanished true \
            --ns-depth 5
        log_info "Sync job created"
    else
        log_info "Sync job already exists"
    fi

    # Verify sync job
    log_info "Sync job configuration:"
    proxmox-backup-manager sync-job list --datastore "$PBS_DATASTORE"

    log_info "Remote sync configuration completed"
    return 0
}

# Verify PBS setup
verify_setup() {
    log_info "=== Verifying PBS Setup ==="

    local all_ok=true

    # Check datastore
    if ! proxmox-backup-manager datastore list | grep -q "$PBS_DATASTORE"; then
        log_error "Datastore '$PBS_DATASTORE' not found"
        all_ok=false
    else
        log_info "Datastore: OK"
    fi

    # Check datastore info
    log_info "Datastore information:"
    proxmox-backup-manager datastore info --datastore "$PBS_DATASTORE"

    # Check remote connection
    if proxmox-backup-manager remote list | grep -q "$SOURCE_HOSTNAME"; then
        log_info "Remote connection to $SOURCE_HOSTNAME: OK"
    else
        log_warn "Remote connection to $SOURCE_HOSTNAME: not configured"
        all_ok=false
    fi

    # Check sync jobs
    local sync_jobs=$(proxmox-backup-manager sync-job list --datastore "$PBS_DATASTORE" 2>/dev/null || echo "")
    if [[ -n "$sync_jobs" ]]; then
        log_info "Sync jobs: configured"
        echo "$sync_jobs"
    else
        log_warn "No sync jobs configured"
        all_ok=false
    fi

    # Check disk space
    local disk_usage=$(df -h "$DATASTORE_PATH" | awk 'NR==2 {print $5}' | tr -d '%')
    log_info "Disk usage: ${disk_usage}%"

    # Check PBS service status
    if systemctl is-active --quiet proxmox-backup; then
        log_info "PBS service: running"
    else
        log_error "PBS service: not running"
        all_ok=false
    fi

    if [[ "$all_ok" == true ]]; then
        log_info "=== PBS Verification: PASSED ==="
        return 0
    else
        log_error "=== PBS Verification: FAILED ==="
        return 1
    fi
}

# Display next steps
show_next_steps() {
    log_info "=== Next Steps ==="
    echo ""
    echo "1. Add this PBS server to your Proxmox hosts:"
    echo "   pvesm add pbs fgsrv07-pbs \\"
    echo "     --server <FGSRV07_IP> \\"
    echo "     --fingerprint <FINGERPRINT> \\"
    echo "     --username backup@pve \\"
    echo "     --password <TOKEN_SECRET>"
    echo ""
    echo "2. Create backup jobs on AGLSRV1 to target both datastores:"
    echo "   - Primary: aglsrv6-pbs (on-site)"
    echo "   - Secondary: fgsrv07-pbs (off-site DR)"
    echo ""
    echo "3. Monitor sync jobs:"
    echo "   proxmox-backup-manager sync-job list --datastore $PBS_DATASTORE"
    echo ""
    echo "4. Test restore procedure:"
    echo "   pct restore <new-vmid> fgsrv07-pbs:backup/vzdump-lxc-<vmid>-*"
    echo ""
}

# Main execution
main() {
    log_info "=== Proxmox Backup Server Setup for FGSRV07 ==="
    log_info "Target: $PBS_HOST"
    log_info "Datastore: $PBS_DATASTORE"
    log_info "Source PBS: $SOURCE_PBS:$SOURCE_DATASTORE"

    # Check if running on correct host
    check_host

    # Check requirements
    check_requirements || {
        log_error "System requirements not met"
        exit 1
    }

    # Run requested operations
    if [[ "$INIT_PBS" == true ]]; then
        init_pbs || exit 1
    fi

    if [[ "$CONFIGURE_SYNC" == true ]]; then
        configure_sync || exit 1
    fi

    if [[ "$VERIFY_SETUP" == true ]]; then
        verify_setup || exit 1
    fi

    # If no options specified, show help
    if [[ "$INIT_PBS" == false ]] && [[ "$CONFIGURE_SYNC" == false ]] && [[ "$VERIFY_SETUP" == false ]]; then
        echo "No operation specified. Use --help for usage information."
        echo ""
        echo "Quick start: Run with --all to initialize and configure everything"
        exit 0
    fi

    # Show next steps
    show_next_steps

    log_info "PBS setup completed successfully!"
}

# Run main
main "$@"
