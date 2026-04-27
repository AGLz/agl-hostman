# Agent OS + Archon Integration Guide

**Version**: 1.0.0
**Last Updated**: 2025-10-28

## Overview

This document explains how Agent OS (spec-driven development) integrates with Archon AI Command Center (MCP server) to provide a complete infrastructure management solution.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Code CLI                          │
│                                                              │
│  ┌──────────────────┐              ┌──────────────────┐    │
│  │   Agent OS       │              │   Archon MCP     │    │
│  │   Standards      │◄────────────►│   Server         │    │
│  │   & Workflows    │              │   (CT183)        │    │
│  └──────────────────┘              └──────────────────┘    │
│         │                                   │                │
│         │ Skills Auto-Apply                 │ MCP Tools      │
│         │ Specs Guide Work                  │ Task Tracking  │
│         │                                   │ RAG Search     │
│         ▼                                   ▼                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         AGL Infrastructure Management               │   │
│  │   (Proxmox, LXC, WireGuard, Storage, Services)     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Integration Points

### 1. Standards → Archon Knowledge Base

Agent OS standards are ideal candidates for Archon's RAG knowledge base:

**Priority Standards to Index**:
- `agent-os/standards/global/infrastructure-management.md`
- `agent-os/standards/global/coding-style.md`
- `agent-os/standards/global/error-handling.md`
- `agent-os/standards/backend/*.md`
- `agent-os/standards/frontend/*.md`

**How to Index**:
```javascript
// Via Archon MCP tools
mcp__archon__archon_add_knowledge_source({
  source_type: "file",
  url: "/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/standards/",
  name: "Agent OS Standards"
})
```

### 2. Workflows → Archon Task Management

Agent OS workflows become trackable tasks in Archon:

**Example Workflow**: `agent-os/specs/infrastructure/wireguard-peer-setup.md`

**Archon Task Creation**:
```javascript
// Create project first
mcp__archon__manage_project("create", {
  title: "WireGuard Mesh Expansion",
  description: "Add new peers to WireGuard mesh network"
})

// Create tasks from workflow steps
mcp__archon__manage_task("create", {
  project_id: "<project_id>",
  title: "Generate WireGuard keys for CT184",
  description: "Run wg genkey on target container",
  status: "todo"
})
```

### 3. Skills → MCP Tool Discovery

Agent OS Skills help Claude Code discover when to use Archon MCP tools:

**Skill Triggers MCP Usage**:
```markdown
## When to use this skill:
- Working with Proxmox hosts and LXC containers
  → Use mcp__archon__manage_task for tracking deployment

- Writing infrastructure documentation
  → Use mcp__archon__rag_search_knowledge_base for examples
```

### 4. Documentation → Cross-Referencing

All infrastructure documentation references both systems:

**Agent OS → Archon**:
- Workflows reference Archon for task tracking
- Standards mention Archon MCP tools

**Archon → Agent OS**:
- ARCHON.md references Agent OS standards
- Task descriptions link to workflow specs

## Workflow Patterns

### Pattern 1: Spec-Driven Infrastructure Task

**Step 1**: Read Agent OS workflow spec
```
Read agent-os/specs/infrastructure/wireguard-peer-setup.md
```

**Step 2**: Create Archon project and tasks
```
Create Archon project "WireGuard CT184 Setup"
Break down wireguard-peer-setup.md into Archon tasks
```

**Step 3**: Execute with Skills auto-applying
```
Implement task: Generate WireGuard keys
(infrastructure-management Skill auto-applies standards)
```

**Step 4**: Update Archon task status
```
mcp__archon__manage_task("update", task_id="...", status="done")
```

### Pattern 2: Knowledge-Driven Development

**Step 1**: Search Archon knowledge base
```
mcp__archon__rag_search_knowledge_base(query="wireguard lxc config")
```

**Step 2**: Apply Agent OS standards
```
(global-infrastructure-management Skill provides context)
```

**Step 3**: Implement following spec
```
Follow agent-os/specs/infrastructure/wireguard-peer-setup.md
```

**Step 4**: Document in Archon
```
mcp__archon__manage_document("create", {
  project_id: "...",
  title: "CT184 WireGuard Configuration",
  document_type: "note",
  content: {...}
})
```

### Pattern 3: Cross-Session Context

**Session 1** (via Agent OS):
```
Implement container deployment following
agent-os/specs/infrastructure/container-deployment.md
```

**Session 2** (via Archon MCP):
```
mcp__archon__find_tasks(query="container deployment")
→ Retrieves context from previous session
→ Shows what was completed, what's pending
```

## Command Cheat Sheet

### Agent OS Commands (Claude Code)

