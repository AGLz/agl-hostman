---
name: wireguard-network-management
description: "WireGuard VPN mesh network configuration, peer management, routing, and troubleshooting. Use when setting up secure site-to-site connectivity, managing VPN peers, or configuring private networks."
category: infrastructure
priority: P1
tags: [wireguard, vpn, networking, security, mesh]
---

# WireGuard Network Management

## Overview

This skill manages the AGL infrastructure WireGuard mesh network (10.6.0.0/24), providing secure site-to-site connectivity between all locations. The mesh uses a hub-and-spoke topology with FGSRV6 as the central routing hub.

### Network Architecture

```
                    WireGuard Mesh Network (10.6.0.0/24)

                              FGSRV6 (Hub)
                        10.6.0.5:51823
                    186.202.57.120:51823
                                  |
        ┌─────────────────────────┼─────────────────────────┐
        |                         |                         |
   AGLHQ (LAN)              AGLALD (Remote)           AGLFG-VPS (Cloud)
   CT120: 10.6.0.1         AGLSRV6: 10.6.0.12        FGSRV4: 10.6.0.16
   AGLSRV1: 10.6.0.10      CT121: 10.6.0.3           FGSRV5: 10.6.0.11
   CT179: 10.6.0.19        AGLSRV6C: 10.6.0.22       AGLSRV5: 10.6.0.17
   CT181: 10.6.0.24        AGLSRV6D: 10.6.0.23       FGSRV3: 10.6.0.18
   CT183: 10.6.0.21        CT111: 10.6.0.20
```

### Current Mesh Status

| Location | Active Nodes | IP Range | Hub |
|----------|--------------|----------|-----|
| AGLHQ | 5 | 10.6.0.1, 10.6.0.10, 10.6.0.19, 10.6.0.21, 10.6.0.24 | FGSRV6 |
| AGLALD | 5 | 10.6.0.3, 10.6.0.12, 10.6.0.20, 10.6.0.22, 10.6.0.23 | FGSRV6 |
| AGLFG-VPS | 3 | 10.6.0.11, 10.6.0.16, 10.6.0.18 | FGSRV6 |
| **Total** | **16** | **10.6.0.1-10.6.0.24** | **1 Hub** |

### Network Priorities

Connection priority for all services:
1. **WireGuard** (10.6.0.0/24) - Primary, kernel-level performance
2. **LAN** (192.168.0.0/24) - Local network, secondary
3. **Tailscale** (100.x.x.x) - Fallback/backup remote access

---

## Mesh Network Setup

### Hub Configuration (FGSRV6)

**Server**: vps41772.publiccloud.com.br
**Public IP**: 186.202.57.120
**WireGuard IP**: 10.6.0.5
**Port**: 51823/UDP
**Public Key**: `Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=`

```ini
[Interface]
PrivateKey = <FGSRV6_PRIVATE_KEY>
Address = 10.6.0.5/24
ListenPort = 51823
MTU = 1420

[Peer]
PublicKey = <PEER_PUBLIC_KEY>
AllowedIPs = 10.6.0.X/32
```

### New Node Setup Checklist

```bash
# Prerequisites
- [ ] Host/container accessible via SSH
- [ ] WireGuard installed (apt install wireguard)
- [ ] Available IP in 10.6.0.25-10.6.0.50 range
- [ ] Available port in 51825-51899 range
- [ ] For LXC: features: keyctl=1,nesting=1 configured

# Steps (see scripts/wg-add-peer.sh)
1. Generate keys on new peer
2. Create WireGuard configuration
3. Register peer on hub (FGSRV6)
4. Start WireGuard interface
5. Verify connectivity
6. Document in docs/WIREGUARD.md
```

---

## Peer Configuration

### LXC Container Configuration

**Critical**: LXC containers MUST NOT use PresharedKey (causes handshake failures)

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.6.0.X/24
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = 186.202.57.120:51823
```

### Proxmox Host Configuration

Hosts SHOULD use PresharedKey for additional security:

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

### LXC Container Requirements

For WireGuard in LXC containers, add to `/etc/pve/lxc/<VMID>.conf`:

```ini
# Enable keyctl and nesting for WireGuard
features: keyctl=1,nesting=1

# Allow /dev/net/tun device
lxc.cgroup2.devices.allow: c 10:200 rwm

# Mount /dev/net/tun inside container
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

After adding, restart container: `pct restart <VMID>`

---

## Key Management

### Generate New Key Pair

```bash
# Generate private key
wg genkey | tee /etc/wireguard/privatekey

# Derive public key
wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey

# Secure private key
chmod 600 /etc/wireguard/privatekey
```

### Key Rotation

Key rotation should be performed periodically for security:

