# VPS Diagnostic and Monitoring Scripts

**Author:** Hive Mind Coder Agent
**Version:** 1.0.0
**Purpose:** Comprehensive VPS infrastructure monitoring and diagnostics

## 📋 Overview

This collection of bash scripts provides comprehensive monitoring and diagnostic capabilities for VPS infrastructure, with special focus on detecting resource usage patterns during peak hours (9-10am).

## 🛠️ Scripts Included

### 1. `check-cron-jobs.sh`
**Purpose:** Analyze cron jobs and detect jobs running during specified time windows

**Features:**
- Scans user and system crontabs
- Identifies jobs scheduled during morning peak (9-10am)
- Analyzes cron daemon status
- Reviews recent cron activity from logs

**Usage:**
```bash
sudo ./check-cron-jobs.sh
```

**Cron Schedule:**
```bash
# Run daily at 10am to review morning jobs
0 10 * * * /path/to/scripts/diagnostics/check-cron-jobs.sh
```

---

### 2. `detect-mysql-backups.sh`
**Purpose:** Detect and analyze MySQL backup jobs, timing, and resource usage

**Features:**
- Detects active mysqldump processes
- Locates backup scripts and configurations
- Analyzes backup schedules
- Estimates resource impact
- Alerts if backups run during peak hours

**Usage:**
```bash
sudo ./detect-mysql-backups.sh
```

**Cron Schedule:**
```bash
# Run at 9:30am to catch morning backups
30 9 * * * /path/to/scripts/diagnostics/detect-mysql-backups.sh
```

---

### 3. `monitor-php-fpm.sh`
**Purpose:** Monitor PHP-FPM processes, pools, and resource usage

**Features:**
- Real-time PHP-FPM process monitoring
- Pool configuration analysis
- Resource usage tracking (CPU, Memory)
- Slow request detection
- Error log analysis
- 1-minute sampling (12 samples @ 5s interval)

**Usage:**
```bash
sudo ./monitor-php-fpm.sh
```

**Cron Schedule:**
```bash
# Monitor PHP-FPM at 9am daily
0 9 * * * /path/to/scripts/diagnostics/monitor-php-fpm.sh
```

---

### 4. `analyze-nginx-connections.sh`
**Purpose:** Monitor nginx connections, requests, and performance metrics

**Features:**
- Active connection monitoring
- Access log analysis
- Error log review
- Real-time connection tracking
- Top URLs and client IPs
- HTTP status code distribution

**Usage:**
```bash
sudo ./analyze-nginx-connections.sh
```

**Cron Schedule:**
```bash
# Monitor every 5 minutes during peak hours
*/5 9-10 * * * /path/to/scripts/diagnostics/analyze-nginx-connections.sh
```

---

### 5. `log-resource-usage.sh`
**Purpose:** Log comprehensive system resource usage over time

**Features:**
- CPU, Memory, Disk I/O, Network monitoring
- CSV output for data analysis
- Configurable sampling (default: 1 hour)
- Alert thresholds for critical resources
- Statistical summary generation
- Peak value tracking

**Usage:**
```bash
sudo ./log-resource-usage.sh
```

**Custom Duration:**
```bash
# 30 minutes @ 5s interval
SAMPLE_COUNT=360 SAMPLE_INTERVAL=5 ./log-resource-usage.sh
```

**Cron Schedule:**
```bash
# Log resources starting at 9am for 1 hour
0 9 * * * /path/to/scripts/diagnostics/log-resource-usage.sh
```

---

### 6. `morning-monitor.sh` (Unified Monitor)
**Purpose:** Comprehensive monitoring during 9-10am peak period

**Features:**
- Orchestrates all diagnostic scripts
- System snapshot capture
- Service health checks
- 10-minute resource monitoring
- Automated analysis and reporting
- Executive summary generation

**Usage:**
```bash
sudo ./morning-monitor.sh
```

