# Claude Code Configuration - AGL Infrastructure Management

> **Last Updated**: 2025-10-28 | **Version**: 2.4.0

## 🔖 CRITICAL: Always Read These Documents

**Before any infrastructure or Archon-related task, ALWAYS read:**
- **`docs/INFRA.md`** - Complete infrastructure map, network topology, connection matrix
- **`docs/ARCHON.md`** - Archon AI Command Center integration guide and MCP tools

These documents contain essential context and MUST be consulted for:
- Infrastructure queries (hosts, containers, IPs, networks)
- Connection troubleshooting (WireGuard, Tailscale, LAN)
- Archon MCP integration and usage
- Storage mounts and NFS configuration

---

## 🤖 Archon Integration - QUICK REFERENCE

### ⚡ Current Working Configuration (Updated 2025-10-27)

**CT183 (archon)** - AI Command Center deployed on AGLSRV1:
- **IP (LAN)**: 192.168.0.183
- **IP (WireGuard)**: 10.6.0.21 ✅ **PRIMARY ACCESS**
- **IP (Tailscale)**: 100.80.30.59 ✅ **BACKUP ACCESS**
- **DNS**: archon.aglz.io ✅ **WORKING with Basic Auth**
- **Services**:
  - UI: Port 3737 (React + Vite)
  - API: Port 8181 (FastAPI)
  - MCP: Port 8051 (Docker direct) / Port 8052 (nginx LAN-only)
  - nginx: Port 8080 (public with Basic Auth)

### 🔐 Authentication

**Basic Auth Credentials** (for HTTPS/public access):
- **Username**: admin
- **Password**: ArchonPass2025

### 🌐 Access Methods (3 Options)

#### Option 1: WireGuard Mesh (PRIMARY - External Access)
```bash
# Direct MCP access (no auth required)
claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp

# Web UI (requires Basic Auth)
curl -u admin:ArchonPass2025 http://10.6.0.21:8080
```

#### Option 2: Tailscale VPN (BACKUP - External Access)
```bash
# Direct MCP access (no auth required)
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp

# Web UI (requires Basic Auth)
curl -u admin:ArchonPass2025 http://100.80.30.59:8080
```

#### Option 3: Local LAN (Development Only)
```bash
# MCP without auth (nginx port 8052)
claude mcp add --transport http archon http://192.168.0.183:8052/mcp

# OR direct Docker port 8051
claude mcp add --transport http archon http://192.168.0.183:8051/mcp

# Web UI direct
http://192.168.0.183:3737
```

#### Option 4: Public DNS (HTTPS with Basic Auth)
```
UI:  https://archon.aglz.io (Basic Auth required)
API: https://archon.aglz.io/api
MCP: https://archon.aglz.io/mcp (Basic Auth required)
```

### ✅ Verified Working Configuration

**Claude Code MCP Endpoints** (all 3 connected ✓):
```bash
# LAN (development)
claude mcp add --transport http archon http://192.168.0.183:8052/mcp

# WireGuard (primary external)
claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp

# Tailscale (backup external)
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp
```

**Verification**:
```bash
claude mcp list
# Should show all 3 with ✓ Connected status
```

### 🔧 Network Ports Summary

| Port | Service | Access Level | Auth Required |
|------|---------|--------------|---------------|
| 3737 | Frontend UI | LAN | No (direct) / Yes (via nginx) |
| 8051 | MCP (Docker) | LAN/WG/TS | No |
| 8052 | MCP (nginx) | LAN only | No |
| 8080 | nginx proxy | Public/WG/TS | Yes (Basic Auth) |
| 8181 | FastAPI Backend | Internal | N/A |

### 📋 Available MCP Tools

When connected, Archon provides these tools (prefix: `mcp__archon__` or `mcp__archon-wg__` or `mcp__archon-tailscale__`):

**Knowledge Base**:
- `rag_get_available_sources` - List knowledge sources
- `rag_search_knowledge_base` - Semantic search (keep queries 2-5 keywords!)
- `rag_search_code_examples` - Find code snippets
- `rag_list_pages_for_source` - Browse documentation
- `rag_read_full_page` - Get full page content

**Project Management**:
- `find_projects` - Search/list projects
- `manage_project` - Create/update/delete projects
- `get_project_features` - Get project features list

**Task Management**:
- `find_tasks` - Search/list tasks with filters
- `manage_task` - Create/update/delete tasks (status: todo/doing/review/done)

**Document Management**:
- `find_documents` - Search/list documents
- `manage_document` - Create/update/delete documents

**Version Control**:
- `find_versions` - Version history
- `manage_version` - Create/restore versions

**System**:
- `archon_get_status` - System status
- `health_check` - Health status
- `session_info` - Session information

**Full documentation**: See `docs/ARCHON.md`

### 🚀 Quick Commands

**Service Management**:
```bash
# Check status
ssh root@192.168.0.245 'pct exec 183 -- docker ps'

# View logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp'
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-ui'

# Restart services (use docker compose, not docker-compose!)
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart"'

# Check nginx status
ssh root@192.168.0.245 'pct exec 183 -- systemctl status nginx'

# Restart nginx
ssh root@192.168.0.245 'pct exec 183 -- systemctl restart nginx'
```

**Health Checks**:
```bash
# Test MCP endpoints
curl http://192.168.0.183:8051/mcp  # Direct Docker
curl http://192.168.0.183:8052/mcp  # nginx LAN
curl http://10.6.0.21:8051/mcp      # WireGuard
curl http://100.80.30.59:8051/mcp   # Tailscale

# Test with auth
curl -u admin:ArchonPass2025 https://archon.aglz.io
```

### 🔒 Security Notes

1. **No authentication required** for MCP endpoints on ports 8051/8052 (LAN/VPN trusted)
2. **Basic Auth required** for nginx port 8080 and public HTTPS
3. **WireGuard/Tailscale** provide encrypted transport for MCP access
4. **Cloudflare Tunnel** routes public HTTPS to nginx:8080 with auth

### 📚 Complete Documentation

**ALWAYS READ** `docs/ARCHON.md` for:
- Detailed architecture
- Complete MCP tools reference
- Development guidelines (fail-fast philosophy)
- Troubleshooting guides
- Database operations

---

## 📑 Table of Contents

