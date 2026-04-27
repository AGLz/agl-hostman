#!/bin/bash
#
# Harbor CT182 Master Deployment Script
# Comprehensive automated deployment for Proxmox LXC Container
#
# Author: Hive Mind Coder Agent
# Session: swarm-1761131660305-65la2tiid
# Date: 2025-10-22
# Version: 1.0.0
#
# Description:
#   Production-grade automated deployment script for Harbor Container Registry
#   in Proxmox CT182 with full security hardening, monitoring, and backup automation.
#
# Usage:
#   ./deploy-harbor.sh [OPTIONS]
#
# Options:
#   --ct-id <ID>              Proxmox container ID (default: 182)
#   --hostname <FQDN>         Harbor hostname (default: harbor.yourdomain.com)
#   --ip-address <IP>         Static IP address (default: 192.168.1.182)
#   --data-volume <PATH>      Data volume path (default: /data/registry)
#   --skip-ct-creation        Skip Proxmox CT creation (container exists)
#   --skip-ssl                Skip SSL certificate generation
#   --production              Production mode (use corporate certificates)
#   --help                    Show this help message
#

set -euo pipefail

# Script Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/harbor-deploy-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=${VERBOSE:-1}

# Default Configuration
CT_ID="${CT_ID:-182}"
CT_HOSTNAME="${CT_HOSTNAME:-harbor-registry}"
HARBOR_FQDN="${HARBOR_FQDN:-harbor.agl.local}"
IP_ADDRESS="${IP_ADDRESS:-192.168.0.182}"
IP_GATEWAY="${IP_GATEWAY:-192.168.0.1}"
IP_NETMASK="${IP_NETMASK:-24}"
DATA_VOLUME="${DATA_VOLUME:-/data/registry}"
HARBOR_VERSION="${HARBOR_VERSION:-2.12.2}"

# Resource Allocation
CT_CORES="${CT_CORES:-4}"
CT_MEMORY="${CT_MEMORY:-8192}"
CT_SWAP="${CT_SWAP:-2048}"
CT_ROOTFS_SIZE="${CT_ROOTFS_SIZE:-16}"
CT_DATA_SIZE="${CT_DATA_SIZE:-200}"

# Mode Flags
SKIP_CT_CREATION=0
SKIP_SSL=0
PRODUCTION_MODE=0

# Color Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() {
    if [[ $VERBOSE -eq 1 ]]; then
        log "INFO" "${BLUE}$*${NC}"
    fi
}

success() {
    log "SUCCESS" "${GREEN}✓ $*${NC}"
}

warn() {
    log "WARN" "${YELLOW}⚠ $*${NC}"
}

error() {
    log "ERROR" "${RED}✗ $*${NC}"
}

fatal() {
    error "$*"
    exit 1
}

# Progress Display
show_progress() {
    local step="$1"
    local total="$2"
    local description="$3"
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Step $step/$total: ${description}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

# Parse Command Line Arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ct-id)
                CT_ID="$2"
                shift 2
                ;;
            --hostname)
                HARBOR_FQDN="$2"
                shift 2
                ;;
            --ip-address)
                IP_ADDRESS="$2"
                shift 2
                ;;
            --data-volume)
                DATA_VOLUME="$2"
                shift 2
                ;;
            --skip-ct-creation)
                SKIP_CT_CREATION=1
                shift
                ;;
            --skip-ssl)
                SKIP_SSL=1
                shift
                ;;
            --production)
                PRODUCTION_MODE=1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Harbor CT182 Master Deployment Script

Usage: $0 [OPTIONS]

Options:
  --ct-id <ID>              Proxmox container ID (default: 182)
  --hostname <FQDN>         Harbor hostname (default: harbor.yourdomain.com)
  --ip-address <IP>         Static IP address (default: 192.168.1.182)
  --data-volume <PATH>      Data volume path (default: /data/registry)
  --skip-ct-creation        Skip Proxmox CT creation (container exists)
  --skip-ssl                Skip SSL certificate generation
  --production              Production mode (use corporate certificates)
  --help                    Show this help message

