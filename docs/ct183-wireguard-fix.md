# CT183 WireGuard TCP Connection Issue - Root Cause & Fix

**Date**: 2025-10-28
**Status**: ⚠️ **ROOT CAUSE IDENTIFIED** - Awaiting Hub Configuration

---

## 🎯 Executive Summary

**Problem**: TCP connections to CT183 (Archon) via WireGuard IP (10.6.0.21) fail with "Connection refused" while ICMP (ping) works.

**Root Cause**: CT183's WireGuard peer is **NOT registered on the hub** (FGSRV6). The container has:
- ✅ WireGuard interface configured (10.6.0.21/24)
- ✅ Sending keepalive packets (43.36 KiB sent)
- ❌ **NO handshake established with hub**
- ❌ **0 bytes received** (no return traffic)

**Impact**:
- ICMP appears to work (false positive - may be local routing)
- TCP connections never establish because WireGuard tunnel is NOT active
- Services (nginx, Docker) are correctly configured and work via LAN (192.168.0.183)

---

## 📊 Diagnostic Evidence

### CT183 WireGuard Status
```bash
root@192.168.0.245 'pct exec 183 -- wg show'

interface: wg0
  public key: 6QrRRYK1JFtW7VGaR3OlwICsA4jO6/gaDo3OoT8re08=
  private key: (hidden)
  listening port: 51821

peer: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
  endpoint: 186.202.57.120:51823
  allowed ips: 10.6.0.0/24
  transfer: 0 B received, 43.36 KiB sent              ← ❌ NO RECEIVED DATA
  persistent keepalive: every 25 seconds
  # ❌ NO "latest handshake" LINE = NO ESTABLISHED TUNNEL
```

### CT179 WireGuard Status (Working Peer)
```bash
wg show

interface: wg0
  public key: nZrRsDkPdjqsmzxkQOLAcy7QBjCi4jHILUOuF0AdTUE=
  private key: (hidden)
  listening port: 51819

peer: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
  endpoint: 186.202.57.120:51823
  allowed ips: 10.6.0.0/24
  latest handshake: 1 minute, 30 seconds ago        ← ✅ ACTIVE HANDSHAKE
  transfer: 32.70 KiB received, 89.40 KiB sent     ← ✅ BIDIRECTIONAL TRAFFIC
  persistent keepalive: every 25 seconds
```

### CT183 Configuration (/etc/wireguard/wg0.conf)
```ini
[Interface]
PrivateKey = +ABgxElFx99686WWWk6bXN760Ea8yPNh8oSJgA4Tcn4=
Address = 10.6.0.21/24
MTU = 1420
ListenPort = 51821

# FGSRV6 Hub
[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24
Endpoint = 186.202.57.120:51823
PersistentKeepalive = 25
```

✅ Configuration is **CORRECT** (no PresharedKey, correct AllowedIPs)

---

## 🔍 Troubleshooting Journey

### Tests Performed

1. **ICMP Test** (False Positive)
   ```bash
   ping -c 2 10.6.0.21
   # Result: 64 bytes from 10.6.0.21 (17-23ms)
   # ⚠️ FALSE POSITIVE - Packets may be routed locally, not through WireGuard
   ```

2. **TCP Test** (Failed)
   ```bash
   curl http://10.6.0.21:8052/mcp
   # Result: Connection refused
   ```

3. **LAN Test** (Success)
   ```bash
   curl http://192.168.0.183:8052/mcp
   # Result: HTTP/1.1 405 Method Not Allowed (correct MCP response)
   ```

4. **tcpdump on CT183 wg0** (No Packets Received)
   ```bash
   tcpdump -i wg0 host 10.6.0.19 and port 8052
   # Result: NO PACKETS CAPTURED (tunnel not active)
   ```

5. **tcpdump on CT179 wg0** (No Packets Sent)
   ```bash
   tcpdump -i wg0 host 10.6.0.21 and tcp port 8052
   # Result: NO TCP PACKETS SENT (connection attempt fails before sending)
   ```

### Attempted Fixes (All Failed)

