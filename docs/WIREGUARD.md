# WireGuard Mesh Network Configuration

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Reference**: WireGuard mesh network (10.6.0.0/24) configuration and standards

---

## 🌐 Network Overview

### WireGuard Mesh Details

- **Network**: 10.6.0.0/24
- **Hub**: FGSRV6 (186.202.57.120:51823)
- **Topology**: Hub-and-spoke with mesh capabilities
- **Active Nodes**: 16
- **Total Configured**: 18 (2 offline)
- **Encryption**: ChaCha20-Poly1305
- **Protocol**: UDP

### Hub Configuration

- **Server**: FGSRV6 (vps41772.publiccloud.com.br)
- **Public IP**: 186.202.57.120
- **WireGuard IP**: 10.6.0.5
- **Port**: 51823/UDP
- **Role**: Central routing point for entire infrastructure

---

## 📊 WireGuard Mesh Nodes

### Complete Node Inventory

| Node | IP | Port | Type | Host | Physical Location | Status |
|------|-----|------|------|------|-------------------|--------|
| **FGSRV6** | 10.6.0.5 | 51823 | Hub | Cloud VPS | AGLFG-VPS | ✅ **Hub** |
| CT120 | 10.6.0.1 | 51820 | Container | AGLSRV1 | AGLHQ | ✅ |
| CT121 | 10.6.0.3 | 51821 | Container | AGLSRV6 | AGLALD | ✅ |
| AGLSRV1 | 10.6.0.10 | 51810 | Host | Local | AGLHQ | ✅ |
| FGSRV5 | 10.6.0.11 | 51811 | Host | Cloud VPS | AGLFG-VPS | ✅ |
| **AGLSRV6** | 10.6.0.12 | 51812 | Host | Remote | AGLALD | ✅ **Primary** |
| AGLSRV6B | 10.6.0.13 | 51813 | Host | Remote | AGLALD | ❌ **DEAD** |
| CT113 | 10.6.0.14 | 51814 | Container | AGLSRV6 | AGLALD | ✅ PBS |
| CT172 | 10.6.0.15 | 51815 | Container | AGLSRV6B | AGLALD | ⚠️ Host offline |
| FGSRV4 | 10.6.0.16 | 51816 | Host | Cloud VPS | AGLFG-VPS | ✅ |
| AGLSRV5 | 10.6.0.17 | 51817 | Host | Remote | AGLFG | ✅ |
| FGSRV3 | 10.6.0.18 | 51818 | Host | Cloud VPS | AGLFG-VPS | ✅ |
| **CT179** | 10.6.0.19 | 51819 | Container | AGLSRV1 | AGLHQ | ✅ **Dev** |
| **CT111** | 10.6.0.20 | 51820 | Container | AGLSRV6 | AGLALD | ✅ **NFS** |
| **CT183** | 10.6.0.21 | 51821 | Container | AGLSRV1 | AGLHQ | ✅ **Archon AI** |
| **AGLSRV6C** | 10.6.0.22 | 51822 | Host | Remote | AGLALD | ✅ Active |
| **AGLSRV6D** | 10.6.0.23 | 51823 | Host | Remote | AGLALD | ✅ Active |
| **CT181** | 10.6.0.24 | 43373 | Container | AGLSRV1 | AGLHQ | ✅ **Dev** |

### Node Status Summary

| Status | Count | Nodes |
|--------|-------|-------|
| ✅ Active | 16 | FGSRV3/4/5/6, AGLSRV1/5/6/6C/6D, CT111/113/120/121/179/181/183 |
| ❌ Dead | 1 | AGLSRV6B (RAID failure) |
| ⚠️ Host Offline | 1 | CT172 (on dead AGLSRV6B host) |

### Critical Nodes

| Node | Role | Importance | Notes |
|------|------|------------|-------|
| **FGSRV6** | WireGuard Hub | **CRITICAL** | Central routing point - failure affects entire mesh |
| **CT179** | Development | High | Main development container (48GB RAM) |
| **CT181** | Development | High | Secondary development container (48GB RAM, cloned from CT179) |
| **CT111** | NFS Server | High | NFS storage for mesh (10.6.0.20) |
| **CT183** | Archon AI | High | AI Command Center with MCP server |
| **AGLSRV6** | Remote Host | High | Primary remote Proxmox host |

---

## 🔧 Configuration Standards

### Container Configuration (No PresharedKey)

**Used by**: LXC containers on Proxmox hosts

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24  # Only mesh network
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

**Key Differences**:
- ❌ No `PresharedKey` (LXC limitation)
- ✅ `AllowedIPs = 10.6.0.0/24` (mesh network only)
- ✅ `PersistentKeepalive = 25` (keeps connection alive)

