# AGL Hostman High Availability Implementation Guide

## Overview

This guide covers implementing a complete High Availability (HA) infrastructure for AGL Hostman with:

- **99.9% uptime SLA** (max 43.2 min downtime/month)
- **Automatic failover** for MySQL and Redis
- **Zero-downtime deployments** with blue-green strategy
- **Load distribution** across multiple application nodes
- **Comprehensive monitoring** with alerting

## Architecture

```
                            ┌─────────────────┐
                            │   Internet     │
                            └───────┬───────┘
                                    │
                            ┌──────────▼──────────┐
                            │   HAProxy LB       │
                            │   (Primary)        │
                            └──────────┬──────────┘
                                       │
            ┌──────────────────────────────┼──────────────────────────────┐
            │                          │                          │
   ┌────────▼────────┐      ┌──────────▼───────┐      ┌──────────▼───────┐
   │  App Blue-1     │      │  App Blue-2       │      │  App Green-1     │
   │  (Primary)       │      │  (Primary)        │      │  (Standby)        │
   │  PHP-FPM/Nginx  │      │  PHP-FPM/Nginx   │      │  PHP-FPM/Nginx   │
   └────────┬─────────┘      └──────────┬─────────┘      └──────────┬─────────┘
            │                          │                          │
            └──────────────────────────────┼──────────────────────────────┘
                                       │
            ┌──────────────────────────────┼──────────────────────────────┐
            │                          │                          │
   ┌────────▼────────┐      ┌──────────▼───────┐      ┌──────────▼───────┐
   │ MySQL Master    │─────▶│ MySQL Slave-1      │      │ MySQL Slave-2      │
   │ (Write)        │      │ (Read)            │      │ (Read)            │
   │ GTID Replication│◀─────│                   │◀─────│                   │
   └─────────────────┘      └─────────────────────┘      └─────────────────────┘
            │
   ┌────────▼────────┐      ┌──────────▼───────┐      ┌──────────▼───────┐
   │ Redis Master   │─────▶│ Redis Slave-1      │      │ Redis Slave-2      │
   │ Sentinel HA    │◀─────│                   │◀─────│                   │
   └─────────────────┘      └──────────┬─────────┘      └──────────┬─────────┘
                                     │                          │
                              ┌──────────▼───────────┬──────────▼───────┐
                              │ Sentinel-1           │ Sentinel-2         │
                              │ (Auto-failover)      │ (Auto-failover)    │
                              └──────────────────────┴─────────────────────┘
```

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU       | 2 cores  | 4 cores      |
| RAM        | 4 GB     | 8 GB         |
| Storage    | 50 GB    | 100 GB SSD    |
| Network    | 1 Gbps   | 10 Gbps      |

### Software Requirements

- Ubuntu 22.04 LTS
- Docker 24.0+
- Docker Compose 2.20+
- Ansible 2.14+
- HAProxy 2.8+
- MySQL 8.0+
- Redis 7.0+

## Implementation Steps

### Phase 1: Infrastructure Setup (Days 1-2)

#### 1.1 Provision Load Balancer

```bash
# Using Terraform
cd infrastructure/terraform
terraform apply -target=module.ha_load_balancer

# Or using Ansible
cd infrastructure/ansible
ansible-playbook playbooks/ha/ha-setup.yml --tags haproxy
```

**Verification:**
```bash
curl http://lb-hostname:8404/stats
# Login with admin/stats password
```

#### 1.2 Configure MySQL Master-Slave

```bash
# Deploy MySQL cluster
ansible-playbook playbooks/ha/ha-setup.yml --tags mysql

# Verify replication
mysql -h mysql-master -e "SHOW MASTER STATUS\G"
mysql -h mysql-slave-1 -e "SHOW SLAVE STATUS\G"
```

**Expected Output:**
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

#### 1.3 Deploy Redis Sentinel

```bash
ansible-playbook playbooks/ha/ha-setup.yml --tags redis,sentinel

# Verify Sentinel cluster
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL slaves mymaster
```

### Phase 2: Application Configuration (Days 3-4)

#### 2.1 Update Application Environment

```bash
# Edit .env on all app servers
DB_HOST=mysql-master
DB_PORT=3306
DB_READ_HOST=mysql-slave-1,mysql-slave-2
REDIS_HOST=redis-master
REDIS_PORT=6379
REDIS_SENTINEL_MASTER=mymaster
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
```

#### 2.2 Configure Read/Write Splitting

