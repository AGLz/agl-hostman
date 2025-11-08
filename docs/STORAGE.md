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
