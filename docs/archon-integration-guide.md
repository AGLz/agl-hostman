# Archon Integration with AGL Infrastructure

## 📋 Integration Overview

This guide explains how Archon (CT183) integrates with the existing AGL infrastructure for maximum synergy and productivity.

---

## 🎯 Integration Points

### 1. Claude Code MCP Integration

**Purpose**: Enable Claude Code to access centralized knowledge base and task management

#### Configuration Steps

1. **On your development machine** (AGLHQ11, CT179, etc.):

```bash
# Edit Claude Code MCP settings
# Location: ~/.config/Code/User/globalStorage/claude-code/settings/mcp.json

{
  "mcpServers": {
    "archon-aglsrv1": {
      "transport": "sse",
      "url": "http://192.168.0.183:8051/sse",
      "description": "AGL Infrastructure knowledge base and task management"
    }
  }
}
```

2. **Verify connection**:
   - Restart Claude Code
   - Look for Archon server in MCP status
   - Test with a query: "Search for CT179 configuration"

#### Connection Matrix

| Source | Network | MCP URL | Notes |
|--------|---------|---------|-------|
| **CT179 (agldv03)** | LAN | http://192.168.0.183:8051 | Direct LAN access (fastest) |
| **AGLHQ11 (WSL2)** | Tailscale | http://100.x.x.x:8051 | After Tailscale setup |
| **Remote Workstations** | WireGuard | http://10.6.0.23:8051 | After WireGuard setup |

---

### 2. Knowledge Base Population

**Goal**: Import AGL infrastructure documentation into Archon for AI-assisted queries

#### Documents to Import

| Category | Source | Import Method |
|----------|--------|---------------|
| **Infrastructure Docs** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/` | Web UI upload |
| **CLAUDE.md** | `/mnt/overpower/apps/dev/agl/agl-hostman/CLAUDE.md` | Direct upload |
| **CT Deployment Guides** | `docs/ct*-deployment-guide.md` | Batch upload |
| **Network Configs** | WireGuard, Tailscale configs | Manual entry |
| **Container List** | AGLSRV1/6 container inventory | API integration |

#### Import Commands

```bash
# From CT183 (after Archon is running)

# 1. Upload CLAUDE.md
curl -X POST http://localhost:8181/api/documents/upload \
  -H "Content-Type: application/json" \
  -d @/mnt/overpower/apps/dev/agl/agl-hostman/CLAUDE.md

