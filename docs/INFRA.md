# AGL Infrastructure Map - Central Reference

> **Last Updated**: 2025-11-10 | **Version**: 3.1.0
> **Reference**: Central infrastructure overview with links to detailed documentation

---

## 📚 Documentation Structure

This document serves as the **central reference point** for the entire infrastructure. For detailed information, refer to the specialized documentation files:

### Infrastructure Documentation

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[PROXMOX.md](PROXMOX.md)** | Installation standards, deployment status | Setting up new hosts, troubleshooting OS issues |
| **[TOPOLOGY.md](TOPOLOGY.md)** | Physical locations, network architecture | Understanding site layout, planning expansions |
| **[HOSTS.md](HOSTS.md)** | Detailed host configurations | Looking up host specs, network addresses, resources |
| **[WIREGUARD.md](WIREGUARD.md)** | Mesh network configuration, standards | Adding nodes, troubleshooting connectivity |
| **[STORAGE.md](STORAGE.md)** | Storage mounts, NFS exports | Managing storage, mounting shares |
| **[CONTAINERS.md](CONTAINERS.md)** | Container inventory, key services | Finding containers, checking services |
| **[CONNECTIONS.md](CONNECTIONS.md)** | Access patterns, connection priorities | Connecting to hosts, troubleshooting access |
| **[SSH-CONFIG.md](SSH-CONFIG.md)** | SSH configuration, keys, aliases | SSH setup, key management |

### Development & AI Documentation

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[SUPERCLAUDE-DEPLOYMENT.md](SUPERCLAUDE-DEPLOYMENT.md)** | SuperClaude Hive-Mind deployment guide | Installing multi-agent system on new containers |
| **[AGLDV3-DEPLOYMENT-GUIDE.md](AGLDV3-DEPLOYMENT-GUIDE.md)** | CT179 original deployment guide | Reference for CT179 configuration |
| **[CT179-vs-CT181-COMPARISON.md](CT179-vs-CT181-COMPARISON.md)** | CT179/CT181 comparison and deployment | Understanding differences between dev containers |

---

## 🌐 Network Overview

### Network Segments

| Network | CIDR | Purpose | Status | Details |
|---------|------|---------|--------|---------|
| **WireGuard Mesh** | 10.6.0.0/24 | Encrypted inter-site connectivity | ✅ 16 nodes active | See [WIREGUARD.md](WIREGUARD.md) |
| **Local LAN** | 192.168.0.0/24 | Primary local network | ✅ Active | AGLHQ, AGLALD locations |
| **Local LAN Alt** | 192.168.1.0/24 | Secondary local network | ✅ Active | AGLSRV6C secondary |
| **Remote LAN** | 192.168.15.0/24 | AGLFG standalone network | ✅ Active | AGLSRV5 only |
| **Tailscale** | 100.64.0.0/10 | Cross-site VPN overlay | ✅ Active | Fallback connectivity |

### WireGuard Hub (CRITICAL)

- **Server**: FGSRV6 (vps41772.publiccloud.com.br)
- **Public IP**: 186.202.57.120
- **WireGuard IP**: 10.6.0.5
- **Port**: 51823/UDP
- **Type**: Hub-and-spoke + mesh hybrid
- **Importance**: **CRITICAL** - Central routing point, failure affects entire mesh

**Complete Details**: See [WIREGUARD.md](WIREGUARD.md) for configuration, node inventory, and deployment procedures.

---

## 📍 Physical Locations Summary

| Location | Type | Hosts | Status | Details |
|----------|------|-------|--------|---------|
| **AGLHQ** | Headquarters | AGLSRV1, AGLSRV3, AGLHQ11, AGLFA02 | ✅ Active | Main production site (2 Proxmox hosts) |
| **AGLFG** | Remote Site | AGLSRV5 | ✅ Active | Standalone network (192.168.15.x) |
| **AGLALD** | Remote Site | AGLSRV6, AGLSRV6C, AGLSRV6D | ✅ Active | Backup/failover capacity |
| **AGLFG-VPS** | Cloud | FGSRV3, FGSRV4, FGSRV5, FGSRV6 | ✅ Active | Cloud infrastructure |

