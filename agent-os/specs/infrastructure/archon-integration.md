# Archon MCP Server Integration

**Type**: Service Integration
**Category**: AI Command Center
**Estimated Time**: 15-20 minutes

## Overview

Integrate Archon AI Command Center MCP server for project management, task tracking, and knowledge base access via Claude Code.

## Prerequisites

- [ ] Archon is deployed and running (CT183 on AGLSRV1)
- [ ] Network connectivity to Archon (LAN, WireGuard, or Tailscale)
- [ ] Claude Code CLI installed locally
- [ ] Authentication credentials (if using public HTTPS)

## Archon Endpoints

### Available Access Methods

**1. Local LAN** (Development):
- UI: `http://192.168.0.183:3737`
- API: `http://192.168.0.183:8181`
- MCP: `http://192.168.0.183:8051/mcp` (Docker direct)
- MCP: `http://192.168.0.183:8052/mcp` (nginx, LAN-only)
- **Authentication**: None required

**2. WireGuard Mesh** (PRIMARY External):
- IP: `10.6.0.21`
- MCP: `http://10.6.0.21:8051/mcp`
- nginx: `http://10.6.0.21:8080` (Basic Auth required)
- **Authentication**: Basic Auth for nginx only

**3. Tailscale VPN** (BACKUP External):
- IP: `100.80.30.59`
- MCP: `http://100.80.30.59:8051/mcp`
- nginx: `http://100.80.30.59:8080` (Basic Auth required)
- **Authentication**: Basic Auth for nginx only

**4. Public HTTPS**:
- URL: `https://archon.aglz.io`
- MCP: `https://archon.aglz.io/mcp`
- **Authentication**: Basic Auth required
  - Username: `admin`
  - Password: `ArchonPass2025`

## Specification

### Step 1: Verify Archon Availability
```bash
# Test MCP endpoints
curl http://192.168.0.183:8051/mcp  # LAN
curl http://10.6.0.21:8051/mcp      # WireGuard
curl http://100.80.30.59:8051/mcp   # Tailscale

# Test with Basic Auth (for public/nginx)
curl -u admin:ArchonPass2025 http://10.6.0.21:8080
curl -u admin:ArchonPass2025 https://archon.aglz.io
```

### Step 2: Add Archon MCP Servers to Claude Code

**Recommended Configuration** (all 3 endpoints):
```bash
# LAN endpoint (development, fastest)
claude mcp add --transport http archon \
  http://192.168.0.183:8052/mcp

# WireGuard endpoint (primary external)
claude mcp add --transport http archon-wg \
  http://10.6.0.21:8051/mcp

# Tailscale endpoint (backup external)
claude mcp add --transport http archon-tailscale \
  http://100.80.30.59:8051/mcp
```

**Verify Connection**:
```bash
claude mcp list
# Should show all 3 with ✓ Connected status
```

### Step 3: Test MCP Tools

**Available Tool Categories**:

**Knowledge Base** (RAG):
- `mcp__archon__rag_get_available_sources`
- `mcp__archon__rag_search_knowledge_base`
- `mcp__archon__rag_search_code_examples`
- `mcp__archon__rag_list_pages_for_source`
- `mcp__archon__rag_read_full_page`

**Project Management**:
- `mcp__archon__find_projects`
- `mcp__archon__manage_project`
- `mcp__archon__get_project_features`

**Task Management**:
- `mcp__archon__find_tasks`
- `mcp__archon__manage_task`

**Document Management**:
- `mcp__archon__find_documents`
- `mcp__archon__manage_document`

**Version Control**:
- `mcp__archon__find_versions`
- `mcp__archon__manage_version`

**System**:
- `mcp__archon__archon_get_status`
- `mcp__archon__health_check`
- `mcp__archon__session_info`

### Step 4: Create Infrastructure Project in Archon

Use Claude Code with Archon MCP:
```
Create a new project in Archon:
- Title: "AGL Infrastructure Management"
- Description: "Proxmox hosts, LXC containers, WireGuard mesh, storage management"
- GitHub repo: https://github.com/your-org/agl-hostman
```

Claude will use `mcp__archon__manage_project` to create the project.

### Step 5: Import Infrastructure Tasks

Example tasks to create:
```
Create tasks in Archon for infrastructure management:
1. Monitor WireGuard mesh connectivity
2. Maintain storage mounts (NFS/SSHFS)
3. Update container configurations
4. Document infrastructure changes
5. Perform weekly health checks
```

