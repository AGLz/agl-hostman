# MySQL High Availability Implementation

## Overview

This document describes the MySQL High Availability (HA) implementation for AGL Hostman, providing automated failover, backup/recovery procedures, and monitoring capabilities.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         Application Layer (Laravel)                           │
│                     ┌─────────────────────────────┐                            │
│                     │   Read/Write Splitting     │                            │
│                     └─────────────┬───────────────┘                            │
│                                   │                                          │
├───────────────────────────────────────────┼───────────────────────────────────────────┤
│                                   │                                          │
│                    ┌──────────────▼──────────────┐                             │
│                    │      ProxySQL Layer        │                             │
│                    │  - Connection Pooling      │                             │
│                    │  - Query Routing          │                             │
│                    │  - Health Monitoring      │                             │
│                    └──────────────┬──────────────┘                             │
│                                   │                                          │
│              ┌──────────────────────┼──────────────────────┐                │
│              │                      │                      │                │
│    ┌───────▼────────┐    ┌───────▼────────┐    ┌───────▼────────┐   │
│    │  MySQL Master   │    │  MySQL Slave 1  │    │  MySQL Slave 2  │   │
│    │  (Write)       │    │  (Read)        │    │  (Read)        │   │
│    │  Server ID: 1   │    │  Server ID: 2   │    │  Server ID: 3   │   │
│    └────────────────┘    └────────────────┘    └────────────────┘   │
│              │                      │                      │                │
│              └──────────────────────┴──────────────────────┘                │
│                                   │                                          │
├───────────────────────────────────┼───────────────────────────────────────────────┤
│                                   │                                          │
│                    ┌──────────────▼──────────────┐                             │
│                    │   Backup Automation        │                             │
│                    │   - XtraBackup            │                             │
│                    │   - S3 Upload             │                             │
│                    │   - Retention Policy       │                             │
│                    └─────────────────────────────┘                             │
│                                                                       │
│                    ┌─────────────────────────────┐                             │
│                    │   Monitoring & Alerting     │                             │
│                    │   - Prometheus Exporter    │                             │
│                    │   - Grafana Dashboards    │                             │
│                    │   - Alert Rules           │                             │
│                    └─────────────────────────────┘                             │
│                                                                       │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

## Key Features

| Feature | Description | Status |
|----------|-------------|--------|
| **Master-Slave Replication** | GTID-based asynchronous replication with semi-sync | ✅ |
| **Read/Write Splitting** | ProxySQL automatically routes reads to slaves, writes to master | ✅ |
| **Connection Pooling** | ProxySQL manages connection pools for performance | ✅ |
| **Automated Failover** | Automatic slave promotion when master fails | ✅ |
| **Automated Backups** | Percona XtraBackup with S3 upload | ✅ |
| **Point-in-Time Recovery** | PITR using binary logs | ✅ |
| **Monitoring** | Prometheus metrics and Grafana dashboards | ✅ |
| **Alerting** | Slack/PagerDuty integration | ✅ |

## Deployment

### Quick Start

```bash
# 1. Configure environment
cd /mnt/overpower/apps/dev/agl/agl-hostman/infrastructure/docker
cp mysql/ha/replication-config.env.example mysql/ha/replication-config.env
# Edit replication-config.env with your values

# 2. Start MySQL HA stack
docker compose -f docker-compose.mysql-ha.yml up -d

# 3. Initialize replication
docker exec agl-mysql-master /scripts/setup-replication.sh init

# 4. Verify replication
docker exec agl-mysql-master /scripts/setup-replication.sh verify
```

### Ansible Deployment

```bash
# Deploy to production hosts
cd /mnt/overpower/apps/dev/agl/agl-hostman/infrastructure/ansible
ansible-playbook -i inventory mysql-ha.yml --tags all

# Deploy only replication
ansible-playbook -i inventory mysql-ha.yml --tags replication

# Deploy only monitoring
ansible-playbook -i inventory mysql-ha.yml --tags monitoring
```

