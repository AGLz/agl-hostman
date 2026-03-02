# Claude Code Configuration - AGL Infrastructure Management

> **Last Updated**: 2026-02-22 | **Version**: 3.0.1

## 🔖 CRITICAL: Always Read These Documents

**Before any infrastructure or Archon-related task, ALWAYS read:**
- **`docs/INFRA.md`** - Complete infrastructure map, network topology, connection matrix
- **`docs/ARCHON.md`** - Archon AI Command Center integration guide and MCP tools
- **`docs/WORKFLOWS.md`** - SPARC methodology, Agent OS integration, development workflows
- **`docs/RULES.md`** - Coding standards, execution patterns, best practices
- **`docs/QUICK-START.md`** - Fast reference for commands, connections, troubleshooting

**How to load on-demand**: Use `@docs/filename.md` syntax to load only when needed.

---

## 📚 Document Navigation - When to Read Which Document

### Primary Documents (Load First)

**1. `docs/INFRA.md` - Infrastructure Map**
- **Read When**: Infrastructure queries, connection issues, checking container status
- **Contains**:
  - Complete host/container inventory with IPs (AGLSRV1, AGLSRV6, FGSRV6)
  - Network topology (WireGuard mesh, Tailscale, LAN)
  - Connection priority matrix by environment (WSL2, CT179, CT108)
  - Storage configuration (NFS, SSHFS, mount points)
  - WireGuard configuration standards
- **Example Queries**: "What's the IP for CT179?", "How to connect to AGLSRV6?", "Where is NFS storage mounted?"

**2. `docs/ARCHON.md` - Archon Integration**
- **Read When**: Using MCP tools, task management, knowledge base operations
- **Contains**:
  - Complete MCP tools reference (28 tools available)
  - Archon deployment architecture (CT183 configuration)
  - Development guidelines (fail-fast philosophy)
  - RAG knowledge base usage
  - Project and task management workflows
- **Example Queries**: "How to search Archon knowledge base?", "How to create Archon project?", "What MCP tools are available?"

**3. `docs/WORKFLOWS.md` - Development Workflows**
- **Read When**: Following SPARC methodology, using Agent OS, understanding available agents
- **Contains**:
  - Agent OS integration (7 commands, 16 Skills, 4 workflows)
  - SPARC methodology (5 phases: Specification, Pseudocode, Architecture, Refinement, Completion)
  - Available agents (54 total) organized by category
  - MCP tool categories and agent coordination protocol
  - Infrastructure workflows and best practices
- **Example Queries**: "How to use Agent OS?", "What are SPARC phases?", "Which agents are available?", "How to run infrastructure workflows?"

**4. `docs/RULES.md` - Coding Standards**
- **Read When**: Before implementing code, debugging issues, checking execution patterns
- **Contains**:
  - CRITICAL execution rules (concurrent operations, file organization)
  - Mandatory subagent usage patterns
  - Claude Code vs MCP tools division
  - Concurrent execution examples
  - Code quality standards and best practices
- **Example Queries**: "What are the mandatory patterns?", "When to use subagents?", "What are file organization rules?"

**5. `docs/QUICK-START.md` - Fast Reference**
- **Read When**: Need quick commands, connection troubleshooting, common operations
- **Contains**:
  - Environment detection scripts
  - Quick connection commands by source (WSL2, CT179, CT108)
  - SSH commands, storage access, Docker operations
  - Archon quick commands (MCP setup, health checks)
  - Troubleshooting guide with common issues table
- **Example Queries**: "How to SSH from WSL2?", "How to access NFS storage?", "How to restart Archon?", "Quick troubleshooting?"

---

## 📍 Project Context

**Project**: `agl-hostman` - Infrastructure management and host administration
**Working Directory**: `/root/agl-hostman` (can be on any host with WSL/Linux)
**Repository**: Git-based infrastructure as code