```bash
# Use the key rotation script
scripts/wg-rotate-keys.sh <peer_name>

# Manual process:
# 1. Generate new keys on peer
# 2. Update peer config
# 3. Update hub config with new public key
# 4. Restart WireGuard on both ends
# 5. Verify connectivity
```

### Key Storage Best Practices

- Private keys: `/etc/wireguard/privatekey` (chmod 600)
- Public keys: `/etc/wireguard/publickey` (chmod 644)
- Pre-shared keys: `/etc/wireguard/psk` (chmod 600, hosts only)
- **NEVER** commit private keys to git
- Store public keys in hub configuration only

---

## Routing Configuration

### Allowed IPs

- **Mesh Network**: `10.6.0.0/24` (all peers)
- **Individual Peer**: `10.6.0.X/32` (on hub config)
- **Internet Routing**: DISABLED (split-tunnel, no `0.0.0.0/0`)

### Persistent Keepalive

- **Purpose**: Maintain NAT traversal
- **Setting**: 25 seconds (optimal for most NAT devices)
- **Hub**: Not required (has public IP)
- **Spokes**: Required (behind NAT/firewalls)

### MTU Configuration

- **Optimal MTU**: 1420 bytes
- **Calculation**: 1500 (standard) - 80 (WireGuard overhead)
- **Path MTU Discovery**: Automatically handled by wg-quick

### DNS Configuration

```ini
DNS = 1.1.1.1, 8.8.8.8
```

Use Cloudflare (1.1.1.1) as primary with Google DNS (8.8.8.8) as fallback.

---

## Troubleshooting

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| No handshake | PresharedKey in LXC | Remove PresharedKey, restart |
| No handshake | Wrong AllowedIPs | Change to `10.6.0.0/24` |
| Can't start WG | Missing LXC features | Add keyctl=1,nesting=1 to config |
| High latency | Suboptimal MTU | Set MTU to 1420 |
| Connection drops | Low keepalive | Set PersistentKeepalive to 25 |
| Can't reach peers | Firewall blocking | Allow UDP 51823 on firewall |

### Diagnostic Commands

```bash
# Check WireGuard status
wg show wg0

# Watch for handshakes
watch -n 1 'wg show wg0'

# Check interface details
ip addr show wg0

# Test connectivity to hub
ping -c 3 10.6.0.5

# Test connectivity to specific peer
ping -c 3 10.6.0.12

# Check routing table
ip route show dev wg0

# View WireGuard logs
journalctl -u wg-quick@wg0 -f

# Restart WireGuard
wg-quick down wg0 && wg-quick up wg0

# Check if UDP port is listening
ss -ulnp | grep 51823

# Test UDP connectivity from hub
nc -u -z 186.202.57.120 51823
```

### Network Debug Flow

```
1. wg show wg0
   ├─ No handshake? → Check config (PresharedKey, AllowedIPs)
   ├─ Old handshake? → Check endpoint reachability
   └─ Recent handshake? → Connection working

2. ping 10.6.0.5 (hub)
   ├─ Success? → Routing works
   └─ Failed? → Check routing table

3. ip route show
   ├─ Has 10.6.0.0/24 dev wg0? → Route configured
   └─ Missing? → WireGuard not up or config issue

4. journalctl -u wg-quick@wg0 -n 50
   └─ Check for errors during startup
```

### Performance Issues

```bash
# Check latency to hub
ping -c 10 10.6.0.5 | tail -1

# Test throughput (requires iperf3 on both ends)
iperf3 -c 10.6.0.5 -t 30

# Check packet loss
ping -c 100 10.6.0.5 | grep "packet loss"

# Check MTU path
tracepath 10.6.0.5

# View transfer statistics
wg show wg0 transfer

# Optimize network parameters
scripts/optimization/optimize-wireguard-mesh.sh
```

---

## Tailscale Fallback

When WireGuard is unavailable, use Tailscale as backup:

### Tailscale IPs for Key Nodes

| Host | WireGuard IP | Tailscale IP | Fallback Use |
|------|--------------|--------------|--------------|
| AGLSRV1 | 10.6.0.10 | 100.98.108.66 | SSH, management |
| AGLSRV6 | 10.6.0.12 | 100.98.119.51 | SSH, management |
| FGSRV5 | 10.6.0.11 | 100.71.107.26 | NFS access |
| FGSRV6 | 10.6.0.5 | 100.83.51.9 | Hub access |

### Connection Priority Matrix

| Operation | 1st Choice | 2nd Choice | 3rd Choice |
|-----------|------------|------------|------------|
| SSH to hosts | WireGuard | LAN | Tailscale |
| NFS mounts | WireGuard | LAN | Tailscale |
| Service access | WireGuard | LAN | Tailscale |
| Emergency access | WireGuard | Tailscale | LAN |

### Tailscale Setup

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate (requires URL)
tailscale up --accept-routes