# 2. Batch upload docs folder
for file in /mnt/overpower/apps/dev/agl/agl-hostman/docs/*.md; do
  curl -X POST http://localhost:8181/api/documents/upload \
    -H "Content-Type: multipart/form-data" \
    -F "file=@$file"
done
```

**Or use the Web UI**:
1. Open http://192.168.0.183:3737
2. Go to "Documents" section
3. Click "Upload" and select files
4. Tag documents (e.g., "infrastructure", "proxmox", "wireguard")

---

### 3. Task Management Integration

**Purpose**: Centralize infrastructure tasks across AI assistants

#### Workflow Example

1. **Create task in Archon** (via UI or API):
   ```json
   {
     "title": "Configure CT200 Ollama GPU Passthrough",
     "description": "Add NVIDIA GPU passthrough to CT200 for local LLM inference",
     "tags": ["infrastructure", "gpu", "ollama"],
     "priority": "high",
     "assignee": "claude-code"
   }
   ```

2. **Query task from Claude Code**:
   ```
   User: "What tasks are pending for GPU configuration?"
   Claude Code: [Queries Archon MCP] → Returns CT200 GPU task
   ```

3. **Update task status programmatically**:
   ```bash
   curl -X PATCH http://192.168.0.183:8181/api/tasks/123 \
     -H "Content-Type: application/json" \
     -d '{"status": "in_progress", "notes": "Testing GPU passthrough..."}'
   ```

---

### 4. Distributed Knowledge Sharing

**Scenario**: Multiple developers/AI assistants need access to same infrastructure knowledge

#### Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Archon CT183 (Hub)                      │
│              192.168.0.183:8051 (MCP)                    │
└──────────────────────────────────────────────────────────┘
           ↓              ↓              ↓
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ Claude   │   │ Cursor   │   │ Windsurf │
    │ Code     │   │ IDE      │   │ IDE      │
    │ (CT179)  │   │(AGLHQ11) │   │ (Remote) │
    └──────────┘   └──────────┘   └──────────┘
```

**Benefits**:
- ✅ **Unified knowledge base**: All AI assistants see same infrastructure docs
- ✅ **Consistent responses**: Same prompts yield same context
- ✅ **Collaborative learning**: One assistant's discoveries benefit all
- ✅ **Version control**: Single source of truth for infrastructure state

---

### 5. Automation Workflows

#### Example: Automated Container Documentation

**Trigger**: New container created on Proxmox
**Action**: Automatically add to Archon knowledge base

```bash
#!/bin/bash
# /usr/local/bin/archon-sync-containers.sh
# Run via cron every 15 minutes

ARCHON_API="http://192.168.0.183:8181/api"

# Get container list from AGLSRV1
ssh root@192.168.0.245 'pct list' | tail -n +2 | while read vmid status name; do
  # Get container details
  DETAILS=$(ssh root@192.168.0.245 "pct config $vmid")

  # Upload to Archon
  curl -X POST "$ARCHON_API/documents/create" \
    -H "Content-Type: application/json" \
    -d "{
      \"title\": \"CT$vmid - $name\",
      \"content\": \"$DETAILS\",
      \"tags\": [\"container\", \"proxmox\", \"aglsrv1\"],
      \"auto_generated\": true
    }"
done
```

#### Example: WireGuard Peer Monitoring

**Trigger**: WireGuard peer status changes
**Action**: Update Archon knowledge base

```bash
#!/bin/bash
# Monitor WireGuard mesh and sync to Archon

PEERS=$(wg show wg0 peers)
curl -X POST http://192.168.0.183:8181/api/documents/update \
  -H "Content-Type: application/json" \
  -d "{
    \"document_id\": \"wireguard-status\",
    \"content\": \"$PEERS\",
    \"timestamp\": \"$(date -Iseconds)\"
  }"
```

---

### 6. Integration with Existing Services

#### A. Observium (CT132)

**Purpose**: Query infrastructure metrics via Archon

```python
# Archon custom tool: query_observium
import requests

def query_observium(device_name):
    """Query device metrics from Observium via Archon"""
    url = f"http://192.168.0.132/api/v0/devices/{device_name}"
    response = requests.get(url, headers={"X-Auth-Token": "YOUR_TOKEN"})
    return response.json()

# Register in Archon settings → Custom Tools
```

#### B. Proxmox API

**Purpose**: Direct container management via Archon MCP tools

```python
# Archon custom tool: pct_command
def pct_command(vmid, action):
    """Execute Proxmox pct commands"""
    ssh = SSHClient()
    ssh.connect("192.168.0.245", username="root", key_filename="/root/.ssh/id_ed25519")
    stdout = ssh.exec_command(f"pct {action} {vmid}")
    return stdout.read().decode()

# Available actions: start, stop, restart, status, config
```

#### C. Harbor Registry (CT182) - Future Integration

**Purpose**: Query Docker image metadata

```python
# When Harbor is deployed, integrate container image search
def harbor_search(image_name):
    """Search Harbor registry for container images"""
    # Implementation pending CT182 deployment
    pass
```

---

## 📊 Monitoring Integration

### Archon Health Checks

Add to Observium/Prometheus for monitoring:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'archon-ct183'
    static_configs:
      - targets: ['192.168.0.183:8181']
    metrics_path: '/api/metrics'
    scrape_interval: 30s
```

### Alerting Rules

```yaml
# Alert if Archon MCP server is down
- alert: ArchonMCPDown
  expr: up{job="archon-ct183"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Archon MCP server down on CT183"
    description: "AI assistants cannot access knowledge base"
```

---

## 🔗 Cross-Project Integration

### Use Cases

#### 1. Multi-Container Orchestration

**Scenario**: Deploy complex app across CT179 (dev), CT180 (dokploy), CT183 (archon)

```python
# Archon workflow: deploy_distributed_app
def deploy_distributed_app(app_config):
    """Orchestrate deployment across multiple containers"""
    # 1. Update Archon knowledge base with deployment plan
    archon.create_document("deployment-plan", app_config)

    # 2. Execute on CT179 (Docker containers)
    ct179.docker_compose_up(app_config["dev_services"])

    # 3. Deploy to CT180 (Dokploy PaaS)
    ct180.dokploy_deploy(app_config["prod_services"])

    # 4. Update Archon with deployment status
    archon.update_task("deployment-123", status="completed")
```

#### 2. Infrastructure as Code (IaC) Generation

**Scenario**: Generate Terraform/Ansible configs from Archon knowledge

```python
# Query Archon for container specs
containers = archon.search("container specifications")

# Generate Terraform config
terraform_config = generate_terraform(containers)

# Save to git repo
save_to_git("/root/agl-hostman/infrastructure/terraform/", terraform_config)
```

---

## 🚀 Advanced Integration Patterns

### Pattern 1: Event-Driven Updates

**Architecture**: Proxmox hooks → Archon API → MCP broadcast

```bash
# /etc/pve/lxc/<vmid>.conf (on AGLSRV1 host)
# Add post-start hook
hookscript: local:snippets/archon-notify.sh

# /var/lib/vz/snippets/archon-notify.sh
#!/bin/bash
VMID=$1
PHASE=$2

if [ "$PHASE" == "post-start" ]; then
  curl -X POST http://192.168.0.183:8181/api/events \
    -d "{\"type\": \"container_started\", \"vmid\": $VMID}"
fi
```

### Pattern 2: Semantic Search for Troubleshooting

**Workflow**:
1. Error occurs on CT179
2. Claude Code queries Archon: "Similar errors to [error message]"
3. Archon returns vector-search results from past incidents
4. Claude Code suggests fix based on historical solutions

```python
# Archon MCP tool: search_similar_issues
def search_similar_issues(error_message, k=5):
    """Find similar past issues using semantic search"""
    results = archon.vector_search(
        query=error_message,
        filters={"tags": ["error", "troubleshooting"]},
        top_k=k
    )
    return [
        {"title": r.title, "solution": r.content, "similarity": r.score}
        for r in results
    ]
```

---

## 📝 Integration Checklist

### Phase 1: Basic MCP Connection
- [ ] Archon deployed and running on CT183
- [ ] MCP server accessible at port 8051
- [ ] Claude Code configured with Archon MCP server
- [ ] Test query: "List all CT containers on AGLSRV1"

### Phase 2: Knowledge Population
- [ ] CLAUDE.md imported to Archon
- [ ] All docs/*.md files uploaded
- [ ] Container configurations imported
- [ ] WireGuard/Tailscale configs documented

### Phase 3: Task Management
- [ ] Infrastructure tasks created in Archon
- [ ] Claude Code can query and update tasks
- [ ] Task status syncs with actual infrastructure state

### Phase 4: Automation
- [ ] Cron job for container sync (every 15 min)
- [ ] Proxmox hooks for real-time updates
- [ ] WireGuard peer monitoring
- [ ] Observium metric queries

### Phase 5: Advanced Features
- [ ] Semantic search for troubleshooting
- [ ] Distributed app deployment workflows
- [ ] IaC generation from Archon knowledge
- [ ] Cross-assistant collaboration (Claude + Cursor + Windsurf)

---

## 🎯 Expected Outcomes

**After Full Integration**:

1. **AI Assistants become infrastructure-aware**:
   - "What containers are running on AGLSRV1?" → Instant, accurate response
   - "How do I connect to CT179 from AGLHQ11?" → Connection matrix from CLAUDE.md

2. **Faster troubleshooting**:
   - Error occurs → Claude searches Archon → Finds similar past issue → Suggests fix
   - Reduces time from hours to minutes

3. **Knowledge retention**:
   - Solutions documented once → Available to all future sessions
   - No more "I fixed this before but forgot how"

4. **Collaborative development**:
   - Multiple developers/AI assistants share same context
   - Consistent responses across tools (Claude Code, Cursor, Windsurf)

5. **Automated documentation**:
   - Infrastructure changes auto-update Archon
   - Always-current documentation (no stale docs)

---

**Integration Guide Version**: 1.0
**Last Updated**: 2025-10-27
**Next Review**: After Supabase configuration and first MCP connection
