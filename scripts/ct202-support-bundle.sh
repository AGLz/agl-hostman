#!/bin/bash
# CT202 Support Bundle Collection Script
# Creates comprehensive diagnostic package for escalation
# Usage: ./ct202-support-bundle.sh

CTID=202
BUNDLE_DIR="/root/host-admin/claudedocs/ct202_support_$(date +%Y%m%d_%H%M%S)"

echo "Creating CT202 support bundle..."
echo "Target directory: $BUNDLE_DIR"

# Create bundle directory
mkdir -p "$BUNDLE_DIR"

# Run full diagnostic
echo "[1/7] Running comprehensive diagnostic..."
if [ -x /root/host-admin/scripts/ct202-diagnostic.sh ]; then
    /root/host-admin/scripts/ct202-diagnostic.sh "$BUNDLE_DIR/diagnostic_report.txt"
else
    echo "ERROR: ct202-diagnostic.sh not found or not executable" > "$BUNDLE_DIR/diagnostic_report.txt"
fi

# Collect configuration
echo "[2/7] Collecting configuration files..."
pct config $CTID > "$BUNDLE_DIR/container_config.txt" 2>&1
if [ -f /etc/pve/lxc/$CTID.conf ]; then
    cp /etc/pve/lxc/$CTID.conf "$BUNDLE_DIR/lxc_config.conf"
fi

# Collect logs
echo "[3/7] Collecting application logs..."
pct exec $CTID -- journalctl -u n8n -n 1000 --no-pager > "$BUNDLE_DIR/n8n_service.log" 2>&1
pct exec $CTID -- dmesg > "$BUNDLE_DIR/dmesg.log" 2>&1
pct exec $CTID -- cat /var/log/syslog 2>/dev/null | tail -500 > "$BUNDLE_DIR/syslog.log" 2>&1

# Collect system state
echo "[4/7] Collecting system state..."
pct exec $CTID -- df -h > "$BUNDLE_DIR/disk_usage.txt" 2>&1
pct exec $CTID -- free -m > "$BUNDLE_DIR/memory_info.txt" 2>&1
pct exec $CTID -- ps aux > "$BUNDLE_DIR/process_list.txt" 2>&1
pct exec $CTID -- netstat -tulpn > "$BUNDLE_DIR/network_ports.txt" 2>&1

# Collect baseline data (if exists)
echo "[5/7] Collecting baseline metrics..."
LATEST_BASELINE=$(ls -t /root/host-admin/claudedocs/ct202_baseline_*.log 2>/dev/null | head -1)
if [ -n "$LATEST_BASELINE" ]; then
    cp "$LATEST_BASELINE" "$BUNDLE_DIR/baseline_metrics.log"
fi

# Collect Proxmox host context
echo "[6/7] Collecting host context..."
{
    echo "=== Proxmox Version ==="
    pveversion -v
    echo ""
    echo "=== Storage Status ==="
    pvesm status
    echo ""
    echo "=== All Containers ==="
    pct list
    echo ""
    echo "=== Host Resources ==="
    free -m
    echo ""
    df -h
} > "$BUNDLE_DIR/proxmox_host_info.txt" 2>&1

# Create bundle metadata
echo "[7/7] Creating bundle metadata..."
{
    echo "CT202 Support Bundle"
    echo "===================="
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "Container ID: $CTID"
    echo "Bundle Directory: $BUNDLE_DIR"
    echo ""
    echo "Contents:"
    ls -lh "$BUNDLE_DIR"
} > "$BUNDLE_DIR/README.txt"

# Archive and compress
echo "Compressing bundle..."
BUNDLE_ARCHIVE="${BUNDLE_DIR}.tar.gz"
tar -czf "$BUNDLE_ARCHIVE" -C "$(dirname $BUNDLE_DIR)" "$(basename $BUNDLE_DIR)" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "Support bundle created successfully!"
    echo "============================================"
    echo "Archive: $BUNDLE_ARCHIVE"
    echo "Size: $(du -h "$BUNDLE_ARCHIVE" | cut -f1)"
    echo ""
    echo "To view contents:"
    echo "  tar -tzf $BUNDLE_ARCHIVE"
    echo ""
    echo "To extract:"
    echo "  tar -xzf $BUNDLE_ARCHIVE"
    echo ""
    echo "The uncompressed directory is also available at:"
    echo "  $BUNDLE_DIR"
else
    echo "ERROR: Failed to create archive"
    echo "Uncompressed bundle available at: $BUNDLE_DIR"
fi
