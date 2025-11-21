# CT138 fileserver5 - NFS/SMB Access Fix (AGLSRV5)

> **Status**: ✅ PARTIALLY RESOLVED
> **Date**: 2025-11-18
> **Issue**: macOS cannot access fgsrv4-fg_antigo share
> **Root Cause**: Missing IP configuration + fgsrv4 offline

---

## Summary

Fixed fileserver5 network configuration to allow macOS access via SMB, but discovered that fgsrv4 (10.6.0.16) is offline, preventing NFS mounts from being active.

---

## Original Problem

User reported unable to access SMB share `fgsrv4-fg_antigo` from macOS:
- Expected access: `smb://192.168.15.100/fgsrv4-fg_antigo`
- Issue: Connection refused / host not found

---

## Diagnosis

### Environment
- **Host**: AGLSRV5 (Proxmox VE)
- **Container**: CT138 (fileserver5)
- **Access Method**: Tailscale (100.119.223.113) → AGLSRV5 → CT138
- **Target Network**: 192.168.15.0/24 (AGLFG LAN)

### Issues Found

1. **Missing LAN IP** ✅ FIXED
   - **Expected**: 192.168.15.100 on eth0
   - **Found**: eth0 had NO IPv4 address (DHCP failed, only IPv6)
   - **Impact**: macOS could not reach fileserver5

2. **fgsrv4 Offline** ⚠️ REQUIRES INVESTIGATION
   - **Expected**: fgsrv4 at 10.6.0.16 (WireGuard)
   - **Found**: 100% packet loss, RPC timeout
   - **Impact**: NFS mounts empty, SMB shares empty

---

## Root Cause Analysis

### Network Configuration Issue

**File**: `/etc/network/interfaces` (CT138)

**Before (BROKEN)**:
```
auto eth0
iface eth0 inet dhcp     # DHCP failed - no IPv4 assigned
```

**After (FIXED)**:
```
auto eth0
iface eth0 inet static
	address 192.168.15.100/24
	gateway 192.168.15.1
```

### fgsrv4 Connectivity Issue

**Expected NFS Mounts** (from `ct138-fileserver5-aglsrv5-configuration.md`):
```bash
10.6.0.16:/var/www/fg_antigo → /mnt/fgsrv4-fg_antigo
10.6.0.16:/storage/nfs-export → /mnt/fgsrv4-nfs
```

**Current Status**:
- Directories exist: `/mnt/fgsrv4-fg_antigo/` and `/mnt/fgsrv4-nfs/`
- **But**: Both are empty (no active NFS mounts)
- **Reason**: fgsrv4 (10.6.0.16) unreachable

---

## Solution Applied

### 1. Fixed Network Configuration ✅

```bash
# Connected to AGLSRV5 via Tailscale
ssh root@100.119.223.113

# Added static IP to fileserver5 eth0
pct exec 138 -- ip addr add 192.168.15.100/24 dev eth0

# Verified connectivity
pct exec 138 -- ping 192.168.15.222  # Success!
```

**Result**: fileserver5 now has IP 192.168.15.100 on LAN

### 2. Verified SMB Configuration ✅

**Samba Status**: Active and running

**Configured Shares**:
```ini
[fgsrv4-nfs]
path = /mnt/fgsrv4-nfs
browseable = yes
writeable = yes
comment = FGSRV4 NFS Export via WireGuard

[fgsrv4-fg_antigo]
path = /mnt/fgsrv4-fg_antigo
browseable = yes
writeable = yes
comment = FGSRV4 fg_antigo via WireGuard (25GB)
```

### 3. Identified fgsrv4 Issue ⚠️

```bash
# Test connectivity to fgsrv4
pct exec 138 -- ping 10.6.0.16
# Result: 100% packet loss

# Test NFS exports
pct exec 138 -- showmount -e 10.6.0.16
# Result: RPC timeout
```

**Status**: fgsrv4 (10.6.0.16) is **offline or unreachable**

---

## Current State

### ✅ Working

1. **Network Configuration**
   - fileserver5 has IP 192.168.15.100
   - LAN connectivity verified (can ping AGLSRV5 gateway)
   - WireGuard mesh active (10.6.0.51)

2. **SMB Server**
   - Service running: `smbd` active
   - Shares configured for both fgsrv4 mounts
   - macOS can **connect** to shares

3. **NFS Server**
   - Service running: `nfs-server` active
   - Exports configured for 3 networks:
     - 10.6.0.0/24 (WireGuard)
     - 192.168.0.0/24 (Main LAN)
     - 192.168.15.0/24 (AGLFG LAN)

### ❌ Not Working

