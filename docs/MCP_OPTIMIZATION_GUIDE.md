# MCP Optimization Guide for AGL Infrastructure

> **Updated**: 2026-02-18 | **Important**: With `ENABLE_TOOL_SEARCH: true`, MCP limits are less critical

---

## 🎯 Key Update: ENABLE_TOOL_SEARCH Configuration

**With `ENABLE_TOOL_SEARCH: true`** (configured in your Claude Code settings), MCPs use **on-demand/deferred tool loading**. This changes everything:

| Before ENABLE_TOOL_SEARCH | With ENABLE_TOOL_SEARCH |
|---------------------------|-------------------------|
| All tools loaded into context | Tools listed but NOT loaded |
| 24 MCPs = heavy context bloat | 24 MCPs = minimal impact |
| Must limit to 3-4 MCPs | Can keep 20+ MCPs safely |
| Remove unused MCPs | Only remove if problematic |

### How ToolSearch Works

```javascript
// Tools are NOT loaded until explicitly requested
// Use ToolSearch to discover and load tools

// Search by keyword
ToolSearch({ query: "docker container", max_results: 5 })
// Returns: mcp__docker__docker_container_list, mcp__docker__docker_container_inspect, etc.

// Direct select if you know exact name
ToolSearch({ query: "select:mcp__docker__docker_container_list" })

// After ToolSearch returns tools, they become immediately callable
// Example: mcp__docker__docker_container_list() is now available
```

### Context Window Impact Comparison

| Configuration | Token Impact | Status |
|--------------|--------------|--------|
| 24 MCPs without ENABLE_TOOL_SEARCH | HIGH (500+ tools loaded) | ❌ Deprecated |
| 24 MCPs with ENABLE_TOOL_SEARCH | LOW (tools load on-demand) | ✅ Recommended |
| 3-4 MCPs (old rule) | LOW | ⚠️ Unnecessary now |

---

## Current MCP Inventory (Safe to Keep All)

### Tier 1: FREQUENTLY USED (Keep Configured)

| MCP | Tools | Primary Use |
|-----|-------|-------------|
| **archon-tailscale** | 28 | Task management, RAG knowledge base |
| **claude-flow** | 80+ | Swarm coordination, neural, memory |
| **memory** | 10 | Cross-session persistence |
| **github** | 25 | PR management, code review, issues |

**These are your daily drivers** - ToolSearch makes them available instantly without context bloat.

---

### Tier 2: INFRASTRUCTURE (Keep Configured)

| MCP | Tools | When to Use |
|-----|-------|-------------|
| **docker** | 8 | Container operations on AGLSRV1/CT179 |
| **proxmox** | 6 | VM/CT management on AGLSRV1 |
| **cloudflare-dns** | 60 | DNS, Workers, R2, D1 operations |

**Load on-demand via ToolSearch when doing infrastructure work.**

---

### Tier 3: SPECIALIZED (Keep Configured)

| MCP | Tools | Use Case |
|-----|-------|----------|
| **harbor** | 12 | Container registry (CT182) |
| **dokploy** | 40 | Deployment platform |
| **portainer** | 25 | Docker management UI |
| **flow-nexus** | 80+ | Cloud platform, neural training |
| **ruv-swarm** | 20 | Distributed swarm agents |

**Load on-demand for specific tasks.**

---

### Tier 4: RARELY USED (Consider Removing)

| MCP | Tools | Recommendation |
|-----|-------|----------------|
| **minecraft** | 30 | Remove if not gaming |
| **azure-devops** | 25 | Remove if not using Azure DevOps |
| **agentic-payments** | 12 | Remove if not doing payments |

**These are safe to remove if truly unused.** But with ENABLE_TOOL_SEARCH, keeping them has minimal impact.

---

## ToolSearch Best Practices

### Pattern 1: Keyword Search (Discovery)

```javascript
// When you know WHAT you need but not WHICH tool
ToolSearch({ query: "container logs", max_results: 5 })
ToolSearch({ query: "github pull request", max_results: 5 })
ToolSearch({ query: "archon task", max_results: 5 })
```

### Pattern 2: Direct Select (Known Tool)

```javascript
// When you know the exact tool name
ToolSearch({ query: "select:mcp__docker__docker_container_logs" })
ToolSearch({ query: "select:mcp__github__create_pull_request" })
ToolSearch({ query: "select:mcp__archon-tailscale__find_tasks" })
```

### Pattern 3: Tier-Based Search

```javascript
// Search within a specific MCP service
ToolSearch({ query: "+slack send", max_results: 3 })  // Only slack tools
ToolSearch({ query: "+docker container", max_results: 5 })  // Only docker tools
```

---

## When to Remove MCPs

### Remove If:
- [ ] MCP server is causing errors or crashes
- [ ] MCP is completely unused and you want cleaner config
- [ ] MCP conflicts with another MCP
- [ ] MCP is deprecated or unmaintained

### Do NOT Remove Just Because:
- [ ] You have "too many" MCPs (ENABLE_TOOL_SEARCH handles this)
- [ ] You're not using it right now (no context impact)
- [ ] The old "3-4 MCPs" rule (obsolete with ENABLE_TOOL_SEARCH)

---

## Quick Reference Commands

```bash
# List configured MCPs
claude mcp list

# Remove MCP if problematic
claude mcp remove <name>

# Add MCP when needed
claude mcp add --transport http <name> <url>
```

### ToolSearch in Session
```javascript
// Load tools when needed
ToolSearch({ query: "search pattern", max_results: 5 })

// After loading, use directly
mcp__service__tool_name({ param: "value" })
```

---

## Summary

| Aspect | Recommendation |
|--------|----------------|
| **MCP Count** | Keep all useful MCPs configured |
| **Context Bloat** | ENABLE_TOOL_SEARCH prevents it |
| **Tool Discovery** | Use ToolSearch by keyword |
| **Known Tools** | Use ToolSearch with select: prefix |
| **Removal** | Only for problematic/redundant MCPs |

---

**Key Insight**: With `ENABLE_TOOL_SEARCH: true`, focus on **Task Management** and **Session Management** instead of MCP limits. These solve ~90% of context rot issues.

---

*Guide updated: 2026-02-18 | ENABLE_TOOL_SEARCH support added*