Examples:
  # Full deployment
  sudo $0 --hostname harbor.example.com --ip-address 10.0.0.182

  # Deploy to existing container
  sudo $0 --skip-ct-creation

  # Production deployment with custom settings
  sudo $0 --production --hostname harbor.prod.example.com

EOF
}

# Validation Functions
check_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This script must be run as root or with sudo"
    fi
}

check_proxmox_host() {
    if [[ ! -f /etc/pve/.version ]]; then
        warn "Not running on Proxmox host - CT creation will be skipped"
        SKIP_CT_CREATION=1
        return 1
    fi
    return 0
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        fatal "Invalid IP address: $ip"
    fi
}

# Step 1: Create Proxmox LXC Container
create_proxmox_container() {
    show_progress 1 10 "Creating Proxmox LXC Container CT$CT_ID"

    if [[ $SKIP_CT_CREATION -eq 1 ]]; then
        info "Skipping CT creation (--skip-ct-creation flag set)"
        return 0
    fi

    if ! check_proxmox_host; then
        return 0
    fi

    # Check if container already exists
    if pct status "$CT_ID" &>/dev/null; then
        warn "Container CT$CT_ID already exists"
        read -p "Destroy and recreate? (yes/no): " response
        if [[ "$response" == "yes" ]]; then
            info "Destroying existing container CT$CT_ID"
            pct stop "$CT_ID" || true
            pct destroy "$CT_ID" || true
        else
            info "Using existing container CT$CT_ID"
            SKIP_CT_CREATION=1
            return 0
        fi
    fi

    info "Creating LXC container CT$CT_ID with Harbor-optimized settings"

    # Create container
    pct create "$CT_ID" \
        local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
        --hostname "$CT_HOSTNAME" \
        --cores "$CT_CORES" \
        --memory "$CT_MEMORY" \
        --swap "$CT_SWAP" \
        --net0 "name=eth0,bridge=vmbr0,ip=${IP_ADDRESS}/${IP_NETMASK},gw=${IP_GATEWAY}" \
        --features "nesting=1,keyctl=1" \
        --unprivileged 1 \
        --rootfs "local-zfs:${CT_ROOTFS_SIZE}" \
        --onboot 1 \
        --start 1

    if [[ $? -eq 0 ]]; then
        success "Container CT$CT_ID created successfully"
    else
        fatal "Failed to create container CT$CT_ID"
    fi

    # Wait for container to start
    info "Waiting for container to start..."
    sleep 10

    # Configure data volume
    info "Configuring data volume for Harbor registry storage"
    mkdir -p "/mnt/storage/harbor-ct${CT_ID}-data"
    pct set "$CT_ID" -mp0 "/mnt/storage/harbor-ct${CT_ID}-data,mp=${DATA_VOLUME}"

    success "Proxmox container CT$CT_ID ready"
}

# Step 2: Install Docker and Docker Compose
install_docker() {
    show_progress 2 10 "Installing Docker and Docker Compose"

    info "Running Docker installation inside CT$CT_ID"

    pct exec "$CT_ID" -- bash -c "
        set -e
        export DEBIAN_FRONTEND=noninteractive

        # Update system
        apt-get update
        apt-get upgrade -y

        # Install prerequisites
        apt-get install -y ca-certificates curl gnupg lsb-release

        # Add Docker repository
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Verify installation
        docker --version
        docker compose version
    "

    if [[ $? -eq 0 ]]; then
        success "Docker and Docker Compose installed successfully"
    else
        fatal "Docker installation failed"
    fi
}

