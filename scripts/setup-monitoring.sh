#!/bin/bash
# One-shot setup script to install monitoring on agldv03
# Creates log dir, installs systemd units, enables timer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYSTEMD_SRC="${REPO_ROOT}/config/systemd"
SYSTEMD_DEST="/etc/systemd/system"
LOG_DIR="/var/log/hostman"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}>>>${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

step "Creating log directory: ${LOG_DIR}"
mkdir -p "${LOG_DIR}"
chmod 755 "${LOG_DIR}"

step "Installing systemd units to ${SYSTEMD_DEST}"
cp "${SYSTEMD_SRC}/hostman-monitor.service" "${SYSTEMD_DEST}/"
cp "${SYSTEMD_SRC}/hostman-monitor.timer"   "${SYSTEMD_DEST}/"

step "Making monitoring scripts executable"
chmod +x "${REPO_ROOT}/scripts/monitoring/"*.sh

step "Reloading systemd daemon"
systemctl daemon-reload

step "Enabling and starting hostman-monitor.timer"
systemctl enable --now hostman-monitor.timer

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo ""
echo "To run the morning briefing manually:"
echo "  ${REPO_ROOT}/scripts/monitoring/morning-briefing.sh"
echo ""
echo "To check timer status:"
echo "  systemctl status hostman-monitor.timer"
echo ""
echo "To watch journal output:"
echo "  journalctl -u hostman-monitor.service -f"
