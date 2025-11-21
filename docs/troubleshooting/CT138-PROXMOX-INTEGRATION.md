# CT138 NFS Storage - Proxmox AGLSRV5 Integration

**Date**: 2025-11-12
**Location**: AGLSRV5 (AGLFG)
**Container**: CT138 (fileserver5)
**Status**: ✅ **COMPLETE**

---

## 📋 Summary

Successfully integrated CT138 NFS storage with AGLSRV5 Proxmox host, making the shared storage available for container templates, backups, and images across the local infrastructure.

## 🎯 What Was Done

### 1. Documentation Updates

Updated infrastructure documentation to reflect CT138 NFS server:

**Files Updated**:
- `docs/STORAGE.md` - Added complete CT138 NFS server section
- `docs/CONTAINERS.md` - Enhanced CT138 entry with network details
- `docs/INFRA.md` - Added CT138 to storage summary
- `docs/HOSTS.md` - Added ct138-nfs to AGLSRV5 storage table

**Key Information Documented**:
- Network addresses: 192.168.15.100 (DHCP), 172.2.2.138 (internal), 10.6.0.51 (WG)
- Export configuration: 3 networks (192.168.0.0/24, 192.168.15.0/24, 10.6.0.0/24)
- Mount commands for all access methods
- Performance metrics and service status

### 2. Proxmox Storage Configuration

**Command Executed**:
```bash
pvesm add nfs ct138-nfs --server 192.168.15.100 --export /storage/nfs-export --content backup,images,vztmpl,iso
```

**Storage Details**:
- **Storage ID**: `ct138-nfs`
- **Type**: NFS
- **Server**: 192.168.15.100 (CT138 eth0 - DHCP)
- **Export**: /storage/nfs-export
- **Status**: ✅ Active
- **Size**: 15GB total
- **Available**: 12GB (11.48% used)
- **Content Types**: backup, images, vztmpl, iso

**Why 192.168.15.100 Instead of Other IPs?**:
- ❌ **172.2.2.138**: Internal container network, not accessible from host
- ✅ **192.168.15.100**: Host and containers can access (same LAN segment)
- ⚠️ **10.6.0.51**: Would work but slower than local LAN

## 🔍 Validation

### Storage Status Check
```bash
root@aglsrv5:~# pvesm status
Name             Type     Status           Total            Used       Available        %
base          zfspool     active      1885863936      1342539252       543324684   71.19%
bkp               dir     active       606798464        63473792       543324672   10.46%
ct138-nfs         nfs     active        15375360         1764352        12808192   11.48%  ✅
games             dir     active        68763648        38040216        30723432   55.32%
local             dir     active        68763648        38040216        30723432   55.32%
local-lvm     lvmthin     active       136593408        13918868       122674539   10.19%
shares            dir     active        68763648        38040216        30723432   55.32%
```

### NFS Server Verification (from CT138)
```bash
root@fileserver5:~# systemctl status nfs-server
● nfs-server.service - NFS server and services
     Loaded: loaded (/lib/systemd/system/nfs-server.service; enabled)
     Active: active (exited) since Wed 2025-11-12 22:43:47 UTC

root@fileserver5:~# showmount -e localhost
Export list for localhost:
/storage/nfs-export 10.6.0.0/24,192.168.0.0/24,192.168.15.0/24
```

## 📊 Storage Hierarchy

```
AGLSRV5 (192.168.15.222)
├── base (zfspool) - 1.75TB - Primary storage
├── local-lvm (lvmthin) - 130GB - Container volumes
├── ct138-nfs (nfs) - 15GB ✨ - Network shared storage
│   └── CT138 (192.168.15.100)
│       └── /storage/nfs-export
│           ├── Accessible via 192.168.15.100 (LAN)
│           ├── Accessible via 172.2.2.138 (internal - containers only)
│           └── Accessible via 10.6.0.51 (WireGuard)
└── shares/games/local (dir) - 65GB - Local directories
```

