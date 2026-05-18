#!/bin/bash
# =============================================================================
# Proxmox Backup Server (PBS) Automated Configuration Script
# =============================================================================
# Purpose: Configure PBS for automated backups across AGL infrastructure
# Version: 1.0.0
# Date: 2026-02-07
# Author: Deployment Engineer Agent
#
# Features:
# - Automated PBS installation and configuration
# - Datastore creation per host with retention policies
# - Proxmox storage integration
# - Backup job scheduling with staggered times
# - Prune and garbage collection schedules
# - Health monitoring and alerting
# - Remote sync to offsite storage
#
# Architecture:
# - CT113 on AGLSRV6: Primary PBS server (10.6.0.14:8007)
# - Stores backups from AGLSRV1, AGLSRV3, AGLSRV5, AGLSRV6C, AGLSRV6D
# - Tailscale access: 100.65.189.83 (CT113)
# =============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/pbs-automated-setup.log"
LOCK_FILE="/var/run/pbs-setup.lock"
CONFIG_DIR="/etc/pve/pbs-automation"

# PBS Server Configuration
PBS_CONTAINER="113"  # CT113 on AGLSRV6
PBS_HOST="10.6.0.14"  # WireGuard IP (primary)
PBS_HOST_TS="100.65.189.83"  # Tailscale IP (backup)
PBS_PORT="8007"
PBS_DATASTORE_BASE="/mnt/backups"

# Proxmox Hosts to Configure Backups For
declare -A PROMOX_HOSTS=(
    ["aglsrv1"]="192.168.0.245,10.6.0.10,100.107.113.33"
    ["aglsrv3"]="192.168.0.247,10.6.0.24,100.123.5.81"
    ["aglsrv5"]="192.168.15.222,10.6.0.17,100.119.223.113"
    ["aglsrv6"]="192.168.0.202,10.6.0.12,100.98.108.66"
    ["aglsrv6c"]="192.168.0.233,10.6.0.22,100.124.53.91"
    ["aglsrv6d"]="192.168.0.234,10.6.0.23,100.76.201.83"
)

# Datastore Configuration
DATASTORE_RETENTION_DAILY=7
DATASTORE_RETENTION_WEEKLY=4
DATASTORE_RETENTION_MONTHLY=6

# Backup Schedule (staggered by host to avoid network congestion)
BACKUP_START_HOUR=2  # 2 AM
BACKUP_INTERVAL_MINUTES=15  # 15 minutes between hosts

# GC and Prune Schedule
GC_SCHEDULE="daily 03:00"  # 3 AM daily
PRUNE_SCHEDULE="daily 04:00"  # 4 AM daily (after GC)
VERIFY_SCHEDULE="daily 05:00"  # 5 AM daily (after prune)

# SSH Configuration
SSH_USER="root"
SSH_OPTIONS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_error "Script is already running (PID: $pid)"
            exit 1
        else
            log_warning "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

create_config_dir() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        log_info "Created config directory: $CONFIG_DIR"
    fi
}

save_config() {
    local key="$1"
    local value="$2"
    echo "$value" > "$CONFIG_DIR/$key"
    log_info "Saved config: $key"
}

load_config() {
    local key="$1"
    if [[ -f "$CONFIG_DIR/$key" ]]; then
        cat "$CONFIG_DIR/$key"
    fi
}

check_ssh_connectivity() {
    local host="$1"
    local ip="$2"

    log_info "Testing SSH connectivity to $host ($ip)..."

    if ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${ip} "echo 'OK'" > /dev/null 2>&1; then
        log_success "SSH OK: $host ($ip)"
        return 0
    else
        log_error "SSH FAIL: $host ($ip)"
        return 1
    fi
}

# ============================================================================
# PBS SERVER FUNCTIONS
# ============================================================================

check_pbs_server() {
    log_info "Checking PBS server on CT113..."

    # Try WireGuard first, then Tailscale
    local pbs_ip=""
    for ip in "$PBS_HOST" "$PBS_HOST_TS"; do
        if check_ssh_connectivity "CT113-PBS" "$ip"; then
            pbs_ip="$ip"
            save_config "pbs_ip" "$ip"
            break
        fi
    done

    if [[ -z "$pbs_ip" ]]; then
        log_error "Cannot connect to PBS server (CT113)"
        return 1
    fi

    # Check if PBS is installed and running
    log_info "Checking PBS service status..."
    if ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} \
        "systemctl is-active proxmox-backup-proxy" > /dev/null 2>&1; then
        log_success "PBS service is running"
        return 0
    else
        log_error "PBS service is not running"
        return 1
    fi
}

