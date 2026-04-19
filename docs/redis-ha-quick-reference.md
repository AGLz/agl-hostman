# Redis High Availability - Quick Reference

## Architecture Overview

```
                    +------------------+
                    |  Application     |
                    |  (Laravel)       |
                    +---------+--------+
                              |
                    +---------v--------+
                    |  Redis Sentinel  | (x3 for quorum)
                    |  Failover Coord  |
                    +---------+--------+
                              |
          +-------------------+-------------------+
          |                   |                   |
+---------v--------+ +--------v--------+ +--------v--------+
| Redis Master    | | Redis Slave 1   | | Redis Slave 2   |
| (Read-Write)   | | (Read-Only)     | | (Read-Only)     |
| Port: 6379     | | Port: 6380      | | Port: 6381      |
+-----------------+ +-----------------+ +-----------------+
          |                   |                   |
          +-------------------+-------------------+
                              |
                    +---------v--------+
                    | Redis Slave 3    |
                    | (Read-Only)      |
                    | Port: 6382       |
                    +------------------+
```

## Quick Start

### 1. Deploy Redis HA Cluster

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman

# Generate strong password
export REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')

# Deploy cluster
./infrastructure/scripts/redis-sentinel-init.sh deploy
```

### 2. Verify Deployment

```bash
# Check cluster status
./infrastructure/scripts/redis-sentinel-init.sh status

# Check health
./infrastructure/scripts/redis-health-monitor.sh check

# Get JSON status
./infrastructure/scripts/redis-health-monitor.sh json
```

### 3. Connect from Laravel

Update `.env`:

```env
REDIS_SENTINEL_ENABLED=true
REDIS_SENTINEL_MASTER=aglmaster
REDIS_SENTINEL_HOST=127.0.0.1
REDIS_SENTINEL_PORT=26379
REDIS_PASSWORD=your_generated_password
```

## Container Ports

| Container | Internal Port | External Port | Purpose |
|-----------|---------------|----------------|----------|
| redis-master | 6379 | 6379 | Master (RW) |
| redis-slave-1 | 6379 | 6380 | Slave 1 (RO) |
| redis-slave-2 | 6379 | 6381 | Slave 2 (RO) |
| redis-slave-3 | 6379 | 6382 | Slave 3 (RO) |
| redis-sentinel-1 | 26379 | 26379 | Sentinel 1 |
| redis-sentinel-2 | 26379 | 26380 | Sentinel 2 |
| redis-sentinel-3 | 26379 | 26381 | Sentinel 3 |
| redis-exporter | 9121 | 9121 | Prometheus Metrics |

## Redis CLI Commands

### Master Operations

```bash
# Connect to master
redis-cli -h localhost -p 6379 -a $REDIS_PASSWORD

# Check replication status
redis-cli -p 6379 -a $REDIS_PASSWORD INFO replication

# Check memory
redis-cli -p 6379 -a $REDIS_PASSWORD INFO memory

# Slow log
redis-cli -p 6379 -a $REDIS_PASSWORD SLOWLOG GET 10
```

### Sentinel Operations

```bash
# Check master address
redis-cli -p 26379 SENTINEL get-master-addr-by-name aglmaster

# Check master status
redis-cli -p 26379 SENTINEL master aglmaster

# Check slaves
redis-cli -p 26379 SENTINEL slaves aglmaster

# Check sentinels
redis-cli -p 26379 SENTINEL sentinels aglmaster

# Manual failover
redis-cli -p 26379 SENTINEL failover aglmaster
```

## Failover Testing

### Test Automatic Failover

```bash
# Run the test script
./infrastructure/scripts/redis-sentinel-init.sh test
```

### Manual Failover

```bash
# Trigger manual failover
redis-cli -p 26379 SENTINEL failover aglmaster

# Watch failover in real-time
watch -n 1 'redis-cli -p 26379 SENTINEL get-master-addr-by-name aglmaster'
```

## Health Monitoring

### Continuous Monitoring

```bash
# Run continuous health monitor
./infrastructure/scripts/redis-health-monitor.sh monitor

# With custom interval
CHECK_INTERVAL=60 ./infrastructure/scripts/redis-health-monitor.sh monitor
```

### Alert Configuration

```bash
# Set up webhook alerts
export ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK"

# Set up email alerts
export ALERT_EMAIL="ops@example.com"

# Run with alerts
ALERT_WEBHOOK=$WEBHOOK ALERT_EMAIL=$EMAIL \
  ./infrastructure/scripts/redis-health-monitor.sh monitor
```

## Backup and Restore

### Backup

```bash
# Trigger RDB snapshot
docker exec redis-ha-master redis-cli -a $REDIS_PASSWORD BGSAVE

# Wait for completion
docker exec redis-ha-master redis-cli -a $REDIS_PASSWORD LASTSAVE

# Copy backup
docker cp redis-ha-master:/data/dump.rdb \
  ./backups/redis/dump-$(date +%Y%m%d_%H%M%S).rdb
```

### Restore

```bash
# Stop container
docker stop redis-ha-master

# Restore backup
docker cp ./backups/redis/dump-20250211.rdb \
  redis-ha-master:/data/dump.rdb

