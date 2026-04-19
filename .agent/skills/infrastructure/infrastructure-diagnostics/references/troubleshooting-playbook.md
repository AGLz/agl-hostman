# Infrastructure Troubleshooting Playbook

This playbook provides step-by-step procedures for resolving common infrastructure issues in the AGL environment.

## Table of Contents

1. [Emergency Procedures](#emergency-procedures)
2. [Application Issues](#application-issues)
3. [Container Issues](#container-issues)
4. [Proxmox Issues](#proxmox-issues)
5. [Network Issues](#network-issues)
6. [Queue Issues](#queue-issues)
7. [Performance Issues](#performance-issues)
8. [Storage Issues](#storage-issues)

---

## Emergency Procedures

### Application Completely Down

**Symptoms:**
- All endpoints returning 502/503
- Cannot access web interface
- No containers running

**Steps:**

1. **Check basic connectivity**
   ```bash
   ping $(hostname)
   systemctl status nginx
   docker ps
   ```

2. **Check if containers are running**
   ```bash
   docker ps -a
   ```

3. **Restart stopped containers**
   ```bash
   docker start $(docker ps -a -q -f status=exited)
   ```

4. **Check logs for errors**
   ```bash
   docker logs $(docker ps -a -q -f status=exited) --tail 100
   ```

5. **If containers won't start, check Docker daemon**
   ```bash
   systemctl status docker
   systemctl restart docker
   ```

6. **Verify application services**
   ```bash
   curl -I http://localhost:8000
   php artisan tinker --execute="echo 'App is accessible';"
   ```

### High CPU Alert

**Symptoms:**
- CPU usage > 85%
- Load average > CPU cores
- Slow application response

**Steps:**

1. **Identify top CPU consumers**
   ```bash
   ps aux --sort=-%cpu | head -20
   docker stats --no-stream | sort -k3 -hr
   ```

2. **Check for runaway processes**
   ```bash
   top -bn1 | head -20
   ```

3. **If a container is consuming excessive CPU**
   ```bash
   docker stats --no-stream
   # Identify the container
   docker logs <container> --tail 100
   # Consider restarting the container
   docker restart <container>
   ```

4. **Check for Kubernetes/Orchestration issues**
   ```bash
   kubectl top pods
   ```

5. **If system process is consuming CPU**
   ```bash
   systemctl status cron
   # Check for scheduled tasks
   ```

### Memory Exhaustion

**Symptoms:**
- Memory usage > 90%
- OOM killer messages in logs
- Processes being killed

**Steps:**

1. **Check memory usage**
   ```bash
   free -h
   ps aux --sort=-%mem | head -20
   ```

2. **Check for memory leaks**
   ```bash
   docker stats --no-stream | sort -k4 -hr
   ```

3. **Clear caches if appropriate**
   ```bash
   sync; echo 3 > /proc/sys/vm/drop_caches
   ```

4. **Restart memory-hungry containers**
   ```bash
   docker restart <container>
   ```

5. **Check swap usage**
   ```bash
   free -h | grep Swap
   ```

---

## Application Issues

### Laravel Application Slow

**Symptoms:**
- Page load times > 5 seconds
- High response times
- Database queries taking long

**Steps:**

1. **Check application logs**
   ```bash
   tail -100 storage/logs/laravel.log | grep -i error
   ```

2. **Enable query logging if not enabled**
   ```bash
   # In config/database.php
   'log' => env('DB_QUERY_LOG', true),
   ```

3. **Check slow queries**
   ```bash
   mysql -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"
   ```

4. **Clear application cache**
   ```bash
   php artisan cache:clear
   php artisan config:clear
   php artisan route:clear
   php artisan view:clear
   ```

4. **Restart queue workers**
   ```bash
   php artisan horizon:terminate
   # Horizon will auto-restart
   ```

5. **Check for N+1 queries**
   ```bash
   # Use Laravel Debugbar or Telescope
   php artisan telescope:install
   ```

### Queue Jobs Not Processing

**Symptoms:**
- Jobs accumulating in queue
- Failed jobs increasing
- Horizon showing no activity

**Steps:**

1. **Check Horizon status**
   ```bash
   systemctl status horizon
   php artisan horizon:status
   ```

2. **Check queue sizes**
   ```bash
   redis-cli -n 1 llen queues:default
   redis-cli -n 1 llen queues:high
   redis-cli -n 1 llen queues:low
   ```

3. **Restart Horizon**
   ```bash
   systemctl restart horizon
   ```

4. **Check failed jobs**
   ```bash
   php artisan queue:failed
   php artisan queue:retry all
   ```

5. **Check worker logs**
   ```bash
   journalctl -u horizon -n 100
   ```

6. **Verify Redis connection**
   ```bash
   redis-cli ping
   redis-cli info clients
   ```

### Database Connection Issues

**Symptoms:**
- "SQLSTATE[HY000] [2002] Connection refused"
- Cannot connect to MySQL/PostgreSQL
- Authentication errors

**Steps:**

1. **Check database service**
   ```bash
   systemctl status mysql
   # or
   systemctl status postgresql
   ```

2. **Check database connections**
   ```bash
   mysql -e "SHOW PROCESSLIST;"
   # or
   psql -c "SELECT * FROM pg_stat_activity;"
   ```

3. **Check connection limits**
   ```bash
   mysql -e "SHOW VARIABLES LIKE 'max_connections';"
   ```

4. **Test connection from application**
   ```bash
   php artisan tinker --execute="DB::connection()->getPdo();"
   ```

5. **Check database logs**
   ```bash
   tail -100 /var/log/mysql/error.log
   ```

---

## Container Issues

### Container Won't Start

**Symptoms:**
- Container status: Exited
- Restart loop
- Cannot attach to container

**Steps:**

1. **Check container logs**
   ```bash
   docker logs <container> --tail 100
   ```

2. **Inspect container configuration**
   ```bash
   docker inspect <container>
   ```

3. **Check if port is already in use**
   ```bash
   netstat -tulpn | grep <port>
   ss -tulpn | grep <port>
   ```

4. **Check disk space**
   ```bash
   df -h
   ```

5. **Check image availability**
   ```bash
   docker images | grep <image>
   ```

6. **Recreate container**
   ```bash
   docker rm <container>
   docker run <parameters> <image>
   ```

### Container in Restart Loop

**Symptoms:**
- Status: Restarting
- Exits immediately after starting
- Logs show startup errors

**Steps:**

1. **Get detailed logs**
   ```bash
   docker logs <container> --tail 200
   docker logs <container> --since 1h
   ```

2. **Check if it's a resource issue**
   ```bash
   docker inspect <container> | jq '.[0].HostConfig.Memory'
   ```

3. **Try running interactively**
   ```bash
   docker run -it <image> /bin/bash
   ```

4. **Check for missing dependencies**
   ```bash
   docker exec <container> ls -la
   ```

5. **Update image if outdated**
   ```bash
   docker pull <image>
   docker restart <container>
   ```

---

## Proxmox Issues

### No Quorum

**Symptoms:**
- Cluster read-only
- Cannot start VMs
- "No quorum" error

**Steps:**

1. **Check cluster status**
   ```bash
   pvesh get /cluster/status
   ```

2. **For single-node cluster, set expected votes**
   ```bash
   pvecm expected 1
   ```

3. **Check network connectivity between nodes**
   ```bash
   ping <other-node-ip>
   ```

4. **Check corosync status**
   ```bash
   systemctl status pve-corosync
   ```

5. **Restart cluster services if needed**
   ```bash
   systemctl restart pve-cluster
   systemctl restart corosync
   ```

### VM Won't Start

**Symptoms:**
- VM status: Stopped
- "Task ERROR: command failed"
- Configuration errors

**Steps:**

1. **Check VM status**
   ```bash
   pvesh get /nodes/<node>/qemu/<vmid>/status/current
   ```

2. **Check VM configuration**
   ```bash
   pvesh get /nodes/<node>/qemu/<vmid>/config
   ```

3. **Check if VM is locked**
   ```bash
   qm status <vmid>
   ```

4. **Clear lock if present**
   ```bash
   qm unlock <vmid>
   ```

5. **Check storage availability**
   ```bash
   pvesm status
   ```

6. **Start VM from command line**
   ```bash
   qm start <vmid>
   ```

---

## Network Issues

### Cannot Connect to Service

**Symptoms:**
- Connection refused
- Timeout errors
- Cannot resolve hostname

**Steps:**

1. **Check if service is listening**
   ```bash
   ss -tulpn | grep <port>
   netstat -tulpn | grep <port>
   ```

2. **Check firewall rules**
   ```bash
   ufw status
   iptables -L -n -v
   ```

3. **Check DNS resolution**
   ```bash
   nslookup <hostname>
   dig <hostname>
   ```

4. **Test connectivity**
   ```bash
   ping <host>
   nc -zv <host> <port>
   ```

5. **Check routing**
   ```bash
   ip route show
   traceroute <host>
   ```

6. **Check if VPN is affecting connectivity**
   ```bash
   wg show
   tailscale status
   ```

### High Network Latency

**Symptoms:**
- Slow response times
- Connection timeouts
- Packet loss

**Steps:**

1. **Measure latency**
   ```bash
   ping -c 10 <host>
   mtr <host>
   ```

2. **Check for packet loss**
   ```bash
   ping -c 100 <host> | grep "packet loss"
   ```

3. **Check network interface errors**
   ```bash
   ip -s link show
   ```

4. **Check bandwidth usage**
   ```bash
   iftop
   nethogs
   ```

5. **Check for network congestion**
   ```bash
   sar -n DEV 1 10
   ```

---

## Queue Issues

### Jobs Stuck in Queue

**Symptoms:**
- Queue size growing
- Jobs not being processed
- Horizon shows idle workers

**Steps:**

1. **Check Horizon status**
   ```bash
   systemctl status horizon
   php artisan horizon:status
   ```

2. **Check queue sizes**
   ```bash
   redis-cli -n 1 keys "queues:*"
   redis-cli -n 1 llen queues:default
   ```

3. **Check worker status**
   ```bash
   supervisorctl status horizon*
   ```

4. **Restart Horizon**
   ```bash
   systemctl restart horizon
   ```

5. **Check for memory issues in workers**
   ```bash
   ps aux | grep horizon
   ```

6. **Purge queue if needed (use with caution)**
   ```bash
   php artisan queue:flush
   ```

### Failed Jobs

**Symptoms:**
- Failed jobs table growing
- Jobs retrying indefinitely
- Error in job execution

**Steps:**

1. **View failed jobs**
   ```bash
   php artisan queue:failed
   ```

2. **Get specific job details**
   ```bash
   php artisan queue:failed <job_id>
   ```

3. **Retry failed jobs**
   ```bash
   php artisan queue:retry all
   php artisan queue:retry <job_id>
   ```

4. **Delete failed jobs if needed**
   ```bash
   php artisan queue:flush
   ```

5. **Check exception messages**
   ```bash
   php artisan queue:failed | grep -i "exception"
   ```

---

## Performance Issues

### Slow Application Response

**Symptoms:**
- Page load times > 5 seconds
- High latency in API calls
- Database queries slow

**Steps:**

1. **Check application performance**
   ```bash
   php artisan tinker --execute="echo microtime(true);"
   ```

2. **Check database query performance**
   ```bash
   mysql -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"
   ```

3. **Check cache hit rate**
   ```bash
   redis-cli info stats | grep keyspace
   ```

4. **Enable Laravel Telescope for profiling**
   ```bash
   php artisan telescope:install
   ```

5. **Check for N+1 queries**
   ```bash
   # Use Laravel Debugbar in development
   composer require barryvdh/laravel-debugbar --dev
   ```

6. **Optimize autoloader**
   ```bash
   composer install --optimize-autoloader --no-dev
   ```

### High I/O Wait

**Symptoms:**
- High %iowait in top
- Slow disk operations
- Processes waiting for I/O

**Steps:**

1. **Check I/O stats**
   ```bash
   iostat -x 1 5
   ```

2. **Identify I/O-intensive processes**
   ```bash
   iotop
   pidstat -d 1 10
   ```

3. **Check disk health**
   ```bash
   smartctl -a /dev/sda
   ```

4. **Check for swap activity**
   ```bash
   vmstat 1 5
   ```

5. **Consider moving to faster storage**
   ```bash
   # Move to SSD if using HDD
   ```

---

## Storage Issues

### Disk Full

**Symptoms:**
- Cannot write files
- "No space left on device"
- Services failing

**Steps:**

1. **Check disk usage**
   ```bash
   df -h
   du -sh /* | sort -hr | head -20
   ```

2. **Find large files**
   ```bash
   find / -type f -size +1G -exec ls -lh {} \; 2>/dev/null
   ```

3. **Clean old logs**
   ```bash
   find /var/log -type f -name "*.log" -mtime +30 -delete
   ```

4. **Clean Docker resources**
   ```bash
   docker system prune -a
   docker volume prune
   ```

5. **Clean old backups**
   ```bash
   find /backup -type f -mtime +90 -delete
   ```

6. **Clear package cache**
   ```bash
   apt clean
   apt autoclean
   ```

### Inode Exhaustion

**Symptoms:**
- "No space left on device" but disk has space
- Cannot create new files
- Many small files

**Steps:**

1. **Check inode usage**
   ```bash
   df -i
   ```

2. **Find directories with many files**
   ```bash
   for i in /*; do echo $i; find $i -xdev | wc -l; done
   ```

3. **Clean up small files**
   ```bash
   find /path -type f -size 0 -delete
   ```

4. **Remove cache directories**
   ```bash
   rm -rf /path/to/cache/*
   ```

---

## Escalation Procedures

### When to Escalate

- Issue persists after following troubleshooting steps
- Multiple systems affected simultaneously
- Data loss or corruption suspected
- Security breach suspected
- Production downtime exceeds SLA

### Information to Gather

1. **System Information**
   ```bash
   uname -a
   uptime
   df -h
   free -h
   ```

2. **Recent Logs**
   ```bash
   journalctl -n 500 > /tmp/journal.log
   docker logs <container> --tail 500 > /tmp/docker.log
   ```

3. **Configuration Files**
   ```bash
   # Backup relevant configs
   tar -czf /tmp/configs.tar.gz /etc/<service>/
   ```

4. **Metrics and Screenshots**
   - Take screenshots of monitoring dashboards
   - Export metrics for the time period

---

## Prevention and Monitoring

### Regular Health Checks

```bash
# Run daily
.agent/skills/infrastructure/infrastructure-diagnostics/scripts/diag-full-scan.sh

# Monitor resources
watch -n 5 'free -h && df -h'

# Check logs
tail -f storage/logs/laravel.log
```

### Alert Thresholds

Based on `config/monitoring.php`:

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU | 70% | 85% |
| Memory | 80% | 90% |
| Disk | 80% | 90% |
| Load | 1.0 | 2.0 |
| Latency | 50ms | 150ms |

### Maintenance Tasks

**Daily:**
- Review system alerts
- Check queue status
- Monitor disk usage

**Weekly:**
- Review slow queries
- Check backup integrity
- Review failed jobs

**Monthly:**
- Security updates
- Log rotation verification
- Capacity planning review