1. [Archon Integration](#-archon-integration---quick-reference) ⬆️ **YOU ARE HERE**
2. [Project Context](#-project-context)
3. [Quick Start Guide](#-quick-start-guide)
4. [Development Environments](#-development-environments)
5. [Claude Code Rules](#-claude-code-rules)
6. [SPARC Workflow](#-sparc-workflow)
7. [Documentation Structure](#-documentation-structure)

**For detailed infrastructure information, see `docs/INFRA.md`**

---

## 📍 Project Context

**Project**: `agl-hostman` - Infrastructure management and host administration
**Working Directory**: `/root/agl-hostman` (can be on any host with WSL/Linux)
**Repository**: Git-based infrastructure as code

**Key Infrastructure** (see `docs/INFRA.md` for details):
- **AGLSRV1**: Main Proxmox host (192.168.0.245) - 68 containers/VMs
- **AGLSRV6**: Secondary Proxmox host (WG: 10.6.0.12) - Remote
- **CT179**: Primary development container (48GB RAM, Docker)
- **CT183**: Archon AI Command Center (MCP server)
- **WireGuard Mesh**: 14 active nodes (10.6.0.0/24)
- **Tailscale**: Cross-site VPN overlay (100.x.x.x)

---

## 🚀 Quick Start Guide

### Current Environment Detection
```bash
# Detect where you are running
if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then
    echo "WSL2 (AGLHQ11)" # Tailscale only
elif [[ -f /etc/pve/.version ]]; then
    echo "Proxmox Host"
elif [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "Container (CT179/CT108)"
fi
```

### Quick Connection Commands
```bash
# From WSL2 (Tailscale only)
ssh root@100.94.221.87  # CT179 (primary dev)
ssh root@100.107.113.33  # AGLSRV1 host

# From CT179 (Full stack - prefer WireGuard)
ssh root@10.6.0.12  # AGLSRV6 via WireGuard (fastest)
ssh root@192.168.0.245  # AGLSRV1 host via LAN
```

### Essential Infrastructure Commands
```bash
# Check container status
pct list  # On Proxmox host
ssh root@192.168.0.245 'pct list'  # From CT179

# Access storage
ls /mnt/pve/fgsrv6-wg  # NFS via WireGuard
df -h | grep wg  # Show all WireGuard mounts
```

---

## 💻 Development Environments

### 1. AGLHQ11 - Windows 11 + WSL2 (Ubuntu)
- **Tailscale IP**: 100.75.205.122 (eth0)
- **WSL Version**: WSL2 (kernel 6.6.87.2-microsoft-standard-WSL2)
- **Network**: Tailscale only (Windows host manages VPN)
- **Available Tools**: ssh, git, curl (Tailscale via Windows)
- **Connection Method**: SSH via Tailscale to remote hosts
- **Best For**: Remote work, cross-site access, Windows-based development
- **Limitations**: No direct WireGuard (requires Windows host), no local LAN access

### 2. CT179 (agldv03) - AGLSRV1 Development Container
- **Local IP**: 192.168.0.179 (eth0), 192.168.1.179 (eth1)
- **WireGuard**: 10.6.0.19 (wg0, Port 51819)
- **Tailscale**: 100.94.221.87
- **Resources**: 48GB RAM, Docker, full development stack
- **Network**: Triple-stack (LAN + WireGuard + Tailscale)
- **Connection Method**: Direct LAN (192.168.0.x), WireGuard mesh (10.6.0.x), Tailscale (100.x)
- **Best For**: High-performance local ops, WireGuard mesh access, Docker workloads
- **Advantages**: Full network stack, direct Proxmox access, GPU passthrough capable

### 3. CT108 (agldv06) - AGLSRV6 Development Container
- **Tailscale**: 100.71.229.12
- **Network**: Tailscale only
- **Connection Method**: SSH via Tailscale
- **Best For**: AGLSRV6 local operations, distributed development

**Current Environment Detection**:
```bash
# Detect current environment
if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then
    echo "Running on WSL2 (AGLHQ11-like)"
elif [[ -f /etc/pve/.version ]]; then
    echo "Running on Proxmox host"
elif [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "Running in container (CT179/CT108-like)"
else
    echo "Unknown environment"
fi
```

## 🔧 Environment-Specific Tooling Requirements

### WSL2 (AGLHQ11) - Remote Access Profile

**Required Tools**:
- ✅ `ssh` - SSH client (pre-installed)
- ✅ `git` - Version control (pre-installed)
- ✅ `curl` - HTTP client (pre-installed)
- ⚠️ `tailscale` - Managed by Windows host (not in WSL PATH)
- ❌ `wg-quick` - Not available (no kernel module support)
- ❌ `pct` - Not available (not a Proxmox host)

**Network Capabilities**:
- ✅ Tailscale VPN (via Windows host)
- ✅ Internet access
- ❌ WireGuard mesh (kernel limitation)
- ❌ Direct LAN access (NAT'd through Windows)

**Typical Workflow**:
```bash
# Clone project (works from WSL2)
git clone <repo> /root/agl-hostman

# SSH to remote hosts via Tailscale
ssh root@100.94.221.87  # CT179

# Run commands remotely
ssh root@100.94.221.87 'cd /root/agl-hostman && git pull'

# Cannot: Direct WireGuard, pct commands, local LAN access
```

**Recommended Setup**:
```bash
# Install additional tools in WSL2
sudo apt update
sudo apt install -y openssh-client git curl wget jq tmux

# Configure SSH keys for passwordless access
ssh-keygen -t ed25519 -C "wsl2@aglhq11"
ssh-copy-id root@100.94.221.87  # CT179
ssh-copy-id root@100.107.113.33  # AGLSRV1
```

---

### CT179 (agldv03) - Full Stack Development Profile

**Required Tools**:
- ✅ `ssh` - SSH client
- ✅ `git` - Version control
- ✅ `curl` - HTTP client
- ✅ `tailscale` - Tailscale client (installed)
- ✅ `wg-quick` - WireGuard management (installed)
- ✅ `docker` - Container runtime (48GB RAM available)
- ✅ `pct` - Proxmox CLI (via host: `ssh root@192.168.0.245 pct`)

**Network Capabilities**:
- ✅ Tailscale VPN (100.94.221.87)
- ✅ WireGuard mesh (10.6.0.19)
- ✅ Local LAN (192.168.0.179, 192.168.1.179)
- ✅ Internet access (dual interface)
- ✅ Direct Proxmox access (via LAN)

**Typical Workflow**:
```bash
# Full network stack available
ping 192.168.0.245  # LAN (AGLSRV1 host)
ping 10.6.0.12      # WireGuard (AGLSRV6)
ping 100.98.108.66  # Tailscale (AGLSRV6)

# Access storage via WireGuard NFS
ls /mnt/pve/fgsrv6-wg
ls /mnt/pve/ct111-shares

# Run Docker workloads
docker ps
docker compose up -d

# Proxmox commands via host
ssh root@192.168.0.245 'pct list'
ssh root@192.168.0.245 'pvesm status'

# Can do everything: WireGuard, Tailscale, LAN, Docker
```

**Recommended Tools**:
```bash
# Development stack
sudo apt install -y build-essential python3-pip nodejs npm
pip3 install ansible docker-compose

# Monitoring
sudo apt install -y htop iotop nethogs tmux

# Network tools
sudo apt install -y wireguard-tools iproute2 net-tools dnsutils
```

---

### CT108 (agldv06) - Tailscale-Only Profile

**Required Tools**:
- ✅ `ssh` - SSH client
- ✅ `git` - Version control
- ✅ `curl` - HTTP client
- ✅ `tailscale` - Tailscale client (installed)
- ❌ `wg-quick` - Not configured
- ⚠️ `docker` - Status unknown
- ⚠️ `pct` - Via host only (ssh root@10.6.0.12 if WG available on host)

**Network Capabilities**:
- ✅ Tailscale VPN (100.71.229.12)
- ✅ Internet access
- ❌ WireGuard mesh (not configured)
- ⚠️ Local LAN (AGLSRV6 network, limited)

**Typical Workflow**:
```bash
# Tailscale-based access (similar to WSL2)
ssh root@100.94.221.87  # CT179
ssh root@100.107.113.33  # AGLSRV1

# Limited to Tailscale network
# Similar limitations to WSL2 but with better container performance
```

---

## 🎯 Quick Reference: Command Routing by Environment

### Check Infrastructure Status

**From WSL2**:
```bash
# Via Tailscale
ssh root@100.107.113.33 'pct list'  # AGLSRV1 containers
ssh root@100.98.108.66 'pct list'   # AGLSRV6 containers
```

**From CT179**:
```bash
# Direct LAN (fastest)
ssh root@192.168.0.245 'pct list'  # AGLSRV1 containers
ssh root@10.6.0.12 'pct list'      # AGLSRV6 via WireGuard

# Or via Tailscale
ssh root@100.107.113.33 'pct list'
```

### Access NFS Storage

**From WSL2**:
```bash
# Cannot mount directly, must SSH
ssh root@100.94.221.87 'ls /mnt/pve/fgsrv6-wg'
```

**From CT179**:
```bash
# Direct mount points (fastest)
ls /mnt/pve/fgsrv6-wg
ls /mnt/pve/ct111-shares
df -h | grep wg
```

### Run Docker Commands

**From WSL2**:
```bash
# Remote execution only
ssh root@100.94.221.87 'docker ps'
ssh root@100.94.221.87 'cd /root/agl-hostman && docker compose up -d'
```

**From CT179**:
```bash
# Native Docker commands
docker ps
cd /root/agl-hostman && docker compose up -d
docker logs -f <container>
```

## 🚨 CRITICAL: CONCURRENT EXECUTION & FILE MANAGEMENT

**ABSOLUTE RULES**:
1. ALL operations MUST be concurrent/parallel in a single message
2. **NEVER save working files, text/mds and tests to the root folder**
3. ALWAYS organize files in appropriate subdirectories
4. **ALWAYS use Task tool with subagents for complex operations** - NEVER execute complex tasks directly

### ⚡ GOLDEN RULE: "1 MESSAGE = ALL RELATED OPERATIONS"

**MANDATORY PATTERNS:**
- **TodoWrite**: ALWAYS batch ALL todos in ONE call (5-10+ todos minimum)
- **Task tool**: ALWAYS spawn ALL agents in ONE message with full instructions
- **File operations**: ALWAYS batch ALL reads/writes/edits in ONE message
- **Bash commands**: ALWAYS batch ALL terminal operations in ONE message
- **Memory operations**: ALWAYS batch ALL memory store/retrieve in ONE message
- **Parallelism & Subagents**: ALWAYS use parallelism and spawn subagents whenever necessary and/or possible to maximize efficiency and performance

### 📁 File Organization Rules

**NEVER save to root folder. Use these directories:**
- `/src` - Source code files
- `/tests` - Test files
- `/docs` - Documentation and markdown files
- `/config` - Configuration files
- `/scripts` - Utility scripts
- `/examples` - Example code

### 🤖 MANDATORY SUBAGENT USAGE

**CRITICAL: ALWAYS delegate to specialized subagents using the Task tool**

**When to use subagents** (ALWAYS, not optional):
- Code analysis and exploration (use `Explore` agent)
- Research and information gathering (use `researcher` agent)
- Code implementation (use `coder` or `sparc-coder` agent)
- Testing (use `tester` or `tdd-london-swarm` agent)
- Code review (use `code-reviewer` or `reviewer` agent)
- Architecture design (use `architect` or `system-architect` agent)
- Performance analysis (use `perf-analyzer` agent)
- Documentation (use appropriate specialized agent)

**How to use subagents**:
```javascript
// ✅ CORRECT - Delegate to subagent
Task({
  subagent_type: "Explore",
  description: "Find error handling code",
  prompt: "Search the codebase for error handling patterns and document all locations where client errors are caught and processed"
})

// ❌ WRONG - Direct execution
Grep("pattern: error", "path: .")
Read("file.ts")
// Manual analysis...
```

**Benefits**:
- 🎯 Specialized expertise for each task type
- ⚡ Parallel execution (spawn multiple agents concurrently)
- 💾 Reduced token usage (agents work in isolation)
- 📊 Better context management
- 🔄 Reusable agent patterns

**Remember**: If you're tempted to do complex work directly, STOP and spawn a subagent instead.

## Project Overview

This project uses SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology with Claude-Flow orchestration for systematic Test-Driven Development.

## SPARC Commands

### Core Commands
- `npx claude-flow sparc modes` - List available modes
- `npx claude-flow sparc run <mode> "<task>"` - Execute specific mode
- `npx claude-flow sparc tdd "<feature>"` - Run complete TDD workflow
- `npx claude-flow sparc info <mode>` - Get mode details

### Batchtools Commands
- `npx claude-flow sparc batch <modes> "<task>"` - Parallel execution
- `npx claude-flow sparc pipeline "<task>"` - Full pipeline processing
- `npx claude-flow sparc concurrent <mode> "<tasks-file>"` - Multi-task processing

### Build Commands
- `npm run build` - Build project
- `npm run test` - Run tests
- `npm run lint` - Linting
- `npm run typecheck` - Type checking

## SPARC Workflow Phases

1. **Specification** - Requirements analysis (`sparc run spec-pseudocode`)
2. **Pseudocode** - Algorithm design (`sparc run spec-pseudocode`)
3. **Architecture** - System design (`sparc run architect`)
4. **Refinement** - TDD implementation (`sparc tdd`)
5. **Completion** - Integration (`sparc run integration`)

## Code Style & Best Practices

- **Modular Design**: Files under 500 lines
- **Environment Safety**: Never hardcode secrets
- **Test-First**: Write tests before implementation
- **Clean Architecture**: Separate concerns
- **Documentation**: Keep updated

## 🚀 Available Agents (54 Total)

### Core Development
`coder`, `reviewer`, `tester`, `planner`, `researcher`

### Swarm Coordination
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`, `collective-intelligence-coordinator`, `swarm-memory-manager`

### Consensus & Distributed
`byzantine-coordinator`, `raft-manager`, `gossip-coordinator`, `consensus-builder`, `crdt-synchronizer`, `quorum-manager`, `security-manager`

### Performance & Optimization
`perf-analyzer`, `performance-benchmarker`, `task-orchestrator`, `memory-coordinator`, `smart-agent`

### GitHub & Repository
`github-modes`, `pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`, `workflow-automation`, `project-board-sync`, `repo-architect`, `multi-repo-swarm`

### SPARC Methodology
`sparc-coord`, `sparc-coder`, `specification`, `pseudocode`, `architecture`, `refinement`

### Specialized Development
`backend-dev`, `mobile-dev`, `ml-developer`, `cicd-engineer`, `api-docs`, `system-architect`, `code-analyzer`, `base-template-generator`

### Testing & Validation
`tdd-london-swarm`, `production-validator`

### Migration & Planning
`migration-planner`, `swarm-init`

## 🎯 Claude Code vs MCP Tools

### Claude Code Handles ALL:
- File operations (Read, Write, Edit, MultiEdit, Glob, Grep)
- Code generation and programming
- Bash commands and system operations
- Implementation work
- Project navigation and analysis
- TodoWrite and task management
- Git operations
- Package management
- Testing and debugging

### MCP Tools ONLY:
- Coordination and planning
- Memory management
- Neural features
- Performance tracking
- Swarm orchestration
- GitHub integration

**KEY**: MCP coordinates, Claude Code executes.

## 🚀 Quick Setup

```bash
# Add Claude Flow MCP server
claude mcp add claude-flow npx claude-flow@alpha mcp start
```

## MCP Tool Categories

### Coordination
`swarm_init`, `agent_spawn`, `task_orchestrate`

### Monitoring
`swarm_status`, `agent_list`, `agent_metrics`, `task_status`, `task_results`

### Memory & Neural
`memory_usage`, `neural_status`, `neural_train`, `neural_patterns`

### GitHub Integration
`github_swarm`, `repo_analyze`, `pr_enhance`, `issue_triage`, `code_review`

### System
`benchmark_run`, `features_detect`, `swarm_monitor`

## 📋 Agent Coordination Protocol

### Every Agent MUST:

**1️⃣ BEFORE Work:**
```bash
npx claude-flow@alpha hooks pre-task --description "[task]"
npx claude-flow@alpha hooks session-restore --session-id "swarm-[id]"
```

**2️⃣ DURING Work:**
```bash
npx claude-flow@alpha hooks post-edit --file "[file]" --memory-key "swarm/[agent]/[step]"
npx claude-flow@alpha hooks notify --message "[what was done]"
```

**3️⃣ AFTER Work:**
```bash
npx claude-flow@alpha hooks post-task --task-id "[task]"
npx claude-flow@alpha hooks session-end --export-metrics true
```

## 🎯 Concurrent Execution Examples

### ✅ CORRECT (Single Message):
```javascript
[BatchTool]:
  // Initialize swarm
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
  mcp__claude-flow__agent_spawn { type: "researcher" }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "tester" }
  
  // Spawn agents with Task tool
  Task("Research agent: Analyze requirements...")
  Task("Coder agent: Implement features...")
  Task("Tester agent: Create test suite...")
  
  // Batch todos
  TodoWrite { todos: [
    {id: "1", content: "Research", status: "in_progress", priority: "high"},
    {id: "2", content: "Design", status: "pending", priority: "high"},
    {id: "3", content: "Implement", status: "pending", priority: "high"},
    {id: "4", content: "Test", status: "pending", priority: "medium"},
    {id: "5", content: "Document", status: "pending", priority: "low"}
  ]}
  
  // File operations
  Bash "mkdir -p app/{src,tests,docs}"
  Write "app/src/index.js"
  Write "app/tests/index.test.js"
  Write "app/docs/README.md"
```

### ❌ WRONG (Multiple Messages):
```javascript
Message 1: mcp__claude-flow__swarm_init
Message 2: Task("agent 1")
Message 3: TodoWrite { todos: [single todo] }
Message 4: Write "file.js"
// This breaks parallel coordination!
```

## Performance Benefits

- **84.8% SWE-Bench solve rate**
- **32.3% token reduction**
- **2.8-4.4x speed improvement**
- **27+ neural models**

## Hooks Integration

### Pre-Operation
- Auto-assign agents by file type
- Validate commands for safety
- Prepare resources automatically
- Optimize topology by complexity
- Cache searches

### Post-Operation
- Auto-format code
- Train neural patterns
- Update memory
- Analyze performance
- Track token usage

### Session Management
- Generate summaries
- Persist state
- Track metrics
- Restore context
- Export workflows

## Advanced Features (v2.0.0)

- 🚀 Automatic Topology Selection
- ⚡ Parallel Execution (2.8-4.4x speed)
- 🧠 Neural Training
- 📊 Bottleneck Analysis
- 🤖 Smart Auto-Spawning
- 🛡️ Self-Healing Workflows
- 💾 Cross-Session Memory
- 🔗 GitHub Integration

## Integration Tips

1. Start with basic swarm init
2. Scale agents gradually
3. Use memory for context
4. Monitor progress regularly
5. Train patterns from success
6. Enable hooks automation
7. Use GitHub tools first

## Support

- Documentation: https://github.com/ruvnet/claude-flow
- Issues: https://github.com/ruvnet/claude-flow/issues

---

Remember: **Claude Flow coordinates, Claude Code creates!**

## 🏗️ Infrastructure Map

### Network Overview
- **WireGuard Mesh**: 10.6.0.0/24 (Hub: FGSRV6 @ 186.202.57.120:51823)
- **Local Network**: 192.168.0.0/24
- **Tailscale Network**: 100.64.0.0/10

---

### FGSRV6 (Hub) - vps41772
**Aliases**: (fgsrv6, fgsrv06, FGSRV06, FG6, fg6)
**Location**: Cloud VPS (186.202.57.120)
- **Internet**: 186.202.57.120
- **WireGuard**: 10.6.0.5 (Hub - Port 51823)
- **Tailscale**: 100.83.51.9
- **Type**: Proxmox VE Host
- **SSH Config**: FGSRV06
- **Role**: WireGuard mesh hub, NFS server

---

### FGSRV5
**Aliases**: (fgsrv5, fgsrv05, FGSRV05, FG5, fg5)
**Location**: Cloud VPS (191.252.200.20)
- **Internet**: 191.252.200.20
- **WireGuard**: 10.6.0.11 (Port 51811)
- **Tailscale**: 100.71.107.26
- **Type**: Proxmox VE Host
- **SSH Config**: FGSRV05
- **Role**: NFS server, storage backend
- **Notes**: Timeout issues on SSH connection

---

### FGSRV4
**Aliases**: (fgsrv4, fgsrv04, FGSRV04, FG4, fg4)
**Location**: Cloud VPS (vps22826.publiccloud.com.br)
- **WireGuard**: 10.6.0.16 (Port 51816)
- **Tailscale**: 100.111.79.2
- **Type**: Proxmox VE Host
- **SSH Config**: FGSRV04
- **User**: sysadmin

---

### FGSRV3
**Aliases**: (fgsrv3, fgsrv03, FGSRV03, FG3, fg3)
**Location**: Cloud VPS (191.252.201.205)
- **Internet**: 191.252.201.205
- **WireGuard**: 10.6.0.18 (Port 51818)
- **Tailscale**: 100.67.99.115
- **Type**: Proxmox VE Host
- **SSH Config**: FGSRV03

---

### AGLSRV1
**Hostname**: algsrv1 (Proxmox Host)
**Aliases**: (AGLSRV01, aglsrv01, aglsrv1, agl1, AGL1)
- **Local IP**: 192.168.0.245 (host), 192.168.0.179 (CT179 eth0), 192.168.1.179 (CT179 eth1)
- **WireGuard Host**: 10.6.0.10 (Port 51810)
- **WireGuard CT120**: 10.6.0.1 (Port 51820)
- **WireGuard CT179**: 10.6.0.19 (Port 51819)
- **Tailscale**: 100.107.113.33 (algsrv1 host), 100.94.221.87 (CT179 agldv03)
- **Type**: Proxmox VE Host
- **SSH Config**: AGLSRV1 (192.168.0.245)
- **Role**: Main production server, media/dev/monitoring infrastructure
- **Total VMs/CTs**: 68 (42 running, 26 stopped)
- **Primary Dev Container**: CT179 (agldv03) - 48GB RAM, Docker, full development stack

- **Storage Mounts** (Updated 2025-10-16):
  - fgsrv5-wg: NFS → 10.6.0.11:/ (NFSv4.2, WireGuard)
  - fgsrv6-wg: NFS → 10.6.0.5:/ (NFSv4.2, WireGuard)
  - ct111-shares: NFS → 10.6.0.20:/mnt/shares (NFSv4.2, WireGuard) ✅ **NEW**
  - ct111-sistema: NFS → 10.6.0.20:/mnt/sistema (NFSv4.2, WireGuard) ✅ **NEW**
  - aglsrv6-bb: SSHFS → 10.6.0.12:/mnt/pve/bb (WireGuard) ✅ **MIGRATED**
  - aglsrv6-usb4tb: SSHFS → 10.6.0.12:/mnt/usb4tb-direct (WireGuard) ✅ **MIGRATED**

**Key Containers** (Running - 42 total):

| VMID | Name | IP | Tailscale | Purpose |
|------|------|----|-----------| --------|
| 102 | pihole (PIHOLE, pi-hole) | 192.168.0.102 | 100.114.66.80 | DNS/DHCP server |
| 103 | portainer (PORTAINER, port) | 192.168.0.103 | - | Docker management |
| 111 | tautulli (TAUTULLI, tau) | 192.168.0.111 | - | Plex monitoring |
| 112 | bazarr (BAZARR, baz) | 192.168.0.112 | - | Subtitle automation |
| 113 | plexmediaserver (PLEX, plex, plexms) | 192.168.0.113 | - | Media server |
| 117 | cloudflared (CLOUDFLARED, cfd) | 192.168.0.117 | - | Cloudflare tunnel |
| 120 | wireguard (WIREGUARD, wg, wg0) | 192.168.0.120 | - | WireGuard (10.6.0.1) |
| 121 | qbittorrent | 192.168.0.121 | - | Torrent client |
| 122 | jackett | 192.168.0.122 | - | Torrent indexer |
| 123 | radarr | 192.168.0.123 | - | Movie automation |
| 124 | sonarr | 192.168.0.124 | - | TV automation |
| 126 | guac | 192.168.0.126 | - | Guacamole remote |
| 131 | mysql (MYSQL, db) | 192.168.0.131 | - | MySQL database |
| 132 | observium (OBSERVIUM, obs) | 192.168.0.132 | - | Network monitoring |
| 133 | aping (APING, ping) | 192.168.0.133 | - | Network testing |
| 137 | redis (REDIS, cache) | 192.168.0.137 | - | Redis cache |
| 139 | aldsys4 (ALDSYS4, ALDSYS, ald4) | 192.168.0.139 | - | System management |
| 141 | sabnzbd | 192.168.0.141 | - | Usenet client |
| 144 | autobrr | 192.168.0.144 | - | Torrent automation |
| 149 | postgresql (POSTGRESQL, postgres, psql, pg) | 192.168.0.149 | - | PostgreSQL DB |
| 157 | deluge (DELUGE, dlg) | 192.168.0.157 | - | Torrent client |
| 159 | nginxproxy (NGINX, nginx, proxy) | 192.168.0.159 | - | Nginx reverse proxy |
| 161 | gameserver | 192.168.0.161 | - | Game hosting |
| 162 | meshcentral (MESHCENTRAL, mesh, mc) | 192.168.0.162 | - | Remote management |
| 163 | gameserver2 | 192.168.0.163 | - | Game hosting |
| 165 | aria2 | 192.168.0.165 | - | Download manager |
| 170 | homarr | 192.168.0.170 | - | Dashboard |
| 171 | overseerr | 192.168.0.171 | - | Media requests |
| 172 | prowlarr | 192.168.0.172 | - | Indexer manager |
| 173 | cacheng | 192.168.0.173 | - | Cache engine |
| 176 | iventoy | 192.168.0.176 | - | Network boot |
| 178 | aglfs1 (AGLFS1, aglfs) | 192.168.0.178 | - | File server |
| 179 | agldv03 (AGLDV03, AGLDV3, agldv3) | 192.168.0.179 | 100.94.221.87 | Dev env (10.6.0.19) |
| 180 | dokploy (DOKPLOY, dok, dply) | 192.168.0.180 | - | Deployment platform |
| 183 | archon (ARCHON, arch) | 192.168.0.183 | - | AI Command Center, MCP Server |
| 200 | ollama-gpu (OLLAMA, ollama, llm) | 192.168.0.200 | 100.116.57.111 | LLM GPU compute |
| 201 | amp-server (AMP, amp) | 192.168.0.201 | - | AMP game panel |
| 202 | n8n-docker (N8N, n8n, workflow) | 192.168.0.202 | - | Workflow automation |

**Stopped Containers** (3):
- 167: az-agent1 (Azure DevOps agent)
- 168: az-agent2 (Azure DevOps agent)
- 169: az-agent3 (Azure DevOps agent)
- 174: agldv02 (AGLDV02, AGLDV2, agldv2) (Development - 48GB RAM)

**Key Virtual Machines** (Running - 4 total):

| VMID | Name | RAM | Disk | Tailscale | Purpose |
|------|------|-----|------|-----------|---------|
| 104 | aglwk45 (AGLWK45, AGL45, agl45) | 16GB | 720GB | - | Workstation |
| 138 | haos | 8GB | 32GB | 100.105.133.18 | Home Assistant |
| 148 | zabbix | 4GB | 10GB | - | Monitoring |
| 150 | wazuh-app | 16GB | 50GB | - | Security monitoring |

**Stopped VMs** (22):
- 100: aglsrv2 (4GB, 0GB) - Secondary server
- 101: openwrt (2GB, 0.5GB) - Router OS
- 105: opnsense (16GB, 40GB) - Firewall
- 106: pfsense (8GB, 40GB) - Firewall
- 114: UbuntuDesktop (16GB, 240GB) - Desktop
- 115: aglw7 (4GB, 240GB) - Workstation
- 116: aglwk46 (16GB, 240GB) - Workstation
- 125: AGLMAC06 (16GB, 0GB) - macOS
- 128: plex (8GB, 120GB) - Media server (duplicate)
- 135-136: aglwk48/49 - Workstations
- 142: aglws1 (16GB, 240GB) - Windows server
- 145: android-x86 (4GB, 256GB) - Android VM
- 146: bliss (8GB, 240GB) - Android VM
- 147: agldv01 (AGLDV01, AGLDV1, agldv1) (32GB, 240GB) - Development
- 151-156: test-k3s-* (4GB each) - Kubernetes cluster
- 300: nobara-gaming (16GB, 128GB) - Gaming VM

---

### AGLSRV6
**Hostname**: AGLSRV6 (formerly man6)
**Aliases**: (aglsrv6, agl6, AGL6, man6, AGLSRV06, aglsrv06)
- **Local IP**: Unknown (behind Tailscale/WireGuard)
- **WireGuard Host**: 10.6.0.12 (Port 51812) ✅ **ACTIVE** - Updated 2025-10-16
- **Tailscale**: 100.98.108.66 (fallback)
- **Type**: Proxmox VE Host
- **SSH Config**: Prefer 10.6.0.12 (WireGuard), fallback 100.98.108.66 (Tailscale)
- **SSH Key**: AGLSRV1 key added to authorized_keys on 2025-10-16
- **Role**: Container host, storage server, SSHFS source

**Containers**:
| VMID | Name | WireGuard IP | Tailscale IP | Purpose |
|------|------|--------------|--------------|---------|
| 101 | cloudflared6 | - | 100.120.181.108 | Cloudflare tunnel |
| 102 | meshcentral6 | - | - | Remote management |
| 104 | luzdivina | - | - | - |
| 107 | kuber601 | - | - | Kubernetes (stopped) |
| 108 | agldv06 (AGLDV06, AGLDV6, agldv6) | - | 100.71.229.12 | Development |
| 109 | redis6 | - | - | Redis server |
| 110 | mssql6 | - | - | SQL Server |
| 111 | aluzdivina (ALUZDIVINA, aluzdiv) | 10.6.0.20 | 100.65.189.83 | Storage server |
| 113 | pbs | 10.6.0.14 | 100.70.155.60 | PBS backup |
| 114 | cloudflared6b | - | - | Cloudflare tunnel |
| 121 | wireguard | 10.6.0.3 | - | WireGuard node |

**VMs**:
| VMID | Name | Status | RAM | Disk | Purpose |
|------|------|--------|-----|------|---------|
| 100 | SSPADLD01 | stopped | 16GB | 930GB | SharePoint |
| 103 | opnsense | stopped | 8GB | 40GB | Firewall |
| 105 | aglhq26 | running | 8GB | - | - |
| 106 | UbuntuDesktop | stopped | 4GB | 240GB | Desktop |
| 112 | dell-ome | stopped | 8GB | 415GB | Dell OpenManage |
| 200 | WinServer2016-VirtIO | running | 16GB | 500GB | Windows Server |

**CT111 (aluzdivina) Details**:
- **NFS Server**: ✅ Active and accessible via WireGuard mesh
- **WireGuard**: 10.6.0.20 ✅ **FIXED** - Public key updated on hub 2025-10-16
- **WireGuard Status**: Full mesh connectivity (15-22ms latency to hub)
- **Storage**:
  - /mnt/shares (66GB XFS) - NFS exported
  - /mnt/sistema (819GB ZFS) - NFS exported
  - /mnt/bb (CIFS from 192.168.0.203)
  - /mnt/bkp (3.9TB ExFAT)
- **NFS Exports**: /mnt/shares, /mnt/sistema (192.168.0.0/24, 10.6.0.0/24)
- **Mounted on AGLSRV1**: ct111-shares (66GB), ct111-sistema (818GB) via WireGuard

---

### AGLSRV6B
**Hostname**: AGLSRV6B (formerly man6b)
**Aliases**: (aglsrv6b, agl6b, AGL6B, man6b)
- **WireGuard**: 10.6.0.13 (Port 51813)
- **Tailscale**: 100.98.119.51
- **Type**: Proxmox VE Host

**Containers**:
| VMID | Name | WireGuard IP | Purpose |
|------|------|--------------|---------|
| 172 | pbs | 10.6.0.15 | PBS backup |

---

### AGLSRV5
**Aliases**: (aglsrv5, agl5, AGL5)
**WireGuard**: 10.6.0.17 (Port 51817)
**Tailscale**: 100.119.223.113
**Type**: Proxmox VE Host

---

### Other Tailscale Devices

**AGLSRV1 Containers/VMs on Tailscale**:
- CT102 (pihole): 100.114.66.80 → 192.168.0.102 - DNS/DHCP server
- CT120 (wireguard): WireGuard 10.6.0.1 (no Tailscale) - WG mesh node
- CT138 (haos): 100.105.133.18 → 192.168.0.138 - Home Assistant OS
- **CT179 (agldv03)**: 100.94.221.87 → 192.168.0.179 - **Primary Development** (WG 10.6.0.19, 48GB RAM)
- CT200 (ollama-gpu): 100.116.57.111 → 192.168.0.200 - LLM GPU compute

**AGLSRV6 Development Containers**:
- **CT108 (agldv06)**: 100.71.229.12 - Development container (Tailscale only)

**Other Network Nodes**:
- aglsrv5-agldv05: 100.119.41.63 - Development
- aglsrv5-mesh5: 100.82.254.91 - Mesh node

**Workstations**:
- **AGLHQ11**: 100.75.205.122 (Windows 11, WSL2) - **Current Host for Remote Work**
- AGLWK45: 100.117.146.21 - Local workstation
- AGLWK06: f.aguileraz.net:6022
- AGLWK07: man.aguileraz.net:8122

**Mobile Devices**:
- aglcel10: 100.80.84.69 (Android, offline)
- aglmac07: 100.102.187.120 (Windows, offline)
- aglmac08: 100.111.113.102 (macOS)
- aglhq11: 100.75.205.122 (Windows - also listed above)

**Cloud Servers**:
- AGLSRV3: 100.123.5.81 (offline)
- YAPMan: deploy0.yapoli.io (AWS SA-East-1, Ubuntu)
- AGLLX51: ec2-54-81-231-106.compute-1.amazonaws.com (AWS US-East-1)

---

### WireGuard Mesh Status (13 Active Nodes)

**Active Peers**:
| Node | IP | Port | Type | Status |
|------|-----|------|------|--------|
| FGSRV6 | 10.6.0.5 | 51823 | Hub | ✅ |
| CT120 | 10.6.0.1 | 51820 | Container | ✅ |
| CT121 | 10.6.0.3 | 51821 | Container | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Host | ✅ |
| AGLSRV6(Host) | 10.6.0.12 | 51812 | Host | ✅ **ACTIVE** |
| AGLSRV6B(Host) | 10.6.0.13 | 51813 | Host | ✅ |
| CT113 | 10.6.0.14 | 51814 | Container | ✅ |
| CT172 | 10.6.0.15 | 51815 | Container | ✅ |
| FGSRV4 | 10.6.0.16 | 51816 | Host | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Host | ✅ |
| CT179 | 10.6.0.19 | 51819 | Container | ✅ |
| CT111 | 10.6.0.20 | 51820 | Container | ✅ **FIXED** |

**Pending**:
- FGSRV5 Container: 10.6.0.4 (Port 51822)

---

### Storage Configuration

**AGLSRV1 Proxmox Storages** (Updated 2025-10-16):
- **local**: 77GB (local disk)
- **local-zfs**: 1.7TB (ZFS pool)
- **fgsrv5-wg**: 77GB via NFS/WireGuard (10.6.0.11)
- **fgsrv6-wg**: 197GB via NFS/WireGuard (10.6.0.5)
- **ct111-shares**: 66GB via NFS/WireGuard (10.6.0.20) ✅ **NEW**
- **ct111-sistema**: 818GB via NFS/WireGuard (10.6.0.20) ✅ **NEW**
- **man6-bb**: 954GB via SSHFS/WireGuard (10.6.0.12) ✅ **MIGRATED**
- **man6-usb4tb**: 3.9TB via SSHFS/WireGuard (10.6.0.12) ✅ **MIGRATED**
- **aglsrv6-pbs**: 1.2TB PBS backup storage
- **aglsrv6b-pbs**: 1.0TB PBS backup storage
- **spark**: 7.1TB (91.54% used) - Backup storage
- **overpower**: 9.8TB (92.54% used) - Backup storage

**Total WireGuard Storage**: 6.0 TB (1.2TB NFS + 4.8TB SSHFS)

**Mount Points**:
- `/mnt/pve/fgsrv5-wg`: NFS4.2 from 10.6.0.11 via WireGuard
- `/mnt/pve/fgsrv6-wg`: NFS4.2 from 10.6.0.5 via WireGuard
- `/mnt/pve/ct111-shares`: NFS4.2 from 10.6.0.20 via WireGuard ✅
- `/mnt/pve/ct111-sistema`: NFS4.2 from 10.6.0.20 via WireGuard ✅
- `/mnt/pve/aglsrv6-bb`: SSHFS from 10.6.0.12 via WireGuard ✅
- `/mnt/pve/aglsrv6-usb4tb`: SSHFS from 10.6.0.12 via WireGuard ✅

---

### Docker Containers

**AGLSRV1 Containers with Docker** (Updated 2025-10-18):

| VMID | Name | Purpose | Docker Networks |
|------|------|---------|-----------------|
| 103 | portainer | Docker management | - |
| 133 | aping | Network testing | - |
| 139 | aldsys4 | System management | - |
| 161 | gameserver | Game hosting | - |
| 163 | gameserver2 | Game hosting | - |
| 179 | agldv03 | Development | Multiple bridge networks |
| 180 | dokploy | Deployment platform | - |
| 200 | ollama-gpu | LLM GPU compute | - |
| 202 | n8n-docker | Workflow automation | - |

**Notes**:
- Docker not detected on AGLSRV6 or AGLSRV6B hosts
- Total containers with Docker on AGLSRV1: 9
- CT179 (agldv03) has the most complex Docker setup with multiple bridge networks

---

### Migration Status

**Completed** (Updated 2025-10-16):
- ✅ FGSRV6 NFS migrated from Tailscale to WireGuard (87.5% performance improvement)
- ✅ Storage renamed from -nfs to -wg naming convention
- ✅ 14 nodes active on WireGuard mesh (including CT111)
- ✅ Backup retention policy optimized (freed 650GB on spark)
- ✅ AGLSRV6 host WireGuard confirmed active (10.6.0.12) - 2025-10-16
- ✅ CT111 WireGuard fixed (public key updated on hub) - 2025-10-16
- ✅ CT111 NFS accessible via WireGuard mesh - 2025-10-16
- ✅ SSHFS migrated from Tailscale to WireGuard (2-3x performance gain) - 2025-10-16
- ✅ All storage now using WireGuard mesh (6.0 TB total) - 2025-10-16

**Performance Improvements**:
- SSHFS: 6-8 MB/s (Tailscale) → 15-20 MB/s (WireGuard estimated)
- NFS: Already optimized on WireGuard (1.7 GB/s on fgsrv5-wg)
- Total WireGuard storage: 6.0 TB (1.2TB NFS + 4.8TB SSHFS)

**Pending**:
- ⏳ CT111 NFS performance benchmarking
- ⏳ aglsrv6-bb/aglsrv6-usb4tb real-world speed testing

---

### 🔐 Connection Priority Rules

**CRITICAL: Connection strategy varies by source environment**

## Connection Matrix by Source Environment

### From AGLHQ11 (WSL2) - Tailscale Only

**Available Networks**: Tailscale (100.x.x.x) only
**Not Available**: WireGuard (no kernel module), Local LAN (192.168.0.x)

**Connection Priority**:
1. **Tailscale Direct** (Primary): `ssh root@100.x.x.x`
   - Example: `ssh root@100.98.108.66` (AGLSRV6)
   - Example: `ssh root@100.94.221.87` (CT179/agldv03)

2. **SSH via Tailscale to LAN** (Alternative): Chain through Tailscale host
   - Example: `ssh -J root@100.107.113.33 root@192.168.0.179` (AGLSRV1 → CT179)

3. **Cannot Use**: WireGuard mesh, direct LAN access

**Typical Commands from WSL2**:
```bash
# Connect to AGLSRV1 host
ssh root@100.107.113.33

# Connect to CT179 development
ssh root@100.94.221.87

# Connect to AGLSRV6 host
ssh root@100.98.108.66

# Jump through host to reach LAN-only container
ssh -J root@100.107.113.33 root@192.168.0.202  # n8n via AGLSRV1
```

---

### From CT179 (agldv03) - Triple Network Stack

**Available Networks**: LAN (192.168.0.x), WireGuard (10.6.0.x), Tailscale (100.x.x.x)
**Network Interfaces**: eth0 (LAN), wg0 (WireGuard), tailscale0

**Connection Priority**:
1. **WireGuard Mesh** (Best Performance): `ssh root@10.6.0.x`
   - Kernel-level, lowest latency (~15-20ms)
   - Direct mesh routing
   - Example: `ssh root@10.6.0.12` (AGLSRV6)
   - Example: `ssh root@10.6.0.5` (FGSRV6)

2. **Local LAN** (Same Network): `ssh root@192.168.0.x`
   - Zero latency for same subnet
   - Direct access to all AGLSRV1 containers
   - Example: `ssh root@192.168.0.202` (n8n)
   - Example: `pct enter 202` (direct console from host)

3. **Tailscale** (Cross-Network): `ssh root@100.x.x.x`
   - For hosts without WireGuard
   - Cross-site access
   - Example: `ssh root@100.71.229.12` (CT108/agldv06)

4. **Proxmox Direct** (Host Access): Via AGLSRV1 host (192.168.0.245)
   - Example: `ssh root@192.168.0.245 'pct enter 202'`

**Typical Commands from CT179**:
```bash
# Access AGLSRV6 via WireGuard (fastest)
ssh root@10.6.0.12

# Access other AGLSRV1 containers via LAN
ssh root@192.168.0.202  # n8n
ssh root@192.168.0.200  # ollama-gpu

# Access FGSRV6 storage via WireGuard
ls /mnt/pve/fgsrv6-wg

# Access CT108 (no WireGuard) via Tailscale
ssh root@100.71.229.12

# Direct Proxmox commands (on AGLSRV1 host)
pct enter 202
pvesm status
```

---

### From CT108 (agldv06) - Tailscale Only

**Available Networks**: Tailscale (100.x.x.x) only
**Not Available**: WireGuard (not configured), Local LAN (different network)

**Connection Priority**:
1. **Tailscale Direct** (Primary): `ssh root@100.x.x.x`
   - Same as WSL2 behavior
   - Example: `ssh root@100.94.221.87` (CT179)

2. **Local Proxmox** (AGLSRV6 only): Via AGLSRV6 host
   - Example: `ssh root@10.6.0.12 'pct enter 111'` (if WireGuard available on host)

---

### Universal Connection Patterns

**To reach any infrastructure target**:

| Target Type | From WSL2 (AGLHQ11) | From CT179 (agldv03) | From CT108 (agldv06) |
|-------------|---------------------|----------------------|----------------------|
| AGLSRV1 Host | 100.107.113.33 | 192.168.0.245 or 10.6.0.10 | 100.107.113.33 |
| AGLSRV1 CTs | 100.x (if has TS) | 192.168.0.x (direct) | 100.x (if has TS) |
| AGLSRV6 Host | 100.98.108.66 | 10.6.0.12 (WG best) | 10.6.0.12 or 100.98.108.66 |
| FGSRV6 Host | 100.83.51.9 | 10.6.0.5 (WG best) | 100.83.51.9 |
| Cloud VPS | 186.202.57.120 | 10.6.0.5 (WG) or public | 186.202.57.120 |

**Connection Examples by Environment**:
```bash
# From WSL2: Tailscale only
ssh root@100.98.108.66 'hostname'  # AGLSRV6

# From CT179: WireGuard preferred
ssh root@10.6.0.12 'hostname'  # AGLSRV6 (fastest)
ssh root@192.168.0.202 'hostname'  # n8n (LAN)

# From CT108: Tailscale only
ssh root@100.94.221.87 'hostname'  # CT179
```

---

## ⚙️ WireGuard Configuration Standards

**CRITICAL: Mandatory configuration for all WireGuard clients (containers/hosts)**

### ✅ CORRECT Configuration (Containers - No PresharedKey)

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24  ← CRITICAL: Only mesh network
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

### ✅ CORRECT Configuration (Proxmox Hosts - With PresharedKey)

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
PresharedKey = DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=  ← OK on hosts only
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

### ❌ Common Configuration Errors

| Error | Impact | Fix |
|-------|--------|-----|
| `PresharedKey` in LXC containers | Handshake never establishes | Remove PresharedKey line |
| `AllowedIPs = 0.0.0.0/0` | Routes ALL traffic through tunnel, breaks local network | Change to `10.6.0.0/24` |
| Missing `keyctl=1,nesting=1` in LXC config | WireGuard fails to start | Add to `/etc/pve/lxc/XXX.conf` |

### LXC Container Requirements

```ini
# Required in /etc/pve/lxc/XXX.conf
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### Quick Validation & Fix

```bash
# Validate configuration
pct exec <VMID> -- grep "PresharedKey\|AllowedIPs" /etc/wireguard/wg0.conf

# Fix incorrect config (automated)
pct exec <VMID> -- cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup
pct exec <VMID> -- sed -i '/^PresharedKey =/d' /etc/wireguard/wg0.conf
pct exec <VMID> -- sed -i 's/^AllowedIPs = 0\.0\.0\.0\/0/AllowedIPs = 10.6.0.0\/24/' /etc/wireguard/wg0.conf
pct exec <VMID> -- wg-quick down wg0 && sleep 2 && pct exec <VMID> -- wg-quick up wg0

# Verify connectivity
pct exec <VMID> -- wg show && pct exec <VMID> -- ping -c 2 10.6.0.5
```

---

## 📝 Documentation Maintenance

### Update Policy

**MANDATORY**: Update this document when:
- New hosts/containers are deployed
- Network configuration changes (IPs, WireGuard peers)
- SSH keys are added/rotated
- Storage mounts are modified
- Critical issues are resolved

### Git Commit Guidelines

```bash
# Commit infrastructure documentation changes
git add CLAUDE.md
git commit -m "docs: [brief description]

- Change 1
- Change 2
- Impact/benefit"

# Example
git commit -m "docs: add CT180 WireGuard configuration

- Added CT180 to WireGuard mesh (10.6.0.21)
- Updated connection matrix
- Performance: 15ms latency to hub"
```

---

## 🔧 Troubleshooting

### Common Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| WireGuard handshake fails | `wg show` shows timestamp=0 | Check PresharedKey (remove in LXC), verify AllowedIPs |
| Container network unreachable | Cannot ping local network | Check AllowedIPs (should be `10.6.0.0/24`, not `0.0.0.0/0`) |
| SSH connection refused | Connection timeout | Verify Tailscale/WireGuard status, check firewall |
| NFS mount stale | `ls` hangs on mount | Remount: `umount -f /mnt/pve/<storage> && mount -a` |

### Diagnostic Commands

```bash
# Check WireGuard status
wg show  # Shows peers, handshake, transfer
ip route | grep wg  # Verify routing

# Test connectivity
ping 10.6.0.5  # Hub
ping 8.8.8.8  # Internet

# Check NFS mounts
df -h | grep wg  # Show WireGuard NFS mounts
showmount -e 10.6.0.5  # Check exports on FGSRV6
```

---

## 🔗 Quick Reference Links

### SSH Configuration Aliases
- **AGLSRV1**: 192.168.0.245 | **AGLSRV6**: 10.6.0.12 (WG) / 100.98.108.66 (TS)
- **CT179**: 192.168.0.179 (LAN) / 10.6.0.19 (WG) / 100.94.221.87 (TS)
- **FGSRV6**: 186.202.57.120 (Public) / 10.6.0.5 (WG) / 100.83.51.9 (TS)
- **Full list**: See [Infrastructure Map](#-infrastructure-map)

### Key Storage Mounts
- `/mnt/pve/fgsrv6-wg` - 197GB NFS via WireGuard
- `/mnt/pve/ct111-shares` - 66GB NFS via WireGuard
- `/mnt/pve/aglsrv6-bb` - 954GB SSHFS via WireGuard
- `/mnt/pve/aglsrv6-usb4tb` - 3.9TB SSHFS via WireGuard
- sempre verifique em qual host estamos antes de tentar se conectar em outros hosts
---

## 📚 Documentation Structure

### Core Documents

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **CLAUDE.md** | Main configuration, rules, workflows | Always (this file) |
| **docs/INFRA.md** | Infrastructure map, networks, containers | Infrastructure queries |
| **docs/ARCHON.md** | Archon integration, MCP tools, guidelines | Archon-related tasks |
| **docs/QUICK-START.md** | Fast reference for common tasks | Quick lookups |

### Specialized Documentation

| Document | Purpose |
|----------|---------|
| `docs/archon-integration.md` | Original Archon deployment notes |
| `docs/docker-in-lxc-apparmor-solution.md` | Docker BuildKit troubleshooting |
| `docs/ct183-deployment-guide.md` | CT183 setup (to be created) |

### Documentation Rules

**ALWAYS read before starting:**
1. **Infrastructure tasks** → Read `docs/INFRA.md`
2. **Archon tasks** → Read `docs/ARCHON.md`
3. **Quick commands** → Read `docs/QUICK-START.md`
4. **Development rules** → This file (CLAUDE.md)

**Update policy**:
- Document changes immediately after implementation
- Use git commits with clear messages
- Keep version numbers and dates current
- Cross-reference related documents

---

## 🎯 Next Steps

### Immediate Tasks
- [ ] Test Archon MCP connection from CT179
- [ ] Verify DNS access (archon.aglz.io)
- [ ] Configure Tailscale on CT183 for remote access
- [ ] Create CT183 deployment guide

### Documentation
- [x] Create INFRA.md with infrastructure map
- [x] Create ARCHON.md with Archon guide
- [x] Create QUICK-START.md for fast reference
- [x] Optimize CLAUDE.md with document references
- [ ] Create CT183 deployment guide
- [ ] Update infrastructure diagrams

### Integration
- [ ] Integrate Archon error handling patterns
- [ ] Apply Archon code quality standards
- [ ] Test all Archon MCP tools
- [ ] Document Archon workflows

---

**Document Version**: 2.4.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (agl-hostman project)
**Always Read**: `docs/INFRA.md` and `docs/ARCHON.md` for context
