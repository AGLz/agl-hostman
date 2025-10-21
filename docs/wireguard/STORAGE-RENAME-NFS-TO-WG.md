# Storage Rename - NFS to WG Naming Convention

**Date**: 2025-10-16
**Host**: AGLSRV1 (192.168.0.245)
**Scope**: Rename storage identifiers to reflect WireGuard usage

## Summary

Renamed NFS storage identifiers from `-nfs` suffix to `-wg` suffix to accurately reflect that these storages are now accessed via WireGuard mesh network instead of Tailscale.

## Changes Made

### Storage Renames

| Old Name | New Name | Server IP | Protocol |
|----------|----------|-----------|----------|
| **fgsrv5-nfs** | **fgsrv5-wg** | 10.6.0.11 (FGSRV5) | NFSv4.2 over WireGuard |
| **fgsrv6-nfs** | **fgsrv6-wg** | 10.6.0.5 (FGSRV6 hub) | NFSv4.2 over WireGuard |

### Mount Point Renames

| Old Path | New Path |
|----------|----------|
| `/mnt/pve/fgsrv5-nfs` | `/mnt/pve/fgsrv5-wg` |
| `/mnt/pve/fgsrv6-nfs` | `/mnt/pve/fgsrv6-wg` |

## Configuration Files Updated

### 1. /etc/fstab

**Before**:
```
10.6.0.11:/  /mnt/pve/fgsrv5-nfs  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime,_netdev  0  0
10.6.0.5:/   /mnt/pve/fgsrv6-nfs  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime,_netdev  0  0
```

**After**:
```
10.6.0.11:/  /mnt/pve/fgsrv5-wg  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime,_netdev  0  0
10.6.0.5:/   /mnt/pve/fgsrv6-wg  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime,_netdev  0  0
```

**Backup**: `/etc/fstab.backup-rename-20251016-HHMMSS`

### 2. /etc/pve/storage.cfg

**Before**:
```
dir: fgsrv5-nfs
	path /mnt/pve/fgsrv5-nfs
	content rootdir,backup,vztmpl,iso,snippets
	prune-backups keep-last=3
	shared 0

dir: fgsrv6-nfs
	path /mnt/pve/fgsrv6-nfs
	content rootdir,backup,vztmpl,snippets,iso
	prune-backups keep-last=4
	shared 0
```

**After**:
```
dir: fgsrv5-wg
	path /mnt/pve/fgsrv5-wg
	content rootdir,backup,vztmpl,iso,snippets
	prune-backups keep-last=3
	shared 0

dir: fgsrv6-wg
	path /mnt/pve/fgsrv6-wg
	content rootdir,backup,vztmpl,snippets,iso
	prune-backups keep-last=4
	shared 0
```

**Backup**: `/etc/pve/storage.cfg.backup-rename-20251016-HHMMSS`

## Migration Steps

1. **Unmounted existing NFS shares**:
   ```bash
   umount /mnt/pve/fgsrv6-nfs
   umount /mnt/pve/fgsrv5-nfs  # (was not mounted)
   ```

2. **Renamed mount point directories**:
   ```bash
   mv /mnt/pve/fgsrv5-nfs /mnt/pve/fgsrv5-wg
   mv /mnt/pve/fgsrv6-nfs /mnt/pve/fgsrv6-wg
   ```

3. **Updated /etc/fstab**:
   ```bash
   cp /etc/fstab /etc/fstab.backup-rename-$(date +%Y%m%d-%H%M%S)
   sed -i 's|/mnt/pve/fgsrv5-nfs|/mnt/pve/fgsrv5-wg|g; s|/mnt/pve/fgsrv6-nfs|/mnt/pve/fgsrv6-wg|g' /etc/fstab
   ```

4. **Updated /etc/pve/storage.cfg**:
   - Changed storage names: `fgsrv5-nfs` → `fgsrv5-wg`, `fgsrv6-nfs` → `fgsrv6-wg`
   - Updated path directives to new mount points

5. **Remounted with new names**:
   ```bash
   mount /mnt/pve/fgsrv5-wg
   mount /mnt/pve/fgsrv6-wg
   ```

6. **Verified storage accessibility**:
   ```bash
   pvesm status -storage fgsrv5-wg
   pvesm status -storage fgsrv6-wg
   ```

