# Proxmox VE Installation and Configuration

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: Proxmox VE deployment standards and procedures

---

## 🔧 Base Operating System Requirements

**All Proxmox VE hosts in this infrastructure use Debian as the base operating system**. This is not just a preference but a technical requirement.

### Why Debian? ✅

- Proxmox VE is **built on Debian** - it's a complete distribution, not just software
- Official installation method: Add Proxmox repositories to Debian → Install `proxmox-ve` package
- Supported Debian versions: Debian 11 (Bullseye), Debian 12 (Bookworm), Debian 13 (Trixie)
- Shares the same package ecosystem and kernel architecture as Proxmox

### Why NOT Ubuntu? ❌

- **Official Proxmox stance**: "Not possible" - "Proxmox VE is not just a GUI, it's a distribution and therefore you cannot install a distribution on a distribution"
- Ubuntu diverges too much from Debian upstream
- Proxmox packages rely on Debian-specific dependencies not available in Ubuntu
- Proxmox custom kernel incompatible with Ubuntu package system

---

## 📦 Installation Process (Successfully Implemented)

This infrastructure has successfully deployed Proxmox VE over Debian on multiple hosts (AGLSRV6C, AGLSRV6D).

### Step-by-Step Installation

```bash
# 1. Start with clean Debian 12/13 installation

# 2. Add Proxmox repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

# 3. Import GPG key
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# 4. Install Proxmox packages
apt update && apt full-upgrade
apt install proxmox-default-kernel
systemctl reboot

# 5. After reboot, install Proxmox VE
apt install proxmox-ve postfix open-iscsi chrony

# 6. Remove Debian stock kernel (optional)
apt remove linux-image-amd64 'linux-image-6.1*'
update-grub

# 7. Reboot to Proxmox kernel
systemctl reboot
```

### Post-Installation Verification

```bash
# Check Proxmox VE version
pveversion -v

# Verify kernel
uname -r  # Should show 6.x.x-x-pve

# Check services
systemctl status pvedaemon
systemctl status pveproxy
systemctl status pve-cluster

# Access web interface
# https://<host-ip>:8006
```

---

## 🖥️ Current Deployment Status

### Active Proxmox Hosts

| Host | Proxmox Version | Debian Version | Kernel | Installation Type | Status |
|------|----------------|----------------|--------|-------------------|---------|
| **AGLSRV1** | 8.4.14 | Debian | 6.8.x-pve | Standard | ✅ Production |
| **AGLSRV5** | 8.4.14 | Debian 12 | 6.8.12-15-pve | Standard | ✅ Active |
| **AGLSRV6** | 8.x | Debian | 6.x-pve | Standard | ✅ Active |
| **AGLSRV6C** | 9.0.11 | Debian 13 | 6.14.11-4-pve | **Overlay** | ✅ Active |
| **AGLSRV6D** | 9.0.11 | Debian 13 | 6.14.11-4-pve | **Overlay** | ✅ Active |

### Pending/Offline Hosts

| Host | Status | Notes |
|------|--------|-------|
| **AGLSRV3** | ⚠️ Offline | Pending power-on and analysis |
| **AGLSRV6B** | ❌ DEAD | RAID card failure, replaced by AGLSRV6C |

---

## 🔗 Cluster Configuration

### Planned Proxmox Cluster

See `PROXMOX-CLUSTER-PLAN.md` for detailed cluster planning.

**Cluster Goals**:
- High availability across physical locations
- Shared storage with Ceph or distributed ZFS
- Live migration capabilities
- Quorum with QDevice for 2-node configurations

**Challenges**:
- Geographic distribution (AGLHQ, AGLFG, AGLALD, Cloud VPS)
- Network latency between sites
- Bandwidth constraints for replication

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md` - Complete infrastructure map
- **Cluster Planning**: `PROXMOX-CLUSTER-PLAN.md` - Cluster architecture and implementation
- **Hosts Details**: `HOSTS.md` - Detailed host configurations
- **Network Topology**: `TOPOLOGY.md` - Physical and network topology

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
