# Archon UI - Knowledge Base Upload Guide

**Date**: 2025-10-28
**Archon Version**: 1.0.0 (CT183)
**Access Method**: Web UI
**Status**: Required for complete integration

---

## Overview

The Archon MCP `archon_add_knowledge_source` method returns HTTP 404 (not implemented). Knowledge base population **must** be done via the web UI.

---

## Access Information

### Web UI Access

**Primary (LAN)**:
```
http://192.168.0.183:3737
```

**Via WireGuard**:
```
http://10.6.0.21:8080
Username: admin
Password: ArchonPass2025
```

**Via Tailscale**:
```
http://100.80.30.59:8080
Username: admin
Password: ArchonPass2025
```

**Public HTTPS**:
```
https://archon.aglz.io
Username: admin
Password: ArchonPass2025
```

---

## Documents to Upload

### Priority High (4 documents - Upload First)

These provide core infrastructure context:

1. **AGL Infrastructure Map**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRA.md`
   - **Name**: AGL Infrastructure Map
   - **Description**: Complete network topology, hosts, containers, WireGuard mesh, storage configuration
   - **Tags**: infrastructure, network, containers, proxmox, wireguard
   - **Why Important**: Primary reference for all infrastructure queries

2. **Archon Integration Guide**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/ARCHON.md`
   - **Name**: Archon AI Command Center Guide
   - **Description**: Archon deployment details, MCP tools reference, integration patterns, development guidelines
   - **Tags**: archon, mcp, ai, integration, api
   - **Why Important**: MCP tools reference and usage patterns

3. **Claude Code Configuration**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/CLAUDE.md`
   - **Name**: Claude Code Configuration & Rules
   - **Description**: Development rules, environment setup, workflows, infrastructure connection matrix
   - **Tags**: claude-code, development, configuration, rules
   - **Why Important**: Development workflow and environment-specific guidelines

4. **Agent OS Integration**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/ARCHON-INTEGRATION.md`
   - **Name**: Agent OS + Archon Integration Architecture
   - **Description**: Integration points, workflow patterns, command cheat sheets
   - **Tags**: agent-os, archon, integration, workflows, architecture
   - **Why Important**: Defines how Agent OS and Archon work together

---

### Priority Medium (5 documents - Infrastructure Standards & Workflows)

These provide operational procedures and standards:

5. **Infrastructure Management Standard**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/standards/global/infrastructure-management.md`
   - **Name**: AGL Infrastructure Management Standard
   - **Description**: Multi-network configuration, LXC container standards, Docker deployment, storage management
   - **Tags**: standards, infrastructure, containers, networking, deployment
   - **Why Important**: Core infrastructure patterns and best practices

6. **WireGuard Peer Setup Workflow**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/specs/infrastructure/wireguard-peer-setup.md`
   - **Name**: WireGuard Peer Setup Workflow
   - **Description**: Complete workflow for adding peers to WireGuard mesh network (15-20 min)
   - **Tags**: wireguard, networking, workflow, infrastructure
   - **Why Important**: Repeatable network expansion procedure

7. **NFS Storage Mount Workflow**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/specs/infrastructure/nfs-storage-mount.md`
   - **Name**: NFS Storage Mount Workflow
   - **Description**: Mount NFS shares via WireGuard with performance optimization (10-15 min)
   - **Tags**: nfs, storage, workflow, wireguard
   - **Why Important**: Storage integration and performance benchmarking

8. **Container Deployment Workflow**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/specs/infrastructure/container-deployment.md`
   - **Name**: LXC Container Deployment Workflow
   - **Description**: Deploy LXC with Docker support, multi-network config, resource allocation (20-30 min)
   - **Tags**: lxc, containers, docker, workflow, deployment
   - **Why Important**: Standard container provisioning procedure

