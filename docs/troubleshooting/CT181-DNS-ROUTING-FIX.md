# CT181 (agldv04) - DNS/Routing Issue Resolution

> **Date**: 2025-11-11
> **Container**: CT181 (agldv04) - 192.168.0.181 / WG 10.6.0.24 / TS 100.113.9.98
> **Issue**: DNS resolution failures and internet connectivity problems
> **Status**: ✅ **RESOLVED**

---

## 🔴 Problem Description

CT181 was experiencing complete internet connectivity failure:
- ❌ DNS resolution failed (timeout)
- ❌ Ping to external IPs failed (100% packet loss)
- ❌ HTTP/HTTPS connections failed
- ✅ WireGuard mesh working (10.6.0.24)
- ✅ Tailscale working locally
- ✅ Host (AGLSRV1) had perfect internet connectivity

---

## 🔍 Root Cause Analysis

### Symptoms:
1. DNS queries to Tailscale MagicDNS (100.100.100.100) timed out
2. Ping to gateway (192.168.0.1) failed
3. Ping to external IPs (1.1.1.1, 8.8.8.8) failed
4. **Traceroute worked** (showed 5 hops successfully)
5. **Forcing interface worked**: `ping -I eth0 1.1.1.1` succeeded

### Investigation Results:
```bash
# Policy routing showed Tailscale intercepting all traffic
ip rule list
0:      from all lookup local
5210:   from all fwmark 0x80000/0xff0000 lookup main
5230:   from all fwmark 0x80000/0xff0000 lookup default
5250:   from all fwmark 0x80000/0xff0000 unreachable
5270:   from all lookup 52  # ⚠️ PROBLEM: All traffic to table 52
```

### Root Cause:
**Tailscale was accepting routes from other tailnet nodes**, including:
- `192.168.0.0/24 dev tailscale0` (local network!)
- `172.2.2.0/24 dev tailscale0`

This caused all internet-bound traffic to be routed through `tailscale0` instead of the local gateway `eth0`, breaking connectivity.

---

## ✅ Solution

### Command Applied:
```bash
ssh root@10.6.0.24
tailscale set --accept-routes=false
```

### What This Does:
- Disables acceptance of subnet routes from other Tailscale nodes
- Removes policy routing rules that were intercepting local traffic
- Allows normal routing through local gateway (192.168.0.1)
- Preserves Tailscale connectivity for direct peer-to-peer connections

### Verification:
```bash
# All tests now pass
ping -c 2 1.1.1.1          # ✅ Working
nslookup google.com         # ✅ Working (via 100.100.100.100)
curl -I https://google.com  # ✅ Working
```

---

## 🔧 Making It Permanent

The `tailscale set` command persists across reboots, but for documentation purposes, you can verify the setting:

```bash
# Check current Tailscale configuration
tailscale status --json | grep AcceptRoutes

# Should return: "AcceptRoutes": false
```

### Alternative: Use systemd Drop-in

If you need to ensure this setting on Tailscale daemon start:

```bash
# Create drop-in directory
mkdir -p /etc/systemd/system/tailscaled.service.d/

# Create override
cat > /etc/systemd/system/tailscaled.service.d/no-accept-routes.conf << 'EOF'
[Service]
ExecStartPost=/usr/bin/tailscale set --accept-routes=false
EOF

# Reload systemd
systemctl daemon-reload
```

---

## 📊 Network Configuration After Fix

### Interfaces:
- **eth0**: 192.168.0.181/24 (primary, internet via 192.168.0.1)
- **wg0**: 10.6.0.24/24 (WireGuard mesh)
- **tailscale0**: 100.113.9.98/32 (Tailscale VPN)

### Routing:
```bash
ip route show
default via 192.168.0.1 dev eth0 onlink          # ✅ Primary route
10.6.0.0/24 dev wg0 proto kernel scope link       # WireGuard mesh
192.168.0.0/24 dev eth0 proto kernel scope link   # Local LAN
# ... Docker bridges ...
```

### DNS:
- **Resolver**: 100.100.100.100 (Tailscale MagicDNS)
- **Search domains**: degu-chromatic.ts.net, aglz.io, localdomain
- **Status**: ✅ Working

---

## 🎯 Key Learnings

1. **Tailscale `--accept-routes` can override local routing**
   - Be careful when enabling route acceptance
   - Can cause unexpected routing behavior
   - Always verify with `ip route show table 52`

2. **Diagnostic Techniques Used:**
   - Forcing interface: `ping -I eth0` revealed routing issue
   - Policy routing: `ip rule list` showed table 52 was intercepting
   - Route tables: `ip route show table 52` showed problematic routes
   - Comparison: Testing from host vs container isolated the issue

3. **Why Traceroute Worked But Ping Failed:**
   - Traceroute uses different routing path (UDP with TTL manipulation)
   - Regular ICMP/TCP was being caught by policy routing rules
   - This was a key diagnostic clue pointing to policy routing

---

## 📝 Related Documentation

- **Infrastructure Map**: `docs/INFRA.md`
- **Container Inventory**: `docs/CONTAINERS.md` (CT181 entry)
- **WireGuard Configuration**: `docs/WIREGUARD.md`
- **Connection Troubleshooting**: `docs/QUICK-START.md`

---

## 🚀 Future Considerations

### When to Use `--accept-routes=true`:
- ✅ When you want to access subnets announced by exit nodes
- ✅ When using Tailscale as a site-to-site VPN
- ✅ When you need access to remote LANs through Tailscale

### When to Keep `--accept-routes=false`:
- ✅ On containers with local internet access (like CT181)
- ✅ When you want direct internet routing
- ✅ When using WireGuard as primary mesh network
- ✅ To avoid routing conflicts in multi-network environments

---

**Resolution Time**: ~30 minutes
**Complexity**: Intermediate (policy routing investigation)
**Impact**: Critical (no internet connectivity)
**Recurrence Risk**: Low (setting persists)

---

**Documented by**: Claude Code (agl-hostman project)
**Container**: CT179 (agldv03) → investigating CT181 (agldv04)