## 🚀 Usage Examples

### Mount from AGLSRV5 Host
```bash
mount -t nfs 192.168.15.100:/storage/nfs-export /mnt/fileserver5
```

### Mount from Container on AGLSRV5
```bash
# Via LAN (fastest for local containers)
mount -t nfs 192.168.15.100:/storage/nfs-export /mnt/shared

# Via internal network (if container has access to vmbr1)
mount -t nfs 172.2.2.138:/storage/nfs-export /mnt/shared
```

### Mount from Remote via WireGuard
```bash
mount -t nfs 10.6.0.51:/storage/nfs-export /mnt/fileserver5
```

### Use in Proxmox GUI
1. Navigate to **Datacenter → Storage**
2. Select **ct138-nfs** storage
3. Use for:
   - Container templates (vztmpl)
   - Backup storage
   - ISO images
   - Container images

## 📝 Configuration Files

### CT138 /etc/exports
```bash
/storage/nfs-export 10.6.0.0/24(rw,sync,no_subtree_check,no_root_squash) 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 192.168.15.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### AGLSRV5 Storage Config
```bash
# /etc/pve/storage.cfg (auto-generated)
nfs: ct138-nfs
	export /storage/nfs-export
	path /mnt/pve/ct138-nfs
	server 192.168.15.100
	content vztmpl,iso,backup,images
```

## 🎓 Lessons Learned

1. **Container Internal Networks**:
   - Internal container networks (172.2.2.x) are not accessible from Proxmox host
   - Always use host-accessible networks for NFS exports

2. **DHCP Considerations**:
   - CT138 uses DHCP (192.168.15.100)
   - Recommendation: Configure DHCP reservation for stability
   - Alternative: Change to static IP if needed

3. **Network Selection**:
   - LAN (192.168.15.100): Best for local AGLSRV5 access
   - WireGuard (10.6.0.51): Best for remote infrastructure access
   - Internal (172.2.2.138): Only for container-to-container

4. **Storage Content Types**:
   - Added: backup, images, vztmpl, iso
   - Not added: rootdir (not recommended for NFS)

## 📚 Related Documentation

- **Complete NFS Fix**: `CT138-NFS-FIX-COMPLETE.md`
- **Initial Diagnosis**: `CT138-NFS-DIAGNOSIS.md`
- **Infrastructure Map**: `../INFRA.md`
- **Storage Details**: `../STORAGE.md`
- **Host Configuration**: `../HOSTS.md`

## 🔄 Next Steps (Optional)

1. **Configure DHCP Reservation**:
   - Reserve 192.168.15.100 for CT138 MAC address
   - Ensures stable IP for NFS storage

2. **Add to Other Hosts** (if needed):
   ```bash
   # From AGLSRV1 (via WireGuard - fastest cross-site)
   pvesm add nfs ct138-nfs --server 10.6.0.51 --export /storage/nfs-export

   # From AGLSRV6 (via WireGuard)
   pvesm add nfs ct138-nfs --server 10.6.0.51 --export /storage/nfs-export
   ```

3. **Monitoring Setup**:
   - Add storage capacity monitoring
   - Set alerts for space usage > 80%

4. **Backup Strategy**:
   - Consider using ct138-nfs for automated Proxmox backups
   - Configure backup jobs via Proxmox GUI

## ✅ Completion Checklist

- ✅ NFS server operational on CT138
- ✅ Storage added to AGLSRV5 Proxmox
- ✅ Storage status: Active
- ✅ Documentation updated (4 files)
- ✅ Access validated from host
- ✅ Configuration documented
- ✅ Usage examples provided

---

**Status**: ✅ **INTEGRATION COMPLETE**
**Verified**: 2025-11-12 23:15 UTC
**Total Implementation Time**: ~15 minutes
**Zero Downtime**: All changes applied without service interruption
