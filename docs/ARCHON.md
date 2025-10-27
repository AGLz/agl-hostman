# Archon AI Command Center - Integration Guide

> **Last Updated**: 2025-10-27 | **Version**: 1.0.0
> **Reference**: Always read this document for Archon-related queries
> **Repository**: https://github.com/coleam00/Archon

---

## 📑 Table of Contents

1. [Overview](#-overview)
2. [CT183 Infrastructure](#-ct183-infrastructure)
3. [Access Methods](#-access-methods)
4. [MCP Integration](#-mcp-integration)
5. [Development Guidelines](#-development-guidelines)
6. [Quick Commands](#-quick-commands)
7. [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

Archon is an AI Command Center deployed as an MCP (Model Context Protocol) server, providing centralized knowledge base access for Claude Code, Cursor, and Windsurf AI assistants.

### Key Features

- **Knowledge Base** with semantic search (RAG)
- **Code Examples** repository with indexing
- **Project & Task** management
- **Document** processing and embedding
- **MCP Protocol** for AI assistant integration
- **PGVector** semantic search capabilities
- **FastAPI** backend with Socket.IO
- **React** frontend with Vite

### Technology Stack

**Backend**:
- Python 3.12
- FastAPI (REST API + WebSocket)
- Socket.IO (real-time communication)
- Supabase (PostgreSQL + PGVector)
- Crawl4AI (web crawling)
- OpenAI embeddings
- Sentence Transformers (local embeddings)

**Frontend**:
- React 18
- Vite 5
- TypeScript
- Modern UI components

**Infrastructure**:
- Docker + Docker Compose V2
- LXC Container (privileged)
- Ubuntu 24.04 (Noble)

---

## 📦 CT183 Infrastructure

### Container Details

| Property | Value |
|----------|-------|
| **VMID** | 183 |
| **Hostname** | archon |
| **Host** | AGLSRV1 (algsrv1) |
| **Type** | LXC (Privileged) |
| **OS** | Ubuntu 24.04 (Noble) |
| **Resources** | 8 cores, 16GB RAM, 8GB swap |
| **Storage** | 100GB (local-zfs) |
| **Features** | keyctl=1, nesting=1, fuse=1 |

### Network Configuration

| Interface | Network | IP Address | Gateway |
|-----------|---------|------------|---------|
| eth0 | vmbr0 (LAN Primary) | 192.168.0.183/24 | 192.168.0.1 |
| eth1 | vmbr1 (LAN Secondary) | 192.168.1.183/24 | - |

**DNS**: 192.168.0.102 (pihole on CT102)

### Services Running

| Service | Container Name | Port | Purpose | Health |
|---------|---------------|------|---------|--------|
| **archon-server** | archon-server | 8181 | FastAPI Backend + Socket.IO | ✅ Healthy |
| **archon-mcp** | archon-mcp | 8051 | MCP Server (SSE protocol) | ✅ Running |
| **archon-frontend** | archon-frontend | 3737 | React Frontend (Vite) | ✅ Running |

### Docker Images

All services use pre-built images from Docker Hub (renatabk):
- `renatabk/archon-server:latest` (3.06GB)
- `renatabk/archon-mcp:latest` (252MB)
- `renatabk/archon-frontend:latest` (1.04GB)

### Configuration Files

**Location**: `/root/Archon` on CT183

**Environment** (`.env`):
```env
SUPABASE_URL=https://lqvprratqspfblzeqoqq.supabase.co
SUPABASE_SERVICE_KEY=<service_role_key>
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_UI_PORT=3737
LOG_LEVEL=INFO
VITE_ALLOWED_HOSTS=archon.aglz.io
```

**Docker Compose** (`docker-compose.yml`):
- Network: `app-network` (bridge)
- Security: `apparmor=unconfined` (required for LXC)
- Health checks: Enabled for all services
- Service discovery: `docker_compose` mode

### Database

**Supabase Project**: `lqvprratqspfblzeqoqq`
- **URL**: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq
- **Schema**: Initialized with `migration/complete_setup.sql`
- **Extensions**: vector (pgvector), pgcrypto, pg_trgm
- **Tables**:
  - `archon_settings` - System configuration
  - `sources` - Knowledge sources
  - `documents` - Document storage with embeddings
  - `projects` - Project management
  - `tasks` - Task tracking
  - `code_examples` - Code snippet repository
  - `versions` - Version history

---

## 🌐 Access Methods

### Local Network (LAN)

**From AGLSRV1 containers or local network** (direct access):
```
UI:  http://192.168.0.183:3737
API: http://192.168.0.183:8181
MCP: http://192.168.0.183:8051/mcp
Docs: http://192.168.0.183:8181/docs (FastAPI Swagger)
```

**Public DNS** (via reverse proxy):
```
UI:  https://archon.aglz.io
```

### DNS Access (via Reverse Proxy)

**Public DNS** (configured):
```
UI:  https://archon.aglz.io
API: https://archon.aglz.io/api
MCP: https://archon.aglz.io/mcp
```

**Note**: DNS archon.aglz.io is configured with HTTPS reverse proxy. Internal services on CT183 (192.168.0.183) are proxied:
- HTTPS → UI (port 3737)
- /api → Backend (port 8181)
- /mcp → MCP Server (port 8051)

### Tailscale Network

**Status**: Not configured yet
**Planned IP**: TBD

After Tailscale configuration:
```
UI:  http://TAILSCALE_IP:3737
API: http://TAILSCALE_IP:8181
MCP: http://TAILSCALE_IP:8051/mcp
```

---

## 🔌 MCP Integration

### Connection Methods

#### Option 1: Local Network Access (from CT179 or AGLSRV1)

Best for containers/hosts on local network:
```bash
claude mcp add archon-knowledge sse http://192.168.0.183:8051/mcp
```

#### Option 2: DNS Access

If DNS is accessible:
```bash
claude mcp add archon-knowledge sse http://archon.aglz.io:8051/mcp
```

#### Option 3: SSH Tunnel (from WSL2/remote)

Create manual SSH tunnel:
```bash
# Terminal 1: Create tunnel
ssh -L 18051:192.168.0.183:8051 root@192.168.0.245 -N

# Terminal 2: Add MCP
claude mcp add archon-knowledge sse http://localhost:18051/mcp
```

#### Option 4: Tailscale (future)

After configuring Tailscale on CT183:
```bash
claude mcp add archon-knowledge sse http://TAILSCALE_IP:8051/mcp
```

### Available MCP Tools

When connected to Archon MCP, the following tools become available in Claude Code:

#### Knowledge Base Tools

**Search and Discovery**:
- `archon:rag_search_knowledge_base` - Semantic search across all documents
  - Parameters: query, source_filter, limit
  - Returns: Relevant documents with similarity scores

- `archon:rag_search_code_examples` - Find code snippets
  - Parameters: query, language, limit
  - Returns: Code examples with metadata

- `archon:rag_get_available_sources` - List all knowledge sources
  - Returns: Sources with document counts

- `archon:rag_list_pages_for_source` - Browse documentation structure
  - Parameters: source_id
  - Returns: Hierarchical page list

- `archon:rag_read_full_page` - Retrieve complete page content
  - Parameters: page_id
  - Returns: Full content with metadata

#### Project Management Tools

**Project Operations**:
- `archon:find_projects` - Search/list/get projects
  - Modes: search, list, get
  - Filters: status, tags, date ranges
  - Returns: Project details with tasks

- `archon:manage_project` - Create/update/delete projects
  - Actions: create, update, delete
  - Fields: name, description, status, tags, metadata
  - Returns: Project object

#### Task Management Tools

**Task Operations**:
- `archon:find_tasks` - Search/list/get tasks with filters
  - Modes: search, list, get
  - Filters: project_id, status, priority, assignee
  - Returns: Task list with details

- `archon:manage_task` - Create/update/delete tasks
  - Actions: create, update, delete
  - Fields: title, description, status, priority, project_id
  - Returns: Task object

#### Document Management Tools

**Document Operations**:
- `archon:find_documents` - Search/list/get documents
  - Modes: search, list, get
  - Filters: source, type, date ranges
  - Returns: Document metadata

- `archon:manage_document` - Create/update/delete documents
  - Actions: create, update, delete
  - Fields: title, content, source, type, metadata
  - Auto-generates embeddings for RAG

#### Version Control Tools

**Version Operations**:
- `archon:find_versions` - Version history tracking
  - Parameters: document_id, limit
  - Returns: Version timeline

- `archon:manage_version` - Create versions and restore
  - Actions: create, restore
  - Automatic versioning on document updates
  - Returns: Version object

### MCP Usage Examples

**Knowledge Base Search**:
```typescript
// Search for Docker-related documentation
archon:rag_search_knowledge_base({
  query: "Docker container networking best practices",
  source_filter: "documentation",
  limit: 5
})
```

**Code Example Lookup**:
```typescript
// Find React component examples
archon:rag_search_code_examples({
  query: "authentication component",
  language: "typescript",
  limit: 3
})
```

**Project Management**:
```typescript
// Create new project
archon:manage_project({
  action: "create",
  name: "Infrastructure Automation",
  description: "Automate deployment workflows",
  status: "active",
  tags: ["devops", "automation"]
})

// List all active projects
archon:find_projects({
  mode: "list",
  status: "active"
})
```

**Task Tracking**:
```typescript
// Create task
archon:manage_task({
  action: "create",
  title: "Configure WireGuard mesh",
  project_id: "proj_123",
  priority: "high",
  status: "todo"
})

// Find high-priority tasks
archon:find_tasks({
  mode: "list",
  priority: "high",
  status: "in_progress"
})
```

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
- Return success count + detailed failure list for batch operations

### Code Quality Standards

1. **Remove dead code immediately** (no backward compatibility baggage)
2. **Fix forward, not backward** (no legacy workarounds)
3. **Detailed error messages** with full context
4. **Specific exception types** (not generic Exception)
5. **Include relevant IDs, URLs, data** in errors
6. **Batch operations**: report success count + detailed failure list

### Example Error Handling

**Bad** ❌:
```python
try:
    process_document(doc)
except Exception as e:
    print(f"Error: {e}")
```

**Good** ✅:
```python
try:
    embeddings = generate_embeddings(doc.content)
    if not embeddings or len(embeddings) == 0:
        raise ValueError(
            f"Failed to generate embeddings for document {doc.id} "
            f"(source: {doc.source}, title: '{doc.title}'). "
            f"Content length: {len(doc.content)}"
        )
    doc.embeddings = embeddings
except OpenAIError as e:
    logger.error(
        f"OpenAI API failed for document {doc.id}: {e}. "
        f"Retrying in 5 seconds..."
    )
    raise
except ValidationError as e:
    logger.error(
        f"Document {doc.id} validation failed: {e}. "
        f"Skipping this document. Data: {doc.dict()}"
    )
    # Don't retry, skip corrupted data
    return None
```

### Archon Best Practices

1. **Validate early**: Check data integrity before processing
2. **Fail explicitly**: Specific exceptions for specific failures
3. **Log with context**: Include IDs, states, relevant data
4. **No silent failures**: Always log or raise
5. **Batch reporting**: Success count + individual failures
6. **Never partial success**: Atomic operations or rollback
7. **Clean up dead code**: Remove immediately, don't comment out
8. **Forward compatibility**: Fix issues going forward
9. **Type safety**: Use Pydantic models for validation
10. **Health checks**: Expose service health via /health endpoints

---

## 🚀 Quick Commands

### Service Management

```bash
# SSH to CT183
ssh root@192.168.0.245 'pct enter 183'

# Check status (from Proxmox host)
ssh root@192.168.0.245 'pct exec 183 -- docker compose ps'

# View logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-frontend'

# Follow logs (real-time)
ssh root@192.168.0.245 'pct exec 183 -- docker logs -f archon-server'

# Restart services (use Docker Compose V2)
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart"'

# Restart specific service
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart archon-server"'

# Stop all services
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose down"'

# Start all services
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose up -d"'

# Rebuild and restart (if needed)
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose up -d --force-recreate"'
```

### Health Checks

```bash
# API Health
curl http://192.168.0.183:8181/health

# API Documentation
curl http://192.168.0.183:8181/docs

# UI Access (check HTTP status)
curl -I http://192.168.0.183:3737

# MCP Endpoint (check connectivity)
curl http://192.168.0.183:8051/mcp

# Check all services
ssh root@192.168.0.245 'pct exec 183 -- docker compose ps --all'

# Check Docker network
ssh root@192.168.0.245 'pct exec 183 -- docker network inspect archon_app-network'
```

### Database Operations

```bash
# Access Supabase SQL Editor
# URL: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq/editor

# Check table counts (via API)
curl http://192.168.0.183:8181/api/stats

# Backup database (SQL dump)
# Use Supabase dashboard: Database -> Backups
```

### Container Management

```bash
# Enter container console
ssh root@192.168.0.245 'pct enter 183'

# Start container
ssh root@192.168.0.245 'pct start 183'

# Stop container
ssh root@192.168.0.245 'pct stop 183'

# Restart container
ssh root@192.168.0.245 'pct reboot 183'

# Container resource usage
ssh root@192.168.0.245 'pct status 183'

# Container config
ssh root@192.168.0.245 'pct config 183'
```

### Docker Compose V2 Commands

**ALWAYS use Docker Compose V2** (with space, not hyphen):

```bash
# Correct ✅
docker compose ps
docker compose up -d
docker compose restart
docker compose logs -f archon-server

# Wrong ❌ (Python 3.12 distutils issue)
docker-compose ps      # Will fail with ModuleNotFoundError
```

---

## 🔧 Troubleshooting

### Issue: MCP Connection Failed

**Symptoms**: `claude mcp list` shows archon-knowledge as "Failed to connect"

**Causes**:
1. Wrong network (using LAN from WSL2)
2. Container not running
3. Port not accessible
4. Firewall blocking connection

**Solutions**:
1. **From WSL2**: Use SSH tunnel (Option 3 above)
2. **From CT179**: Use direct LAN (Option 1 above)
3. **Check containers**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- docker compose ps'
   ```
4. **Test endpoint**:
   ```bash
   curl http://192.168.0.183:8051/mcp
   ```
5. **Check logs**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
   ```

---

### Issue: Docker Containers Unhealthy

**Symptoms**: Health check failures, containers restarting

**Diagnosis**:
```bash
# Check container health
ssh root@192.168.0.245 'pct exec 183 -- docker compose ps'

# Check logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
```

**Solutions**:
1. **Verify .env file** has correct Supabase credentials
2. **Check database schema** is initialized
3. **Restart containers**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart"'
   ```
4. **Force recreate**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose up -d --force-recreate"'
   ```

---

### Issue: Database Connection Errors

**Symptoms**: "Could not find table" errors in logs

**Solutions**:
1. **Verify Supabase project** is active:
   - Visit: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq

2. **Re-run SQL setup**:
   - Open SQL Editor in Supabase
   - Execute: `/root/Archon/migration/complete_setup.sql`

3. **Check SUPABASE_SERVICE_KEY** (not anon key!)
   - File: `/root/Archon/.env`
   - Must be `service_role` key, not `anon` key

4. **Test connection**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server | grep -i "database\|supabase"'
   ```

---

### Issue: Vite Hostname Blocking

**Symptoms**: "Blocked request. This host ("archon.aglz.io") is not allowed"

**Cause**: Vite dev server blocks non-whitelisted hostnames by default

**Solution**:
1. **Add to .env**:
   ```env
   VITE_ALLOWED_HOSTS=archon.aglz.io
   ```

2. **Restart frontend**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart archon-frontend"'
   ```

3. **Verify**:
   ```bash
   curl -I http://archon.aglz.io:3737
   ```

---

### Issue: Docker Compose V1 vs V2

**Symptoms**: `ModuleNotFoundError: No module named 'distutils'`

**Cause**: `docker-compose` (V1) uses Python and is broken on Python 3.12

**Solution**: Always use `docker compose` (V2) with space:
```bash
# Wrong ❌
docker-compose ps

# Correct ✅
docker compose ps
```

---

### Issue: AppArmor Errors in LXC

**Symptoms**: `unable to apply apparmor profile`

**Cause**: Docker BuildKit requires AppArmor features not available in LXC

**Solutions**:
1. **Use pre-built images** (recommended - already implemented)
2. **Disable BuildKit** in `/etc/docker/daemon.json`:
   ```json
   {
     "features": {
       "buildkit": false
     }
   }
   ```
3. **Add to docker-compose.yml**:
   ```yaml
   services:
     service-name:
       security_opt:
         - apparmor=unconfined
   ```

See: `docs/docker-in-lxc-apparmor-solution.md` for detailed guide

---

## 📚 Related Documentation

- **Infrastructure**: `docs/INFRA.md` - Complete infrastructure map
- **Main Config**: `CLAUDE.md` - Claude Code configuration
- **Docker in LXC**: `docs/docker-in-lxc-apparmor-solution.md` - AppArmor solution
- **Archon GitHub**: https://github.com/coleam00/Archon
- **Supabase Dashboard**: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq

---

## 🔗 Quick Links

- **Archon UI**: http://192.168.0.183:3737 (LAN) | http://archon.aglz.io:3737 (DNS)
- **API Docs**: http://192.168.0.183:8181/docs (FastAPI Swagger)
- **MCP Endpoint**: http://192.168.0.183:8051/mcp
- **Supabase Dashboard**: https://supabase.com/dashboard/project/lqvprratqspfblzeqoqq

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-27
**Deployed By**: Claude Code (agl-hostman project)
**Always Read**: This document should ALWAYS be read for Archon-related queries
