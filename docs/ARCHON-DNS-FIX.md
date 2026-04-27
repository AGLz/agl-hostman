# Archon DNS Fix - 2025-10-29

## Problem Summary
Archon WebUI was not accessible due to DNS resolution failures in CT183.

## Root Cause
**Tailscale DNS server (100.100.100.100) request queue was full**, causing all DNS lookups to time out:
- archon-server could not resolve Supabase URL (lqvprratqspfblzeqoqq.supabase.co)
- Error: `[Errno -3] Temporary failure in name resolution`
- Container startup failed during initialization when trying to connect to Supabase

## Solution Applied

### 1. Fixed System DNS (/etc/resolv.conf)
```bash
# Added fallback DNS servers:
nameserver 100.100.100.100  # Tailscale (primary, but failing)
nameserver 1.1.1.1           # Cloudflare DNS (fallback)
nameserver 8.8.8.8           # Google DNS (fallback)
search degu-chromatic.ts.net aglz.io
```

### 2. Fixed Docker DNS (/etc/docker/daemon.json)
```json
{
  "default-address-pools": [
    {"base": "172.17.0.0/16", "size": 24}
  ],
  "features": {
    "buildkit": false
  },
  "dns": ["1.1.1.1", "8.8.8.8"]
}
```

### 3. Restarted Services
```bash
# Restart Docker daemon to apply DNS config
systemctl restart docker

# Start all Archon containers
docker start archon-server archon-mcp archon-ui
```

## Verification

### ✅ DNS Resolution Working
```bash
$ nslookup lqvprratqspfblzeqoqq.supabase.co
Server:		1.1.1.1
Address:	1.1.1.1#53

Name:	lqvprratqspfblzeqoqq.supabase.co
Address: 104.18.38.10
Address: 172.64.149.246
```

### ✅ Archon Server Healthy
```bash
$ curl http://192.168.0.183:8181/health
{
  "status":"healthy",
  "service":"archon-backend",
  "timestamp":"2025-10-29T18:46:24.160840",
  "ready":true,
  "credentials_loaded":true,
  "schema_valid":true
}
```

### ✅ WebUI Accessible
```bash
$ curl -I http://192.168.0.183:3737/
HTTP/1.1 200 OK
Content-Type: text/html
```

### ✅ Logs Show Success
```
2025-10-29 18:45:37 | src.server.main | INFO | ✅ Credentials initialized
2025-10-29 18:45:38 | api | INFO | 🎉 Archon backend started successfully!
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8181 (Press CTRL+C to quit)
```

## Container Status
```
NAMES           STATUS                                 PORTS
archon-server   Up About a minute (health: starting)   0.0.0.0:8181->8181/tcp
archon-ui       Up About a minute (unhealthy)          0.0.0.0:3737->3737/tcp
archon-mcp      Up About a minute (health: starting)   0.0.0.0:8051->8051/tcp
```

**Note**: Health check status shows "starting"/"unhealthy" but containers are actually working correctly (confirmed by direct endpoint testing).

## Access Points

### Internal Access (CT183 LAN):
- **WebUI**: http://192.168.0.183:3737
- **API**: http://192.168.0.183:8181
- **MCP**: http://192.168.0.183:8051

### WireGuard Access:
- **WebUI**: http://10.6.0.21:3737
- **API**: http://10.6.0.21:8181
- **MCP**: http://10.6.0.21:8051

### Tailscale Access:
- **WebUI**: http://100.80.30.59:3737
- **API**: http://100.80.30.59:8181
- **MCP**: http://100.80.30.59:8051

### Public Access:
- **WebUI**: https://archon.aglz.io (Basic Auth: admin/ArchonPass2025)

## Future Prevention

### Monitor Tailscale DNS
Watch for these log messages indicating DNS overload:
```
dns udp query: request queue full
[RATELIMIT] format("dns udp query: %v")
```

### Permanent Solution Options
1. **Disable Tailscale DNS management** in CT183 if not needed
2. **Increase Tailscale DNS queue size** (if possible via configuration)
3. **Keep fallback DNS servers** in both /etc/resolv.conf and Docker daemon.json
4. **Consider using systemd-resolved** with Tailscale for better DNS management

## Commands for Quick Recovery

If DNS issues occur again:

```bash
# Fix system DNS
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf

# Fix Docker DNS
cat > /etc/docker/daemon.json << 'EOF'
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF

# Restart and test
systemctl restart docker
docker restart archon-server archon-mcp archon-ui
curl http://localhost:8181/health
```

---

**Resolution Time**: ~20 minutes
**Status**: ✅ RESOLVED
**Impact**: WebUI and API now fully operational
