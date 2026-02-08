---
name: infrastructure-diagnostics
description: "Comprehensive infrastructure health checks, troubleshooting procedures, and root cause analysis for Proxmox, Docker, networks, and services. Use when debugging issues, performing health checks, or investigating incidents."
category: infrastructure
priority: P0
tags: [diagnostics, troubleshooting, health-check, debugging]
---

# Infrastructure Diagnostics

## Overview

The infrastructure diagnostics skill provides systematic health checks, troubleshooting procedures, and root cause analysis for the entire AGL infrastructure stack. This skill follows a structured approach to identify, isolate, and resolve issues across Proxmox nodes, Docker containers, networks, and application services.

### Diagnostic Methodology

1. **Gather Context** - Understand symptoms, scope, and impact
2. **Verify Health** - Run systematic health checks
3. **Isolate Issue** - Narrow down to specific component
4. **Identify Root Cause** - Use analysis techniques
5. **Implement Fix** - Apply minimal, targeted fix
6. **Verify Resolution** - Confirm issue is resolved
7. **Document Learning** - Update knowledge base

### When to Use This Skill

- Application is slow or unresponsive
- Container or VM failures
- Network connectivity issues
- Queue jobs failing or stuck
- Resource exhaustion (CPU, memory, disk)
- Service not starting
- Unexpected error messages
- Performance degradation

---

## Health Check Framework

### Systematic Health Checks

The health check framework follows a layered approach, starting from the physical layer up to the application layer.

### Check Levels

```yaml
health_levels:
  L1_critical:
    - System reachable (ping/SSH)
    - Basic services running
    - No resource exhaustion
  L2_infrastructure:
    - Proxmox cluster healthy
    - Docker daemon running
    - Network connectivity
    - Storage accessible
  L3_services:
    - Containers healthy
    - Queue workers processing
    - Database accessible
    - Cache reachable
  L4_application:
    - API responding
    - Web interface accessible
    - Background jobs running
    - Metrics collecting
```

### Quick Health Check Command

```bash
# Run full diagnostic scan
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-full-scan.sh

# Run specific diagnostic
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-proxmox.sh
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-docker.sh
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-network.sh
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-queues.sh
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-performance.sh
```

---

## Proxmox Diagnostics

### Node Health

#### Check Node Status

```bash
# Get cluster status
pvesh get /cluster/status

# Check specific node
pvesh get /nodes/{node}/status

# Get node resource usage
pvesh get /nodes/{node}/status/current
```

#### Critical Metrics

| Metric | Warning | Critical | Check |
|--------|---------|----------|-------|
| CPU | 70% | 85% | `pvesh get /nodes/{node}/status/current` |
| Memory | 80% | 90% | `pvesh get /nodes/{node}/status/current` |
| Disk | 80% | 90% | `pvesh get /nodes/{node}/status/current` |
| Load | 1.0 | 2.0 | `pvesh get /nodes/{node}/status/current` |

### VM and Container Health

#### List All VMs/Containers

```bash
# List VMs
pvesh get /nodes/{node}/qemu --output-format yaml

# List Containers
pvesh get /nodes/{node}/lxc --output-format yaml

# Get specific VM status
pvesh get /nodes/{node}/qemu/{vmid}/status/current
```

#### Check VM Health

```bash
# Check if VM is running
STATUS=$(pvesh get /nodes/{node}/qemu/{vmid}/status/current --output-format json | jq -r '.status')
if [ "$STATUS" != "running" ]; then
  echo "VM {vmid} is not running (status: $STATUS)"
fi

# Check VM resource usage
pvesh get /nodes/{node}/qemu/{vmid}/status/current --output-format json | jq '.'
```

### Cluster Health

#### Check Quorum

```bash
# Check cluster quorum status
pvesh get /cluster/status | grep quorum
```

#### Check Node Connectivity

```bash
# Check corosync status
systemctl status pve-corosync

# Check cluster members
pvecm nodes
```

### Storage Health

#### Check Storage Status