```bash
# Create tasks from spec
/create-tasks
Use agent-os/specs/infrastructure/wireguard-peer-setup.md

# Implement tasks
/implement-tasks
Implement tasks 1-3 from the list

# Shape specification
/shape-spec
Refine agent-os/specs/infrastructure/archon-integration.md

# Plan product
/plan-product
Plan infrastructure monitoring system
```

### Archon MCP Commands (Claude Code)

```javascript
// Knowledge base search
mcp__archon__rag_search_knowledge_base({
  query: "wireguard mesh",
  match_count: 5
})

// Task management
mcp__archon__find_tasks({
  filter_by: "status",
  filter_value: "todo"
})

mcp__archon__manage_task("update", {
  task_id: "...",
  status: "doing"
})

// Project tracking
mcp__archon__find_projects({
  query: "infrastructure"
})
```

## Best Practices

### ✅ DO

1. **Store specs in Agent OS** (`agent-os/specs/`)
   - Workflows are version-controlled
   - Easy to reference and update

2. **Track execution in Archon**
   - Tasks show real-time progress
   - Cross-session continuity

3. **Index standards in Archon RAG**
   - Semantic search across all standards
   - Find relevant patterns quickly

4. **Use Skills for auto-context**
   - Infrastructure Skill applies automatically
   - No need to manually reference standards

5. **Cross-reference documentation**
   - CLAUDE.md → INFRA.md → ARCHON.md → Agent OS
   - Clear navigation between systems

### ❌ DON'T

1. **Don't duplicate content**
   - Specs in Agent OS, tracking in Archon
   - Not both in both places

2. **Don't bypass standards**
   - Always follow Agent OS standards
   - Skills enforce them automatically

3. **Don't skip Archon integration**
   - Use Archon for task management
   - Benefit from cross-session memory

4. **Don't create orphan workflows**
   - Every workflow should reference related docs
   - Clear links to Archon, INFRA.md, CLAUDE.md

## Integration Checklist

For complete Agent OS + Archon integration:

- [ ] Agent OS installed (`~/agent-os/`)
- [ ] Agent OS project integration (`agent-os/` folder in project)
- [ ] Custom infrastructure standards created
- [ ] Infrastructure Skill created and optimized
- [ ] All Skills improved with detailed descriptions
- [ ] Infrastructure workflows created (`agent-os/specs/infrastructure/`)
- [ ] Archon MCP connected (3 endpoints: LAN, WireGuard, Tailscale)
- [ ] Archon knowledge base populated with Agent OS standards
- [ ] Infrastructure project created in Archon
- [ ] Initial tasks created and tracked
- [ ] CLAUDE.md updated with Agent OS section
- [ ] Cross-references established in all docs

## Environment-Specific Usage

### From WSL2 (AGLHQ11)
**Agent OS**: ✅ Full access (local files)
**Archon MCP**: ✅ Via Tailscale (`archon-tailscale`)
**Recommended**: Create specs locally, track via Archon Tailscale

### From CT179 (agldv03)
**Agent OS**: ✅ Full access (local files)
**Archon MCP**: ✅ All networks (prefer WireGuard `archon-wg`)
**Recommended**: Full integration, use WireGuard for best performance

### From CT108 (agldv06)
**Agent OS**: ✅ Full access (local files)
**Archon MCP**: ✅ Via Tailscale (`archon-tailscale`)
**Recommended**: Create specs locally, track via Archon Tailscale

## Troubleshooting

### Skills Not Auto-Applying
**Check**: Verify `standards_as_claude_code_skills: true` in `~/agent-os/config.yml`

### Archon MCP Not Connected
**Check**: Run `claude mcp list` and verify endpoints are connected

### Workflows Not Found
**Check**: Ensure specs are in `agent-os/specs/infrastructure/` directory

### RAG Search Returns Nothing
**Check**: Verify Agent OS standards are indexed in Archon knowledge base

## Support & Documentation

**Agent OS**:
- Official Docs: https://buildermethods.com/agent-os
- Config: `~/agent-os/config.yml`
- Project Config: `agent-os/config.yml`

**Archon**:
- Integration Guide: `docs/ARCHON.md`
- Infrastructure Map: `docs/INFRA.md`
- Claude Config: `CLAUDE.md`

**This Integration**:
- Standards: `agent-os/standards/global/infrastructure-management.md`
- Workflows: `agent-os/specs/infrastructure/`
- Skills: `.claude/skills/global-infrastructure-management/`

## Version History

- **1.0.0** (2025-10-28): Initial integration documentation
  - Agent OS installed and configured
  - Custom infrastructure standards created
  - 4 infrastructure workflows created
  - 16 Skills optimized
  - Archon MCP integration documented