## Configuration Files

| File | Purpose |
|------|-----------|
| `/infrastructure/docker/docker-compose.mysql-ha.yml` | Docker Compose for MySQL HA stack |
| `/infrastructure/docker/mysql/ha/my-master.cnf` | MySQL Master configuration |
| `/infrastructure/docker/mysql/ha/my-slave.cnf` | MySQL Slave configuration |
| `/infrastructure/docker/mysql/proxysql/proxysql.cnf` | ProxySQL configuration |
| `/infrastructure/monitoring/prometheus/rules/mysql-ha-rules.yml` | Prometheus alert rules |
| `/infrastructure/ansible/playbooks/mysql-ha.yml` | Ansible deployment playbook |
| `/config/database-ha.php` | Laravel database configuration |
| `/config/database-ha.env` | Environment variables template |

## Backup and Recovery

### Backup Strategy

1. **Full Backups**: Daily at 2 AM (configurable via `BACKUP_SCHEDULE`)
2. **Incremental Backups**: Every 6 hours at 6 AM, 12 PM, 6 PM
3. **Compression**: Backups compressed with pigz
4. **S3 Upload**: Optional upload to S3 for off-site storage
5. **Retention**: 7 days for full, 3 days for incremental

### Running Backups

```bash
# Manual full backup
docker exec agl-mysql-backup /scripts/backup-scheduler.sh full

# Manual incremental backup
docker exec agl-mysql-backup /scripts/backup-scheduler.sh inc

# List available backups
docker exec agl-mysql-backup /scripts/backup-scheduler.sh list
```

### Recovery Procedures

#### Full Restoration

```bash
# List available backups
docker exec agl-mysql-backup /scripts/restore.sh list

# Restore from specific backup
docker exec agl-mysql-backup /scripts/restore.sh restore /backups/full/20240201-120000

# Force restore (skip confirmation)
FORCE_RESTORE=true docker exec agl-mysql-backup /scripts/restore.sh restore /backups/full/latest
```

#### Point-in-Time Recovery

```bash
# Restore to specific point in time
docker exec agl-mysql-backup /scripts/restore.sh pitr /backups/full/20240201-120000 "2024-02-01 15:30:00"
```

## Failover Procedures

### Automated Failover

The failover monitor automatically:
1. Detects master failure (3 consecutive failed health checks)
2. Verifies at least one slave is healthy with acceptable lag
3. Promotes the healthiest slave to master
4. Updates application configuration
5. Sends alerts via Slack/email

### Manual Failover

```bash
# Check health status
docker exec agl-mysql-failover /scripts/failover-monitor.sh health

# Trigger manual failover
docker exec agl-mysql-failover /scripts/failover-monitor.sh failover
```

### Failback Procedure

```bash
# 1. Ensure old master is repaired and started
docker start agl-mysql-master

# 2. Verify replication is working
docker exec agl-mysql-master /scripts/setup-replication.sh verify

# 3. Perform failback (manual process recommended)
# - Stop all application writes
# - Verify data consistency
# - Reconfigure replication from new master to old master
# - Update application configuration
# - Restart application

docker exec agl-mysql-failover /scripts/restore.sh failback
```

## Monitoring

### Access Points

| Service | URL | Credentials |
|---------|------|-------------|
| **Grafana** | http://localhost:3000 | admin/GRAFANA_PASSWORD |
| **Prometheus** | http://localhost:9090 | - |
| **PhpMyAdmin** | http://localhost:8084 | DB_USERNAME/DB_PASSWORD |
| **ProxySQL Admin** | `mysql -h localhost -P 6080` | admin/admin |

### Key Metrics

- **Replication Lag**: `mysql_slave_status_seconds_behind_master`
- **Connection Usage**: `mysql_global_status_threads_connected / mysql_global_variables_max_connections`
- **Query Performance**: `mysql_global_status_slow_queries`
- **Buffer Pool**: `mysql_global_status_innodb_buffer_pool_pages_total`

