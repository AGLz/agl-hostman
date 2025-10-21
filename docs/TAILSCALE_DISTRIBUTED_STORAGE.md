# Distributed Storage - Current State and Migration Plan

**Date**: 2025-10-16
**Scope**: SSHFS mounts on AGLSRV1 from man6 host

## Current Configuration

### SSHFS Mounts (Tailscale)

AGLSRV1 currently has 2 SSHFS mounts using **Tailscale** network:

| Mount Point | Source | Protocol | Network |
|-------------|--------|----------|---------|
| `/mnt/remote-storage/aglsrv6-bb` | `root@100.98.108.66:/mnt/pve/bb` | SSHFS | Tailscale |
| `/mnt/remote-storage/aglsrv6-usb4tb` | `root@100.98.108.66:/mnt/usb4tb-direct` | SSHFS | Tailscale |

**Host**: man6 (100.98.108.66 via Tailscale)
**Status**: ✅ Active and operational

### SSHFS Options
```
-o allow_other,default_permissions,reconnect,ServerAliveInterval=15,compression=no,Ciphers=aes128-gcm@openssh.com,cache=yes
```

## Storage Analysis

### CT111 (aluzdivina) on man6

The CT111 container on man6 host contains the actual storage:

**Mount Points Inside CT111**:
- `mp0`: `/mnt/shares` (XFS - /dev/mapper/pve-root - 66GB)
- `mp1`: `/mnt/sistema` (ZFS - rpool/sistema - 819GB)
- `mp2`: `/mnt/pve/bb` → `/mnt/bb` (CIFS mount from 192.168.0.203)
- `mp3`: `/mnt/usb4tb-direct/backup` → `/mnt/bkp` (ExFAT - /dev/sde3 - 3.9TB)

### NFS Configuration on CT111

**NFS Server**: ✅ Configured and running
**Exports**:
```
/mnt/shares  192.168.0.0/24,10.6.0.0/24 (rw,sync,no_subtree_check,no_root_squash)
/mnt/sistema 192.168.0.0/24,10.6.0.0/24 (rw,sync,no_subtree_check,no_root_squash)
```

**Note**: `/mnt/bb` (CIFS) and `/mnt/bkp` (ExFAT) cannot be exported via NFS

### WireGuard Status

**CT111 WireGuard**:
- IP: 10.6.0.20
- Status: Configured but no routing (handshake OK, ping fails)
- Public Key: `j1r5kjpucqemhdV+7tbmtkGxr4isk0BUJHxJHVR1oCA=`

**man6 Host**:
- ❌ No WireGuard configuration (only CT111 inside has it)
- ✅ Has Tailscale: 100.98.108.66

## Migration Challenges

### 1. NFS Access Issues
- **Problem**: NFS from CT111 not accessible externally
- **Cause**: Network/firewall blocking between AGLSRV1 and man6
- **Status**: Unresolved

### 2. WireGuard Routing
- **Problem**: CT111 has WireGuard configured but no routing to mesh
- **Symptoms**: Handshake with hub succeeds, but ping to any peer fails
- **Possible Causes**:
  - LXC container networking limitations
  - Missing routes or NAT configuration
  - Firewall rules blocking forwarding

### 3. man6 Host WireGuard
- **Problem**: man6 host itself does not have WireGuard
- **Current**: Only CT111 inside man6 has WireGuard (10.6.0.20)
- **Impact**: Cannot use WireGuard for SSHFS to man6 host

## Migration Options

### Option 1: Configure WireGuard on man6 Host (Recommended)

**Steps**:
1. Install WireGuard on man6 Proxmox host
2. Assign IP (suggested: 10.6.0.21 or reuse AGLSRV6 IP from docs)
3. Add peer to FGSRV6 hub
4. Test connectivity from AGLSRV1
5. Migrate SSHFS from Tailscale IP to WireGuard IP

**Pros**:
- Direct host-to-host connection
- Better performance than through container
- Simpler configuration

**Cons**:
- Requires Proxmox host configuration
- Need to ensure WireGuard module loaded

### Option 2: Fix CT111 WireGuard Routing

**Steps**:
1. Debug routing issues in CT111
2. Configure NAT/forwarding on man6 host
3. Enable IP forwarding in container
4. Add specific routes

**Pros**:
- WireGuard already configured
- No host changes needed

**Cons**:
- Complex LXC networking
- May have performance overhead
- Harder to troubleshoot

### Option 3: Keep Current Tailscale Setup

**Steps**:
- None (maintain status quo)

**Pros**:
- Working and stable
- No migration risk
- Zero downtime

**Cons**:
- Not using WireGuard mesh
- Mixed networking (some Tailscale, some WireGuard)
- Dependent on Tailscale service

## Recommended Next Steps

1. **Short term**: Keep SSHFS via Tailscale (current state - stable)

2. **Medium term**: Configure WireGuard on man6 Proxmox host
   ```bash
   # On man6 host (100.98.108.66)
   apt-get install wireguard
   # Generate keys
   # Configure wg0 with IP 10.6.0.21
   # Add peer to FGSRV6 hub
   # Test connectivity
   # Migrate SSHFS mounts
   ```

3. **Long term**: Consider migrating from SSHFS to NFS
   - Requires resolving network/firewall issues
   - Better performance than SSHFS
   - More native to Proxmox environment

## Current Network Topology

```
AGLSRV1 (10.6.0.10 WG / 100.107.113.33 TS)
    ↓ SSHFS via Tailscale
    ↓ 100.98.108.66
    ↓
man6 Host (100.98.108.66 TS only)
    └─ CT111 (aluzdivina)
        ├─ WireGuard: 10.6.0.20 (no routing)
        ├─ Tailscale: (inherited from host)
        ├─ NFS Server: configured but inaccessible
        └─ Storage:
            ├─ /mnt/shares (66GB XFS)
            ├─ /mnt/sistema (819GB ZFS)
            ├─ /mnt/bb (CIFS from 192.168.0.203)
            └─ /mnt/bkp (3.9TB ExFAT)
```

## Related Documentation

- [WireGuard Deployment Status](wireguard/DEPLOYMENT-STATUS-UPDATE.md)
- [Storage Rename NFS to WG](wireguard/STORAGE-RENAME-NFS-TO-WG.md)
- [FGSRV6 NFS Migration](wireguard/FGSRV6-NFS-MIGRATION.md)

## Status Summary

| Component | Status | Network | Notes |
|-----------|--------|---------|-------|
| SSHFS aglsrv6-bb | ✅ Working | Tailscale | Via 100.98.108.66 |
| SSHFS aglsrv6-usb4tb | ✅ Working | Tailscale | Via 100.98.108.66 |
| CT111 NFS | ⚠️ Configured | N/A | Not accessible |
| CT111 WireGuard | ⚠️ Partial | WireGuard | No routing |
| man6 WireGuard | ❌ Missing | N/A | Needs setup |

---

**Last Updated**: 2025-10-16
**Status**: SSHFS operational via Tailscale, WireGuard migration pending
**Next Action**: Configure WireGuard on man6 Proxmox host
