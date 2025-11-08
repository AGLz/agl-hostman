# Infrastructure Physical Topology and Network Architecture

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: Physical locations and network topology

---

## 🏢 Physical Locations Overview

The infrastructure is distributed across **4 physical locations**, each with its own network segment and connectivity profile.

### Location Summary

| Location | Network Segment | Hosts | Connectivity | Critical Services |
|----------|----------------|-------|--------------|-------------------|
| **AGLHQ** | 192.168.0.0/24 | 4 (3 active, 1 offline) | LAN + WG + TS | Production, Development, AI |
| **AGLFG** | 192.168.15.0/24 | 1 | LAN + WG + TS | Storage, Media |
| **AGLALD** | 192.168.0.0/24 | 4 (3 active, 1 dead) | LAN + WG + TS | Backup, Development, NFS |
| **AGLFG-VPS** | Public IPs | 4 | WG + TS | WireGuard Hub, NFS |

**Total Infrastructure**:
- 13 physical/virtual hosts (12 active, 1 offline)
- 6 Proxmox VE hosts (5 active, 1 offline)
- 3 network layers (LAN, WireGuard, Tailscale)

---

## 📍 AGLHQ (Headquarters)

### Location Details
- **Network**: 192.168.0.0/24
- **Connectivity**: Full stack (LAN + WireGuard + Tailscale)
- **Type**: Primary production environment

### Hosts and Devices

| Host/Device | Type | Status | Networks |
|-------------|------|--------|----------|
| **AGLSRV1** | Proxmox VE Host | ✅ Active | LAN, WG (10.6.0.10), TS (100.107.113.33) |
| **AGLSRV3** | Proxmox VE Host | ⚠️ Offline | To be analyzed when powered on |
| **AGLHQ11** | Physical Machine | ✅ Active | LAN, TS (present in network) |
| **AGLFA02** | Physical Machine | ✅ Active | LAN only (not in Tailscale yet) |

### Key Services

**AGLSRV1 (Main Production Host)**:
- 68 containers/VMs (42 running, 26 stopped)
- Development: CT179 (agldv03 - 48GB RAM), CT180 (dokploy)
- AI Infrastructure: CT183 (Archon AI), CT200 (ollama-gpu), CT202 (n8n)
- DNS/DHCP: CT102 (pihole)
- Monitoring: CT132 (observium), CT162 (meshcentral)
- Media: CT113 (plex), CT121-124 (arr stack)

### Infrastructure Role
- Primary production environment
- Main development containers
- AI/ML infrastructure
- Central DNS and monitoring

---

## 📍 AGLFG (Remote Standalone Site)

### Location Details
- **Network**: 192.168.15.0/24 (independent segment)
- **Connectivity**: Full stack (LAN + WireGuard + Tailscale)
- **Type**: Remote standalone location

### Hosts and Devices

| Host/Device | Type | Status | Networks |
|-------------|------|--------|----------|
| **AGLSRV5** | Proxmox VE Host | ✅ Active | LAN (192.168.15.222), WG (10.6.0.17), TS (100.119.223.113) |

### Key Services

**AGLSRV5 (Storage and Media)**:
- Large storage capacity: 1.75TB ZFS pool (70% used)
- Media services: CT132 (plex5)
- Network services: CT133 (mesh5), CT139 (pihole5)
- File server: CT138 (fileserver5)
- Cloudflare tunnel: CT130 (cloudflared5)
- Total containers: 8 (7 running, 1 stopped)

### Infrastructure Role
- Independent storage location
- Media streaming services
- File server for remote access
- Backup DNS/network services

### Important Notes
- Standalone location with independent network segment
- Different LAN segment (192.168.15.x) vs other sites (192.168.0.x)
- **Access recommendation**: Use Tailscale (WireGuard has SSH auth issue)

---

## 📍 AGLALD (Remote Site)

### Location Details
- **Network**: 192.168.0.0/24 (same segment as AGLHQ but different physical location)
- **Connectivity**: Full stack (LAN + WireGuard + Tailscale)
- **Type**: Remote site with backup/failover capacity

### Hosts and Devices

| Host/Device | Type | Status | Networks |
|-------------|------|--------|----------|
| **AGLSRV6** | Proxmox VE Host | ✅ Active | WG (10.6.0.12), TS (100.98.108.66) |
| **AGLSRV6B** | Proxmox VE Host | ❌ DEAD | RAID card failure, replaced by AGLSRV6C |
| **AGLSRV6C** | Proxmox VE Host | ✅ Active | LAN (192.168.0.233), WG (10.6.0.22), TS (100.124.53.91) |
| **AGLSRV6D** | Proxmox VE Host | ✅ Active | LAN (192.168.0.234), WG (10.6.0.23), TS (100.76.201.83) |

### Key Services

**AGLSRV6 (Primary Remote Host)**:
- 11 containers, 6 VMs
- Large storage: 954GB + 3.9TB + 1.2TB PBS
- CT111 (aluzdivina): NFS server for mesh (10.6.0.20)
- CT108 (agldv06): Development container
- CT113, CT172: Proxmox Backup Server instances