**Database Config (config/database.php):**
```php
'reads' => [
    'host' => env('DB_READ_HOST', 'mysql-slave-1,mysql-slave-2'),
],
'write' => [
    'host' => env('DB_HOST', 'mysql-master'),
],
```

#### 2.3 Deploy Application Services

```bash
# Deploy blue environment
docker compose -f docker/production/docker-compose.blue.yml up -d

# Health check
curl http://app-blue-1:8080/health
curl http://app-blue-2:8080/health
```

### Phase 3: Monitoring & Alerting (Days 5)

#### 3.1 Deploy Prometheus

```bash
docker compose -f infrastructure/docker/docker-compose.ha.yml up -d prometheus
```

#### 3.2 Deploy Grafana Dashboards

```bash
# Import dashboards
curl -X POST http://grafana:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @infrastructure/monitoring/grafana/dashboards/ha-overview.json
```

#### 3.3 Configure AlertManager

```yaml
# alertmanager.yml
route:
  receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK}'
```

### Phase 4: Testing & Validation (Days 6-7)

#### 4.1 Load Testing

```bash
# Using siege
siege -c 100 -t 60s http://lb-hostname/

# Using wrk
wrk -t4 -c100 -d60s http://lb-hostname/
```

#### 4.2 Failover Testing

**MySQL Failover:**
```bash
# Stop master
systemctl stop mysql

# Trigger failover script
./infrastructure/scripts/ha/mysql-failover-automated.sh execute

# Verify new master
mysql -h mysql-slave-1 -e "SELECT @@read_only"
# Should return 0
```

**Redis Failover:**
```bash
# Stop master
redis-cli SHUTDOWN

# Monitor sentinel failover
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

# Verify automatic promotion
# Should return new master IP
```

#### 4.3 Disaster Recovery Test

1. **Simulate network partition** - disconnect one AZ
2. **Verify traffic reroutes** to healthy nodes
3. **Restore connectivity** - verify auto-recovery
4. **Check data consistency** - GTID positions

## Runbooks

### MySQL Failover Procedure

**Detection:**
```bash
# Check master status
mysqladmin -h mysql-master ping
# Returns: mysqld is alive

# Check slave lag
mysql -h mysql-slave-1 -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
# Should be < 10 seconds
```

**Manual Failover:**
```bash
# Run failover script
./infrastructure/scripts/ha/mysql-failover-automated.sh execute

# Update application
# Script updates .env and reloads services
```

**Verification:**
```bash
# Check new master
mysql -h <new-master> -e "SELECT @@read_only"
# Returns: 0

# Verify replication from other slaves
mysql -h mysql-slave-2 -e "SHOW SLAVE STATUS\G"
# Master_Host should show new master
```

### Redis Sentinel Failover

**Detection:**
```bash
# Check sentinel status
redis-cli -p 26379 SENTINEL masters

# Check current master
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

**Automatic Failover:**
Sentinel automatically:
1. Detects master down (> 5 seconds)
2. Reaches quorum (2 of 3 sentinels agree)
3. Promotes slave with lowest priority
4. Updates other slaves
5. Notifies applications

**Manual Intervention:**
```bash
# Force failover if needed
redis-cli -p 26379 SENTINEL failover mymaster
```

### Blue-Green Deployment

**Deploy Green:**
```bash
# Build new version
docker build -t agl-hostman:{{NEW_VERSION}} .

# Deploy to green
docker compose -f docker-compose.green.yml up -d

# Health check green
curl http://app-green-1:8080/health
```

**Switch Traffic:**
```bash
# Update HAProxy to use green
# Edit haproxy.cfg: change backup to active
# Reload config
haproxy -f /etc/haproxy/haproxy.cfg -D -p /run/haproxy.pid
```

**Rollback (if needed):**
```bash
# Revert to blue
haproxy -f /etc/haproxy/haproxy.cfg.bak -D -p /run/haproxy.pid
```

## Monitoring Dashboard URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| HAProxy Stats | http://lb:8404/stats | admin/[HAPROXY_STATS_PASSWORD] |
| Prometheus | http://monitoring:9090 | None |
| Grafana | http://monitoring:3000 | admin/[GRAFANA_PASSWORD] |
| MySQL Master | mysql://mysql-master:3306 | root/[MYSQL_ROOT_PASSWORD] |
| Redis Sentinel | redis://sentinel-1:26379 | None |

## SLA Metrics

### Uptime Calculation

```
Uptime % = (Total Time - Downtime) / Total Time * 100

