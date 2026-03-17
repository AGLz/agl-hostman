---
name: AGL Infrastructure
description: Manage AGL infrastructure including Proxmox CTs/VMs, WireGuard mesh network, storage monitoring, Tailscale VPN, and LiteLLM integration. Use this skill when performing infrastructure operations like starting/stopping containers, checking storage alerts, verifying network connectivity, or managing AI stack services. Essential for tasks involving CT179 (agldv03), AGLSRV1, AGLSRV6, WireGuard peers, NFS mounts, or LiteLLM gateway status.
---

# AGL Infrastructure Management

Quick reference for managing AGL infrastructure components.

## Hosts Reference

| Host | Tailscale IP | WireGuard IP | LAN IP | Role |
|------|-------------|--------------|--------|------|
| **AGLSRV1** | 100.107.113.33 | 10.6.0.10 | 192.168.0.245 | Proxmox principal |
| **AGLSRV6** | 100.98.108.66 | 10.6.0.12 | - | Proxmox secundario |
| **FGSRV6** | 100.83.51.9 | 10.6.0.5 | - | WireGuard hub |
| **CT179** (agldv03) | 100.94.221.87 | 10.6.0.19 | 192.168.0.179 | Dev principal |
| **CT111** (aluzdivina) | 100.65.189.83 | 10.6.0.20 | - | NFS server |

## Proxmox Container Commands

### List and Status

```bash
# List all containers (from AGLSRV1)
ssh root@192.168.0.245 'pct list'

# List all VMs
ssh root@192.168.0.245 'qm list'

# Check specific container status
ssh root@192.168.0.245 'pct status <VMID>'

# Storage status
ssh root@192.168.0.245 'pvesm status'
```

### Start/Stop/Restart Containers

```bash
# Start container
ssh root@192.168.0.245 'pct start <VMID>'

# Stop container (graceful)
ssh root@192.168.0.245 'pct stop <VMID>'

# Force stop
ssh root@192.168.0.245 'pct stop <VMID> --force'

# Restart container
ssh root@192.168.0.245 'pct reboot <VMID>'
```

### Unlock Locked Containers

Containers can get locked during backup snapshots. Always unlock AND start:

```bash
# Unlock and start (common pattern)
ssh root@192.168.0.245 'pct unlock <VMID> && pct start <VMID>'

# Example: CT102 (pihole)
ssh root@192.168.0.245 'pct unlock 102 && pct start 102'
```

### Container Console Access

```bash
# Enter container console (from Proxmox host)
pct enter <VMID>

# Execute command in container
pct exec <VMID> -- <command>

# Example: Check cloudflared in CT117
ssh root@192.168.0.245 'pct exec 117 -- systemctl status cloudflared'
```

### VM Commands (QEMU)

```bash
# VM status
ssh root@192.168.0.245 'qm status <VMID>'

# Start VM
ssh root@192.168.0.245 'qm start <VMID>'

# Stop VM
ssh root@192.168.0.245 'qm stop <VMID>'

# VM guest exec (for VMs with QEMU agent)
ssh root@192.168.0.245 'qm guest exec <VMID> -- <command>'

# Example: Check OpenClaw in VM104 (aglwk45)
ssh root@192.168.0.245 'qm guest exec 104 -- openclaw --version'
```

## Storage Monitoring

### Critical Thresholds

| Storage | Size | Current Usage | Alert Threshold |
|---------|------|---------------|-----------------|
| spark | 7.1TB | ~91.5% | 90% |
| overpower | 9.8TB | ~92.5% | 90% |

### Storage Commands

```bash
# Quick storage check
ssh root@192.168.0.245 'df -h | grep -E "(spark|overpower|local)"'

# ZFS pool status
ssh root@192.168.0.245 'zpool status'

# ZFS pool list with usage
ssh root@192.168.0.245 'zpool list'

# Run storage alert script
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/storage-alert.sh

# Check NFS mounts
df -h | grep -E "(wg|nfs)"

# Remount stale NFS
umount -f /mnt/pve/fgsrv6-wg && mount -a
```

### NFS Mount Verification

```bash
# Check FGSRV6 exports
showmount -e 10.6.0.5

# Check CT111 exports
showmount -e 10.6.0.20

# Mount options verification
mount | grep nfs4
```

## Network Status

### WireGuard Mesh

```bash
# Show WireGuard status
wg show

# Check peer handshakes (should be < 3 min)
wg show wg0 latest-handshakes

# Transfer statistics
wg show wg0 transfer

# Ping test to hub
ping -c 3 10.6.0.5

# Ping test to AGLSRV6
ping -c 3 10.6.0.12
```

### WireGuard Quick Troubleshooting

```bash
# No handshake - check firewall
iptables -L -n | grep 51823

# Intermittent - check MTU
ip link show wg0

# Test with DF bit
ping -M do -s 1372 10.6.0.5
```

