# WireGuard Network Management Skill

Infrastructure skill for managing the AGL WireGuard mesh network (10.6.0.0/24).

## Quick Start

```bash
# Check mesh status
./scripts/wg-status.sh

# Add new peer
./scripts/wg-add-peer.sh <hostname> <ip> <port> [type]

# Remove peer
./scripts/wg-remove-peer.sh <ip>

# Rotate keys
./scripts/wg-rotate-keys.sh <peer_name>
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Main skill documentation |
| `scripts/wg-add-peer.sh` | Add new WireGuard peer |
| `scripts/wg-remove-peer.sh` | Remove WireGuard peer |
| `scripts/wg-status.sh` | Check mesh status |
| `scripts/wg-rotate-keys.sh` | Rotate WireGuard keys |
| `templates/wg-config.conf` | Peer configuration template |
| `templates/wg-peer-config.conf` | Hub peer registration template |

## Network Overview

- **Network**: 10.6.0.0/24
- **Hub**: FGSRV6 (186.202.57.120:51823)
- **Active Peers**: 16
- **Locations**: AGLHQ, AGLALD, AGLFG-VPS

## Key Information

| Item | Value |
|------|-------|
| Hub IP | 10.6.0.5 |
| Hub Endpoint | 186.202.57.120:51823 |
| Hub Public Key | `Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8=` |
| Pre-shared Key | `DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk=` (hosts only) |

## Common Tasks

### Add New Peer

```bash
./scripts/wg-add-peer.sh new-container 10.6.0.25 51825 container
```

### Check Connectivity

```bash
./scripts/wg-status.sh --test-peers
```

### Remove Peer

```bash
./scripts/wg-remove-peer.sh 10.6.0.25
```

### Rotate Keys

```bash
./scripts/wg-rotate-keys.sh ct120
```

## Critical Rules

1. **LXC Containers**: NEVER use PresharedKey (causes handshake failure)
2. **AllowedIPs**: Always `10.6.0.0/24` (NOT `0.0.0.0/0`)
3. **MTU**: Always set to 1420
4. **PersistentKeepalive**: Set to 25 seconds for NAT traversal

## LXC Container Requirements

For WireGuard in LXC containers, add to `/etc/pve/lxc/<VMID>.conf`:

```ini
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

## Related Documentation

- Main: `docs/WIREGUARD.md`
- Infrastructure: `docs/INFRA.md`
- Network: `docs/NETWORK-TOPOLOGY.md`
