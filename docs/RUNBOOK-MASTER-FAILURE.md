# MySQL Master Failure Runbook

## Overview

This runbook provides step-by-step procedures for handling MySQL master failures in the AGL Hostman infrastructure.

## Severity: CRITICAL

**Target RTO**: 5 minutes
**Target RPO**: < 1 minute (based on replication lag)

## Prerequisites

- Access to Docker/Ansible control node
- Access to monitoring dashboards (Grafana: http://localhost:3000)
- Read access to this runbook
- Access to alert systems (Slack/Email)

## Detection

### Automatic Detection

The failover monitor (`mysql-failover` container) will:
1. Detect master failure after 3 consecutive failed health checks (30 seconds)
2. Verify at least one healthy slave exists
3. Automatically promote healthiest slave to master
4. Send alerts via Slack/Email

### Manual Detection

Check Prometheus alerts:
```bash
# Check for critical alerts
curl -s 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.severity == "critical")'
```

## Procedures

### 1. Initial Assessment (Minutes 0-2)

#### 1.1 Verify Failure

```bash
# Check master health
docker exec agl-mysql-master mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" ping

# Check ProxySQL backend status
mysql -h localhost -P 6080 -u admin -padmin -e "SELECT * FROM mysql_servers WHERE hostgroup_id=10;"

# Verify all masters are down
docker exec agl-mysql-failover /scripts/failover-monitor.sh health
```

#### 1.2 Check Slave Health

```bash
# Check all slave replication status
for slave in mysql-slave-1 mysql-slave-2; do
  echo "=== $slave ==="
  docker exec agl-$slave mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS\G" | \
    grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
done
```

#### 1.3 Assess Impact

```bash
# Check application error logs
docker logs agl-hostman-app-blue-1 --tail 100 | grep -i "database\|mysql\|connection"

# Check current connections
docker exec agl-proxysql mysql -h 127.0.0.1 -P 6080 -u admin -padmin -e "
  SELECT hostname, status, Queries, Bytes_data_sent, Bytes_data_recv
  FROM stats_mysql_connection_pool
  WHERE hostgroup_id IN (10, 20);
"
```

### 2. Immediate Response (Minutes 2-5)

#### 2.1 Automatic Failover (Preferred)

If failover monitor is running, it should automatically:
1. Promote healthiest slave to master
2. Update ProxySQL configuration
3. Send alerts

**Verify failover completed:**

```bash
# Check failover state
docker exec agl-mysql-failover /scripts/failover-monitor.sh status

# Check which node is now master
docker exec agl-proxysql mysql -h 127.0.0.1 -P 6080 -u admin -padmin -e "
  SELECT hostname, hostgroup_id, status, weight
  FROM mysql_servers
  WHERE hostgroup_id=10;
"
```

#### 2.2 Manual Failover (If Automatic Fails)

```bash
# Trigger manual failover
docker exec agl-mysql-failover /scripts/failover-monitor.sh failover

# Or manually promote a slave
docker exec agl-mysql-slave-1 mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
  STOP SLAVE;
  RESET SLAVE ALL;
  SET GLOBAL read_only = OFF;
  SET GLOBAL super_read_only = OFF;
"

# Update ProxySQL to route writes to new master
mysql -h localhost -P 6080 -u admin -padmin <<EOF
-- Update master to new host
UPDATE mysql_servers SET hostname='mysql-slave-1' WHERE hostgroup_id=10 AND hostname='mysql-master';

-- Move old master to read hostgroup
UPDATE mysql_servers SET hostgroup_id=20 WHERE hostname='mysql-master';

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
EOF
```

#### 2.3 Verify Application Connectivity

```bash
# Test application database connection
docker exec agl-hostman-app-blue-1 php artisan tinker --execute="
  \DB::connection('default')->select(DB::raw('SELECT 1'));
  echo 'Database connection successful';
"

# Check application health
curl -f http://localhost/health || echo "Application health check failed"
```

### 3. Recovery Operations (Minutes 5-30)

#### 3.1 Diagnose Root Cause

```bash
# Check master logs
docker logs agl-mysql-master --tail 500

# Check system resources
docker stats agl-mysql-master --no-stream

# Check disk space
df -h /srv/mysql/master
```

**Common Causes:**
- Out of memory/disk
- Network issues
- Corrupted data files
- Hardware failure

#### 3.2 Repair or Replace Master

**Option A: Quick Repair**

```bash
# Restart master container
docker restart agl-mysql-master

# Wait for startup
docker logs agl-mysql-master -f
```

**Option B: Data Recovery**

```bash
# If data corruption suspected, restore from latest backup
docker exec agl-mysql-backup /scripts/restore.sh restore /backups/full/latest

# Or rebuild from slave
docker exec agl-mysql-slave-1 mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" \
  --all-databases --single-transaction --quick --lock-tables=false \
  | docker exec -i agl-mysql-master mysql -u root -p"${MYSQL_ROOT_PASSWORD}"
```

**Option C: Container Replacement**

```bash
# Remove failed container
docker rm -f agl-mysql-master

# Recreate from image
docker compose -f docker-compose.mysql-ha.yml up -d mysql-master
```

#### 3.3 Reconfigure Replication

Once old master is repaired:

```bash
# Configure old master as slave to new master
docker exec agl-mysql-master /scripts/setup-replication.sh reset
docker exec agl-mysql-master /scripts/setup-replication.sh init
```

### 4. Failback Procedure (When Ready)

**Warning: Failback involves downtime. Schedule during maintenance window.**

#### 4.1 Pre-Failback Checklist

- [ ] Original master repaired and verified
- [ ] Replication from new master to old master working
- [ ] Application tested on current topology
- [ ] Maintenance window approved
- [ ] Stakeholders notified

#### 4.2 Execute Failback

```bash
# 1. Stop all application writes
docker exec agl-proxysql mysql -h 127.0.0.1 -P 6080 -u admin -padmin -e "
  INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply)
  VALUES (1000, 1, '^.*', 10, 1);
  LOAD MYSQL QUERY RULES TO RUNTIME;
"

# 2. Verify replication caught up
docker exec agl-mysql-master mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS" | grep Seconds_Behind_Master

# 3. Promote original master
docker exec agl-mysql-master mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
  STOP SLAVE;
  RESET SLAVE ALL;
  SET GLOBAL read_only = OFF;
  SET GLOBAL super_read_only = OFF;
"

# 4. Update ProxySQL configuration
mysql -h localhost -P 6080 -u admin -padmin <<EOF
UPDATE mysql_servers SET hostname='mysql-master' WHERE hostgroup_id=10;
UPDATE mysql_servers SET hostname='mysql-slave-1' WHERE hostgroup_id=20 AND hostname='mysql-slave-1';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
EOF

# 5. Remove temporary read-only rule
mysql -h localhost -P 6080 -u admin -padmin -e "
  DELETE FROM mysql_query_rules WHERE rule_id=1000;
  LOAD MYSQL QUERY RULES TO RUNTIME;
  SAVE MYSQL QUERY RULES TO DISK;
"

# 6. Reset failover state
docker exec agl-mysql-failover /scripts/failover-monitor.sh reset
```

#### 4.3 Verify Failback

```bash
# Test write operations
docker exec agl-hostman-app-blue-1 php artisan tinker --execute="
  \DB::connection('default')->table('test_failback')->insert(['key' => 'test', 'value' => now()]);
"

# Verify replication to slaves
docker exec agl-mysql-slave-1 mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT * FROM test_failback"

# Check replication lag
docker exec agl-mysql-failover /scripts/failover-monitor.sh health
```

## Communication Template

### Initial Alert (Automatic)

```
🚨 CRITICAL: MySQL Master Failure Detected

Status: Master is DOWN
Action: Automatic failover in progress
Expected RTO: 5 minutes

Current State:
- Master: mysql-master - UNREACHABLE
- Failover Monitor: RUNNING
- Auto-Failover: ENABLED

Updates in: #infrastructure-alerts
```

### Failure Resolved

```
✅ RESOLVED: MySQL Master Failure Recovered

Time to Resolution: X minutes
Action Taken: Automatic failover to mysql-slave-1

Root Cause: [Brief description]
Preventive Actions: [What will prevent recurrence]

Current Topology:
- Master: mysql-slave-1 (promoted)
- Slave 1: mysql-slave-2
- Old Master: mysql-master (offline, being repaired)

Next Steps:
- [ ] Repair original master
- [ ] Reconfigure as slave
- [ ] Schedule failback
```

## Post-Incident Review

### Questions to Answer

1. Why did the master fail?
2. Was automatic failover successful?
3. What was the actual RTO/RPO?
4. Could this have been prevented?
5. What changes are needed?

### Improvements to Consider

| Area | Finding | Action | Owner | Due Date |
|-------|----------|--------|---------|-----------|
| Monitoring | Detection took X seconds | Tune thresholds | Infra Team | TBD |
| Failover | Automatic failover worked/didn't work | [Action] | Infra Team | TBD |
| Documentation | Runbook was accurate/inaccurate | [Action] | Docs Team | TBD |

## Related Runbooks

- [Replication Issues](RUNBOOK-REPLICATION.md)
- [Performance Troubleshooting](PERFORMANCE-TUNING.md)
- [Disaster Recovery](DISASTER-RECOVERY.md)

## References

- [MySQL Replication Documentation](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [ProxySQL Configuration](https://www.proxysql.com/documentation/)
- [Internal Architecture](MYSQL-HA-IMPLEMENTATION.md)

---

**Runbook Version**: 1.0.0
**Last Updated**: 2026-02-11
**Maintainer**: AGL Infrastructure Team
