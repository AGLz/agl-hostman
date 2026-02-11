# FGSRV07 - Host Overview

**Documentation Created:** 2026-02-09
**Host Name:** FGSRV07
**Status:** 🆕 **NEW HOST - BASE INSTALLATION**
**Provider:** VPS Locaweb
**Primary IP:** 191.252.93.227
**OS:** Debian 13 (Current Debian Version)
**SSH Access:** ✅ Key Authorized

---

## 📋 Host Specifications

### Infrastructure Details

| Attribute | Value | Notes |
|-----------|-------|-------|
| **Host Name** | FGSRV07 | New Proxmox host designation |
| **Provider** | VPS Locaweb | Brazilian VPS provider |
| **Server Type** | VPS | Virtual Private Server |
| **Operating System** | Debian 13 | Current stable Debian release |
| **Primary IP** | 191.252.93.227 | Public IPv4 address |
| **SSH Access** | Key-based | Already authorized |
| **Installation Status** | Base OS | Fresh Debian 13 installation |

### Network Configuration

| Network Interface | IP Address | Purpose | Status |
|-------------------|------------|---------|--------|
| **Public IPv4** | 191.252.93.227 | Primary access | ✅ Active |
| **Tailscale** | *To be assigned* | VPN mesh network | ⏳ Pending setup |

---

## 🎯 Purpose and Role

### Primary Function
FGSRV07 is designated as a **new Proxmox host** in the infrastructure, expanding the FGSRV fleet with virtualization capabilities.

### Intended Uses
- **Proxmox VE Hypervisor**: Host virtual machines and containers
- **Tailscale Integration**: VPN connectivity for secure mesh networking
- **Infrastructure Expansion**: Additional capacity for services
- **Development/Testing**: Isolated environment for new deployments

### Infrastructure Relationships

**FGSRV Fleet Context:**
```
FGSRV03 (Ubuntu 20.04) - Legacy services
FGSRV04 (Ubuntu 22.04) - Active services
FGSRV05 (Ubuntu 22.04) - NFS storage (14GB)
FGSRV06 (Ubuntu 22.04) - NFS storage (132GB)
FGSRV07 (Debian 13)    - NEW: Proxmox hypervisor
```

**Integration Points:**
- **Tailscale Mesh**: Will join existing FGSRV tailnet
- **Storage Access**: Can mount NFS from FGSRV05/FGSRV06
- **Proxmox Cluster**: Potential clustering with other Proxmox hosts
- **Backup Targets**: Can serve as backup destination for CTs/VMs

---

## 🔧 Installation Status

### Current State: Base Installation

| Component | Status | Details |
|-----------|--------|---------|
| **Operating System** | ✅ Installed | Debian 13 base |
| **SSH Access** | ✅ Configured | Key authorized |
| **Network** | ✅ Active | 191.252.93.227 reachable |
| **Tailscale** | ⏳ Pending | To be installed |
| **Proxmox VE** | ⏳ Pending | To be installed |
| **Firewall** | ⏳ Pending | To be configured |
| **Storage Setup** | ⏳ Pending | To be configured |

### Required Installation Steps

1. **System Preparation**
   ```bash
   # Update system
   apt update && apt upgrade -y

   # Install essential packages
   apt install -y curl wget vim sudo ufw
   ```

2. **Tailscale Installation**
   ```bash
   # Install Tailscale
   curl -fsSL https://tailscale.com/install.sh | sh

   # Authenticate and connect
   tailscale up

   # Enable IP forwarding (for subnet router/exit node)
   echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
   ```

3. **Proxmox VE Installation**
   ```bash
   # Add Proxmox repository
   echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > \
       /etc/apt/sources.list.d/pve-install-repo.list

   # Add repository key
   wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

   # Update and install
   apt update && apt full-upgrade -y
   apt install -y proxmox-ve postfix open-iscsi
   ```

4. **Firewall Configuration**
   ```bash
   # Configure UFW
   ufw default deny incoming
   ufw default allow outgoing
   ufw allow 22/tcp    # SSH
   ufw allow 8006/tcp  # Proxmox web UI
   ufw allow 5900:5999/tcp  # VNC console
   ufw allow 3128/tcp  # VNC Websocket
   ufw allow 111/tcp   # NFS
   ufw allow 2049/tcp  # NFS
   ufw allow from 100.64.0.0/10  # Tailscale
   ufw enable
   ```

---

## 🌐 Network Integration

### Tailscale Configuration
- **Tailnet:** Will join existing FGSRV tailnet
- **IP Assignment:** Tailscale IP will be assigned (100.x.x.x range)
- **DNS:** Will use Tailscale DNS (100.100.100.100)
- **ACLs:** Must be configured for Proxmox access

### Firewall Requirements

| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| **22** | TCP | SSH | Admin IPs + Tailscale |
| **8006** | TCP | Proxmox Web UI | Admin IPs + Tailscale |
| **5900-5999** | TCP | VNC Console | Admin IPs + Tailscale |
| **3128** | TCP | VNC Websocket | Admin IPs + Tailscale |
| **111** | TCP/UDP | NFS | Tailscale network |
| **2049** | TCP/UDP | NFS | Tailscale network |
| **4789** | UDP | VXLAN (if clustering) | Proxmox hosts |

---

## 📊 Storage Planning

### Recommended Storage Layout

| Mount Point | Size | Purpose | Type |
|-------------|------|---------|------|
| `/` | 20-50GB | System | ext4/xfs |
| `/var/lib/vz` | Remaining | Proxmox storage | ext4/xfs/ZFS |
| `/var/lib/vz/template` | Subdir | ISO/CT templates | ext4 |
| `/var/lib/vz/images` | Subdir | VM disks | ext4 |
| `/var/lib/vz/private` | Subdir | CT rootfs | ext4 |
| `/var/lib/vz/backups` | Subdir | Backups | ext4 |

### NFS Storage Integration
FGSRV07 can mount NFS storage from existing FGSRV hosts:

```bash
# Mount FGSRV6 NFS (132GB available)
mkdir -p /mnt/fgsrv6-nfs
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576 100.83.51.9:/ /mnt/fgsrv6-nfs

# Mount FGSRV5 NFS (14GB available)
mkdir -p /mnt/fgsrv5-nfs
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576 100.71.107.26:/ /mnt/fgsrv5-nfs
```

---

## 🔗 Related Documentation

### FGSRV Fleet Documentation
- **[FGSRV All Hosts Troubleshooting Summary](./FGSRV_ALL_HOSTS_TROUBLESHOOTING_SUMMARY.md)** - Complete fleet status
- **[FGSRV6 Final Results](./test-reports/fgsrv6-final-results.md)** - NFS v4.2 deployment reference
- **[FGSRV5 Final Results](./test-reports/fgsrv5-final-results.md)** - Performance benchmarks

### Proxmox Documentation
- **[Proxmox NFS Storage Guide](./proxmox-nfs-storage-guide.md)** - NFS integration
- **[Storage Architecture](./storage-architecture.md)** - Storage design overview

### Network Documentation
- **[Tailscale Storage Performance](./TAILSCALE_STORAGE_PERFORMANCE_SUMMARY.md)** - VPN performance
- **[Tailscale Distributed Storage](./TAILSCALE_DISTRIBUTED_STORAGE.md)** - Mesh storage

---

## ✅ Installation Checklist

### Phase 1: Base System
- [x] Debian 13 installed
- [x] Network configured (191.252.93.227)
- [x] SSH key authorized
- [ ] System updated (apt upgrade)
- [ ] Essential packages installed

### Phase 2: Network
- [ ] Tailscale installed
- [ ] Tailscale authenticated
- [ ] Tailscale IP assigned
- [ ] Firewall configured
- [ ] DNS resolution verified

### Phase 3: Proxmox
- [ ] Proxmox repository added
- [ ] Proxmox VE installed
- [ ] Web UI accessible (port 8006)
- [ ] Storage configured
- [ ] Network bridges configured

### Phase 4: Integration
- [ ] Joined FGSRV tailnet
- [ ] NFS mounts configured (optional)
- [ ] Backup targets configured
- [ ] Monitoring setup
- [ ] Documentation updated

---

## 🎯 Next Steps

### Immediate Actions (Priority 1)
1. **System Update**: Run `apt update && apt upgrade -y`
2. **Tailscale Setup**: Install and authenticate Tailscale
3. **Security**: Configure firewall (UFW)
4. **Proxmox Install**: Deploy Proxmox VE hypervisor

### Short-term Tasks (Priority 2)
1. **Storage Setup**: Configure local storage for VMs/CTs
2. **NFS Integration**: Mount FGSRV05/FGSRV06 storage (optional)
3. **Backup Config**: Set up backup targets
4. **Monitoring**: Install monitoring agents

### Long-term Planning (Priority 3)
1. **Clustering**: Evaluate Proxmox clustering with other hosts
2. **High Availability**: Configure HA if needed
3. **Resource Planning**: Monitor utilization and capacity
4. **Documentation**: Maintain up-to-date records

---

## 📞 Access Information

### SSH Access
```bash
# Connect via SSH (from AGLSRV1 or Tailscale network)
ssh root@191.252.93.227

# After Tailscale setup (preferred)
ssh root@fgsrv07  # via Tailscale DNS
```

### Proxmox Web UI
```
URL: https://191.252.93.227:8006 (or https://fgsrv07:8006 via Tailscale)
User: root@pam
Auth: Linux PAM authentication
```

---

## 📝 Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-09 | Initial documentation created | Hive Mind Worker |
| | | |

---

**Document Status:** ✅ Complete
**Last Updated:** 2026-02-09
**Maintained By:** AGL Infrastructure Team
**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/docs/fgsrv07-host-overview.md`

---

*This document will be updated as FGSRV07 installation and configuration progresses.*