```bash
# List all storage
pvesm status

# Check specific storage
pvesm status --storage {storage_name}

# Get storage content
pvesm list {storage_name}
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Node offline | Cannot connect, ping fails | Check network, power cycle hardware |
| No quorum | Cluster read-only | Check network, use pvecm expected 1 for single node |
| High CPU | Sluggish performance | Identify top VM, migrate or reduce resources |
| Storage full | Cannot create VMs/containers | Clean old backups, extend storage |
| Locked VM | Cannot start/stop | Clear lock with `qm unlock {vmid}` |

---

## Docker Diagnostics

### Container Health

#### List All Containers

```bash
# List all containers with status
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.State}}\t{{.Ports}}"

# Filter by status
docker ps -f "status=running"
docker ps -f "status=exited"
docker ps -f "status=created"
```

#### Check Container Resource Usage

```bash
# Live stats
docker stats --no-stream

# Stats for specific container
docker stats {container_name} --no-stream

# Detailed stats JSON
docker stats {container_name} --no-stream --format "{{ json . }}" | jq
```

#### Inspect Container

```bash
# Get detailed container info
docker inspect {container_name}

# Check container logs
docker logs {container_name} --tail 100 -f

# Check logs with timestamps
docker logs {container_name} --timestamps
```

### Container States

```yaml
states:
  created: Container created but not started
  running: Container is running
  paused: Container is paused
  restarting: Container is restarting (loop)
  exited: Container has exited
  removing: Container is being removed
  dead: Container is dead
```

### Image Issues

#### List Images

```bash
# List all images
docker images

# Find dangling images
docker images -f "dangling=true"

# Clean unused images
docker image prune -a
```

### Network Issues

#### Check Container Networks

```bash
# List networks
docker network ls

# Inspect network
docker network inspect {network_name}

# Check container network
docker inspect {container_name} | jq '.[0].NetworkSettings'
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Container won't start | Exited immediately | Check logs, verify config, check resources |
| High memory usage | OOM killed | Check limits, identify leak, restart |
| Cannot connect | Connection refused | Check ports, network mode, firewall |
| Stuck in restart loop | Keeps restarting | Check logs, fix config, remove auto-restart |
| DNS issues | Cannot resolve hosts | Check daemon.json, use --dns flag |

---

## Network Diagnostics

### Connectivity Checks

#### Basic Ping Tests

```bash
# Check local gateway
ping -c 3 $(ip route | grep default | awk '{print $3}')

# Check DNS
ping -c 3 8.8.8.8
ping -c 3 google.com

# Check Proxmox nodes
ping -c 3 {node1_ip}
ping -c 3 {node2_ip}
```

#### Port Connectivity

```bash
# Check if port is open
nc -zv {host} {port}

# Check HTTP/HTTPS
curl -I http://{host}:{port}
curl -I https://{host}:{port}

# Check multiple ports
for port in 22 80 443 8006; do
  nc -zv {host} $port
done
```

### DNS Diagnostics

#### Check DNS Resolution

```bash
# Check DNS server
cat /etc/resolv.conf

# Test resolution
nslookup {hostname}
dig {hostname}

# Check specific DNS server
dig @{dns_server} {hostname}
```

### VPN Diagnostics

#### WireGuard Status

```bash
# Check WireGuard interface
wg show

# Check specific interface
wg show wg0

# Check connection status
wg show wg0 peers
```

#### Tailscale Status

```bash
# Check Tailscale status
tailscale status

# Check peers
tailscale status --peers

# Check connectivity
tailscale ping {peer_name}
```

### Routing Issues

#### Check Routing Table

```bash
# Show routing table
ip route show

# Check default route
ip route | grep default

# Trace route to host
traceroute {host}
mtr {host}
```

### Firewall Diagnostics

