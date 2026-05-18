#!/bin/bash
# Install NFS & Tailscale monitoring systemd service and timer
# Run this script on the monitoring host (typically AGLSRV1 or management machine)
#
# Usage: ./install-nfs-monitor-service.sh [--uninstall]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
SYSTEMD_DIR="/etc/systemd/system"

UNINSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "=========================================="
if [[ "${UNINSTALL}" == "true" ]]; then
  echo "Uninstalling NFS Monitor Service"
else
  echo "Installing NFS Monitor Service"
fi
echo "=========================================="

# Verify we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   echo "Usage: sudo $0"
   exit 1
fi

if [[ "${UNINSTALL}" == "true" ]]; then
  # Stop and disable services
  echo "Stopping services..."
  systemctl stop nfs-tailscale-monitor.timer 2>/dev/null || true
  systemctl stop nfs-tailscale-monitor.service 2>/dev/null || true

  # Disable services
  echo "Disabling services..."
  systemctl disable nfs-tailscale-monitor.timer 2>/dev/null || true
  systemctl disable nfs-tailscale-monitor.service 2>/dev/null || true

  # Remove systemd files
  echo "Removing systemd unit files..."
  rm -f "${SYSTEMD_DIR}/nfs-tailscale-monitor.service"
  rm -f "${SYSTEMD_DIR}/nfs-tailscale-monitor.timer"

  # Reload systemd
  systemctl daemon-reload

  echo "✅ NFS Monitor Service uninstalled successfully"
  exit 0
fi

# Installation
echo "Making scripts executable..."
chmod +x "${SCRIPT_DIR}/nfs-tailscale-monitor.sh"
chmod +x "${SCRIPT_DIR}/nfs-tailscale-recovery.sh"

echo "Creating log directory..."
mkdir -p "${SCRIPT_DIR}/../logs/nfs-monitor"

echo "Installing systemd unit files..."
cp "${PROJECT_ROOT}/config/systemd/nfs-tailscale-monitor.service" "${SYSTEMD_DIR}/"
cp "${PROJECT_ROOT}/config/systemd/nfs-tailscale-monitor.timer" "${SYSTEMD_DIR}/"

echo "Setting correct paths in systemd files..."
# Update paths in systemd files to match actual project location
sed -i "s|/mnt/overpower/apps/dev/agl/agl-hostman|${SCRIPT_DIR}/..|g" "${SYSTEMD_DIR}/nfs-tailscale-monitor.service"

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling timer..."
systemctl enable nfs-tailscale-monitor.timer

echo "Starting timer..."
systemctl start nfs-tailscale-monitor.timer

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Service Status:"
systemctl status nfs-tailscale-monitor.timer --no-pager | head -10
echo ""
echo "Next scheduled run:"
systemctl list-timers nfs-tailscale-monitor.timer --no-pager | tail -1
echo ""
echo "Manual test (dry run):"
echo "  sudo ${SCRIPT_DIR}/nfs-tailscale-monitor.sh --dry-run --verbose"
echo ""
echo "View logs:"
echo "  journalctl -u nfs-tailscale-monitor.service -f"
echo "  tail -f ${SCRIPT_DIR}/../logs/nfs-monitor/monitor-\$(date +%Y%m%d).log"
echo ""
echo "Uninstall:"
echo "  sudo $0 --uninstall"
echo ""
