#!/bin/bash
# ZFS Critical Troubleshooting Diagnostic Script
# Server: 100.69.9.111 (Proxmox)
# Issue: Boot failure after rpool expansion

set -e

echo "=== ZFS CRITICAL TROUBLESHOOTING DIAGNOSTIC ==="
echo "Server: $(hostname)"
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo ""

echo "=== PHASE 1: SYSTEM STATUS CHECK ==="
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "System state:"
systemctl is-system-running 2>/dev/null || echo "systemctl not available or system degraded"
echo ""

echo "=== PHASE 2: HARDWARE DETECTION ==="
echo "All block devices:"
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINT 2>/dev/null || echo "lsblk failed"
echo ""

echo "NVMe devices specifically:"
ls -la /dev/nvme* 2>/dev/null || echo "No NVMe devices found in /dev/"
echo ""

echo "Device IDs (for ZFS identification):"
ls -la /dev/disk/by-id/ 2>/dev/null || echo "/dev/disk/by-id/ not accessible"
echo ""

echo "=== PHASE 3: ZFS STATUS CHECK ==="
echo "ZFS service status:"
systemctl status zfs-import-cache zfs-import.target zfs.target 2>/dev/null || echo "ZFS services status unavailable"
echo ""

echo "Current ZFS pools:"
zpool list 2>/dev/null || echo "zpool command failed - ZFS may not be loaded"
echo ""

echo "ZFS rpool specific status:"
zpool status rpool 2>/dev/null || echo "rpool status unavailable - critical issue"
echo ""

echo "Available pools for import:"
zpool import 2>/dev/null || echo "No pools available for import or zpool import failed"
echo ""

echo "=== PHASE 4: BOOT AND MOUNT STATUS ==="
echo "Root filesystem mount:"
df -h / 2>/dev/null || echo "Root filesystem status unavailable"
echo ""

echo "All mounts:"
mount | grep -E "(zfs|rpool)" 2>/dev/null || echo "No ZFS mounts found"
echo ""

echo "=== PHASE 5: LOG ANALYSIS ==="
echo "Recent ZFS-related kernel messages:"
dmesg | grep -i zfs | tail -20 2>/dev/null || echo "No ZFS kernel messages or dmesg unavailable"
echo ""

echo "ZFS module status:"
lsmod | grep zfs 2>/dev/null || echo "ZFS module not loaded"
echo ""

echo "=== PHASE 6: BOOT CONFIGURATION ==="
echo "GRUB ZFS entries:"
grep -i zfs /boot/grub/grub.cfg 2>/dev/null | head -5 || echo "GRUB config not accessible"
echo ""

echo "=== DIAGNOSTIC COMPLETE ==="
echo "If this script runs successfully, the system is accessible."
echo "Next step: Analyze output and determine recovery strategy."