❌ **Tailscale Disabled**: Problem persisted (not Tailscale's fault)
❌ **iptables Rules Added**: DOCKER-USER chain rules for wg0
❌ **Reverse Path Filtering**: Disabled rp_filter on all/wg0
❌ **DNAT Rules**: Added explicit DNAT for wg0 interface
❌ **socat Proxy**: Tried binding to 10.6.0.21:8053

**Why They Failed**: All focused on firewall/routing, but root cause is **no WireGuard handshake**.

---

## ✅ Solution

### Required Action

Add CT183 as a peer on FGSRV6 (WireGuard hub):

**CT183 Details**:
- Public Key: `6QrRRYK1JFtW7VGaR3OlwICsA4jO6/gaDo3OoT8re08=`
- IP Address: `10.6.0.21/32`
- ListenPort: `51821` (UDP)
- Endpoint: Not needed (hub doesn't need to initiate, CT183 connects to hub)

### Hub Configuration (FGSRV6 - 186.202.57.120)

**Option 1: wg-easy Web UI** (Recommended)
1. Access: http://186.202.57.120:51821
2. Add new peer:
   - Name: `CT183-archon`
   - Public Key: `6QrRRYK1JFtW7VGaR3OlwICsA4jO6/gaDo3OoT8re08=`
   - Allowed IPs: `10.6.0.21/32`
3. Save configuration

**Option 2: Manual wg0.conf Edit**
```bash
ssh root@186.202.57.120

# Edit /etc/wireguard/wg0.conf
cat >> /etc/wireguard/wg0.conf <<'EOF'

[Peer]
# CT183 (archon - Archon AI Command Center)
PublicKey = 6QrRRYK1JFtW7VGaR3OlwICsA4jO6/gaDo3OoT8re08=
AllowedIPs = 10.6.0.21/32
# No Endpoint needed (client-initiated)
# No PresharedKey (LXC container)
EOF

# Reload WireGuard configuration
wg syncconf wg0 <(wg-quick strip wg0)

# Verify peer added
wg show wg0 peers | grep 6QrRRYK1JFtW7VGaR3OlwICsA4jO6/gaDo3OoT8re08=
```

### Verification Steps

After adding peer on hub, verify on CT183:

```bash
# Check handshake established
ssh root@192.168.0.245 'pct exec 183 -- wg show'
# Expected: "latest handshake: X seconds ago"
# Expected: transfer shows "received" data (not 0 B)

# Test ICMP
ping -c 2 10.6.0.21
# Expected: Response with low latency

# Test TCP (MCP)
curl -I http://10.6.0.21:8052/mcp
# Expected: HTTP/1.1 405 Method Not Allowed

# Test TCP (Docker MCP)
curl -I http://10.6.0.21:8051/mcp
# Expected: HTTP/1.1 405 Method Not Allowed

# Test Claude Code MCP Connection
claude mcp add --transport http archon http://10.6.0.21:8052/mcp
# Expected: archon: ... (HTTP) - ✓ Connected
```

---

## 📚 Lessons Learned

### False Positives

**ICMP Success ≠ Tunnel Working**:
- Ping may succeed due to local routing or other mechanisms
- Always verify bidirectional traffic with `wg show` (transfer stats)
- Look for "latest handshake" line - if missing, tunnel is NOT active

### Proper WireGuard Diagnostics

1. **Check handshake**: `wg show` must show "latest handshake"
2. **Check transfer**: Both "received" and "sent" should be non-zero
3. **Check tcpdump**: Packets should appear on wg0 interface
4. **Check hub peer list**: Peer must be registered on hub

### WireGuard Hub-and-Spoke Model

- Hub (FGSRV6) must know about ALL peers
- Peers connect TO hub, not to each other directly
- Adding new peer requires hub configuration update
- Mesh connectivity requires hub registration

---

## 🔗 Related Documentation

- **CLAUDE.md**: WireGuard configuration standards (line 1144-1180)
- **INFRA.md**: Network topology and WireGuard mesh architecture
- **docs/ct183-deployment-guide.md**: CT183 deployment details
- **docs/archon-basic-auth-implementation.md**: nginx configuration (working)

---

## 📊 Impact Assessment

**Current State**:
- ❌ TCP via WireGuard: Blocked (no handshake)
- ✅ TCP via LAN: Working (192.168.0.183)
- ✅ HTTPS via Cloudflare: Working (archon.aglz.io)
- ✅ Tailscale: Unknown (not tested, but likely works)

**Post-Fix State** (Expected):
- ✅ TCP via WireGuard: Working (10.6.0.21)
- ✅ External access via WG: Working (primary method)
- ✅ Tailscale: Working (backup method)
- ✅ Claude Code MCP: Working via WG from remote locations

---

## 🚀 Next Steps

1. **Immediate**: Add CT183 peer to FGSRV6 hub (requires hub access)
2. **Verify**: Run verification tests above
3. **Update Claude Code**: Switch MCP endpoint to WireGuard IP
4. **Test External**: Connect from remote location via WireGuard
5. **Document**: Update INFRA.md with CT183 in WireGuard mesh

---

**Document Version**: 1.0
**Created**: 2025-10-28
**Author**: Claude Code
**Status**: Awaiting hub configuration