9. **Archon Integration Workflow**
   - **Local Path**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/specs/infrastructure/archon-integration.md`
   - **Name**: Archon MCP Integration Workflow
   - **Description**: Connect Archon MCP to Claude Code with 3 endpoint strategies (15-20 min)
   - **Tags**: archon, mcp, integration, workflow
   - **Why Important**: MCP connection setup and troubleshooting

---

### Priority Low (6 documents - Coding Standards)

These provide general development standards:

10-15. **Agent OS Global Standards**
   - **coding-style.md** - Code formatting conventions
   - **error-handling.md** - Error management patterns
   - **commenting-conventions.md** - Documentation standards
   - **validation-patterns.md** - Input validation patterns
   - **tech-stack.md** - Technology choices and rationale
   - **conventions.md** - Naming conventions and best practices

**Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/agent-os/standards/global/`
**Tags**: standards, development, coding, best-practices
**Why Important**: Consistent code quality across projects

---

## Step-by-Step Upload Process

### Method 1: File Upload (Recommended for local files)

1. **Access Web UI**
   ```bash
   # From local network
   open http://192.168.0.183:3737

   # Or with auth (WireGuard/Tailscale)
   open http://10.6.0.21:8080
   # Login: admin / ArchonPass2025
   ```

2. **Navigate to Knowledge Base**
   - Click on "Knowledge Base" in main menu
   - Or go directly to `/knowledge-base` route

3. **Click "Add Source"**
   - Look for "+" button or "Add Source" button
   - Should open upload dialog

4. **Select "File Upload"**
   - Choose "File" option (vs URL)
   - Browse to file location

5. **Configure Source**
   - **Name**: Use descriptive name from priority list above
   - **Description**: Copy description from priority list
   - **Tags**: Add relevant tags (comma-separated)
   - **File**: Select the .md file

6. **Upload and Index**
   - Click "Upload" or "Add Source"
   - Wait for indexing (may take 10-60 seconds per file)
   - Verify in sources list

7. **Repeat for All Priority Files**
   - Start with Priority High (documents 1-4)
   - Continue with Priority Medium (documents 5-9)
   - Finish with Priority Low (documents 10-15)

---

### Method 2: URL Ingestion (For web-accessible content)

If documents are accessible via URL (GitHub raw, documentation sites):

1. **Get Public URL**
   ```bash
   # Example for GitHub
   https://raw.githubusercontent.com/your-org/agl-hostman/main/docs/INFRA.md
   ```

2. **Add as URL Source**
   - Select "URL" option in Add Source dialog
   - Paste URL
   - Archon will fetch and index automatically

3. **Configure Metadata**
   - Name, description, tags as above

**Note**: Local files are preferred for this project since they're not in a public repository.

---

## Verification

### After Upload, Verify Sources

1. **Check Sources List**
   ```bash
   # Via MCP
   mcp__archon-wg__rag_get_available_sources()
   ```

   Expected: Should show all uploaded documents

2. **Test Search**
   ```bash
   # Search for infrastructure content
   mcp__archon-wg__rag_search_knowledge_base({
     query: "wireguard mesh",
     match_count: 5
   })
   ```

   Expected: Should return relevant results from uploaded docs

3. **Read Full Page**
   ```bash
   # Get specific document content
   mcp__archon-wg__rag_list_pages_for_source({
     source_id: "<source_id_from_list>"
   })
   ```

   Expected: Should show pages from document

---

## Troubleshooting

### Issue: Upload Button Not Found

**Solution**: Check UI version, may be under:
- Settings → Knowledge Base
- Admin → Knowledge Sources
- Direct URL: `http://192.168.0.183:3737/admin/knowledge`

### Issue: File Upload Fails

**Possible Causes**:
- File too large (try splitting large docs)
- Invalid markdown format (validate syntax)
- Server disk space full (check CT183 storage)

**Debug**:
```bash
# Check Archon logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server'
```

### Issue: Indexing Hangs

**Solution**: Check processing status in UI, may take time for large files

**Check Background Jobs**:
```bash
# Via MCP
mcp__archon-wg__archon_get_status()
```

Look for `processing_jobs` or similar status field

### Issue: Search Returns No Results

**Causes**:
- Documents not yet indexed
- Query too specific (use 2-5 keywords max)
- Wrong source_id filter