**Cron Schedule:**
```bash
# Run complete monitoring suite at 9am daily
0 9 * * * /path/to/scripts/diagnostics/morning-monitor.sh

# With email notification
0 9 * * * /path/to/scripts/diagnostics/morning-monitor.sh && \
  mail -s "Morning Monitor Report" admin@example.com < \
  /var/log/diagnostics/morning-monitor-report-*.txt
```

---

## 📁 Installation

### 1. Copy Scripts to Server
```bash
# Create diagnostics directory
mkdir -p /opt/scripts/diagnostics

# Copy all scripts
cp scripts/diagnostics/*.sh /opt/scripts/diagnostics/

# Make executable
chmod +x /opt/scripts/diagnostics/*.sh
```

### 2. Create Log Directory
```bash
sudo mkdir -p /var/log/diagnostics
sudo chmod 755 /var/log/diagnostics
```

### 3. Install Dependencies
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y sysstat procps coreutils bc

# CentOS/RHEL
sudo yum install -y sysstat procps-ng coreutils bc
```

---

## 🔧 Configuration

### Alert Thresholds

Edit the scripts to customize alert thresholds:

**CPU Threshold:**
```bash
readonly ALERT_CPU_THRESHOLD=80.0
```

**Memory Threshold:**
```bash
readonly ALERT_MEMORY_THRESHOLD=85
```

**Disk Threshold:**
```bash
readonly ALERT_DISK_THRESHOLD=90
```

### Sampling Configuration

**Resource Logger:**
```bash
readonly SAMPLE_INTERVAL=10  # seconds
readonly SAMPLE_COUNT=360    # 360 samples = 1 hour
```

**PHP-FPM Monitor:**
```bash
readonly SAMPLE_INTERVAL=5   # seconds
readonly SAMPLE_COUNT=12     # 12 samples = 1 minute
```

---

## 📊 Output Files

All scripts log to `/var/log/diagnostics/`:

```
/var/log/diagnostics/
├── cron-analysis-YYYYMMDD_HHMMSS.log
├── mysql-backup-analysis-YYYYMMDD_HHMMSS.log
├── php-fpm-monitor-YYYYMMDD_HHMMSS.log
├── nginx-connections-YYYYMMDD_HHMMSS.log
├── resource-usage-YYYYMMDD_HHMMSS.log
├── resource-usage-YYYYMMDD_HHMMSS.csv
├── morning-monitor-YYYYMMDD_HHMMSS.log
└── morning-monitor-report-YYYYMMDD_HHMMSS.txt
```

---

## 🚀 Quick Start Guide

### Daily Morning Monitoring

**Option 1: Unified Monitor (Recommended)**
```bash
# Run complete diagnostic suite at 9am
0 9 * * * /opt/scripts/diagnostics/morning-monitor.sh
```

**Option 2: Individual Scripts**
```bash
# Cron jobs check at 9am
0 9 * * * /opt/scripts/diagnostics/check-cron-jobs.sh

# MySQL backup detection at 9:15am
15 9 * * * /opt/scripts/diagnostics/detect-mysql-backups.sh

# PHP-FPM monitoring at 9:30am
30 9 * * * /opt/scripts/diagnostics/monitor-php-fpm.sh

# Nginx analysis every 5 minutes during peak
*/5 9-10 * * * /opt/scripts/diagnostics/analyze-nginx-connections.sh

# Resource logging starting at 9am
0 9 * * * /opt/scripts/diagnostics/log-resource-usage.sh
```

---

## 📈 Data Analysis

### Viewing CSV Data
```bash
# View in terminal
column -t -s, /var/log/diagnostics/resource-usage-*.csv | less

# Extract memory usage timeline
awk -F, '{print $1,$6}' resource-usage-*.csv

# Find peak CPU times
awk -F, '$2 > 80 {print $0}' resource-usage-*.csv

