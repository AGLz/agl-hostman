# CT202 (N8N) Quick Reference Guide

**Last Updated**: 2025-10-14
**Service**: CT202 (n8n-docker) on AGLSRV1

---

## Quick Health Check

```bash
# One-line health check
ssh root@AGLSRV1 "/root/scripts/ct202-health-check.sh"

# Check temperatures
ssh root@AGLSRV1 "sensors | grep -E 'Package id|temp1|Composite'"

# Check CT202 status
ssh root@AGLSRV1 "pct status 202"

# Check n8n logs
ssh root@AGLSRV1 "pct exec 202 -- docker logs n8n --tail 50"
```

---

## Common Issues & Solutions

### Issue: Container Not Responding

**Solution**:
```bash
# 1. Stop container
ssh root@AGLSRV1 "pct stop 202"

# 2. Run filesystem check
ssh root@AGLSRV1 "pct fsck 202"

# 3. If errors, force repair
ssh root@AGLSRV1 "e2fsck -fy /spark/base/images/202/vm-202-disk-0.raw"

# 4. Restart container
ssh root@AGLSRV1 "pct start 202"
```

### Issue: N8N Not Accessible

**Solution**:
```bash
# Restart n8n service
ssh root@AGLSRV1 "pct exec 202 -- docker compose restart n8n"

# Check logs
ssh root@AGLSRV1 "pct exec 202 -- docker logs n8n --tail 30"
```

---

## Critical Temperatures (Current Status: ⚠️ WARNING)

**CURRENT READINGS** (2025-10-14 17:13):
- **CPU Package 1**: **76°C** ⚠️ (approaching limit)
- **Network Cards**: **94°C** 🔴 **CRITICAL!**
- **CPU Package 0**: 62°C ✅

**URGENT**: Network cards at 94°C require immediate attention!

---

## Monitoring Logs

```bash
/var/log/ct202-health.log           # Health status
/var/log/ct202-recovery.log         # Recovery attempts
/var/log/temperature-monitor.log    # Temperature history
/var/log/temperature-metrics/       # CSV metrics
```

---

## Emergency Commands

```bash
# Force restart CT202
pct stop 202 --force && sleep 10 && pct start 202

# Check hardware temps
sensors | grep -E "Package id|temp1"

# Manual filesystem repair
pct stop 202 && e2fsck -fy /spark/base/images/202/vm-202-disk-0.raw && pct start 202
```

---

*Quick Reference - Version 1.0*
