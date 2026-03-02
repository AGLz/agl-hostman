# Archon Knowledge Base Integration

> **Date**: 2025-10-27
> **Container**: CT183 (archon) on AGLSRV1
> **Status**: Deployed and Running

---

## 🎯 Overview

Archon is an AI Command Center deployed as an MCP (Model Context Protocol) server providing centralized knowledge base access for Claude Code, Cursor, and Windsurf AI assistants.

**Key Features:**
- **Knowledge Base** with semantic search (RAG)
- **Code Examples** repository with indexing
- **Project & Task** management
- **Document** processing and embedding
- **MCP Protocol** for AI assistant integration

---

## 📋 CT183 (Archon) Infrastructure

### Container Details

| Property | Value |
|----------|-------|
| **VMID** | 183 |
| **Hostname** | archon |
| **Type** | LXC (Privileged) |
| **OS** | Ubuntu 24.04 (Noble) |
| **Resources** | 8 cores, 16GB RAM, 8GB swap |
| **Storage** | 100GB (local-zfs) |
| **Network** | 192.168.0.183 (eth0), 192.168.1.183 (eth1) |

### Services Running

| Service | Port | Purpose | Health |
|---------|------|---------|--------|
| **archon-server** | 8181 | FastAPI Backend + Socket.IO | ✅ Healthy |
| **archon-mcp** | 8051 | MCP Server (SSE protocol) | ✅ Running |
| **archon-ui** | 3737 | React Frontend (Vite) | ✅ Running |

### Access URLs

**From Local Network (LAN):**
```
UI:  http://192.168.0.183:3737
API: http://192.168.0.183:8181
MCP: http://192.168.0.183:8051/mcp
```

**From Tailscale Network:**
```
Status: ⏳ Pending Authentication
Auth URL: https://login.tailscale.com/a/140ac19a01f901

After authentication, access via:
UI:  http://<TAILSCALE_IP>:3737
API: http://<TAILSCALE_IP>:8181
MCP: http://<TAILSCALE_IP>:8051/mcp
```

**Public DNS (via HTTPS):**
```
Status: ❌ 502 Bad Gateway (requires Cloudflare Tunnel or reverse proxy)
See: docs/cloudflare-archon-config.md for configuration options

Intended URL: https://archon.aglz.io
```

---

## 🔌 MCP Integration with Claude Code

### Connection Methods

#### Option 1: Local Network Access (LAN)
Best for CT179 or AGLSRV1 host:
```bash
claude mcp add archon-knowledge sse http://192.168.0.183:8051/mcp
```

#### Option 2: SSH Tunnel (from WSL2/remote)
Create manual SSH tunnel:
```bash
# Terminal 1: Create tunnel
ssh -L 18051:192.168.0.183:8051 root@100.94.221.87 -N

# Terminal 2: Add MCP
claude mcp add archon-knowledge sse http://localhost:18051/mcp
```

#### Option 3: Tailscale (future)
After configuring Tailscale on CT183:
```bash
claude mcp add archon-knowledge sse http://TAILSCALE_IP:8051/mcp
```

### Available MCP Tools

When connected, the following tools become available in Claude Code:

**Knowledge Base:**
- `archon:rag_search_knowledge_base` - Semantic search across all documents
- `archon:rag_search_code_examples` - Find code snippets
- `archon:rag_get_available_sources` - List knowledge sources
- `archon:rag_list_pages_for_source` - Browse documentation structure
- `archon:rag_read_full_page` - Retrieve complete page content

**Project Management:**
- `archon:find_projects` - Search/list/get projects
- `archon:manage_project` - Create/update/delete projects

**Task Management:**
- `archon:find_tasks` - Search/list/get tasks with filters
- `archon:manage_task` - Create/update/delete tasks

**Document Management:**
- `archon:find_documents` - Search/list/get documents
- `archon:manage_document` - Create/update/delete documents

**Version Control:**
- `archon:find_versions` - Version history tracking
- `archon:manage_version` - Create versions and restore

---

## 🛠️ Deployment Details

### Docker Images Used