**Key Infrastructure** (see `@docs/INFRA.md` for complete details):
- **AGLSRV1**: Main Proxmox host (192.168.0.245) - 68 containers/VMs
- **AGLSRV6**: Secondary Proxmox host (WG: 10.6.0.12) - Remote operations
- **CT179**: Primary development container (48GB RAM, Docker, triple network stack)
- **CT183**: Archon AI Command Center (MCP server, task management, RAG)
- **WireGuard Mesh**: 14 active nodes (10.6.0.0/24) - Primary network
- **Tailscale**: Cross-site VPN overlay (100.x.x.x) - Backup network

**Network Priority**: WireGuard (fastest) > LAN (local) > Tailscale (fallback)

---

## 🤖 Archon Integration - Quick Summary

**CT183 (Archon)** - AI Command Center deployed on AGLSRV1:
- **Primary Access**: WireGuard (10.6.0.21) → `claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp`
- **Backup Access**: Tailscale (100.80.30.59) → `claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp`
- **LAN Access** (dev only): 192.168.0.183 → `claude mcp add --transport http archon http://192.168.0.183:8052/mcp`
- **Public DNS**: https://archon.aglz.io (Basic Auth: admin/ArchonPass2025)

**Available MCP Tools** (28 total):
- **Knowledge Base**: `rag_search_knowledge_base`, `rag_search_code_examples`, `rag_read_full_page`
- **Project Management**: `find_projects`, `manage_project`, `get_project_features`
- **Task Management**: `find_tasks`, `manage_task` (status: todo/doing/review/done)
- **Document Management**: `find_documents`, `manage_document`
- **System**: `health_check`, `session_info`, `archon_get_status`

**Verification**:
```bash
claude mcp list  # Should show all 3 endpoints connected
```

**Complete Documentation**: See `@docs/ARCHON.md` for full MCP tools reference, architecture, development guidelines, and troubleshooting.

---

## 🚨 CRITICAL RULES - Quick Reference

**ABSOLUTE REQUIREMENTS**:
1. ✅ **Concurrent Execution**: ALL related operations in ONE message (TodoWrite, Task tool, File operations, Bash commands)
2. ✅ **File Organization**: NEVER save to root folder (use `/src`, `/tests`, `/docs`, `/config`, `/scripts`, `/examples`)
3. ✅ **Mandatory Subagents**: ALWAYS use Task tool for complex operations (Explore, researcher, coder, tester, reviewer, architect)
4. ✅ **Documentation Loading**: Use `@docs/filename.md` syntax for on-demand loading

**Golden Rule**: "1 MESSAGE = ALL RELATED OPERATIONS"

**Example - Correct Batching**:
```javascript
[BatchTool]:
  // Spawn multiple agents in parallel
  Task("Research agent: Analyze requirements...")
  Task("Coder agent: Implement features...")
  Task("Tester agent: Create test suite...")

  // Batch all todos in ONE call
  TodoWrite { todos: [
    {content: "Research", status: "in_progress"},
    {content: "Design", status: "pending"},
    {content: "Implement", status: "pending"},
    {content: "Test", status: "pending"},
    {content: "Document", status: "pending"}
  ]}

  // Batch file operations
  Bash "mkdir -p app/{src,tests,docs}"
  Write "app/src/index.js"
  Write "app/tests/index.test.js"
  Write "app/docs/README.md"
```

**Complete Rules**: See `@docs/RULES.md` for execution patterns, code quality standards, error handling, Git workflow, and best practices.

---

## 🎯 Workflows & Methodologies

**Agent OS Integration** (Spec-Driven Development):
- **6 Slash Commands**: `/create-tasks`, `/implement-tasks`, `/shape-spec`, `/write-spec`, `/plan-product`, `/improve-skills`
- **16 Skills**: Auto-apply standards (backend, frontend, global, infrastructure, testing)
- **4 Infrastructure Workflows**: WireGuard setup, NFS mounts, container deployment, Archon integration

