# Archon Supabase Configuration Fix - January 2026

> **Date**: 2026-01-03
> **Issue**: Archon server crashing due to Supabase misconfiguration
> **Status**: ⚠️ Awaiting decision on Supabase deployment method
> **Priority**: 🟡 MEDIUM - Blocks Archon MCP functionality

---

## 🔍 Problem Summary

Archon MCP server is unavailable because archon-server cannot connect to Supabase backend.

### Current State

| Service | Status | Issue |
|---------|--------|-------|
| **archon-server** | ❌ Not running | Connection refused (exit code 1) |
| **archon-mcp** | ⚠️ Unhealthy | Depends on archon-server |
| **archon-ui** | ⚠️ Unhealthy | Depends on archon-server |

### Error Messages

```
httpx.ConnectError: [Errno 111] Connection refused
ERROR: Application startup failed. Exiting.
```

---

## 🕵️ Root Cause Analysis

### Timeline of Events

**December 2025** (from troubleshooting-notes.md):
- Original Supabase Cloud project deleted: `lqvprratqspfblzeqoqq.supabase.co`
- DNS resolution failed: NXDOMAIN

**Current Configuration** (January 2026):
- `.env` changed to: `SUPABASE_URL=http://host.docker.internal:8000`
- Intention: Use local Supabase instance
- **Problem**: No Supabase service running on port 8000!

### Current Configuration

```env
# /root/Archon/.env on CT183
SUPABASE_URL=http://host.docker.internal:8000
SUPABASE_SERVICE_KEY=<redacted>
ARCHON_SERVER_PORT=8181
ARCHON_MCP_PORT=8051
```

### Diagnosis

```bash
# Port 8000 is NOT in use
$ ss -tlnp | grep :8000
# (no output - nothing listening)

# archon-server tries to connect to host.docker.internal:8000
$ docker logs archon-server
httpx.ConnectError: [Errno 111] Connection refused
```

---

## ✅ Solution Options

### Option 1: Supabase Cloud (Recommended - Fastest)

**Pros**:
- Quick setup (5-10 minutes)
- Fully managed (no maintenance)
- Free tier available
- Automatic backups
- Built-in auth & realtime

**Cons**:
- Requires internet connection
- Data stored externally
- Free tier has limits

**Steps**:

1. **Create Supabase Project**:
   ```
   Visit: https://supabase.com/dashboard
   - Sign up / Log in
   - Create new project
   - Wait for provisioning (~2 minutes)
   ```

2. **Get Credentials**:
   ```
   Project Settings → API
   - Copy "Project URL" (https://xxxxx.supabase.co)
   - Copy "service_role" key (NOT anon key!)
   ```

3. **Initialize Database**:
   ```
   SQL Editor → Run:
   /root/Archon/migration/complete_setup.sql
   ```

4. **Update Archon Configuration**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/Archon
   # Backup current .env
   cp .env .env.backup.$(date +%Y%m%d)

   # Update Supabase URL
   sed -i 's|SUPABASE_URL=.*|SUPABASE_URL=https://YOUR_PROJECT.supabase.co|' .env

   # Update service key
   sed -i 's|SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=YOUR_SERVICE_KEY|' .env
   "'
   ```

5. **Restart Services**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/Archon
   docker compose down
   docker compose up -d
   "'
   ```

6. **Verify**:
   ```bash
   # Check containers
   ssh root@192.168.0.245 'pct exec 183 -- docker compose ps'

   # Check logs
   ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server --tail 20'

   # Test MCP endpoint
   curl http://192.168.0.183:8051/mcp
   ```

---

### Option 2: Self-Hosted Supabase (Local)

**Pros**:
- Complete control
- Data stays local
- No external dependencies
- No usage limits

**Cons**:
- More complex setup
- Requires maintenance
- Uses more resources (~4GB RAM)
- Manual backups needed

**Steps**:

1. **Clone Supabase**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root
   git clone --depth 1 https://github.com/supabase/supabase
   cd supabase/docker
   cp .env.example .env
   "'
   ```

2. **Configure Supabase**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/supabase/docker

   # Generate secure passwords
   POSTGRES_PASSWORD=\$(openssl rand -hex 32)
   JWT_SECRET=\$(openssl rand -hex 32)
   ANON_KEY=\$(openssl rand -hex 32)
   SERVICE_KEY=\$(openssl rand -hex 32)

   # Update .env file
   sed -i \"s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=\$POSTGRES_PASSWORD/\" .env
   sed -i \"s/JWT_SECRET=.*/JWT_SECRET=\$JWT_SECRET/\" .env
   sed -i \"s/ANON_KEY=.*/ANON_KEY=\$ANON_KEY/\" .env
   sed -i \"s/SERVICE_ROLE_KEY=.*/SERVICE_ROLE_KEY=\$SERVICE_KEY/\" .env

   # Save service key for later
   echo \$SERVICE_KEY > /root/supabase_service_key.txt
   "'
   ```

