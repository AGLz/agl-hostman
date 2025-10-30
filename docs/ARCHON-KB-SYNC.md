# Archon Knowledge Base Sync - Setup Complete

> **Status**: ✅ Active
> **Last Sync**: 2025-10-30
> **Connection**: LAN (192.168.0.183:8052)

---

## 🎯 Overview

Automated synchronization system for keeping Archon Knowledge Base updated with documentation changes.

### What Was Implemented

1. **Slash Command**: `/sync-archon-kb` - Manual sync trigger
2. **Git Hook**: `post-commit` - Auto-reminder on doc changes
3. **Sync Script**: `scripts/sync-archon-kb.sh` - Standalone utility

---

## 📊 Current Status

### ✅ INFRA.md Upload (In Progress)

**Upload Started**: 2025-10-30
**Method**: MCP via temporary HTTP server
**Progress ID**: `3d81cb5d-d222-4937-959a-e4a71e0da7b5`
**Estimated Completion**: 3-5 minutes from start
**Status**: Crawling in progress

**Document Details**:
- **Title**: AGL Infrastructure Map
- **Size**: 16KB (508 lines)
- **Content**: Network topology, hosts, containers, storage
- **Tags**: infrastructure, network, wireguard, proxmox, docker, storage, containers, nfs
- **Knowledge Type**: technical

### 📚 Knowledge Base Sources

**Current Sources** (before INFRA.md):
1. Python Documentation (6,581 words)
2. Model Context Protocol (76,215 words)

**After Sync** (will include):
3. AGL Infrastructure Map (~5,000 words)

---

## 🚀 How to Use

### Method 1: Slash Command (Recommended)

When you update documentation:

```
1. Edit document (e.g., docs/INFRA.md)
2. Commit changes: git commit -m "docs: update infrastructure"
3. In Claude Code: /sync-archon-kb
4. Verify: Search for updated content
```

**Example**:
```bash
# Update document
echo "New content" >> docs/INFRA.md
git add docs/INFRA.md
git commit -m "docs: add CT184 to infrastructure"

# Git hook will remind you
# 📚 Documentation changed, consider syncing to Archon Knowledge Base
# Changed documents:
#   - docs/INFRA.md
# Run: /sync-archon-kb

# In Claude Code session
/sync-archon-kb
```

### Method 2: Standalone Script

Direct script execution:

```bash
# Sync all priority documents
./scripts/sync-archon-kb.sh

# Sync only changed documents
./scripts/sync-archon-kb.sh --changed

# Sync specific documents
./scripts/sync-archon-kb.sh docs/INFRA.md docs/ARCHON.md
```

### Method 3: Git Hook (Automatic Reminder)

**Current Behavior**: Reminder only (safe)

After committing doc changes:
```
📚 Documentation changed, consider syncing to Archon Knowledge Base

Changed documents:
  - docs/INFRA.md

Run: /sync-archon-kb (in Claude Code session)
Or: git commit --amend (to include in this commit)
```

**Optional**: Enable auto-sync (edit `.git/hooks/post-commit`):
```bash
# Uncomment this line in the hook:
# claude-code --command "/sync-archon-kb"
```

---

## 📋 Sync Workflow Details

### 1. Change Detection

**Automatic Detection**:
- Git hook monitors: `docs/**/*.md`, `CLAUDE.md`
- Slash command asks which docs to sync
- Script scans for changes: `git diff --name-only HEAD~1 HEAD`

**Priority Documents** (always recommended to sync):
- `docs/INFRA.md` - Infrastructure map
- `docs/ARCHON.md` - Archon integration
- `docs/WORKFLOWS.md` - Development workflows
- `docs/RULES.md` - Coding standards
- `CLAUDE.md` - Project navigation

**Conditional Documents** (sync if changed):
- `docs/DEPLOYMENT-GUIDE.md`
- `docs/HARBOR-REGISTRY.md`
- `docs/DOKPLOY-DEPLOYMENT.md`
- `docs/TROUBLESHOOTING-DEPLOY.md`
- `docs/ROLLBACK-PROCEDURE.md`

