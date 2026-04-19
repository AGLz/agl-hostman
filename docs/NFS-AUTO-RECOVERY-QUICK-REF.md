# NFS Auto-Recovery Quick Reference

## 🚀 Quick Start

### Install (on management host, as root)

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
sudo scripts/monitoring/install-nfs-monitor-service.sh
```

### Manual Health Check

```bash
# Dry run (safe, no changes)
sudo scripts/monitoring/nfs-tailscale-monitor.sh --dry-run --verbose

# Full check with auto-recovery
sudo scripts/monitoring/nfs-tailscale-monitor.sh --verbose
```

### Manual Recovery

```bash
# No Proxmox local: o recovery tem de correr no AGLSRV5 (usa pct). Desde 2026-04-09 o monitor
# remoto invoca isto por SSH; para manual:
ssh root@100.119.223.113 '/usr/local/lib/agl-nfs-monitor/nfs-tailscale-recovery.sh manual'
# Ou, com repo copiado para o host:
ssh root@100.119.223.113 'bash -s manual' < scripts/monitoring/nfs-tailscale-recovery.sh
```

### Timer no AGLSRV5 (reconexão periódica sem depender do monitor remoto)

Instala remount leve a cada ~15 min (útil quando FGSRV4 volta e os mounts ficam stale):

```bash
# A partir de uma máquina com SSH ao aglsrv5
chmod +x scripts/monitoring/install-nfs-local-aglsrv5.sh
./scripts/monitoring/install-nfs-local-aglsrv5.sh root@100.119.223.113
```

No **AGLSRV5**:

```bash
systemctl list-timers agl-nfs-aglsrv5-local.timer
journalctl -u agl-nfs-aglsrv5-local.service -n 50
tail -f /var/log/agl-nfs-monitor/aglsrv5-local-$(date +%Y%m%d).log
```

## 📊 Status Checks

```bash
# View timer status
systemctl status nfs-tailscale-monitor.timer

# Next scheduled run
systemctl list-timers nfs-tailscale-monitor.timer

# View live logs
tail -f logs/nfs-monitor/monitor-$(date +%Y%m%d).log
journalctl -u nfs-tailscale-monitor.service -f
```

## 🔧 Common Issues

### NFS Mounts Missing

```bash
# Quick fix: remount
ssh root@100.119.223.113 'pct exec 138 -- mount -a'

# Ou recovery completo no Proxmox
ssh root@100.119.223.113 '/usr/local/lib/agl-nfs-monitor/nfs-tailscale-recovery.sh nfs-connectivity-critical'
```

### Tailscale Down

```bash
# Restart Tailscale on CT138
ssh root@100.119.223.113 'pct exec 138 -- systemctl restart tailscaled'
ssh root@100.119.223.113 'pct exec 138 -- tailscale up --accept-routes=false'
```

### Samba Down

```bash
# Restart Samba
ssh root@100.119.223.113 'pct exec 138 -- systemctl restart smbd nmbd'
```

### Container Stuck

```bash
# Force restart CT138
ssh root@100.119.223.113 'pct stop 138'
ssh root@100.119.223.113 'find /sys/fs/cgroup/ -name "*138*" -type d -print -delete 2>/dev/null || true'
ssh root@100.119.223.113 'pct start 138'
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `scripts/monitoring/nfs-tailscale-monitor.sh` | Health check script |
| `scripts/monitoring/nfs-tailscale-recovery.sh` | Automated recovery (Proxmox / pct) |
| `scripts/monitoring/nfs-aglsrv5-local-remount.sh` | Remount leve no AGLSRV5 |
| `scripts/monitoring/install-nfs-local-aglsrv5.sh` | Deploy timer no AGLSRV5 |
| `config/systemd/nfs-tailscale-monitor.timer` | Hourly schedule (host de gestão) |
| `config/systemd/agl-nfs-aglsrv5-local.timer` | ~15 min no AGLSRV5 |
| `logs/nfs-monitor/monitor-YYYYMMDD.log` | Daily logs |
| `docs/NFS-TAILSCALE-AUTO-RECOVERY.md` | Full documentation |

## 🔍 Monitored Hosts

| Host | Role | IP (Tailscale) | Status |
|------|------|----------------|--------|
| **FileServer5 (CT138)** | NFS Client | 100.66.136.84 | ✅ Monitored |
| **FGSRV4** | NFS Server | 100.111.79.2 | ✅ Monitored |
| **AGLSRV5** | Proxmox Host | 100.119.223.113 | ✅ Used for management |

## ⚠️ Emergency Contacts

If automated recovery fails:
1. Check logs: `logs/nfs-monitor/recovery-$(date +%Y%m%d).log`
2. Manual intervention on AGLSRV5 may be required
3. See `docs/FILESERVER5-RECOVERY-COMPLETE.md` for detailed procedures

---

**Last Updated**: 2026-04-09