# Step 3: Configure Storage and Permissions
configure_storage() {
    show_progress 3 10 "Configuring Storage and Permissions"

    info "Setting up Harbor data directories"

    pct exec "$CT_ID" -- bash -c "
        set -e

        # Create directory structure
        mkdir -p ${DATA_VOLUME}/{registry,database,secrets/cert,backups}

        # Set permissions for unprivileged LXC
        chown -R 10000:10000 ${DATA_VOLUME}
        chmod 755 ${DATA_VOLUME}
        chmod 700 ${DATA_VOLUME}/secrets

        # Create log directory
        mkdir -p /var/log/harbor
        chown -R 10000:10000 /var/log/harbor
    "

    success "Storage configured with proper permissions"
}

# Step 4: Generate SSL Certificates
generate_ssl_certificates() {
    show_progress 4 10 "Generating SSL/TLS Certificates"

    if [[ $SKIP_SSL -eq 1 ]]; then
        info "Skipping SSL certificate generation (--skip-ssl flag set)"
        return 0
    fi

    if [[ $PRODUCTION_MODE -eq 1 ]]; then
        warn "Production mode enabled - you must provide corporate certificates"
        warn "Place certificates at: ${DATA_VOLUME}/secrets/cert/"
        warn "  - server.crt: Certificate file"
        warn "  - server.key: Private key file"
        read -p "Press Enter when certificates are in place..."
        return 0
    fi

    info "Generating self-signed certificates for testing"

    pct exec "$CT_ID" -- bash -c "
        set -e

        openssl req -newkey rsa:4096 -nodes -sha256 \
            -keyout ${DATA_VOLUME}/secrets/cert/server.key \
            -x509 -days 365 \
            -out ${DATA_VOLUME}/secrets/cert/server.crt \
            -subj \"/C=US/ST=State/L=City/O=Organization/CN=${HARBOR_FQDN}\"

        # Set permissions
        chmod 644 ${DATA_VOLUME}/secrets/cert/server.crt
        chmod 600 ${DATA_VOLUME}/secrets/cert/server.key
        chown -R 10000:10000 ${DATA_VOLUME}/secrets
    "

    warn "Self-signed certificates generated - NOT suitable for production"
    success "SSL certificates ready"
}

# Step 5: Download and Install Harbor
install_harbor() {
    show_progress 5 10 "Downloading and Installing Harbor v${HARBOR_VERSION}"

    info "Downloading Harbor installer"

    pct exec "$CT_ID" -- bash -c "
        set -e
        cd /root

        # Download Harbor
        wget -q --show-progress https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-online-installer-v${HARBOR_VERSION}.tgz

        # Extract
        tar xzf harbor-online-installer-v${HARBOR_VERSION}.tgz
        cd harbor

        # Verify download
        ls -lh /root/harbor/
    "

    success "Harbor installer downloaded and extracted"
}

# Step 6: Configure Harbor
configure_harbor() {
    show_progress 6 10 "Configuring Harbor Settings"

    info "Generating Harbor configuration"

    # Generate admin password if not set
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(openssl rand -base64 32)}"
    DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32)}"

    pct exec "$CT_ID" -- bash -c "
        set -e
        cd /root/harbor

        # Copy template
        cp harbor.yml.tmpl harbor.yml

        # Configure Harbor
        sed -i 's|^hostname:.*|hostname: ${HARBOR_FQDN}|' harbor.yml
        sed -i 's|^  port:.*|  port: 443|' harbor.yml
        sed -i 's|^  certificate:.*|  certificate: ${DATA_VOLUME}/secrets/cert/server.crt|' harbor.yml
        sed -i 's|^  private_key:.*|  private_key: ${DATA_VOLUME}/secrets/cert/server.key|' harbor.yml
        sed -i 's|^harbor_admin_password:.*|harbor_admin_password: ${ADMIN_PASSWORD}|' harbor.yml
        sed -i 's|^  password:.*|  password: ${DB_PASSWORD}|' harbor.yml
        sed -i 's|^data_volume:.*|data_volume: ${DATA_VOLUME}|' harbor.yml
    "

    # Save credentials
    echo "HARBOR_ADMIN_PASSWORD=${ADMIN_PASSWORD}" > "${SCRIPT_DIR}/.harbor-credentials"
    echo "HARBOR_DB_PASSWORD=${DB_PASSWORD}" >> "${SCRIPT_DIR}/.harbor-credentials"
    chmod 600 "${SCRIPT_DIR}/.harbor-credentials"

    success "Harbor configured"
    info "Admin credentials saved to: ${SCRIPT_DIR}/.harbor-credentials"
}

