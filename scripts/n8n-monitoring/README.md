# N8N Container Monitoring & Auto-Recovery System

A production-ready monitoring and recovery system for n8n containers running on Proxmox LXC environments with Docker.

## Features

### 🔍 Health Monitoring
- **Comprehensive health checks** covering container status, resource usage, HTTP endpoints, and log analysis
- **Configurable thresholds** for CPU, memory, and response times
- **Multi-level status reporting** (healthy, warning, critical, unknown)
- **Persistent state tracking** across monitoring sessions

### 🔄 Auto-Recovery
- **Intelligent restart logic** with exponential backoff
- **Circuit breaker pattern** to prevent infinite restart loops
- **Safety limits** for hourly/daily restart attempts
- **Graceful shutdown** with configurable timeouts
- **Post-restart health verification** to ensure successful recovery

### 📊 Diagnostics Collection
- **Comprehensive data gathering** including container logs, metrics, network info, and system state
- **Automated issue analysis** with actionable insights
- **Tarball archives** for easy sharing and troubleshooting
- **Automatic cleanup** of old diagnostic data

### 📈 Log Aggregation
- **Multi-source log collection** from container, health checks, and recovery operations
- **Pattern analysis** for errors, warnings, and performance issues
- **Time-based distribution** analysis
- **Health score calculation** based on log patterns
- **Automated reporting** with detailed breakdowns

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    N8N Container                             │
│                  (Docker/Compose)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌────────┐  ┌──────────┐  ┌──────────┐
   │ Health │  │ Recovery │  │   Logs   │
   │ Check  │  │  System  │  │Aggregator│
   └────┬───┘  └────┬─────┘  └────┬─────┘
        │           │             │
        │           │             │
        ▼           ▼             ▼
   ┌────────────────────────────────┐
   │   Monitoring Logs & Reports    │
   │  /var/log/n8n-monitoring/      │
   └────────────────────────────────┘
```

## Quick Start

### Installation

```bash
# Navigate to the monitoring directory
cd /root/host-admin/scripts/n8n-monitoring

# Run setup script as root
sudo ./setup_monitoring.sh
```

The setup script will:
1. Check requirements (Docker, curl, bash 4+)
2. Create necessary directories
3. Set up log rotation
4. Configure scheduled tasks (cron or systemd timers)
5. Run initial tests

### Manual Commands

```bash
# Check n8n health
./check_n8n_health.sh

# Trigger recovery if needed
./n8n_auto_recovery.sh

# Collect full diagnostics
./collect_diagnostics.sh

# Generate log analysis report
./aggregate_logs.sh

# View recovery system status
./n8n_auto_recovery.sh --status

# Reset circuit breaker
./n8n_auto_recovery.sh --reset-circuit-breaker
```

## Configuration

Edit `n8n_monitor.conf` to customize behavior:

```bash
# Container identification
N8N_CONTAINER_NAME=n8n           # Container name to monitor
N8N_HTTP_PORT=5678               # HTTP port for health checks

# Resource thresholds
N8N_MAX_MEMORY_PERCENT=90        # Memory usage alert threshold
N8N_MAX_CPU_PERCENT=95           # CPU usage alert threshold

# Recovery limits
N8N_MAX_RESTARTS_PER_HOUR=5      # Maximum restarts per hour
N8N_MAX_RESTARTS_PER_DAY=20      # Maximum restarts per day

# Backoff strategy
N8N_INITIAL_BACKOFF=10           # Initial backoff in seconds
N8N_MAX_BACKOFF=600              # Maximum backoff (10 minutes)
N8N_BACKOFF_MULTIPLIER=2         # Exponential backoff multiplier
```

## Components

### 1. Health Check Script (`check_n8n_health.sh`)

Performs comprehensive health checks on the n8n container.

**Features:**
- Container status verification
- Resource usage monitoring (CPU, memory)
- HTTP endpoint testing with response time measurement
- Log analysis for errors and warnings
- Restart count tracking
- Uptime monitoring

**Exit Codes:**
- `0` - Healthy
- `1` - Warning
- `2` - Critical
- `3` - Unknown

**Usage:**
```bash
./check_n8n_health.sh