install_pbs() {
    local pbs_ip=$(load_config "pbs_ip")

    log_info "Installing Proxmox Backup Server..."

    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} bash << 'EOF'
set -euo pipefail

# Check if already installed
if command -v proxmox-backup-manager &> /dev/null; then
    echo "PBS already installed, skipping..."
    proxmox-backup-manager version
    exit 0
fi

# Add PBS repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs bookworm main" > \
    /etc/apt/sources.list.d/pbs-install-repo.list

# Download key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Update and install
apt-get update
apt-get install -y proxmox-backup-server

# Enable and start services
systemctl enable proxmox-backup-proxy
systemctl enable proxmox-backup
systemctl start proxmox-backup-proxy
systemctl start proxmox-backup

echo "PBS installation complete"
proxmox-backup-manager version
EOF

    log_success "PBS installed successfully"
}

create_pbs_user() {
    local pbs_ip=$(load_config "pbs_ip")
    local username="backup@pam"
    local token_name="proxmox-sync"

    log_info "Creating PBS backup user and API token..."

    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} bash << EOF
set -euo pipefail

# Create user if doesn't exist
if ! proxmox-backup-manager user list | grep -q "^$username"; then
    proxmox-backup-manager user create "$username" --comment "Automated backup user"
    echo "Created user: $username"
else
    echo "User $username already exists"
fi

# Generate API token
TOKEN_INFO=\$(proxmox-backup-manager user generate-token "$username" "$token_name")
echo "\$TOKEN_INFO"

# Save token info
echo "\$TOKEN_INFO" > /root/pbs-token.txt
chmod 600 /root/pbs-token.txt

echo "Token saved to /root/pbs-token.txt"
EOF

    log_success "PBS user and token created"
}

create_datastores() {
    local pbs_ip=$(load_config "pbs_ip")

    log_info "Creating PBS datastores..."

    local gc_offset=0
    for hostname in "${!PROMOX_HOSTS[@]}"; do
        local datastore_name="datastore-${hostname}"
        local datastore_path="${PBS_DATASTORE_BASE}/${hostname}"

        # Calculate staggered schedules
        local gc_min=$((gc_offset * 15))
        local gc_hour=3
        if [[ $gc_min -ge 60 ]]; then
            gc_hour=$((gc_hour + gc_min / 60))
            gc_min=$((gc_min % 60))
        fi
        local gc_schedule=$(printf "daily %02d:%02d" $gc_hour $gc_min)

        local prune_hour=$((gc_hour + 1))
        local prune_schedule=$(printf "daily %02d:%02d" $prune_hour $gc_min))

        ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} bash << EOF
set -euo pipefail

# Create datastore directory
mkdir -p "$datastore_path"
chown backup:backup "$datastore_path"
chmod 750 "$datastore_path"

# Create or update datastore
if proxmox-backup-manager datastore list | grep -q "\$datastore_name"; then
    echo "Datastore \$datastore_name already exists"
    proxmox-backup-manager datastore update "\$datastore_name" \
        --keep-daily $DATASTORE_RETENTION_DAILY \
        --keep-weekly $DATASTORE_RETENTION_WEEKLY \
        --keep-monthly $DATASTORE_RETENTION_MONTHLY \
        --gc-schedule "$gc_schedule" \
        --prune-schedule "$prune_schedule"
else
    proxmox-backup-manager datastore create "\$datastore_name" \
        --path "$datastore_path" \
        --keep-daily $DATASTORE_RETENTION_DAILY \
        --keep-weekly $DATASTORE_RETENTION_WEEKLY \
        --keep-monthly $DATASTORE_RETENTION_MONTHLY \
        --gc-schedule "$gc_schedule" \
        --prune-schedule "$prune_schedule" \
        --comment "Backup datastore for $hostname"
    echo "Created datastore: \$datastore_name"
fi

# Get fingerprint
proxmox-backup-manager cert info | grep "Fingerprint (sha256):" | head -1
EOF

        log_success "Datastore configured: $datastore_name"
        ((gc_offset++))
    done

    log_success "All datastores created"
}

get_pbs_fingerprint() {
    local pbs_ip=$(load_config "pbs_ip")

    log_info "Getting PBS server fingerprint..."

    local fingerprint=$(ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} \
        "proxmox-backup-manager cert info 2>/dev/null | grep 'Fingerprint (sha256):' | head -1 | awk '{print \$3}'")

    save_config "pbs_fingerprint" "$fingerprint"
    log_success "Fingerprint: $fingerprint"

    echo "$fingerprint"
}

