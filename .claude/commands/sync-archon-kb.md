# Sync Documentation to Archon Knowledge Base

When the user runs `/sync-archon-kb`, synchronize updated documentation to Archon Knowledge Base.

## Task

You are responsible for syncing documentation changes to the Archon Knowledge Base via MCP.

## Workflow

### 1. Detect Changed Documentation

Check for modified documentation files:
```bash
git diff --name-only HEAD~1 HEAD | grep -E "^docs/.*\.md$"
```

### 2. For Each Changed Document

**Priority Documents** (always sync):
- `docs/INFRA.md` - Infrastructure map
- `docs/ARCHON.md` - Archon integration guide
- `docs/WORKFLOWS.md` - Development workflows
- `docs/RULES.md` - Coding standards
- `CLAUDE.md` - Project navigation hub

**Deployment Documents** (sync if changed):
- `docs/DEPLOYMENT-GUIDE.md`
- `docs/HARBOR-REGISTRY.md`
- `docs/DOKPLOY-DEPLOYMENT.md`
- `docs/TROUBLESHOOTING-DEPLOY.md`
- `docs/ROLLBACK-PROCEDURE.md`

### 3. Sync Process

For each document to sync:

**A. Start Temporary HTTP Server** (if not running):
```bash
cd /path/to/docs
python3 -m http.server 8765 --bind 192.168.0.183 &
echo $! > /tmp/http-server.pid
```

**B. Add/Update in Archon**:
```typescript
// Use MCP tool
mcp__archon__archon_add_knowledge_source({
  source_type: "website",
  url: `http://192.168.0.183:8765/${filename}`,
  name: documentTitle,
  description: documentSummary,
  knowledge_type: "technical",
  tags: relevantTags,
  max_depth: 1
})
```

**C. Cleanup**:
```bash
# Stop HTTP server after all syncs
kill $(cat /tmp/http-server.pid)
rm /tmp/http-server.pid
```

### 4. Verification

After sync, verify with search:
```typescript
mcp__archon__rag_search_knowledge_base({
  query: "key terms from document",
  match_count: 3
})
```

### 5. Report Results

Output summary:
```
✅ Synced to Archon Knowledge Base:
  - docs/INFRA.md → source_id: abc123
  - docs/WORKFLOWS.md → source_id: def456

⏭️ Skipped (no changes):
  - docs/ARCHON.md
  - CLAUDE.md

❌ Failed:
  - docs/NEW-DOC.md → Error: timeout

📊 Total: 2 synced, 2 skipped, 1 failed
```

## Configuration

**Archon Connection** (LAN):
- URL: http://192.168.0.183:8052/mcp
- Status: Connected via `mcp__archon__*` tools

**HTTP Server**:
- Port: 8765
- Bind: 192.168.0.183 (LAN interface)
- Purpose: Temporary document serving for crawling

## Tags by Document Type

**Infrastructure**:
- `infrastructure`, `network`, `wireguard`, `proxmox`, `docker`, `storage`

**Development**:
- `workflows`, `sparc`, `agent-os`, `development`, `automation`

**Standards**:
- `coding-standards`, `rules`, `best-practices`, `guidelines`

**Deployment**:
- `deployment`, `harbor`, `dokploy`, `ci-cd`, `troubleshooting`, `rollback`

## Error Handling

**Common Issues**:

1. **HTTP Server Failed**
   - Check port 8765 available: `netstat -tuln | grep 8765`
   - Use alternative port: `python3 -m http.server 8766`

2. **Archon Timeout**
   - Document too large: Split into sections
   - Retry with smaller max_depth

3. **Crawl Failed**
   - Verify URL accessible: `curl http://192.168.0.183:8765/docs/INFRA.md`
   - Check Archon logs: `docker logs archon-mcp`

## Best Practices

✅ **DO**:
- Sync after major documentation updates
- Include relevant tags for discoverability
- Verify sync success with search test
- Cleanup temporary HTTP server

❌ **DON'T**:
- Sync every minor typo fix (batch changes)
- Leave HTTP server running indefinitely
- Sync without testing document accessibility
- Forget to update document descriptions

## Examples

**Manual Sync After Doc Update**:
```
User: "Updated INFRA.md with new container CT184"
Assistant: "I'll sync the updated INFRA.md to Archon Knowledge Base"
[Runs /sync-archon-kb command]
[Reports: ✅ INFRA.md synced → source_id: xyz789]
```

**Automatic Sync (Git Hook)**:
```bash
# .git/hooks/post-commit
#!/bin/bash
if git diff --name-only HEAD~1 HEAD | grep -q "^docs/.*\.md$"; then
  echo "📚 Documentation changed, syncing to Archon..."
  # Trigger sync via API or script
fi
```

## Integration with Git Workflow

This command should be:
1. **Manual**: Available as `/sync-archon-kb` for on-demand sync
2. **Automatic**: Triggered by git hook on doc changes (optional)
3. **CI/CD**: Run in GitHub Actions on doc updates (future)

---

**Related Commands**:
- `/create-tasks` - Task decomposition
- `/implement-tasks` - Implementation with TDD
- No other sync commands currently exist
