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
# Trigger full recovery
sudo scripts/monitoring/nfs-tailscale-recovery.sh manual
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

# Or trigger full recovery
sudo scripts/monitoring/nfs-tailscale-recovery.sh nfs-connectivity-critical
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
| `scripts/monitoring/nfs-tailscale-recovery.sh` | Automated recovery |
| `config/systemd/nfs-tailscale-monitor.timer` | Hourly schedule |
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

**Last Updated**: 2026-04-06