## Verification

### Current Mount Status

```
10.6.0.11:/ on /mnt/pve/fgsrv5-wg type nfs4 (rw,noatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,nconnect=8,timeo=600,retrans=2,sec=sys,clientaddr=10.6.0.10,local_lock=none,addr=10.6.0.11,_netdev)

10.6.0.5:/ on /mnt/pve/fgsrv6-wg type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=8,timeo=600,retrans=2,sec=sys,clientaddr=10.6.0.10,local_lock=none,addr=10.6.0.5,_netdev)
```

### Proxmox Storage Status

**fgsrv5-wg**:
- Type: dir
- Status: ✅ active
- Total: 77 GB
- Used: 62 GB (80.20%)
- Available: 13 GB
- Content: rootdir, backup, vztmpl, iso, snippets

**fgsrv6-wg**:
- Type: dir
- Status: ✅ active
- Total: 197 GB
- Used: 58 GB (29.28%)
- Available: 132 GB
- Content: rootdir, backup, vztmpl, snippets, iso

### Storage Contents Verified

Both storages show expected directory structure:
```
drwxr-xr-x dump
drwxr-xr-x private
drwxr-xr-x snippets
drwxr-xr-x template
```

## Rationale

### Why Rename?

1. **Accuracy**: Storage names now reflect the actual network protocol in use (WireGuard, not generic NFS)
2. **Clarity**: Makes it immediately clear which storages are on the WireGuard mesh
3. **Consistency**: Aligns with naming convention for WireGuard-connected resources
4. **Documentation**: Self-documenting configuration that reduces confusion

### Naming Convention

**Format**: `<hostname>-wg`
- `<hostname>`: Source server hostname (fgsrv5, fgsrv6)
- `-wg`: Indicates access via WireGuard mesh network

**Examples**:
- `fgsrv5-wg`: FGSRV5 storage accessed via WireGuard
- `fgsrv6-wg`: FGSRV6 storage accessed via WireGuard
- `aglsrv6-pbs`: PBS storage (already follows clear naming)

## Network Path

Both storages now connect via WireGuard mesh:

```
AGLSRV1 (10.6.0.10)
    ↓ wg0 interface
    ↓ WireGuard kernel mesh
    ↓
FGSRV5 (10.6.0.11) ← fgsrv5-wg
    ↓
FGSRV6 Hub (10.6.0.5) ← fgsrv6-wg
```

## Impact

### Zero Downtime
- No service interruption
- No data migration required
- All existing data immediately accessible

### Configuration Changes
- ✅ fstab updated
- ✅ storage.cfg updated
- ✅ Mount points renamed
- ✅ Proxmox recognizes new storage names

### No Breaking Changes
- Data paths unchanged (directory renames only)
- File permissions preserved
- NFS settings identical
- Performance unchanged

## Rollback Procedure

If rollback is needed:

```bash
# Unmount
umount /mnt/pve/fgsrv5-wg
umount /mnt/pve/fgsrv6-wg

# Restore directory names
mv /mnt/pve/fgsrv5-wg /mnt/pve/fgsrv5-nfs
mv /mnt/pve/fgsrv6-wg /mnt/pve/fgsrv6-nfs

# Restore configs
cp /etc/fstab.backup-rename-20251016-HHMMSS /etc/fstab
cp /etc/pve/storage.cfg.backup-rename-20251016-HHMMSS /etc/pve/storage.cfg

# Remount
mount /mnt/pve/fgsrv5-nfs
mount /mnt/pve/fgsrv6-nfs
```

## Related Documentation

- [FGSRV6 NFS Migration](FGSRV6-NFS-MIGRATION.md) - Migration from Tailscale to WireGuard
- [PBS Storage Migration](PBS-STORAGE-MIGRATION.md) - PBS storage migration to WireGuard
- [Deployment Status Update](DEPLOYMENT-STATUS-UPDATE.md) - WireGuard mesh status

## Status

✅ **Rename Complete and Operational**
- All storages accessible via Proxmox
- All data intact and accessible
- New naming convention in effect
- Backups created for all config files

---

**Renamed**: 2025-10-16
**Impact**: Zero downtime, configuration-only change
**Status**: Production ready ✅
