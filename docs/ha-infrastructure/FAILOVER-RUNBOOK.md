# AGL Hostman - Failover Runbook

## Purpose

This runbook provides step-by-step procedures for handling various failure scenarios in the AGL Hostman High Availability infrastructure.

## Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| DevOps Lead | [Name] | [Phone/Slack] |
| DBA Lead | [Name] | [Phone/Slack] |
| Engineering Manager | [Name] | [Phone/Slack] |

## Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| SEV-1 | Complete service outage | 15 min |
| SEV-2 | Major functionality broken | 1 hour |
| SEV-3 | Partial degradation | 4 hours |
| SEV-4 | Minor issues | 1 business day |

---

## Scenario 1: Application Node Failure

### Detection

**Symptoms**:
- Health check failing for specific app node
- Increased errors from LB
- Dashboard showing node as DOWN

**Verification**:
```bash
# Check LB stats
curl -u admin:[password] http://localhost:8404/stats; csv | grep app

# Check individual node
curl http://10.0.1.10:8080/health

# Check Docker
ssh 10.0.1.10 "docker ps"
```

### Automated Recovery

**Expected Action**:
- HAProxy automatically removes unhealthy node
- Traffic redirects to healthy nodes
- No manual intervention needed

**Timeline**:
- Detection: 10 seconds
- Removal: Immediate
- Traffic redirect: Immediate

### Manual Recovery (if automated fails)

```bash
# 1. SSH into failed node
ssh user@10.0.1.10

# 2. Check application logs
tail -f /var/log/agl-hostman/app.log

# 3. Restart Docker services
cd /var/www/agl-hostman
docker-compose restart

# 4. If persistent issue, pull latest code
git pull origin main
docker-compose pull
docker-compose up -d

# 5. Verify health
curl http://localhost:8080/health
```

### Replacement Node

If node cannot be recovered:

```bash
# 1. Provision new node via Terraform
cd /infrastructure/terraform/environments/production
terraform apply -var='app_node_count=4'

# 2. New node automatically joins LB

# 3. Decommission old node
terraform taint module.app_node.aws_instance.this[2]
terraform apply
```

---

## Scenario 2: MySQL Master Failure

### Detection

**Symptoms**:
- All application nodes show database errors
- Health checks failing
- Alerts: "MySQL master unreachable"

**Verification**:
```bash
# Check master status
mysqladmin -h 10.0.2.10 ping

# Check replication status on slave
mysql -h 10.0.2.20 -e "SHOW SLAVE STATUS\G"

# Check replication lag
mysql -h 10.0.2.20 -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
```

### Automated Failover

**Script**: `/infrastructure/scripts/mysql-failover.sh`

**Process**:
1. Verify master is down (3 consecutive checks)
2. Check slave health
3. Verify replication lag < 30 seconds
4. Stop slave replication
5. Promote slave to master
6. Update Laravel config
7. Reload PHP-FPM
8. Send alert

**Timeline**:
- Detection: 30 seconds
- Failover: 2 minutes
- App reconnection: Immediate

### Manual Failover (if automated fails)

**Step 1: Verify master is truly down**
```bash
# Try to connect
mysql -h 10.0.2.10 -u root -p

# Check from multiple nodes
# If reachable, investigate before failover
```

**Step 2: Choose best slave**
```bash
# Check all slaves
for slave in 10.0.2.20 10.0.2.21; do
  echo "Checking $slave:"
  mysql -h $slave -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
done

# Choose slave with:
# - Both IO and SQL running: Yes
# - Lowest replication lag
```

**Step 3: Stop slave and promote**
```bash
# Connect to chosen slave
mysql -h 10.0.2.20 -u root -p

# Stop replication
STOP SLAVE;

# Reset slave settings
RESET SLAVE ALL;

# Enable read-write
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;

# Verify
SHOW MASTER STATUS;
```