```bash
# Check iptables rules
iptables -L -n -v

# Check UFW status
ufw status

# Check specific port
ufw status | grep {port}
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Cannot ping host | Request timeout | Check firewall, routing, host status |
| DNS fails | Unknown host | Check /etc/resolv.conf, try different DNS |
| Port blocked | Connection refused | Check firewall, verify service listening |
| VPN down | Cannot reach peers | Check key config, restart service |
| High latency | Slow responses | Check routing, network congestion |

---

## Service Diagnostics

### Laravel Horizon (Queue Workers)

#### Check Horizon Status

```bash
# Check Horizon service status
systemctl status horizon

# Check Horizon via Artisan
php artisan horizon:status

# Get queue stats
php artisan horizon:stats
```

#### Check Failed Jobs

```bash
# List failed jobs
php artisan queue:failed

# Get specific failed job details
php artisan queue:failed {job_id}

# Retry failed jobs
php artisan queue:retry all

# Retry specific job
php artisan queue:retry {job_id}
```

#### Check Pending Jobs

```bash
# Get queue size from Redis
redis-cli -n 1 llen queues:default

# Check all queues
redis-cli -n 1 keys "queues:*" | xargs -I {} redis-cli -n 1 llen {}

# Get job details
redis-cli -n 1 lrange queues:default 0 10
```

### Cron Jobs

#### Check Cron Status

```bash
# List cron jobs
crontab -l

# Check system cron
systemctl status cron

# View cron logs
grep CRON /var/log/syslog
```

### Database Health

#### Check MySQL

```bash
# Check MySQL service
systemctl status mysql

# Check MySQL connections
mysql -e "SHOW PROCESSLIST;"

# Check slow queries
mysql -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"

# Check table locks
mysql -e "SHOW OPEN TABLES WHERE In_use > 0;"
```

#### Check PostgreSQL

```bash
# Check PostgreSQL service
systemctl status postgresql

# Check connections
psql -c "SELECT * FROM pg_stat_activity;"

# Check slow queries
psql -c "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### Redis Health

```bash
# Check Redis service
systemctl status redis

# Check Redis info
redis-cli info

# Check memory usage
redis-cli info memory

# Check connected clients
redis-cli info clients
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Jobs not processing | Queue growing | Check Horizon status, restart workers |
| Cron not running | Tasks not executing | Check cron syntax, verify system time |
| DB connections exhausted | Too many connections | Check max_connections, identify leaks |
| Redis OOM | Cannot set values | Check maxmemory, evict old keys |

---

## Performance Diagnostics

### CPU Analysis

#### Check CPU Usage

```bash
# Overall CPU usage
top -bn1 | grep "Cpu(s)"

# Per-core usage
mpstat -P ALL

# CPU usage by process
ps aux --sort=-%cpu | head -20

# CPU frequency
cpupower frequency-info
```

#### Identify CPU Bottlenecks

```bash
# System-wide CPU stats
vmstat 1 5

# Process CPU usage
pidstat -u 1 5

# Top CPU consumers
htop
```

### Memory Analysis

#### Check Memory Usage

```bash
# Overall memory
free -h

# Detailed memory
vmstat -s

# Process memory
ps aux --sort=-%mem | head -20

# Memory by process
smem --sort name
```

#### Identify Memory Leaks

```bash
# Monitor over time
watch -n 5 'free -h'

# Process memory trend
pidstat -r 1 10

# Detailed process info
pmap {pid}
```

### Disk Analysis

#### Check Disk Usage

```bash
# Disk usage by mount
df -h

# Inode usage
df -i