**AGLSRV6C (Full Operational)**:
- Proxmox VE 9.0.11 on Debian 13
- Full operational capacity
- Dual-network setup (LAN + WireGuard + Tailscale)
- Replacement for AGLSRV6B

**AGLSRV6D (Failsafe/Backup)**:
- Proxmox VE 9.0.11 on Debian 13
- Desktop converted to server
- 8GB RAM, 465GB storage
- Role: Failsafe backup for AGLSRV6 + AGLSRV6C

### Infrastructure Role
- Backup and failover capacity
- NFS storage for WireGuard mesh
- Development containers
- Proxmox Backup Server instances

### Important Notes
- AGLSRV6D is desktop hardware converted to server role
- AGLSRV6B deprecated due to RAID card hardware failure
- AGLSRV6C is full replacement for AGLSRV6B

---

## 📍 AGLFG-VPS (Cloud Virtual Private Servers)

### Location Details
- **Network**: Public IPs with WireGuard overlay (10.6.0.0/24)
- **Connectivity**: WireGuard mesh + Tailscale
- **Type**: Cloud infrastructure across multiple providers

### Hosts and Devices

| Host/Device | Type | Status | Networks |
|-------------|------|--------|----------|
| **FGSRV3** | Proxmox VE VPS | ✅ Active | Public IP (191.252.201.205), WG (10.6.0.18), TS (100.67.99.115) |
| **FGSRV4** | Proxmox VE VPS | ✅ Active | Public DNS (vps22826), WG (10.6.0.16), TS (100.111.79.2) |
| **FGSRV5** | Proxmox VE VPS | ✅ Active | Public IP (191.252.200.20), WG (10.6.0.11), TS (100.71.107.26) |
| **FGSRV6** | Proxmox VE VPS | ✅ **Hub** | Public IP (186.202.57.120), WG (10.6.0.5:51823), TS (100.83.51.9) |

### Key Services

**FGSRV6 (Critical Infrastructure - WireGuard Hub)**:
- **WireGuard mesh hub** - central routing point for entire infrastructure
- Public endpoint: 186.202.57.120:51823
- NFS server: 197GB export, mounted at AGLSRV1 as `fgsrv6-wg`
- Provider: vps41772.publiccloud.com.br

**FGSRV5 (NFS Storage)**:
- NFS server: 77GB export, mounted at AGLSRV1 as `fgsrv5-wg`
- Provider: vps24136.publiccloud.com.br

**FGSRV4 (General Purpose)**:
- Provider: vps22826.publiccloud.com.br
- Tailscale working: 100.111.79.2

**FGSRV3 (General Purpose)**:
- Provider: vps14419
- Tailscale working: 100.67.99.115

### Infrastructure Role
- **FGSRV6 is CRITICAL** - WireGuard mesh hub for all inter-site connectivity
- Distributed NFS storage (FGSRV5, FGSRV6)
- Public IP endpoints for VPN termination
- Cloud-based redundancy

### Important Notes
- FGSRV6 failure would disrupt entire WireGuard mesh
- Public IPs allow external access and VPN connections
- Multiple cloud providers for redundancy

---

## 🌐 Network Architecture

### Network Layers

**1. Local LAN**:
- AGLHQ/AGLALD: 192.168.0.0/24
- AGLFG: 192.168.15.0/24
- Direct local connectivity
- Fastest performance for same-location hosts

**2. WireGuard Mesh (Primary)**:
- Network: 10.6.0.0/24
- Hub: FGSRV6 (186.202.57.120:51823)
- 15 active nodes, 17 total configured
- Encrypted inter-site connectivity
- See `WIREGUARD.md` for complete mesh details

**3. Tailscale Overlay (Backup)**:
- Network: 100.64.0.0/10
- Cross-site VPN
- Fallback when WireGuard unavailable
- Easier access from mobile/remote

### Connection Priority

From any source:
1. **LAN** (if same location) - Fastest
2. **WireGuard** (if configured) - Encrypted, fast
3. **Tailscale** (always available) - Reliable fallback

---

## 📊 Infrastructure Statistics

### Host Count by Location

| Location | Proxmox Hosts | Other Machines | Total | Status |
|----------|---------------|----------------|-------|--------|
| AGLHQ | 2 (1 active, 1 offline) | 2 | 4 | ✅ Primary |
| AGLFG | 1 | 0 | 1 | ✅ Active |
| AGLALD | 4 (3 active, 1 dead) | 0 | 4 | ✅ Active |
| AGLFG-VPS | 4 | 0 | 4 | ✅ Active |

### Network Coverage

| Location | LAN | WireGuard | Tailscale |
|----------|-----|-----------|-----------|
| AGLHQ | ✅ | ✅ | ✅ |
| AGLFG | ✅ | ✅ | ✅ |
| AGLALD | ✅ | ✅ | ✅ |
| AGLFG-VPS | ❌ | ✅ | ✅ |

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md` - Complete infrastructure map
- **Hosts Details**: `HOSTS.md` - Detailed host configurations and resources
- **WireGuard Mesh**: `WIREGUARD.md` - Complete mesh configuration
- **Storage**: `STORAGE.md` - Storage configuration and NFS mounts
- **Connections**: `CONNECTIONS.md` - Connection matrix and priorities

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