# Check status
tailscale status

# Get Tailscale IP
tailscale ip -4
```

### When to Use Tailscale

- WireGuard hub (FGSRV6) is down
- New node initial setup
- Testing connectivity before WireGuard config
- Emergency remote access
- WSL2 environments (no WireGuard support)

---

## Security Best Practices

### Key Rotation Schedule

- **Private/Public Keys**: Rotate every 6 months
- **Pre-shared Keys**: Rotate every 3 months
- **After Security Event**: Rotate immediately

### Firewall Rules

```bash
# On hub (FGSRV6)
ufw allow 51823/udp comment 'WireGuard Hub'

# On peers (if behind NAT)
ufw allow out 51823/udp comment 'WireGuard to Hub'

# On Proxmox hosts
# Allow UDP port for each peer
iptables -A INPUT -p udp --dport 518XX -j ACCEPT
```

### Access Control

- **AllowedIPs**: Restrict to `10.6.0.0/24` only (not `0.0.0.0/0`)
- **Public Keys**: Only registered peers can connect
- **Pre-shared Keys**: Additional encryption layer for hosts
- **No Internet Routing**: Split-tunnel configuration (security)

### Monitoring

```bash
# Monitor peer connections
watch -n 10 'wg show wg0'

# Check for unauthorized peers
wg show wg0 peers

# Monitor bandwidth usage
vnstat -i wg0 -l

# Alert on disconnections
# Add to monitoring: check handshake age > 180s = alert
```

### Audit Procedures

```bash
# List all registered peers
ssh root@186.202.57.120 'wg show wg0 peers'

# Verify each peer has recent handshake
ssh root@186.202.57.120 'wg show wg0 latest-handshakes'

# Check for stale peers (no handshake > 24h)
# Consider removal or investigation

# Document audit findings
# Update docs/WIREGUARD.md with current status
```

---

## Quick Reference

### Hub Information

```
Hub: FGSRV6
Public IP: 186.202.57.120
WireGuard IP: 10.6.0.5
Port: 51823/UDP
Public Key: Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=
PresharedKey: DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=
```

### Critical Nodes

| Node | IP | Role | Contact Via |
|------|-----|------|-------------|
| FGSRV6 | 10.6.0.5 | Hub | 186.202.57.120:22 |
| AGLSRV1 | 10.6.0.10 | HQ Host | 10.6.0.10:22 or 192.168.0.245:22 |
| AGLSRV6 | 10.6.0.12 | Remote Host | 10.6.0.12:22 or 100.98.119.51:22 |
| CT111 | 10.6.0.20 | NFS Server | Via AGLSRV6: pct exec 111 |
| CT183 | 10.6.0.21 | Archon AI | Via AGLSRV1: pct exec 183 |

### Next Available IPs

- Range: 10.6.0.25 - 10.6.0.50 (26 IPs available)
- Port Range: 51825 - 51899

### Common Tasks

```bash
# Add new peer
scripts/wg-add-peer.sh <hostname> <ip> <port>

# Remove peer
scripts/wg-remove-peer.sh <ip>

# Check mesh status
scripts/wg-status.sh

# Rotate keys
scripts/wg-rotate-keys.sh <peer_name>

# Optimize performance
scripts/optimization/optimize-wireguard-mesh.sh
```

---

## Related Documentation

- **Main Infrastructure**: `docs/INFRA.md` - Complete infrastructure map
- **Network Topology**: `docs/NETWORK-TOPOLOGY.md` - Physical locations
- **WireGuard Details**: `docs/WIREGUARD.md` - Full configuration reference
- **Connection Matrix**: `docs/CONNECTIONS.md` - All connection priorities
- **Storage**: `docs/STORAGE.md` - NFS mounts over WireGuard
- **Troubleshooting**: `docs/troubleshooting/` - Issue resolution guides

---

## Scripts Reference

### wg-add-peer.sh
Adds new WireGuard peer to mesh network.

```bash
Usage: ./wg-add-peer.sh <hostname> <ip> <port>

Example: ./wg-add-peer.sh new-container 10.6.0.25 51825
```

### wg-remove-peer.sh
Removes WireGuard peer from mesh network.

```bash
Usage: ./wg-remove-peer.sh <ip>

Example: ./wg-remove-peer.sh 10.6.0.25
```

### wg-status.sh
Shows WireGuard mesh status and connectivity.

```bash
Usage: ./wg-status.sh [--verbose]

Example: ./wg-status.sh --verbose
```

### wg-rotate-keys.sh
Rotates WireGuard keys for security maintenance.

```bash
Usage: ./wg-rotate-keys.sh <peer_name>

Example: ./wg-rotate-keys.sh ct120
```

---

**Version**: 1.0.0
**Last Updated**: 2026-02-07
**Maintainer**: AGL Infrastructure Team