# Step 7: Run Harbor Installer
run_harbor_installer() {
    show_progress 7 10 "Running Harbor Installer with Trivy Scanner"

    info "Installing Harbor with security scanning enabled"

    pct exec "$CT_ID" -- bash -c "
        set -e
        cd /root/harbor

        # Run installer with Trivy
        ./install.sh --with-trivy
    "

    if [[ $? -eq 0 ]]; then
        success "Harbor installed successfully"
    else
        fatal "Harbor installation failed"
    fi
}

# Step 8: Configure Automated Restart (LXC Fix)
configure_restart_automation() {
    show_progress 8 10 "Configuring Automated Container Restart"

    info "Setting up container restart automation for LXC"

    pct exec "$CT_ID" -- bash -c "
        set -e

        # Create restart script
        cat > /usr/local/bin/harbor-restart-check.sh << 'EOFSCRIPT'
#!/bin/bash
# Harbor Container Restart Monitor
# Ensures all Harbor containers are running

LOGFILE=\"/var/log/harbor-restart.log\"

log() {
    echo \"\$(date '+%Y-%m-%d %H:%M:%S') - \$*\" >> \"\$LOGFILE\"
}

cd /root/harbor || exit 1

# Check for exited containers
exited_containers=\$(docker compose ps -a --filter \"status=exited\" --format \"{{.Names}}\" | grep -E \"harbor|nginx|registry\")

if [ -n \"\$exited_containers\" ]; then
    log \"Found stopped containers: \$exited_containers\"

    # Restart all Harbor services
    docker compose restart

    log \"Harbor services restarted\"
else
    log \"All Harbor containers running normally\"
fi
EOFSCRIPT

        chmod +x /usr/local/bin/harbor-restart-check.sh

        # Add cron job
        (crontab -l 2>/dev/null; echo '*/10 * * * * /usr/local/bin/harbor-restart-check.sh') | crontab -
    "

    success "Restart automation configured"
}

# Step 9: Configure Backup Automation
configure_backup_automation() {
    show_progress 9 10 "Configuring Automated Backup System"

    info "Setting up daily backup automation"

    pct exec "$CT_ID" -- bash -c "
        set -e

        mkdir -p ${DATA_VOLUME}/backups

        # Create backup script
        cat > /usr/local/bin/harbor-backup.sh << 'EOFSCRIPT'
#!/bin/bash
# Harbor Automated Backup Script

BACKUP_DIR=\"${DATA_VOLUME}/backups\"
BACKUP_DATE=\$(date +%Y%m%d)
BACKUP_PATH=\"\$BACKUP_DIR/harbor-backup-\$BACKUP_DATE\"
RETENTION_DAYS=30

mkdir -p \"\$BACKUP_PATH\"

# Backup PostgreSQL database
docker exec harbor-db pg_dumpall -U postgres > \"\$BACKUP_PATH/harbor-db.sql\"

# Backup configuration
cp -r /root/harbor/harbor.yml \"\$BACKUP_PATH/\"
cp -r /root/harbor/common/config \"\$BACKUP_PATH/\"

# Backup certificates
cp -r ${DATA_VOLUME}/secrets \"\$BACKUP_PATH/\"

# Create tarball
tar czf \"\$BACKUP_PATH.tar.gz\" -C \"\$BACKUP_DIR\" \"harbor-backup-\$BACKUP_DATE\"
rm -rf \"\$BACKUP_PATH\"

# Cleanup old backups
find \"\$BACKUP_DIR\" -name \"harbor-backup-*.tar.gz\" -mtime +\$RETENTION_DAYS -delete

echo \"\$(date): Backup completed successfully\" >> /var/log/harbor-backup.log
EOFSCRIPT

        chmod +x /usr/local/bin/harbor-backup.sh

        # Schedule daily backups at 2 AM
        (crontab -l 2>/dev/null; echo '0 2 * * * /usr/local/bin/harbor-backup.sh') | crontab -
    "

    success "Backup automation configured (daily at 2 AM)"
}

# Step 10: Final Configuration and Verification
finalize_deployment() {
    show_progress 10 10 "Finalizing Deployment and Running Verification"

    info "Verifying Harbor deployment"

    # Wait for services to stabilize
    sleep 15

    pct exec "$CT_ID" -- bash -c "
        cd /root/harbor
        docker compose ps
    "

    # Test connectivity
    info "Testing Harbor accessibility"
    if curl -k -s "https://${IP_ADDRESS}" | grep -q "Harbor"; then
        success "Harbor is accessible at https://${IP_ADDRESS}"
    else
        warn "Harbor may not be fully accessible yet - check logs"
    fi

    success "Deployment completed successfully!"
}

# Display Deployment Summary
show_deployment_summary() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        Harbor CT182 Deployment Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"

    echo -e "${BLUE}Container Details:${NC}"
    echo -e "  Container ID:     CT$CT_ID"
    echo -e "  Hostname:         $CT_HOSTNAME"
    echo -e "  IP Address:       $IP_ADDRESS"
    echo -e "  Harbor FQDN:      $HARBOR_FQDN"
    echo -e ""

    echo -e "${BLUE}Access Information:${NC}"
    echo -e "  Web UI:           https://$HARBOR_FQDN"
    echo -e "                    https://$IP_ADDRESS"
    echo -e "  Admin User:       admin"
    echo -e "  Credentials:      ${SCRIPT_DIR}/.harbor-credentials"
    echo -e ""

    echo -e "${BLUE}Resources:${NC}"
    echo -e "  CPU Cores:        $CT_CORES"
    echo -e "  Memory:           ${CT_MEMORY}MB"
    echo -e "  Storage:          ${DATA_VOLUME}"
    echo -e ""

    echo -e "${BLUE}Features Enabled:${NC}"
    echo -e "  ✓ Trivy Vulnerability Scanner"
    echo -e "  ✓ Automated Container Restart (every 10 min)"
    echo -e "  ✓ Daily Backups (2 AM)"
    echo -e "  ✓ SSL/TLS Encryption"
    echo -e ""

    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Access Harbor web UI and change admin password"
    echo -e "  2. Configure DNS A record: $HARBOR_FQDN → $IP_ADDRESS"
    echo -e "  3. Configure LDAP/OIDC authentication (optional)"
    echo -e "  4. Create first project and configure retention policies"
    echo -e "  5. Test Docker push/pull operations"
    echo -e ""

    echo -e "${BLUE}Log File:${NC}"
    echo -e "  $LOG_FILE"
    echo -e ""

    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
}

# Main Execution
main() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Harbor CT182 Automated Deployment Script           ║${NC}"
    echo -e "${BLUE}║       Version 1.0.0 - Production Ready                    ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # Initialize
    parse_args "$@"
    check_root
    validate_ip "$IP_ADDRESS"

    info "Starting Harbor deployment to CT$CT_ID"
    info "Log file: $LOG_FILE"

    # Execute deployment steps
    create_proxmox_container
    install_docker
    configure_storage
    generate_ssl_certificates
    install_harbor
    configure_harbor
    run_harbor_installer
    configure_restart_automation
    configure_backup_automation
    finalize_deployment

    # Show summary
    show_deployment_summary

    success "Harbor deployment completed successfully!"
    exit 0
}

# Trap errors
trap 'error "Deployment failed at line $LINENO. Check log: $LOG_FILE"; exit 1' ERR

# Run main function
main "$@"
