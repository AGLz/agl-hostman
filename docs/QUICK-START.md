# Quick Start Guide - AGL Infrastructure

> **Last Updated**: 2025-10-27
> **For full details**: See `CLAUDE.md`, `docs/INFRA.md`, `docs/ARCHON.md`

---

## 🚀 Instant Connection

### From WSL2 (AGLHQ11)
```bash
# Primary development
ssh root@100.94.221.87  # CT179 (agldv03)

# Proxmox hosts
ssh root@100.107.113.33  # AGLSRV1
ssh root@100.98.108.66   # AGLSRV6
```

### From CT179 (Full Stack)
```bash
# WireGuard (fastest)
ssh root@10.6.0.12       # AGLSRV6 host
ssh root@10.6.0.5        # FGSRV6 hub

# Local LAN
ssh root@192.168.0.245   # AGLSRV1 host
ssh root@192.168.0.183   # CT183 (Archon)
```

---

## 🎯 Common Tasks

### Check Infrastructure
```bash
# From anywhere
ssh root@192.168.0.245 'pct list'  # List containers

# Storage
ls /mnt/pve/fgsrv6-wg    # NFS storage (from CT179)
df -h | grep wg          # All WireGuard mounts
```

### Archon MCP
```bash
# Access (Public DNS via HTTPS)
UI:  https://archon.aglz.io

# Direct access (LAN)
UI:  http://192.168.0.183:3737
API: http://192.168.0.183:8181
MCP: http://192.168.0.183:8051/mcp

# Manage
ssh root@192.168.0.245 'pct exec 183 -- docker ps'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
```

### Docker Commands
```bash
# Use Docker Compose V2 standalone
/usr/local/bin/docker-compose ps       # Check status
/usr/local/bin/docker-compose restart  # Restart services

# Or direct docker command
docker ps
docker logs <container>
```

---

## 📚 Read Next

- **CLAUDE.md** - Full Claude Code configuration
- **docs/INFRA.md** - Complete infrastructure map
- **docs/ARCHON.md** - Archon integration guide
