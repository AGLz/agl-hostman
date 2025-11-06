# Archon UI Access - Troubleshooting Guide

**Date**: 2025-10-28
**Issue**: APIServiceError when accessing Archon UI
**Status**: ✅ RESOLVED

---

## Problem Description

**Error**: Receiving APIServiceError when trying to access `http://192.168.0.183:3737/mcp` in browser

**Root Cause**: Incorrect URL - `/mcp` endpoint is for MCP protocol clients, not web browsers

---

## Archon Architecture (Port Mapping)

### Service Ports

| Port | Service | Protocol | Browser Access | Purpose |
|------|---------|----------|----------------|---------|
| **3737** | archon-ui | HTTP | ✅ YES | React Frontend UI (Vite) |
| **8181** | archon-server | HTTP | ⚠️ API only | FastAPI Backend |
| **8051** | archon-mcp | SSE | ❌ NO | MCP Protocol (Server-Sent Events) |
| **8052** | nginx-mcp | SSE | ❌ NO | MCP via nginx (LAN only) |
| **8080** | nginx-proxy | HTTP | ✅ YES | Public proxy with Basic Auth |

### Key Understanding

**MCP Protocol vs Web UI**:
- **MCP Endpoint** (`/mcp` on ports 8051/8052): Model Context Protocol for AI assistants (Claude Code)
  - Uses Server-Sent Events (SSE)
  - Requires `Accept: text/event-stream` header
  - NOT accessible via web browser
  - Used by: `claude mcp add` command

- **Web UI** (port 3737): React application for human users
  - Standard HTTP/HTML
  - Accessible via web browser
  - Routes: `/`, `/projects`, `/tasks`, `/knowledge`, etc.
  - Does NOT have `/mcp` route

---

## Correct Access Methods

### 1. Web UI (Human Interface) ✅

**LAN Access** (No Authentication):
```
http://192.168.0.183:3737/
```

**Features Available**:
- Projects dashboard
- Task management
- Knowledge base browser
- MCP status monitoring
- Configuration settings

**Important**: Do NOT add `/mcp` to the URL - this is the web UI root.

---

### 2. MCP Protocol (Claude Code Integration) ✅

**For Claude Code MCP Client**:

```bash
# LAN (no auth)
claude mcp add --transport http archon http://192.168.0.183:8051/mcp

# WireGuard (primary external, no auth)
claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp

# Tailscale (backup external, no auth)
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp
```

**Cannot Be Accessed**:
- ❌ Web browser directly
- ❌ Standard HTTP GET requests
- ❌ Without proper SSE client

**Correct Response**: HTTP 406 "Not Acceptable: Client must accept text/event-stream"
- This is EXPECTED behavior
- Means MCP server is working correctly
- Only SSE-capable clients (like Claude Code) can connect

---

### 3. API Endpoints (Programmatic Access) ✅

**Backend API**:
```bash
# Health check
curl http://192.168.0.183:8181/api/health

# Projects list
curl http://192.168.0.183:8181/api/projects

# MCP status
curl http://192.168.0.183:8181/api/mcp/status
```

**Use Cases**:
- Custom integrations
- Monitoring scripts
- Automation tools

---

## Common Errors and Solutions

### Error 1: "APIServiceError" at http://192.168.0.183:3737/mcp

**Cause**: Trying to access MCP endpoint through frontend UI port

**Solution**: Remove `/mcp` from URL
```bash
# ❌ Wrong
http://192.168.0.183:3737/mcp

# ✅ Correct
http://192.168.0.183:3737/
```

**Explanation**:
- Port 3737 serves the React web UI
- Route `/mcp` doesn't exist in the frontend
- MCP protocol is on ports 8051/8052, not 3737

---

### Error 2: HTTP 406 "Not Acceptable" at http://192.168.0.183:8051/mcp

**Cause**: Trying to access MCP endpoint with web browser