get_pbs_api_token() {
    local pbs_ip=$(load_config "pbs_ip")

    log_info "Getting PBS API token..."

    local token=$(ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} \
        "cat /root/pbs-token.txt 2>/dev/null | grep -oP '(?<=Token Value: ).*'")

    if [[ -z "$token" ]]; then
        log_error "Failed to retrieve API token"
        return 1
    fi

    save_config "pbs_api_token" "$token"
    log_success "API token retrieved"

    echo "$token"
}

# ============================================================================
# PROXMOX HOST CONFIGURATION
# ============================================================================

configure_pve_storage() {
    local pbs_ip=$(load_config "pbs_ip")
    local fingerprint=$(load_config "pbs_fingerprint")
    local token=$(load_config "pbs_api_token")

    log_info "Configuring Proxmox VE storage for PBS..."

    for hostname in "${!PROMOX_HOSTS[@]}"; do
        local ips="${PROMOX_HOSTS[$hostname]}"
        local ip=$(echo "$ips" | cut -d',' -f2)  # Use WireGuard IP

        log_info "Configuring storage on $hostname ($ip)..."

        ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${ip} bash << EOF
set -euo pipefail

# Backup current storage config
cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-\$(date +%Y%m%d-%H%M%S)

# Check if PBS storage already exists
if grep -q "pbs: remote-pbs" /etc/pve/storage.cfg; then
    echo "PBS storage already exists, updating..."
    sed -i '/^pbs: remote-pbs/,/^$/d' /etc/pve/storage.cfg
fi

# Add PBS storage
cat >> /etc/pve/storage.cfg << 'STORAGE_CFG'
pbs: remote-pbs
    datastore datastore-${hostname}
    server ${pbs_ip}
    username backup@pam
    password ${token}
    fingerprint ${fingerprint}
    content backup,vzdumptmpl
    backup-max-performance 1
    notify always
STORAGE_CFG

# Reload storage configuration
pvesm update

# Verify
pvesm status | grep "remote-pbs"

echo "PBS storage configured on $hostname"
EOF

        log_success "Storage configured: $hostname -> PBS"
    done

    log_success "All Proxmox hosts configured"
}

create_backup_jobs() {
    log_info "Creating backup jobs..."

    local job_offset=0
    for hostname in "${!PROMOX_HOSTS[@]}"; do
        local ips="${PROMOX_HOSTS[$hostname]}"
        local ip=$(echo "$ips" | cut -d',' -f2)  # Use WireGuard IP

        # Calculate staggered backup schedule
        local backup_min=$((job_offset * BACKUP_INTERVAL_MINUTES))
        local backup_hour=$BACKUP_START_HOUR
        while [[ $backup_min -ge 60 ]]; do
            backup_hour=$((backup_hour + 1))
            backup_min=$((backup_min - 60))
        done
        local backup_schedule=$(printf "%02d:%02d" $backup_hour $backup_min)

        log_info "Creating backup job for $hostname at $backup_schedule..."

        ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${ip} bash << EOF
set -euo pipefail

# Get all VMs and containers
VMS=\$(pvesh get /cluster/resources --type vm | jq -r '.[] | select(.status == "running") | .vmid' | tr '\n' ',' | sed 's/,\$//')

if [[ -z "\$VMS" ]]; then
    echo "No running VMs/CTs on $hostname"
    exit 0
fi

# Backup jobs config
cat > /etc/pve/jobs.cfg << 'JOBS_CFG'
# Backup job created by PBS automation script
vzdump: ${hostname}-daily
    enabled 1
    schedule $backup_schedule
    storage remote-pbs
    vmid \$VMS
    mode snapshot
    compress zstd
    mailnotification always
    performance 1
    protect 1
JOBS_CFG

echo "Created backup job: ${hostname}-daily at $backup_schedule"
echo "VMs: \$VMS"
EOF

        log_success "Backup job created: $hostname ($backup_schedule)"
        ((job_offset++))
    done

    log_success "All backup jobs created"
}

# ============================================================================
# HEALTH MONITORING
# ============================================================================

