# CT183 (Archon) Deployment Guide

## 📋 Deployment Summary

**Date**: 2025-10-27
**Container**: CT183 (archon)
**Host**: AGLSRV1 (192.168.0.245)
**Purpose**: Archon - AI Command Center & MCP Server
**Status**: ✅ Container Created, ⏳ Awaiting Supabase Configuration

---

## 🎯 Container Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **VMID** | 183 | Unique container ID |
| **Hostname** | archon | Container hostname |
| **OS** | Ubuntu 24.04 LTS | Latest LTS release |
| **CPU** | 8 cores | Dedicated allocation |
| **RAM** | 16GB | Sufficient for Archon services |
| **Disk** | 100GB (local-zfs) | SSD storage |
| **Features** | keyctl=1, nesting=1, fuse=1 | Docker support enabled |

---

## 🌐 Network Configuration

### IP Addresses

| Interface | IP Address | Network | Purpose |
|-----------|-----------|---------|---------|
| **eth0** | 192.168.0.183/24 | LAN (primary) | Main access point |
| **eth1** | 192.168.1.183/24 | LAN (secondary) | Backup network |
| **wg0** | 10.6.0.23/24 (planned) | WireGuard mesh | Remote MCP access |
| **tailscale0** | TBD | Tailscale VPN | Cross-site access |

### Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Archon UI** | http://192.168.0.183:3737 | Web interface |
| **API Server** | http://192.168.0.183:8181 | REST API |
| **MCP Server** | http://192.168.0.183:8051 | AI assistants (Claude Code, Cursor, etc.) |
| **Agents Service** | http://192.168.0.183:8052 | ML agents (optional) |
| **Documentation** | http://192.168.0.183:3838 | Archon docs |

---

## 🐳 Docker Services

### Installed Components

- **Docker Engine**: v28.2.2
- **Docker Compose**: v1.29.2
- **Containerd**: v1.7.28

### Service Status

```bash
# Check Docker status
ssh root@192.168.0.183 'docker --version'
ssh root@192.168.0.183 'docker ps'

# View logs
ssh root@192.168.0.183 'cd /root/Archon && docker compose logs -f'
```

---

## 📦 Archon Installation

### Repository Details

- **Source**: https://github.com/coleam00/Archon
- **Location**: `/root/Archon`
- **Branch**: stable (default)

### Technology Stack

- **Frontend**: React 18, TypeScript, TailwindCSS, Vite 5
- **Backend**: FastAPI, Python 3.12, PydanticAI
- **Database**: PostgreSQL 15+ with PGVector (via Supabase)
- **AI/LLM**: OpenAI, Google Gemini, Ollama support
- **Protocol**: MCP (Model Context Protocol)

---

## ⚙️ Configuration

### Environment Variables (`.env`)

```bash
# Location
/root/Archon/.env

# Key Variables
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_SERVICE_KEY=YOUR_SERVICE_ROLE_KEY_HERE
HOST=0.0.0.0
ARCHON_UI_PORT=3737
ARCHON_MCP_PORT=8051
```

### Port Mapping

| Internal Port | External Port | Service | Access |
|--------------|--------------|---------|--------|
| 3737 | 3737 | React UI | LAN, WireGuard |
| 8181 | 8181 | FastAPI Server | LAN, WireGuard |
| 8051 | 8051 | MCP Server | LAN, WireGuard, Tailscale |
| 8052 | 8052 | Agents Service | Internal only |
| 3838 | 3838 | Documentation | LAN only |

---

## 🔐 Security Configuration

### Firewall Rules (Planned)

```bash
# UFW rules to be implemented
ufw allow from 192.168.0.0/24 to any port 3737 proto tcp  # UI
ufw allow from 192.168.0.0/24 to any port 8051 proto tcp  # MCP
ufw allow from 10.6.0.0/24 to any port 8051 proto tcp     # WireGuard MCP
ufw limit 22/tcp  # SSH rate limiting
```

### Access Control Matrix

| Service | LAN | WireGuard | Tailscale | Internet |
|---------|-----|-----------|-----------|----------|
| **SSH** | ✅ | ✅ (planned) | ✅ (planned) | ❌ |
| **UI (3737)** | ✅ | ✅ (planned) | ⚠️ Optional | ❌ |
| **MCP (8051)** | ✅ | ✅ (planned) | ✅ (planned) | ❌ |
| **API (8181)** | ✅ | ✅ (planned) | ⚠️ Optional | ❌ |

---

## 🚀 Deployment Steps

### Prerequisites

#### 1. Create Supabase Account

1. Go to https://supabase.com
2. Sign up (free tier is sufficient)
3. Create new project:
   - Project name: `archon-aglsrv1` (or your choice)
   - Database password: Choose strong password
   - Region: Select closest to your location

#### 2. Get Supabase Credentials

**Critical: Use SERVICE ROLE KEY, not Anon Key!**

