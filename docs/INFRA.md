# AGL Infrastructure Map

> **Last Updated**: 2025-11-08 | **Version**: 2.1.0
> **Reference**: Always read this document for infrastructure queries

---

## 📋 Table of Contents

1. [Network Overview](#-network-overview)
2. [Hosts and Servers](#-hosts-and-servers)
3. [WireGuard Mesh](#-wireguard-mesh)
4. [Storage Configuration](#-storage-configuration)
5. [Container Inventory](#-container-inventory)
6. [Connection Matrix](#-connection-matrix)

---

## 🌐 Network Overview

### Network Segments

| Network | CIDR | Purpose | Status |
|---------|------|---------|--------|
| WireGuard Mesh | 10.6.0.0/24 | Encrypted inter-site connectivity | ✅ Active (15 nodes) |
| Local LAN | 192.168.0.0/24 | Primary local network | ✅ Active |
| Local LAN Alt | 192.168.1.0/24 | Secondary local network | ✅ Active |
| Tailscale | 100.64.0.0/10 | Cross-site VPN overlay | ✅ Active |

### WireGuard Hub
- **Server**: FGSRV6 (vps41772)
- **Public IP**: 186.202.57.120
- **WireGuard IP**: 10.6.0.5
- **Port**: 51823/UDP
- **Type**: Hub-and-spoke + mesh hybrid

---

## 🖥️ Hosts and Servers

### AGLSRV1 (Main Production Host)
**Hostname**: algsrv1
**Type**: Proxmox VE Host
**Location**: Local (192.168.0.0/24)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.245 | vmbr0 | ✅ Primary |
| WireGuard | 10.6.0.10 | wg0 | ✅ Port 51810 |
| Tailscale | 100.107.113.33 | tailscale0 | ✅ Active |

**Resources**:
- Total VMs/CTs: 68 (42 running, 26 stopped)
- Primary Dev Container: CT179 (agldv03) - 48GB RAM
- AI Infrastructure: CT183 (archon), CT200 (ollama-gpu)
- Storage: local-zfs (1.7TB), spark (7.1TB), overpower (9.8TB)

**Key Services**:
- DNS/DHCP: CT102 (pihole)
- Media: CT113 (plex), CT121-124 (arr stack)
- Development: CT179 (agldv03), CT180 (dokploy)
- AI: CT183 (archon), CT200 (ollama-gpu), CT202 (n8n)
- Monitoring: CT132 (observium), CT162 (meshcentral)

---

### AGLSRV6 (Secondary Host)
**Hostname**: AGLSRV6 (formerly man6)
**Type**: Proxmox VE Host
**Location**: Remote (behind WireGuard/Tailscale)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| WireGuard | 10.6.0.12 | wg0 | ✅ Port 51812 (PRIMARY) |
| Tailscale | 100.98.108.66 | tailscale0 | ✅ Fallback |

**Resources**:
- Containers: 11 (CT101-114, CT121)
- VMs: 6 (VM100, VM103, VM105-106, VM112, VM200)
- Storage: 954GB (bb), 3.9TB (usb4tb), 1.2TB (PBS)

**Key Services**:
- Storage: CT111 (aluzdivina) - NFS server (10.6.0.20)
- Backup: CT113 (PBS), CT172 (PBS)
- Development: CT108 (agldv06)
- Infrastructure: CT101 (cloudflared), CT102 (meshcentral)

---

### AGLSRV5 (Remote Proxmox Host)
**Hostname**: aglsrv5
**Type**: Proxmox VE 8.4.14 on Debian 12 (bookworm)
**Location**: Remote location (different network segment)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| LAN | 192.168.15.222/24 | vmbr0 | ✅ Active |
| WireGuard | 10.6.0.17/24 | wg0 | ✅ Port 51817 |
| Tailscale | 100.119.223.113 | tailscale0 | ✅ Active |

**Hardware**:
- CPU: Intel Xeon E3-1220 v6 @ 3.00GHz (4 cores, 4 threads)
- RAM: 62GB (32GB used, 24GB free, 7.2GB buffers/cache)
- Storage: 66GB root (37GB used, 30GB free - 56%)

**Proxmox Configuration**:
- Version: 8.4.14 (release 8.4)
- Kernel: 6.8.12-15-pve
- OS: Debian GNU/Linux 12 (bookworm)
- Status: ✅ Fully operational

**Storage Pools**:
| Storage | Type | Total | Used | Available | Usage |
|---------|------|-------|------|-----------|-------|
| base | zfspool | 1.75TB | 1.23TB | 533MB | 70% PRIMARY |
| bkp | dir | 593MB | 60MB | 533MB | 10% |
| games | dir | 65GB | 36GB | 29GB | 55% |
| local | dir | 65GB | 36GB | 29GB | 55% |
| local-lvm | lvmthin | 130GB | 12GB | 117GB | 9% |
| shares | dir | 65GB | 36GB | 29GB | 55% |

**Containers** (8 total: 7 running, 1 stopped):
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

**Access Methods**:
- Via Tailscale (recommended): `ssh root@100.119.223.113` (20-42ms latency)
- Via WireGuard: 10.6.0.17 (SSH connection closes immediately - auth issue)
- Via LAN: 192.168.15.222 (only from same network segment)

**Network Configuration**:
- Connected to WireGuard mesh via FGSRV6 hub (10.6.0.5)
- Part of different LAN segment (192.168.15.x vs 192.168.0.x)
- Tailscale provides cross-site connectivity

**Role**:
- Remote Proxmox VE Host with significant storage capacity (1.75TB ZFS pool)
- Runs production services: Plex, Pi-hole, file server, Cloudflare tunnel
- Development container (agldv05) available
- Part of distributed infrastructure with independent network segment

**Notes**:
- SSH via WireGuard has authentication issues (connection established but closes)
- Tailscale access works perfectly (✅ verified)
- Different network segment (192.168.15.x) indicates separate physical location
- Large ZFS storage pool (base) at 70% capacity - may need monitoring

---

### AGLSRV6C (New Proxmox Host)
**Hostname**: man6c (alias aglsrv6c)
**Type**: Proxmox VE 9.0 Host on Debian 13 (trixie) - **✅ Fully operational**
**Location**: Same network as AGLSRV6 (192.168.0.0/24)

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN (Primary) | 192.168.0.233 | vmbr0 | ✅ Active |
| Local LAN (Secondary) | 192.168.1.233 | vmbr2 | ✅ Active |
| WireGuard | 10.6.0.22 | wg0 | ✅ Port 51822 |
| Tailscale | 100.124.53.91 | tailscale0 | ✅ Active |

**Hardware**:
- Physical Interfaces: eno8303 (vmbr0), eno8403 (vmbr2)
- Boot: Triple EFI partitions (sdb, sdc, sdd) for redundancy
- systemd-boot with proxmox-boot-tool

**Current State**:
- OS: Debian GNU/Linux (Trixie) - Proxmox VE 9.0
- Kernel: 6.14.11-4-pve (updated during hardening)
- Status: ✅ Fully configured and operational
- Setup completed: 2025-11-08
- Timezone: America/Sao_Paulo (-03)

**Configuration Details**:
- **Persistent Interface Fix**: systemd service (`force-interfaces-up.service`) forces eno8303/eno8403 UP on boot
  - Solves issue where interfaces start DOWN despite physical cable connection
  - Service runs before `networking.service` using `WantedBy=sysinit.target`
- **Dual-Network Setup**: Both 192.168.0.x and 192.168.1.x networks active
  - vmbr0 (192.168.0.233) with gateway - Primary network
  - vmbr2 (192.168.1.233) no gateway - Secondary network
  - DNS: Google DNS (8.8.8.8, 8.8.4.4)
- **Security**:
  - fail2ban active for SSH protection
  - SSH hardening applied (MaxAuthTries 3, X11Forwarding disabled)
  - unattended-upgrades configured for automatic security updates
  - UFW firewall installed (not activated - Proxmox manages via GUI)
- **Monitoring Tools**: htop, iotop, ncdu installed

**Role**:
- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity
- Ready for container/VM deployment
- Full mesh network integration

**WireGuard Configuration**:
- PublicKey: `Ha57VYk9mTvUgfyl0GV7EZCdwxCzCXzEwGl4L+2jFQU=`
- PresharedKey: Configured (host pattern, not container)
- Connected to hub FGSRV6 (10.6.0.5) at 186.202.57.120:51823
- MTU: 1420, PersistentKeepalive: 25
- **Mesh Connectivity** (verified with 0% packet loss):
  - FGSRV6 (10.6.0.5): 14-16ms latency
  - AGLSRV1 (10.6.0.10): 29-38ms latency
  - AGLSRV6 (10.6.0.12): 34-41ms latency
  - CT179 (10.6.0.19): 29-40ms latency

**Access Methods**:
- Via LAN: `ssh root@192.168.0.233`
- Via Tailscale: `ssh root@100.124.53.91`
- Via WireGuard: `ssh root@10.6.0.22`
- Via Jump Host (AGLSRV6 Tailscale): `ssh -J root@100.98.108.66 root@192.168.0.233`
- Via Jump Host (AGLSRV6 WireGuard): `ssh -J root@10.6.0.12 root@192.168.0.233`
- Proxmox Web Interface: https://192.168.0.233:8006

**Documentation**:
- Complete setup guide: `/tmp/AGLSRV6C-SETUP-COMPLETE.md`
- All configuration files documented
- Troubleshooting procedures included

---

### AGLSRV6D (Proxmox VE Host)
**Hostname**: man6d (alias aglsrv6d)
**Type**: Proxmox VE 9.0.11 on Debian 13 (trixie) - **✅ Fully operational**
**Location**: Same network as AGLSRV6

| Network | Address | Interface | Status |
|---------|---------|-----------|--------|
| Local LAN | 192.168.0.234 | enp2s0 | ✅ Active |
| Tailscale | 100.76.201.83 | tailscale0 | ✅ Active |
| WireGuard | 10.6.0.23 | wg0 | ✅ Port 51823 |

**Hardware**:
- CPU: Intel Core i5-4590 @ 3.30GHz (4 cores, 4 threads)
- RAM: 8GB (7.7GB usable)
- Storage: 465GB SSD (456GB root + 976MB boot + 8GB swap)

**Current State**:
- OS: Proxmox VE 9.0.11 on Debian 13 (trixie)
- Kernel: 6.14.11-4-pve (Proxmox kernel)
- Status: ✅ Fully operational
- WireGuard: ✅ Active and connected to mesh
- Web Interface: https://192.168.0.234:8006 (LAN)
- Services: pvedaemon, pveproxy, pve-cluster all running

**Role**:
- Proxmox VE Host (same location as AGLSRV6)
- Additional compute/storage capacity (8GB RAM, 465GB storage)
- Ready for container/VM deployment
- Backup/failover capabilities

**WireGuard Configuration**:
- PublicKey: `d9i/Izz71+3O4t2jMwt2L5N0m5mCVjph0GzplJGzXDM=`
- Connected to hub FGSRV6 (10.6.0.5)
- Latency: ~15-30ms to mesh nodes
- Full mesh connectivity established

---

### FGSRV6 (Cloud VPS - WireGuard Hub)
**Location**: Cloud VPS (vps41772)
**Type**: Proxmox VE Host
**Role**: WireGuard mesh hub, NFS server

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 186.202.57.120 | - | ✅ Internet |
| WireGuard | 10.6.0.5 | 51823/UDP | ✅ Hub |
| Tailscale | 100.83.51.9 | - | ✅ Active |

**NFS Exports**:
- Export: 197GB NFSv4.2
- Mounted on: AGLSRV1 as `fgsrv6-wg` (10.6.0.5)

---

### FGSRV5 (Cloud VPS)
**Location**: Cloud VPS (191.252.200.20)
**Type**: Proxmox VE Host
**Role**: NFS server, storage backend

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.200.20 | - | ✅ Internet |
| WireGuard | 10.6.0.11 | 51811/UDP | ✅ Active |
| Tailscale | 100.71.107.26 | - | ✅ Active |

**NFS Exports**:
- Export: 77GB NFSv4.2
- Mounted on: AGLSRV1 as `fgsrv5-wg` (10.6.0.11)
- **Notes**: SSH timeout issues reported

---

### FGSRV4 (Cloud VPS)
**Location**: Cloud VPS (vps22826.publiccloud.com.br)
**Type**: Proxmox VE Host

| Network | Address | Port | Status |
|---------|---------|------|--------|
| WireGuard | 10.6.0.16 | 51816/UDP | ✅ Active |
| Tailscale | 100.111.79.2 | - | ✅ Active |

**User**: sysadmin

---

### FGSRV3 (Cloud VPS)
**Location**: Cloud VPS (191.252.201.205)
**Type**: Proxmox VE Host

| Network | Address | Port | Status |
|---------|---------|------|--------|
| Public IP | 191.252.201.205 | - | ✅ Internet |
| WireGuard | 10.6.0.18 | 51818/UDP | ✅ Active |
| Tailscale | 100.67.99.115 | - | ✅ Active |

---

## 🔗 WireGuard Mesh

### WireGuard Mesh Nodes (15 Active, 17 Total)

| Node | IP | Port | Type | Host | Status |
|------|-----|------|------|------|--------|
| **FGSRV6** | 10.6.0.5 | 51823 | Hub | Cloud VPS | ✅ Hub |
| CT120 | 10.6.0.1 | 51820 | Container | AGLSRV1 | ✅ |
| CT121 | 10.6.0.3 | 51821 | Container | AGLSRV6 | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | Local | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Host | Cloud VPS | ✅ |
| **AGLSRV6** | 10.6.0.12 | 51812 | Host | Remote | ✅ PRIMARY |
| AGLSRV6B | 10.6.0.13 | 51813 | Host | Remote | ❌ DEAD - RAID failure, replaced by AGLSRV6C |
| CT113 | 10.6.0.14 | 51814 | Container | AGLSRV6 | ✅ |
| CT172 | 10.6.0.15 | 51815 | Container | AGLSRV6B | ⚠️ Host offline |
| FGSRV4 | 10.6.0.16 | 51816 | Host | Cloud VPS | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | Remote | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Host | Cloud VPS | ✅ |
| **CT179** | 10.6.0.19 | 51819 | Container | AGLSRV1 | ✅ Dev |
| **CT111** | 10.6.0.20 | 51820 | Container | AGLSRV6 | ✅ NFS |
| **CT183** | 10.6.0.21 | 51821 | Container | AGLSRV1 | ✅ Archon AI |
| **AGLSRV6C** | 10.6.0.22 | 51822 | Host | Remote | ✅ Active |
| **AGLSRV6D** | 10.6.0.23 | 51823 | Host | Remote | ✅ Active |

### Configuration Standards

**Containers (No PresharedKey)**:
```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24  # Only mesh network
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

**Hosts (With PresharedKey)**:
```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
PresharedKey = DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

### LXC Container Requirements
```ini
# Required in /etc/pve/lxc/XXX.conf
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

---

## 💾 Storage Configuration

### AGLSRV1 Storage Mounts

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

**Total WireGuard Storage**: 6.0 TB
- NFS: 1.2TB (fgsrv5-wg + fgsrv6-wg + ct111-shares + ct111-sistema)
- SSHFS: 4.8TB (aglsrv6-bb + aglsrv6-usb4tb)

### CT111 (aluzdivina) NFS Server

**WireGuard**: 10.6.0.20 (Port 51820)
**Tailscale**: 100.65.189.83
**Host**: AGLSRV6

**Storage**:
- /mnt/shares: 66GB XFS (NFS exported)
- /mnt/sistema: 819GB ZFS (NFS exported)
- /mnt/bb: CIFS from 192.168.0.203
- /mnt/bkp: 3.9TB ExFAT

**NFS Exports**:
- 192.168.0.0/24 (Local LAN)
- 10.6.0.0/24 (WireGuard mesh)

**Performance**:
- Latency to hub: 15-22ms
- Mounted on AGLSRV1 as ct111-shares (66GB) and ct111-sistema (818GB)

---

## 📦 Container Inventory

### AGLSRV1 Containers (Running - 42 Total)

#### Infrastructure & Network
| VMID | Name | IP (LAN) | IP (WG/TS) | Purpose |
|------|------|----------|------------|---------|
| 102 | pihole | 192.168.0.102 | TS: 100.114.66.80 | DNS/DHCP |
| 117 | cloudflared | 192.168.0.117 | - | Cloudflare tunnel |
| 120 | wireguard | 192.168.0.120 | WG: 10.6.0.1 | WireGuard node |
| 126 | guac | 192.168.0.126 | - | Guacamole remote |
| 159 | nginxproxy | 192.168.0.159 | - | Nginx reverse proxy |
| 162 | meshcentral | 192.168.0.162 | - | Remote management |
| 176 | iventoy | 192.168.0.176 | - | Network boot |

#### Media & Automation
| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 111 | tautulli | 192.168.0.111 | Plex monitoring |
| 112 | bazarr | 192.168.0.112 | Subtitle automation |
| 113 | plexmediaserver | 192.168.0.113 | Media server |
| 121 | qbittorrent | 192.168.0.121 | Torrent client |
| 122 | jackett | 192.168.0.122 | Torrent indexer |
| 123 | radarr | 192.168.0.123 | Movie automation |
| 124 | sonarr | 192.168.0.124 | TV automation |
| 141 | sabnzbd | 192.168.0.141 | Usenet client |
| 144 | autobrr | 192.168.0.144 | Torrent automation |
| 157 | deluge | 192.168.0.157 | Torrent client |
| 165 | aria2 | 192.168.0.165 | Download manager |
| 170 | homarr | 192.168.0.170 | Dashboard |
| 171 | overseerr | 192.168.0.171 | Media requests |
| 172 | prowlarr | 192.168.0.172 | Indexer manager |

#### Development & DevOps
| VMID | Name | IP (LAN) | IP (WG/TS) | RAM | Purpose |
|------|------|----------|------------|-----|---------|
| 103 | portainer | 192.168.0.103 | - | - | Docker mgmt |
| 178 | aglfs1 | 192.168.0.178 | - | - | File server |
| 179 | agldv03 | 192.168.0.179 | WG: 10.6.0.19, TS: 100.94.221.87 | 48GB | **Primary Dev** |
| 180 | dokploy | 192.168.0.180 | - | - | Deployment |
| 202 | n8n-docker | 192.168.0.202 | - | - | Workflow automation |

#### AI & Machine Learning
| VMID | Name | IP (LAN) | IP (TS) | GPU | Purpose |
|------|------|----------|---------|-----|---------|
| 183 | archon | 192.168.0.183 | - | - | **AI Command Center** |
| 200 | ollama-gpu | 192.168.0.200 | 100.116.57.111 | ✅ NVIDIA | LLM compute |

#### Databases & Services
| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 131 | mysql | 192.168.0.131 | MySQL DB |
| 137 | redis | 192.168.0.137 | Redis cache |
| 139 | aldsys4 | 192.168.0.139 | System mgmt |
| 149 | postgresql | 192.168.0.149 | PostgreSQL |

#### Monitoring & Security
| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 132 | observium | 192.168.0.132 | Network monitoring |
| 133 | aping | 192.168.0.133 | Network testing |

#### Game Servers
| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 161 | gameserver | 192.168.0.161 | Game hosting |
| 163 | gameserver2 | 192.168.0.163 | Game hosting |
| 201 | amp-server | 192.168.0.201 | AMP game panel |

#### Caching & Performance
| VMID | Name | IP (LAN) | Purpose |
|------|------|----------|---------|
| 173 | cacheng | 192.168.0.173 | Cache engine |

---

### AGLSRV6 Containers

#### Infrastructure
| VMID | Name | IP (WG/TS) | Purpose |
|------|------|------------|---------|
| 101 | cloudflared6 | TS: 100.120.181.108 | Cloudflare tunnel |
| 102 | meshcentral6 | - | Remote management |
| 114 | cloudflared6b | - | Cloudflare tunnel |
| 121 | wireguard | WG: 10.6.0.3 | WireGuard node |

#### Storage & Backup
| VMID | Name | IP (WG/TS) | Purpose |
|------|------|------------|---------|
| 111 | aluzdivina | WG: 10.6.0.20, TS: 100.65.189.83 | **NFS Server** |
| 113 | pbs | WG: 10.6.0.14, TS: 100.70.155.60 | PBS backup |

#### Development
| VMID | Name | IP (TS) | Purpose |
|------|------|---------|---------|
| 108 | agldv06 | 100.71.229.12 | Development |

#### Services
| VMID | Name | Purpose |
|------|------|---------|
| 104 | luzdivina | - |
| 109 | redis6 | Redis server |
| 110 | mssql6 | SQL Server |

#### Kubernetes (Stopped)
| VMID | Name | Status | Purpose |
|------|------|--------|---------|
| 107 | kuber601 | Stopped | Kubernetes |

---

## 🔀 Connection Matrix

### From WSL2 (AGLHQ11)

**Available Networks**: Tailscale only
**Not Available**: WireGuard, Local LAN

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| AGLSRV1 Host | Tailscale | 100.107.113.33 | `ssh root@100.107.113.33` |
| CT179 Dev | Tailscale | 100.94.221.87 | `ssh root@100.94.221.87` |
| CT183 Archon | SSH Jump | Via AGLSRV1 | `ssh -J root@100.107.113.33 root@192.168.0.183` |
| AGLSRV6 Host | Tailscale | 100.98.108.66 | `ssh root@100.98.108.66` |
| FGSRV6 Hub | Tailscale | 100.83.51.9 | `ssh root@100.83.51.9` |

---

### From CT179 (agldv03)

**Available Networks**: LAN, WireGuard, Tailscale (triple-stack)
**Network Priority**: WireGuard > LAN > Tailscale

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| AGLSRV1 Host | LAN | 192.168.0.245 | `ssh root@192.168.0.245` |
| AGLSRV1 Host | WireGuard | 10.6.0.10 | `ssh root@10.6.0.10` |
| CT183 Archon | LAN | 192.168.0.183 | `ssh root@192.168.0.183` |
| AGLSRV6 Host | WireGuard | 10.6.0.12 | `ssh root@10.6.0.12` (FASTEST) |
| AGLSRV6 Host | Tailscale | 100.98.108.66 | `ssh root@100.98.108.66` |
| FGSRV6 Hub | WireGuard | 10.6.0.5 | `ssh root@10.6.0.5` |
| CT111 NFS | WireGuard | 10.6.0.20 | `ls /mnt/pve/ct111-shares` |

**Storage Access**:
```bash
ls /mnt/pve/fgsrv6-wg      # FGSRV6 NFS
ls /mnt/pve/ct111-shares   # CT111 NFS
ls /mnt/pve/aglsrv6-bb     # AGLSRV6 SSHFS
df -h | grep wg            # All WireGuard mounts
```

---

### From CT108 (agldv06)

**Available Networks**: Tailscale only
**Not Available**: WireGuard (not configured)

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| CT179 Dev | Tailscale | 100.94.221.87 | `ssh root@100.94.221.87` |
| AGLSRV1 Host | Tailscale | 100.107.113.33 | `ssh root@100.107.113.33` |
| AGLSRV6 Host | Local | 10.6.0.12 | Via host WireGuard |

---

### From AGLSRV6D (man6d)

**Available Networks**: LAN, WireGuard (PRIMARY), Tailscale
**Network Priority**: WireGuard > LAN > Tailscale

| Target | Method | Address | Example |
|--------|--------|---------|---------|
| FGSRV6 Hub | WireGuard | 10.6.0.5 | `ssh root@10.6.0.5` ⚡ |
| AGLSRV1 Host | WireGuard | 10.6.0.10 | `ssh root@10.6.0.10` ⚡ |
| AGLSRV6 Host | WireGuard | 10.6.0.12 | `ssh root@10.6.0.12` ⚡ |
| CT111 NFS | WireGuard | 10.6.0.20 | Access via `10.6.0.20` ⚡ |
| CT179 Dev | WireGuard | 10.6.0.19 | `ssh root@10.6.0.19` ⚡ |
| Any mesh node | WireGuard | 10.6.0.x | Full mesh access |
| AGLSRV1 Host | Tailscale | 100.107.113.33 | `ssh root@100.107.113.33` |
| CT179 Dev | Tailscale | 100.94.221.87 | `ssh root@100.94.221.87` |

⚡ = Fastest option (WireGuard mesh - 15-30ms latency)

---

### From Proxmox Hosts

**From AGLSRV1 Host**:
- Direct LAN access: 192.168.0.x
- Container console: `pct enter <VMID>`
- WireGuard mesh: 10.6.0.x
- Tailscale: 100.x.x.x

**From AGLSRV6 Host**:
- Container console: `pct enter <VMID>`
- WireGuard mesh: 10.6.0.x (PRIMARY)
- Tailscale: 100.x.x.x (fallback)

---

## 🔍 Quick Commands

### Infrastructure Status
```bash
# From any Proxmox host
pct list                    # List all containers
qm list                     # List all VMs
pvesm status               # Storage status

# From CT179 or remote
ssh root@192.168.0.245 'pct list'         # AGLSRV1
ssh root@10.6.0.12 'pct list'             # AGLSRV6 via WireGuard
```

### Network Testing
```bash
# WireGuard status
wg show                     # Show WireGuard status
wg show wg0 latest-handshakes  # Check peer connectivity

# Ping tests
ping 10.6.0.5              # FGSRV6 hub
ping 10.6.0.12             # AGLSRV6 host
ping 10.6.0.20             # CT111 NFS

# Route verification
ip route | grep wg         # WireGuard routes
ip route | grep tailscale  # Tailscale routes
```

### Storage Operations
```bash
# Check mounts
df -h | grep wg            # WireGuard storage
df -h | grep nfs           # NFS mounts
showmount -e 10.6.0.5      # FGSRV6 exports
showmount -e 10.6.0.20     # CT111 exports

# Remount if stale
umount -f /mnt/pve/fgsrv6-wg && mount -a
```

### Service Management
```bash
# Check container status
pct status <VMID>
pct enter <VMID>           # Console access

# Docker containers (from CT with Docker)
docker ps                  # List running containers
docker logs <container>    # View logs
docker-compose ps          # Compose stack status
```

---

## 📚 Related Documentation

- **Main Config**: `CLAUDE.md` - Claude Code configuration
- **Archon**: `docs/archon-integration.md` - AI Command Center
- **Docker in LXC**: `docs/docker-in-lxc-apparmor-solution.md`
- **WireGuard**: Various host-specific docs

---

**Document Version**: 2.1.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
**Always Read**: This document should ALWAYS be read for infrastructure queries

---

## 📝 Recent Changes

**v2.3.0 (2025-11-08)**:
- ✅ **AGLSRV5 Complete Analysis**: Full host documentation via Tailscale
  - Proxmox VE 8.4.14 on Debian 12, kernel 6.8.12-15-pve
  - Hardware: Intel Xeon E3-1220 v6 @ 3.00GHz, 62GB RAM
  - Storage: 1.75TB ZFS pool (70% used) + multiple storage pools
  - Networks: LAN (192.168.15.222), WireGuard (10.6.0.17), Tailscale (100.119.223.113)
  - Containers: 8 total (7 running) - Plex, Pi-hole, file server, Cloudflare tunnel
  - Access: Tailscale works perfectly, WireGuard has SSH auth issue
  - Different network segment (192.168.15.x) indicates separate physical location

**v2.2.0 (2025-11-08)**:
- ✅ **Infrastructure Inventory Complete**: All 5 Proxmox hosts now documented
  - AGLSRV1 (local), AGLSRV5 (remote), AGLSRV6 (remote), AGLSRV6C (remote), AGLSRV6D (remote)
- ❌ **AGLSRV6B Deprecated**: Marked as DEAD due to RAID card failure
  - Being replaced by AGLSRV6C (dual-network host at 192.168.0.233)
  - CT172 container marked as offline (host AGLSRV6B is dead)
- ✅ **WireGuard Mesh Table Complete**: Added missing nodes
  - CT183 (Archon AI) at 10.6.0.21:51821
  - AGLSRV6C at 10.6.0.22:51822
  - Updated mesh count: 15 active nodes, 17 total (2 offline: AGLSRV6B, CT172)

**v2.1.0 (2025-11-08)**:
- ✅ Added AGLSRV6D (man6d) - New Proxmox VE 9.0.11 host at same location as AGLSRV6
- Hardware: Intel i5-4590, 8GB RAM, 465GB SSD
- Networks: LAN (192.168.0.234), Tailscale (100.76.201.83), WireGuard (10.6.0.23)
- WireGuard: Fully configured and connected to mesh (port 51823)
- PublicKey: d9i/Izz71+3O4t2jMwt2L5N0m5mCVjph0GzplJGzXDM=
- Connectivity: Verified to hub (10.6.0.5), AGLSRV1 (10.6.0.10), AGLSRV6 (10.6.0.12)
- ✅ Proxmox VE: Installed, kernel 6.14.11-4-pve loaded, all services operational
- Web Interface: https://192.168.0.234:8006 (accessible via LAN)
- Status: Fully operational and ready for container/VM deployment