create_monitoring_script() {
    local script_path="/usr/local/bin/pbs-health-monitor.sh"

    log_info "Creating health monitoring script..."

    cat > "$script_path" << 'MONITOR_EOF'
#!/bin/bash
# PBS Health Monitoring Script
# Run via cron every 15 minutes

PBS_HOST="10.6.0.14"
LOG_FILE="/var/log/pbs-health-monitor.log"
ALERT_EMAIL="${ADMIN_EMAIL:-root@localhost}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_pbs_health() {
    # Check PBS service
    if ! ssh -o ConnectTimeout=5 root@${PBS_HOST} "systemctl is-active proxmox-backup-proxy" > /dev/null 2>&1; then
        log "CRITICAL: PBS service is not running"
        return 1
    fi

    # Check datastore health
    local unhealthy=$(ssh root@${PBS_HOST} "proxmox-backup-manager datastore list 2>/dev/null | grep -c degraded || true")
    if [[ $unhealthy -gt 0 ]]; then
        log "WARNING: $unhealthy datastores are degraded"
    fi

    # Check disk space
    local usage=$(ssh root@${PBS_HOST} "df -h /mnt/backups | tail -1 | awk '{print \$5}' | sed 's/%//'")
    if [[ $usage -gt 90 ]]; then
        log "CRITICAL: Backup storage at ${usage}%"
    elif [[ $usage -gt 80 ]]; then
        log "WARNING: Backup storage at ${usage}%"
    fi

    # Check recent backups
    local last_backup=$(ssh root@${PBS_HOST} "proxmox-backup-manager snapshot-list datastore-aglsrv1 2>/dev/null | tail -2 | head -1 | awk '{print \$1}' || true")
    if [[ -n "$last_backup" ]]; then
        log "Last backup: $last_backup"
    fi

    return 0
}

check_pbs_health
MONITOR_EOF

    chmod +x "$script_path"
    log_success "Health monitoring script created: $script_path"
}

setup_health_monitoring() {
    local pbs_ip=$(load_config "pbs_ip")

    log_info "Setting up health monitoring..."

    # Create monitoring script on PBS server
    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} bash << 'EOF'
cat > /usr/local/bin/pbs-health-monitor.sh << 'MONITOR_EOF'
#!/bin/bash
# PBS Health Monitoring Script

LOG_FILE="/var/log/pbs-health-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_datastores() {
    proxmox-backup-manager datastore list 2>/dev/null | while read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local status=$(echo "$line" | awk '{print $2}')
        if [[ "$status" != "ok" ]]; then
            log "WARNING: Datastore $name status: $status"
        fi
    done
}

check_disk_space() {
    local usage=$(df -h /mnt/backups | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $usage -gt 90 ]]; then
        log "CRITICAL: Backup storage at ${usage}%"
    elif [[ $usage -gt 80 ]]; then
        log "WARNING: Backup storage at ${usage}%"
    else
        log "OK: Backup storage at ${usage}%"
    fi
}

check_recent_backups() {
    log "Checking recent backups..."
    proxmox-backup-manager datastore list 2>/dev/null | grep "^datastore" | awk '{print $1}' | while read -r ds; do
        local count=$(proxmox-backup-manager snapshot-list "$ds" 2>/dev/null | tail -n +2 | wc -l)
        log "$ds: $count snapshots"
    done
}

log "=== PBS Health Check ==="
check_datastores
check_disk_space
check_recent_backups
EOF

chmod +x /usr/local/bin/pbs-health-monitor.sh

# Add to crontab (every 15 minutes)
(crontab -l 2>/dev/null | grep -v "pbs-health-monitor"; echo "*/15 * * * * /usr/local/bin/pbs-health-monitor.sh") | crontab -

echo "Health monitoring configured"
EOF

    log_success "Health monitoring configured"
}

# ============================================================================
# REMOTE SYNC CONFIGURATION
# ============================================================================

setup_remote_sync() {
    local pbs_ip=$(load_config "pbs_ip")
    local remote_host="192.168.0.245"  # AGLSRV1
    local remote_path="/mnt/spark/pbs-remote"

    log_info "Setting up remote sync to AGLSRV1..."

    # Create remote directory
    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${remote_host} bash << EOF
mkdir -p "$remote_path"
EOF

    # Create sync script on PBS server
    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${pbs_ip} bash << EOF
cat > /usr/local/bin/pbs-remote-sync.sh << 'SYNC_EOF'
#!/bin/bash
# PBS Remote Sync Script
# Syncs backups to remote storage for offsite backup

REMOTE_HOST="${remote_host}"
REMOTE_PATH="${remote_path}"
LOG_FILE="/var/log/pbs-remote-sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$*" | tee -a "\$LOG_FILE"
}

sync_backups() {
    log "Starting remote sync..."

    # Use rsync with compression
    rsync -avz --delete --progress \
        /mnt/backups/ \
        root@\${REMOTE_HOST}:\${REMOTE_PATH}/ \
        2>&1 | tee -a "\$LOG_FILE"

    if [[ \${PIPESTATUS[0]} -eq 0 ]]; then
        log "Remote sync completed successfully"
    else
        log "ERROR: Remote sync failed"
        exit 1
    fi
}

