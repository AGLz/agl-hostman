# Gemini Code Configuration - AGL Infrastructure Management

> **Last Updated**: 2025-11-19 | **Version**: 1.0.0
> **Based on**: CLAUDE.md v3.1.0 & .cursor Rules

## 🔖 CRITICAL: Always Read These Documents

**Before any infrastructure or Archon-related task, ALWAYS read:**
- **`docs/INFRA.md`** - Complete infrastructure map, network topology, connection matrix
- **`docs/ARCHON.md`** - Archon AI Command Center integration guide and MCP tools
- **`docs/WORKFLOWS.md`** - SPARC methodology, Agent OS integration, development workflows
- **`docs/RULES.md`** - Coding standards, execution patterns, best practices
- **`docs/QUICK-START.md`** - Fast reference for commands, connections, troubleshooting

**How to load on-demand**: Use `@docs/filename.md` syntax to load only when needed.

---

## 🤖 AI Behavior & Rules (from .cursor)

### 🧠 Core Rules
- **Edit in chunks**: Avoid large file replacements; use surgical edits to prevent JSON/syntax issues.
- **Ask if uncertain**: Do not guess about infrastructure or critical configurations.
- **Verify paths**: Confirm files and directories exist before writing.
- **Never delete code**: Unless explicitly instructed.
- **Update memories**: Use `.cursor/rules/learned-memories.mdc` to store project-specific preferences.

### 🧱 Code Standards
- **Max 500 lines/file**: Refactor if longer.
- **Modular design**: Separate concerns by feature/responsibility.
- **Clear imports**: Use relative paths within packages.
- **Comments**: Use `# Reason:` for complex logic.

### 🧪 Testing
- **Unit tests**: Required for all features (expected/edge/failure).
- **Location**: Tests must be in `/tests` mirroring app structure.
- **Update tests**: When logic changes, update tests immediately.

### ✅ Task Management
- **Track progress**: Use `ai-docs/tasks/TASKS.md` (or feature-specific task files).
- **Structure**:
  - `# Feature Name`
  - `## Completed Tasks`
  - `## In Progress Tasks`
  - `## Future Tasks`
  - `## Implementation Plan`
- **Update frequency**: Update task lists after every significant step.

---

## 📚 Document Navigation

### Primary Documents
1.  **`docs/INFRA.md`**: Central reference for hosts, networks, and storage.
2.  **`docs/ARCHON.md`**: MCP tools, knowledge base, and task management.
3.  **`docs/WORKFLOWS.md`**: Development methodologies (SPARC) and Agent OS.
4.  **`docs/RULES.md`**: Detailed coding and execution rules.

### Specialized Documentation
- **`docs/PROXMOX.md`**: Proxmox VE standards.
- **`docs/WIREGUARD.md`**: Mesh network configuration.
- **`docs/DOKPLOY.md`**: Deployment platform (CT180).
- **`docs/GEMINI-FLOW.md`**: Gemini Flow CLI & Swarm orchestration.

---

## 📍 Project Context

**Project**: `agl-hostman` - Infrastructure management and host administration
**Working Directory**: `/root/agl-hostman`

**Key Infrastructure**:
- **AGLSRV1** (192.168.0.245): Main Proxmox host.
- **AGLSRV6** (WG: 10.6.0.12): Secondary Proxmox host.
- **CT179**: Primary dev container (Docker, Triple Network).
- **CT183**: Archon AI Command Center.
- **WireGuard Mesh**: 10.6.0.0/24 (Primary Network).

**Network Priority**: WireGuard > LAN > Tailscale.

---

## 🚀 Quick Operations

### Environment Detection
```bash
if [[ -f /proc/version ]] && grep -q microsoft /proc/version; then
    echo "WSL2 (Tailscale only)"
elif [[ -f /.dockerenv ]]; then
    echo "Container (CT179/CT108)"
fi
```

### Common Commands
```bash
# SSH to AGLSRV1
ssh root@192.168.0.245

# Check containers
ssh root@192.168.0.245 'pct list'

# Access NFS storage
ls /mnt/pve/fgsrv6-wg
```

---

## 📋 Archon Integration

**MCP Tools**:
- **Knowledge Base**: `rag_search_knowledge_base`
- **Task Management**: `manage_task`, `find_tasks`
- **Project Management**: `manage_project`

**Workflow**:
1.  **Plan**: Create Archon project/tasks.
2.  **Execute**: Use Skills and Standards.
3.  **Track**: Update Archon task status.

---

## 💎 Gemini Specifics

- **Gemini Flow**: Use `gemini-flow` CLI for swarm orchestration if available.
- **Context Window**: Leverage Gemini's large context window to read full documentation files when necessary, but prefer on-demand loading for efficiency.
- **Multimodality**: Use image generation/analysis capabilities if required for UI/diagram tasks.

---

**Maintainer**: Gemini Code (agl-hostman project)
**Always Load**: `@docs/INFRA.md` and `@docs/ARCHON.md` for complete context.
