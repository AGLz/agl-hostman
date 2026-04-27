# NFS Storage Mount via WireGuard

**Type**: Infrastructure Configuration
**Category**: Storage Management
**Estimated Time**: 10-15 minutes

## Overview

Mount NFS storage from remote servers over WireGuard mesh for high-performance network storage access.

## Prerequisites

- [ ] WireGuard mesh is configured and operational
- [ ] Source NFS server is accessible via WireGuard (10.6.0.x)
- [ ] NFS client packages installed: `apt install nfs-common`
- [ ] Target mount point exists or can be created

## Specification

### Step 1: Verify WireGuard Connectivity
```bash
# Test connection to NFS server
ping -c 3 10.6.0.5  # FGSRV6
ping -c 3 10.6.0.11  # FGSRV5
ping -c 3 10.6.0.20  # CT111 (aluzdivina)

# Check WireGuard status
wg show
```

### Step 2: Test NFS Availability
```bash
# Check what shares are exported
showmount -e 10.6.0.5   # FGSRV6
showmount -e 10.6.0.20  # CT111

# Expected output example:
# Export list for 10.6.0.20:
# /mnt/shares   10.6.0.0/24,192.168.0.0/24
# /mnt/sistema  10.6.0.0/24,192.168.0.0/24
```

### Step 3: Create Mount Point
```bash
# Standard naming: /mnt/pve/<source>-wg
mkdir -p /mnt/pve/fgsrv6-wg
mkdir -p /mnt/pve/ct111-shares
mkdir -p /mnt/pve/ct111-sistema
```

### Step 4: Test Manual Mount
```bash
# Mount with NFSv4.2 for best performance
mount -t nfs -o vers=4.2 10.6.0.5:/ /mnt/pve/fgsrv6-wg
mount -t nfs -o vers=4.2 10.6.0.20:/mnt/shares /mnt/pve/ct111-shares
mount -t nfs -o vers=4.2 10.6.0.20:/mnt/sistema /mnt/pve/ct111-sistema

# Verify mount
df -h | grep wg
ls -la /mnt/pve/fgsrv6-wg
```

### Step 5: Add to /etc/fstab for Persistence
```bash
# Backup fstab first
cp /etc/fstab /etc/fstab.backup

# Add NFS mounts (with _netdev for network dependency)
cat >> /etc/fstab <<'EOF'

# NFS over WireGuard Mesh
10.6.0.5:/        /mnt/pve/fgsrv6-wg      nfs vers=4.2,_netdev 0 0
10.6.0.20:/mnt/shares   /mnt/pve/ct111-shares   nfs vers=4.2,_netdev 0 0
10.6.0.20:/mnt/sistema  /mnt/pve/ct111-sistema  nfs vers=4.2,_netdev 0 0
EOF

# Test fstab syntax
mount -a
```

### Step 6: Configure Proxmox Storage (if on Proxmox host)
```bash
# Add storage to Proxmox configuration
pvesm add nfs fgsrv6-wg \
  --server 10.6.0.5 \
  --export / \
  --content vztmpl,backup,iso,snippets \
  --options vers=4.2

pvesm add nfs ct111-shares \
  --server 10.6.0.20 \
  --export /mnt/shares \
  --content vztmpl,backup \
  --options vers=4.2

pvesm add nfs ct111-sistema \
  --server 10.6.0.20 \
  --export /mnt/sistema \
  --content vztmpl,backup,iso \
  --options vers=4.2

# Verify storage
pvesm status
```

## Performance Benchmarking

### Step 7: Benchmark Performance
```bash
# Write test
dd if=/dev/zero of=/mnt/pve/fgsrv6-wg/test.bin bs=1M count=1024 oflag=direct
# Target: >100 MB/s over WireGuard

# Read test
dd if=/mnt/pve/fgsrv6-wg/test.bin of=/dev/null bs=1M iflag=direct
# Target: >100 MB/s over WireGuard

# Cleanup
rm /mnt/pve/fgsrv6-wg/test.bin
```

**Expected Performance** (WireGuard mesh):
- **FGSRV6 (10.6.0.5)**: 500-1700 MB/s (cloud VPS, varies by network)
- **FGSRV5 (10.6.0.11)**: 500-1700 MB/s (cloud VPS)
- **CT111 (10.6.0.20)**: 100-200 MB/s (LAN uplink bottleneck)

## Troubleshooting

### Mount Hangs or Times Out
**Symptom**: `mount` command hangs or times out
**Causes**:
- WireGuard not connected
- NFS server not running or not exporting
- Firewall blocking NFS ports (2049)

**Fix**:
```bash
# Check WireGuard
wg show

# Check NFS service on server
ssh root@10.6.0.5 'systemctl status nfs-server'

# Try manual mount with timeout
mount -t nfs -o vers=4.2,timeout=30 10.6.0.5:/ /mnt/pve/test
```

### Stale NFS Handle
**Symptom**: `ls` shows "Stale NFS file handle"
**Fix**:
```bash
# Force unmount
umount -f /mnt/pve/fgsrv6-wg

# Remount
mount -a
```

### Permission Denied
**Symptom**: Cannot write to NFS mount
**Cause**: NFS export options or UID/GID mismatch
**Fix**:
```bash
# Check exports on server
ssh root@10.6.0.5 'cat /etc/exports'

# Expected:
# /  10.6.0.0/24(rw,sync,no_subtree_check,no_root_squash)

# Verify you can write
touch /mnt/pve/fgsrv6-wg/test.txt
```

## Success Criteria

- [ ] Manual mount succeeds without errors
- [ ] `df -h` shows mounted NFS filesystem
- [ ] Can read and write files to mount
- [ ] Mount persists after reboot (test with `mount -a`)
- [ ] Performance meets expected targets (>100 MB/s for WireGuard)
- [ ] Proxmox storage visible in UI (if applicable)
- [ ] Documentation updated

## Comparison: NFS vs SSHFS

| Aspect | NFS over WireGuard | SSHFS over WireGuard |
|--------|-------------------|----------------------|
| **Performance** | 500-1700 MB/s | 15-20 MB/s |
| **Latency** | Low (~15-20ms) | Higher (SSH overhead) |
| **Setup** | Requires NFS server | Only needs SSH |
| **Security** | WireGuard encryption | SSH + WireGuard double encryption |
| **Use Case** | Primary storage | Backup/secondary access |

**Recommendation**: Always use NFS over WireGuard when possible. Use SSHFS only when NFS is unavailable.

## Related Workflows

- [WireGuard Peer Setup](./wireguard-peer-setup.md)
- [SSHFS Backup Mount](./sshfs-backup-mount.md)
- [Storage Performance Tuning](./storage-performance.md)