# Environment variable overrides
N8N_CONTAINER_NAME=my-n8n N8N_HTTP_PORT=8080 ./check_n8n_health.sh
```

### 2. Auto Recovery Script (`n8n_auto_recovery.sh`)

Automatically recovers unhealthy n8n containers with safety mechanisms.

**Features:**
- Exponential backoff between restart attempts
- Circuit breaker to prevent restart storms
- Safety limits (hourly/daily restart caps)
- Graceful shutdown with force fallback
- Post-restart health verification
- Incident logging

**Safety Mechanisms:**
- Maximum 5 restarts per hour
- Maximum 20 restarts per day
- Circuit breaker opens after 10 consecutive failures
- Automatic cooldown periods
- Manual override capability

**Usage:**
```bash
# Automatic recovery attempt
./n8n_auto_recovery.sh

# Check recovery system status
./n8n_auto_recovery.sh --status

# Reset circuit breaker manually
./n8n_auto_recovery.sh --reset-circuit-breaker
```

### 3. Diagnostics Collection (`collect_diagnostics.sh`)

Collects comprehensive diagnostic data for troubleshooting.

**Collected Data:**
- Container inspection and stats
- Container logs (configurable lines)
- Network configuration and connectivity
- Resource usage metrics (5 samples over 10 seconds)
- Docker environment information
- System information (CPU, memory, disk)
- Monitoring logs and state files
- Automated issue analysis

**Output:**
- Timestamped directory with all diagnostic files
- Compressed tarball for easy sharing
- Summary report with findings

**Usage:**
```bash
# Full diagnostic collection
./collect_diagnostics.sh

# Quick collection (fewer log lines, faster)
./collect_diagnostics.sh --quick

# Logs only (fastest)
./collect_diagnostics.sh --logs-only
```

### 4. Log Aggregation (`aggregate_logs.sh`)

Aggregates and analyzes logs from multiple sources.

**Features:**
- Multi-source collection (container, health checks, recovery logs)
- Error and warning pattern detection
- Performance issue identification
- Restart event tracking
- Time-based distribution analysis
- Health score calculation
- Automated report generation

**Analysis Sections:**
- Error frequency analysis
- Warning frequency analysis
- Performance issue detection
- Restart event timeline
- Incident pattern analysis
- Time distribution (hourly)
- Overall health score

**Usage:**
```bash
# Full log aggregation and analysis
./aggregate_logs.sh

# Quick analysis (1000 lines)
./aggregate_logs.sh --quick

# Generate report from existing aggregated log
./aggregate_logs.sh --report-only
```

## Scheduled Tasks

The system automatically runs the following scheduled tasks:

| Task | Frequency | Purpose |
|------|-----------|---------|
| Health Check | Every 5 minutes | Monitor container health |
| Auto Recovery | Every minute | Attempt recovery if needed (safety limits apply) |
| Log Aggregation | Daily at 02:00 | Generate daily log analysis report |
| Full Diagnostics | Weekly (Sunday 03:00) | Comprehensive diagnostic collection |

### Using Cron

Scheduled tasks are configured in `/etc/cron.d/n8n-monitoring`

```bash
# View cron configuration
cat /etc/cron.d/n8n-monitoring

# View cron logs
tail -f /var/log/n8n-monitoring/cron.log
```

### Using Systemd Timers

Alternatively, use systemd timers for better logging and management:

```bash
# Enable health check timer
systemctl enable --now n8n-health-check.timer

# Enable recovery timer
systemctl enable --now n8n-auto-recovery.timer

# Check timer status
systemctl list-timers | grep n8n

# View service logs
journalctl -u n8n-health-check.service -f
journalctl -u n8n-auto-recovery.service -f
```

## Logs and Reports

All logs are stored in `/var/log/n8n-monitoring/`:

```
/var/log/n8n-monitoring/
├── health_check.log          # Health check history
├── auto_recovery.log         # Recovery attempts and results
├── incidents.log             # Critical incident log
├── aggregated.log            # Aggregated logs from all sources
├── cron.log                  # Cron job execution log
├── diagnostics/              # Diagnostic collections
│   ├── diag_20241014_120000/ # Timestamped diagnostic data
│   └── n8n_diagnostics_*.tar.gz # Compressed archives
├── reports/                  # Log analysis reports
│   └── report_20241014_*.txt # Daily analysis reports
└── recovery_state/           # Recovery system state
    ├── restart_history.log   # Restart event history
    ├── circuit_breaker.state # Circuit breaker state
    └── health_state.json     # Latest health check state
```

## Monitoring Dashboard

View real-time monitoring status:

```bash
# Health check status
tail -f /var/log/n8n-monitoring/health_check.log

# Recovery activity
tail -f /var/log/n8n-monitoring/auto_recovery.log