### Alert Thresholds

| Metric | Warning | Critical | Action |
|----------|----------|-----------|--------|
| Replication Lag | 30s | 300s | Check network, restart slave |
| Connection Usage | 80% | 95% | Add connections/servers |
| Disk Space | 80% | 90% | Clean up old backups |
| Master Down | N/A | Immediate | Trigger failover |

## Maintenance Procedures

### Zero-Downtime Schema Changes

Use `pt-online-schema-change` for safe schema modifications:

```bash
# Example: Add column without locking
pt-online-schema-change \
  --alter "ADD COLUMN new_column INT" \
  --host=localhost \
  --database=agl_hostman \
  --table=users \
  --user=root \
  --password=${MYSQL_ROOT_PASSWORD} \
  --execute
```

### Slave Maintenance

```bash
# Stop replication gracefully
mysql -h mysql-slave-1 -u root -p${MYSQL_ROOT_PASSWORD} -e "STOP SLAVE;"

# Perform maintenance
# ...

# Start replication
mysql -h mysql-slave-1 -u root -p${MYSQL_ROOT_PASSWORD} -e "START SLAVE;"
```

### ProxySQL Maintenance

```sql
-- Connect to ProxySQL admin interface
mysql -h localhost -P 6080 -u admin -padmin

-- Reload configuration
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;

-- Save to disk
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;

-- Check query cache
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;
```

## Troubleshooting

### Replication Issues

```bash
# Check slave status
docker exec agl-mysql-slave-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW SLAVE STATUS\G"

# Check replication lag
docker exec agl-mysql-slave-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW SLAVE STATUS" | awk '/Seconds_Behind_Master/ {print $2}'

# Skip problematic transaction (use carefully)
docker exec agl-mysql-slave-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "STOP SLAVE; SET GLOBAL sql_slave_skip_counter = 1; START SLAVE;"
```

### Connection Issues

```bash
# Check ProxySQL backend status
mysql -h localhost -P 6080 -u admin -padmin -e "SELECT * FROM mysql_servers;"

# Check connection pool usage
mysql -h localhost -P 6080 -u admin -padmin -e "SELECT * FROM stats_mysql_connection_pool;"

# Flush connection pool
mysql -h localhost -P 6080 -u admin -padmin -e "UPDATE mysql_servers SET max_connections=0; UPDATE mysql_servers SET max_connections=1000;"
```

### Performance Issues

```bash
# Check slow queries
docker exec agl-mysql-master tail -f /var/log/mysql/slow-query.log

# Check InnoDB status
docker exec agl-mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW ENGINE INNODB STATUS\G"

# Check buffer pool hit rate
docker exec agl-mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
  SELECT
    (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_read_requests') /
    (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_reads') * 100
  AS hit_rate_percentage;
"
```

## Best Practices

1. **Test Backups Regularly**: Unrestored backups don't exist
2. **Monitor Replication Lag**: Keep under 5 seconds normally
3. **Use Read/Write Splitting**: Route reads to slaves for better performance
4. **Practice Failover**: Conduct quarterly failover drills
5. **Document Changes**: Keep runbooks updated
6. **Review Alerts**: Adjust thresholds based on actual usage patterns

## Runbooks

- [Master Failure Runbook](RUNBOOK-MASTER-FAILURE.md)
- [Replication Issues Runbook](RUNBOOK-REPLICATION.md)
- [Performance Tuning Guide](PERFORMANCE-TUNING.md)
- [Disaster Recovery Plan](DISASTER-RECOVERY.md)

## References

- [MySQL Replication Documentation](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [ProxySQL Documentation](https://www.proxysql.com/documentation/)
- [Percona XtraBackup](https://docs.percona.com/percona-xtrabackup/8.0/)
- [Laravel Database Configuration](https://laravel.com/docs/8.x/database)

---

**Document Version**: 1.0.0
**Last Updated**: 2026-02-11
**Maintainer**: AGL Infrastructure Team
