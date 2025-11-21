# Storage Configuration and NFS Mounts

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: Storage infrastructure, NFS exports, and mount points

---

## 💾 AGLSRV1 Storage Overview

### Storage Mounts Summary

| Storage | Size | Type | Source | Path | Status |
|---------|------|------|--------|------|--------|
| local | 77GB | Local | Disk | - | ✅ |
| local-zfs | 1.7TB | ZFS | Pool | - | ✅ |
| fgsrv5-wg | 77GB | NFS | 10.6.0.11:/ | /mnt/pve/fgsrv5-wg | ✅ |
| fgsrv6-wg | 197GB | NFS | 10.6.0.5:/ | /mnt/pve/fgsrv6-wg | ✅ |
| ct111-shares | 66GB | NFS | 10.6.0.20:/mnt/shares | /mnt/pve/ct111-shares | ✅ |
| ct111-sistema | 818GB | NFS | 10.6.0.20:/mnt/sistema | /mnt/pve/ct111-sistema | ✅ |
| aglsrv6-bb | 954GB | SSHFS | 10.6.0.12:/mnt/pve/bb | /mnt/pve/aglsrv6-bb | ✅ |
| aglsrv6-usb4tb | 3.9TB | SSHFS | 10.6.0.12:/mnt/usb4tb-direct | /mnt/pve/aglsrv6-usb4tb | ✅ |
| aglsrv6-pbs | 1.2TB | PBS | - | - | ✅ |
| aglsrv6b-pbs | 1.0TB | PBS | - | - | ✅ |
| spark | 7.1TB | Local | Disk | - | ✅ 91.54% used |
| overpower | 9.8TB | Local | Disk | - | ✅ 92.54% used |

### Total WireGuard Storage: 6.0 TB

- **NFS**: 1.2TB (fgsrv5-wg + fgsrv6-wg + ct111-shares + ct111-sistema)
- **SSHFS**: 4.8TB (aglsrv6-bb + aglsrv6-usb4tb)

---

## 🔧 CT111 (aluzdivina) NFS Server

### Network Configuration

- **WireGuard**: 10.6.0.20 (Port 51820)
- **Tailscale**: 100.65.189.83
- **Host**: AGLSRV6 (AGLALD location)

### Storage Exports

| Mount Point | Size | Filesystem | Purpose | NFS Exported |
|-------------|------|------------|---------|--------------|
| /mnt/shares | 66GB | XFS | Shared files | ✅ |
| /mnt/sistema | 819GB | ZFS | System storage | ✅ |
| /mnt/bb | - | CIFS | Backup from 192.168.0.203 | ❌ |
| /mnt/bkp | 3.9TB | ExFAT | Large backups | ❌ |

### NFS Export Configuration

**Allowed Networks**:
- 192.168.0.0/24 (Local LAN)
- 10.6.0.0/24 (WireGuard mesh)

**Exports**:
```
/mnt/shares   *(rw,sync,no_subtree_check,no_root_squash)
/mnt/sistema  *(rw,sync,no_subtree_check,no_root_squash)
```

### Performance Metrics

- **Latency to hub**: 15-22ms
- **Mounted on AGLSRV1** as:
  - ct111-shares (66GB)
  - ct111-sistema (818GB)

---

## 🔧 CT138 (fileserver5) NFS Server

### Network Configuration

- **LAN (DHCP)**: 192.168.15.100
- **Internal**: 172.2.2.138
- **WireGuard**: 10.6.0.51
- **Host**: AGLSRV5 (AGLFG location)

### Storage Exports

| Mount Point | Size | Purpose | NFS Exported |
|-------------|------|---------|--------------|
| /storage/nfs-export | - | Network storage | ✅ |

### NFS Export Configuration

**Allowed Networks**:
- 192.168.0.0/24 (Remote LAN - AGLHQ)
- 192.168.15.0/24 (Local LAN - AGLFG)
- 10.6.0.0/24 (WireGuard mesh)

**Exports**:
```
/storage/nfs-export 10.6.0.0/24(rw,sync,no_subtree_check,no_root_squash) 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 192.168.15.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### Access Methods

```bash
# Via LAN local (DHCP)
mount -t nfs 192.168.15.100:/storage/nfs-export /mnt/fileserver5

# Via WireGuard (recommended - fixed IP)
mount -t nfs 10.6.0.51:/storage/nfs-export /mnt/fileserver5

# Via internal network (from AGLSRV5 host/containers)
mount -t nfs 172.2.2.138:/storage/nfs-export /mnt/fileserver5
```

### Performance Metrics

- **Port**: 2049 (listening on all interfaces)
- **Auto-start**: Enabled
- **Services**: nfs-server, rpcbind, idmapd all active

### Proxmox Integration

**AGLSRV5 Storage Configuration**:
- **Storage ID**: ct138-nfs
- **Server**: 192.168.15.100
- **Export**: /storage/nfs-export
- **Status**: ✅ Active
- **Size**: 15GB total, 12GB available (11.48% used)
- **Content Types**: backup, images, vztmpl, iso

### Notes

- Container uses DHCP on eth0 (gets 192.168.15.100)
- DHCP server exists on 192.168.15.0/24 network
- Gateway configuration removed from LXC (causes networking.service failure)
- Storage successfully added to AGLSRV5 Proxmox host
- See `docs/troubleshooting/CT138-NFS-FIX-COMPLETE.md` for configuration details

---

## 🌐 Cloud VPS NFS Servers

### FGSRV5 NFS Export

- **WireGuard IP**: 10.6.0.11
- **Export Size**: 77GB
- **Mount Point on AGLSRV1**: /mnt/pve/fgsrv5-wg
- **Provider**: vps24136.publiccloud.com.br

### FGSRV6 NFS Export

- **WireGuard IP**: 10.6.0.5 (Hub)
- **Export Size**: 197GB
- **Mount Point on AGLSRV1**: /mnt/pve/fgsrv6-wg
- **Provider**: vps41772.publiccloud.com.br
- **Critical**: Hub for entire WireGuard mesh

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md`
- **Network Topology**: `TOPOLOGY.md`
- **WireGuard Mesh**: `WIREGUARD.md`
- **Hosts Details**: `HOSTS.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