1. **fgsrv4 Connectivity**
   - Host at 10.6.0.16 unreachable
   - NFS mounts cannot be established
   - SMB shares are empty (no data)

---

## Access Instructions for macOS

### Connect to fileserver5

```bash
# Via Finder → Go → Connect to Server
smb://192.168.15.100/fgsrv4-fg_antigo

# Or via command line
mount -t smbfs //guest@192.168.15.100/fgsrv4-fg_antigo /mnt/fileserver5
```

**Current Result**: ✅ Connection succeeds, but shares are **empty**

---

## Next Steps

### 1. Investigate fgsrv4 Status

```bash
# Check if fgsrv4 is online
# Need to determine:
# - Is fgsrv4 a VPS or container?
# - Where is it hosted?
# - How to access it?
# - Is WireGuard running?

# From documentation clues:
# - fgsrv4 is mentioned in VPS-HOSTS-ACCESS-INFO.md
# - Listed as nginx/PHP5 server
# - Part of AGLFG-VPS cloud infrastructure
```

### 2. Verify fgsrv4 WireGuard Configuration

Once fgsrv4 is accessible:

```bash
# Check WireGuard status on fgsrv4
wg show

# Verify it has IP 10.6.0.16
ip addr show wg0

# Check NFS server is running
systemctl status nfs-server
```

### 3. Mount NFS Shares on fileserver5

After fgsrv4 is online:

```bash
# Mount fg_antigo
ssh root@100.119.223.113 'pct exec 138 -- mount -t nfs 10.6.0.16:/var/www/fg_antigo /mnt/fgsrv4-fg_antigo'

# Mount nfs-export
ssh root@100.119.223.113 'pct exec 138 -- mount -t nfs 10.6.0.16:/storage/nfs-export /mnt/fgsrv4-nfs'

# Verify mounts
ssh root@100.119.223.113 'pct exec 138 -- df -h | grep fgsrv4'
```

### 4. Make Network Configuration Persistent

```bash
# Update Proxmox CT config to use static IP
ssh root@100.119.223.113 'pct set 138 -net0 name=eth0,bridge=vmbr0,ip=192.168.15.100/24,gw=192.168.15.1'

# Or keep current manual config and fix /etc/network/interfaces
# (currently configured but systemd networking restart failed)
```

---

## Files Modified

### `/mnt/fgsrv4-fg_antigo/` and `/mnt/fgsrv4-nfs/`
- Directories exist but are empty
- **Action Needed**: Mount NFS shares when fgsrv4 comes online

### `/etc/network/interfaces` (CT138)
- Added static IP 192.168.15.100/24
- **Status**: Configured but requires systemd fix or CT restart to persist

---

## Testing Checklist

### After fgsrv4 is Online

- [ ] Verify fgsrv4 WireGuard connectivity (ping 10.6.0.16)
- [ ] Test NFS exports (showmount -e 10.6.0.16)
- [ ] Mount fg_antigo share on fileserver5
- [ ] Mount nfs-export share on fileserver5
- [ ] Verify SMB access from macOS shows data
- [ ] Make IP configuration persistent in Proxmox
- [ ] Test CT138 reboot (IP should persist)

---

## Reference Documentation

- **Original Config**: `docs/ct138-fileserver5-aglsrv5-configuration.md`
- **Network Topology**: `docs/TOPOLOGY.md`
- **Container Inventory**: `docs/CONTAINERS.md`
- **WireGuard Mesh**: `docs/WIREGUARD.md`

---

## Diagnostic Commands Used

```bash
# Check CT status
ssh root@100.119.223.113 'pct list | grep 138'

# Access fileserver5
ssh root@100.119.223.113 'pct exec 138 -- bash'

# Network diagnostics
pct exec 138 -- ip addr show
pct exec 138 -- ping 192.168.15.222
pct exec 138 -- ping 10.6.0.16

# Service status
pct exec 138 -- systemctl status smbd
pct exec 138 -- systemctl status nfs-server

# Check mounts
pct exec 138 -- mount | grep fgsrv4
pct exec 138 -- ls -la /mnt/

# Samba configuration
pct exec 138 -- cat /etc/samba/smb.conf
```

---

## Changelog

| Date | Change | Status |
|------|--------|--------|
| 2025-11-18 | Configured IP 192.168.15.100 on eth0 | ✅ Complete |
| 2025-11-18 | Verified SMB server and shares | ✅ Complete |
| 2025-11-18 | Identified fgsrv4 offline issue | ⚠️ Requires Action |
| 2025-11-18 | Documented diagnosis and solution | ✅ Complete |

---

**Status**: ✅ fileserver5 network fixed, ⚠️ fgsrv4 needs investigation
**Next Action**: Locate and restore fgsrv4 (10.6.0.16) connectivity
