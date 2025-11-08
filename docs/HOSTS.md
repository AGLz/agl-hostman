# Proxmox Hosts Detailed Configuration

> **Last Updated**: 2025-11-08 | **Version**: 1.1.0
> **Reference**: Complete host configurations, resources, and network details

---

## 📊 Host Summary

| Host | Type | Location | Status | Proxmox | Containers | Networks |
|------|------|----------|--------|---------|------------|----------|
| **AGLSRV1** | Production | AGLHQ | ✅ Active | 8.4.14 | 68 (42 running) | LAN + WG + TS |
| **AGLSRV3** | Standby | AGLHQ | ⚠️ Offline | TBD | TBD | TBD |
| **AGLSRV5** | Remote | AGLFG | ✅ Active | 8.4.14 | 8 (7 running) | LAN + WG + TS |
| **AGLSRV6** | Remote | AGLALD | ✅ Active | TBD | 11 containers | WG + TS |
| **AGLSRV6B** | Dead | AGLALD | ❌ Dead | - | CT172 offline | ❌ None |
| **AGLSRV6C** | Remote | AGLALD | ✅ Active | 9.0 | 0 (ready) | LAN + WG + TS |
| **AGLSRV6D** | Remote | AGLALD | ✅ Active | 9.0.11 | 0 (ready) | LAN + WG + TS |
| **FGSRV3** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | Public + WG + TS |
| **FGSRV4** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | WG + TS |
| **FGSRV5** | Cloud VPS | AGLFG-VPS | ✅ Active | TBD | TBD | Public + WG + TS |
| **FGSRV6** | Cloud VPS | AGLFG-VPS | ✅ **Hub** | TBD | TBD | Public + WG + TS |

---

## 🖥️ AGLSRV1 (Main Production Host)

**Hostname**: algsrv1
**Type**: Proxmox VE Host
**Physical Location**: **AGLHQ** (Headquarters)
**Network Location**: Local LAN (192.168.0.0/24)

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.245 | vmbr0 | ✅ Primary |
| WireGuard | 10.6.0.10 | wg0 | ✅ Port 51810 |
| Tailscale | 100.107.113.33 | tailscale0 | ✅ Active |

### Resources

- **Total VMs/CTs**: 68 (42 running, 26 stopped)
- **Primary Dev Container**: CT179 (agldv03) - 48GB RAM
- **AI Infrastructure**: CT183 (archon), CT200 (ollama-gpu)
- **Storage**:
  - local-zfs: 1.7TB
  - spark: 7.1TB (91.54% used)
  - overpower: 9.8TB (92.54% used)

### Key Services

| Category | Containers | Notes |
|----------|------------|-------|
| DNS/DHCP | CT102 (pihole) | Primary DNS server |
| Media | CT113 (plex), CT121-124 (arr stack) | Media automation |
| Development | CT179 (agldv03), CT180 (dokploy) | 48GB dev container |
| AI | CT183 (archon), CT200 (ollama-gpu), CT202 (n8n) | AI Command Center |
| Monitoring | CT132 (observium), CT162 (meshcentral) | Infrastructure monitoring |

### Connection Commands

```bash
# From WSL2 (Tailscale only)
ssh root@100.107.113.33

# From CT179 (prefer LAN)
ssh root@192.168.0.245  # Fastest (<1ms)

# From remote (prefer WireGuard)
ssh root@10.6.0.10
```

---

## 🖥️ AGLSRV3 (Proxmox VE Host - Offline)

**Hostname**: aglsrv3
**Type**: Proxmox VE Host
**Physical Location**: **AGLHQ** (Headquarters - same location as AGLSRV1)
**Status**: ⚠️ **Currently powered off** - pending power-on and analysis

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | TBD | vmbr0 | ⚠️ Awaiting power-on |
| WireGuard | TBD | wg0 | ⚠️ To be configured |
| Tailscale | TBD | tailscale0 | ⚠️ To be verified |

### Notes

- Located at AGLHQ headquarters with AGLSRV1, AGLHQ11, and AGLFA02
- Same local network (192.168.0.0/24) as AGLSRV1
- Will be analyzed when powered on by user
- Expected to have similar configuration to AGLSRV1 (Proxmox VE host)

### Pending Tasks

- [ ] Power on host
- [ ] Identify network addresses (LAN, Tailscale)
- [ ] Configure WireGuard mesh connectivity
- [ ] Inventory containers and VMs
- [ ] Document hardware specifications
- [ ] Update this section with complete information

---

## 🖥️ AGLSRV6 (Secondary Host)

**Hostname**: AGLSRV6 (formerly man6)
**Type**: Proxmox VE Host
**Physical Location**: **AGLALD** (Remote site)
**Network Location**: Remote (behind WireGuard/Tailscale)

### Network Configuration