All services use pre-built images from Docker Hub (renatabk):
- `renatabk/archon-server:latest` (3.06GB)
- `renatabk/archon-mcp:latest` (252MB)
- `renatabk/archon-frontend:latest` (1.04GB)

### Configuration Files

**Environment** (`/root/Archon/.env`):
```bash
SUPABASE_URL=https://lqvprratqspfblzeqoqq.supabase.co
SUPABASE_SERVICE_KEY=<service_role_key>
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_UI_PORT=3737
LOG_LEVEL=INFO
```

**Docker Compose** (`/root/Archon/docker-compose.yml`):
- Network: `archon_app-network` (bridge)
- Security: `apparmor=unconfined` (required for LXC)
- Health checks: Enabled for all services

### Database

**Supabase Project**: `lqvprratqspfblzeqoqq`
- **Schema**: Initialized with `migration/complete_setup.sql`
- **Extensions**: vector (pgvector), pgcrypto, pg_trgm
- **Tables**: archon_settings, sources, documents, projects, tasks, code_examples

---

## 📝 Development Guidelines (Archon-Inspired)

### Error Handling Philosophy

**Fail Fast and Loud** for critical issues:
- Service startup failures
- Missing configuration
- Database connection failures
- Authentication/authorization failures
- Data corruption or validation errors

**Complete but Log** for batch operations:
- Document processing
- Embedding generation
- Background tasks
- External API calls (with retry)

**Never Accept Corrupted Data**:
- Skip failed items entirely
- Never store zero embeddings, null foreign keys, or malformed JSON
- Log detailed failures with context

### Code Quality Standards

- Remove dead code immediately (no backward compatibility)
- Fix forward, not backward
- Detailed error messages with full context
- Specific exception types (not generic Exception)
- Include relevant IDs, URLs, data in errors
- For batch operations: report success count + detailed failure list

---

## 🚀 Quick Commands

### Service Management

```bash
# Check status
ssh root@192.168.0.245 'pct exec 183 -- docker ps --filter "name=archon"'

# View logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-ui'

# Restart services
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && /usr/local/bin/docker-compose restart"'

# Stop/Start
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && /usr/local/bin/docker-compose down"'
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && /usr/local/bin/docker-compose up -d"'
```

### Health Checks

```bash
# API Health
curl http://192.168.0.183:8181/health

# UI Access
curl -I http://192.168.0.183:3737

# MCP Status (via logs)
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp 2>&1 | tail -20'
```

---

## 🔧 Troubleshooting

### Issue: MCP Connection Failed

**Symptoms**: `claude mcp list` shows archon-knowledge as "Failed to connect"

**Causes**:
1. Wrong network (using LAN from WSL2)
2. Container not running
3. Port not accessible

**Solutions**:
1. Use SSH tunnel from WSL2 (see Option 2 above)
2. Check containers: `docker ps --filter "name=archon"`
3. Test endpoint: `curl http://192.168.0.183:8051/mcp`

### Issue: Docker Containers Unhealthy

**Symptoms**: Health check failures, containers restarting

**Solutions**:
1. Check logs: `docker logs archon-server`
2. Verify .env file has correct Supabase credentials
3. Ensure database schema is initialized
4. Restart containers: `docker-compose restart`

### Issue: Database Connection Errors

**Symptoms**: "Could not find table" errors in logs

**Solutions**:
1. Verify Supabase project is active
2. Re-run `migration/complete_setup.sql` in Supabase SQL Editor
3. Check SUPABASE_SERVICE_KEY (not anon key!)

---

## 📚 Related Documentation

- **Deployment Guide**: `docs/ct183-deployment-guide.md` (to be created)
- **AppArmor Solution**: `docs/docker-in-lxc-apparmor-solution.md`
- **Archon Repository**: https://github.com/coleam00/Archon
- **Infrastructure Map**: `CLAUDE.md` (main infrastructure documentation)

---

## 🔗 Quick Links

- **Archon UI**: http://192.168.0.183:3737
- **API Docs**: http://192.168.0.183:8181/docs (FastAPI Swagger)
- **Supabase Dashboard**: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Deployed By**: Claude Code (agl-hostman project)