### 2. Upload Process

**Technical Implementation**:

```mermaid
graph LR
A[Doc Changed] --> B[Git Commit]
B --> C[Post-Commit Hook]
C --> D{Auto-Sync?}
D -->|No| E[Remind User]
D -->|Yes| F[/sync-archon-kb]
E --> F
F --> G[Start HTTP Server]
G --> H[MCP: archon_add_knowledge_source]
H --> I[Archon Crawls Document]
I --> J[Indexing & Embeddings]
J --> K[Stop HTTP Server]
K --> L[Verify with RAG Search]
```

**Steps**:
1. Start temporary HTTP server (port 8765)
2. Make document accessible via HTTP
3. Call Archon MCP: `archon_add_knowledge_source`
4. Archon crawls the document
5. Generates embeddings for semantic search
6. Indexes content into Knowledge Base
7. Stop HTTP server
8. Verify with RAG search

### 3. Tag Generation

**Automatic Tags by Document Type**:

| Document Pattern | Tags |
|------------------|------|
| `*INFRA*` | infrastructure, network, wireguard, proxmox, docker, storage |
| `*ARCHON*` | archon, mcp, ai, task-management, knowledge-base |
| `*WORKFLOW*` | workflows, sparc, agent-os, development, automation |
| `*RULES*` | coding-standards, rules, best-practices, guidelines |
| `*DEPLOY*` | deployment, harbor, dokploy, ci-cd |
| `*TROUBLESHOOT*` | troubleshooting, debugging, diagnostics |
| `*ROLLBACK*` | rollback, emergency, recovery |

### 4. Verification

**After Sync**:
```bash
# Test semantic search
mcp__archon__rag_search_knowledge_base(
  query="wireguard mesh topology",
  match_count=3
)

# Should return results from INFRA.md
```

---

## 🔧 Configuration

### Archon Connection

**LAN (Current)**:
- URL: http://192.168.0.183:8052/mcp
- Status: ✅ Connected
- Speed: Fast (local network)

**Alternative** (if LAN unavailable):
- WireGuard: http://10.6.0.21:8051/mcp
- Tailscale: http://100.80.30.59:8051/mcp

### HTTP Server Settings

**Purpose**: Temporary document serving for crawling
**Port**: 8765 (configurable in script)
**Bind**: 192.168.0.183 (LAN interface)
**Lifetime**: Only during sync operation
**Cleanup**: Automatic shutdown after sync

### Sync Behavior

**Default Mode**: Manual reminder
**Optional Mode**: Auto-sync (must enable in hook)
**Frequency**: On-demand (after doc changes)
**Batch Mode**: Multiple docs in single operation

---

## 🐛 Troubleshooting

### Common Issues

**1. HTTP Server Port Conflict**

**Symptom**: "Address already in use" error

**Solution**:
```bash
# Check if port 8765 is in use
netstat -tuln | grep 8765

# Kill existing server
kill $(cat /tmp/archon-sync-http.pid)

# Or use alternative port
# Edit scripts/sync-archon-kb.sh: HTTP_PORT=8766
```

**2. Archon Crawl Timeout**

**Symptom**: Progress stuck, no completion after 10 minutes

**Solution**:
```bash
# Check Archon logs
docker logs archon-mcp --tail 50

# Restart Archon service
docker restart archon-mcp

# Retry sync
/sync-archon-kb
```

**3. Document Not Accessible**

**Symptom**: "Failed to fetch URL" error

**Solution**:
```bash
# Verify HTTP server is running
curl http://192.168.0.183:8765/docs/INFRA.md

# Check file exists
ls -la docs/INFRA.md

# Verify network connectivity
ping 192.168.0.183
```

**4. RAG Search Returns Nothing**

**Symptom**: Search after sync returns empty results

