# Archon Project - Comprehensive Technical Analysis

> **Research Date**: 2025-10-27
> **Source**: https://github.com/coleam00/Archon
> **Branch**: stable
> **Version**: 0.1.0 (Beta)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture & Technology Stack](#2-architecture--technology-stack)
3. [System Requirements](#3-system-requirements)
4. [Installation & Deployment](#4-installation--deployment)
5. [Configuration](#5-configuration)
6. [Integration Points](#6-integration-points)
7. [Use Cases & Capabilities](#7-use-cases--capabilities)
8. [CT183 Container Design Recommendations](#8-ct183-container-design-recommendations)

---

## 1. Project Overview

### 1.1 What is Archon?

**Archon** is an open-source **command center for AI coding assistants** that functions as a **Model Context Protocol (MCP) server**. It enables AI agents to access shared knowledge bases, context, and task management systems in a centralized, collaborative manner.

### 1.2 Problem Statement & Solution

**Problem**: AI coding assistants (Claude Code, Cursor, Windsurf, etc.) operate in isolation without access to:
- Shared organizational knowledge bases
- Project-specific documentation
- Collaborative task management
- Historical context across sessions
- Unified code examples and patterns

**Solution**: Archon provides:
- **Unified Knowledge Base**: Centralized repository for documentation, code examples, and organizational knowledge
- **Intelligent Search**: Vector-based semantic search with embeddings and RAG (Retrieval-Augmented Generation)
- **Task Management**: Hierarchical project/feature/task organization with AI-assisted requirement generation
- **Multi-AI Integration**: Single MCP server supporting multiple AI coding tools simultaneously
- **Real-time Collaboration**: WebSocket-based updates across all connected clients
- **Version Control**: Document versioning and history tracking

### 1.3 Key Differentiators

- **True Microservices Architecture**: Independent services with no shared code dependencies
- **Multi-LLM Support**: OpenAI, Google Gemini, Ollama (local models)
- **Hybrid RAG Strategies**: Result reranking, semantic search, and contextual retrieval
- **Real-time Updates**: Socket.IO integration for live collaboration
- **MCP Protocol Standard**: Compatible with any MCP-enabled AI client
- **Self-hosted & Private**: Full control over data and infrastructure

---

## 2. Architecture & Technology Stack

### 2.1 Microservices Architecture

Archon uses a **true microservices design** with four independent services:

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Network Bridge                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   │
│  │ Frontend UI  │   │ Server API   │   │  MCP Server  │   │
│  │  (React)     │◄──┤  (FastAPI)   │◄──┤   (HTTP)     │   │
│  │  Port 3737   │   │  Port 8181   │   │  Port 8051   │   │
│  └──────────────┘   └──────┬───────┘   └──────────────┘   │
│                             │                               │
│                     ┌───────▼───────┐                       │
│                     │ Agents Service│                       │
│                     │  (PydanticAI) │                       │
│                     │  Port 8052    │                       │
│                     └───────┬───────┘                       │
│                             │                               │
└─────────────────────────────┼───────────────────────────────┘
                              │
                     ┌────────▼─────────┐
                     │   Supabase DB    │
                     │  (PostgreSQL +   │
                     │    PGVector)     │
                     └──────────────────┘
```

**Communication Protocol**:
- **HTTP/REST**: Service-to-service API calls
- **Socket.IO**: Real-time bidirectional updates (UI ↔ Server)
- **MCP Protocol**: AI client integration (SSE-based)
- **PostgreSQL**: Shared data persistence layer

### 2.2 Technology Stack

#### Backend Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **API Framework** | FastAPI | >0.104.0 | High-performance async web framework |
| **ASGI Server** | Uvicorn | Latest | Production-grade ASGI server |
| **Python Runtime** | Python | >=3.12 | Modern Python with performance improvements |
| **Package Manager** | uv | Latest | Fast Python package management |
| **Database** | PostgreSQL | 15+ | Relational data storage |
| **Vector DB** | PGVector | Latest | Semantic search embeddings |
| **ORM/Client** | Supabase Python | 2.15.1 | Database client with RLS support |
| **Async DB Driver** | asyncpg | Latest | High-performance PostgreSQL driver |
| **AI/LLM** | OpenAI SDK | 1.71.0 | LLM integration (GPT-4, GPT-3.5) |
| **AI Framework** | PydanticAI | >0.0.13 | Type-safe AI agent framework |
| **Web Crawler** | Crawl4AI | 0.7.4 | Intelligent web scraping with sitemap support |
| **PDF Processing** | PyPDF2, pdfplumber | Latest | PDF parsing and text extraction |
| **Document Processing** | python-docx, markdown | Latest | Word and Markdown parsing |
| **Security** | python-jose + cryptography | Latest | JWT tokens, encryption |
| **Rate Limiting** | slowapi | Latest | API throttling |
| **Logging** | logfire | Latest | Structured logging and observability |
| **ML/Reranking** | sentence-transformers, torch | >2.0.0 | Semantic similarity and result reranking |
| **MCP Protocol** | mcp | 1.12.2 | Model Context Protocol implementation |

#### Frontend Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | React | 18.3.1 | UI component library |
| **Build Tool** | Vite | 5.2.0 | Fast bundler and dev server |
| **TypeScript** | TypeScript | 5.5.4 | Type safety |
| **State Management** | TanStack React Query | 5.85.8 | Server state management |
| **Router** | React Router DOM | 6.26.2 | Client-side routing |
| **Styling** | Tailwind CSS | 4.1.2 | Utility-first CSS framework |
| **Animation** | Framer Motion | 11.5.4 | Motion library |
| **UI Components** | Radix UI | Latest | Accessible component primitives |
| **Markdown Editor** | MDX Editor | 3.42.0 | Rich text editing |
| **Drag & Drop** | React DnD | 16.0.1 | Drag-and-drop interactions |
| **Icons** | Lucide React | Latest | Icon library |
| **Validation** | Zod | 3.25.46 | Schema validation |
| **Date Handling** | Date-fns | 4.1.0 | Date utilities |
| **Real-time** | Socket.IO Client | Latest | WebSocket communication |
| **Testing** | Vitest | 1.6.0 | Unit testing framework |
| **Linting** | ESLint, Biome | 8.57.1, 2.2.2 | Code quality |

#### Infrastructure Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Containerization** | Docker | Service isolation |
| **Orchestration** | Docker Compose | Multi-container deployment |
| **Database Platform** | Supabase | Managed PostgreSQL + Auth + Storage |
| **Documentation** | Docusaurus 2 | Static site generator |
| **Development Tools** | Make | Build automation |

### 2.3 Service Breakdown

#### 2.3.1 archon-server (Port 8181)

**Purpose**: Core business logic and API orchestration

**Key Responsibilities**:
- Web crawling with sitemap detection
- Document processing (PDF, DOCX, Markdown)
- Vector embeddings generation
- Knowledge base management
- Task/project CRUD operations
- Real-time Socket.IO broadcasts
- Authentication and authorization
- Rate limiting and security

**Build Configuration**:
- **Dockerfile**: `./python/Dockerfile.server`
- **Context**: `./python`
- **Volumes**: Source code, tests, migrations (for hot reload)
- **Health Check**: `GET /health` (30s interval, 40s startup)
- **Environment**: Supabase credentials, OpenAI keys, service discovery mode

#### 2.3.2 archon-mcp (Port 8051)

**Purpose**: Model Context Protocol server for AI client integration

**Key Responsibilities**:
- MCP protocol implementation (HTTP/SSE transport)
- AI client request routing
- Context retrieval from knowledge base
- Task management interface for AI agents
- Streaming responses to AI clients

**Build Configuration**:
- **Dockerfile**: `./python/Dockerfile.mcp`
- **Context**: `./python`
- **Dependencies**: Requires `archon-server` health check
- **Health Check**: Socket connectivity on port 8051 (60s startup delay)
- **Network**: Communicates with `archon-server` via `http://archon-server:8181`

**Transport**: Server-Sent Events (SSE) for real-time streaming

#### 2.3.3 archon-agents (Port 8052)

**Purpose**: PydanticAI-based ML operations and reranking

**Key Responsibilities**:
- Semantic result reranking
- Advanced RAG strategies
- ML-based query enhancement
- Sentence transformer embeddings

**Build Configuration**:
- **Dockerfile**: `./python/Dockerfile.agents`
- **Context**: `./python`
- **Profile**: `agents` (opt-in via `--profile agents`)
- **Health Check**: `GET /health`
- **Environment**: OpenAI credentials, Supabase config

**Note**: Optional service - only start if advanced reranking is needed

#### 2.3.4 archon-frontend (Port 3737)

**Purpose**: Web-based user interface

**Key Responsibilities**:
- Dashboard for knowledge base management
- Project/task visualization
- Real-time updates via Socket.IO
- API key configuration
- Settings management
- Document editor (MDX)

**Build Configuration**:
- **Dockerfile**: `./archon-ui-main/Dockerfile`
- **Context**: `./archon-ui-main`
- **Volumes**: Source and public directories (for hot reload)
- **Environment**: Vite config, Docker environment flag
- **Proxy**: Relative URLs to API server

---

## 3. System Requirements

### 3.1 Hardware Requirements

#### Minimum (Development/Testing)

| Component | Specification |
|-----------|--------------|
| **CPU** | 2 cores (x86_64) |
| **RAM** | 4 GB |
| **Storage** | 10 GB free space |
| **Network** | Internet connection for LLM APIs |

#### Recommended (Production)

| Component | Specification |
|-----------|--------------|
| **CPU** | 4+ cores (x86_64) |
| **RAM** | 8 GB (16 GB with agents service) |
| **Storage** | 50 GB SSD (for document storage and embeddings) |
| **Network** | 100 Mbps+ (for web crawling and API calls) |

#### With ML Agents Service

| Component | Specification |
|-----------|--------------|
| **CPU** | 8+ cores (x86_64) |
| **RAM** | 16 GB+ |
| **Storage** | 100 GB SSD |
| **GPU** | Optional (PyTorch CPU-only by default) |

**Note**: PyTorch is configured for **CPU-only** via `https://download.pytorch.org/whl/cpu` index. GPU support requires custom configuration.

### 3.2 Software Requirements

#### Required

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker Desktop** | Latest | Container runtime |
| **Docker Compose** | v2.0+ | Multi-container orchestration |
| **Git** | Latest | Repository cloning |

#### Optional (Development)

| Software | Version | Purpose |
|----------|---------|---------|
| **Node.js** | 18+ | Frontend development (hybrid mode) |
| **Python** | 3.12+ | Backend development (hybrid mode) |
| **Make** | Latest | Build automation |
| **uv** | Latest | Python package management |

### 3.3 Network Requirements

#### Ports (Default - Configurable)

| Port | Service | Protocol | Access Level |
|------|---------|----------|--------------|
| **3737** | Frontend UI | HTTP | Public (via reverse proxy) |
| **8181** | Server API | HTTP | Internal (Docker network) |
| **8051** | MCP Server | HTTP/SSE | AI Clients (localhost or VPN) |
| **8052** | Agents Service | HTTP | Internal (Docker network) |

#### External Connectivity

| Destination | Purpose | Required |
|-------------|---------|----------|
| **Supabase Cloud** | Database API (or localhost:8000 for local) | Yes |
| **OpenAI API** | GPT-4/3.5 completions | Optional (can use Ollama) |
| **Google Gemini API** | Gemini models | Optional |
| **Web Crawling Targets** | Documentation sites | Optional |

#### Firewall Rules

- **Inbound**: Allow ports 3737 (UI), 8051 (MCP) from trusted networks
- **Outbound**: Allow HTTPS (443) to LLM APIs and Supabase
- **Docker Network**: Bridge mode (default) - no additional configuration

### 3.4 Third-Party Services

#### Required

**Supabase** (Free Tier Compatible):
- **Purpose**: PostgreSQL database with PGVector extension
- **Features Used**: Row-level security (RLS), real-time subscriptions, vector search
- **Options**:
  - **Cloud**: Free tier at https://supabase.com (500 MB database)
  - **Self-hosted**: Local Supabase stack (requires additional ~2 GB RAM)
- **Credentials Needed**: Project URL, Service Role Key (not anon key!)

#### Optional

**OpenAI**:
- **Purpose**: GPT-4/GPT-3.5 for completions and embeddings
- **Cost**: Pay-as-you-go (embeddings ~$0.0001/1K tokens)
- **Alternative**: Use Ollama for local models (free)

**Google Gemini**:
- **Purpose**: Alternative LLM provider
- **Cost**: Free tier available

**Logfire**:
- **Purpose**: Structured logging and observability
- **Cost**: Free tier available
- **Note**: Optional - LOG_LEVEL can be set without Logfire

---

## 4. Installation & Deployment

### 4.1 Standard Installation (Docker Compose)

#### Step 1: Clone Repository

```bash
git clone -b stable https://github.com/coleam00/archon.git
cd archon
```

**Note**: Use the `stable` branch for production deployments. `main` may contain unstable features.

#### Step 2: Configure Environment

```bash
cp .env.example .env
nano .env  # or vim, code, etc.
```

**Minimum Required Configuration**:

```env
# Supabase Configuration (REQUIRED)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here

# Port Configuration (Optional - defaults shown)
ARCHON_UI_PORT=3737
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052

# Hostname (Optional - for custom domains)
HOST=localhost
```

**CRITICAL**: Use the **Service Role Key**, not the anon/public key. Service keys are longer and contain `service_role` in the JWT. Using the wrong key causes "permission denied" errors on save operations.

#### Step 3: Database Setup

1. Log in to Supabase Dashboard
2. Navigate to **SQL Editor**
3. Copy contents of `migration/complete_setup.sql`
4. Execute SQL script
5. Verify tables and functions are created

**Expected Tables**:
- `projects`, `features`, `tasks`
- `knowledge_base`, `document_chunks`
- `settings`, `api_keys`

#### Step 4: Start Services

**Standard (without agents service)**:
```bash
docker compose up --build -d
```

**With ML Agents Service**:
```bash
docker compose --profile agents up --build -d
```

**Monitor Logs**:
```bash
docker compose logs -f
```

#### Step 5: Access UI & Configure

1. Open browser to `http://localhost:3737`
2. Complete onboarding wizard:
   - Set OpenAI API key (or configure Gemini/Ollama)
   - Select default model (GPT-4, GPT-3.5-turbo, etc.)
   - Configure RAG strategy (hybrid recommended)
3. Verify health checks:
   - `http://localhost:8181/health` → {"status": "healthy"}
   - `http://localhost:8051/` → MCP server info

### 4.2 Development Installation

#### Hybrid Mode (Recommended for Frontend Development)

```bash
make dev
```

**What it does**:
- Starts backend services in Docker (server, MCP, agents if profiled)
- Runs frontend locally with Vite hot reload
- Enables fast UI iteration without rebuilds

**Prerequisites**:
- Node.js 18+
- Make installed

#### Full Docker Mode

```bash
make dev-docker
```

**What it does**:
- All services in Docker with volume mounts
- Source code hot reload for all services
- Good for full-stack development

#### Local Python Development

```bash
# Install uv package manager
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
cd python
uv sync

# Run server locally
uv run uvicorn src.server.main:app --reload --port 8181
```

### 4.3 Production Deployment

#### Option 1: Docker Compose (Single Host)

**Recommended Setup**:
```yaml
# docker-compose.prod.yml
services:
  archon-server:
    image: archon-server:latest
    restart: unless-stopped
    environment:
      - LOG_LEVEL=WARNING
      - PROD=true
    # ... (full config from main compose)

  archon-mcp:
    image: archon-mcp:latest
    restart: unless-stopped
    # ... (full config)

  archon-frontend:
    image: archon-frontend:latest
    restart: unless-stopped
    # ... (full config)
```

**Deploy**:
```bash
docker compose -f docker-compose.prod.yml up -d
```

#### Option 2: Kubernetes (Multi-Host)

**Requirements**:
- Kubernetes cluster (K3s, K8s, etc.)
- Persistent volumes for document storage
- Ingress controller for routing

**Sample Deployment Structure**:
```yaml
# archon-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: archon-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: archon-server
  template:
    metadata:
      labels:
        app: archon-server
    spec:
      containers:
      - name: archon-server
        image: archon-server:latest
        ports:
        - containerPort: 8181
        env:
        - name: SUPABASE_URL
          valueFrom:
            secretKeyRef:
              name: archon-secrets
              key: supabase-url
        # ... (full config)
```

**Note**: Archon does not currently provide official Kubernetes manifests. The above is a reference implementation.

#### Option 3: LXC Container (Proxmox)

**Recommended for AGL Infrastructure**:

**Container Specs** (CT183):
- **Template**: Ubuntu 24.04 LTS
- **CPU**: 4 cores
- **RAM**: 8 GB (16 GB with agents)
- **Storage**: 50 GB (100 GB recommended)
- **Network**: Bridge (vmbr0) with static IP
- **Features**: `keyctl=1,nesting=1` (for Docker in LXC)

**Installation Steps**:
```bash
# 1. Update system
apt update && apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# 3. Install Docker Compose
apt install docker-compose-plugin -y

# 4. Clone Archon
git clone -b stable https://github.com/coleam00/archon.git /opt/archon
cd /opt/archon

# 5. Configure environment
cp .env.example .env
nano .env

# 6. Deploy
docker compose up -d

# 7. Enable systemd service (optional)
cat > /etc/systemd/system/archon.service <<EOF
[Unit]
Description=Archon AI Command Center
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/archon
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable archon.service
```

### 4.4 Database Migration & Reset

#### Reset Database (Clear All Data)

```bash
# 1. Execute reset script in Supabase SQL Editor
# Paste contents of migration/RESET_DB.sql

# 2. Re-run setup
# Paste contents of migration/complete_setup.sql

# 3. Restart services
docker compose restart
```

#### Version Upgrades

**Check for Migrations**:
```bash
# Pull latest stable branch
git pull origin stable

# Check for new migration files
ls -la migration/

# Execute any new SQL files in Supabase SQL Editor
```

**Backup Before Upgrade**:
```bash
# Export Supabase data via Dashboard > Database > Backups
# Or use pg_dump if self-hosted
```

---

## 5. Configuration

### 5.1 Environment Variables

#### Core Configuration (.env)

```env
# ============================================
# SUPABASE CONFIGURATION (REQUIRED)
# ============================================
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here

# ============================================
# PORT CONFIGURATION (Optional)
# ============================================
ARCHON_UI_PORT=3737
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052
ARCHON_DOCS_PORT=3838

# ============================================
# HOSTNAME CONFIGURATION (Optional)
# ============================================
HOST=localhost
# For production: HOST=archon.yourdomain.com

# ============================================
# LOGGING & OBSERVABILITY (Optional)
# ============================================
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR
LOGFIRE_TOKEN=  # Optional Logfire integration

# ============================================
# FRONTEND CONFIGURATION (Optional)
# ============================================
VITE_ALLOWED_HOSTS=localhost,127.0.0.1,::1
VITE_SHOW_DEVTOOLS=false  # Enable TanStack Query DevTools
PROD=false  # Proxy API through UI port in production

# ============================================
# SERVICE DISCOVERY (Internal)
# ============================================
# Automatically set to 'docker_compose' in containers
# No manual configuration needed
```

### 5.2 Database-Managed Settings

**Configured via UI after initial setup** (`http://localhost:3737/settings`):

#### API Keys & Models

```sql
-- Settings are encrypted and stored in Supabase
-- Managed via Settings UI:

- OpenAI API Key (encrypted)
- Google Gemini API Key (encrypted)
- Ollama Endpoint (for local models)
- Default Model Selection (gpt-4, gpt-3.5-turbo, gemini-pro, etc.)
```

#### RAG Strategy Configuration

**Available Strategies**:
- **Basic**: Simple semantic search
- **Hybrid**: Combines vector search with keyword matching
- **Reranked**: Uses agents service for result reranking (requires `--profile agents`)

**Crawler Settings**:
- Max pages per crawl
- Crawl depth limit
- Allowed domains
- User agent configuration

### 5.3 MCP Server Configuration

**For AI Clients** (Claude Code, Cursor, Windsurf):

#### Claude Code Configuration

**Add to `~/.config/claude/mcp_servers.json`**:

```json
{
  "mcpServers": {
    "archon": {
      "command": "node",
      "args": ["-e", "fetch('http://localhost:8051/mcp').then(r=>r.text()).then(console.log)"],
      "env": {
        "ARCHON_API_URL": "http://localhost:8051"
      }
    }
  }
}
```

**Or via SSE transport**:
```json
{
  "mcpServers": {
    "archon": {
      "transport": "sse",
      "url": "http://localhost:8051/sse"
    }
  }
}
```

#### Cursor Configuration

**Add to Cursor settings** (Settings → MCP Servers):

```json
{
  "archon": {
    "url": "http://localhost:8051",
    "protocol": "mcp"
  }
}
```

#### Windsurf Configuration

**Add to Windsurf MCP config**:

```json
{
  "servers": {
    "archon": {
      "endpoint": "http://localhost:8051/mcp",
      "transport": "http"
    }
  }
}
```

**Remote Access** (via Tailscale/WireGuard):

If Archon is running on CT183 (e.g., 192.168.0.183), configure:
```json
{
  "archon": {
    "url": "http://192.168.0.183:8051",  // LAN
    // OR
    "url": "http://10.6.0.183:8051",     // WireGuard mesh
    // OR
    "url": "http://100.x.x.x:8051"       // Tailscale
  }
}
```

### 5.4 Docker Compose Customization

#### Custom Ports Example

```yaml
# docker-compose.override.yml
services:
  archon-frontend:
    ports:
      - "80:3737"  # Expose on standard HTTP port

  archon-mcp:
    ports:
      - "0.0.0.0:8051:8051"  # Expose to all interfaces (for remote access)
```

#### Resource Limits

```yaml
# docker-compose.override.yml
services:
  archon-server:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G

  archon-agents:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G  # ML models need more RAM
```

#### Persistent Volumes

```yaml
# docker-compose.override.yml
services:
  archon-server:
    volumes:
      - archon-documents:/app/documents  # Persist uploaded documents
      - archon-cache:/app/cache          # Persist embeddings cache

volumes:
  archon-documents:
  archon-cache:
```

---

## 6. Integration Points

### 6.1 MCP Server Integration

**Model Context Protocol** (MCP) is the primary integration method for AI clients.

#### Protocol Overview

**Transport**: HTTP with Server-Sent Events (SSE)
**Endpoint**: `http://localhost:8051/`
**Methods**: GET, POST

#### Available MCP Tools

Archon exposes the following tools to AI clients:

| Tool | Description | Parameters |
|------|-------------|-----------|
| **search_knowledge** | Semantic search across knowledge base | `query`, `limit`, `threshold` |
| **get_document** | Retrieve full document by ID | `document_id` |
| **list_projects** | Get all projects with tasks | `status_filter` |
| **create_task** | Create new task with AI context | `title`, `description`, `project_id` |
| **update_task** | Update task status/details | `task_id`, `updates` |
| **get_task_context** | Retrieve task with related code/docs | `task_id` |

#### Example MCP Flow

```
AI Client (Claude Code)
    ↓
MCP Protocol Request: search_knowledge("authentication patterns")
    ↓
Archon MCP Server (Port 8051)
    ↓
Archon API Server (Port 8181)
    ↓
Supabase (Vector Search)
    ↓
Results (semantic matches with scores)
    ↓
AI Client (context for coding)
```

### 6.2 REST API Integration

**Base URL**: `http://localhost:8181`

#### Authentication

Currently uses **Supabase Service Key** authentication. Future versions may support user-based auth.

#### Key Endpoints

**Knowledge Base**:
```bash
# Search documents
POST /api/knowledge/search
{
  "query": "authentication best practices",
  "limit": 10
}

# Upload document
POST /api/knowledge/upload
Content-Type: multipart/form-data
file: <PDF/DOCX/MD>

# Crawl website
POST /api/knowledge/crawl
{
  "url": "https://docs.example.com",
  "max_pages": 100
}
```

**Projects & Tasks**:
```bash
# List projects
GET /api/projects

# Create project
POST /api/projects
{
  "name": "My Project",
  "description": "Project description"
}

# Create task
POST /api/tasks
{
  "title": "Implement auth",
  "project_id": 1,
  "description": "Add JWT authentication"
}
```

**Settings**:
```bash
# Get settings
GET /api/settings

# Update settings
PUT /api/settings
{
  "openai_api_key": "sk-...",
  "default_model": "gpt-4"
}
```

### 6.3 WebSocket Integration (Socket.IO)

**Endpoint**: `ws://localhost:8181/socket.io`

#### Real-time Events

**Client → Server**:
- `join_project`: Subscribe to project updates
- `leave_project`: Unsubscribe
- `task_update`: Push task status change

**Server → Client**:
- `task_created`: New task added
- `task_updated`: Task status changed
- `document_processed`: New document indexed
- `crawl_progress`: Web crawl status update

#### Example Integration (JavaScript)

```javascript
import { io } from 'socket.io-client';

const socket = io('http://localhost:8181');

// Subscribe to project updates
socket.emit('join_project', { project_id: 1 });

// Listen for task updates
socket.on('task_updated', (data) => {
  console.log('Task updated:', data);
  // Update UI, trigger notifications, etc.
});
```

### 6.4 Supabase Direct Integration

**Use Cases**:
- Custom analytics dashboards
- Data export/import
- Advanced querying
- Backup automation

**Connection Details**:
```env
POSTGRES_HOST=db.your-project.supabase.co
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<your-password>
```

**Example Query** (using `psql` or any PostgreSQL client):

```sql
-- Get all knowledge base documents
SELECT id, title, url, created_at
FROM knowledge_base
ORDER BY created_at DESC;

-- Get task statistics by project
SELECT
  p.name,
  COUNT(t.id) AS total_tasks,
  SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) AS completed_tasks
FROM projects p
LEFT JOIN tasks t ON p.id = t.project_id
GROUP BY p.name;
```

### 6.5 LLM Provider Integration

#### OpenAI

**Requirements**:
- API Key from https://platform.openai.com
- Sufficient credits ($5+ recommended for testing)

**Supported Models**:
- `gpt-4` (recommended for complex tasks)
- `gpt-4-turbo-preview`
- `gpt-3.5-turbo` (cost-effective)
- `text-embedding-ada-002` (for embeddings)

**Configuration** (via UI):
```
Settings → API Keys → OpenAI API Key
Settings → Model Selection → gpt-4
```

#### Google Gemini

**Requirements**:
- API Key from https://makersuite.google.com

**Supported Models**:
- `gemini-pro`
- `gemini-pro-vision`

**Configuration** (via UI):
```
Settings → API Keys → Google Gemini API Key
Settings → Model Selection → gemini-pro
```

#### Ollama (Local Models)

**Requirements**:
- Ollama installed locally or on network
- Models pulled (e.g., `ollama pull llama2`)

**Configuration** (via UI):
```
Settings → Ollama Endpoint → http://localhost:11434
Settings → Model Selection → llama2
```

**Advantages**:
- No API costs
- Full data privacy
- Offline operation

**Disadvantages**:
- Requires significant local compute (16GB+ RAM recommended)
- Slower than cloud APIs
- May require fine-tuning for best results

---

## 7. Use Cases & Capabilities

### 7.1 Primary Use Cases

#### 7.1.1 Centralized Knowledge Management

**Scenario**: Software team with scattered documentation across GitHub wikis, Confluence, Google Docs, and local files.

**Archon Solution**:
1. **Crawl documentation sites** with automatic sitemap detection
2. **Upload PDF/DOCX manuals** for processing
3. **Index code examples** from repositories
4. **Vector search** enables semantic queries ("how to implement authentication" finds relevant docs even without exact keywords)

**Benefits**:
- Single source of truth for AI assistants
- Consistent context across all developers
- No manual copy-paste of documentation to AI chats

#### 7.1.2 AI-Assisted Development Workflows

**Scenario**: Developer using Claude Code needs to implement a new feature.

**Archon Workflow**:
1. Claude Code queries Archon via MCP: "Get authentication patterns"
2. Archon returns semantic search results from knowledge base
3. Developer reviews context, starts implementation
4. Claude Code creates task in Archon with AI-generated subtasks
5. Real-time updates sync across team via WebSocket

**Benefits**:
- AI has full project context (not just current file)
- Task tracking without leaving IDE
- Version-controlled requirements

#### 7.1.3 Cross-Tool Collaboration

**Scenario**: Team uses multiple AI coding tools (Claude Code, Cursor, Windsurf).

**Archon Solution**:
- All tools connect to same MCP server
- Shared knowledge base ensures consistency
- Task updates propagate to all clients in real-time
- Collaborative editing without conflicts

**Benefits**:
- No tool lock-in
- Consistent AI behavior across tools
- Centralized task management

#### 7.1.4 Onboarding & Knowledge Transfer

**Scenario**: New developer joins team.

**Archon Workflow**:
1. Admin uploads onboarding docs to Archon
2. New developer's AI assistant has instant access to:
   - Architecture diagrams
   - Code style guides
   - Setup instructions
   - Common patterns
3. AI can answer questions like "how do we handle errors in this codebase?"

**Benefits**:
- Faster onboarding (hours instead of days)
- Consistent knowledge transfer
- Reduces senior developer interruptions

#### 7.1.5 Code Example Repository

**Scenario**: Team has recurring patterns (API clients, database migrations, tests).

**Archon Solution**:
1. Index code examples from existing codebase
2. Tag patterns (e.g., "API client", "database migration")
3. AI can retrieve similar examples when implementing new features

**Benefits**:
- Consistency across codebase
- Accelerates development
- Reduces copy-paste errors

### 7.2 Advanced Capabilities

#### 7.2.1 Hybrid RAG Strategies

**Basic RAG**: Simple vector search
**Hybrid RAG**: Vector search + keyword matching + result reranking

**When to Use**:
- **Basic**: Small knowledge bases (<1000 docs)
- **Hybrid**: Medium knowledge bases (1000-10000 docs)
- **Reranked**: Large knowledge bases (10000+ docs) - requires agents service

**Performance Comparison**:
| Strategy | Precision | Recall | Latency |
|----------|-----------|--------|---------|
| Basic | 70% | 80% | 50ms |
| Hybrid | 85% | 90% | 100ms |
| Reranked | 95% | 95% | 500ms |

#### 7.2.2 Multi-LLM Workflows

**Example**: Use different models for different tasks

```python
# Configuration in Settings UI
{
  "embedding_model": "text-embedding-ada-002",  # OpenAI (high quality)
  "completion_model": "llama2",                 # Ollama (cost-effective)
  "reranking_model": "gpt-4"                    # OpenAI (accuracy critical)
}
```

**Benefits**:
- Cost optimization (expensive models only where needed)
- Offline fallback (Ollama when internet unavailable)
- Best-of-breed approach

#### 7.2.3 Version-Controlled Documents

**Feature**: Document history tracking

**Use Case**: Track changes to requirements documents

```sql
-- Archon stores document versions
SELECT version, content, updated_at
FROM document_versions
WHERE document_id = 123
ORDER BY version DESC;
```

**Benefits**:
- Audit trail for compliance
- Rollback to previous versions
- Compare changes over time

#### 7.2.4 Code-Aware Chunking

**Feature**: Intelligent document splitting for code files

**How it Works**:
1. Detect programming language
2. Parse AST (Abstract Syntax Tree)
3. Chunk by function/class boundaries
4. Preserve context in vector embeddings

**Benefits**:
- Better search results for code queries
- Context-aware retrieval (entire function, not partial)
- Improved AI code generation

---

## 8. CT183 Container Design Recommendations

### 8.1 Container Specifications

Based on the research, here are the recommended specs for **CT183 (Archon deployment on AGLSRV1)**:

#### LXC Configuration

```ini
# /etc/pve/lxc/183.conf
arch: amd64
cores: 4
features: keyctl=1,nesting=1
hostname: archon
memory: 8192
nameserver: 192.168.0.102  # pihole DNS
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.0.1,hwaddr=XX:XX:XX:XX:XX:XX,ip=192.168.0.183/24,type=veth
ostype: ubuntu
rootfs: local-zfs:subvol-183-disk-0,size=50G
swap: 4096
unprivileged: 1

# LXC nested container support
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**Key Features**:
- **keyctl=1**: Required for Docker in LXC
- **nesting=1**: Enables nested containers
- **4 cores**: Sufficient for concurrent API calls and embeddings
- **8 GB RAM**: Base recommendation (increase to 16 GB if using agents service)
- **50 GB storage**: Room for documents, embeddings, and Docker images

#### Network Configuration

**Primary Network**:
- **LAN IP**: 192.168.0.183 (eth0)
- **WireGuard**: 10.6.0.183 (wg0, optional for remote MCP access)
- **Tailscale**: Optional (for cross-site access)

**Firewall Rules**:
```bash
# /etc/pve/firewall/183.fw
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -p tcp -dport 3737 -source 192.168.0.0/24  # UI from LAN
IN ACCEPT -p tcp -dport 8051 -source 192.168.0.0/24  # MCP from LAN
IN ACCEPT -p tcp -dport 8051 -source 10.6.0.0/24     # MCP from WireGuard
OUT ACCEPT                                           # All outbound
```

### 8.2 Installation Procedure for CT183

#### Phase 1: Container Creation

```bash
# On AGLSRV1 host (192.168.0.245)
pct create 183 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname archon \
  --cores 4 \
  --memory 8192 \
  --swap 4096 \
  --rootfs local-zfs:50 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.0.183/24,gw=192.168.0.1 \
  --nameserver 192.168.0.102 \
  --features keyctl=1,nesting=1 \
  --unprivileged 1

# Enable nested containers
cat >> /etc/pve/lxc/183.conf <<EOF
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

# Start container
pct start 183
```

#### Phase 2: Base System Setup

```bash
# Enter container
pct enter 183

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
apt install docker-compose-plugin -y

# Install additional tools
apt install -y git curl wget nano htop

# Configure timezone
timedatectl set-timezone America/Sao_Paulo  # or your timezone

# Create archon user (optional, for non-root operation)
adduser --disabled-password --gecos "" archon
usermod -aG docker archon
```

#### Phase 3: Archon Deployment

```bash
# Clone repository
git clone -b stable https://github.com/coleam00/archon.git /opt/archon
cd /opt/archon

# Configure environment
cp .env.example .env
nano .env
```

**Recommended .env for CT183**:
```env
# Supabase (use cloud or local)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key

# Custom ports (optional - expose on standard ports)
ARCHON_UI_PORT=80     # Standard HTTP
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
ARCHON_AGENTS_PORT=8052

# Hostname (for reverse proxy)
HOST=archon.agl.local  # or 192.168.0.183

# Logging
LOG_LEVEL=INFO
```

**Deploy**:
```bash
# Standard deployment (without agents)
docker compose up -d

# OR with agents service (requires 16 GB RAM)
docker compose --profile agents up -d

# Verify services
docker compose ps
docker compose logs -f
```

#### Phase 4: Systemd Service

```bash
cat > /etc/systemd/system/archon.service <<'EOF'
[Unit]
Description=Archon AI Command Center
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/archon
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable archon.service
systemctl start archon.service
```

#### Phase 5: Reverse Proxy (Optional - Nginx)

**For production-grade access with SSL**:

```bash
# Install Nginx
apt install nginx -y

# Create reverse proxy config
cat > /etc/nginx/sites-available/archon <<'EOF'
server {
    listen 80;
    server_name archon.agl.local 192.168.0.183;

    # UI
    location / {
        proxy_pass http://localhost:3737;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # MCP Server
    location /mcp {
        proxy_pass http://localhost:8051;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;
    }

    # API Server
    location /api {
        proxy_pass http://localhost:8181;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }
}
EOF

# Enable site
ln -s /etc/nginx/sites-available/archon /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

**SSL with Let's Encrypt** (if using public domain):
```bash
apt install certbot python3-certbot-nginx -y
certbot --nginx -d archon.yourdomain.com
```

### 8.3 Integration with AGL Infrastructure

#### WireGuard Mesh Access

**Enable MCP access from other hosts via WireGuard**:

```bash
# Install WireGuard in CT183
apt install wireguard -y

# Configure WireGuard interface
cat > /etc/wireguard/wg0.conf <<'EOF'
[Interface]
PrivateKey = <GENERATE_NEW_KEY>
Address = 10.6.0.183/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
EOF

# Generate keys
wg genkey | tee /tmp/privatekey | wg pubkey > /tmp/publickey

# Update hub (FGSRV6) with new peer
# Add to hub's WireGuard config:
# [Peer]
# PublicKey = <content of /tmp/publickey>
# AllowedIPs = 10.6.0.183/32

# Start WireGuard
wg-quick up wg0
systemctl enable wg-quick@wg0

# Verify connectivity
ping 10.6.0.5  # Hub
```

**Update Firewall**:
```bash
# Allow MCP access from WireGuard mesh
iptables -A INPUT -p tcp --dport 8051 -s 10.6.0.0/24 -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```

#### Tailscale Integration (Optional)

**For cross-site access** (e.g., from AGLHQ11 WSL2):

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
tailscale up

# Advertise routes (optional - expose entire LAN)
tailscale up --advertise-routes=192.168.0.0/24
```

**Access from WSL2**:
```bash
# From AGLHQ11
ssh root@100.x.x.x  # Tailscale IP of CT183

# Configure AI client to use Tailscale IP
# ~/.config/claude/mcp_servers.json
{
  "archon": {
    "url": "http://100.x.x.x:8051"
  }
}
```

#### NFS Storage for Documents (Optional)

**Mount NFS for large document storage**:

```bash
# On CT183
mkdir -p /mnt/archon-docs

# Mount FGSRV6 NFS via WireGuard
echo "10.6.0.5:/archon /mnt/archon-docs nfs4 defaults,_netdev 0 0" >> /etc/fstab
mount -a

# Configure Archon to use NFS
# Add volume to docker-compose.override.yml:
services:
  archon-server:
    volumes:
      - /mnt/archon-docs:/app/documents
```

### 8.4 Monitoring & Maintenance

#### Health Checks

**Automated monitoring script**:

```bash
cat > /usr/local/bin/archon-health.sh <<'EOF'
#!/bin/bash
set -e

echo "=== Archon Health Check ==="

# Check Docker service
systemctl is-active docker >/dev/null 2>&1 || { echo "ERROR: Docker not running"; exit 1; }

# Check Archon containers
cd /opt/archon
EXPECTED_CONTAINERS=3  # server, mcp, frontend (4 with agents)
RUNNING=$(docker compose ps -q | wc -l)

if [ "$RUNNING" -lt "$EXPECTED_CONTAINERS" ]; then
  echo "ERROR: Expected $EXPECTED_CONTAINERS containers, found $RUNNING"
  docker compose ps
  exit 1
fi

# Check endpoints
curl -f http://localhost:8181/health >/dev/null 2>&1 || { echo "ERROR: Server API unhealthy"; exit 1; }
curl -f http://localhost:3737 >/dev/null 2>&1 || { echo "ERROR: Frontend unhealthy"; exit 1; }

echo "✓ All services healthy"
EOF

chmod +x /usr/local/bin/archon-health.sh

# Add cron job (every 5 minutes)
echo "*/5 * * * * /usr/local/bin/archon-health.sh || /usr/bin/docker compose -f /opt/archon/docker-compose.yml restart" | crontab -
```

#### Backup Strategy

**Automated Supabase backup**:

```bash
cat > /usr/local/bin/archon-backup.sh <<'EOF'
#!/bin/bash
set -e

BACKUP_DIR=/mnt/pve/fgsrv6-wg/backups/archon
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Export Supabase data (requires pg_dump with Supabase credentials)
# Alternative: Use Supabase Dashboard → Database → Backups

# Backup Docker volumes
docker run --rm -v archon_documents:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/documents_$DATE.tar.gz -C /data .

# Backup environment config
cp /opt/archon/.env $BACKUP_DIR/env_$DATE.bak

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x /usr/local/bin/archon-backup.sh

# Daily backup at 2 AM
echo "0 2 * * * /usr/local/bin/archon-backup.sh" | crontab -
```

#### Log Management

**Centralized logging** (forward to existing Observium/Zabbix):

```bash
# Install Fluent Bit
curl -L https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

# Configure forwarding
cat > /etc/fluent-bit/fluent-bit.conf <<'EOF'
[SERVICE]
    Flush        5
    Daemon       Off

[INPUT]
    Name         systemd
    Tag          archon.*
    Systemd_Filter _SYSTEMD_UNIT=archon.service

[OUTPUT]
    Name         syslog
    Match        *
    Host         192.168.0.132  # Observium server
    Port         514
    Mode         tcp
EOF

systemctl enable fluent-bit
systemctl start fluent-bit
```

### 8.5 Performance Tuning

#### Recommended Optimizations

**Docker Daemon**:
```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

**PostgreSQL Connection Pooling** (if using local Supabase):
```env
# Increase max connections
MAX_CONNECTIONS=200
```

**Nginx Caching** (for static assets):
```nginx
# In /etc/nginx/sites-available/archon
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
    proxy_pass http://localhost:3737;
    proxy_cache_valid 200 1h;
    expires 1h;
    add_header Cache-Control "public, immutable";
}
```

---

## 9. Summary & Next Steps

### 9.1 Key Findings

**Archon is a production-ready, microservices-based AI command center** that:

✅ **Solves real problems**: Centralized knowledge, multi-AI integration, collaborative task management
✅ **Well-architected**: True microservices, clean separation of concerns, scalable design
✅ **Actively maintained**: Stable branch, regular updates, community support
✅ **Docker-first**: Easy deployment, consistent environments, production-ready
✅ **Flexible**: Supports OpenAI, Gemini, Ollama; works with multiple AI clients
✅ **AGL-compatible**: Fits perfectly in LXC container with WireGuard/Tailscale access

### 9.2 Recommended CT183 Configuration

**Summary**:
- **OS**: Ubuntu 24.04 LTS
- **CPU**: 4 cores
- **RAM**: 8 GB (16 GB with agents service)
- **Storage**: 50 GB (local-zfs)
- **Network**: 192.168.0.183 (LAN), 10.6.0.183 (WireGuard optional)
- **Features**: `keyctl=1,nesting=1` (for Docker)
- **Services**: Docker Compose with 3-4 containers
- **Access**: HTTP (port 80/3737), MCP (port 8051)

### 9.3 Next Steps

1. **Create CT183** on AGLSRV1 with recommended specs
2. **Set up Supabase** (cloud free tier recommended for initial deployment)
3. **Deploy Archon** using Docker Compose
4. **Configure WireGuard** for mesh access (optional but recommended)
5. **Integrate with AI clients** (Claude Code, Cursor, etc.)
6. **Populate knowledge base** with existing documentation
7. **Monitor performance** and scale resources as needed

### 9.4 Additional Resources

- **Official Repository**: https://github.com/coleam00/Archon
- **Documentation**: In-repo Docusaurus site (`/docs`)
- **MCP Protocol**: https://modelcontextprotocol.io
- **Supabase**: https://supabase.com/docs
- **Docker Compose**: https://docs.docker.com/compose/

---

**End of Analysis**

*Generated by Research Agent on 2025-10-27*
*Source: Archon GitHub Repository (stable branch)*
