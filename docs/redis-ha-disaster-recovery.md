# Redis High Availability - Disaster Recovery Runbook

## Overview

This runbook provides procedures for handling Redis HA failures and disaster recovery scenarios for AGL Hostman.

**Target RTO:** 5 minutes
**Target RPO:** 1 second (synchronous replication potential)

## Architecture

```
                    +------------------+
                    |  Application     |
                    +---------+--------+
                              |
                    +---------v--------+
                    |  Redis Sentinel  | (x3 for quorum)
                    +---------+--------+
                              |
          +-------------------+-------------------+
          |                   |                   |
+---------v--------+ +--------v--------+ +--------v--------+
| Redis Master    | | Redis Slave 1   | | Redis Slave 2   |
| (Read-Write)   | | (Read-Only)     | | (Read-Only)     |
+-----------------+ +-----------------+ +-----------------+
```

## Cluster Configuration

| Component | Port | Purpose |
|-----------|-------|---------|
| Redis Master | 6379 | Primary read-write node |
| Redis Slave 1 | 6380 | Hot standby + read scaling |
| Redis Slave 2 | 6381 | Hot standby + read scaling |
| Redis Slave 3 | 6382 | Hot standby + read scaling |
| Sentinel 1 | 26379 | Failover coordinator |
| Sentinel 2 | 26380 | Failover coordinator |
| Sentinel 3 | 26381 | Failover coordinator |

## Pre-Failure Checklist

### Daily Monitoring

```bash
# Check cluster health
./infrastructure/scripts/redis-health-monitor.sh json

# Expected output: "healthy": true
```

### Weekly Verification

```bash
# Check replication lag
redis-cli -p 26379 SENTINEL slaves aglmaster | grep lag=

# Verify all sentinels agree
redis-cli -p 26379 SENTINEL sentinels aglmaster
```

### Monthly Failover Test

```bash
# Automated failover test
./infrastructure/scripts/redis-sentinel-init.sh test

# Verify automatic failover completes in < 30 seconds
```

## Disaster Scenarios

### Scenario 1: Master Failure (Automatic Failover)

**Symptoms:**
- Application errors with "connection refused" to master
- Sentinel alerts indicate master down
- One slave promoted to master

**Recovery Steps (Automatic):**

1. **Sentinel detects failure** (within 5 seconds)
2. **Sentinel agrees on failover** (quorum of 2)
3. **Slave promotion** (within 10 seconds)
4. **Application reconnection** (automatic via Sentinel)

**Verification:**

```bash
# Check current master
redis-cli -p 26379 SENTINEL get-master-addr-by-name aglmaster

# Check cluster status
docker compose -f docker/docker-compose.redis-ha.yml ps

# Verify application connectivity
redis-cli -h <new-master> -p 6379 -a <password> PING
```

**RTO:** < 30 seconds
**RPO:** < 1 second

**Post-Failover Actions:**

1. Investigate failed master root cause
2. Fix and rejoin as slave
3. Monitor replication lag
4. Update incident report

---

### Scenario 2: All Sentinels Down

**Symptoms:**
- No failover coordination
- Manual intervention required
- Master failure = service outage

**Recovery Steps:**

```bash
# 1. Start all sentinel containers
docker start redis-ha-sentinel-1 redis-ha-sentinel-2 redis-ha-sentinel-3

# 2. Verify sentinels discovered each other
redis-cli -p 26379 SENTINEL sentinels aglmaster

# 3. Check master is correctly identified
redis-cli -p 26379 SENTINEL master aglmaster

# 4. Test manual failover
redis-cli -p 26379 SENTINEL ckquorum aglmaster
```

**RTO:** 2 minutes

---

### Scenario 3: Network Partition (Split Brain)

**Symptoms:**
- Multiple masters exist
- Data inconsistency
- Applications confused

**Prevention:**

- Sentinel requires quorum (2 of 3)
- Replication uses async but with conflict detection
- Network timeout configured (5 seconds)

**Recovery Steps:**