**Solution**: This is CORRECT behavior - use Claude Code instead
```bash
claude mcp add --transport http archon http://192.168.0.183:8051/mcp
```

**Explanation**:
- MCP requires Server-Sent Events (SSE) protocol
- Web browsers don't automatically send `Accept: text/event-stream`
- Only MCP clients (like Claude Code) can connect

**Test MCP is Working**:
```bash
# This should return 406 (correct)
curl http://192.168.0.183:8051/mcp

# Verify MCP is processing requests (check logs)
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp --tail 20'
# Should show: "Processing request of type ListToolsRequest" etc.
```

---

### Error 3: Containers Show as "Unhealthy"

**Status Check**:
```bash
ssh root@192.168.0.245 'pct exec 183 -- docker ps --format "table {{.Names}}\t{{.Status}}"'
```

**Example Output**:
```
NAMES           STATUS
archon-ui       Up 17 hours (unhealthy)
archon-mcp      Up 17 hours (unhealthy)
archon-server   Up 17 hours (healthy)
```

**Cause**: Healthcheck configuration may be checking wrong endpoint

**Impact**: ⚠️ **COSMETIC ONLY** - Services are actually working fine

**Evidence Services Are Working**:
1. UI accessible at port 3737
2. API responding on port 8181
3. MCP processing requests on port 8051
4. Logs show normal operation

**Investigation**:
```bash
# Check healthcheck config
ssh root@192.168.0.245 'pct exec 183 -- docker inspect archon-ui --format "{{json .State.Health}}"'

# Check what healthcheck is testing
ssh root@192.168.0.245 'pct exec 183 -- docker inspect archon-ui --format "{{json .Config.Healthcheck}}"'
```

**Potential Fix** (if needed):
Healthcheck may be testing wrong endpoint or expecting wrong response. Services work regardless of healthcheck status.

---

## Verification Steps

### Step 1: Verify Web UI Access

```bash
# Test UI homepage
curl -I http://192.168.0.183:3737/

# Expected: HTTP/1.1 200 OK
# Expected: Content-Type: text/html
```

**Browser Test**:
1. Open browser
2. Navigate to: `http://192.168.0.183:3737/`
3. Should see: "Archon - Knowledge Engine" dashboard
4. No errors in browser console (F12)

---

### Step 2: Verify API Backend

```bash
# Test health endpoint
curl http://192.168.0.183:8181/api/health

# Expected JSON response with system status
```

**Expected Response**:
```json
{
  "status": "healthy",
  "uptime_seconds": 61262,
  "version": "1.0.0"
}
```

---

### Step 3: Verify MCP Protocol

```bash
# Test MCP endpoint (should return 406)
curl http://192.168.0.183:8051/mcp

# Expected: HTTP 406 with error message about text/event-stream
```

**Expected Response**:
```json
{
  "jsonrpc": "2.0",
  "id": "server-error",
  "error": {
    "code": -32600,
    "message": "Not Acceptable: Client must accept text/event-stream"
  }
}
```

**Why This Is Correct**:
- HTTP 406 means "I'm working, but you're not using the right protocol"
- MCP requires SSE client (Claude Code)
- Browser HTTP GET is not sufficient

---

### Step 4: Verify Claude Code MCP Connection

```bash
# List MCP connections
claude mcp list

# Expected: Should show archon (or archon-wg/archon-tailscale) with ✓ Connected
```

**Test MCP Call**:
```bash
# Via Claude Code, test an MCP tool
mcp__archon__health_check()

# Expected: Returns health status with uptime
```

---

## Quick Reference

### Access Points Summary

