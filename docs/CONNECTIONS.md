# Connection Matrix and Access Priorities

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: Connection methods, priorities, and access patterns

---

## 🔀 Connection Priority Matrix

### From WSL2 (AGLHQ11)

**Available Networks**: Tailscale only (100.75.205.122)

| Destination | Method | Priority | Address | Notes |
|-------------|--------|----------|---------|-------|
| CT179 | Tailscale | **PRIMARY** | 100.94.221.87 | Development container |
| AGLSRV1 | Tailscale | **PRIMARY** | 100.107.113.33 | Main host |
| AGLSRV5 | Tailscale | **PRIMARY** | 100.119.223.113 | Remote host |
| AGLSRV6 | Tailscale | **PRIMARY** | 100.98.108.66 | Remote host |

**Limitations**:
- ❌ No WireGuard access (deprecated)
- ❌ No local LAN access
- ❌ No Docker (use CT179 for Docker operations)

---

### From CT179 (agldv03)

**Available Networks**: LAN + Tailscale + WireGuard (legacy)

| Destination | 1st Priority | 2nd Priority | 3rd Priority | Recommended |
|-------------|--------------|--------------|--------------|-------------|
| AGLSRV1 | TS (100.107.113.33) | LAN (192.168.0.245) | WG (10.6.0.10) | **Tailscale** 🔧 |
| AGLSRV5 | TS (100.119.223.113) | LAN (remote) | WG (10.6.0.17) | **Tailscale** 🔧 |
| AGLSRV6 | TS (100.98.108.66) | WG (10.6.0.12) | - | **Tailscale** 🔧 |
| FGSRV6 | TS (100.83.51.9) | WG (10.6.0.5) | Public (186.202.57.120) | **Tailscale** 🔧 |
| CT111 (NFS) | TS (100.65.189.83) | WG (10.6.0.20) | - | **Tailscale** 🔧 |
| CT183 (Archon) | TS (100.80.30.59) | LAN (192.168.0.183) | WG (10.6.0.21) | **Tailscale** 🔧 |

**Notes**:
- ✅ Full network stack available
- 🔧 **Tailscale is now PRIMARY for all hosts** (per user directive)
- ⚡ LAN is fastest for same-location hosts when available
- 📉 WireGuard marked as legacy (deprecated)

---

### From CT108 (agldv06)

**Available Networks**: Tailscale only (100.71.229.12)
**Location**: AGLSRV6 (AGLALD)

Similar to WSL2, but with better container performance and local access to AGLSRV6 resources.

---

## 🌐 Network Layer Characteristics

| Network | Speed | Latency | Security | Availability | Priority | Use Case |
|---------|-------|---------|----------|--------------|----------|----------|
| **Tailscale** | ⚡⚡ Fast | 5-30ms | 🟢 Encrypted | 🟢 Universal | **PRIMARY** | All host access |
| **LAN** | ⚡⚡⚡ Fastest | <1ms | 🟡 Local only | 🟢 Same location | Secondary | Local operations |
| **WireGuard** | ⚡⚡ Fast | 15-30ms | 🟢 Encrypted | 🟢 Mesh nodes | Legacy | Being phased out |

---

## 🔑 SSH Connection Methods

See `SSH-CONFIG.md` for complete SSH configuration, keys, and aliases.

### Quick SSH Commands

**From CT179 (full access)**:
```bash
# Tailscale (PRIMARY - recommended for all hosts)
ssh root@100.107.113.33   # AGLSRV1
ssh root@100.119.223.113  # AGLSRV5
ssh root@100.98.108.66    # AGLSRV6
ssh root@100.80.30.59     # CT183 (Archon)
ssh root@100.83.51.9      # FGSRV6 (Tailscale)
ssh root@100.65.189.83    # CT111 (NFS)

# LAN (fastest for same-location hosts)
ssh root@192.168.0.245    # AGLSRV1

# WireGuard (legacy - being phased out)
ssh root@10.6.0.12        # AGLSRV6
ssh root@10.6.0.21        # CT183 (Archon)
```

**From WSL2 (Tailscale only)**:
```bash
ssh root@100.94.221.87    # CT179
ssh root@100.107.113.33   # AGLSRV1
ssh root@100.119.223.113  # AGLSRV5
```

---

## 🌍 External Access Patterns

### Archon AI Command Center (CT183)

**Internal Access** (from infrastructure):
- Primary: WireGuard (10.6.0.21:8051/8052)
- Backup: Tailscale (100.80.30.59:8051/8052)
- LAN: 192.168.0.183:8051/8052 (dev only)

**External Access**:
- Public DNS: https://archon.aglz.io
- Authentication: Basic Auth (admin/ArchonPass2025)

### Dokploy Deployment Platform (CT180)

**External Access**:
- Public DNS: https://dok.aglz.io
- Cloudflare Tunnel secured

---

## 📊 Connection Quality Metrics

### Latency Benchmarks

| Source | Destination | Network | Latency | Status |
|--------|-------------|---------|---------|--------|
| CT179 | AGLSRV1 | LAN | <1ms | ⚡ Excellent |
| CT179 | AGLSRV6 | WireGuard | 15-25ms | ✅ Good |
| CT179 | FGSRV6 Hub | WireGuard | 20-35ms | ✅ Good |
| CT111 | FGSRV6 Hub | WireGuard | 15-22ms | ✅ Good |
| WSL2 | CT179 | Tailscale | 20-42ms | ✅ Good |

---

## 🚨 Known Issues

### AGLSRV5 WireGuard SSH

**Issue**: SSH connection closes immediately after key exchange
- WireGuard: ✅ Working (ping successful)
- SSH: ❌ Failing on WireGuard interface
- **Workaround**: Use Tailscale (100.119.223.113)
- Status: Pending investigation

### FGSRV5 Tailscale Timeout

**Issue**: Tailscale connection timeout
- Tailscale alias (fgsrv5): ❌ Timeout (100.71.107.26)
- Public IP (FGSRV05): ✅ Working (191.252.200.20)
- **Workaround**: Use public IP with key auth
- Status: Requires local investigation

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md`
- **SSH Configuration**: `SSH-CONFIG.md` - Complete SSH setup and keys
- **WireGuard Mesh**: `WIREGUARD.md` - Mesh configuration details
- **Network Topology**: `TOPOLOGY.md` - Physical locations and network architecture

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)
