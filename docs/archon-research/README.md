# Archon Research & Deployment Documentation

> **Research Date**: 2025-10-27
> **Target Deployment**: CT183 on AGLSRV1
> **Status**: Research Complete, Ready for Deployment

---

## 📑 Document Index

### 1. [Comprehensive Analysis](./archon-comprehensive-analysis.md)
**Full technical deep-dive** including:
- Project overview and problem statement
- Complete architecture breakdown (4 microservices)
- Technology stack (Python 3.12, FastAPI, React, PostgreSQL+PGVector)
- Hardware/software requirements
- Installation procedures (Docker Compose, Kubernetes, LXC)
- Configuration options (environment variables, MCP, API)
- Integration points (MCP protocol, REST API, WebSocket, LLM providers)
- Use cases and capabilities
- CT183 container design recommendations

**Audience**: Technical leads, architects, developers
**Length**: ~12,000 words (comprehensive reference)

### 2. [CT183 Deployment Guide](./ct183-deployment-guide.md)
**Quick-start guide** for deploying Archon on CT183:
- Prerequisites checklist
- Step-by-step deployment commands
- Base system setup
- Docker Compose deployment
- Database configuration
- WireGuard integration (optional)
- AI client configuration examples
- Verification procedures
- Maintenance scripts
- Troubleshooting guide

**Audience**: System administrators, DevOps
**Length**: ~2,500 words (actionable quick reference)

---

## 🎯 Executive Summary

### What is Archon?

**Archon** is an open-source **AI command center** that functions as a **Model Context Protocol (MCP) server**, enabling AI coding assistants (Claude Code, Cursor, Windsurf, etc.) to:
- Access shared organizational knowledge bases
- Perform semantic search across documentation
- Manage projects, features, and tasks collaboratively
- Maintain context across sessions and teams

### Why Deploy Archon?

**Problem Solved**:
- AI assistants work in isolation without shared knowledge
- Developers manually copy-paste documentation to AI chats
- No centralized task management for AI-assisted workflows
- Context lost between sessions

**Archon Benefits**:
- ✅ **Single source of truth** for AI assistants
- ✅ **Intelligent search** (vector embeddings + RAG)
- ✅ **Multi-AI support** (OpenAI, Gemini, Ollama)
- ✅ **Real-time collaboration** (WebSocket updates)
- ✅ **Self-hosted** (full data control)
- ✅ **MCP standard** (works with any MCP client)

### Key Features

| Feature | Description | Technology |
|---------|-------------|------------|
| **Knowledge Base** | Web crawling, PDF/DOCX processing, semantic search | Crawl4AI, PyPDF2, PGVector |
| **Task Management** | Hierarchical projects/features/tasks with AI generation | FastAPI, PostgreSQL |
| **Multi-LLM** | OpenAI, Google Gemini, Ollama (local models) | OpenAI SDK, PydanticAI |
| **Hybrid RAG** | Vector search + keyword matching + reranking | Sentence-transformers, PyTorch |
| **Real-time Sync** | Live updates across all clients | Socket.IO |
| **MCP Protocol** | Standard AI assistant integration | MCP 1.12.2 |

### Architecture (4 Microservices)

```
Frontend (React + Vite)  ←→  Server API (FastAPI)  ←→  Supabase DB
   Port 3737                    Port 8181              (PostgreSQL+PGVector)
                                    ↕
                          MCP Server (Port 8051)
                                    ↕
                        Agents Service (Port 8052)
                           (Optional ML/Reranking)
```

**Communication**: HTTP/REST + WebSocket (Socket.IO) + MCP Protocol (SSE)

---

## 📊 Technical Specifications

### System Requirements

#### CT183 Recommended Specs

| Component | Specification |
|-----------|--------------|
| **CPU** | 4 cores |
| **RAM** | 8 GB (16 GB with agents service) |
| **Storage** | 50 GB (local-zfs) |
| **OS** | Ubuntu 24.04 LTS |
| **Network** | 192.168.0.183 (LAN), 10.6.0.183 (WireGuard optional) |
| **Features** | `keyctl=1,nesting=1` (Docker in LXC) |

#### Software Dependencies

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker** | Latest | Container runtime |
| **Docker Compose** | v2.0+ | Multi-container orchestration |
| **Python** | 3.12+ | Backend runtime |
| **Node.js** | 18+ | Frontend build (optional for dev) |
| **PostgreSQL** | 15+ | Database (via Supabase) |

#### Third-Party Services

