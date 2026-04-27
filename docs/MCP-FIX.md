# Archon MCP Access Fix

**Date**: 2025-01-05
**Issue**: Archon MCP server not accessible
**Status**: ✅ FIXED

## Problem

Archon MCP tools were failing with connection errors. The MCP configuration was pointing to an unreachable IP address.

## Root Cause

The MCP configuration in `/root/.claude/mcp.json` had the Archon server configured as:

```json
"archon": {
  "transport": "http",
  "url": "http://10.6.0.21:8051/mcp"
}
```

**Problem**: `10.6.0.21` is a WireGuard IP that is **not accessible** (100% packet loss).

## Network Analysis

Tested all available network paths to CT183:

| Network | IP | Status | Latency |
|---------|-----|--------|---------|
| ❌ WireGuard | 10.6.0.21 | **DOWN** | 100% packet loss |
| ✅ Tailscale | 100.80.30.59 | **UP** | ~0.5ms |
| ✅ LAN | 192.168.0.183 | **UP** | <1ms |

## Solution

Updated MCP configuration to use the **LAN IP** (fastest and most reliable):

```json
"archon": {
  "transport": "http",
  "url": "http://192.168.0.183:8051/mcp"
}
```

**Why LAN IP?**
- Lowest latency (<1ms vs 0.5ms for Tailscale)
- Direct network path (no VPN overhead)
- Always available when on local network
- Backup configuration: `archon-tailscale` points to Tailscale IP

## Verification

Tested MCP endpoint connectivity:

```bash
# Via LAN (new configuration)
curl -H "Accept: text/event-stream" http://192.168.0.183:8051/mcp
# Response: {"jsonrpc":"2.0","id":"server-error","error":{"code":-32600,"message":"Bad Request: Missing session ID"}}
# ✅ Server is responding (error is expected without proper session)

# Via Tailscale (backup)
curl -H "Accept: text/event-stream" http://100.80.30.59:8051/mcp
# Response: Same as above
# ✅ Backup path working
```

## Changes Made

### 1. Updated MCP Configuration

**File**: `/root/.claude/mcp.json`
**Backup**: `/root/.claude/mcp.json.backup-20250105-HHMMSS`

```diff
- "url": "http://10.6.0.21:8051/mcp"
+ "url": "http://192.168.0.183:8051/mcp"
```

### 2. Available MCP Configurations

Now there are **two** Archon MCP configurations:

1. **archon** (primary) - `http://192.168.0.183:8051/mcp` (LAN)
2. **archon-tailscale** (backup) - `http://100.80.30.59:8051/mcp` (Tailscale)

### 3. Verification Steps

To verify the fix works:

```bash
# Check MCP server status
claude mcp list | grep archon

# Expected output:
# archon: http://192.168.0.183:8051/mcp (HTTP) - ✓ Connected
# archon-tailscale: http://100.80.30.59:8051/mcp (HTTP) - ✓ Connected
```

## Network Topology

```
┌─────────────────────────────────────────────────────┐
│ This Machine (agldv03 - 192.168.0.179)             │
│                                                     │
│  Interfaces:                                        │
│  - eth0: 192.168.0.179 (LAN)                       │
│  - wg0: 10.6.0.19 (WireGuard)                      │
│  - tailscale0: 100.80.x.x (Tailscale)              │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Network Paths
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌────────┐  ┌────────┐  ┌──────────┐
│ Wire   │  │Tail-   │  │   LAN    │
│Guard   │  │scale   │  │          │
│10.6.0.21│  │100.80  │  │192.168.0 │
│   ❌   │  │  .30.59│  │   .183   │
│        │  │   ✅   │  │    ✅    │
└────────┘  └────────┘  └──────┬───┘
                                  │
                         ┌────────▼─────────┐
                         │ CT183 (Archon)   │
                         │ archon-mcp:8051  │
                         └──────────────────┘
```

## Future Improvements

1. **Fix WireGuard**: Investigate why 10.6.0.21 is not accessible
   - Check WireGuard configuration on CT183
   - Verify peer configuration
   - Check firewall rules

2. **Automatic Failover**: Implement automatic switching between LAN and Tailscale
   - Use health checks to determine best path
   - Automatically switch to backup if primary fails

3. **Documentation**: Update CT183-STARTUP-GUIDE.md with network configuration details

## Related Files

- `/root/.claude/mcp.json` - MCP configuration
- `./docs/CT183-STARTUP-GUIDE.md` - Startup guide
- `./docs/updates/archon-supabase-integration-success.md` - Integration details

## Troubleshooting

If MCP becomes inaccessible again:

1. Test all network paths:
   ```bash
   ping -c 1 10.6.0.21  # WireGuard
   ping -c 1 100.80.30.59  # Tailscale
   ping -c 1 192.168.0.183  # LAN
   ```

2. Test MCP endpoints:
   ```bash
   curl -H "Accept: text/event-stream" http://192.168.0.183:8051/mcp
   curl -H "Accept: text/event-stream" http://100.80.30.59:8051/mcp
   ```

3. Check configuration:
   ```bash
   cat /root/.claude/mcp.json | grep -A 3 "archon"
   ```

4. Reload MCP configuration (restart Claude Code)

---

**Fixed by**: Claude Code (agl-hostman project)
**Verified**: 2025-01-05
**Status**: ✅ Production Ready
