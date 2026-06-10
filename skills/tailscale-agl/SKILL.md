---
name: tailscale-agl
description: >
  Manage AGL Tailscale mesh network. Use when the user asks to check Tailscale status, list devices,
  ping peers, configure exit nodes, manage subnet routers, set up ACLs, create auth keys, troubleshoot
  connectivity, or manage the AGL tailnet. Covers all AGL hosts: agldv03/04/05/06/07/12, fgsrv06,
  AGLSRV1/5/6, and WireGuard mesh hub.
---
# Tailscale AGL Mesh Network

## AGL Network Topology

### Tailscale IPs

| Host        | Tailscale IP      | Role                              |
|-------------|-------------------|-----------------------------------|
| agldv03     | 100.94.221.87     | Main dev + LiteLLM gateway (src)  |
| agldv04     | 100.113.9.98      | Secondary dev + LiteLLM           |
| agldv05     | 100.119.41.63     | Remote dev (AGLSRV5)              |
| agldv06     | 100.71.229.12     | Remote dev (AGLSRV6)              |
| agldv07     | 100.64.139.79     | Dev satélite (**CT547** @ FGSRV7) |
| agldv12     | 100.71.217.115    | Turbo Flow clone (OpenClaw off)   |
| archon      | 100.80.30.59      | AI Command Center (**CT183** @ AGLSRV1) — **≠ agldv07** |
| fgsrv06     | 100.83.51.9       | VPS + WireGuard hub + LiteLLM     |
| fgsrv07     | 100.109.181.93    | Proxmox FGSRV7                    |
| AGLSRV1     | 100.107.113.33    | Proxmox host (main)               |
| AGLSRV5     | 100.119.223.113   | Proxmox host (remote)             |
| AGLSRV6     | 100.98.108.66     | Proxmox host (remote)             |

> **agldv07 vs archon:** `agldv07` = hostname **CT547** em FGSRV7 (`fgsrv07-agldv07`, LAN `192.168.70.241`). **archon** = **CT183** em AGLSRV1 (`aglsrv1-archon`, LAN `192.168.0.183`). Nunca usar `100.80.30.59` para agldv07.

### WireGuard Mesh (10.6.0.0/24)

| Host     | WireGuard IP | Role           |
|----------|-------------|----------------|
| fgsrv06  | 10.6.0.5    | **HUB** :51823 |
| agldv03  | 10.6.0.19   | Node           |
| agldv04  | 10.6.0.24   | Node           |
| agldv05  | 10.6.0.13   | Node           |
| archon   | 10.6.0.21   | Node (CT183)   |

## CLI Operations

### Status & Diagnostics
```bash
# Current status
tailscale status
tailscale status --json | jq '.Peer | to_entries[] | {name: .value.HostName, ip: .value.TailscaleIPs[0], online: .value.Online}'

# Check specific AGL hosts
tailscale status | grep -E "agldv|fgsrv|aglsrv|archon"

# Network diagnostics
tailscale netcheck
tailscale netcheck --json

# Get this machine's Tailscale IP
tailscale ip -4
```

### Connectivity Tests
```bash
# Ping AGL hosts
tailscale ping 100.94.221.87   # agldv03
tailscale ping 100.113.9.98    # agldv04
tailscale ping 100.64.139.79   # agldv07 (CT547 FGSRV7)
tailscale ping 100.83.51.9     # fgsrv06
tailscale ping 100.80.30.59    # archon (CT183)

# Check if connection is direct or relayed (DERP)
tailscale ping 100.94.221.87
```

### SSH via Tailscale
```bash
# All AGL hosts are accessible via SSH over Tailscale
ssh root@100.94.221.87    # agldv03
ssh root@100.113.9.98     # agldv04
ssh root@100.119.41.63    # agldv05
ssh root@100.71.229.12    # agldv06
ssh root@100.64.139.79    # agldv07 (CT547)
ssh root@100.71.217.115   # agldv12
ssh root@100.80.30.59     # archon (CT183)
ssh root@100.83.51.9      # fgsrv06 (uses fg_srv.pem key)
ssh root@100.109.181.93   # fgsrv07 Proxmox — ou `pct start 547` + exec no CT
```

### Expose Services
```bash
# Expose LiteLLM gateway within tailnet
tailscale serve 4000

# Check what's being served
tailscale serve status

# Funnel (public internet)
tailscale funnel 8080
```

### File Transfer (Taildrop)
```bash
# Send config to remote host
tailscale file cp config.yaml root@agldv03:

# Receive files
tailscale file get ~/Downloads
```

## API Operations (tailnet-wide)

Requires API key from Tailscale Admin Console → Settings → Keys

```bash
# List all devices
curl -s -H "Authorization: Bearer $TS_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/-/devices" | jq '.devices[] | {name, addresses, os, lastSeen}'

# Filter AGL devices
curl -s -H "Authorization: Bearer $TS_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/-/devices" | jq '.devices[] | select(.name | test("agl|fgsrv")) | {name, addresses, online}'
```

## Troubleshooting

### Host unreachable
```bash
# 1. Check Tailscale status
tailscale status | grep <hostname>

# 2. Check if daemon is running
systemctl status tailscaled

# 3. Restart Tailscale
systemctl restart tailscaled

# 4. Re-authenticate if needed
tailscale up --authkey=<key>
```

### agldv07 (CT547) offline
```bash
# CT547 costuma estar stopped — arrancar no FGSRV7:
ssh root@100.109.181.93 'pct start 547 && pct exec 547 -- tailscale ip -4'
```

### After cloning a container (CT179 → CT185)
```bash
# MUST reset Tailscale identity on clone
ssh root@100.71.217.115 "tailscale down && tailscale up --hostname=aglsrv1-agldv12 --authkey=<new-key>"
```

### WireGuard + Tailscale conflict
```bash
# Check if both are active
wg show
tailscale status

# Tailscale may use WireGuard as underlying transport — this is normal
tailscale netcheck
```

## Auth Key Creation
```bash
# Via admin console or API
curl -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
  -H "Authorization: Bearer $TS_API_KEY" \
  -d '{"Reusable": true, "Ephemeral": false, "Tags": ["tag:agl-server"], "ExpirySeconds": 86400}'
```

## Notes
- fgsrv06 is the WireGuard mesh hub — if it goes down, all WireGuard nodes lose connectivity
- Tailscale is the PRIMARY access method for all AGL hosts
- agldv12 was cloned from agldv03 — required Tailscale identity reset
- Use Tailscale IPs for SSH from external networks (this macOS host)