# Count critical alerts
grep "CRITICAL" resource-usage-*.csv | wc -l
```

### Graphing with gnuplot
```bash
gnuplot << EOF
set datafile separator ","
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%H:%M"
set xlabel "Time"
set ylabel "Usage %"
set title "CPU and Memory Usage"
plot "resource-usage-*.csv" using 1:2 with lines title "CPU", \
     "" using 1:6 with lines title "Memory"
EOF
```

---

## 🔍 Troubleshooting

### Script Permissions
```bash
# If scripts won't execute
chmod +x /opt/scripts/diagnostics/*.sh

# Check ownership
ls -la /opt/scripts/diagnostics/
```

### Missing Dependencies
```bash
# Test required commands
for cmd in vmstat iostat free df bc curl netstat ss; do
    command -v $cmd &>/dev/null && echo "✓ $cmd" || echo "✗ $cmd MISSING"
done
```

### Log Rotation
```bash
# Compress old logs
find /var/log/diagnostics -name "*.log" -mtime +7 -exec gzip {} \;

# Delete very old logs
find /var/log/diagnostics -name "*.gz" -mtime +30 -delete
```

---

## 🎯 Best Practices

### 1. Baseline Monitoring
Run scripts at different times to establish baselines:
```bash
# Low traffic (3am)
0 3 * * * /opt/scripts/diagnostics/log-resource-usage.sh

# Peak traffic (9am)
0 9 * * * /opt/scripts/diagnostics/log-resource-usage.sh

# Afternoon (2pm)
0 14 * * * /opt/scripts/diagnostics/log-resource-usage.sh
```

### 2. Alert Integration
Integrate with monitoring systems:
```bash
# Send alerts on critical issues
if grep -q "CRITICAL" /var/log/diagnostics/morning-monitor-*.log; then
    mail -s "CRITICAL: Morning Monitor Alert" admin@example.com < report.txt
fi
```

### 3. Regular Review
- Review logs weekly
- Compare month-over-month trends
- Adjust alert thresholds based on patterns
- Update backup schedules to avoid peak hours

---

## 📝 Recommendations

Based on diagnostic findings:

### Cron Jobs
- Schedule resource-intensive jobs during 2-4am
- Avoid scheduling between 9-10am
- Spread jobs throughout the day

### MySQL Backups
- **Optimal times:** 2-4am (lowest traffic)
- Use incremental backups for large databases
- Implement compression to reduce I/O
- Monitor backup duration

### PHP-FPM
- Review `pm.max_children` based on memory
- Set `pm.max_requests` to 500-1000
- Enable slow log for requests >5s
- Configure opcache appropriately

### Nginx
- Set `worker_processes` to CPU core count
- Configure `worker_connections` to 1024-4096
- Implement connection rate limiting
- Enable status module for monitoring

### Resource Monitoring
- Set up continuous monitoring (Prometheus/Grafana)
- Implement automated alerts
- Review trends monthly
- Plan capacity upgrades proactively

---

## 🤝 Integration with Hive Mind

These scripts integrate with the Hive Mind coordination system via hooks:

```bash
# Pre-task hook
npx claude-flow@alpha hooks pre-task --description "VPS diagnostics"

# Post-edit hook (after creating files)
npx claude-flow@alpha hooks post-edit --file "script.sh" --memory-key "hive/coder/scripts"

# Post-task hook
npx claude-flow@alpha hooks post-task --task-id "diagnostics"
```

---

## 📞 Support

For issues or enhancements:
1. Review script logs in `/var/log/diagnostics/`
2. Check script exit codes
3. Verify dependencies are installed
4. Ensure proper permissions

---

## 📄 License

These scripts are part of the AGL Host Management system.

---

## 🔄 Version History

**v1.0.0** - Initial release
- Complete diagnostic suite
- Morning peak monitoring
- CSV data export
- Automated reporting

---

**Last Updated:** 2025-10-22
**Maintained By:** Hive Mind Collective
