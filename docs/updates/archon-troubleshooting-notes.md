# Archon Troubleshooting Notes - 2025-12-12

## Problem Summary

Archon server (CT183) cannot start due to missing Supabase instance.

## Current Status

- **Archon Version**: renatabk/archon-server:latest
- **archon-server**: Exited (exit code 3) - Cannot connect to Supabase
- **archon-ui**: Up but unhealthy (waiting for server)
- **archon-mcp**: Up but unhealthy (waiting for server)

## Root Cause

**The configured Supabase instance no longer exists**:
- **Configured URL**: `https://lqvprratqspfblzeqoqq.supabase.co`
- **DNS Resolution**: NXDOMAIN (domain does not exist)
- **Tested from**: CT183, Proxmox host, multiple DNS servers (Tailscale, Google, Cloudflare)
- **Conclusion**: Supabase project was deleted or is no longer accessible

## Error Details

```
httpx.ConnectError: [Errno -2] Name or service not known
ERROR: Application startup failed. Exiting.
Exit Code: 3
```

## Configuration Location

- **Archon Directory**: `/root/Archon/` in CT183
- **Environment File**: `/root/Archon/.env`
- **Supabase URL**: `SUPABASE_URL=https://lqvprratqspfblzeqoqq.supabase.co`
- **Service Key**: `SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

## Secondary Issues Found

1. **DNS Configuration**: CT183 was using Tailscale DNS (100.100.100.100) exclusively
   - **Fixed**: Added fallback DNS (8.8.8.8, 1.1.1.1) to `/etc/resolv.conf`
   - However, this revealed the real issue: Supabase instance doesn't exist

2. **Health Check Syntax Error** in docker-compose.yml:
   ```yaml
   # Current (BROKEN):
   healthcheck:
     test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen(http://localhost:8181/health)"]

   # Should be:
   healthcheck:
     test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8181/health')"]
   ```

## Resolution Options

### Option 1: Create New Supabase Cloud Instance (Recommended)

1. **Create Supabase project**: https://supabase.com/dashboard
2. **Get credentials**:
   - Project URL (e.g., `https://xxxxx.supabase.co`)
   - Service Role Key (from API settings)
3. **Update Archon .env file**:
   ```bash
   cd /root/Archon
   nano .env
   # Update SUPABASE_URL and SUPABASE_SERVICE_KEY
   ```
4. **Restart Archon**:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Option 2: Deploy Local Supabase (Self-Hosted)

1. **Clone Supabase**:
   ```bash
   cd /root
   git clone --depth 1 https://github.com/supabase/supabase
   cd supabase/docker
   cp .env.example .env
   ```

2. **Configure**:
   ```bash
   nano .env
   # Set POSTGRES_PASSWORD, JWT_SECRET, etc.
   ```

3. **Start Supabase**:
   ```bash
   docker compose up -d
   ```

4. **Update Archon to use local Supabase**:
   ```bash
   cd /root/Archon
   nano .env
   # Set SUPABASE_URL=http://localhost:8000 (or Kong gateway port)
   # Set SUPABASE_SERVICE_KEY from Supabase .env
   ```

### Option 3: Use Alternative Backend

Check if Archon supports other backends besides Supabase. Review documentation at:
- https://github.com/renatabk/archon

## Temporary Workaround

**Archon MCP server will remain unavailable** until Supabase backend is configured.

**Impact**:
- No Archon MCP tools available in Claude Code
- No task management via Archon
- No knowledge base search

**Alternatives** while Archon is down:
- Use local file-based task tracking
- Use GitHub Issues for task management
- Use local documentation instead of Archon knowledge base

## Next Steps

1. **Decide on Supabase approach**: Cloud (Option 1) vs Self-hosted (Option 2)
2. **Create/configure Supabase instance**
3. **Update Archon .env with new credentials**
4. **Fix health check syntax error in docker-compose.yml**
5. **Restart all Archon containers**
6. **Verify Archon MCP endpoint**: `http://10.6.0.21:8051/mcp`

## Priority

🟡 **MEDIUM** - Archon is important for task management and knowledge base but not blocking other infrastructure updates.

**Recommendation**: Proceed with updating other containers (Ollama, Open WebUI, LiteLLM, n8n, CacheNG) first, then return to set up Supabase for Archon.

## Last Updated

2025-12-12 17:30 UTC