| Network | Address | Interface | Status | Purpose |
|---------|---------|-----------|--------|---------|
| Local LAN | 192.168.0.202 | vmbr0 | ✅ Active | External access |
| Proxmox Internal | 192.168.60.202 | vmbr1 | ✅ Active | Corosync/cluster |
| **Inter-host LAN** | **192.168.1.202** | **vmbr2** | ✅ **PRIMARY** | **AGLSRV6 ↔ AGLSRV6C ↔ CTs** |
| WireGuard | 10.6.0.12 | wg0 | ✅ Port 51812 | Remote access |
| Tailscale | 100.98.108.66 | tailscale0 | ✅ Active | Fallback |

### Resources

- **Containers**: 11 (CT101-114, CT121)
- **VMs**: 6 (VM100, VM103, VM105-106, VM112, VM200)
- **Storage**:
  - bb: 954GB
  - usb4tb: 3.9TB
  - PBS: 1.2TB

### Key Services

| Service | Container | Details |
|---------|-----------|---------|
| Storage | CT111 (aluzdivina) | NFS server (10.6.0.20) |
| Backup | CT113 (PBS), CT172 (PBS) | Proxmox Backup Server |
| Development | CT108 (agldv06) | Tailscale-only dev container |
| Infrastructure | CT101 (cloudflared), CT102 (meshcentral) | Remote access |

### Connection Commands

```bash
# Via inter-host LAN (from AGLSRV6C or containers - RECOMMENDED)
ssh root@192.168.1.202  # PRIMARY for local communication

# Via external LAN (from same location)
ssh root@192.168.0.202

# From CT179 (prefer WireGuard)
ssh root@10.6.0.12

# From WSL2 (Tailscale only)
ssh root@100.98.108.66

# Proxmox Web Interface
https://192.168.0.202:8006  # External LAN
https://192.168.1.202:8006  # Inter-host LAN
```

---

## 🖥️ AGLSRV5 (Remote Proxmox Host)

**Hostname**: aglsrv5
**Type**: Proxmox VE 8.4.14 on Debian 12 (bookworm)
**Physical Location**: **AGLFG** (Remote standalone site)
**Network Location**: Remote location (different network segment - 192.168.15.0/24)

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| LAN (Primary) | 192.168.15.222/24 | vmbr0 | ✅ Active |
| LAN (Secondary) | 172.2.2.222/24 | vmbr1 | ✅ Active |
| WireGuard | 10.6.0.17/24 | wg0 | ✅ Port 51817 |
| Tailscale | 100.119.223.113 | tailscale0 | ✅ Active |

### Hardware

- **CPU**: Intel Xeon E3-1220 v6 @ 3.00GHz (4 cores, 4 threads)
- **RAM**: 62GB (32GB used, 24GB free, 7.2GB buffers/cache)
- **Storage**: 66GB root (37GB used, 30GB free - 56%)

### Proxmox Configuration

- **Version**: 8.4.14 (release 8.4)
- **Kernel**: 6.8.12-15-pve
- **OS**: Debian GNU/Linux 12 (bookworm)
- **Status**: ✅ Fully operational

### Storage Pools

| Storage | Type | Total | Used | Available | Usage |
|---------|------|-------|------|-----------|-------|
| base | zfspool | 1.75TB | 1.23TB | 533MB | 70% PRIMARY |
| bkp | dir | 593MB | 60MB | 533MB | 10% |
| games | dir | 65GB | 36GB | 29GB | 55% |
| local | dir | 65GB | 36GB | 29GB | 55% |
| local-lvm | lvmthin | 130GB | 12GB | 117GB | 9% |
| shares | dir | 65GB | 36GB | 29GB | 55% |

### Containers (8 total: 7 running, 1 stopped)

| VMID | Name | Status |
|------|------|--------|
| CT130 | cloudflared5 | ✅ Running |
| CT132 | plex5 | ✅ Running |
| CT133 | mesh5 | ✅ Running |
| CT134 | ipmitool5 | ✅ Running |
| CT135 | mysql5 | ⚠️ Stopped |
| CT136 | agldv05 | ✅ Running |
| CT138 | fileserver5 | ✅ Running |
| CT139 | pihole5 | ✅ Running |

### Access Methods

```bash
# Via Tailscale (recommended - 20-42ms latency)
ssh root@100.119.223.113

# Via WireGuard (SSH connection closes immediately - auth issue)
ssh root@10.6.0.17  # ⚠️ Known issue

# Via LAN (only from same network segment)
ssh root@192.168.15.222
```

### Network Configuration

- Connected to WireGuard mesh via FGSRV6 hub (10.6.0.5)
- Part of different LAN segment (192.168.15.x vs 192.168.0.x)
- Tailscale provides cross-site connectivity

### Role

