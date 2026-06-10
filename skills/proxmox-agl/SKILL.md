---
name: proxmox-agl
description: >
  Manage AGL Proxmox infrastructure (AGLSRV1, AGLSRV5, AGLSRV6). Use when the user asks to
  list/start/stop/restart VMs or LXC containers, check node status, create snapshots, manage backups,
  clone containers, or troubleshoot Proxmox issues. Covers CT179 (agldv03), CT181 (agldv04), CT183 (archon), CT185 (agldv12) on AGLSRV1;
  **CT547** (agldv07; ex.241) on FGSRV7; **CT536** (agldv05; ex.136) on AGLSRV5;
  **CT608** (agldv06; ex.108) on AGLSRV6; **CT548** (evonexus; ex.242) on FGSRV7.
  VMID map: docs/PROXMOX-VMID-RENUMBER-2026-06.md
  Also handles pct unlock, cluster health, storage, and network bridges.
---
# Proxmox AGL Infrastructure

## Credentials

```bash
# AGLSRV1 (main Proxmox host)
export PROXMOX_HOST="192.168.0.245"  # LAN
export PROXMOX_USER="root"
export PROXMOX_KEY="~/.ssh/id_rsa"   # SSH-based, no API token

# AGLSRV5
export PROXMOX_HOST5="192.168.15.222"  # LAN / 100.119.223.113 Tailscale

# AGLSRV6
export PROXMOX_HOST6="100.98.108.66"  # Tailscale
```

## SSH Access

```bash
# AGLSRV1
ssh AGLSRV1          # LAN 192.168.0.245
ssh aglsrv1          # Tailscale 100.107.113.33

# AGLSRV5
ssh AGLSRV5          # Tailscale 100.119.223.113

# AGLSRV6
ssh AGLSRV6          # Tailscale 100.98.108.66
```

## Container Inventory (AGL)

| CT   | Host     | Role                          | Tailscale IP      | RAM   |
|------|----------|-------------------------------|-------------------|-------|
| 179  | AGLSRV1  | agldv03 - Main dev + LiteLLM  | 100.94.221.87     | 48GB  |
| 181  | AGLSRV1  | agldv04 - Secondary dev        | 100.113.9.98      | 48GB  |
| 183  | AGLSRV1  | archon - AI Command Center     | 100.80.30.59      | -     |
| 185  | AGLSRV1  | agldv12 - Turbo Flow clone     | 100.71.217.115    | -     |
| 136  | AGLSRV5  | agldv05 - Remote dev           | 100.119.41.63     | 8GB   |
| 108  | AGLSRV6  | agldv06 - Remote dev           | 100.71.229.12     | -     |
| 547  | FGSRV7   | agldv07 - Dev satélite         | 100.64.139.79     | 8GB   |

## Common Operations

### List all containers on AGLSRV1
```bash
ssh AGLSRV1 "pct list"
```

### Start/Stop/Restart a container
```bash
# Start (unlock first if locked)
ssh AGLSRV1 "pct unlock 179 && pct start 179"

# Stop
ssh AGLSRV1 "pct stop 179"

# Restart
ssh AGLSRV1 "pct stop 179 && sleep 3 && pct start 179"
```

### Execute command inside container
```bash
ssh AGLSRV1 "pct exec 179 -- systemctl status openclaw-gateway"
ssh AGLSRV1 "pct exec 179 -- tailscale status"
```

### Check container status
```bash
ssh AGLSRV1 "pct list" | grep -E "CTID|179|181|183|185"
```

### Unlock stuck container
```bash
ssh AGLSRV1 "pct unlock <vmid>"
```

### Clone container (CT179 → CT185 pattern)
```bash
# Stop source
ssh AGLSRV1 "pct stop 179"

# Clone
ssh AGLSRV1 "pct clone 179 185 --hostname agldv12 --full"

# Start source
ssh AGLSRV1 "pct start 179"
```

### Snapshots
```bash
# Create snapshot
ssh AGLSRV1 "pct snapshot 179 pre-update"

# List snapshots
ssh AGLSRV1 "pct listsnapshot 179"

# Rollback (container must be stopped)
ssh AGLSRV1 "pct stop 179 && pct rollback 179 pre-update && pct start 179"

# Delete snapshot
ssh AGLSRV1 "pct delsnapshot 179 pre-update"
```

### Resource monitoring
```bash
# All containers resource usage
ssh AGLSRV1 "pct list --full"

# Node resources
ssh AGLSRV1 "pvesh get /nodes"
ssh AGLSRV1 "free -h && df -h"
```

### Pi-hole CT102 (special case)
```bash
ssh AGLSRV1 "pct unlock 102 && pct start 102"
```

### Cloudflared CT117
```bash
ssh AGLSRV1 "pct exec 117 -- systemctl restart cloudflared"
```

## Troubleshooting

### Container won't start
```bash
# 1. Unlock
ssh AGLSRV1 "pct unlock <vmid>"

# 2. Check logs
ssh AGLSRV1 "pct start <vmid> 2>&1"

# 3. Check disk space
ssh AGLSRV1 "df -h"
```

### Container locked
```bash
ssh AGLSRV1 "pct unlock <vmid>"
```

### Network issues inside CT
```bash
ssh AGLSRV1 "pct exec <vmid> -- ip a"
ssh AGLSRV1 "pct exec <vmid> -- ip route"
ssh AGLSRV1 "pct exec <vmid> -- systemctl restart networking"
```

## Notes
- Always prefer `pct unlock` before `pct start` if container is stuck
- Cloned containers inherit Tailscale identity — must reset after clone
- agldv12 (CT185) is a clone of agldv03 (CT179) — OpenClaw gateway is disabled
- agldv05 and agldv06 are on remote Proxmox hosts (AGLSRV5, AGLSRV6)