**Step 4: Update application**
```bash
# Update Laravel config
ssh app-node-1 "cd /var/www/agl-hostman && sed -i 's/10.0.2.10/10.0.2.20/g' config/database.php"

# Reload PHP-FPM
ssh app-node-1 "systemctl reload php-fpm"

# Verify connection
curl http://localhost:8080/api/health
```

**Step 5: Reconfigure other slaves**
```bash
# On remaining slaves
mysql -h 10.0.2.21 -u root -p

STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='10.0.2.20',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='[password]',
  MASTER_AUTO_POSITION=1;
START SLAVE;
```

**Step 6: Restore old master**
```bash
# After fixing old master, add as slave
mysql -h 10.0.2.10 -u root -p

CHANGE MASTER TO
  MASTER_HOST='10.0.2.20',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='[password]',
  MASTER_AUTO_POSITION=1;
START SLAVE;
```

---

## Scenario 3: Redis Master Failure

### Detection

**Symptoms**:
- Application errors: "Redis connection refused"
- Cache misses increasing
- Session failures

**Verification**:
```bash
# Check Redis master
redis-cli -h 10.0.3.10 ping

# Check Sentinel status
redis-cli -p 26379 SENTINEL masters

# Check current master
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

### Automated Failover

**Technology**: Redis Sentinel

**Process**:
1. Sentinels detect master failure (quorum: 2/3)
2. Leader sentinel elected
3. Best slave chosen (highest priority)
4. Slave promoted to master
5. Other slaves reconfigured
6. Applications reconnect automatically

**Timeline**:
- Detection: 5 seconds
- Failover: 10 seconds
- App reconnection: Immediate

### Manual Verification

```bash
# Check Sentinel view
redis-cli -p 26379 SENTINEL slaves mymaster

# Check new master
redis-cli -h [NEW_MASTER_IP] INFO replication

# Verify applications reconnecting
redis-cli -h [NEW_MASTER_IP] CLIENT LIST
```

### Manual Intervention (if Sentinel fails)

**Step 1: Verify master is down**
```bash
redis-cli -h 10.0.3.10 PING
# If responds, do NOT failover manually
```

**Step 2: Choose best slave**
```bash
# Check all slaves
for slave in 10.0.3.11 10.0.3.12 10.0.3.13; do
  echo "Slave $slave:"
  redis-cli -h $slave INFO replication | grep -E "role|master_host|master_link_status"
done
```

**Step 3: Promote slave**
```bash
# Connect to chosen slave
redis-cli -h 10.0.3.11

# Make it master
SLAVEOF NO ONE

# Verify
INFO replication
```

**Step 4: Update Sentinel**
```bash
# On all sentinels
redis-cli -p 26379 SENTINEL failover mymaster

# Or reset sentinel
redis-cli -p 26379 SENTINEL RESET mymaster
```

**Step 5: Update Laravel config**
```bash
# If using static Redis config
sed -i 's/10.0.3.10/10.0.3.11/g' config/database.php

# Reload PHP-FPM
systemctl reload php-fpm
```

---

## Scenario 4: Load Balancer Failure

### Detection

**Symptoms**:
- External monitoring shows site DOWN
- VIP not responding
- Internal connectivity works

**Verification**:
```bash
# Check LB status
curl http://10.0.0.11:8404/stats

# Check VIP
ip addr show | grep 10.0.0.10

# Check both LBs
for lb in 10.0.0.11 10.0.0.12; do
  echo "LB $lb:"
  ssh $lb "systemctl status haproxy"
done
```

### VIP Failover

**Technology**: Keepalived (or similar)

**Process**:
1. Master LB fails
2. Backup LB detects failure
3. VIP moves to backup
4. Traffic resumes

**Timeline**:
- Detection: 3 seconds
- VIP move: Immediate
- Traffic resume: Immediate

### Manual Recovery

```bash
# Check which LB has VIP
ip addr show

# If VIP stuck on failed LB, move manually
# On failed LB:
ip addr del 10.0.0.10/32 dev eth0

# On healthy LB:
ip addr add 10.0.0.10/32 dev eth0

