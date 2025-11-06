# AGL Infrastructure Map

> **Last Updated**: 2025-10-27 | **Version**: 2.0.0
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
| WireGuard Mesh | 10.6.0.0/24 | Encrypted inter-site connectivity | ✅ Active (14 nodes) |
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

### Active Nodes (14 Total)

| Node | IP | Port | Type | Host | Status |
|------|-----|------|------|------|--------|
| **FGSRV6** | 10.6.0.5 | 51823 | Hub | Cloud VPS | ✅ Hub |
| CT120 | 10.6.0.1 | 51820 | Container | AGLSRV1 | ✅ |
| CT121 | 10.6.0.3 | 51821 | Container | AGLSRV6 | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | Local | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Host | Cloud VPS | ✅ |
| **AGLSRV6** | 10.6.0.12 | 51812 | Host | Remote | ✅ PRIMARY |
| AGLSRV6B | 10.6.0.13 | 51813 | Host | Remote | ✅ |
| CT113 | 10.6.0.14 | 51814 | Container | AGLSRV6 | ✅ |
| CT172 | 10.6.0.15 | 51815 | Container | AGLSRV6B | ✅ |
| FGSRV4 | 10.6.0.16 | 51816 | Host | Cloud VPS | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | Remote | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Host | Cloud VPS | ✅ |
| **CT179** | 10.6.0.19 | 51819 | Container | AGLSRV1 | ✅ Dev |
| **CT111** | 10.6.0.20 | 51820 | Container | AGLSRV6 | ✅ NFS |

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

**Document Version**: 2.0.0
**Last Updated**: 2025-10-27
**Maintainer**: Claude Code (agl-hostman project)
**Always Read**: This document should ALWAYS be read for infrastructure queries
