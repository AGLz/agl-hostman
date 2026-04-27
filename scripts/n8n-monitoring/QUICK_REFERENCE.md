# N8N Monitoring System - Quick Reference

## Installation

```bash
cd /root/host-admin/scripts/n8n-monitoring
sudo ./setup_monitoring.sh
```

## Daily Commands

### Check Health
```bash
./check_n8n_health.sh
```

### Trigger Recovery
```bash
./n8n_auto_recovery.sh
```

### View Status
```bash
./n8n_auto_recovery.sh --status
```

## Troubleshooting Commands

### Collect Diagnostics
```bash
./collect_diagnostics.sh
```

### Generate Log Report
```bash
./aggregate_logs.sh
```

### Reset Circuit Breaker
```bash
./n8n_auto_recovery.sh --reset-circuit-breaker
```

## Log Locations

| Log Type | Location |
|----------|----------|
| Health Checks | `/var/log/n8n-monitoring/health_check.log` |
| Recovery | `/var/log/n8n-monitoring/auto_recovery.log` |
| Incidents | `/var/log/n8n-monitoring/incidents.log` |
| Cron Jobs | `/var/log/n8n-monitoring/cron.log` |
| Reports | `/var/log/n8n-monitoring/reports/` |
| Diagnostics | `/var/log/n8n-monitoring/diagnostics/` |

## View Logs

```bash
# Real-time health monitoring
tail -f /var/log/n8n-monitoring/health_check.log

# Recent recovery attempts
tail -50 /var/log/n8n-monitoring/auto_recovery.log

# Critical incidents only
cat /var/log/n8n-monitoring/incidents.log

# Latest report
ls -t /var/log/n8n-monitoring/reports/ | head -1 | \
  xargs -I {} cat /var/log/n8n-monitoring/reports/{}
```

## Configuration

Edit `/root/host-admin/scripts/n8n-monitoring/n8n_monitor.conf`

### Key Settings

```bash
# Container name
N8N_CONTAINER_NAME=n8n

# Resource thresholds
N8N_MAX_MEMORY_PERCENT=90
N8N_MAX_CPU_PERCENT=95

# Restart limits
N8N_MAX_RESTARTS_PER_HOUR=5
N8N_MAX_RESTARTS_PER_DAY=20

# Backoff timing
N8N_INITIAL_BACKOFF=10      # seconds
N8N_MAX_BACKOFF=600         # 10 minutes
```

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Healthy | None needed |
| 1 | Warning | Monitor closely |
| 2 | Critical | Recovery triggered |
| 3 | Unknown | Check configuration |

## Safety Mechanisms

1. **Restart Limits**
   - Maximum 5 restarts per hour
   - Maximum 20 restarts per day

2. **Circuit Breaker**
   - Opens after 10 consecutive failures
   - Auto-resets after 24 hours
   - Manual reset available

3. **Exponential Backoff**
   - Starts at 10 seconds
   - Doubles each attempt
   - Caps at 10 minutes

## Scheduled Tasks

| Task | Frequency | Purpose |
|------|-----------|---------|
| Health Check | Every 5 min | Monitor status |
| Auto Recovery | Every 1 min | Attempt recovery |
| Log Aggregation | Daily 02:00 | Generate reports |
| Full Diagnostics | Weekly Sun 03:00 | Deep analysis |

## Common Issues

### Container Not Found
```bash
# List containers
docker ps -a

# Set correct name
export N8N_CONTAINER_NAME="actual-name"
./check_n8n_health.sh
```

### Circuit Breaker Open
```bash
# Check status
./n8n_auto_recovery.sh --status

# Reset if needed
./n8n_auto_recovery.sh --reset-circuit-breaker
```

### Too Many Restarts
```bash
# Check root cause
./aggregate_logs.sh

# Collect diagnostics
./collect_diagnostics.sh

# Increase limits temporarily
nano n8n_monitor.conf
# Edit: N8N_MAX_RESTARTS_PER_HOUR=10
```

### False Positives
```bash
# Adjust thresholds
nano n8n_monitor.conf
# Edit: N8N_MAX_MEMORY_PERCENT=95
# Edit: N8N_MAX_CPU_PERCENT=98
```

## Manual Operations

### Stop Monitoring Temporarily
```bash
# Disable cron jobs
sudo chmod -x /etc/cron.d/n8n-monitoring

# OR stop systemd timers
systemctl stop n8n-health-check.timer
systemctl stop n8n-auto-recovery.timer
```