**Possible Causes**:
- Indexing not complete (wait 1-2 minutes)
- Wrong query terms (try different keywords)
- Document not actually uploaded (check sources list)

**Solution**:
```bash
# Check if source was added
mcp__archon__archon_get_knowledge_sources()

# Try broader search
rag_search_knowledge_base(query="AGL", match_count=5)

# Check Archon UI
open http://192.168.0.183:3737
```

---

## 📚 Usage Examples

### Example 1: Update Infrastructure Doc

```bash
# 1. Add new container to infrastructure
vim docs/INFRA.md
# ... add CT184 information ...

# 2. Commit changes
git add docs/INFRA.md
git commit -m "docs: add CT184 to infrastructure map"

# Output from git hook:
# 📚 Documentation changed, consider syncing to Archon Knowledge Base
# Changed documents:
#   - docs/INFRA.md
# Run: /sync-archon-kb

# 3. In Claude Code session
/sync-archon-kb

# 4. Verify
# Claude Code will search: "CT184 configuration"
# Should find the new content
```

### Example 2: Batch Sync Multiple Docs

```bash
# After updating multiple docs
git add docs/INFRA.md docs/WORKFLOWS.md docs/RULES.md
git commit -m "docs: comprehensive update"

# Sync all changed docs
./scripts/sync-archon-kb.sh --changed

# Or sync specific docs
./scripts/sync-archon-kb.sh docs/INFRA.md docs/WORKFLOWS.md
```

### Example 3: Verify Sync Success

```bash
# After sync, test searches
mcp__archon__rag_search_knowledge_base(
  query="wireguard configuration",
  match_count=3
)

# Should return results from INFRA.md with:
# - WireGuard IP addresses
# - Hub configuration
# - Mesh topology details
```

---

## 🎯 Best Practices

### When to Sync

✅ **DO Sync**:
- After adding new infrastructure (hosts, containers)
- After major workflow updates
- After changing coding standards
- After deployment procedure updates
- When new features are documented

❌ **DON'T Sync**:
- Minor typo fixes (batch with other changes)
- Comment-only changes
- Formatting-only changes
- Every single commit (batch daily/weekly)

### Sync Frequency

**Recommended**:
- **Infrastructure changes**: Immediately (critical for queries)
- **Workflow updates**: Same day
- **Minor doc updates**: Batch weekly
- **Typo fixes**: Don't sync individually

### Verification

**Always Verify After Sync**:
```bash
# 1. Check source was added
mcp__archon__archon_get_knowledge_sources()

# 2. Test semantic search
rag_search_knowledge_base(query="key terms from doc")

# 3. Verify content appears in results
# Results should include the document title and relevant content
```

---

## 📊 Current Sync Status

**Last Sync**: 2025-10-30 (INFRA.md)
**Status**: ✅ In Progress (crawling)
**Progress ID**: 3d81cb5d-d222-4937-959a-e4a71e0da7b5
**Next Check**: Wait 3-5 minutes, then verify

**To Verify Completion**:
```bash
# Check if INFRA.md appears in sources
mcp__archon__archon_get_knowledge_sources()

# Test search
mcp__archon__rag_search_knowledge_base(
  query="AGLSRV1 containers",
  match_count=3
)
```

---

## 🔗 Related Documentation

- **Archon Integration**: `docs/ARCHON.md`
- **MCP Tools Reference**: 28 tools available
- **Slash Commands**: `.claude/commands/`
- **Sync Script**: `scripts/sync-archon-kb.sh`
- **Git Hook**: `.git/hooks/post-commit`

---

## 📞 Support

**Archon Issues**:
- Check logs: `docker logs archon-mcp`
- Restart: `docker restart archon-mcp`
- Web UI: http://192.168.0.183:3737

**Script Issues**:
- Check script output
- Verify HTTP server: `curl http://192.168.0.183:8765/`
- Kill hung server: `kill $(cat /tmp/archon-sync-http.pid)`

---

**Status**: System operational and ready for use
**Next Sync**: On next documentation update