### Step 6: Add Knowledge Base Sources

**Priority Documentation** to add to Archon RAG:
1. `docs/INFRA.md` - Infrastructure map
2. `docs/ARCHON.md` - Archon integration guide
3. `CLAUDE.md` - Claude Code configuration
4. Agent OS standards - Infrastructure management

Use Archon UI or API to add sources:
```bash
# Via API (requires authentication)
curl -X POST -u admin:ArchonPass2025 \
  http://10.6.0.21:8080/api/knowledge/add \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "file",
    "path": "/path/to/docs/INFRA.md",
    "name": "AGL Infrastructure Map"
  }'
```

## Usage Patterns

### Query Best Practices

**✅ GOOD Queries** (2-5 keywords):
```
rag_search_knowledge_base(query="wireguard mesh topology")
rag_search_code_examples(query="docker compose nginx")
rag_search_knowledge_base(query="nfs over wireguard")
```

**❌ BAD Queries** (too long):
```
rag_search_knowledge_base(query="how to set up wireguard mesh network with proper configuration for LXC containers")
```

### Task Management Workflow

**1. List pending tasks**:
```
find_tasks(filter_by="status", filter_value="todo", project_id="<project_id>")
```

**2. Start working on task**:
```
manage_task("update", task_id="<task_id>", status="doing")
```

**3. Complete task**:
```
manage_task("update", task_id="<task_id>", status="done")
```

### Project Tracking

**Get project status**:
```
find_projects(project_id="<project_id>")
```

**Get project features**:
```
get_project_features(project_id="<project_id>")
```

## Environment-Specific Access

### From WSL2 (AGLHQ11)
**Available**: Tailscale only
```bash
# Use Tailscale endpoint
claude mcp add --transport http archon-tailscale \
  http://100.80.30.59:8051/mcp
```

### From CT179 (agldv03)
**Available**: All networks (LAN, WireGuard, Tailscale)
**Recommended**: WireGuard (best performance)
```bash
# Primary: WireGuard
claude mcp add --transport http archon-wg \
  http://10.6.0.21:8051/mcp

# Fallback: LAN
claude mcp add --transport http archon \
  http://192.168.0.183:8052/mcp
```

### From CT108 (agldv06)
**Available**: Tailscale only
```bash
# Use Tailscale endpoint
claude mcp add --transport http archon-tailscale \
  http://100.80.30.59:8051/mcp
```

## Troubleshooting

### MCP Connection Fails
**Symptom**: `claude mcp list` shows ✗ Disconnected
**Fixes**:
```bash
# Check network connectivity
ping 10.6.0.21  # WireGuard
ping 100.80.30.59  # Tailscale

# Check Archon services
ssh root@192.168.0.245 'pct exec 183 -- docker ps'

# Test endpoint manually
curl http://10.6.0.21:8051/mcp
```

### Authentication Errors
**Symptom**: 401 Unauthorized when accessing nginx endpoints
**Fix**: Ensure Basic Auth credentials are correct
```bash
# Test with credentials
curl -u admin:ArchonPass2025 http://10.6.0.21:8080
```

### RAG Search Returns No Results
**Symptom**: Knowledge base searches return empty
**Cause**: Sources not yet indexed in Archon
**Fix**: Add documentation to Archon knowledge base via UI or API

## Success Criteria

- [ ] All 3 MCP endpoints connected in Claude Code
- [ ] Can list available sources (`rag_get_available_sources`)
- [ ] Can search knowledge base successfully
- [ ] Infrastructure project created in Archon
- [ ] Initial tasks created and tracked
- [ ] Documentation added to knowledge base
- [ ] MCP tools integrated into workflows

## Integration Benefits

✅ **Centralized Task Management**: Track infrastructure work across sessions
✅ **Knowledge Base**: Semantic search across all documentation
✅ **Project Tracking**: Monitor progress on infrastructure improvements
✅ **Cross-Session Memory**: Persist context and decisions
✅ **Code Examples**: Find relevant implementation patterns
✅ **Version Control**: Track documentation changes

## Related Workflows

- [Archon Deployment](../../docs/ct183-deployment-guide.md)
- [MCP Server Management](./mcp-server-management.md)
- [Knowledge Base Maintenance](./knowledge-base-maintenance.md)
- [Task-Driven Development](./task-driven-development.md)