| Service | Tier | Purpose |
|---------|------|---------|
| **Supabase** | Free | PostgreSQL + PGVector + Auth |
| **OpenAI** | Pay-as-you-go | GPT-4/3.5 + Embeddings (optional) |
| **Google Gemini** | Free tier | Alternative LLM (optional) |
| **Ollama** | Free (self-hosted) | Local models (optional) |

### Network Ports

| Port | Service | Access Level | Protocol |
|------|---------|--------------|----------|
| **3737** | Frontend UI | Public (via reverse proxy) | HTTP |
| **8181** | Server API | Internal (Docker network) | HTTP |
| **8051** | MCP Server | AI Clients (LAN/VPN) | HTTP/SSE |
| **8052** | Agents Service | Internal (Docker network) | HTTP |

---

## 🚀 Deployment Overview

### Quick Deployment (5 Steps)

1. **Create CT183** on AGLSRV1 (4 cores, 8 GB RAM, 50 GB storage)
2. **Install Docker** and Docker Compose
3. **Clone Archon** from GitHub (`stable` branch)
4. **Configure `.env`** with Supabase credentials
5. **Deploy**: `docker compose up -d`

**Total Time**: ~30 minutes (excluding Supabase setup)

### Deployment Options

| Method | Use Case | Complexity |
|--------|----------|-----------|
| **Docker Compose** | Single host, production-ready | ⭐ Easy |
| **Kubernetes** | Multi-host, high availability | ⭐⭐⭐ Advanced |
| **LXC Container** | Proxmox infrastructure (AGL) | ⭐⭐ Moderate |

**Recommended for AGL**: LXC Container (CT183) with Docker Compose inside

### Integration Points

#### MCP Server (Primary Integration)

**AI Clients**:
- Claude Code
- Cursor
- Windsurf
- Any MCP-compatible client

**Configuration Example** (Claude Code):
```json
// ~/.config/claude/mcp_servers.json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://192.168.0.183:8051/sse"
    }
  }
}
```

#### REST API

**Base URL**: `http://192.168.0.183:8181/api`

**Endpoints**:
- `/knowledge/search` - Semantic search
- `/projects` - Project CRUD
- `/tasks` - Task management
- `/settings` - Configuration

#### WebSocket (Real-time)

**Endpoint**: `ws://192.168.0.183:8181/socket.io`

**Events**:
- `task_created`, `task_updated`
- `document_processed`
- `crawl_progress`

---

## 📝 Pre-Deployment Checklist

### Required

- [ ] **Supabase account** created at https://supabase.com
  - [ ] Free tier project created
  - [ ] Service Role Key obtained (NOT anon key!)
  - [ ] Project URL noted