### Tailscale

```bash
# Tailscale status
tailscale status

# List peers (first 20)
tailscale status --peers | head -20

# Ping via Tailscale
tailscale ping <hostname>

# Check routes
tailscale status --verbose | grep -A5 "Routes"
```

### Network Priority (CT179/agldv03)

**Priority**: WireGuard > LAN > Tailscale

```bash
# Fastest route to AGLSRV6
ssh root@10.6.0.12  # WireGuard (preferred)

# Fallback via Tailscale
ssh root@100.98.108.66

# LAN only works locally
ssh root@192.168.0.245  # AGLSRV1 only
```

## LiteLLM Integration

### Service Status

```bash
# Check LiteLLM health (from agldv03)
curl -s http://localhost:4000/health

# List available models
curl -s http://localhost:4000/v1/models | jq '.data[].id'

# Check LiteLLM config
cat /mnt/overpower/apps/dev/agl/agl-hostman/config/litellm/config.yaml
```

### LiteLLM Endpoints

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Health | http://localhost:4000/health | Service status |
| Models | http://localhost:4000/v1/models | Available models |
| Chat | http://localhost:4000/v1/chat/completions | Chat completions |

### Environment Variables

```bash
# In src/.env
ANTHROPIC_BASE_URL=http://localhost:4000
ANTHROPIC_API_KEY=sk-litellm-default

# Claude Code settings
# .claude/settings.json already configured
```

## AI Stack Services

### Ruflo Daemon

```bash
# Check Ruflo daemon status
npx ruflo@latest daemon status

# Start Ruflo daemon
npx ruflo@latest daemon start

# Stop Ruflo daemon
npx ruflo@latest daemon stop
```

### Hive Mind

```bash
# Hive Mind status
npx ruflo@latest hive-mind status

# List active workers
npx ruflo@latest hive-mind workers

# Memory search
npx ruflo@latest memory search --query "infrastructure patterns"
```

## Common CT/VM Reference

### AGLSRV1 Key Containers

| VMID | Name | Purpose | Status |
|------|------|---------|--------|
| 102 | pihole | DNS/DHCP | Critical |
| 117 | cloudflared | Cloudflare tunnel | Active |
| 120 | wireguard | WG node | Active |
| 179 | agldv03 | Primary dev | Active |
| 183 | archon | AI Command Center | Active |
| 200 | ollama-gpu | LLM compute (GPU) | Active |

### Quick Actions

```bash
# Restart pihole (CT102)
ssh root@192.168.0.245 'pct exec 102 -- systemctl restart pihole-FTL'

# Restart cloudflared (CT117)
ssh root@192.168.0.245 'pct exec 117 -- systemctl restart cloudflared'

# Check Archon status (CT183)
ssh root@192.168.0.245 'pct exec 183 -- systemctl status archon'

# Ollama GPU status (CT200)
ssh root@192.168.0.245 'pct exec 200 -- ollama ps'
```

## Monitoring Scripts

### Available Scripts

```bash
# Storage alert (threshold: 90%)
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/storage-alert.sh

# Host health check
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/host-health.sh

# AI stack health
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/ai-stack-health.sh

# WireGuard mesh status
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/wireguard-mesh.sh

# Morning briefing
/mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/morning-briefing.sh
```

### Setup Systemd Timer

```bash
# Install monitoring timer (15 min interval)
sudo ./scripts/setup-monitoring.sh

# Check timer status
systemctl status hostman-monitor.timer
```

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| CT locked (snapshot) | `pct unlock <VMID> && pct start <VMID>` |
| CT102 (pihole) stopped | `ssh root@192.168.0.245 'pct unlock 102 && pct start 102'` |
| Cloudflared (CT117) no tunnel | `pct exec 117 -- systemctl restart cloudflared` |
| DNS issues on AGLSRV1 | `tailscale set --accept-dns=false`; edit `/etc/resolv.conf` |
| Host overloaded | Check load, swap, zombies; stop VM125 if needed |
| WireGuard no handshake | Check firewall `iptables -L -n | grep 51823` |
| NFS mount stale | `umount -f /mnt/pve/<mount> && mount -a` |
| LiteLLM not responding | Check daemon: `curl http://localhost:4000/health` |
| Ruflo daemon down | `npx ruflo@latest daemon start` |

## Important Notes

1. **Never restart CT from within itself** - Always from host or Proxmox UI
2. **Storage is critical** - spark/overpower at 91-92%, check before large writes
3. **WireGuard first** - Use 10.6.0.x addresses when available (faster)
4. **VM104 has no SSH** - Use `qm guest exec 104` from AGLSRV1
5. **Read INFRA.md first** - For any infrastructure task, consult docs/INFRA.md