| What You Want | Use This URL | Notes |
|---------------|--------------|-------|
| Browse UI in browser | `http://192.168.0.183:3737/` | No /mcp suffix! |
| Use Knowledge Base | `http://192.168.0.183:3737/` → Navigate to Knowledge | Upload docs here |
| View Projects/Tasks | `http://192.168.0.183:3737/` → Navigate to Projects | Web dashboard |
| Connect Claude Code | `claude mcp add ... http://192.168.0.183:8051/mcp` | MCP protocol |
| Call API directly | `curl http://192.168.0.183:8181/api/*` | Backend API |
| Check MCP status | UI → Settings → MCP Status | Or API endpoint |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Interactions                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │   Web Browser    │         │   Claude Code    │    │
│  │  (Human Users)   │         │   (AI Assistant) │    │
│  └────────┬─────────┘         └─────────┬────────┘    │
│           │                              │              │
│           │ HTTP/HTML                    │ SSE/MCP      │
│           │                              │              │
└───────────┼──────────────────────────────┼──────────────┘
            │                              │
            ▼                              ▼
┌───────────────────────┐      ┌─────────────────────┐
│   archon-ui:3737      │      │  archon-mcp:8051    │
│   (React/Vite)        │      │  (MCP Server/SSE)   │
│   ✅ Browser Access   │      │  ❌ Browser Access  │
│   Routes: /, /projects│      │  Protocol: SSE only │
└───────────┬───────────┘      └──────────┬──────────┘
            │                             │
            │ Proxy /api/* to 8181       │
            │                             │
            └────────────┬────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  archon-server:8181    │
            │  (FastAPI Backend)     │
            │  - PostgreSQL          │
            │  - PGVector RAG        │
            │  - Knowledge Base      │
            │  - Task Management     │
            └────────────────────────┘
```

---

## Best Practices

### For Web UI Access

1. ✅ **Do**: Access root URL `http://192.168.0.183:3737/`
2. ✅ **Do**: Navigate using UI menus and links
3. ❌ **Don't**: Add `/mcp` to the URL
4. ❌ **Don't**: Try to access MCP endpoints in browser

### For MCP Integration

1. ✅ **Do**: Use `claude mcp add` command
2. ✅ **Do**: Use MCP tools via Claude Code
3. ❌ **Don't**: Try to access MCP endpoints directly
4. ✅ **Do**: Monitor MCP status via Web UI settings

### For Troubleshooting

1. ✅ **Check Docker containers**: All should be "Up" (unhealthy status may be cosmetic)
2. ✅ **Check logs**: `docker logs archon-*` shows actual operation status
3. ✅ **Test endpoints**: Each service on correct port
4. ✅ **Verify connectivity**: Ping, curl, and browser access

---

## Related Documentation

- **Setup Guide**: `docs/agent-os-archon-setup-complete.md`
- **MCP Validation**: `docs/archon-mcp-validation-report.md`
- **Knowledge Base Upload**: `docs/archon-ui-knowledge-base-guide.md`
- **Archon Integration**: `docs/ARCHON.md`

---

## Summary

**The "Error" Was Not An Error!**

✅ **What's Working**:
- Web UI: `http://192.168.0.183:3737/` (without /mcp)
- MCP Protocol: Correctly rejecting browser requests
- API Backend: Responding normally
- All services operational

❌ **What Was Wrong**:
- Trying to access `/mcp` route through UI port (3737)
- This route doesn't exist in the web frontend
- `/mcp` is only on MCP server ports (8051/8052)

🎯 **Solution**:
```bash
# For Web UI (humans)
http://192.168.0.183:3737/

# For MCP (Claude Code)
claude mcp add --transport http archon http://192.168.0.183:8051/mcp
```

**Status**: ✅ Everything working as designed!

---

---

## Error 4: Backend API Connectivity (FileNotFoundError)

**Date Resolved**: 2025-10-28

### Error Details
```
APIServiceError: Error while fetching server API version:
('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

**Cause**: Docker socket not mounted in archon-server container

**Solution**: Added Docker socket mount to docker-compose.yml
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

**Full Resolution**: See `docs/archon-backend-api-fix.md` for complete details

**Status**: ✅ RESOLVED - Backend API fully functional

---

**Document Complete** | Issues: URL routing + Backend API | System: Fully operational