### Re-enable Monitoring
```bash
# Enable cron jobs
sudo chmod +x /etc/cron.d/n8n-monitoring

# OR start systemd timers
systemctl start n8n-health-check.timer
systemctl start n8n-auto-recovery.timer
```

### Clean Old Logs
```bash
# Diagnostics older than 7 days
find /var/log/n8n-monitoring/diagnostics -mtime +7 -delete

# Reports older than 14 days
find /var/log/n8n-monitoring/reports -mtime +14 -delete

# Rotate main logs
cd /var/log/n8n-monitoring
for log in *.log; do
  [ -f "$log" ] && mv "$log" "$log.$(date +%Y%m%d)" && gzip "$log.$(date +%Y%m%d)"
done
```

## Integration Examples

### Webhook Alert
```bash
# Add to recovery script after line 500
if [[ $recovery_result -eq 2 ]]; then
  curl -X POST "https://alerts.example.com/webhook" \
    -H "Content-Type: application/json" \
    -d "{\"status\":\"critical\",\"container\":\"n8n\",\"message\":\"Recovery failed\"}"
fi
```

### Prometheus Export
```bash
# Add to cron
* * * * * root /path/to/export_metrics.sh
```

### Email Alerts
```bash
# Add to health check script
if [[ $status -eq 2 ]]; then
  echo "N8N Critical" | mail -s "N8N Alert" admin@example.com
fi
```

## Performance Tips

1. **Reduce Log Verbosity**
   ```bash
   N8N_REPORT_LINES=1000  # Default: 5000
   N8N_DIAG_LOG_LINES=500 # Default: 1000
   ```

2. **Increase Check Interval**
   ```bash
   # Edit cron: */10 instead of */5 for health checks
   ```

3. **Disable Unused Features**
   ```bash
   # Comment out in cron file
   # 0 3 * * 0 root ... # Disable weekly diagnostics
   ```

## Validation

### Test Installation
```bash
./validate_system.sh
```

### Manual Health Check
```bash
./check_n8n_health.sh
echo "Exit code: $?"
```

### Test Recovery Logic
```bash
# View recovery state
./n8n_auto_recovery.sh --status

# Check restart history
cat /var/log/n8n-monitoring/recovery_state/restart_history.log
```

## Directory Structure

```
/root/host-admin/scripts/n8n-monitoring/
├── check_n8n_health.sh          # Health monitoring
├── n8n_auto_recovery.sh         # Auto recovery
├── collect_diagnostics.sh       # Diagnostics collection
├── aggregate_logs.sh            # Log analysis
├── setup_monitoring.sh          # Installation
├── validate_system.sh           # Validation
├── n8n_monitor.conf             # Configuration
├── README.md                    # Full documentation
└── QUICK_REFERENCE.md          # This file

/var/log/n8n-monitoring/
├── health_check.log             # Health history
├── auto_recovery.log            # Recovery log
├── incidents.log                # Critical events
├── cron.log                     # Scheduled tasks
├── aggregated.log               # Combined logs
├── diagnostics/                 # Diagnostic archives
├── reports/                     # Analysis reports
└── recovery_state/              # System state
    ├── restart_history.log
    ├── circuit_breaker.state
    └── health_state.json
```

## Support Checklist

When reporting issues, provide:

1. ✓ Output of `./check_n8n_health.sh`
2. ✓ Last 50 lines of `/var/log/n8n-monitoring/auto_recovery.log`
3. ✓ Contents of `/var/log/n8n-monitoring/incidents.log`
4. ✓ Diagnostic archive from `./collect_diagnostics.sh`
5. ✓ Configuration file `n8n_monitor.conf`
6. ✓ Docker version: `docker version`
7. ✓ OS version: `cat /etc/os-release`

## Quick Fixes

| Problem | Solution |
|---------|----------|
| Container not found | Check `docker ps -a` and set `N8N_CONTAINER_NAME` |
| Permission denied | Run with `sudo` or as root |
| Circuit breaker open | `./n8n_auto_recovery.sh --reset-circuit-breaker` |
| Logs growing too large | Enable log rotation, decrease retention |
| Too many alerts | Increase thresholds in config |
| Recovery not working | Check `--status`, review incidents.log |
| Cron not running | `systemctl status cron` or `ps aux | grep cron` |

---

**Need more details?** See `README.md` for comprehensive documentation.

**Installation issues?** Run `./validate_system.sh` for detailed diagnostics.
