# Hive Mind Operations Manual
**Version**: 1.0.0
**Date**: 2026-02-10
**Status**: Active Production
**Maintainers**: AGL Infrastructure Team

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Getting Started](#getting-started)
3. [Daily Operations](#daily-operations)
4. [Monitoring](#monitoring)
5. [Maintenance](#maintenance)
6. [Troubleshooting](#troubleshooting)
7. [Security](#security)
8. [Backup & Recovery](#backup--recovery)
9. [Performance Optimization](#performance-optimization)
10. [Incident Response](#incident-response)
11. [Integration Guide](#integration-guide)
12. [References](#references)

---

## System Overview

### Architecture
The Hive Mind system is a distributed intelligence platform that coordinates multiple AI agents to perform complex infrastructure management tasks. It uses a master-worker pattern with strategic coordination.

```
┌─────────────────────────────────────────────────────────────┐
│                    Queen Node (Control Plane)                │
│                - Task Distribution & Coordination           │
│                - Consensus Management                       │
│                - Memory Management                          │
└─────────────────────────────────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    ▼                     ▼                     ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ Worker Pool │   │ Memory      │   │ Neural      │
│ (Agents)    │   │ Store       │   │ Recognizer  │
└─────────────┘   └─────────────┘   └─────────────┘
                          │
    ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Target Systems                             │
│           AGL Infrastructure (Proxmox, Containers, etc.)    │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Queen Node**: Central coordinator for task distribution and consensus
2. **Worker Agents**: Specialized AI agents for specific tasks
3. **Memory Store**: Persistent storage for shared knowledge
4. **Neural Recognizer**: Pattern recognition and learning system
5. **Monitoring Stack**: Prometheus + Grafana for metrics and visualization

---

## Getting Started

### Prerequisites

#### System Requirements
- **CPU**: 8+ cores (16 recommended for production)
- **Memory**: 32GB+ RAM (64GB recommended)
- **Storage**: 500GB+ SSD (NVMe preferred)
- **Network**: 1+ Gbps network interface
- **OS**: Ubuntu 20.04 LTS or CentOS 8+

#### Software Dependencies
```bash
# Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Docker & Docker Compose
sudo apt-get install -y docker.io docker-compose

# Required tools
sudo apt-get install -y git htop net-tools curl jq

# Node.js dependencies
npm install -g pm2 zeromq sqlite3
```

### Installation

#### 1. Clone Repository
```bash
git clone https://github.com/ruvnet/agl-hostman.git
cd agl-hostman
```

#### 2. Configure Environment
```bash
cp .env.example .env
nano .env
```

Example `.env` configuration:
```bash
# Queen Node Configuration
HIVE_MIND_HOST=0.0.0.0
HIVE_MIND_PORT=8080
HIVE_MIND_WORKERS=8
HIVE_MIND_MEMORY=4GB

# Database Configuration
DATABASE_URL=sqlite:///data/hive-mind.db

# Security Settings
ENCRYPTION_KEY=your-256-bit-secret-key
SSL_CERT_PATH=/etc/hive-mind/cert.pem
SSL_KEY_PATH=/etc/hive-mind/key.pem

# Monitoring Configuration
GRAFANA_URL=http://localhost:3000
PROMETHEUS_URL=http://localhost:9090
```

#### 3. Initialize System
```bash
# Install dependencies
npm install

# Create data directories
mkdir -p /data/hive-mind/{memory,logs,backups}

# Initialize database
npm run db:migrate

# Set up SSL certificates
./scripts/generate-cert.sh

# Start the system
npm run start
```

#### 4. Verify Installation
```bash
# Check system status
curl http://localhost:8080/api/health

# View dashboard
open http://localhost:3000/dash/hive-mind

# Check logs
tail -f /data/hive-mind/logs/queen.log
```

---

## Daily Operations

### Morning Checks (08:00)

#### System Health Check
```bash
#!/bin/bash
# /usr/local/bin/hive-mind-daily-check.sh

# Check Queen node
echo "=== Queen Node Status ==="
curl -s http://localhost:8080/api/health | jq .

# Check Worker agents
echo -e "\n=== Worker Agents ==="
curl -s http://localhost:8080/api/agents | jq '.[] | {id, type, status, tasks}'

# Check System Resources
echo -e "\n=== System Resources ==="
free -h
df -h | grep hive-mind
uptime

# Check Network
echo -e "\n=== Network Status ==="
ping -c 3 $(cat /etc/hive-mind/queen-ip)
```

#### Critical Tasks Review
```bash
# Check pending tasks with high priority
curl -s http://localhost:8080/api/tasks?priority=high | jq '.[] | {id, description, status}'

# Check failed tasks
curl -s http://localhost:8080/api/tasks?status=failed | jq '.[] | {id, error, retry_count}'

# Review system alerts
curl -s http://localhost:8080/api/alerts | jq '.[] | {severity, message, timestamp}'
```

### Routine Tasks

#### 1. Task Management
```bash
# Create new task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Analyze system logs for anomalies",
    "priority": "medium",
    "type": "analysis",
    "deadline": "2026-02-11T08:00:00Z"
  }'

# Monitor task progress
curl -s http://localhost:8080/api/tasks/123 | jq '.progress'

# Cancel task if needed
curl -X DELETE http://localhost:8080/api/tasks/123
```

#### 2. Agent Management
```bash
# Scale workers based on load
if [ $(curl -s http://localhost:8080/api/metrics | jq '.task_queue_length') -gt 50 ]; then
  ./scripts/hive-mind/scale-workers.sh --add=2
fi

# Restart unhealthy agents
curl -s http://localhost:8080/api/agents/health | \
  jq -r '.[] | select(.status != "healthy") | .id' | \
  xargs -I {} curl -X POST http://localhost:8080/api/agents/{}/restart
```

#### 3. Maintenance Operations
```bash
# Clean up old logs
find /data/hive-mind/logs -name "*.log" -mtime +7 -delete

# Rotate metrics data
curl -X POST http://localhost:8080/api/maintenance/rotate

# Update patterns (daily)
./scripts/hive-mind/update-patterns.sh
```

### Evening Shutdown (18:00)

#### Graceful Shutdown
```bash
#!/bin/bash
# /usr/local/bin/hive-mind-evening-shutdown.sh

# Pause new tasks
curl -X POST http://localhost:8080/api/system/pause

# Wait for active tasks to complete
wait_until_empty() {
  while [ $(curl -s http://localhost:8080/api/tasks?status=running | jq length) -gt 0 ]; do
    echo "Waiting for $(curl -s http://localhost:8080/api/tasks?status=running | jq length) tasks to complete..."
    sleep 30
  done
}

wait_until_empty

# Create checkpoint
./scripts/hive-mind/create-checkpoint.sh --output=/data/hive-mind/checkpoints/evening-$(date +%Y%m%d).json

# Stop workers gracefully
curl -X POST http://localhost:8080/api/workers/stop

# Stop Queen node
pm2 stop hive-mind-queen

# Backup memory store
./scripts/hive-mind/backup-memory.sh
```

---

## Monitoring

### Grafana Dashboards

#### Main Dashboard (Port 3000)
Access URL: `http://localhost:3000/dash/hive-mind`

**Key Metrics**:
- Task completion rate
- Worker health status
- Memory usage trends
- Network I/O patterns
- CPU utilization
- Alert status

#### Custom Dashboards
```yaml
# dashboard-config.yml
dashboards:
  - name: "Hive Mind Performance"
    url: "http://localhost:3000/api/dashboards/hive-mind"
    refresh: "30s"

  - name: "Agent Statistics"
    url: "http://localhost:3000/api/dashboards/agents"
    refresh: "15s"

  - name: "System Health"
    url: "http://localhost:3000/api/dashboards/health"
    refresh: "5s"
```

### Prometheus Metrics

#### Available Endpoints
```bash
# System metrics
curl http://localhost:9090/api/v1/label/__name__/values

# Query specific metrics
curl -g 'http://localhost:9090/api/v1/query?query=hive_mind_tasks_completed_total'

# Export all metrics
curl http://localhost:9090/metrics
```

#### Key Metric Definitions
```yaml
# metrics.yml
groups:
  - name: hive_mind
    interval: 15s
    metrics:
      - task_count:
          type: counter
          description: "Total tasks processed"
          labels: [status, type, priority]

      - agent_health:
          type: gauge
          description: "Agent health status (0-1)"
          labels: [agent_id, type]

      - memory_usage:
          type: gauge
          description: "Memory usage in bytes"
          labels: [component]

      - cpu_usage:
          type: gauge
          description: "CPU usage percentage"
          labels: [component]

      - task_duration:
          type: histogram
          description: "Task execution time"
          buckets: [10, 30, 60, 300, 600]
```

### Alerting Configuration

#### Alert Rules
```yaml
# alerts.yml
groups:
  - name: hive_mind_alerts
    rules:
      - alert: HighTaskFailureRate
        expr: rate(hive_mind_tasks_failed_total[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High task failure rate detected"
          description: "Failure rate: {{ $value }} tasks/min"

      - alert: WorkerUnhealthy
        expr: up{job="hive_mind_workers"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "All workers are down"
          description: "Check worker node health"

      - alert: MemoryPressure
        expr: rate(hive_mind_memory_usage_bytes[5m]) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage: {{ $value }}"
```

### Logging

#### Log Levels
```bash
# Log level configuration
export LOG_LEVEL=info  # debug, info, warn, error

# View real-time logs
tail -f /data/hive-mind/logs/queen.log | grep -E "(ERROR|WARN|CRITICAL)"

# Filter by component
tail -f /data/hive-mind/logs/queen.log | grep worker

# Follow specific agent
tail -f /data/hive-mind/logs/agent-1.log
```

#### Log Rotation
```bash
# Configure logrotate
cat > /etc/logrotate.d/hive-mind << EOF
/data/hive-mind/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        pm2 reload hive-mind-queen --update-env
    endscript
}
EOF
```

---

## Maintenance

### Weekly Maintenance Window

#### Schedule
- **Time**: Sunday 02:00-04:00 UTC
- **Duration**: 2 hours
- **Downtime**: Minimal (< 5 minutes)

#### Maintenance Checklist
```bash
#!/bin/bash
# /usr/local/bin/hive-mind-weekly-maintenance.sh

echo "Starting Hive Mind weekly maintenance..."

# 1. Create maintenance mode
curl -X POST http://localhost:8080/api/system/maintenance-mode

# 2. Backup current state
./scripts/hive-mind/weekly-backup.sh

# 3. Apply updates
npm update

# 4. Restart services
pm2 reload hive-mind-queen --update-env
./scripts/hive-mind/restart-workers.sh

# 5. Verify health
sleep 60
curl -s http://localhost:8080/api/health | jq .

# 6. Exit maintenance mode
curl -X DELETE http://localhost:8080/api/system/maintenance-mode

echo "Maintenance completed successfully."
```

### Monthly Deep Maintenance

#### Tasks
```bash
#!/bin/bash
# /usr/local/bin/hive-mind-monthly-maintenance.sh

# 1. System optimization
./scripts/hive-mind/optimize-system.sh

# 2. Database maintenance
sqlite3 /data/hive-mind/memory.db "VACUUM; ANALYZE;"

# 3. Pattern recognition training
./scripts/hive-mind/train-patterns.sh

# 4. Security audit
./scripts/hive-mind/security-audit.sh

# 5. Capacity planning
./scripts/hive-mind/capacity-plan.sh

# 6. Documentation update
./scripts/hive-mind/update-docs.sh
```

### Performance Tuning

#### Worker Optimization
```bash
# Optimize worker count based on load
CURRENT_LOAD=$(curl -s http://localhost:8080/api/metrics | jq '.task_queue_length')
MAX_WORKERS=16

if [ $CURRENT_LOAD -gt 100 ] && [ $WORKER_COUNT -lt $MAX_WORKERS ]; then
  NEW_WORKERS=$((WORKER_COUNT + 2))
  ./scripts/hive-mind/scale-workers.sh --count=$NEW_WORKERS
fi

# Monitor impact
./scripts/hive-mind/performance-test.sh --duration=300
```

#### Memory Optimization
```bash
# Enable memory compression
export HIVE_MIND_COMPRESSION=true

# Clear unused memory
curl -X POST http://localhost:8080/api/memory/cleanup

# Adjust cache size
if [ $(free -m | grep Mem | awk '{print $3/$2 * 100.0}') -gt 80 ]; then
  export HIVE_MIND_CACHE_SIZE=1GB
else
  export HIVE_MIND_CACHE_SIZE=2GB
fi
```

---

## Troubleshooting

### Common Issues

#### 1. Queen Node Unresponsive
```bash
#!/bin/bash
# /usr/local/bin/troubleshoot-queen.sh

echo "=== Queen Node Troubleshooting ==="

# Check process
if ! pgrep -f "hive-mind-queen" > /dev/null; then
  echo "ERROR: Queen process not found"
  pm2 list
  exit 1
fi

# Check port
if ! netstat -tuln | grep :8080 > /dev/null; then
  echo "ERROR: Port 8080 not listening"
  ss -tuln | grep 8080
  exit 1
fi

# Check resources
echo "Resource Usage:"
ps aux | grep hive-mind-queen | awk '{print "CPU: "$3"%", "MEM: "$4"%"}'
free -h | grep hive-mind

# Check logs
echo "Recent Errors:"
tail -n 100 /data/hive-mind/logs/queen.log | grep -E "(ERROR|CRITICAL|FATAL)"
```

#### 2. Worker Failures
```bash
#!/bin/bash
# /usr/local/bin/troubleshoot-workers.sh

echo "=== Worker Node Troubleshooting ==="

# Check worker status
curl -s http://localhost:8080/api/agents | jq '.[] | select(.status != "healthy")'

# Check worker resources
for worker_id in {1..8}; do
  echo "Worker $worker_id:"
  curl -s http://localhost:8080/api/agents/$worker_id/health | jq .
done

# Check worker logs
echo "Worker Error Logs:"
for log in /data/hive-mind/logs/worker*.log; do
  echo "--- $log ---"
  tail -n 20 $log | grep -E "(ERROR|CRITICAL)"
done
```

#### 3. Memory Issues
```bash
#!/bin/bash
# /usr/local/bin/troubleshoot-memory.sh

echo "=== Memory Troubleshooting ==="

# Check memory usage
echo "Memory Usage:"
du -sh /data/hive-mind/memory*
df -h /data/hive-mind

# Check database size
echo "Database Size:"
sqlite3 /data/hive-mind/memory.db "SELECT name, page_count*page_size/1024/1024 as size_mb FROM sqlite_master WHERE type='table';"

# Check memory leaks
echo "Memory Leak Detection:"
ps aux | grep hive-mind | awk '{print $11, $4, $11}'
```

### Debug Mode

#### Enable Debug Logging
```bash
# Set debug level
export LOG_LEVEL=debug
export DEBUG_MODE=true

# Restart with debug
pm2 reload hive-mind-queen --update-env

# Enable debug endpoints
curl -X POST http://localhost:8080/api/debug/enable

# Debug endpoints
curl http://localhost:8080/api/debug/memory
curl http://localhost:8080/api/debug/tasks
curl http://localhost:8080/api/debug/agents
```

#### Performance Analysis
```bash
#!/bin/bash
# /usr/local/bin/performance-analysis.sh

echo "=== Performance Analysis ==="

# System-wide stats
echo "System Stats:"
htop -p $(pgrep -f hive-mind)
iostat -x 1 5

# Task analysis
echo "Task Analysis:"
curl -s http://localhost:8080/api/metrics | jq '.task_durations'

# Network analysis
echo "Network Analysis:"
iftop -i eth0 -t
```

### Error Codes Reference

| Error Code | Description | Solution |
|------------|-------------|----------|
| HM_ERR_001 | Worker initialization failed | Check resources, restart workers |
| HM_ERR_002 | Consensus timeout | Increase timeout, check network |
| HM_ERR_003 | Memory exhausted | Clear cache, increase memory |
| HM_ERR_004 | Database connection failed | Check database service |
| HM_ERR_005 | SSL certificate error | Regenerate certificates |
| HM_ERR_006 | Rate limit exceeded | Increase rate limit |
| HM_ERR_007 | Task timeout | Increase timeout, optimize task |
| HM_ERR_008 | Agent unresponsive | Restart agent, check logs |
| HM_ERR_009 | Network partition | Check connectivity |
| HM_ERR_010 | Disk full | Clean up disk space |

---

## Security

### Access Control

#### User Authentication
```bash
# Create admin user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "secure-password",
    "role": "admin",
    "permissions": ["read", "write", "admin"]
  }'

# Create regular user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "operator",
    "password": "secure-password",
    "role": "operator",
    "permissions": ["read", "write"]
  }'
```

#### API Authentication
```bash
# Generate API key
curl -X POST http://localhost:8080/api/auth/api-key \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "description": "Monitoring script",
    "permissions": ["read"]
  }'

# Use API key in requests
curl -H "Authorization: Bearer your-api-key" \
  http://localhost:8080/api/health
```

### Network Security

#### Firewall Configuration
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8080/tcp   # Queen API
sudo ufw allow 3000/tcp   # Grafana
sudo ufw allow 9090/tcp   # Prometheus
sudo ufw deny 8080:8090/tcp  # Block other ports
sudo ufw enable
```

#### SSL/TLS Configuration
```bash
# Generate SSL certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Configure SSL
cat > /etc/hive-mind/ssl.conf << EOF
server {
    listen 443 ssl;
    server_name hive-mind.local;

    ssl_certificate /etc/hive-mind/cert.pem;
    ssl_certificate_key /etc/hive-mind/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
```

### Security Auditing

#### Regular Security Checks
```bash
#!/bin/bash
# /usr/local/bin/security-audit.sh

echo "=== Security Audit ==="

# Check user permissions
curl -s http://localhost:8080/api/users | jq '.[] | {username, role, permissions}'

# Check API key usage
curl -s http://localhost:8080/api/auth/api-keys | jq '.[] | {key, last_used, usage_count}'

# Check for suspicious activities
tail -n 1000 /data/hive-mind/logs/queen.log | grep -E "(FAILED|UNAUTHORIZED|SUSPICIOUS)"

# Check system vulnerabilities
npm audit
```

### Incident Response

#### Security Incident Procedure
```bash
#!/bin/bash
# /usr/local/incident-response.sh

# 1. Isolate system
echo "Isolating system..."
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
sudo iptables -A INPUT -p tcp --dport 3000 -j DROP

# 2. Preserve evidence
echo "Preserving evidence..."
mkdir -p /incident-evidence/$(date +%Y%m%d-%H%M%S)
cp /data/hive-mind/logs/* /incident-evidence/$(date +%Y%m%d-%H%M%S)/
cp /data/hive-mind/memory.db /incident-evidence/$(date +%Y%m%d-%H%M%S)/

# 3. Notify team
echo "Security incident detected. Notifying team..."
mail -s "Hive Mind Security Incident" security-team@aglz.io < /incident-details.txt

# 4. Create incident ticket
curl -X POST https://jira.aglz.io/api/issues \
  -H "Content-Type: application/json" \
  -d '{
    "project": "HMSEC",
    "summary": "Security Incident - $(date)",
    "description": "Details...",
    "priority": "Critical"
  }'
```

---

## Backup & Recovery

### Backup Strategy

#### Backup Schedule
```bash
# Create backup schedule
cat > /etc/cron.d/hive-mind-backups << EOF
# Daily backup at 02:00
0 2 * * * /usr/local/bin/hive-mind-daily-backup.sh

# Weekly backup at 02:00 on Sunday
0 2 * * 0 /usr/local/bin/hive-mind-weekly-backup.sh

# Monthly backup at 02:00 on 1st
0 2 1 * * /usr/local/bin/hive-mind-monthly-backup.sh
EOF
```

#### Backup Scripts
```bash
#!/bin/bash
# /usr/local/bin/hive-mind-daily-backup.sh

BACKUP_DIR="/backups/hive-mind/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Create timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Backup configuration
cp /etc/hive-mind/* $BACKUP_DIR/config-$TIMESTAMP/

# Backup memory database
cp /data/hive-mind/memory.db $BACKUP_DIR/memory-$TIMESTAMP.db

# Backup logs (last 24 hours)
find /data/hive-mind/logs -name "*.log" -mtime -1 -exec cp {} $BACKUP_DIR/ \;

# Backup state
curl -s http://localhost:8080/api/system/state > $BACKUP_DIR/state-$TIMESTAMP.json

# Verify backup
if [ $? -eq 0 ]; then
  echo "Backup completed successfully: $BACKUP_DIR"
  # Cleanup old backups (keep 30 days)
  find /backups/hive-mind -name "*" -mtime +30 -delete
else
  echo "Backup failed!"
  exit 1
fi
```

### Recovery Procedures

#### System Recovery
```bash
#!/bin/bash
# /usr/local/bin/recover-system.sh

BACKUP_DATE=$1
BACKUP_DIR="/backups/hive-mind/$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# Stop services
pm2 stop hive-mind-queen

# Restore configuration
cp -r $BACKUP_DIR/config-*/* /etc/hive-mind/

# Restore database
cp $BACKUP_DIR/memory-*.db /data/hive-mind/memory.db

# Restore logs
cp $BACKUP_DIR/*.log /data/hive-mind/logs/

# Start services
pm2 start hive-mind-queen

# Verify recovery
sleep 30
curl -s http://localhost:8080/api/health | jq .
```

#### Disaster Recovery
```bash
#!/bin/bash
# /usr/local/bin/disaster-recovery.sh

# 1. Assess damage
echo "=== Damage Assessment ==="
ls -la /data/hive-mind/
cat /var/log/syslog | grep -E "(ERROR|CRITICAL)"

# 2. Restore from latest backup
echo "=== Restoring from Backup ==="
BACKUP_LATEST=$(ls -t /backups/hive-mind/ | head -1)
./recover-system.sh $BACKUP_LATEST

# 3. Validate system
echo "=== System Validation ==="
curl -s http://localhost:8080/api/health | jq '.status == "healthy"'
curl -s http://localhost:8080/api/agents | jq '.length > 0'

# 4. Resume operations
echo "=== Resuming Operations ==="
curl -X POST http://localhost:8080/api/system/resume
```

### Backup Testing

#### Monthly Backup Test
```bash
#!/bin/bash
# /usr/local/test-backup.sh

echo "=== Testing Backup Integrity ==="

# Create test backup
BACKUP_DIR="/tmp/test-backup-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup test data
sqlite3 /data/hive-mind/memory.db ".backup $BACKUP_DIR/test-memory.db"

# Verify backup
if sqlite3 $BACKUP_DIR/test-memory.db "SELECT COUNT(*) FROM tasks;" > /dev/null; then
  echo "✓ Backup verification passed"

  # Test restore
  cp /data/hive-mind/memory.db /data/hive-mind/memory.db.backup
  cp $BACKUP_DIR/test-memory.db /data/hive-mind/memory.db

  # Verify data integrity
  if [ $(sqlite3 /data/hive-mind/memory.db "SELECT COUNT(*) FROM tasks;") -gt 0 ]; then
    echo "✓ Restore test passed"
  else
    echo "✗ Restore test failed"
    cp /data/hive-mind/memory.db.backup /data/hive-mind/memory.db
  fi

  # Cleanup
  rm -rf $BACKUP_DIR
  rm /data/hive-mind/memory.db.backup
else
  echo "✗ Backup verification failed"
fi
```

---

## Performance Optimization

### Performance Monitoring

#### Baseline Metrics
```bash
#!/bin/bash
# /usr/local/performance-baseline.sh

echo "=== Performance Baseline ==="

# System baseline
echo "System Resources:"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h /data | tail -1 | awk '{print $4} available')"

# Application baseline
echo "Hive Mind Performance:"
echo "Tasks completed: $(curl -s http://localhost:8080/api/metrics | jq '.tasks_completed')"
echo "Average task time: $(curl -s http://localhost:8080/api/metrics | jq '.avg_task_time')"
echo "Worker efficiency: $(curl -s http://localhost:8080/api/metrics | jq '.worker_efficiency')"
```

#### Optimization Scripts

##### Worker Scaling
```bash
#!/bin/bash
# /usr/local/optimize-workers.sh

# Get current metrics
TASK_QUEUE=$(curl -s http://localhost:8080/api/metrics | jq '.task_queue_length')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# Scale workers based on queue length
if [ $TASK_QUEUE -gt 100 ]; then
  NEW_WORKERS=$(($WORKER_COUNT + 2))
  ./scripts/hive-mind/scale-workers.sh --count=$NEW_WORKERS
  echo "Scaled up to $NEW_WORKERS workers"
elif [ $TASK_QUEUE -lt 10 ] && [ $WORKER_COUNT -gt 4 ]; then
  NEW_WORKERS=$(($WORKER_COUNT - 1))
  ./scripts/hive-mind/scale-workers.sh --count=$NEW_WORKERS
  echo "Scaled down to $NEW_WORKERS workers"
fi

# Monitor impact
sleep 60
echo "New performance metrics:"
curl -s http://localhost:8080/api/metrics | jq '.task_completion_rate, .cpu_usage, .memory_usage'
```

##### Memory Optimization
```bash
#!/bin/bash
# /usr/local/optimize-memory.sh

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')

if [ $(echo "$MEMORY_USAGE > 80" | bc -l) -eq 1 ]; then
  echo "High memory usage detected: $MEMORY_USAGE%"

  # Clear cache
  curl -X POST http://localhost:8080/api/memory/cache/clear

  # Enable compression
  export HIVE_MIND_COMPRESSION=true
  pm2 reload hive-mind-queen --update-env

  # Adjust cache size
  if [ $(echo "$MEMORY_USAGE > 90" | bc -l) -eq 1 ]; then
    export HIVE_MIND_CACHE_SIZE=512MB
  else
    export HIVE_MIND_CACHE_SIZE=1GB
  fi

  echo "Memory optimization applied"
else
  echo "Memory usage normal: $MEMORY_USAGE%"
fi
```

### Load Testing

#### Automated Load Test
```bash
#!/bin/bash
# /usr/local/load-test.sh

CONCURRENT_USERS=${1:-10}
DURATION=${2:-300}

echo "Starting load test with $CONCURRENT_USERS users for $DURATION seconds..."

# Generate load
for i in $(seq 1 $CONCURRENT_USERS); do
  {
    for j in $(seq 1 100); do
      curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/tasks &
      sleep 0.1
    done
  } &
done

# Monitor performance
while [ $DURATION -gt 0 ]; do
  echo "Time remaining: $DURATION seconds"
  echo "Current metrics:"
  curl -s http://localhost:8080/api/metrics | jq '.tasks_completed, .response_time, .error_rate'
  sleep 10
  DURATION=$((DURATION - 10))
done

# Kill background processes
pkill curl
echo "Load test completed"
```

#### Performance Analysis
```bash
#!/bin/bash
# /usr/local/performance-analysis.sh

echo "=== Performance Analysis ==="

# Collect performance data
./performance-baseline.sh > /tmp/perf-baseline.txt

# Generate load
./load-test.sh 5 60 > /tmp/perf-results.txt

# Analyze results
echo "Performance Summary:"
echo "Throughput: $(grep 'tasks_completed' /tmp/perf-results.txt | awk '{sum+=$2} END {print sum}') tasks/min"
echo "Average Response Time: $(grep 'response_time' /tmp/perf-results.txt | awk '{sum+=$2} END {print sum/NR}') ms"
echo "Error Rate: $(grep 'error_rate' /tmp/perf-results.txt | awk '{sum+=$2} END {print sum/NR}')%"

# Cleanup
rm /tmp/perf-baseline.txt /tmp/perf-results.txt
```

---

## Incident Response

### Incident Classification

#### Incident Levels
```yaml
Critical:
  - System completely down
  - Data corruption
  - Security breach
  - Extended downtime (> 4 hours)

High:
  - Partial system failure
  - Performance degradation > 50%
  - Data loss risk
  - Downtime 1-4 hours

Medium:
  - Reduced functionality
  - Performance degradation 25-50%
  - Minor data issues
  - Downtime < 1 hour

Low:
  - Degraded performance
  - Minor UI issues
  - Non-critical errors
  - Self-healing
```

### Incident Response Workflow

#### 1. Detection
```bash
#!/bin/bash
# /usr/local/incident-detection.sh

# Check critical systems
CRITICAL_CHECKS=(
  "http://localhost:8080/api/health"
  "http://localhost:3000/api/health"
  "http://localhost:9090/api/v1/status"
)

for check in "${CRITICAL_CHECKS[@]}"; do
  if ! curl -s $check > /dev/null; then
    echo "CRITICAL: $check failed"
    send_incident_alert "CRITICAL_SYSTEM_FAILURE" "$check"
  fi
done

# Check performance thresholds
METRICS=$(curl -s http://localhost:8080/api/metrics)
ERROR_RATE=$(echo $METRICS | jq '.error_rate')
RESPONSE_TIME=$(echo $METRICS | jq '.response_time')

if [ $(echo "$ERROR_RATE > 0.1" | bc -l) -eq 1 ]; then
  send_incident_alert "HIGH_ERROR_RATE" "Error rate: $ERROR_RATE"
fi

if [ $(echo "$RESPONSE_TIME > 1000" | bc -l) -eq 1 ]; then
  send_incident_alert "HIGH_RESPONSE_TIME" "Response time: $RESPONSE_TIME ms"
fi
```

#### 2. Initial Response
```bash
#!/bin/bash
# /usr/local/incident-response-initial.sh

INCIDENT_ID=$1
INCIDENT_TYPE=$2

# Create incident ticket
curl -X POST https://jira.aglz.io/api/issues \
  -H "Content-Type: application/json" \
  -d "{
    \"project\": \"HM\",
    \"summary\": \"$INCIDENT_TYPE - $(date)\",
    \"description\": \"Incident details...\",
    \"priority\": \"High\"
  }"

# Notify team
send_slack_alert "#incidents" "🚨 Incident detected: $INCIDENT_TYPE (ID: $INCIDENT_ID)"

# Isolate if security incident
if [ "$INCIDENT_TYPE" = "SECURITY_BREACH" ]; then
  ./security-isolate.sh
fi

# Preserve evidence
mkdir -p /incident-evidence/$INCIDENT_ID
cp /data/hive-mind/logs/* /incident-evidence/$INCIDENT_ID/
```

#### 3. Containment
```bash
#!/bin/bin/local/incident-containment.sh

# Pause new tasks
curl -X POST http://localhost:8080/api/system/pause

# Scale down workers
curl -X POST http://localhost:8080/api/workers/scale --data '{"count": 2}'

# Enable maintenance mode
curl -X POST http://localhost:8080/api/system/maintenance-mode

# Check affected systems
echo "Checking affected systems:"
for system in $(curl -s http://localhost:8080/api/systems | jq -r '.[] | .name'); do
  status=$(curl -s "http://localhost:8080/api/systems/$system/status" | jq -r '.status')
  echo "System $system: $status"
done
```

#### 4. Recovery
```bash
#!/usr/local/bin/incident-recovery.sh

# Attempt recovery based on incident type
case $1 in
  "MEMORY_LEAK")
    echo "Recovering from memory leak..."
    curl -X POST http://localhost:8080/api/memory/restart
    ;;
  "WORKER_FAILURE")
    echo "Recovering from worker failure..."
    curl -X POST http://localhost:8080/api/workers/restart
    ;;
  "DATABASE_ERROR")
    echo "Recovering from database error..."
    ./recover-database.sh
    ;;
  *)
    echo "General recovery procedure..."
    ./restart-all.sh
    ;;
esac

# Verify recovery
sleep 30
if curl -s http://localhost:8080/api/health | jq '.status == "healthy"'; then
  echo "✓ Recovery successful"
  send_slack_alert "#incidents" "✅ Recovery completed for incident $1"
else
  echo "✗ Recovery failed - escalation required"
  send_slack_alert "#incidents" "🚨 Recovery failed for incident $1 - escalation required"
fi
```

#### 5. Post-Incident Review
```bash
#!/usr/local/bin/incident-review.sh

INCIDENT_ID=$1

# Generate incident report
cat > /incident-reports/$INCIDENT_ID-$(date +%Y%m%d).md << EOF
# Incident Review Report
**Incident ID**: $INCIDENT_ID
**Date**: $(date)
**Duration**: $2 minutes
**Impact**: $3

## Summary
$4

## Root Cause
$5

## Resolution
$6

## Follow-up Actions
$7

## Prevention
$8

EOF

# Schedule follow-up meeting
curl -X POST https://calendar.aglz.io/api/events \
  -H "Content-Type: application/json" \
  -d "{
    \"summary\": \"Post-incident review for $INCIDENT_ID\",
    \"start\": \"$(date -d '+3 days' -Iseconds)\",
    \"attendees\": [\"team@aglz.io\"]
  }"
```

### Communication Plan

#### Alert Escalation
```yaml
alert_levels:
  - name: "Info"
    severity: 1
    channels: ["slack-info"]
    response_time: "24h"

  - name: "Warning"
    severity: 2
    channels: ["slack-warning", "email-team"]
    response_time: "4h"

  - name: "Critical"
    severity: 3
    channels: ["slack-critical", "email-team", "sms"]
    response_time: "30min"

  - name: "Emergency"
    severity: 4
    channels: ["slack-critical", "email-team", "sms", "phone"]
    response_time: "5min"
```

#### Notification Templates
```bash
#!/usr/local/bin/send-notification.sh

LEVEL=$1
MESSAGE=$2
CHANNEL=$3

case $LEVEL in
  "INFO")
    icon="ℹ️"
    color="#36a64f"
    ;;
  "WARNING")
    icon="⚠️"
    color="#ff9500"
    ;;
  "CRITICAL")
    icon="🚨"
    color="#ff0000"
    ;;
  "EMERGENCY")
    icon="🔥"
    color="#8b0000"
    ;;
esac

payload=$(jq -n --arg msg "$MESSAGE" --arg icon "$icon" --arg color "$color" '{
  text: $icon + " " + $msg,
  attachments: [{
    color: $color,
    fields: [
      {title: "Host", value: "`hostname`", short: true},
      {title: "Time", value: "`date`", short: true}
    ]
  }]
})

case $CHANNEL in
  "slack")
    curl -X POST https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
      -H "Content-Type: application/json" \
      -d "$payload"
    ;;
  "email")
    echo "$MESSAGE" | mail -s "Hive Mind Alert: $LEVEL" team@aglz.io
    ;;
  "sms")
    curl "https://api.twilio.com/2010-04-01/Accounts/YOUR/Messages.json" \
      -u "YOUR:YOUR" \
      -d "From=+1234567890" \
      -d "To=+0987654321" \
      -d "Body=$MESSAGE"
    ;;
esac
```

---

## Integration Guide

### External System Integration

#### API Integration
```javascript
// Example: Integrate with external monitoring system
class ExternalIntegration {
  constructor(config) {
    this.webhookUrl = config.webhookUrl;
    this.apiKey = config.apiKey;
  }

  async sendAlert(message, severity = 'info') {
    const payload = {
      timestamp: new Date().toISOString(),
      source: 'hive-mind',
      severity,
      message,
      system: 'agl-hostman'
    };

    await fetch(this.webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify(payload)
    });
  }
}

// Usage
const integration = new ExternalIntegration({
  webhookUrl: 'https://monitoring.aglz.io/api/alerts',
  apiKey: 'your-api-key'
});

// Send alert when task fails
integration.sendAlert('Task 123 failed', 'critical');
```

#### Database Integration
```python
# Example: Connect to external database for analytics
import sqlite3
import psycopg2
from datetime import datetime

class DatabaseIntegration:
    def __init__(self, config):
        self.hive_mind_db = config['hive_mind_db']
        self.external_db = config['external_db']

    def sync_tasks(self):
        # Get tasks from Hive Mind
        hm_conn = sqlite3.connect(self.hive_mind_db)
        hm_cursor = hm_conn.cursor()

        hm_cursor.execute("SELECT * FROM tasks WHERE synced = 0")
        tasks = hm_cursor.fetchall()

        # Sync to external database
        ext_conn = psycopg2.connect(self.external_db)
        ext_cursor = ext_conn.cursor()

        for task in tasks:
            ext_cursor.execute("""
                INSERT INTO analytics.tasks
                (id, description, status, created_at)
                VALUES (%s, %s, %s, %s)
            """, (task[0], task[1], task[2], datetime.now()))

        # Mark as synced
        hm_cursor.execute("UPDATE tasks SET synced = 1 WHERE id IN ({})".format(
            ','.join(str(t[0]) for t in tasks)
        ))

        hm_conn.commit()
        ext_conn.commit()
        hm_conn.close()
        ext_conn.close()
```

### Cloud Integration

#### AWS Integration
```javascript
// Example: AWS CloudWatch integration
const AWS = require('aws-sdk');

class AWSIntegration {
  constructor(config) {
    this.cloudwatch = new AWS.CloudWatch({
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      region: config.region
    });
  }

  async putMetric(metricData) {
    await this.cloudwatch.putMetricData({
      Namespace: 'HiveMind',
      MetricData: [metricData]
    }).promise();
  }

  async putTaskMetrics() {
    const metrics = await this.getTaskMetrics();

    for (const metric of metrics) {
      await this.putMetric({
        MetricName: metric.name,
        Value: metric.value,
        Unit: metric.unit,
        Timestamp: new Date(),
        Dimensions: [
          { Name: 'Component', Value: 'Queen' },
          { Name: 'Environment', Value: 'production' }
        ]
      });
    }
  }
}
```

#### Kubernetes Integration
```yaml
# Example: Kubernetes deployment manifest
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hive-mind-worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hive-mind-worker
  template:
    metadata:
      labels:
        app: hive-mind-worker
    spec:
      containers:
      - name: worker
        image: agl-hostman/hive-mind-worker:latest
        env:
        - name: HIVE_MIND_QUEUE_URL
          value: "amqp://rabbitmq:5672"
        - name: WORKER_COUNT
          value: "3"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      livenessProbe:
        httpGet:
          path: /health
          port: 8081
        initialDelaySeconds: 30
        periodSeconds: 10
```

### CI/CD Integration

#### GitHub Actions
```yaml
# .github/workflows/hive-mind.yml
name: Hive Mind CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '20'

    - name: Install dependencies
      run: npm ci

    - name: Run tests
      run: npm test

    - name: Run integration tests
      run: npm run test:integration

    - name: Performance test
      run: npm run test:performance

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v2

    - name: Deploy to staging
      run: |
        ssh staging-server "cd /opt/hive-mind && git pull"
        ssh staging-server "npm run deploy:staging"

    - name: Run smoke tests
      run: npm run test:smoke

    - name: Deploy to production
      run: |
        ssh production-server "cd /opt/hive-mind && git pull"
        ssh production-server "npm run deploy:production"
```

#### Jenkins Pipeline
```groovy
pipeline {
  agent any

  environment {
    HIVE_MIND_CONFIG = credentials('hive-mind-config')
    DEPLOY_KEY = credentials('deploy-key')
  }

  stages {
    stage('Build') {
      steps {
        sh 'npm ci'
        sh 'npm run build'
      }
    }

    stage('Test') {
      parallel {
        stage('Unit Tests') {
          steps {
            sh 'npm test'
          }
        }
        stage('Integration Tests') {
          steps {
            sh 'npm run test:integration'
          }
        }
      }
    }

    stage('Security Scan') {
      steps {
        sh 'npm audit'
        sh 'npm run security:scan'
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          scp -i $DEPLOY_KEY -o StrictHostKeyChecking=no \
            dist/* user@staging:/opt/hive-mind/
          ssh -i $DEPLOY_KEY user@staging "cd /opt/hive-mind && npm run deploy:staging"
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '**/test-results/**', fingerprint: true
      junit '**/test-results/**/*.xml'
    }

    success {
      slackSend message: "Hive Mind deployment successful: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
    }

    failure {
      slackSend message: "Hive Mind deployment failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
    }
  }
}
```

---

## References

### Documentation
- [Hive Mind Implementation Summary](./hive-mind-implementation-summary.md)
- [Architecture Decisions](./architecture-decisions.md)
- [Training Materials](./training-materials.md)

### Configuration Files
- Queen node configuration: `/etc/hive-mind/queen.conf`
- Worker configuration: `/etc/hive-mind/workers.conf`
- SSL configuration: `/etc/hive-mind/ssl.conf`
- Monitoring configuration: `/etc/hive-mind/monitoring.conf`

### Scripts and Tools
- Daily check script: `/usr/local/bin/hive-mind-daily-check.sh`
- Backup script: `/usr/local/bin/hive-mind-backup.sh`
- Incident response: `/usr/local/bin/incident-response.sh`
- Performance analysis: `/usr/local/bin/performance-analysis.sh`

### API Documentation
- Queen API: `http://localhost:8080/api/docs`
- Worker API: `http://localhost:8081/api/docs`
- Monitoring API: `http://localhost:3000/api/docs`

### Support Contacts
- Primary: hive-mind-support@aglz.io
- Emergency: +1 (555) 123-4567
- Documentation: docs@aglz.io
- Community: community@aglz.io

### Additional Resources
- Wiki: https://wiki.aglz.io/hive-mind
- Troubleshooting Guide: https://support.aglz.io/hive-mind
- API Reference: https://api-docs.aglz.io/hive-mind
- Community Forum: https://forum.aglz.io

---

**Document Information**:
- **Created**: 2025-02-10
- **Version**: 1.0.0
- **Status**: Active Production
- **Next Review**: 2025-03-10
- **Maintainer**: AGL Infrastructure Team

*End of Operations Manual*