3. **Start Supabase**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/supabase/docker
   docker compose up -d
   "'
   ```

4. **Initialize Database**:
   ```bash
   # Wait for Supabase to start (~30 seconds)
   sleep 30

   # Run Archon migration
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   # Copy SQL to Supabase postgres container
   docker cp /root/Archon/migration/complete_setup.sql supabase-db:/tmp/

   # Execute SQL
   docker exec supabase-db psql -U postgres -d postgres -f /tmp/complete_setup.sql
   "'
   ```

5. **Update Archon Configuration**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/Archon

   # Get service key
   SERVICE_KEY=\$(cat /root/supabase_service_key.txt)

   # Backup and update .env
   cp .env .env.backup.$(date +%Y%m%d)
   sed -i 's|SUPABASE_URL=.*|SUPABASE_URL=http://host.docker.internal:8000|' .env
   sed -i \"s|SUPABASE_SERVICE_KEY=.*|SUPABASE_SERVICE_KEY=\$SERVICE_KEY|\" .env
   "'
   ```

6. **Restart Archon**:
   ```bash
   ssh root@192.168.0.245 'pct exec 183 -- bash -c "
   cd /root/Archon
   docker compose down
   docker compose up -d
   "'
   ```

---

## 🔧 Additional Fixes Needed

### Fix Health Check Syntax Error

Current docker-compose.yml has broken health checks:

```yaml
# BROKEN - missing quotes in Python string
healthcheck:
  test: ["CMD", "sh", "-c", "python -c \"import socket; s=socket.socket(); s.connect((localhost, 8051)); s.close()\""]

# FIXED - quoted string
healthcheck:
  test: ["CMD", "sh", "-c", "python -c \"import socket; s=socket.socket(); s.connect(('localhost', 8051)); s.close()\""]
```

**Fix**:
```bash
ssh root@192.168.0.245 'pct exec 183 -- bash -c "
cd /root/Archon
# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Fix health check (add quotes around localhost)
sed -i \"s/s.connect((localhost,/s.connect(('localhost',/\" docker-compose.yml
sed -i \"s/8051));/8051));/\" docker-compose.yml
"'
```

---

## 🧪 Verification Steps

After applying fix:

```bash
# 1. Check all containers healthy
ssh root@192.168.0.245 'pct exec 183 -- docker compose ps'
# Expected: All "healthy" status

# 2. Check archon-server logs
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-server --tail 30'
# Expected: No connection errors, "Uvicorn running"

# 3. Test MCP endpoint
curl http://192.168.0.183:8051/mcp
# Expected: JSON-RPC error about SSE (normal for curl)

# 4. Test from Claude Code
claude mcp list
# Expected: archon and archon-tailscale both "Connected"

# 5. Test MCP functionality
# In Claude Code, try:
# mcp__archon__find_projects()
```

---

## 📊 Decision Matrix

| Criteria | Supabase Cloud | Self-Hosted |
|----------|----------------|-------------|
| **Setup Time** | ⚡ 5-10 min | ⏱️ 30-60 min |
| **Maintenance** | ✅ Zero | ⚙️ Ongoing |
| **Resources** | ☁️ External | 💾 ~4GB RAM |
| **Data Privacy** | ⚠️ Cloud | ✅ Local |
| **Reliability** | ✅ 99.9% | ⚠️ Self-managed |
| **Backups** | ✅ Automatic | ⚙️ Manual |
| **Internet Req.** | ⚠️ Required | ✅ Not needed |

**Recommendation**:
- **Quick Fix**: Supabase Cloud (Option 1)
- **Long Term**: Self-Hosted if data privacy is critical

---

## 🎯 Impact Assessment

### Current Impact

**Blocked Functionality**:
- ❌ Archon MCP tools unavailable in Claude Code
- ❌ Task management via `find_tasks`, `manage_task`
- ❌ Knowledge base search via `rag_search_knowledge_base`
- ❌ Project management via `find_projects`, `manage_project`
- ❌ Document management via `find_documents`

**Workarounds**:
- Use local task tracking (markdown files)
- Use GitHub Issues for project management
- Use local documentation files
- Use other MCP servers (dokploy, harbor, proxmox, etc.)

### After Fix

**Restored Functionality**:
- ✅ All 28 Archon MCP tools available
- ✅ Centralized task tracking
- ✅ RAG knowledge base search
- ✅ Project and document management
- ✅ Version control and history

---

## 📝 Related Issues

**From troubleshooting-notes.md (2025-12-12)**:
- Original Supabase project `lqvprratqspfblzeqoqq` deleted
- DNS resolution failed for Cloud instance
- Attempted local setup but never completed

**Additional Findings (2026-01-03)**:
- Configuration changed to `host.docker.internal:8000`
- No Supabase service running on port 8000
- archon-server crashloop on startup
- Health check syntax errors in docker-compose.yml

---

## ✅ Next Steps

**User Decision Required**:

1. Choose deployment method:
   - [ ] **Option 1**: Create Supabase Cloud project (faster)
   - [ ] **Option 2**: Deploy Supabase locally (more control)

2. After choosing, execute the corresponding steps above

3. Fix health check syntax error

4. Verify all services healthy

5. Test MCP functionality

---

## 📚 References

- **Archon Documentation**: `docs/ARCHON.md`
- **Previous Troubleshooting**: `docs/updates/archon-troubleshooting-notes.md`
- **Supabase Cloud**: https://supabase.com/dashboard
- **Supabase Self-Hosted**: https://github.com/supabase/supabase
- **Archon GitHub**: https://github.com/coleam00/Archon

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-03
**Created By**: Claude Code
**Status**: Awaiting user decision on Supabase deployment method