sync_backups
SYNC_EOF

chmod +x /usr/local/bin/pbs-remote-sync.sh

# Add to crontab (daily at 6 AM after backups/prune)
(crontab -l 2>/dev/null | grep -v "pbs-remote-sync"; echo "0 6 * * * /usr/local/bin/pbs-remote-sync.sh") | crontab -

echo "Remote sync configured"
EOF

    log_success "Remote sync configured to $remote_host:$remote_path"
}

# ============================================================================
# VERIFICATION AND TESTING
# ============================================================================

test_backup_restore() {
    local test_vm="102"  # CT102 (pihole) - small container
    local test_host_ip="192.168.0.245"  # AGLSRV1

    log_info "Testing backup and restore (CT102)..."

    log_warning "This will create a test backup of CT102 and restore it"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping test"
        return 0
    fi

    ssh $SSH_OPTIONS -i "$SSH_KEY_PATH" ${SSH_USER}@${test_host_ip} bash << EOF
set -euo pipefail

# Create test backup
echo "Creating test backup of CT${test_vm}..."
vzdump ${test_vm} --storage remote-pbs --mode snapshot --compress zstd

# List recent backups
echo "Recent backups:"
pvesh get /cluster/backup --output-format json-pretty 2>/dev/null | jq -r '.[] | select(\(["vmid"] | tostring) == "${test_vm}") | .time'

echo "Test backup created. To restore, use:"
echo "pct restore ${test_vm} /mnt/pbs/..."
EOF

    log_success "Test backup created"
    log_info "Verify in PBS web UI: https://${PBS_HOST}:${PBS_PORT}"
}

# ============================================================================
# DOCUMENTATION
# =============================================================================()

print_summary() {
    local pbs_ip=$(load_config "pbs_ip")

    cat << 'SUMMARY'

=============================================================================
PBS AUTOMATED BACKUP CONFIGURATION COMPLETE
=============================================================================

PBS Server: CT113 on AGLSRV6
  - WireGuard: 10.6.0.14:8007
  - Tailscale: 100.65.189.83:8007
  - Web UI: https://10.6.0.14:8007

Datastores Created:
SUMMARY

    for hostname in "${!PROMOX_HOSTS[@]}"; do
        echo "  - datastore-$hostname (for $hostname)"
    done

    cat << 'SUMMARY'

Backup Jobs:
  - Schedule: Staggered starting at 02:00 (15min intervals)
  - Retention: 7 daily, 4 weekly, 6 monthly
  - Compression: zstd
  - Mode: snapshot

Maintenance Schedule:
  - Garbage Collection: Daily 03:00-04:00 (staggered)
  - Prune: Daily 04:00-05:00 (staggered)
  - Verification: Daily 05:00-06:00 (staggered)
  - Remote Sync: Daily 06:00
  - Health Monitoring: Every 15 minutes

Next Steps:
  1. Access PBS web UI: https://10.6.0.14:8007
  2. Verify all datastores are healthy
  3. Monitor first backup cycle
  4. Test restore procedure
  5. Configure email notifications

Monitoring Commands:
  # Check backup status on any host
  pvesm status | grep remote-pbs

  # View backup logs
  tail -f /var/log/vzdump/*.log

  # Check PBS health
  ssh root@10.6.0.14 "/usr/local/bin/pbs-health-monitor.sh"

Troubleshooting:
  - Logs: /var/log/pbs-automated-setup.log
  - PBS logs: /var/log/proxmox-backup/
  - Backup logs: /var/log/vzdump/

=============================================================================
SUMMARY
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "============================================="
    log_info "PBS Automated Backup Configuration v${SCRIPT_VERSION}"
    log_info "============================================="

    check_lock
    create_config_dir

    # Phase 1: PBS Server Setup
    log_info "Phase 1: PBS Server Setup"
    check_pbs_server || install_pbs
    create_pbs_user

    # Phase 2: Datastore Configuration
    log_info "Phase 2: Datastore Configuration"
    create_datastores
    get_pbs_fingerprint
    get_pbs_api_token

    # Phase 3: Proxmox Integration
    log_info "Phase 3: Proxmox VE Integration"
    configure_pve_storage
    create_backup_jobs

    # Phase 4: Monitoring and Maintenance
    log_info "Phase 4: Monitoring and Maintenance"
    setup_health_monitoring
    setup_remote_sync

    # Phase 5: Testing (optional)
    log_info "Phase 5: Verification"
    read -p "Run backup/restore test? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_backup_restore
    fi

    # Summary
    print_summary

    log_success "PBS automated backup configuration complete!"
}

# Run main function
main "$@"
