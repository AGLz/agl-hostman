#!/bin/bash
################################################################################
# Harbor CT182 - Complete Deployment Script
# Orchestrates all deployment phases
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_phase() { echo -e "${BLUE}[PHASE]${NC} $1"; }
log_title() { echo -e "${CYAN}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export HARBOR_VERSION="${HARBOR_VERSION:-2.12.2}"
export HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.aglsrv1.local}"
export HARBOR_IP="${HARBOR_IP:-192.168.0.182}"
export HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"

log_title "═══════════════════════════════════════════════════"
log_title "  Harbor Container Registry - Complete Deployment"
log_title "═══════════════════════════════════════════════════"
echo ""
log_info "Configuration:"
log_info "  Harbor Version: $HARBOR_VERSION"
log_info "  Hostname: $HARBOR_HOSTNAME"
log_info "  IP Address: $HARBOR_IP"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Deployment phases
phases=(
    "01-install-docker.sh|Installing Docker and Docker Compose"
    "02-install-harbor.sh|Downloading and preparing Harbor"
    "03-configure-ssl.sh|Generating SSL certificates"
    "04-deploy-harbor.sh|Deploying Harbor services"
    "05-configure-harbor.sh|Configuring Harbor settings"
)

total_phases=${#phases[@]}
current_phase=0

# Execute each phase
for phase_entry in "${phases[@]}"; do
    IFS='|' read -r script description <<< "$phase_entry"
    ((current_phase++))

    echo ""
    log_phase "Phase $current_phase/$total_phases: $description"
    echo ""

    script_path="$SCRIPT_DIR/$script"

    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        exit 1
    fi

    chmod +x "$script_path"

    if ! "$script_path"; then
        log_error "Phase $current_phase failed: $description"
        log_error "Check the logs above for details"
        exit 1
    fi

    log_info "Phase $current_phase completed successfully ✓"
done

# Final summary
echo ""
log_title "═══════════════════════════════════════════════════"
log_title "  Deployment Completed Successfully!"
log_title "═══════════════════════════════════════════════════"
echo ""
log_info "Harbor Registry is now running at:"
log_info "  URL: https://$HARBOR_HOSTNAME"
log_info "  IP: https://$HARBOR_IP"
echo ""
log_info "Default credentials:"
log_info "  Username: admin"
log_info "  Password: $HARBOR_ADMIN_PASSWORD"
echo ""
log_warn "⚠️  IMPORTANT NEXT STEPS:"
log_warn "  1. Change the admin password immediately"
log_warn "  2. Add DNS entry: $HARBOR_HOSTNAME -> $HARBOR_IP"
log_warn "  3. Configure client machines to trust the CA certificate"
log_warn "  4. Set up regular backups"
log_warn "  5. Configure LDAP/OIDC for user authentication"
echo ""
log_info "Client setup command:"
echo "  # Copy CA certificate from CT182:/data/cert/ca.crt"
echo "  # Then on client:"
echo "  sudo mkdir -p /etc/docker/certs.d/$HARBOR_HOSTNAME"
echo "  sudo cp ca.crt /etc/docker/certs.d/$HARBOR_HOSTNAME/"
echo "  docker login $HARBOR_HOSTNAME"
echo ""
log_info "Documentation: /mnt/overpower/apps/dev/agl/agl-hostman/docs/"
log_info "Scripts: $SCRIPT_DIR"
echo ""

exit 0
