# Quick Start Guide - AGL Infrastructure

> **Last Updated**: 2025-11-08 | **Version**: 1.1.0

**Purpose**: Fast reference for common commands, connection patterns, and environment-specific operations.

**When to read**: When you need quick commands for connections, storage access, Docker operations, or troubleshooting.

---

## 📑 Table of Contents

1. [Environment Detection](#-environment-detection)
2. [Quick Connection Matrix](#-quick-connection-matrix)
3. [Common SSH Commands](#-common-ssh-commands)
4. [Storage Access](#-storage-access)
5. [Docker Operations](#-docker-operations)
6. [Archon Quick Commands](#-archon-quick-commands)
7. [Troubleshooting](#-troubleshooting)
8. [Document Navigation](#-document-navigation)

---

## 🔍 Environment Detection

**Quick Check - Where am I running?**

```bash
# Detect current environment
if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then
    echo "WSL2 (AGLHQ11)" # Tailscale only
elif [[ -f /etc/pve/.version ]]; then
    echo "Proxmox Host"
elif [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "Container (CT179/CT108)"
else
    echo "Unknown environment"
fi
```

**Environment Capabilities**:

| Environment | LAN | WireGuard | Tailscale | Docker | pct |
|-------------|-----|-----------|-----------|--------|-----|
| WSL2 (AGLHQ11) | ❌ | ❌ | ✅ | ❌ | ❌ |
| CT179 (agldv03) | ✅ | ✅ | ✅ | ✅ | Via host |
| CT108 (agldv06) | Limited | ❌ | ✅ | ⚠️ | Via host |
| AGLSRV6D (man6d) | ✅ | ⏳ Pending | ✅ | ⏳ Pending | ⏳ After Proxmox |

---

## 🌐 Quick Connection Matrix

### From WSL2 (Tailscale Only)

```bash
# Connect to hosts
ssh root@100.94.221.87   # CT179 (primary dev)
ssh root@100.107.113.33  # AGLSRV1 host
ssh root@100.98.108.66   # AGLSRV6 host
ssh root@100.76.201.83   # AGLSRV6D (man6d) - Debian 13
ssh root@100.71.229.12   # CT108 (agldv06)

# Check infrastructure
ssh root@100.107.113.33 'pct list'  # AGLSRV1 containers
ssh root@100.98.108.66 'pct list'   # AGLSRV6 containers
```

### From CT179 (Full Stack - Prefer WireGuard)

```bash
# WireGuard mesh (fastest)
ssh root@10.6.0.12   # AGLSRV6 via WireGuard
ssh root@10.6.0.5    # FGSRV6 via WireGuard
ssh root@10.6.0.20   # CT111 (aluzdivina) via WireGuard

# Local LAN
ssh root@192.168.0.245  # AGLSRV1 host
ssh root@192.168.0.202  # n8n container
ssh root@192.168.0.200  # ollama-gpu container

# Tailscale (fallback)
ssh root@100.98.108.66  # AGLSRV6 host
ssh root@100.71.229.12  # CT108

# Proxmox commands (via host)
ssh root@192.168.0.245 'pct list'
ssh root@192.168.0.245 'pct exec 183 -- docker ps'
```

### Connection Priority by Target

| Target | From WSL2 | From CT179 | From CT108 |
|--------|-----------|------------|------------|
| AGLSRV1 Host | 100.107.113.33 (TS) | 192.168.0.245 (LAN) or 10.6.0.10 (WG) | 100.107.113.33 (TS) |
| AGLSRV6 Host | 100.98.108.66 (TS) | 10.6.0.12 (WG) ⚡ | 10.6.0.12 or 100.98.108.66 |
| AGLSRV6D Host | 100.76.201.83 (TS) | 192.168.0.234 (LAN) ⏳ 10.6.0.22 (WG) | 100.76.201.83 (TS) |
| FGSRV6 Host | 100.83.51.9 (TS) | 10.6.0.5 (WG) ⚡ | 100.83.51.9 (TS) |
| CT179 Dev | 100.94.221.87 (TS) | 192.168.0.179 (LAN) | 100.94.221.87 (TS) |
| CT183 Archon | Via host | 192.168.0.183 (LAN) or 10.6.0.21 (WG) | Via host |

⚡ = Fastest option (WireGuard mesh)

---

## 🔧 Common SSH Commands

### Check Container Status

**From WSL2**:
```bash
ssh root@100.107.113.33 'pct list'  # AGLSRV1
ssh root@100.98.108.66 'pct list'   # AGLSRV6
```

**From CT179**:
```bash
# Direct LAN (fastest)
ssh root@192.168.0.245 'pct list'  # AGLSRV1
ssh root@10.6.0.12 'pct list'      # AGLSRV6 via WireGuard
```

### Execute Commands in Containers

```bash
# Via pct exec on Proxmox host
ssh root@192.168.0.245 'pct exec 183 -- docker ps'
ssh root@192.168.0.245 'pct exec 183 -- systemctl status nginx'

# Direct SSH to container (if configured)
ssh root@192.168.0.183  # CT183 (Archon)
```

### Check Network Connectivity

```bash
# Test WireGuard mesh
ping 10.6.0.5   # FGSRV6 hub
ping 10.6.0.12  # AGLSRV6

# Test Tailscale
ping 100.98.108.66  # AGLSRV6

# Check WireGuard status
wg show
```

---

## 💾 Storage Access

### NFS Mounts via WireGuard

**From WSL2** (Cannot mount directly):
```bash
# Access via SSH
ssh root@100.94.221.87 'ls /mnt/pve/fgsrv6-wg'
ssh root@100.94.221.87 'ls /mnt/pve/ct111-shares'
```

**From CT179** (Direct mounts):
```bash
# List WireGuard NFS mounts
df -h | grep wg

# Access storage
ls /mnt/pve/fgsrv6-wg      # 197GB from FGSRV6
ls /mnt/pve/fgsrv5-wg      # 77GB from FGSRV5
ls /mnt/pve/ct111-shares   # 66GB from CT111
ls /mnt/pve/ct111-sistema  # 818GB from CT111

# Check mount status
mount | grep wg
```

### SSHFS Mounts via WireGuard

**From CT179**:
```bash
# Check SSHFS mounts
df -h | grep aglsrv6

# Access SSHFS storage
ls /mnt/pve/aglsrv6-bb      # 954GB from AGLSRV6
ls /mnt/pve/aglsrv6-usb4tb  # 3.9TB from AGLSRV6
```

### Storage Quick Reference

| Storage | Type | Size | Source | Access From |
|---------|------|------|--------|-------------|
| fgsrv6-wg | NFS | 197GB | 10.6.0.5 | CT179 direct |
| fgsrv5-wg | NFS | 77GB | 10.6.0.11 | CT179 direct |
| ct111-shares | NFS | 66GB | 10.6.0.20 | CT179 direct |
| ct111-sistema | NFS | 818GB | 10.6.0.20 | CT179 direct |
| aglsrv6-bb | SSHFS | 954GB | 10.6.0.12 | CT179 direct |
| aglsrv6-usb4tb | SSHFS | 3.9TB | 10.6.0.12 | CT179 direct |

---

## 🐳 Docker Operations

### From WSL2 (Remote Only)

```bash
# Execute Docker commands remotely
ssh root@100.94.221.87 'docker ps'
ssh root@100.94.221.87 'docker logs archon-mcp'
ssh root@100.94.221.87 'cd /root/agl-hostman && docker compose up -d'
```

### From CT179 (Native)

```bash
# Native Docker commands
docker ps
docker ps -a
docker logs <container>
docker logs -f <container>  # Follow logs

# Docker Compose
cd /root/agl-hostman
docker compose up -d
docker compose down
docker compose restart

# Container management
docker exec -it <container> bash
docker stop <container>
docker start <container>
```

### Archon Container Management

```bash
# Check Archon services
ssh root@192.168.0.245 'pct exec 183 -- docker ps'

# View logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-ui'

# Restart services (use docker compose, not docker-compose!)
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart"'
```

---

## 🤖 Archon Quick Commands

### MCP Connection Setup

```bash
# LAN (development)
claude mcp add --transport http archon http://192.168.0.183:8052/mcp

# WireGuard (primary external)
claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp

# Tailscale (backup external)
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp

# Verify connections
claude mcp list
```

### Archon Health Checks

```bash
# Test MCP endpoints
curl http://192.168.0.183:8051/mcp  # Direct Docker
curl http://192.168.0.183:8052/mcp  # nginx LAN
curl http://10.6.0.21:8051/mcp      # WireGuard
curl http://100.80.30.59:8051/mcp   # Tailscale

# Test with Basic Auth (public HTTPS)
curl -u admin:ArchonPass2025 https://archon.aglz.io
```

### Archon Service Management

```bash
# Check nginx status
ssh root@192.168.0.245 'pct exec 183 -- systemctl status nginx'

# Restart nginx
ssh root@192.168.0.245 'pct exec 183 -- systemctl restart nginx'

# Restart Archon services
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart"'
```

---

## 🔧 Troubleshooting

### Common Issues

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| SSH timeout | Connection refused | Check Tailscale/WireGuard status |
| NFS mount stale | `ls` hangs | `umount -f /mnt/pve/<storage> && mount -a` |
| Docker permission | Permission denied | Add user to docker group: `usermod -aG docker $USER` |
| WireGuard no handshake | `wg show` timestamp=0 | Restart: `wg-quick down wg0 && wg-quick up wg0` |
| Archon MCP 400 error | Session ID invalid | Restart archon-mcp container |

### Diagnostic Commands

```bash
# Check WireGuard status
wg show
ip route | grep wg

# Test connectivity
ping 10.6.0.5   # WireGuard hub
ping 8.8.8.8    # Internet

# Check NFS mounts
df -h | grep wg
showmount -e 10.6.0.5  # FGSRV6 exports

# Check Docker
docker ps
docker logs <container>
systemctl status docker

# Check network interfaces
ip addr show
ip route show
```

### Quick Reset Commands

```bash
# Restart WireGuard
sudo wg-quick down wg0 && sudo wg-quick up wg0

# Restart Tailscale
sudo systemctl restart tailscaled

# Restart Docker service
sudo systemctl restart docker

# Remount NFS
sudo umount -f /mnt/pve/fgsrv6-wg && sudo mount -a
```

---

## 📚 Document Navigation

### When to Read Which Document

| Task | Document | Why |
|------|----------|-----|
| Infrastructure queries | **docs/INFRA.md** | Complete host/container map, IPs, networks |
| Archon integration | **docs/ARCHON.md** | MCP tools, API reference, development guidelines |
| Workflow methodologies | **docs/WORKFLOWS.md** | SPARC, Agent OS, development processes |
| Coding standards | **docs/RULES.md** | Execution patterns, best practices, quality standards |
| Quick commands | **docs/QUICK-START.md** | This file - fast reference |
| Main config | **CLAUDE.md** | Core rules, project overview, navigation hub |

### Loading Documents On-Demand

```bash
# Use @docs/ syntax to load only when needed
@docs/INFRA.md     # Infrastructure details
@docs/ARCHON.md    # Archon integration
@docs/WORKFLOWS.md # Development workflows
@docs/RULES.md     # Coding standards
```

### Cross-Reference Pattern

Always consult these documents together for infrastructure tasks:
1. **QUICK-START.md** → Find the quick command
2. **INFRA.md** → Verify IPs, network topology, container details
3. **ARCHON.md** → Use MCP tools for task management
4. **RULES.md** → Follow execution patterns and standards

---

## 📞 Quick Reference Cards

### SSH Aliases Quick Card

```bash
# Core hosts (from any environment via Tailscale)
AGLSRV1_HOST="100.107.113.33"  # Main Proxmox host
AGLSRV6_HOST="100.98.108.66"   # Secondary Proxmox host
CT179_DEV="100.94.221.87"      # Primary development
CT108_DEV="100.71.229.12"      # AGLSRV6 development

# WireGuard mesh (from CT179 only)
AGLSRV6_WG="10.6.0.12"   # AGLSRV6 host (fastest)
FGSRV6_WG="10.6.0.5"     # FGSRV6 hub
CT111_WG="10.6.0.20"     # CT111 storage
CT183_WG="10.6.0.21"     # Archon

# Local LAN (from CT179 only)
AGLSRV1_LAN="192.168.0.245"  # AGLSRV1 host
CT183_LAN="192.168.0.183"    # Archon
CT202_LAN="192.168.0.202"    # n8n
```

### Environment Quick Card

```bash
# Current environment
CURRENT_ENV=$(if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then echo "WSL2"; elif [[ -f /.dockerenv ]]; then echo "Container"; else echo "Unknown"; fi)

# Network availability check
check_network() {
    ping -c 1 192.168.0.1 &>/dev/null && echo "LAN: ✅" || echo "LAN: ❌"
    ping -c 1 10.6.0.5 &>/dev/null && echo "WireGuard: ✅" || echo "WireGuard: ❌"
    ping -c 1 100.98.108.66 &>/dev/null && echo "Tailscale: ✅" || echo "Tailscale: ❌"
}
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (AGL Infrastructure Management)