1. Go to project dashboard
2. Navigate to Settings → API (https://supabase.com/dashboard/project/YOUR_PROJECT_ID/settings/api)
3. Copy **Project URL** (e.g., `https://abcdefgh.supabase.co`)
4. Copy **service_role** key (NOT anon key!)
   - ✅ **Correct**: Long key, contains "service_role" in JWT, starts with `eyJ...`
   - ❌ **Wrong**: Shorter "anon" key will cause "permission denied" errors

#### 3. Configure Database Schema

1. In Supabase dashboard, go to SQL Editor
2. Run the setup script:
   ```sql
   -- See /root/Archon/migration/credentials_setup.sql for schema
   ```

### Deployment Commands

```bash
# 1. Connect to CT183
ssh root@192.168.0.183

# 2. Edit environment file
cd /root/Archon
nano .env
# Update SUPABASE_URL and SUPABASE_SERVICE_KEY with your credentials

# 3. Start Archon services
docker compose up -d

# 4. Check service status
docker compose ps

# 5. View logs
docker compose logs -f archon-server
docker compose logs -f archon-ui

# 6. Stop services (if needed)
docker compose down
```

### Verification

```bash
# Test endpoints
curl http://192.168.0.183:8181/api/health
curl http://192.168.0.183:8051/health

# Access UI in browser
# http://192.168.0.183:3737
```

---

## 🧩 Integration with AI Assistants

### Claude Code Configuration

Add to your Claude Code MCP settings (`.mcp/settings.json`):

```json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://192.168.0.183:8051/sse",
      "description": "Archon knowledge base and task management"
    }
  }
}
```

### Cursor Configuration

Settings → Features → MCP Servers:

```json
{
  "archon": {
    "transport": "sse",
    "url": "http://192.168.0.183:8051/sse"
  }
}
```

### Windsurf Configuration

Similar to Cursor, add to MCP settings.

---

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Container status
ssh root@192.168.0.245 'pct status 183'

# Docker services
ssh root@192.168.0.183 'docker ps'

# Resource usage
ssh root@192.168.0.183 'htop'
ssh root@192.168.0.183 'docker stats'

# Logs
ssh root@192.168.0.183 'docker compose -f /root/Archon/docker-compose.yml logs --tail=100'
```

### Backup Strategy

```bash
# Backup Archon configuration
ssh root@192.168.0.183 'tar -czf /root/archon-backup-$(date +%Y%m%d).tar.gz /root/Archon/.env /root/Archon/docker-compose.yml'

# Backup container (from AGLSRV1 host)
ssh root@192.168.0.245 'vzdump 183 --storage aglsrv6-pbs --mode snapshot --compress zstd'
```

### Updates

```bash
# Update Archon code
ssh root@192.168.0.183 'cd /root/Archon && git pull && docker compose down && docker compose up -d --build'

# Update Docker images
ssh root@192.168.0.183 'docker compose pull && docker compose up -d'
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "Permission denied" when saving documents

**Cause**: Using anon key instead of service_role key

**Solution**:
```bash
cd /root/Archon
nano .env
# Replace SUPABASE_SERVICE_KEY with the correct service_role key
docker compose restart
```

#### 2. Cannot connect to Supabase

**Symptoms**: Connection timeouts, database errors

**Solutions**:
```bash
# Check DNS resolution
ping supabase.co

# Check network connectivity
curl -I https://YOUR_PROJECT_ID.supabase.co

# Verify firewall rules
ufw status
```

#### 3. Docker service won't start

```bash
# Check Docker status
systemctl status docker

# Restart Docker
systemctl restart docker

# Check logs
journalctl -u docker -n 50
```

#### 4. High memory usage

```bash
# Check container memory
docker stats --no-stream

# Restart services to clear caches
cd /root/Archon && docker compose restart

# Increase container RAM if needed (on AGLSRV1 host)
ssh root@192.168.0.245 'pct set 183 --memory 32768'  # Increase to 32GB
```

### Log Locations

```bash
# Container logs
/var/log/pct/183.log  # On AGLSRV1 host

# Docker logs
docker compose -f /root/Archon/docker-compose.yml logs

# Application logs
# Check Archon UI Settings page for log viewer
```

---

## 📚 Additional Resources

### Documentation

- **Archon GitHub**: https://github.com/coleam00/Archon
- **Archon Research**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/archon-research/`
  - `README.md` - Quick reference
  - `archon-comprehensive-analysis.md` - Full technical deep-dive
  - `ct183-deployment-guide.md` - This file

### Support & Community

- **GitHub Issues**: https://github.com/coleam00/Archon/issues
- **Supabase Docs**: https://supabase.com/docs
- **Docker Docs**: https://docs.docker.com

---

## 📝 Next Steps

1. ✅ Container created and running
2. ✅ Docker installed and configured
3. ✅ Archon repository cloned
4. ⏳ **TODO**: Create Supabase account and configure credentials
5. ⏳ **TODO**: Deploy Archon services (`docker compose up -d`)
6. ⏳ **TODO**: Configure WireGuard mesh (10.6.0.23)
7. ⏳ **TODO**: Configure Tailscale for cross-site access
8. ⏳ **TODO**: Integrate with Claude Code MCP
9. ⏳ **TODO**: Populate knowledge base with organizational docs
10. ⏳ **TODO**: Update `CLAUDE.md` with CT183 infrastructure details

---

## 🎯 Success Criteria

- [ ] CT183 running and accessible via LAN
- [ ] Docker services healthy
- [ ] Archon UI accessible at http://192.168.0.183:3737
- [ ] MCP server responding at port 8051
- [ ] Claude Code successfully connecting to Archon MCP
- [ ] Documents successfully uploading to knowledge base
- [ ] Search functionality working
- [ ] WireGuard mesh configured (remote access)
- [ ] Backups automated via PBS

---

**Deployment Date**: 2025-10-27
**Deployed By**: Claude Code
**Next Review**: After Supabase configuration