**SPARC Methodology** (Test-Driven Development):
1. **Specification** - Requirements analysis
2. **Pseudocode** - Algorithm design
3. **Architecture** - System design
4. **Refinement** - TDD implementation
5. **Completion** - Integration and validation

**Available Agents** (54 total):
- **Core**: coder, reviewer, tester, planner, researcher
- **Swarm**: hierarchical-coordinator, mesh-coordinator, adaptive-coordinator
- **Performance**: perf-analyzer, performance-benchmarker, task-orchestrator
- **GitHub**: pr-manager, code-review-swarm, issue-tracker, workflow-automation
- **SPARC**: sparc-coord, sparc-coder, specification, pseudocode, architecture, refinement

**Complete Details**: See `@docs/WORKFLOWS.md` for full command reference, workflows, and agent catalog.

---

## 🚀 Quick Operations

### Environment Detection
```bash
# Detect where you are running
if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then
    echo "WSL2 (Tailscale only)"
elif [[ -f /.dockerenv ]]; then
    echo "Container (CT179/CT108)"
fi
```

### Quick Connections
```bash
# From WSL2 (Tailscale only)
ssh root@100.94.221.87  # CT179 development
ssh root@100.107.113.33  # AGLSRV1 host

# From CT179 (prefer WireGuard)
ssh root@10.6.0.12  # AGLSRV6 (fastest)
ssh root@192.168.0.245  # AGLSRV1 host
```

### Essential Commands
```bash
# Check containers
ssh root@192.168.0.245 'pct list'

# Access storage
ls /mnt/pve/fgsrv6-wg  # NFS via WireGuard

# Docker operations
docker ps  # From CT179
```

**Complete Reference**: See `@docs/QUICK-START.md` for environment-specific commands, storage access, Docker operations, Archon management, and troubleshooting.

---

## 💻 Development Environments - Summary

**WSL2 (AGLHQ11)** - Remote Access:
- **Network**: Tailscale only (100.75.205.122)
- **Best For**: Remote work, Windows-based development
- **Limitations**: No WireGuard, no local LAN access, no Docker
- **Typical Use**: SSH to CT179 for infrastructure work

**CT179 (agldv03)** - Full Stack:
- **Network**: Triple-stack (LAN + WireGuard + Tailscale)
- **Resources**: 48GB RAM, Docker, full development tools
- **Best For**: High-performance local operations, WireGuard mesh access
- **Connection Priority**: WireGuard (fastest) > LAN (local) > Tailscale (fallback)

**CT108 (agldv06)** - Tailscale Only:
- **Network**: Tailscale only (100.71.229.12)
- **Best For**: AGLSRV6 local operations
- **Similar to**: WSL2 but with better container performance

**Complete Details**: See `@docs/INFRA.md` for network topology, connection matrix, tooling requirements, and environment-specific workflows.

---

## 📋 Integration with Archon MCP

**How Agent OS and Archon Work Together**:
1. **Standards → Archon Knowledge Base**: Agent OS standards indexed for semantic search
2. **Workflows → Archon Task Management**: Convert workflows to trackable tasks
3. **Skills → MCP Tool Discovery**: Skills trigger appropriate Archon tools
4. **Documentation → Cross-Referencing**: All docs reference each other

**Workflow Patterns**:
```
1. Read Agent OS workflow spec
2. Create Archon project and tasks (via MCP)
3. Execute with Skills auto-applying standards
4. Update Archon task status (todo → doing → done)
```

**Integration Commands**:
```bash
# Search Archon knowledge base
mcp__archon__rag_search_knowledge_base(query="wireguard mesh", match_count=5)

# Create infrastructure project
mcp__archon__manage_project("create", title="WireGuard Expansion")

# Track workflow as tasks
mcp__archon__manage_task("create", project_id="...", title="Setup CT184")
```