# Directory sizes
du -sh {directory}/* | sort -h

# Largest directories
du -h --max-depth=2 / | sort -hr | head -20
```

#### Disk I/O

```bash
# I/O stats
iostat -x 1 5

# Disk usage by process
iotop

# Disk throughput
hdparm -Tt /dev/sda
```

### Network I/O

```bash
# Network interface stats
ip -s link

# Connection statistics
ss -s

# Network throughput
iftop

# Socket statistics
ss -tuln
```

### Common Performance Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| High CPU | Sluggish, load spike | Identify process, optimize or scale |
| Memory leak | Usage grows over time | Identify process, restart or patch |
| Disk full | Cannot write files | Clean old files, extend storage |
| I/O wait | Slow disk operations | Check disk health, optimize queries |
| Network saturation | Slow transfers | Identify traffic, QoS or upgrade |

---

## Log Analysis

### Finding Important Logs

```bash
# Application logs (Laravel)
tail -f storage/logs/laravel.log

# Docker container logs
docker logs {container} -f

# System logs
journalctl -f

# Nginx logs
tail -f /var/log/nginx/error.log
```

### Log Patterns to Look For

#### Error Patterns

```bash
# Find errors in logs
grep -i "error" storage/logs/laravel.log

# Find exceptions
grep -i "exception" storage/logs/laravel.log

# Find fatal errors
grep -i "fatal" storage/logs/laravel.log

# Find connection errors
grep -i "connection refused" storage/logs/laravel.log
```

#### Time-Based Analysis

```bash
# Logs from last hour
journalctl --since "1 hour ago"

# Logs from specific time
journalctl --since "2025-01-20 10:00:00" --until "2025-01-20 11:00:00"

# Grep with context
grep -B 5 -A 5 "error" storage/logs/laravel.log
```

### Log Aggregation

```bash
# Count error types
grep -oP '"type":"\K[^"]+' storage/logs/laravel.log | sort | uniq -c | sort -nr

# Find top error messages
grep -oP '"message":"\K[^"]+' storage/logs/laravel.log | sort | uniq -c | sort -nr | head -20

# Find errors by source
grep -oP '"source":"\K[^"]+' storage/logs/laravel.log | sort | uniq -c | sort -nr
```

---

## Root Cause Analysis

### 5 Whys Technique

Keep asking "why" until you reach the root cause.

Example:
1. Why is the application slow? Database queries are slow.
2. Why are queries slow? Missing index on large table.
3. Why is the index missing? It was never added during schema design.
4. Why wasn't it added? No performance requirements were specified.
5. Why no requirements? Lack of performance planning process.

### Fishbone Diagram

Categories for root cause analysis:

```
        People
          |
Methods -|- Machines
          |
        Materials
          |
Environment -|- Measurement
```

### Timeline Analysis

Create a timeline of events to identify patterns:

```yaml
incident_timeline:
  - time: "09:00"
    event: "User reported slowness"
  - time: "09:05"
    event: "Checked Horizon - workers processing normally"
  - time: "09:10"
    event: "Checked database - slow query detected"
  - time: "09:15"
    event: "Identified missing index"
  - time: "09:20"
    event: "Applied index migration"
  - time: "09:25"
    event: "Performance restored"
```

### Decision Tree

Use a decision tree for systematic diagnosis:

```
Is the system reachable?
├─ No → Check network, power, hardware
└─ Yes → Is the service running?
    ├─ No → Start service, check logs
    └─ Yes → Are resources exhausted?
        ├─ Yes → Scale or optimize
        └─ No → Check application logs
```

---

## Quick Reference Commands

```bash
# Full diagnostic scan
bash .agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-full-scan.sh

# Quick health check
docker ps && pvesh get /cluster/status && php artisan horizon:status

# Check all resources
docker stats --no-stream && pvesh get /nodes/*/status/current

# View recent logs
tail -100 storage/logs/laravel.log && journalctl -n 50

# Check queue status
redis-cli -n 1 keys "queues:*" | xargs -I {} redis-cli -n 1 llen {}

# Network diagnostics
ping -c 3 google.com && nc -zv {host} {port} && curl -I https://{host}
```

---

## Scripts Reference

All diagnostic scripts are located in `scripts/`:

- `diag-full-scan.sh` - Comprehensive diagnostic across all systems
- `diag-proxmox.sh` - Proxmox cluster and node health
- `diag-docker.sh` - Container and Docker daemon checks
- `diag-network.sh` - Connectivity, DNS, routing, VPN
- `diag-queues.sh` - Laravel Horizon and queue worker status
- `diag-performance.sh` - CPU, memory, disk, I/O metrics

All scripts output JSON reports with findings and actionable recommendations.