```bash
# 1. Identify partition cause
docker network inspect redis-ha

# 2. Stop all writes to old master
redis-cli -h <old-master> -a <password> CLIENT PAUSE

# 3. Promote correct master via Sentinel
redis-cli -p 26379 SENTINEL failover aglmaster

# 4. Rejoin other partition as slave
redis-cli -h <rejoining-node> -a <password> REPLICAOF <new-master> 6379

# 5. Verify full resync
redis-cli -p 26379 SENTINEL slaves aglmaster
```

**RTO:** 5-10 minutes

---

### Scenario 4: Data Corruption

**Symptoms:**
- Redis won't start
- AOF/RDB files corrupted
- Keys missing or wrong values

**Recovery Steps:**

```bash
# 1. Stop affected container
docker stop redis-ha-master

# 2. Check backup
ls -lh /var/lib/redis/master/dump.rdb

# 3. Restore from backup
docker run --rm -v redis-ha-master-data:/data \
  -v /backups:/backup alpine:latest \
  sh -c "cp /backup/dump-YYYYMMDD.rdb /data/dump.rdb"

# 4. Start container
docker start redis-ha-master

# 5. Verify data integrity
redis-cli -a <password> DBSIZE
redis-cli -a <password> --scan --count 1000 | wc -l

# 6. Trigger full resync from master (if slave)
redis-cli -h <slave> -a <password> REPLICAOF <master> 6379
```

**RTO:** 10 minutes
**RPO:** Up to last backup (use AOF for <1s RPO)

---

### Scenario 5: Complete Data Center Loss

**Symptoms:**
- All nodes inaccessible
- No Sentinel quorum
- Full service outage

**Recovery Steps:**

```bash
# 1. Provision new environment (Terraform)
cd infrastructure/terraform
terraform apply -var="environment=dr"

# 2. Deploy Redis HA stack
cd /mnt/overpower/apps/dev/agl/agl-hostman
./infrastructure/scripts/redis-sentinel-init.sh deploy

# 3. Restore from off-site backup
aws s3 cp s3://backups/redis/dump-latest.rdb /tmp/dump.rdb
docker cp /tmp/dump.rdb redis-ha-master:/data/dump.rdb

# 4. Restart with restored data
docker restart redis-ha-master

# 5. Update DNS/load balancer
# Update application .env with new Redis endpoints

# 6. Verify application connectivity
curl -f http://app:8080/health || exit 1
```

**RTO:** 30-60 minutes
**RPO:** Up to last off-site backup

---

## Backup and Restore

### Backup Strategy

**RDB Snapshots (Point-in-Time):**
```bash
# Trigger manual snapshot
redis-cli -a <password> BGSAVE

# Wait for completion
redis-cli -a <password> LASTSAVE

# Backup RDB file
cp /var/lib/redis/master/dump.rdb /backups/dump-$(date +%Y%m%d_%H%M%S).rdb
```

**AOF (Append-Only File - Better RPO):**
```bash
# AOF is enabled by default
appendonly yes

# AOF rewrite for compaction
redis-cli -a <password> BGREWRITEAOF

# Backup AOF file
cp /var/lib/redis/master/appendonly.aof /backups/aof-$(date +%Y%m%d_%H%M%S).aof
```

**Automated Backup Script:**

```bash
#!/bin/bash
# /etc/cron.daily/redis-backup

BACKUP_DIR="/backups/redis"
RETENTION_DAYS=7
REDIS_PASSWORD="${REDIS_PASSWORD}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Trigger snapshot
redis-cli -a "$REDIS_PASSWORD" BGSAVE

# Wait for completion
while redis-cli -a "$REDIS_PASSWORD" LASTCHANGE | grep -q -E "^-1$"; do
    sleep 1
done

# Copy RDB
docker cp redis-ha-master:/data/dump.rdb \
    "$BACKUP_DIR/dump-$(date +%Y%m%d).rdb"

# Upload to S3
aws s3 cp "$BACKUP_DIR/dump-$(date +%Y%m%d).rdb \
    s3://backups/redis/dump-$(date +%Y%m%d).rdb

# Cleanup old backups
find "$BACKUP_DIR" -name "dump-*.rdb" -mtime +$RETENTION_DAYS -delete
```

### Restore Procedure

**From RDB Backup:**