- [ ] **API Key** obtained:
  - [ ] OpenAI (https://platform.openai.com) - OR
  - [ ] Google Gemini (https://makersuite.google.com) - OR
  - [ ] Ollama installed for local models
- [ ] **AGLSRV1 access** verified:
  - [ ] SSH to 192.168.0.245 working
  - [ ] Proxmox UI accessible
  - [ ] ZFS storage available (50 GB+)

### Optional (Recommended)

- [ ] **WireGuard mesh** configured for remote MCP access
- [ ] **Tailscale** installed for cross-site access
- [ ] **NFS storage** mounted for large document storage
- [ ] **Backup location** configured (e.g., FGSRV6 NFS)
- [ ] **Monitoring** integration planned (Observium/Zabbix)

---

## 🎓 Key Learnings from Research

### Architecture Insights

1. **True Microservices**: Each service runs independently with no shared code
2. **MCP Protocol**: Industry-standard for AI assistant integration
3. **Hybrid RAG**: Combines vector search, keyword matching, and ML reranking
4. **Real-time First**: Socket.IO ensures instant updates across clients
5. **Docker Native**: All services containerized, easy to deploy

### Technology Choices

**Why FastAPI**:
- Async/await for concurrent requests
- Auto-generated OpenAPI docs
- Type safety with Pydantic
- High performance (on par with Node.js)

**Why PGVector**:
- Native PostgreSQL extension (no separate vector DB)
- ACID guarantees for embeddings
- Supabase integration (RLS, backups, etc.)

**Why React + Vite**:
- Fast development (HMR)
- Modern build tool (faster than Webpack)
- TypeScript support
- TanStack Query for server state

**Why MCP Protocol**:
- Standard protocol (not vendor lock-in)
- Multiple transports (HTTP, SSE, stdio)
- Tool-based architecture (extensible)
- Growing ecosystem (Claude Code, Cursor, etc.)

### Performance Considerations

**Bottlenecks**:
1. **Embedding generation**: Use OpenAI for quality, cache aggressively
2. **Vector search**: PGVector handles ~1M vectors efficiently
3. **Web crawling**: Rate-limit to avoid bans (configurable)
4. **ML reranking**: CPU-intensive (optional agents service)

**Optimizations**:
- **Caching**: Redis for embeddings (not yet implemented)
- **Batching**: Process documents in batches of 100
- **Connection pooling**: PostgreSQL max_connections tuning
- **CDN**: Nginx reverse proxy for static assets

### Security Best Practices

1. **Use Service Role Key**: Never use Supabase anon key in `.env`
2. **Encrypt API keys**: Database-managed settings (encrypted at rest)
3. **Rate limiting**: SlowAPI prevents abuse
4. **Firewall**: Restrict MCP port 8051 to trusted networks
5. **HTTPS**: Use Nginx reverse proxy with Let's Encrypt (production)

---

## 🔮 Future Enhancements (Not Yet Implemented)

Based on repository analysis, these features may be planned:

- [ ] **User authentication** (currently uses service key)
- [ ] **Multi-tenancy** (separate knowledge bases per team)
- [ ] **Redis caching** (for embeddings and search results)
- [ ] **Webhooks** (integrate with GitHub, GitLab, etc.)
- [ ] **Advanced analytics** (usage metrics, search quality)
- [ ] **Plugin system** (custom knowledge sources)
- [ ] **GPU support** (PyTorch currently CPU-only)

---

## 📚 Additional Resources

### Official Documentation

- **GitHub Repository**: https://github.com/coleam00/Archon
- **Stable Branch**: https://github.com/coleam00/Archon/tree/stable
- **Docusaurus Docs**: In-repo `/docs` directory

### Related Technologies

- **MCP Protocol**: https://modelcontextprotocol.io
- **Supabase**: https://supabase.com/docs
- **FastAPI**: https://fastapi.tiangolo.com
- **PGVector**: https://github.com/pgvector/pgvector
- **Docker Compose**: https://docs.docker.com/compose/

### AGL Infrastructure

- **Proxmox VE**: https://pve.proxmox.com/wiki/Main_Page
- **LXC Containers**: https://linuxcontainers.org
- **WireGuard**: https://www.wireguard.com

---

## 🚨 Critical Notes

### Database Key Warning

⚠️ **CRITICAL**: Use **Service Role Key**, not anon/public key!

**How to identify**:
- **Service Role Key**: Longer, contains `service_role` in JWT
- **Anon Key**: Shorter, contains `anon` in JWT

**Where to find** (Supabase Dashboard):
1. Settings → API
2. Look for "Service Role" section (secret key)
3. **DO NOT** use "anon/public" key

**Symptom of wrong key**: "Permission denied" errors on save operations

### Docker in LXC Requirements

⚠️ **REQUIRED** in `/etc/pve/lxc/183.conf`:

```ini
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**Without these**: Docker will fail to start with cryptic errors

### Port Conflicts

⚠️ **BEFORE DEPLOYMENT**: Verify ports are free on AGLSRV1:

```bash
# Check if ports are in use
netstat -tlnp | grep -E "3737|8181|8051|8052"

# If conflicts exist, configure custom ports in .env:
ARCHON_UI_PORT=3737
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052
```

---

## 🤝 Support & Contribution

### Issues & Questions

- **GitHub Issues**: https://github.com/coleam00/Archon/issues
- **Discussions**: https://github.com/coleam00/Archon/discussions

### AGL Infrastructure Support

- **CLAUDE.md**: Project documentation and connection guides
- **CT183 Deployment**: This research documentation

---

## 📅 Next Actions

1. **Review comprehensive analysis** (`archon-comprehensive-analysis.md`)
2. **Prepare prerequisites** (Supabase, API keys)
3. **Follow deployment guide** (`ct183-deployment-guide.md`)
4. **Configure AI clients** (Claude Code, Cursor, etc.)
5. **Populate knowledge base** with organizational docs
6. **Test MCP integration** from development environments
7. **Monitor performance** and scale resources as needed

---

**Research Status**: ✅ Complete
**Deployment Status**: ⏳ Ready to Deploy
**Documentation Status**: ✅ Complete

**End of README**

*Generated by Research Agent on 2025-10-27*
*Based on Archon GitHub Repository Analysis*