- Remote Proxmox VE Host with significant storage capacity (1.75TB ZFS pool)
- Runs production services: Plex, Pi-hole, file server, Cloudflare tunnel
- Development container (agldv05) available
- Part of distributed infrastructure with independent network segment

### Known Issues

- ⚠️ **SSH via WireGuard**: Authentication issues (connection established but closes)
- ✅ **Workaround**: Use Tailscale access (100.119.223.113)
- ℹ️ **Storage**: Large ZFS storage pool (base) at 70% capacity - may need monitoring

---

## 🖥️ AGLSRV6C (New Proxmox Host)

**Hostname**: man6c (alias aglsrv6c)
**Type**: Proxmox VE 9.0 Host on Debian 13 (trixie) - **✅ Fully operational**
**Physical Location**: **AGLALD** (Remote site - same as AGLSRV6)
**Network Location**: Same network as AGLSRV6 (192.168.0.0/24)
**Setup Completed**: 2025-11-08

### Network Configuration

| Network | Address | Interface | Status | Purpose |
|---------|---------|-----------|--------|---------|
| Local LAN | 192.168.0.233 | vmbr0 | ✅ Active | External access |
| **Inter-host LAN** | **192.168.1.233** | **vmbr2** | ✅ **PRIMARY** | **AGLSRV6 ↔ AGLSRV6C ↔ CTs** |
| WireGuard | 10.6.0.22 | wg0 | ✅ Port 51822 | Remote access |
| Tailscale | 100.124.53.91 | tailscale0 | ✅ Active | Fallback |

### Hardware

- **Physical Interfaces**: eno8303 (vmbr0), eno8403 (vmbr2)
- **Boot**: Triple EFI partitions (sdb, sdc, sdd) for redundancy
- **Bootloader**: systemd-boot with proxmox-boot-tool

### Current State

- **OS**: Debian GNU/Linux (Trixie) - Proxmox VE 9.0
- **Kernel**: 6.14.11-4-pve (updated during hardening)
- **Status**: ✅ Fully configured and operational
- **Timezone**: America/Sao_Paulo (-03)

### Configuration Details

**Persistent Interface Fix**:
- systemd service (`force-interfaces-up.service`) forces eno8303/eno8403 UP on boot
- Solves issue where interfaces start DOWN despite physical cable connection
- Service runs before `networking.service` using `WantedBy=sysinit.target`

**Dual-Network Setup**:
- vmbr0 (192.168.0.233) with gateway - Primary network
- vmbr2 (192.168.1.233) no gateway - Secondary network
- DNS: Google DNS (8.8.8.8, 8.8.4.4)

**Security**:
- fail2ban active for SSH protection
- SSH hardening applied (MaxAuthTries 3, X11Forwarding disabled)
- unattended-upgrades configured for automatic security updates
- UFW firewall installed (not activated - Proxmox manages via GUI)

**Monitoring Tools**: htop, iotop, ncdu installed

### Role

- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity
- Ready for container/VM deployment
- Full mesh network integration

### WireGuard Configuration

- **PublicKey**: `Ha57VYk9mTvUgfyl0GV7EZCdwxCzCXzEwGl4L+2jFQU=`
- **PresharedKey**: Configured (host pattern, not container)
- **Connected to**: hub FGSRV6 (10.6.0.5) at 186.202.57.120:51823
- **MTU**: 1420
- **PersistentKeepalive**: 25

**Mesh Connectivity** (verified with 0% packet loss):
- FGSRV6 (10.6.0.5): 14-16ms latency
- AGLSRV1 (10.6.0.10): 29-38ms latency
- AGLSRV6 (10.6.0.12): 34-41ms latency
- CT179 (10.6.0.19): 29-40ms latency

### Access Methods

```bash
# Via inter-host LAN (from AGLSRV6 or containers - RECOMMENDED)
ssh root@192.168.1.233  # PRIMARY for local communication

# Via external LAN
ssh root@192.168.0.233

# Via Tailscale
ssh root@100.124.53.91

# Via WireGuard
ssh root@10.6.0.22

# Via Jump Host (AGLSRV6 Tailscale)
ssh -J root@100.98.108.66 root@192.168.1.233

# Via Jump Host (AGLSRV6 WireGuard)
ssh -J root@10.6.0.12 root@192.168.1.233

# Proxmox Web Interface
https://192.168.0.233:8006  # External LAN
https://192.168.1.233:8006  # Inter-host LAN
```

### Documentation

- Complete setup guide: `/tmp/AGLSRV6C-SETUP-COMPLETE.md`
- All configuration files documented
- Troubleshooting procedures included

---

## 🖥️ AGLSRV6D (Proxmox VE Host)

**Hostname**: man6d (alias aglsrv6d)
**Type**: Proxmox VE 9.0.11 on Debian 13 (trixie) - **✅ Fully operational**
**Physical Location**: **AGLALD** (Remote site - same as AGLSRV6 and AGLSRV6C)
**Network Location**: Same network as AGLSRV6 (192.168.0.0/24)

