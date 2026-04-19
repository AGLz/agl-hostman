# WireGuard Peer Setup Workflow

**Type**: Infrastructure Deployment
**Category**: Network Configuration
**Estimated Time**: 15-20 minutes

## Overview

Complete workflow for adding a new peer to the WireGuard mesh network with proper configuration, hub registration, and connectivity verification.

## Prerequisites

- [ ] Target host/container is accessible (LAN or Tailscale)
- [ ] WireGuard package installed on target (`apt install wireguard`)
- [ ] LXC container has `features: keyctl=1,nesting=1` if applicable
- [ ] Available IP address in 10.6.0.0/24 range
- [ ] Available port number (51800-51899)

## Specification

### Step 1: Generate WireGuard Keys
```bash
# On target peer
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# Store keys securely
PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(cat /etc/wireguard/publickey)
```

### Step 2: Create Peer Configuration
**Template**: `/etc/wireguard/wg0.conf`

**For LXC Containers** (NO PresharedKey):
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

**For Proxmox Hosts** (WITH PresharedKey):
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

**Critical Rules**:
- ⚠️ **LXC Containers**: NEVER use PresharedKey (causes handshake failure)
- ⚠️ **AllowedIPs**: Must be `10.6.0.0/24` ONLY (not `0.0.0.0/0`)
- ✅ **MTU**: Always set to 1420
- ✅ **DNS**: Use 1.1.1.1 or 8.8.8.8

### Step 3: Register Peer on Hub (FGSRV6)
```bash
# SSH to hub
ssh root@186.202.57.120

# Add peer to hub config
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = <NEW_PEER_PUBLIC_KEY>
AllowedIPs = 10.6.0.X/32
EOF

# Reload hub configuration
wg syncconf wg0 <(wg-quick strip wg0)
```

### Step 4: Start WireGuard on Peer
```bash
# On target peer
wg-quick up wg0

# Enable on boot
systemctl enable wg-quick@wg0
```

### Step 5: Verification
```bash
# Check WireGuard status
wg show

# Expected output:
# interface: wg0
#   peer: Dj8X... (hub)
#     endpoint: 186.202.57.120:51823
#     allowed ips: 10.6.0.0/24
#     latest handshake: X seconds ago
#     transfer: X received, Y sent

# Test connectivity to hub
ping -c 3 10.6.0.5

# Test connectivity to other peers
ping -c 3 10.6.0.10  # AGLSRV1
ping -c 3 10.6.0.12  # AGLSRV6
```

### Step 6: Documentation Update
Update the following files:
- [ ] `docs/INFRA.md` - Add peer to WireGuard Mesh Status table
- [ ] `CLAUDE.md` - Update infrastructure map if major host
- [ ] Commit changes: `git add docs/ && git commit -m "docs: add WireGuard peer 10.6.0.X"`

## Troubleshooting

### Handshake Never Establishes
**Symptom**: `wg show` shows no handshake timestamp
**Causes**:
- PresharedKey in LXC container → Remove it
- Wrong AllowedIPs (0.0.0.0/0) → Change to 10.6.0.0/24
- Firewall blocking UDP 51823 → Check firewall rules

**Fix**:
```bash
wg-quick down wg0
# Edit /etc/wireguard/wg0.conf (remove PresharedKey, fix AllowedIPs)
wg-quick up wg0
```

### LXC Container Fails to Start WireGuard
**Symptom**: `wg-quick up wg0` fails
**Cause**: Missing LXC features
**Fix**:
```bash
# On Proxmox host, edit container config
vim /etc/pve/lxc/<VMID>.conf

# Add these lines:
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file

# Restart container
pct stop <VMID> && pct start <VMID>
```

## Success Criteria

- [ ] WireGuard shows successful handshake (`latest handshake: < 60s`)
- [ ] Can ping hub (10.6.0.5)
- [ ] Can ping at least 2 other peers
- [ ] `wg show` displays correct endpoint and transfer stats
- [ ] Documentation updated in git
- [ ] Peer added to hub configuration

## Related Workflows

- [NFS Storage Mount](./nfs-storage-mount.md)
- [Service Deployment](./service-deployment.md)
- [Network Troubleshooting](./network-troubleshooting.md)