### Host Configuration (With PresharedKey)

**Used by**: Proxmox hosts and VPS servers

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
PresharedKey = DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

**Key Differences**:
- ✅ Includes `PresharedKey` (additional security layer)
- ✅ Same hub endpoint and settings as containers

---

## 🐳 LXC Container Requirements

### Proxmox LXC Configuration

**Required in `/etc/pve/lxc/XXX.conf`**:

```ini
# Enable keyctl and nesting for WireGuard
features: keyctl=1,nesting=1

# Allow /dev/net/tun device
lxc.cgroup2.devices.allow: c 10:200 rwm

# Mount /dev/net/tun inside container
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### Explanation

| Setting | Purpose |
|---------|---------|
| `keyctl=1` | Allows container to use kernel keyring (required by WireGuard) |
| `nesting=1` | Enables nested containerization features |
| `lxc.cgroup2.devices.allow` | Grants permission to TUN device (character device 10:200) |
| `lxc.mount.entry` | Mounts /dev/net/tun from host into container |

### Verification

```bash
# Inside container, verify TUN device exists
ls -l /dev/net/tun

# Should output:
# crw-rw-rw- 1 root root 10, 200 Nov  8 12:00 /dev/net/tun

# Test WireGuard can start
wg-quick up wg0
wg show wg0
```

---

## 🚀 Deployment Procedure

### Adding New Node to Mesh

```bash
# 1. Generate keys
wg genkey | tee privatekey | wg pubkey > publickey

# 2. Create config file
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = <paste privatekey content>
Address = 10.6.0.X/24  # Get next available IP
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
# PresharedKey only for hosts, not containers
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
EOF

# 3. For LXC containers, add to Proxmox config
nano /etc/pve/lxc/XXX.conf
# Add LXC requirements (see above)

# 4. Restart container (for LXC)
pct restart XXX

# 5. Start WireGuard
wg-quick up wg0

# 6. Enable at boot
systemctl enable wg-quick@wg0

# 7. Verify connection
wg show wg0
ping 10.6.0.5  # Ping hub
```

### Hub Configuration Update

```bash
# On FGSRV6 (hub), add new peer:
wg set wg0 peer <NEW_PUBLIC_KEY> allowed-ips 10.6.0.X/32

# For permanent config, add to /etc/wireguard/wg0.conf:
[Peer]
PublicKey = <NEW_PUBLIC_KEY>
AllowedIPs = 10.6.0.X/32
```

---

## 🔍 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| No handshake with hub | Check firewall allows UDP 51823, verify endpoint is reachable |
| Container can't start WireGuard | Verify LXC config has all requirements, restart container |
| No traffic after handshake | Check `AllowedIPs` includes destination network |
| Connection drops | Increase `PersistentKeepalive` or check network stability |

### Diagnostic Commands

```bash
# Check WireGuard status
wg show wg0

# Watch for handshakes
watch -n 1 'wg show wg0'

# Test connectivity to hub
ping 10.6.0.5

# Check routing
ip route show dev wg0

# View WireGuard logs
journalctl -u wg-quick@wg0 -f

# Restart WireGuard
wg-quick down wg0 && wg-quick up wg0
```

### Known Issues

**AGLSRV5 SSH via WireGuard**:
- Issue: SSH connection closes immediately after key exchange
- WireGuard: ✅ Working (ping successful)
- SSH: ❌ Failing on WireGuard interface
- **Workaround**: Use Tailscale (100.119.223.113) for SSH access
- Status: Pending investigation

---

## 📊 IP Address Allocation

### Available IPs

| Range | Status | Notes |
|-------|--------|-------|
| 10.6.0.1-10.6.0.24 | ✅ Allocated | Current mesh nodes |
| 10.6.0.25-10.6.0.50 | 🟢 Available | Next assignments |
| 10.6.0.51-10.6.0.254 | 🟢 Available | Future expansion |

### Next Available IPs

For new nodes, use IPs starting from **10.6.0.25**.

---

## 📚 Related Documentation

- **Main Infrastructure**: `INFRA.md` - Complete infrastructure map
- **Network Topology**: `TOPOLOGY.md` - Physical locations and network architecture
- **Storage**: `STORAGE.md` - NFS mounts over WireGuard
- **Connections**: `CONNECTIONS.md` - Connection priorities and matrix
- **Troubleshooting**: `MAN6_SSH_WIREGUARD_FIX.md` - WireGuard SSH issues

---

**Document Version**: 1.1.0
**Last Updated**: 2025-11-10
**Maintainer**: Claude Code (agl-hostman project)