# Incidents only
tail -f /var/log/n8n-monitoring/incidents.log

# All activity
tail -f /var/log/n8n-monitoring/*.log

# Latest report
ls -t /var/log/n8n-monitoring/reports/ | head -1 | xargs -I {} cat /var/log/n8n-monitoring/reports/{}
```

## Troubleshooting

### Container Not Found

If the scripts can't find your n8n container:

```bash
# List all containers
docker ps -a

# Set container name explicitly
export N8N_CONTAINER_NAME="your-container-name"
./check_n8n_health.sh
```

### Circuit Breaker Stuck Open

If the circuit breaker prevents recovery attempts:

```bash
# Check status
./n8n_auto_recovery.sh --status

# Reset circuit breaker
./n8n_auto_recovery.sh --reset-circuit-breaker

# Check logs for root cause
./aggregate_logs.sh
```

### High False Positive Rate

If health checks are too sensitive:

```bash
# Edit configuration
nano /root/host-admin/scripts/n8n-monitoring/n8n_monitor.conf

# Adjust thresholds
N8N_MAX_MEMORY_PERCENT=95  # Increase from 90%
N8N_MAX_CPU_PERCENT=98     # Increase from 95%

# Reload configuration (restart cron or timers)
systemctl restart cron
```

### Recovery Not Working

Check the recovery system status:

```bash
# View status
./n8n_auto_recovery.sh --status

# Check recent recovery logs
tail -50 /var/log/n8n-monitoring/auto_recovery.log

# Collect full diagnostics
./collect_diagnostics.sh
```

## Security Considerations

1. **Log Permissions**: Logs contain container information; ensure appropriate permissions
2. **Root Access**: Scripts require root access to manage Docker containers
3. **Sensitive Data**: Diagnostic archives may contain environment variables; review before sharing
4. **Network Exposure**: HTTP health checks are internal-only by default

## Performance Impact

- **Health checks**: Minimal (<1% CPU, <10MB memory)
- **Log aggregation**: Low (<5% CPU during analysis)
- **Diagnostics collection**: Moderate (I/O intensive for ~30 seconds)
- **Auto recovery**: High during restart (Docker stop/start overhead)

## Compatibility

- **OS**: Ubuntu 20.04+, Debian 10+, RHEL 8+, any Linux with Docker
- **Docker**: Docker 20.10+ or Docker Compose 2.0+
- **Bash**: 4.0 or higher
- **Proxmox**: LXC containers with nested Docker support

## Advanced Usage

### Custom Health Checks

Add custom health check logic to `check_n8n_health.sh`:

```bash
# Add after line 450 (in perform_health_check function)

# Custom database check
echo -n "Checking database connection... "
if docker exec "${container_id}" n8n healthcheck:db 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    overall_status=${EXIT_CRITICAL}
fi
```

### Integration with External Monitoring

Export metrics to monitoring systems:

```bash
# Export Prometheus metrics
./check_n8n_health.sh 2>&1 | grep -E "CPU|Memory" | \
    sed 's/.*: \([0-9.]*\)%.*/n8n_\L\1 \1/' > /var/lib/node_exporter/n8n.prom

# Webhook alerting (add to scripts)
curl -X POST "https://alerts.example.com/webhook" \
    -H "Content-Type: application/json" \
    -d '{"status":"critical","container":"n8n","message":"Recovery failed"}'
```

### Multi-Container Monitoring

Monitor multiple n8n instances:

```bash
# Create separate directories
for instance in n8n-prod n8n-staging n8n-dev; do
    cp -r /root/host-admin/scripts/n8n-monitoring "/root/host-admin/scripts/${instance}-monitoring"
    sed -i "s/N8N_CONTAINER_NAME=n8n/N8N_CONTAINER_NAME=${instance}/" \
        "/root/host-admin/scripts/${instance}-monitoring/n8n_monitor.conf"
done
```

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:
1. Review logs in `/var/log/n8n-monitoring/`
2. Run diagnostics collection: `./collect_diagnostics.sh`
3. Check configuration: `cat n8n_monitor.conf`
4. Review incident log: `cat /var/log/n8n-monitoring/incidents.log`

## Changelog

### Version 1.0.0 (2024-10-14)
- Initial release
- Health monitoring with comprehensive checks
- Auto-recovery with exponential backoff and circuit breaker
- Diagnostic data collection
- Log aggregation and analysis
- Automated scheduling via cron and systemd
- Production-ready with safety mechanisms
