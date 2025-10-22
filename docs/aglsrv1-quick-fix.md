# AGLSRV1 Quick Fix Guide

**Emergency Contact Card** - Keep this handy for quick reference

---

## Is the WebUI Working?

✅ **YES** - https://192.168.0.245:8006 is **OPERATIONAL**

All core Proxmox services are running:
- pveproxy ✅ (Port 8006)
- pvedaemon ✅ (Port 85)
- pvestatd ✅
- pve-cluster ✅

---

## Critical Issue

🔴 **/tmp filesystem is 100% FULL** (63GB rclone cache)

**Symptoms**:
- Container startup failures
- Service degradation
- Backup failures
- High memory pressure (99GB/125GB RAM used, 30GB/31GB swap used)

---

## Quick Fix (5 Minutes)

### Option 1: Emergency Cleanup (Safest)

```bash
# SSH to AGLSRV1
ssh root@192.168.0.245

# Stop rclone
systemctl stop rclone-wg.service

# Clear cache
rm -rf /tmp/rclone-gd/*

# Verify space
df -h /tmp
# Should show <10% usage

# Restart rclone
systemctl start rclone-wg.service
```

### Option 2: Automated Script

```bash
# SSH to AGLSRV1
ssh root@192.168.0.245

# Download script (if not already present)
cd /root/agl-hostman

# Run in dry-run mode first
bash scripts/aglsrv1-emergency-remediation.sh --dry-run

# Execute fixes
bash scripts/aglsrv1-emergency-remediation.sh
```

---

## Verify Fix

```bash
# Check /tmp usage (should be <50%)
df -h /tmp

# Check memory
free -h

# Check failed services (should be clean)
systemctl --failed

# Check WebUI
curl -k https://localhost:8006 | head -5
```

---

## Permanent Fix (30 Minutes)

### Reconfigure rclone Cache Location

**Edit**: `/etc/systemd/system/rclone-wg.service`

**Change cache paths from /tmp to /var/cache**:

```ini
[Service]
ExecStart=/usr/bin/rclone mount \
  --cache-dir=/var/cache/rclone-gd/vfs \
  --cache-tmp-upload-path=/var/cache/rclone-gd/upload \
  --cache-chunk-path=/var/cache/rclone-gd/chunks \
  --cache-db-path=/var/cache/rclone-gd/db \
  --vfs-cache-mode writes \
  --vfs-cache-max-size 10G \
  --vfs-cache-max-age 1m \
  ... (other options)
```

**Changes**:
- `/tmp/rclone-gd` → `/var/cache/rclone-gd` (persistent storage)
- `--vfs-cache-mode full` → `--vfs-cache-mode writes` (less aggressive)
- Add `--vfs-cache-max-size 10G` (limit cache size)

**Apply**:
```bash
mkdir -p /var/cache/rclone-gd/{vfs,upload,chunks,db}
systemctl daemon-reload
systemctl restart rclone-wg.service
df -h /tmp  # Verify <10% usage
```

---

## Other Quick Fixes

### Fix Obsolete Mount Services

```bash
systemctl disable mnt-pve-fgsrv5\\x2dnfs.mount
systemctl disable mnt-pve-fgsrv6\\x2dnfs.mount
systemctl reset-failed
```

### Remove Orphaned Container Service

```bash
systemctl disable pve-container@999.service
systemctl reset-failed
```

### Restart ollama-gpu (CT200)

```bash
pct start 200
pct status 200
```

### Clean Corrupted Storage Configs

```bash
pvesm remove fgsrv5-nfs
pvesm remove fgsrv6-nfs
pvesm status  # Verify clean output
```

---

## Monitoring Commands

```bash
# Watch /tmp usage
watch -n 5 'df -h /tmp'

# Watch memory
watch -n 5 'free -h'

# Watch failed services
watch -n 30 'systemctl --failed --no-pager'

# Check top memory consumers
ps aux --sort=-%mem | head -10
```

---

## When to Escalate

Escalate to full diagnostics if:
- /tmp remains >90% after cleanup
- Memory pressure >90% RAM + >90% swap
- Load average >10.0 sustained
- Any pve* service fails after restart
- WebUI becomes unresponsive

---

## Support Files

- Full diagnostics: `/root/agl-hostman/docs/aglsrv1-service-diagnostics-2025-10-21.md`
- Key findings: `/root/agl-hostman/docs/aglsrv1-key-findings.md`
- Auto-remediation: `/root/agl-hostman/scripts/aglsrv1-emergency-remediation.sh`

---

## Success Metrics

✅ /tmp usage <50%
✅ Memory <80% RAM, <50% swap
✅ Load average <4.0
✅ Zero failed pve* services
✅ WebUI responsive

---

**Last Updated**: 2025-10-21 23:00
**Next Review**: After remediation (24-48 hours)