---

## 📊 Performance & Features

**Performance Benefits**:
- **84.8% SWE-Bench solve rate**
- **32.3% token reduction** with modular documentation
- **2.8-4.4x speed improvement** with parallel execution
- **10-20x faster** concurrent operations vs sequential
- **90% token savings** with on-demand document loading

**Advanced Features**:
- 🚀 Automatic Topology Selection
- ⚡ Parallel Execution (Task tool batching)
- 🧠 Neural Training (27+ models)
- 📊 Bottleneck Analysis
- 🤖 Smart Auto-Spawning
- 🛡️ Self-Healing Workflows
- 💾 Cross-Session Memory (Archon MCP)
- 🔗 GitHub Integration

---

## 🔧 Troubleshooting Quick Reference

### Common Issues

| Issue | Solution | Documentation |
|-------|----------|---------------|
| SSH timeout | Check Tailscale/WireGuard status | `@docs/QUICK-START.md` |
| NFS mount stale | `umount -f /mnt/pve/<storage> && mount -a` | `@docs/INFRA.md` |
| WireGuard handshake fails | Check config (remove PresharedKey in LXC) | `@docs/INFRA.md` |
| Archon MCP error | Restart archon-mcp container | `@docs/ARCHON.md` |
| Docker permission | Add user to docker group | `@docs/QUICK-START.md` |

### Diagnostic Commands
```bash
# Network
wg show  # WireGuard status
ping 10.6.0.5  # Test mesh

# Storage
df -h | grep wg  # NFS mounts
showmount -e 10.6.0.5  # Check exports

# Archon
curl http://10.6.0.21:8051/mcp  # Test MCP endpoint
```

**Complete Troubleshooting**: See `@docs/QUICK-START.md` for common issues table and diagnostic procedures.

---

## 📝 Git Commit Guidelines

```bash
# Format: <type>: <description>
git commit -m "feat: add WireGuard peer CT184

- Generated keys and configuration
- Added to hub (10.6.0.22)
- Verified mesh connectivity"

# Types: feat, fix, docs, refactor, test, perf, chore
```

---

## 🎯 Next Steps & Task Tracking

**Use Archon MCP for task management**:
```bash
# List all tasks
find_tasks(filter_by="status", filter_value="todo")

# Update task status
manage_task("update", task_id="...", status="doing")

# Mark complete
manage_task("update", task_id="...", status="done")
```

**Current Focus Areas**:
- Infrastructure monitoring (WireGuard mesh, NFS storage)
- Container management (configuration updates, deployments)
- Documentation maintenance (keep INFRA.md, ARCHON.md, WORKFLOWS.md current)
- Archon integration (test all MCP tools, knowledge base expansion)

---

## 📚 Support & Documentation

**Official Resources**:
- **Claude-Flow**: https://github.com/ruvnet/claude-flow
- **Claude Code Docs**: https://docs.claude.com/en/docs/claude-code

**Project Documentation**:
- **INFRA.md**: Infrastructure map, network topology, connection matrix
- **ARCHON.md**: Archon integration, MCP tools reference, development guidelines
- **WORKFLOWS.md**: Agent OS, SPARC methodology, available agents
- **RULES.md**: Coding standards, execution patterns, best practices
- **QUICK-START.md**: Fast reference, commands, troubleshooting

**Loading Pattern**: Use `@docs/filename.md` to load on-demand (saves 90% tokens!)

---

**Remember**:
- 📖 Always read context documents before starting infrastructure or Archon tasks
- 🔄 Claude Code creates, Claude-Flow coordinates, Archon MCP tracks
- ⚡ Batch all operations in single messages for maximum performance
- 🎯 Use Agent OS for spec-driven workflows, SPARC for TDD development

---

**Document Version**: 3.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (agl-hostman project)
**Always Load**: `@docs/INFRA.md` and `@docs/ARCHON.md` for complete context