99.9% SLA = 43.2 minutes downtime/month
99.95% SLA = 21.6 minutes downtime/month
99.99% SLA = 4.3 minutes downtime/month
```

### Response Time Targets

| Endpoint | Target | Alert Threshold |
|----------|--------|----------------|
| Health check | < 100ms | > 500ms |
| API calls | < 500ms | > 2000ms |
| Database query | < 50ms | > 200ms |
| Cache get | < 10ms | > 100ms |

### Recovery Time Objectives (RTO)

| Component | RTO Target | RPO Target |
|-----------|-------------|-------------|
| Application | < 5 min | < 1 min |
| MySQL | < 10 min | < 5 sec (GTID) |
| Redis | < 2 min | < 1 sec (AOF) |

## Cost Breakdown (Monthly Estimates)

| Component | Instance Type | Cost |
|-----------|---------------|------|
| HAProxy LB (2x) | c5.large | $140 |
| App Servers (4x) | c5.xlarge | $800 |
| MySQL Master | r5.2xlarge | $400 |
| MySQL Slaves (2x) | r5.xlarge | $400 |
| Redis Master | r5.large | $100 |
| Redis Slaves (2x) | r5.large | $200 |
| Sentinels (3x) | t3.medium | $60 |
| Monitoring (2x) | t3.large | $80 |
| **Total** | | **$2,180/mo** |

## Troubleshooting

### HAProxy Backend Down

**Symptoms:**
- 503 Service Unavailable errors
- Backend shows DOWN in stats page

**Diagnosis:**
```bash
# Check backend health
curl http://app-blue-1:8080/health

# Check HAProxy logs
tail -f /var/log/haproxy.log
```

**Solutions:**
1. Restart application service
2. Verify health endpoint returns 200
3. Check HAProxy configuration syntax
4. Reload HAProxy: `systemctl reload haproxy`

### MySQL Replication Lag

**Symptoms:**
- Stale data reads
- High `Seconds_Behind_Master` value

**Diagnosis:**
```bash
mysql -e "SHOW SLAVE STATUS\G" | grep -E 'Slave_IO|Seconds_Behind'
```

**Solutions:**
1. Check network latency between master/slave
2. Optimize long-running queries on master
3. Increase slave parallel workers
4. Check slave server resources (CPU/IO)

### Redis Split Brain

**Symptoms:**
- Multiple masters detected
- Data inconsistency

**Diagnosis:**
```bash
redis-cli -p 26379 SENTINEL masters
# Should show 1 master
```

**Solutions:**
1. Verify network connectivity between sentinels
2. Check firewall rules (port 26379)
3. Restart sentinel instances
4. Force manual failover to resolve

## Backup Strategy

### MySQL Backups

**Automated Backups:**
```bash
# Daily full backup
0 2 * * * mysqldump --all-databases --single-transaction | gzip > /backup/mysql-$(date +%Y%m%d).sql.gz

# Binary log backup (every 4 hours)
0 */4 * * * mysqlbinlog --read-from-remote-server --raw | gzip >> /backup/binlog-$(date +%Y%m%d).log.gz
```

**PITR (Point-in-Time Recovery):**
```bash
# Restore to specific point
mysqlbinlog --start-datetime="2024-01-15 10:00:00" \
  --stop-datetime="2024-01-15 14:30:00" \
  binlog.000123 | mysql -u root -p
```

### Redis Backups

**RDB Snapshots:**
```bash
# Every 6 hours
0 */6 * * * redis-cli BGSAVE

# Copy RDB file to backup location
cp /data/dump.rdb /backup/redis-$(date +%Y%m%d).rdb
```

**AOF Persistence:**
```bash
# AOF is enabled with everysec fsync
# More durable than RDB but slower
```

## Emergency Contacts

| Role | Name | Contact |
|------|------|----------|
| On-Call Engineer | [Name] | [Phone/Slack] |
| Database Lead | [Name] | [Email] |
| Infrastructure Lead | [Name] | [Email] |

## Maintenance Windows

**Scheduled Maintenance:**
- Every Sunday 2:00-4:00 UTC
- Notifications sent 48h in advance
- Maintenance page displayed during window

**Emergency Maintenance:**
- Immediate notification via Slack/PagerDuty
- Max 15 minutes for critical fixes
- RCA (Root Cause Analysis) required within 24h