**Debug**:
```bash
# List all sources
mcp__archon-wg__rag_get_available_sources()

# Try broader search
mcp__archon-wg__rag_search_knowledge_base({
  query: "infrastructure",  # Very broad
  match_count: 10
})
```

---

## Post-Upload Actions

### 1. Update Documentation

Mark documents as indexed in setup complete doc:
```markdown
- [x] INFRA.md → Archon Knowledge Base
- [x] ARCHON.md → Archon Knowledge Base
- [x] CLAUDE.md → Archon Knowledge Base
... (15 total)
```

### 2. Test RAG Search

Run test queries to verify:
```bash
# Test 1: Infrastructure query
mcp__archon-wg__rag_search_knowledge_base({
  query: "wireguard configuration",
  match_count: 5
})

# Test 2: Code example search
mcp__archon-wg__rag_search_code_examples({
  query: "docker compose",
  match_count: 3
})

# Test 3: Specific document read
mcp__archon-wg__rag_read_full_page({
  page_id: "<page_id_from_search>"
})
```

### 3. Commit Updated Documentation

```bash
git add docs/
git commit -m "docs: Complete Agent OS + Archon integration with knowledge base uploads

- Added 15 documents to Archon RAG via UI
- Validated RAG search functionality
- Updated integration documentation"
```

---

## Benefits After Upload

### Semantic Search Across All Docs

```bash
# Find any infrastructure-related content
"wireguard setup" → Returns peer setup workflow
"nfs mount" → Returns storage workflow + INFRA.md references
"docker lxc" → Returns container deployment + standards
```

### Cross-Document References

RAG will find related content across multiple documents:
- Query "archon tools" returns ARCHON.md + ARCHON-INTEGRATION.md
- Query "multi-network" returns INFRA.md + infrastructure-management.md + workflows

### Context-Aware Assistance

Claude Code can retrieve relevant docs automatically:
- Working on WireGuard → Auto-retrieves peer-setup workflow
- Deploying container → Auto-retrieves container-deployment workflow
- Using MCP tools → Auto-retrieves ARCHON.md reference

---

## Maintenance

### Periodic Updates

**When to Re-Upload**:
- INFRA.md changes (new containers, network updates)
- ARCHON.md updates (new MCP tools, configuration changes)
- CLAUDE.md updates (new rules, workflows)
- New workflow specs created

**Process**:
1. Make changes to local .md file
2. Re-upload via UI (may need to delete old version first)
3. Verify new content appears in search
4. Update git commit

### Version Tracking

Consider adding version/date to document frontmatter:
```markdown
---
version: 2.5.0
last_updated: 2025-10-28
---
```

---

## Quick Reference

### Upload Checklist

```bash
# Priority High (CRITICAL - Upload First)
□ INFRA.md (Infrastructure map)
□ ARCHON.md (MCP guide)
□ CLAUDE.md (Development rules)
□ ARCHON-INTEGRATION.md (Integration architecture)

# Priority Medium (Infrastructure workflows)
□ infrastructure-management.md (Standards)
□ wireguard-peer-setup.md (WG workflow)
□ nfs-storage-mount.md (NFS workflow)
□ container-deployment.md (LXC workflow)
□ archon-integration.md (MCP workflow)

# Priority Low (Coding standards)
□ coding-style.md
□ error-handling.md
□ commenting-conventions.md
□ validation-patterns.md
□ tech-stack.md
□ conventions.md
```

### Verification Commands

```bash
# List sources
mcp__archon-wg__rag_get_available_sources()

# Test search
mcp__archon-wg__rag_search_knowledge_base({query: "test", match_count: 3})

# Check status
mcp__archon-wg__archon_get_status()
```

---

## Estimated Time

- **Per Document Upload**: 1-2 minutes
- **Per Document Indexing**: 10-60 seconds
- **Total Time (15 documents)**: 20-30 minutes

**Recommendation**: Upload in batches:
1. Priority High (5 minutes)
2. Priority Medium (10 minutes)
3. Priority Low (10 minutes)

---

**Guide Complete** | Next Step: Access Archon UI and begin uploads