# Verify
curl http://10.0.0.10:80/health
```

---

## Scenario 5: Complete Region Failure

### Detection

**Symptoms**:
- Multiple services down
- Network unreachable
- Power failure alerts

### DR Activation

**DNS Failover**:
1. Update DNS records to point to DR region
2. TTL: 300 seconds (5 minutes)
3. Propagation: Up to 5 minutes

**Process**:
```bash
# Update DNS (Route53 example)
aws route53 change-resource-record-sets \
  --hosted-zone-id [ZONE_ID] \
  --change-batch file:///dns-failover.json
```

**DR Region Status**:
- Warm standby (read-only)
- Replication lag: < 1 minute
- Activation time: 15 minutes

### Manual Steps

1. **Verify primary region is down**
   ```bash
   # Try multiple nodes
   ping 10.0.0.11
   ping 10.0.1.10
   ```

2. **Activate DR region**
   ```bash
   # Switch to read-write
   ssh dr-db-master "mysql -e 'SET GLOBAL read_only = OFF;'"

   # Update application config
   # Point all nodes to DR region
   ```

3. **Update DNS**
   ```bash
   # Lower TTL first
   # Update A records to DR IPs
   ```

4. **Monitor closely**
   ```bash
   # Check error rates
   # Monitor response times
   # Verify replication from DR to primary (when recovered)
   ```

---

## Scenario 6: Network Partition

### Detection

**Symptoms**:
- Some nodes unreachable
- Inconsistent behavior
- Split-brain scenarios

### Prevention

**Quorum Requirements**:
- Redis Sentinel: 2/3 must agree
- MySQL: Manual verification required
- Consensus: Use majority vote

### Recovery

**Step 1: Identify partition**
```bash
# Check connectivity between nodes
# Determine which partition has quorum
```

**Step 2: Isolate minority partition**
```bash
# Shut down nodes in minority
# Prevent split-brain writes
```

**Step 3: Recover majority partition**
```bash
# Ensure services are running
# Verify data consistency
```

**Step 4: Rejoin partition**
```bash
# When network healed
# Rejoin nodes as slaves
# Resync if necessary
```

---

## Post-Incident Procedures

### 1. Document Incident

Create incident report:
```markdown
# Incident Report: [INC-XXXX]

## Summary
[Brief description]

## Timeline
- [Time]: Detection
- [Time]: Response started
- [Time]: Mitigation
- [Time]: Resolution

## Root Cause
[Analysis]

## Resolution
[Actions taken]

## Preventive Measures
[Future actions]
```

### 2. Post-Mortem

Schedule post-mortem within 48 hours:
- What happened?
- Why did it happen?
- How did we respond?
- How can we prevent it?

### 3. Update Documentation

- Update this runbook
- Update architecture diagrams
- Update monitoring alerts
- Update automation scripts

### 4. Testing

Test fixes:
```bash
# Simulate failure
# Verify automated response
# Document any issues
```

---

## Useful Commands

### Health Checks

```bash
# All services
curl http://localhost:5555/health

# HAProxy stats
curl -u admin:[pass] http://localhost:8404/stats

# MySQL status
mysql -h [host] -e "SHOW STATUS LIKE 'wsrep%'"

# Redis status
redis-cli -h [host] INFO replication
```

### Log Locations

```bash
# HAProxy
/var/log/haproxy.log

# MySQL
/var/log/mysql/error.log
/var/log/mysql/slow-query.log

# Redis
/var/log/redis/redis-server.log

# Application
/var/log/agl-hostman/app.log
/var/log/agl-hostman/laravel.log
```

### Service Management

```bash
# HAProxy
systemctl status|restart|reload haproxy

# MySQL
systemctl status|restart mysql

# Redis
systemctl status|restart redis

# PHP-FPM
systemctl status|restart php-fpm
```

---

## Contact Tree

```
SEV-1 Incident
├── DevOps Lead (Primary)
├── Engineering Manager (Escalation)
└── CTO (Executive)
```

---

**Document Version**: 1.0
**Last Updated**: 2026-02-09
**Next Review**: 2026-05-09