**Complete Details**: See [TOPOLOGY.md](TOPOLOGY.md) for network architecture, routing diagrams, and connectivity patterns.

---

## 🖥️ Hosts Quick Reference

| Host | Location | Type | Networks | Status | Details |
|------|----------|------|----------|--------|---------|
| **AGLSRV1** | AGLHQ | Production | LAN + WG + TS | ✅ 68 CTs | [HOSTS.md](HOSTS.md#aglsrv1) |
| **AGLSRV3** | AGLHQ | Production | LAN + WG + TS | ✅ 1 CT + 5 VMs | [HOSTS.md](HOSTS.md#aglsrv3) |
| **AGLSRV5** | AGLFG | Remote | LAN + WG + TS | ✅ 8 CTs | [HOSTS.md](HOSTS.md#aglsrv5) |
| **AGLSRV6** | AGLALD | Remote | WG + TS | ✅ 11 CTs | [HOSTS.md](HOSTS.md#aglsrv6) |
| **AGLSRV6B** | AGLALD | Dead | None | ❌ Dead | Deprecated |
| **AGLSRV6C** | AGLALD | Remote | LAN + WG + TS | ✅ Ready | [HOSTS.md](HOSTS.md#aglsrv6c) |
| **AGLSRV6D** | AGLALD | Remote | LAN + WG + TS | ✅ Ready | [HOSTS.md](HOSTS.md#aglsrv6d) |
| **FGSRV3** | VPS | Cloud | Public + WG + TS | ✅ Active | [HOSTS.md](HOSTS.md#fgsrv3) |
| **FGSRV4** | VPS | Cloud | WG + TS | ✅ Active | [HOSTS.md](HOSTS.md#fgsrv4) |
| **FGSRV5** | VPS | Cloud | Public + WG + TS | ✅ Active | [HOSTS.md](HOSTS.md#fgsrv5) |
| **FGSRV6** | VPS | Cloud Hub | Public + WG + TS | ✅ **Hub** | [HOSTS.md](HOSTS.md#fgsrv6) |

**Network Codes**:
- **LAN**: Local Area Network (192.168.x.x)
- **WG**: WireGuard (10.6.0.x)
- **TS**: Tailscale (100.x.x.x)

**Complete Details**: See [HOSTS.md](HOSTS.md) for detailed configurations, hardware specs, and access methods.

---

## 🔗 WireGuard Mesh Summary

### Active Nodes (16 of 17 total)

| Node | IP | Port | Host | Type | Status |
|------|-----|------|------|------|--------|
| **FGSRV6** | 10.6.0.5 | 51823 | Cloud VPS | Hub | ✅ **CRITICAL** |
| CT120 | 10.6.0.1 | 51820 | AGLSRV1 | Container | ✅ |
| CT121 | 10.6.0.3 | 51821 | AGLSRV6 | Container | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | Host | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Cloud VPS | Host | ✅ |
| **AGLSRV6** | 10.6.0.12 | 51812 | Host | Host | ✅ Primary |
| AGLSRV6B | 10.6.0.13 | 51813 | Host | Host | ❌ Dead |
| CT113 | 10.6.0.14 | 51814 | AGLSRV6 | Container | ✅ PBS |
| CT172 | 10.6.0.15 | 51815 | AGLSRV6B | Container | ⚠️ Host offline |
| FGSRV4 | 10.6.0.16 | 51816 | Cloud VPS | Host | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | Host | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Cloud VPS | Host | ✅ |
| **CT179** | 10.6.0.19 | 51819 | AGLSRV1 | Container | ✅ Dev |
| **CT111** | 10.6.0.20 | 51820 | AGLSRV6 | Container | ✅ NFS |
| **CT183** | 10.6.0.21 | 51821 | AGLSRV1 | Container | ✅ Archon |
| **AGLSRV6C** | 10.6.0.22 | 51822 | Host | Host | ✅ Active |
| **AGLSRV6D** | 10.6.0.23 | 51823 | Host | Host | ✅ Active |
| **AGLSRV3** | 10.6.0.24 | 51824 | AGLSRV3 | Host | ✅ Active |

### Critical Nodes

| Node | Role | Importance | Notes |
|------|------|------------|-------|
| **FGSRV6** (10.6.0.5) | Hub | **CRITICAL** | Central routing - failure affects entire mesh |
| **CT179** (10.6.0.19) | Development | High | Main dev container (48GB RAM) |
| **CT111** (10.6.0.20) | NFS Server | High | Distributed storage |
| **CT183** (10.6.0.21) | Archon AI | High | AI Command Center + MCP |

**Complete Details**: See [WIREGUARD.md](WIREGUARD.md) for configuration standards, deployment procedures, and troubleshooting.

---

## 💾 Storage Summary

### AGLSRV1 Storage Overview

| Storage | Size | Type | Source | Status |
|---------|------|------|--------|--------|
| local-zfs | 1.7TB | ZFS | Local pool | ✅ |
| spark | 7.1TB | Local | Disk | ✅ 91.54% |
| overpower | 9.8TB | Local | Disk | ✅ 92.54% |
| fgsrv6-wg | 197GB | NFS | 10.6.0.5 | ✅ |
| fgsrv5-wg | 77GB | NFS | 10.6.0.11 | ✅ |
| ct111-shares | 66GB | NFS | 10.6.0.20:/mnt/shares | ✅ |
| ct111-sistema | 818GB | NFS | 10.6.0.20:/mnt/sistema | ✅ |
| aglsrv6-bb | 954GB | SSHFS | 10.6.0.12 | ✅ |
| aglsrv6-usb4tb | 3.9TB | SSHFS | 10.6.0.12 | ✅ |

**Total WireGuard Storage**: 6.0 TB (1.2TB NFS + 4.8TB SSHFS)

### CT111 NFS Server (AGLSRV6)

- **WireGuard**: 10.6.0.20 (Port 51820)
- **Tailscale**: 100.65.189.83
- **Exports**: /mnt/shares (66GB), /mnt/sistema (819GB)
- **Networks**: 192.168.0.0/24, 10.6.0.0/24

### CT138 NFS Server (AGLSRV5)

- **WireGuard**: 10.6.0.51
- **LAN**: 192.168.15.100 (DHCP)
- **Internal**: 172.2.2.138
- **Exports**: /storage/nfs-export
- **Networks**: 192.168.0.0/24, 192.168.15.0/24, 10.6.0.0/24

**Complete Details**: See [STORAGE.md](STORAGE.md) for mount points, NFS configuration, and performance metrics.

---

## 📦 Container Summary

### By Host

| Host | Total | Running | Stopped | Key Services |
|------|-------|---------|---------|--------------|
| **AGLSRV1** | 68 | 42 | 26 | Development, AI, DNS, Media |
| **AGLSRV5** | 8 | 7 | 1 | Media, File Server, Cloudflare |
| **AGLSRV6** | 11 | - | - | NFS, Development, PBS |

### Key Containers

| Container | Host | Purpose | Networks | Notes |
|-----------|------|---------|----------|-------|
| **CT179** (agldv03) | AGLSRV1 | Development | LAN + WG + TS | 48GB RAM, Docker |
| **CT180** (dokploy) | AGLSRV1 | Deployment | LAN | https://dok.aglz.io |
| **CT183** (archon) | AGLSRV1 | AI Command | LAN + WG + TS | Archon MCP Server |
| **CT200** (ollama-gpu) | AGLSRV1 | GPU Inference | LAN + TS | NVIDIA GPU |
| **CT111** (aluzdivina) | AGLSRV6 | NFS Server | WG + TS | Storage exports |
| **CT108** (agldv06) | AGLSRV6 | Development | TS only | Remote dev |
| **CT113** (PBS) | AGLSRV6 | Backup | WG + TS | Proxmox Backup |

**Complete Details**: See [CONTAINERS.md](CONTAINERS.md) for full inventory organized by host and service category.

---

## 🔀 Connection Priority Matrix

### From WSL2 (AGLHQ11)

**Available Networks**: Tailscale only (100.75.205.122)

| Destination | Method | Address | Notes |
|-------------|--------|---------|-------|
| CT179 | Tailscale | 100.94.221.87 | Development container |
| AGLSRV1 | Tailscale | 100.107.113.33 | Main host |
| AGLSRV5 | Tailscale | 100.119.223.113 | Remote host |
| AGLSRV6 | Tailscale | 100.98.108.66 | Remote host |

**Limitations**: ❌ No WireGuard, ❌ No local LAN, ❌ No Docker

### From CT179 (agldv03)

**Available Networks**: LAN + WireGuard + Tailscale (Full stack)

| Destination | 1st Priority | 2nd Priority | 3rd Priority | Recommended |
|-------------|--------------|--------------|--------------|-------------|
| AGLSRV1 | LAN (192.168.0.245) | WG (10.6.0.10) | TS (100.107.113.33) | **LAN** ⚡ |
| AGLSRV5 | WG (10.6.0.17) | TS (100.119.223.113) | - | **Tailscale** 🔧 |
| AGLSRV6 | WG (10.6.0.12) | TS (100.98.108.66) | - | **WireGuard** |
| FGSRV6 | WG (10.6.0.5) | TS (100.83.51.9) | Public (186.202.57.120) | **WireGuard** |
| CT111 (NFS) | WG (10.6.0.20) | TS (100.65.189.83) | - | **WireGuard** |
| CT183 (Archon) | LAN (192.168.0.183) | WG (10.6.0.21) | TS (100.80.30.59) | **LAN** ⚡ |

### From CT108 (agldv06)

**Available Networks**: Tailscale only (100.71.229.12)
**Location**: AGLSRV6 (AGLALD)

Similar to WSL2, but with better container performance and local access to AGLSRV6 resources.

### Network Layer Characteristics

| Network | Speed | Latency | Security | Use Case |
|---------|-------|---------|----------|----------|
| **LAN** | ⚡⚡⚡ Fastest | <1ms | 🟡 Local only | Local operations |
| **WireGuard** | ⚡⚡ Fast | 15-30ms | 🟢 Encrypted | Primary remote |
| **Tailscale** | ⚡ Medium | 30-100ms | 🟢 Encrypted | Fallback/mobile |

**Complete Details**: See [CONNECTIONS.md](CONNECTIONS.md) for connection methods, SSH commands, and troubleshooting.

---

## 🚨 Known Issues

### AGLSRV5 WireGuard SSH

**Issue**: SSH connection closes immediately after key exchange
- WireGuard: ✅ Working (ping successful)
- SSH: ❌ Failing on WireGuard interface
- **Workaround**: Use Tailscale (100.119.223.113)
- **Status**: Pending investigation

### FGSRV5 Tailscale Timeout

**Issue**: Tailscale connection timeout
- Tailscale: ❌ Timeout (100.71.107.26)
- Public IP: ✅ Working (191.252.200.20)
- **Workaround**: Use public IP with key auth
- **Status**: Requires local investigation

**Complete Troubleshooting**: See [CONNECTIONS.md](CONNECTIONS.md) and [WIREGUARD.md](WIREGUARD.md) for diagnostic procedures.

---

## 🔑 SSH Configuration

Quick SSH commands for common destinations:

```bash
# From CT179 (full access)
ssh root@192.168.0.245  # AGLSRV1 (LAN - fastest)
ssh root@10.6.0.12      # AGLSRV6 (WireGuard)
ssh root@10.6.0.21      # CT183 Archon (WireGuard)

# From WSL2 (Tailscale only)
ssh root@100.94.221.87    # CT179
ssh root@100.107.113.33   # AGLSRV1
ssh root@100.119.223.113  # AGLSRV5 (recommended for SSH)
```

**Complete Details**: See [SSH-CONFIG.md](SSH-CONFIG.md) for complete SSH configuration, keys, and aliases.

---

## 📚 Quick Reference Commands

### Check Container Status
```bash
# From AGLSRV1
pct list

# Remote check
ssh root@192.168.0.245 'pct list'
```

### Check WireGuard Status
```bash
# Show WireGuard configuration
wg show wg0

# Test mesh connectivity
ping 10.6.0.5  # Hub
```

### Access NFS Storage
```bash
# Check NFS mounts
df -h | grep wg

# Test NFS connectivity
showmount -e 10.6.0.20  # CT111
```

### Docker Operations (from CT179)
```bash
# Check containers
docker ps

# Check images
docker images

# System info
docker system df
```

---

## 📊 Infrastructure Statistics

- **Total Hosts**: 11 (7 active Proxmox hosts + 4 cloud VPS)
- **Total Containers**: 87+ across all hosts
- **WireGuard Nodes**: 15 active (17 configured, 2 offline)
- **Storage Capacity**: 30+ TB across local and remote storage
- **Network Segments**: 4 (LAN, LAN-Alt, Remote-LAN, Tailscale)
- **Physical Locations**: 4 (AGLHQ, AGLFG, AGLALD, AGLFG-VPS)

---

## 🔗 External Services

### Archon AI Command Center (CT183)

**Internal Access**:
- WireGuard: http://10.6.0.21:8051/8052
- Tailscale: http://100.80.30.59:8051/8052
- LAN: http://192.168.0.183:8051/8052 (dev only)

**External Access**:
- Public DNS: https://archon.aglz.io
- Authentication: Basic Auth (admin/ArchonPass2025)

### Dokploy Deployment Platform (CT180)

**External Access**:
- Public DNS: https://dok.aglz.io
- Cloudflare Tunnel secured

---

## 📚 Complete Documentation Index

### Core Infrastructure
- **[INFRA.md](INFRA.md)** - This file (central reference)
- **[PROXMOX.md](PROXMOX.md)** - Installation standards and requirements
- **[TOPOLOGY.md](TOPOLOGY.md)** - Physical locations and network architecture
- **[HOSTS.md](HOSTS.md)** - Detailed host configurations

### Network & Connectivity
- **[WIREGUARD.md](WIREGUARD.md)** - Mesh network configuration and standards
- **[CONNECTIONS.md](CONNECTIONS.md)** - Access patterns and connection priorities
- **[SSH-CONFIG.md](SSH-CONFIG.md)** - SSH configuration, keys, and aliases

### Services & Storage
- **[STORAGE.md](STORAGE.md)** - Storage configuration and NFS mounts
- **[CONTAINERS.md](CONTAINERS.md)** - Complete container inventory
- **[ARCHON.md](../ARCHON.md)** - Archon AI integration guide (project root)
- **[DOKPLOY.md](DOKPLOY.md)** - Deployment platform documentation

### Procedures & Troubleshooting
- **[QUICK-START.md](QUICK-START.md)** - Fast reference and common commands
- **[WORKFLOWS.md](WORKFLOWS.md)** - SPARC methodology and Agent OS
- **[RULES.md](RULES.md)** - Coding standards and execution patterns

---

**Document Version**: 3.0.0 (Major restructure - modular documentation)
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)

**What Changed in v3.0.0**:
- ✨ Modularized into 7 specialized documentation files
- 📊 Transformed INFRA.md into central reference document
- 🔗 Added cross-references between all documents
- 📉 Reduced size from 1033 lines to ~400 lines (60% reduction)
- 🎯 Improved navigability with clear document purpose statements
- 📚 Following same pattern as CLAUDE.md optimization
