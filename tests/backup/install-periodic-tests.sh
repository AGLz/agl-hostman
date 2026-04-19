#!/bin/bash
# =============================================================================
# Install Periodic Backup Restoration Tests
# =============================================================================
# Sets up systemd timer service for automated periodic restoration testing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="backup-restoration-test"
TIMER_NAME="backup-restoration-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Installing periodic backup restoration tests..."

# Install systemd service file
log_info "Installing systemd service..."
cp "${SCRIPT_DIR}/periodic-test.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload

log_info "Installing systemd timer..."
cp "${SCRIPT_DIR}/periodic-test.timer" "/etc/systemd/system/${TIMER_NAME}.timer"
systemctl daemon-reload

# Enable and start timer
log_info "Enabling timer..."
systemctl enable "${TIMER_NAME}.timer"

log_info "Starting timer..."
systemctl start "${TIMER_NAME}.timer"

# Show status
log_success "Installation complete!"
echo ""
log_info "Timer status:"
systemctl status "${TIMER_NAME}.timer" --no-pager
echo ""
log_info "Next scheduled run:"
systemctl list-timers "${TIMER_NAME}.timer" --no-pager
echo ""
log_info "View logs with:"
echo "  journalctl -u ${SERVICE_NAME}.service -f"
echo ""
log_info "Trigger manual test with:"
echo "  systemctl start ${SERVICE_NAME}.service"