# Start container
docker start redis-ha-master
```

## Common Operations

### Flush Cache (Careful!)

```bash
# Flush current database
redis-cli -p 6379 -a $REDIS_PASSWORD FLUSHDB

# Flush all databases
redis-cli -p 6379 -a $REDIS_PASSWORD FLUSHALL
```

### Key Management

```bash
# Count keys
redis-cli -p 6379 -a $REDIS_PASSWORD DBSIZE

# Find keys by pattern
redis-cli -p 6379 -a $REDIS_PASSWORD --scan --pattern "cache:*"

# Delete keys by pattern
redis-cli -p 6379 -a $REDIS_PASSWORD --scan --pattern "cache:*" | \
  xargs redis-cli -p 6379 -a $REDIS_PASSWORD DEL
```

### Laravel Specific

```bash
# Clear Laravel cache
redis-cli -p 6379 -a $REDIS_PASSWORD --scan --pattern "laravel_cache*" | \
  xargs redis-cli -p 6379 -a $REDIS_PASSWORD DEL

# Clear Horizon queues
redis-cli -p 6379 -a $REDIS_PASSWORD --scan --pattern "queues:*" | \
  xargs redis-cli -p 6379 -a $REDIS_PASSWORD DEL

# Clear sessions
redis-cli -p 6379 -a $REDIS_PASSWORD --scan --pattern "laravel_sessions*" | \
  xargs redis-cli -p 6379 -a $REDIS_PASSWORD DEL
```

## Troubleshooting

### Master Won't Start

```bash
# Check logs
docker logs redis-ha-master

# Check data volume permissions
docker exec redis-ha-master ls -la /data

# Restart with fresh data
docker compose -f docker/docker-compose.redis-ha.yml down -v
docker compose -f docker/docker-compose.redis-ha.yml up -d
```

### Replication Lag

```bash
# Check lag
redis-cli -p 26379 SENTINEL slaves aglmaster | grep lag=

# Resync slave
redis-cli -h localhost -p 6380 -a $REDIS_PASSWORD REPLICAOF redis-master 6379
```

### Sentinel Issues

```bash
# Check sentinel logs
docker logs redis-ha-sentinel-1

# Reset sentinel state
docker exec redis-ha-sentinel-1 redis-cli -p 26379 SENTINEL RESET aglmaster

# Force sentinel to check master
docker exec redis-ha-sentinel-1 redis-cli -p 26379 SENTINEL ckquorum aglmaster
```

### Memory Issues

```bash
# Check memory fragmentation
redis-cli -p 6379 -a $REDIS_PASSWORD MEMORY STATS

# Trigger defragmentation
redis-cli -p 6379 -a $REDIS_PASSWORD MEMORY PURGE

# Check eviction policy
redis-cli -p 6379 -a $REDIS_PASSWORD CONFIG GET maxmemory-policy
```

## Environment Variables

| Variable | Default | Description |
|-----------|----------|-------------|
| REDIS_PASSWORD | auto-generated | Redis authentication password |
| REDIS_HOST | localhost | Redis host (direct connection) |
| REDIS_PORT | 6379 | Redis port |
| REDIS_SENTINEL_ENABLED | false | Enable Sentinel for HA |
| REDIS_SENTINEL_MASTER | aglmaster | Sentinel master name |
| REDIS_SENTINEL_HOST | localhost | Sentinel host |
| REDIS_SENTINEL_PORT | 26379 | Sentinel port |
| REDIS_DB | 0 | Default database |
| REDIS_CACHE_DB | 1 | Cache database |
| REDIS_SESSION_DB | 2 | Session database |
| REDIS_QUEUE_DB | 3 | Queue database |

## Maintenance

### Weekly

```bash
# Check cluster health
./infrastructure/scripts/redis-health-monitor.sh check

# Review slow queries
redis-cli -p 6379 -a $REDIS_PASSWORD SLOWLOG GET 10
```

### Monthly

```bash
# Test failover
./infrastructure/scripts/redis-sentinel-init.sh test

# Backup verification
./infrastructure/scripts/redis-backup.sh verify
```

### Quarterly

```bash
# Full disaster recovery drill
# Follow: docs/redis-ha-disaster-recovery.md

# Update Redis version
# 1. Update image tag in docker-compose.redis-ha.yml
# 2. Rolling restart one node at a time
# 3. Verify replication after each restart
```

## References

- Full documentation: `docs/redis-ha-disaster-recovery.md`
- Init script: `infrastructure/scripts/redis-sentinel-init.sh`
- Health monitor: `infrastructure/scripts/redis-health-monitor.sh`
- Sentinel configs: `infrastructure/redis-sentinel/`

## Support

| Issue | Command |
|--------|----------|
| Cluster status | `./infrastructure/scripts/redis-sentinel-init.sh status` |
| Health check | `./infrastructure/scripts/redis-health-monitor.sh json` |
| View logs | `docker logs redis-ha-<container>` |
| Restart cluster | `docker compose -f docker/docker-compose.redis-ha.yml restart` |
| Stop cluster | `docker compose -f docker/docker-compose.redis-ha.yml down` |