### Network Configuration

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.234 | enp2s0 | ✅ Active |
| Tailscale | 100.76.201.83 | tailscale0 | ✅ Active |
| WireGuard | 10.6.0.23 | wg0 | ✅ Port 51823 |

### Hardware

- **CPU**: Intel Core i5-4590 @ 3.30GHz (4 cores, 4 threads)
- **RAM**: 8GB (7.7GB usable)
- **Storage**: 465GB SSD (456GB root + 976MB boot + 8GB swap)

### Current State

- **OS**: Proxmox VE 9.0.11 on Debian 13 (trixie)
- **Kernel**: 6.14.11-4-pve (Proxmox kernel)
- **Status**: ✅ Fully operational
- **WireGuard**: ✅ Active and connected to mesh
- **Web Interface**: https://192.168.0.234:8006 (LAN)
- **Services**: pvedaemon, pveproxy, pve-cluster all running

### Role

- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity (8GB RAM, 465GB storage)
- Ready for container/VM deployment
- Backup/failover capabilities

### WireGuard Configuration

- **PublicKey**: `d9i/Izz71+3O4t2jMwt2L5N0m5mCVjph0GzplJGzXDM=`
- **Connected to**: hub FGSRV6 (10.6.0.5)
- **Latency**: ~15-30ms to mesh nodes
- **Status**: Full mesh connectivity established

### Access Methods

```bash
# Via LAN
ssh root@192.168.0.234

# Via Tailscale
ssh root@100.76.201.83

# Via WireGuard
ssh root@10.6.0.23

# Proxmox Web Interface
https://192.168.0.234:8006
```

---

## ☁️ FGSRV6 (Cloud VPS - WireGuard Hub)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Cloud Provider**: vps41772.publiccloud.com.br
**Type**: Proxmox VE Host
**Role**: **CRITICAL** - WireGuard mesh hub, NFS server

### Network Configuration

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 186.202.57.120 | - | ✅ Internet |
| WireGuard | 10.6.0.5 | 51823/UDP | ✅ **Hub** |
| Tailscale | 100.83.51.9 | - | ✅ Active |

### NFS Exports

- **Export**: 197GB NFSv4.2
- **Mounted on**: AGLSRV1 as `fgsrv6-wg` (10.6.0.5)

### Critical Role

- **Central routing point** for entire WireGuard mesh
- **Failure affects entire mesh** - all nodes connect through this hub
- Acts as NFS server for distributed storage

---

## ☁️ FGSRV5 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Public IP**: 191.252.200.20
**Type**: Proxmox VE Host
**Role**: NFS server, storage backend

### Network Configuration

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.200.20 | - | ✅ Internet |
| WireGuard | 10.6.0.11 | 51811/UDP | ✅ Active |
| Tailscale | 100.71.107.26 | - | ✅ Active |

### NFS Exports

- **Export**: 77GB NFSv4.2
- **Mounted on**: AGLSRV1 as `fgsrv5-wg` (10.6.0.11)

### Known Issues

- ⚠️ SSH timeout issues reported
- ✅ WireGuard connectivity working

---

## ☁️ FGSRV4 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Cloud Provider**: vps22826.publiccloud.com.br
**Type**: Proxmox VE Host

### Network Configuration

| Network | Address | Port | Status |
|---------|---------|------|--------|
| WireGuard | 10.6.0.16 | 51816/UDP | ✅ Active |
| Tailscale | 100.111.79.2 | - | ✅ Active |

### Access

- **User**: sysadmin

---

## ☁️ FGSRV3 (Cloud VPS)

**Physical Location**: **AGLFG-VPS** (Cloud infrastructure)
**Public IP**: 191.252.201.205
**Type**: Proxmox VE Host

### Network Configuration

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.201.205 | - | ✅ Internet |
| WireGuard | 10.6.0.18 | 51818/UDP | ✅ Active |
| Tailscale | 100.67.99.115 | - | ✅ Active |

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md` - Complete infrastructure overview
- **Network Topology**: `TOPOLOGY.md` - Physical locations and network architecture
- **Proxmox Installation**: `PROXMOX.md` - Installation standards and requirements
- **WireGuard Mesh**: `WIREGUARD.md` - Mesh configuration details
- **Containers**: `CONTAINERS.md` - Complete container inventory
- **Storage**: `STORAGE.md` - Storage configuration and NFS mounts
- **Connections**: `CONNECTIONS.md` - Connection priorities and access patterns

---

**Document Version**: 1.1.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)

**Version Notes**:
- **v1.1.0** (2025-11-08): Added complete network configurations for AGLSRV5 (dual LAN) and AGLSRV6 (triple network)