```bash
# 1. Stop container
docker stop redis-ha-master

# 2. Copy backup to data volume
docker cp /backups/dump-20250211.rdb \
    redis-ha-master:/data/dump.rdb

# 3. Start container
docker start redis-ha-master

# 4. Verify
redis-cli -a <password> DBSIZE
```

**From AOF Backup:**

```bash
# 1. Stop container
docker stop redis-ha-master

# 2. Copy AOF backup
docker cp /backups/aof-20250211.aof \
    redis-ha-master:/data/appendonly.aof

# 3. Start container (Redis will replay AOF)
docker start redis-ha-master
```

---

## Monitoring Alerts

### Alert Thresholds

| Metric | Warning | Critical | Action |
|---------|----------|-----------|--------|
| Master down | N/A | Immediate | Auto failover |
| Replication lag | 5s | 30s | Check network, restart slave |
| Memory usage | 80% | 95% | Add memory, evict keys |
| Sentinel count | 2 | 1 | Restart sentinels |
| Quorum lost | N/A | Immediate | Add sentinels |

### Monitoring Commands

```bash
# Real-time monitoring
watch -n 5 './infrastructure/scripts/redis-health-monitor.sh json'

# Sentinel status
redis-cli -p 26379 SENTINEL master aglmaster

# Slave status
redis-cli -p 26379 SENTINEL slaves aglmaster

# Replication info
redis-cli -a <password> INFO replication

# Slow log
redis-cli -a <password> SLOWLOG GET 10
```

---

## Connection Pooling for Laravel

### Configuration

```php
// config/database.php

'redis' => [
    'client' => env('REDIS_CLIENT', 'predis'),
    'options' => [
        'prefix' => env('REDIS_PREFIX', 'agl_'),
        'exceptions' => true,
    ],

    'default' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', 0),
        'pool' => [
            'min_connections' => 5,
            'max_connections' => 100,
            'connect_timeout' => 5.0,
            'wait_timeout' => 5.0,
            'heartbeat' => 60.0,
            'max_idle_time' => 300.0,
        ],
    ],

    // Sentinel configuration
    'sentinel' => [
        'host' => env('REDIS_SENTINEL_HOST', '127.0.0.1'),
        'port' => env('REDIS_SENTINEL_PORT', '26379'),
        'master_name' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),
        'options' => [
            'replication' => true,
            'retry_interval' => 100, // ms
            'read_timeout' => 2.0, // seconds
        ],
    ],
],
```

### Sentinel Client Configuration

```php
// config/cache.php (use Sentinel for cache)

'redis' => [
    'driver' => 'redis',
    'connection' => 'sentinel', // Use Sentinel connection
    'lock_connection' => 'sentinel',
],
```

---

## Health Check Endpoint

Add to Laravel routes for external monitoring:

```php
// routes/health.php

Route::get('/health/redis', function () {
    try {
        $redis = Redis::connection();
        $ping = $redis->ping();
        $info = $redis->info('replication');

        return response()->json([
            'status' => 'healthy',
            'role' => $info['role'] ?? 'unknown',
            'connected_slaves' => $info['connected_slaves'] ?? 0,
            'master_link_status' => $info['master_link_status'] ?? 'unknown',
            'timestamp' => now()->toIso8601String(),
        ], 200);
    } catch (\Exception $e) {
        return response()->json([
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
            'timestamp' => now()->toIso8601String(),
        ], 503);
    }
});
```

---

## Emergency Contacts

| Role | Name | Contact |
|-------|------|---------|
| Database Lead | [Name] | [Email/Phone] |
| DevOps Lead | [Name] | [Email/Phone] |
| On-Call Engineer | [Name] | [Email/Phone] |

---

## Testing Checklist

### Weekly
- [ ] Check cluster health
- [ ] Verify replication lag < 5s
- [ ] Review slow log
- [ ] Check memory usage

### Monthly
- [ ] Test automatic failover
- [ ] Verify backup integrity
- [ ] Test restore from backup
- [ ] Update runbook if needed

### Quarterly
- [ ] Full disaster recovery drill
- [ ] Load test cluster
- [ ] Review and update RTO/RPO targets
- [ ] Security audit of Redis access
