---
name: wireguard-agl
description: >
  Manage WireGuard mesh network on AGL infrastructure. Use when working with WireGuard
  tunnels, wg0 interface, peer configuration, mesh routing, or troubleshooting WireGuard
  connectivity. Covers the AGL WireGuard mesh (10.6.0.0/24) with fgsrv06 as hub (10.6.0.5:51823)
  and nodes: agldv03 (10.6.0.19), agldv04 (10.6.0.24), agldv05 (10.6.0.13), agldv07 (10.6.0.21).
---
# WireGuard AGL Mesh Network

## Network Topology

```
                    ┌─────────────────────┐
                    │   fgsrv06 (HUB)     │
                    │   10.6.0.5:51823    │
                    │   100.83.51.9 (TS)  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
   ┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐
   │ agldv03     │     │ agldv04     │     │ agldv05     │
   │ 10.6.0.19   │     │ 10.6.0.24   │     │ 10.6.0.13   │
   │ 100.94.x.x  │     │ 100.113.x.x │     │ 100.119.x.x │
   └─────────────┘     └─────────────┘     └─────────────┘
          │
   ┌──────┴──────┐
   │ agldv07     │
   │ 10.6.0.21   │
   │ 100.80.x.x  │
   └─────────────┘
```

## WireGuard IPs

| Host     | WireGuard IP | Tailscale IP      | Role     |
|----------|-------------|-------------------|----------|
| fgsrv06  | 10.6.0.5    | 100.83.51.9       | **HUB**  |
| agldv03  | 10.6.0.19   | 100.94.221.87     | Node     |
| agldv04  | 10.6.0.24   | 100.113.9.98      | Node     |
| agldv05  | 10.6.0.13   | 100.119.41.63     | Node     |
| agldv07  | 10.6.0.21   | 100.80.30.59      | Node     |

## Configuration Files

```bash
# WireGuard config location
/etc/wireguard/wg0.conf

# On fgsrv06 (hub) - has all peer configs
/etc/wireguard/wg0.conf

# On nodes - point to hub
/etc/wireguard/wg0.conf
```

### Example wg0.conf (node)
```ini
[Interface]
PrivateKey = <node-private-key>
Address = 10.6.0.19/24
ListenPort = 51820

[Peer]
PublicKey = <fgsrv06-public-key>
Endpoint = 100.83.51.9:51823
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
```

### Example wg0.conf (hub - fgsrv06)
```ini
[Interface]
PrivateKey = <hub-private-key>
Address = 10.6.0.5/24
ListenPort = 51823

[Peer]
# agldv03
PublicKey = <agldv03-public-key>
AllowedIPs = 10.6.0.19/32

[Peer]
# agldv04
PublicKey = <agldv04-public-key>
AllowedIPs = 10.6.0.24/32

[Peer]
# agldv05
PublicKey = <agldv05-public-key>
AllowedIPs = 10.6.0.13/32

[Peer]
# agldv07
PublicKey = <agldv07-public-key>
AllowedIPs = 10.6.0.21/32
```

## CLI Operations

### Check WireGuard status
```bash
# On any host
sudo wg show

# Detailed status
sudo wg show all

# Show interfaces
sudo wg show interfaces
```

### Check connectivity
```bash
# Ping hub from node
ping -c 3 10.6.0.5

# Ping node from hub
ping -c 3 10.6.0.19

# Check handshake
sudo wg show | grep -A5 "latest handshake"
```

### Start/Stop/Restart WireGuard
```bash
# Start
sudo wg-quick up wg0

# Stop
sudo wg-quick down wg0

# Restart
sudo systemctl restart wg-quick@wg0

# Enable on boot
sudo systemctl enable wg-quick@wg0
```

### Check WireGuard service
```bash
systemctl status wg-quick@wg0
journalctl -u wg-quick@wg0 -n 50
```

## Generate Keys
```bash
# Generate private key
wg genkey > private.key

# Generate public key from private
wg pubkey < private.key > public.key

# Or one-liner
wg genkey | tee private.key | wg pubkey > public.key
```

## Add New Peer
```bash
# On hub (fgsrv06)
# 1. Get peer's public key
# 2. Add to wg0.conf
sudo bash -c 'cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
# new-host
PublicKey = <new-public-key>
AllowedIPs = 10.6.0.XX/32
EOF'

# 3. Restart
sudo systemctl restart wg-quick@wg0
```

## Troubleshooting

### No connectivity
```bash
# 1. Check WireGuard is running
sudo wg show

# 2. Check interface
ip a show wg0

# 3. Check routing
ip route | grep 10.6.0

# 4. Check firewall
sudo ufw status
sudo iptables -L -n | grep 5182
```

### Handshake failing
```bash
# Check endpoint reachability
ping <endpoint-ip>

# Check port is open
nc -zv <endpoint-ip> 51823

# Check keys match
sudo wg show | grep publicKey
```

### WireGuard + Tailscale conflict
```bash
# Both can coexist — Tailscale may use WireGuard as transport
# Check which is being used
tailscale netcheck

# If Tailscale uses WireGuard directly, this is normal
# Tailscale IP → WireGuard IP mapping is handled by routing
```

### fgsrv06 hub down (CRITICAL)
```bash
# If hub is down, ALL WireGuard nodes lose connectivity
# Check fgsrv06 status
ssh root@100.83.51.9 "sudo wg show"  # via Tailscale

# If fgsrv06 unreachable, use Locaweb API
./scripts/locaweb-api/lw fgsrv06
./scripts/locaweb-api/lw reboot fgsrv06  # emergency reboot
```

## Monitoring

### Quick health check
```bash
#!/bin/bash
echo "=== WireGuard Mesh Health ==="
for ip in 10.6.0.5 10.6.0.19 10.6.0.24 10.6.0.13 10.6.0.21; do
  if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
    echo "  ✓ $ip"
  else
    echo "  ✗ $ip"
  fi
done
```

### Check handshakes
```bash
sudo wg show | grep "latest handshake" | while read line; do
  echo "$line"
  # If handshake > 2 min ago, peer may be down
done
```

## Notes
- fgsrv06 is the **single point of failure** for WireGuard mesh
- WireGuard is legacy — Tailscale is the PRIMARY access method
- Tailscale may use WireGuard as underlying transport (normal)
- Port 51823 on fgsrv06 must be open in firewall
- UFW rule for wg0: `sudo ufw allow in on wg0`
