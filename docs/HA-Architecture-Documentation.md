# AGL Hostman - High Availability Architecture Documentation

**Document Version**: 2.0
**Last Updated**: 2026-02-11
**Classification**: Internal - Infrastructure Team
**Maintainer**: DevOps Team

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Network Architecture](#network-architecture)
4. [Component Redundancy](#component-redundancy)
5. [Service Failover Strategies](#service-failover-strategies)
6. [Data Replication & Consistency](#data-replication--consistency)
7. [Monitoring & Observability](#monitoring--observability)
8. [Disaster Recovery](#disaster-recovery)
9. [Performance & Scaling](#performance--scaling)
10. [Security & Compliance](#security--compliance)
11. [Operational Procedures](#operational-procedures)
12. [Implementation Guide](#implementation-guide)

---

## 🎯 Executive Summary

This document describes the comprehensive High Availability (HA) architecture implemented for AGL Hostman. The architecture ensures 99.9%+ uptime through redundant components, automated failover, and continuous monitoring across multiple availability zones.

### Key Objectives

- **Availability**: 99.9%+ uptime for critical services
- **Resilience**: Automatic recovery from component failures
- **Scalability**: Horizontal scaling for increased capacity
- **Maintainability**: Zero-downtime operations and maintenance
- **Performance**: Optimal response times under load

### Service Level Objectives

| Service Tier | Availability | RTO | RPO | Description |
|--------------|-------------|-----|-----|-------------|
| **Tier 1 (Critical)** | 99.95% | < 5 min | < 1 min | Database, authentication |
| **Tier 2 (Important)** | 99.9% | < 15 min | < 4 hours | Application servers |
| **Tier 3 (Standard)** | 99.0% | < 1 hour | < 24 hours | File storage, backups |
| **Tier 4 (Non-Critical)** | 95.0% | < 4 hours | < 7 days | Development, testing |

---

## 🏗️ Architecture Overview

### Design Principles

```
┌─────────────────────────────────────────────────────────────┐
│                    DESIGN PRINCIPLES                       │
├─────────────────────────────────────────────────────────────┤
│ 1. NO SINGLE POINT OF FAILURE                             │
│    - Every critical component has redundant instances      │
│    - Multi-az deployment across different data centers     │
│                                                           │
│ 2. AUTOMATIC FAILOVER                                     │
│    - Service health monitoring                              │
│    - Automated recovery without manual intervention        │
│    - Graceful degradation during failures                  │
│                                                           │
│ 3. SCALABLE DESIGN                                         │
│    - Horizontal scaling for all services                   │
│    - Load balancing across multiple instances              │
│    - Resource auto-scaling based on demand                │
│                                                           │
│ 4. DATA CONSISTENCY                                       │
│    - Synchronous replication for critical data             │
│    - Automatic failover with data integrity               │
│    - Point-in-time recovery capabilities                  │
└─────────────────────────────────────────────────────────────┘
```

### Architecture Diagram

```
                           ┌─────────────────┐
                           │   External      │
                           │   Load Balancer │
                           │   (HAProxy)     │
                           │   Round Robin   │
                           └─────────┬───────┘
                                    │
                                    ▼
        ┌───────────────────────────────────────────────────────┐
        │                   CDN & DNS                         │
        │      ┌────────────┼────────────┬────────────┐      │
        │      │            │            │            │      │
        ▼      ▼            ▼            ▼            ▼      ▼
┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
│  Edge Node │ │  Edge Node │ │  Edge Node │ │  Edge Node │
│    Zone A  │ │    Zone B  │ │    Zone C  │ │    Zone D  │
└──────┬─────┘ └──────┬─────┘ └──────┬─────┘ └──────┬─────┘
       │               │               │               │
       └───────────────┼───────────────┼───────────────┘
                       │               │
                       ▼               ▼
            ┌─────────────────┐ ┌─────────────────┐
            │   Load Balancer │ │   Load Balancer │
            │    Active-Active│ │   Standby       │
            │   Cluster (LB1) │ │   (LB2)         │
            └──────────┬──────┘ └─────────────────┘
                       │
            ┌──────────┴──────┐
            │                 │
            ▼                 ▼
    ┌─────────────────┐ ┌─────────────────┐
    │  Application    │ │  Application    │
    │  Cluster (App1) │ │  Cluster (App2) │
    │   Blue Environment│ │   Green Environment│
    └──────────┬──────┘ └─────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌────────────┐ ┌────────────┐ ┌────────────┐
│ Database   │ │ Database   │ │ Database   │
│ Master     │ │ Replica 1  │ │ Replica 2  │
│ (Write)    │ │ (Read)     │ │ (Read)     │
└──────┬─────┘ └──────┬─────┘ └────────────┘
       │              │
       └──────────────┼──────────────┐
                       │              │
                       ▼              ▼
            ┌─────────────────┐ ┌─────────────────┐
            │   Cache Cluster │ │   Cache Cluster │
            │     (Redis)     │ │     (Redis)     │
            │ Master + Slaves │ │ Master + Slaves │
            └─────────────────┘ └─────────────────┘
```

---

## 🌐 Network Architecture

### Network Topology

```
                    Internet
                      │
                  [CDN/DNS]
                      │
            ┌──────────┼──────────┐
            │          │          │
            ▼          ▼          ▼
        [Edge Router] [Edge Router] [Edge Router]
            │          │          │
            └──────────┼──────────┘
                      │
            ┌──────────┼──────────┐
            │          │          │
            ▼          ▼          ▼
        [LB Cluster] [App Cluster] [DB Cluster]
            │          │          │
            └──────────┼──────────┘
                      │
            ┌──────────┼──────────┐
            │          │          │
            ▼          ▼          ▼
        [Storage]   [Cache]     [Monitoring]
```

### Subnet Allocation

| Network | CIDR | Purpose | Services |
|---------|------|---------|----------|
| **Management** | 10.0.0.0/24 | Admin access | SSH, monitoring |
| **Load Balancer** | 10.0.1.0/24 | Traffic distribution | HAProxy, Keepalived |
| **Application** | 10.0.2.0/24 | Web servers | Nginx, PHP-FPM |
| **Database** | 10.0.3.0/24 | Data storage | MySQL, Redis |
| **Cache** | 10.0.4.0/24 | Session storage | Redis, Memcached |
| **Storage** | 10.0.5.0/24 | File storage | NFS, Ceph |
| **Monitoring** | 10.0.6.0/24 | Observability | Prometheus, Grafana |

### Security Zones

```
┌─────────────────────────────────────────────────────────────┐
│                        EDGE ZONE                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │    Internet     │  │   VPN/Tunnels   │                  │
│  │     Access      │  │   Site-to-Site  │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     DMZ / BUFFER ZONE                      │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   Load Balancer │  │    WAF/ Firewall │                  │
│  │   (HAProxy)     │  │    (ModSecurity)│                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      TRUSTED ZONE                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │  Application    │  │    Database    │  │   Monitoring ││
│  │   Servers       │  │   Servers      │  │   Systems    ││
│  └─────────────────┘  └─────────────────┘  └──────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Firewall Rules

```
# Edge Router Rules
Chain INPUT (policy DROP)
    - Allow established connections
    - Allow ICMP for monitoring
    - Allow HTTPS (443) from anywhere
    - Allow HTTP (80) for health checks

Chain FORWARD (policy DROP)
    - Allow traffic between internal zones
    - Block direct internet access from internal

# Load Balancer Rules
Chain INPUT (policy DROP)
    - Allow HAProxy management (8404)
    - Allow health checks (8080-8082)
    - Allow SSH (22) from management network

# Application Server Rules
Chain INPUT (policy DROP)
    - Allow web traffic (80, 443)
    - Allow database connections (3306)
    - Allow cache connections (6379)
    - Allow monitoring (9100-9103)
```

---

## 🔧 Component Redundancy

### 1. Load Balancer Layer (HAProxy)

#### Architecture
- **Technology**: HAProxy 2.8
- **Deployment**: 2-node active-active cluster
- **Virtual IP**: 10.0.1.10 (managed by Keepalived)
- **Health Checks**: 2-second intervals, 3 failures required

#### Configuration
```haproxy
# Global Configuration
global
    log /dev/log local0
    maxconn 4000
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

# Frontend Configuration
frontend main
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/agl.local.pem
    option httplog
    option forwardfor
    http-request set-header X-Forwarded-Proto https if { ssl_fc }

    # Load balancing algorithm
    default_backend app_servers

# Backend Configuration
backend app_servers
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server app1 10.0.2.10:8080 check inter 2000 fall 3
    server app2 10.0.2.11:8080 check inter 2000 fall 3
    server app3 10.0.2.12:8080 check inter 2000 fall 3

# Sticky sessions for admin panel
backend admin_panel
    balance source
    cookie SRV insert indirect nocache
    server app1 10.0.2.10:8080 check
    server app2 10.0.2.11:8080 check
    server app3 10.0.2.12:8080 check
```

#### High Availability Features
- **Virtual IP Failover**: Keepalived manages VIP movement
- **Connection Tracking**: Session persistence during failover
- **Health Checks**: Automatic server removal on failure
- **Rate Limiting**: Protection against DDoS attacks

#### Failover Procedure
```bash
# Check current master
ip addr show | grep 10.0.1.10

# Force failover if needed
systemctl stop keepalived
systemctl start keepalived

# Verify failover
curl http://10.0.1.10/health
```

### 2. Application Layer (Laravel/PHP-FPM)

#### Architecture
- **Technology**: Docker containers with PHP-FPM
- **Deployment**: Blue-green deployment strategy
- **Scaling**: Horizontal pod autoscaling (HPA)
- **Environment**: Stateless application design

#### Container Configuration
```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    image: agl/laravel:latest
    restart: unless-stopped
    environment:
      - APP_ENV=production
      - DB_HOST=mysql-master
      - REDIS_HOST=redis-master
    volumes:
      - /shared/code:/var/www/html
      - /shared/logs:/var/log/nginx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

#### Deployment Strategy
```
┌─────────────────────────────────────────────────────────────┐
│                    BLUE-GREEN DEPLOYMENT                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PRODUCTION  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│ TRAFFIC    │  Blue     │  │ Green    │  │ Yellow   │     │
│           │  (Current)│  │ (Next)   │  │ (Testing)│     │
│           └──────────┘  └──────────┘  └──────────┘     │
│                                                             │
│  Phase 1: Deploy to Yellow                                │
│  Phase 2: Test Yellow (10% traffic)                       │
│  Phase 3: Shift to Green (100% traffic)                   │
│  Phase 4: Decommission Blue                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Auto-scaling Configuration
```yaml
# k8s-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-scaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 3. Database Layer (MySQL)

#### Architecture
- **Technology**: MySQL 8.0 with GTID replication
- **Deployment**: Master-slave with 3 nodes
- **Failover**: Orchestrator automated failover
- **Backup**: Continuous binlog shipping

#### Topology
```
MySQL Master (Write)
    ↓ GTID Replication
MySQL Slave 1 (Read)
    ↘
MySQL Slave 2 (Read)
```

#### Configuration
```ini
# /etc/mysql/mysql.conf.d/replication.cnf
[mysqld]
# Replication settings
server-id = 1
log-bin = /var/log/mysql/mysql-bin
log-bin-index = /var/log/mysql/mysql-bin.index
binlog-format = ROW
sync-binlog = 1
gtid-mode = ON
enforce-gtid-consistency = ON

# Semi-synchronous replication
plugin-load = rpl_semi_sync_master.so
rpl_semi_sync_master_enabled = 1
rpl_semi_sync_master_timeout = 1000

# Performance optimization
innodb_buffer_pool_size = 4G
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
```

#### Failover Automation
```python
#!/usr/bin/env python3
# orchestrator_failover.py
import subprocess
import time

def check_master_status():
    try:
        result = subprocess.run(
            ["mysql", "-h", "10.0.3.10", "-u", "monitor", "-p'password'",
             "-e", "SHOW MASTER STATUS"],
            capture_output=True, text=True
        )
        return result.returncode == 0
    except:
        return False

def trigger_failover():
    if not check_master_status():
        print("Master down, triggering failover...")
        subprocess.run(["orchestrator", "-c", "failover"])
        return True
    return False

if __name__ == "__main__":
    trigger_failover()
```

### 4. Cache Layer (Redis)

#### Architecture
- **Technology**: Redis 7 with Sentinel
- **Deployment**: Master-slave with 3 Sentinels
- **Persistence**: AOF + RDB snapshots
- **Memory Management**: LRU eviction policy

#### Configuration
```redis
# redis.conf
port 6379
bind 10.0.4.10
protected-mode no
tcp-backlog 511

# Persistence
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Memory management
maxmemory 4gb
maxmemory-policy allkeys-lru

# Replication
replica-serve-stale-data no
replica-read-only yes

# Security
requirepass "redis-password"
rename-command CONFIG ""
rename-command FLUSHALL ""
rename-command FLUSHDB ""
```

#### Sentinel Configuration
```redis
# sentinel.conf
port 26379
bind 10.0.4.10 10.0.4.11 10.0.4.12
daemonize yes

# Monitor configuration
sentinel monitor mymaster 10.0.4.10 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1

# Authentication
sentinel auth-pass mymaster "redis-password"
```

#### Health Check Script
```bash
#!/bin/bash
# redis_health_check.sh
REDIS_HOST=${1:-"10.0.4.10"}
REDIS_PORT=${2:-"6379"}

# Check Redis connection
if ! redis-cli -h $REDIS_HOST -p $REDIS_PORT PING >/dev/null 2>&1; then
    echo "CRITICAL: Redis unreachable at $REDIS_HOST:$REDIS_PORT"
    exit 2
fi

# Check memory usage
MEMORY_USAGE=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT INFO memory | grep used_memory_human | awk -F':' '{print $2}')
MAX_MEMORY=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT CONFIG GET maxmemory | tail -1)

if [ "$MAX_MEMORY" != "0" ]; then
    USAGE_PERCENT=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT INFO memory | grep used_memory_percent | awk -F':' '{print $2}' | tr -d ' ')
    if [ ${USAGE_PERCENT%.*} -gt 90 ]; then
        echo "WARNING: Redis memory usage at ${USAGE_PERCENT}%"
        exit 1
    fi
fi

echo "OK: Redis healthy - Memory: $MEMORY_USAGE"
exit 0
```

### 5. Storage Layer

#### Architecture
- **Primary**: ZFS RAID-Z2 with hot spares
- **Replication**: Continuous async replication
- **Backup**: Daily snapshots, offsite sync
- **Monitoring**: SMART health checks

#### ZFS Configuration
```zfs
# Storage pool configuration
pool_name=agl-storage
vdev_type=raidz2
devices=/dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
hot_spare=/dev/sdg

# Dataset configuration
datasets=(
    "apps"
    "databases"
    "backups"
    "logs"
    "temp"
)

# ZFS properties
compression=lz4
atime=off
xattr=sa
mountpoint=/storage
```

#### Storage Monitoring
```bash
#!/bin/bash
# storage_monitor.sh

POOL="agl-storage"

# Check pool health
if ! zpool status $POOL | grep -q "state: ONLINE"; then
    echo "CRITICAL: ZFS pool $POOL is not ONLINE"
    exit 2
fi

# Check capacity
CAPACITY=$(zpool list -H -o capacity $POOL | tr -d '%')
if [ $CAPACITY -gt 90 ]; then
    echo "CRITICAL: ZFS pool at ${CAPACITY}% capacity"
    exit 2
elif [ $CAPACITY -gt 80 ]; then
    echo "WARNING: ZFS pool at ${CAPACITY}% capacity"
    exit 1
fi

# Check errors
ERRORS=$(zpool status $POOL | grep -i errors | awk '{print $NF}' | head -1)
if [ "$ERRORS" != "0" ]; then
    echo "WARNING: ZFS pool has $ERRORS errors"
    exit 1
fi

echo "OK: ZFS pool healthy - Capacity: ${CAPACITY}%"
exit 0
```

---

## 🚀 Service Failover Strategies

### 1. Load Balancer Failover

#### Detection
- **Health Checks**: 2-second intervals
- **Failure Threshold**: 3 consecutive failures
- **VIP Monitoring**: Keepalived tracks VIP availability

#### Automated Recovery
```bash
#!/bin/bash
# lb_failover.sh
VIP="10.0.1.10"
LB1="10.0.1.11"
LB2="10.0.1.12"

# Check current master
CURRENT_MASTER=$(ip addr show | grep $VIP | awk '{print $7}')

if [ "$CURRENT_MASTER" = "$LB1" ]; then
    STANDBY=$LB2
else
    STANDBY=$LB1
fi

# Force failover to standby
ssh $STANDBY "ip addr add $VIP/32 dev eth0"
ssh $STANDBY "systemctl restart keepalived"

# Verify
sleep 5
if curl -f http://$VIP/health >/dev/null 2>&1; then
    echo "SUCCESS: VIP moved to $STANDBY"
else
    echo "FAILURE: VIP failover failed"
    exit 1
fi
```

### 2. Application Failover

#### Detection
- **Health Endpoint**: `/health` returns 200
- **Process Monitoring**: Docker container health status
- **Response Time**: >5 seconds triggers alert

#### Rolling Update Procedure
```bash
#!/bin/bash
# app_rolling_update.sh

APP_NAME="app"
NAMESPACE="production"
BLUE_VERSION="1.0.0"
GREEN_VERSION="1.1.0"

# 1. Deploy new version to green
kubectl set image deployment/$APP_NAME \
    $APP_NAME=registry.example.com/$APP_NAME:$GREEN_VERSION \
    --namespace $NAMESPACE

# 2. Canary deployment (10% traffic)
kubectl set env deployment/$APP_NAME \
    CANARY_PERCENT=10 --namespace $NAMESPACE

# 3. Monitor for errors
kubectl logs -f deployment/$APP_NAME --namespace $NAMESPACE | grep -i error

# 4. If no errors, full rollout
kubectl set env deployment/$APP_NAME \
    CANARY_PERCENT=100 --namespace $NAMESPACE

# 5. Cleanup old version
kubectl rollout undo deployment/$APP_NAME --to-revision=1 --namespace $NAMESPACE
```

### 3. Database Failover

#### Manual Failover Procedure
```bash
#!/bin/bash
# db_manual_failover.sh

MASTER_HOST="10.0.3.10"
SLAVE_HOST="10.0.3.20"
NEW_MASTER="10.0.3.21"

# Step 1: Verify master is down
if mysql -h $MASTER_HOST -u root -p'password' -e "SELECT 1" >/dev/null 2>&1; then
    echo "ERROR: Master is still reachable"
    exit 1
fi

# Step 2: Choose best slave
REPLICATION_LAG=$(mysql -h $NEW_MASTER -u root -p'password' \
    -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master" | awk '{print $2}')

if [ "$REPLICATION_LAG" -gt 300 ]; then
    echo "ERROR: Replication lag too high: $REPLICATION_LAG seconds"
    exit 1
fi

# Step 3: Promote slave to master
ssh $NEW_MASTER "mysql -u root -p'password' -e \"
    STOP SLAVE;
    RESET SLAVE ALL;
    SET GLOBAL read_only = OFF;
    SET GLOBAL super_read_only = OFF;
\""

# Step 4: Update application configuration
sed -i "s/$MASTER_HOST/$NEW_MASTER/g" /etc/app/database.conf
systemctl reload app

# Step 5: Reconfigure other slaves
ssh $SLAVE_HOST "mysql -u root -p'password' -e \"
    STOP SLAVE;
    CHANGE MASTER TO
        MASTER_HOST='$NEW_MASTER',
        MASTER_USER='repl_user',
        MASTER_PASSWORD='password',
        MASTER_AUTO_POSITION=1;
    START SLAVE;
\""

echo "SUCCESS: Failover completed - New master: $NEW_MASTER"
```

### 4. Cache Failover

#### Redis Sentinel Failover
```bash
#!/bin/bash
# redis_sentinel_failover.sh

REDIS_MASTER="10.0.4.10"
REDIS_SENTINEL="10.0.4.20"

# Check current master
CURRENT_MASTER=$(redis-cli -p 26379 -s $REDIS_SENTINEL SENTINEL get-master-addr-by-name mymaster)

# Trigger failover if needed
if ! redis-cli -h $REDIS_MASTER PING >/dev/null 2>&1; then
    echo "Master down, triggering failover..."
    redis-cli -p 26379 -s $REDIS_SENTINEL SENTINEL failover mymaster

    # Wait for failover
    sleep 10

    # Verify new master
    NEW_MASTER=$(redis-cli -p 26379 -s $REDIS_SENTINEL SENTINEL get-master-addr-by-name mymaster)
    if [ -n "$NEW_MASTER" ]; then
        echo "SUCCESS: New master: $NEW_MASTER"
        exit 0
    else
        echo "ERROR: Failover failed"
        exit 1
    fi
fi
```

### 5. Network Partition Handling

#### Detection
- **Heartbeat Monitoring**: Lost heartbeat indicates partition
- **Quorum Requirements**: Majority must agree on state
- **Split-brain Prevention**: Prevents simultaneous writes

#### Recovery Procedure
```bash
#!/bin/bash
# network_partition_recovery.sh

QUORUM=2
TOTAL_NODES=3

# Check node connectivity
check_connectivity() {
    local node=$1
    ping -c 1 $node >/dev/null 2>&1
    echo $?
}

# Determine partition
nodes_healthy=0
for node in 10.0.3.10 10.0.3.20 10.0.3.21; do
    if check_connectivity $node -eq 0; then
        nodes_healthy=$((nodes_healthy + 1))
    fi
done

# Decision based on quorum
if [ $nodes_healthy -ge $QUORUM ]; then
    echo "Majority partition operational - Continue operations"
    exit 0
else
    echo "Minority partition - Shut down services to prevent split-brain"
    for node in 10.0.3.10 10.0.3.20 10.0.3.21; do
        if check_connectivity $node -eq 0; then
            ssh $node "systemctl stop mysql redis"
        fi
    done
    exit 1
fi
```

---

## 🔄 Data Replication & Consistency

### 1. MySQL Replication

#### Configuration
```ini
# Master configuration
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog-format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
binlog-do-db = agl_database
replicate-ignore-db = information_schema

# Slave configuration
[mysqld]
server-id = 2
relay-log = mysql-relay-bin
read-only = ON
replicate-do-db = agl_database
replicate-ignore-db = information_schema
```

#### Monitoring Script
```bash
#!/bin/bash
# mysql_replication_monitor.sh

MASTER="10.0.3.10"
SLAVE="10.0.3.20"

# Check replication lag
LAG=$(mysql -h $SLAVE -u root -p'password' -e \
    "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master" | awk '{print $2}')

# Check replication status
IO_RUNNING=$(mysql -h $SLAVE -u root -p'password' -e \
    "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running" | awk '{print $2}')
SQL_RUNNING=$(mysql -h $SLAVE -u root -p'password' -e \
    "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running" | awk '{print $2}')

# Alert if issues
if [ "$IO_RUNNING" != "Yes" ] || [ "$SQL_RUNNING" != "Yes" ]; then
    echo "CRITICAL: replication stopped"
    exit 2
fi

if [ "$LAG" -gt 300 ]; then
    echo "WARNING: replication lag $LAG seconds"
    exit 1
fi

echo "OK: replication healthy - lag: $LAG seconds"
exit 0
```

### 2. Redis Replication

#### Configuration
```redis
# Master configuration
port 6379
bind 10.0.4.10
replica-serve-stale-data no
replica-read-only yes
repl-diskless-sync yes
repl-diskless-sync-delay 5
save 900 1
save 300 10
save 60 10000

# Slave configuration
port 6379
bind 10.0.4.11
replicaof 10.0.4.10 6379
masterauth "password"
replica-serve-stale-data no
replica-read-only yes
```

### 3. File System Replication

#### Rsync Configuration
```bash
#!/bin/bash
# rsync_backup.sh

SOURCE="/data/apps"
DEST="backup-server:/backup/apps"
EXCLUDE="--exclude=.git --exclude=node_modules --exclude=*.log"

rsync -avz --delete \
    --bwlimit=10000 \
    $EXCLUDE \
    $SOURCE \
    $DEST

# Verify backup
rsync --dry-run --itemize-changes $SOURCE $DEST > /tmp/verify.log
CHANGES=$(grep -c "^>" /tmp/verify.log)

if [ $CHANGES -gt 0 ]; then
    echo "INFO: $CHANGES files need sync"
else
    echo "OK: backup verified"
fi
```

### 4. Consistency Checks

#### Data Integrity Verification
```bash
#!/bin/bash
# data_consistency_check.sh

# MySQL consistency check
mysql -u root -p'password' -e "
    CHECK TABLE agl_database.*;
    ANALYZE TABLE agl_database.*;
"

# Redis consistency check
redis-cli --rdb-check /var/lib/redis/dump.rdb

# File system checksum
find /data -type f -exec md5sum {} \; > /tmp/checksums.md5
md5sum -c /tmp/checksums.md5

echo "Consistency checks completed"
```

---

## 👁️ Monitoring & Observability

### 1. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   MONITORING STACK                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Metrics   │  │   Logging   │  │   Tracing   │        │
│  │(Prometheus) │  │(ELK Stack) │  │(Jaeger)     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│           │              │              │                 │
│           ▼              ▼              ▼                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Grafana                            │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │    │
│  │ │ Dashboards  │ │  Alerts    │ │  Reports    │  │    │
│  │ └─────────────┘ └─────────────┘ └─────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  Alertmanager                        │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │    │
│  │ │ PagerDuty   │ │  Email     │ │  Slack      │  │    │
│  │ └─────────────┘ └─────────────┘ └─────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Metrics Collection

#### Prometheus Configuration
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'haproxy'
    static_configs:
      - targets: ['10.0.1.11:8404', '10.0.1.12:8404']
    metrics_path: /stats
    scheme: http

  - job_name: 'mysql'
    static_configs:
      - targets: ['10.0.3.10:9100', '10.0.3.20:9100', '10.0.3.21:9100']
    metrics_path: /metrics
    scheme: http

  - job_name: 'redis'
    static_configs:
      - targets: ['10.0.4.10:9121', '10.0.4.11:9121', '10.0.4.12:9121']
    metrics_path: /metrics
    scheme: http

  - job_name: 'node'
    static_configs:
      - targets: ['10.0.2.10:9100', '10.0.2.11:9100', '10.0.2.12:9100']
    metrics_path: /metrics
    scheme: http
```

#### Alert Rules
```yaml
# alert_rules.yml
groups:
- name: system_alerts
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."

  - alert: HighCpuUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "{{ $labels.instance }} CPU usage is at {{ $value }}%."

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "{{ $labels.instance }} memory usage is at {{ $value }}%."

  - alert: MysqlReplicationLag
    expr: mysql_slave_status_seconds_behind_master > 300
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "MySQL replication lag on {{ $labels.instance }}"
      description: "{{ $labels.instance }} replication lag is {{ $value }} seconds."
```

### 3. Dashboard Examples

#### High Availability Overview
```json
{
  "dashboard": {
    "title": "High Availability Overview",
    "panels": [
      {
        "title": "System Availability",
        "type": "stat",
        "targets": [{
          "expr": "avg(up) * 100"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "green", "value": 99.9},
                {"color": "yellow", "value": 95},
                {"color": "red", "value": 0}
              ]
            }
          }
        }
      },
      {
        "title": "Database Response Time",
        "type": "graph",
        "targets": [{
          "expr": "rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])"
        }]
      }
    ]
  }
}
```

#### MySQL Replication Dashboard
```json
{
  "dashboard": {
    "title": "MySQL Replication Status",
    "panels": [
      {
        "title": "Replication Lag",
        "type": "graph",
        "targets": [{
          "expr": "mysql_slave_status_seconds_behind_master",
          "legendFormat": "{{ $labels.instance }}"
        }]
      },
      {
        "title": "Replication Health",
        "type": "singlestat",
        "targets": [{
          "expr": "mysql_slave_status_slave_io_running",
          "legendFormat": "IO Running"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "none",
            "thresholds": {
              "steps": [
                {"color": "green", "value": 1},
                {"color": "red", "value": 0}
              ]
            }
          }
        }
      }
    ]
  }
}
```

### 4. Logging Configuration

#### Filebeat Configuration
```yaml
# filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/nginx/*.log
    - /var/log/mysql/*.log
    - /var/log/redis/*.log
  fields:
    service: web
    env: production

output.elasticsearch:
  hosts: ["elasticsearch:9200"]

setup.kibana:
  host: "kibana:5601"

processors:
- add_docker_metadata:
    host: "node0"
    match: ["docker-*"]

- add_host_metadata:
  when:
    equals:
      docker.container.name: "app"
```

### 5. Alert Escalation

#### Alertmanager Configuration
```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@agl.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'ops-team@agl.local'
    subject: 'Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
        Alert: {{ .Annotations.summary }}
        Description: {{ .Annotations.description }}
        Labels: {{ .Labels }}
      {{ end }}

  webhook_configs:
  - url: 'http://pagerduty.example.com/integration'
    send_resolved: true

- name: 'critical'
  email_configs:
  - to: 'oncall@agl.local'
    subject: 'CRITICAL ALERT: {{ .GroupLabels.alertname }}'
  webhook_configs:
  - url: 'http://critical-pager.example.com'
    send_resolved: true
```

---

## 🛡️ Disaster Recovery

### 1. Recovery Strategies

#### Backup Strategy
```
3-2-1 Backup Rule:
┌─────────────────────────────────────────────────────────────┐
│ 3 copies of data:                                          │
│  1. Primary storage (production)                            │
│  2. Local backup (nightly)                                  │
│  3. Offsite backup (cloud)                                  │
│                                                             │
│ 2 different media:                                          │
│  1. Local SSD/NVMe                                           │
│  2. Cloud storage (AWS S3)                                 │
│                                                             │
│ 1 offsite copy:                                             │
│  - Daily sync to cloud                                      │
│  - Encrypted in transit and at rest                         │
└─────────────────────────────────────────────────────────────┘
```

#### Backup Schedule
```bash
#!/bin/bash
# backup_schedule.sh

# Daily backups
0 2 * * * /scripts/backup/daily_backup.sh
0 3 * * * /scripts/backup/verify_backups.sh

# Weekly backups
0 1 * * 0 /scripts/backup/weekly_backup.sh

# Monthly backups
0 2 1 * * /scripts/backup/monthly_backup.sh

# Offsite sync
0 4 * * * /scripts/backup/offsite_sync.sh

# Cleanup
0 5 * * * /scripts/backup/cleanup_old_backups.sh
```

### 2. Recovery Procedures

#### Complete System Recovery
```bash
#!/bin/bash
# full_system_recovery.sh

BACKUP_DATE="2026-02-10"
BACKUP_TYPE="full"

echo "=== Full System Recovery ==="

# 1. Verify backup integrity
echo "Step 1: Verifying backup integrity"
/backup/verify.sh --date $BACKUP_DATE --type $BACKUP_TYPE
if [ $? -ne 0 ]; then
    echo "ERROR: Backup verification failed"
    exit 1
fi

# 2. Restore system configuration
echo "Step 2: Restoring system configuration"
/backup/restore_config.sh --date $BACKUP_DATE

# 3. Restore databases
echo "Step 3: Restoring databases"
/backup/restore_databases.sh --date $BACKUP_DATE

# 4. Restore application data
echo "Step 4: Restoring application data"
/backup/restore_apps.sh --date $BACKUP_DATE

# 5. Restore user data
echo "Step 5: Restoring user data"
/backup/restore_users.sh --date $BACKUP_DATE

# 6. Verify system functionality
echo "Step 6: Verifying system functionality"
/backup/verify_system.sh --date $BACKUP_DATE

echo "=== Recovery Complete ==="
```

#### Database Recovery
```bash
#!/bin/bash
# database_recovery.sh

DB_NAME="agl_database"
BACKUP_DATE="2026-02-10"
BACKUP_TYPE="full"

# Stop database service
systemctl stop mysql

# Restore from backup
gunzip -c /backup/mysql/${DB_NAME}_${BACKUP_DATE}.sql.gz | \
    mysql -u root -p'password' $DB_NAME

# Verify integrity
mysql -u root -p'password' -e "
    CHECK TABLE ${DB_NAME}.*;
    ANALYZE TABLE ${DB_NAME}.*;
"

# Start database service
systemctl start mysql

# Check replication status
mysql -u root -p'password' -e "
    SHOW MASTER STATUS;
    SHOW SLAVE STATUS\G
"
```

### 3. Testing Procedures

#### DR Test Scenarios
```bash
#!/bin/bash
# dr_test_runner.sh

SCENARIOS=(
    "single_node_failure"
    "database_corruption"
    "complete_site_failure"
    "network_partition"
    "data_center_loss"
)

for scenario in "${SCENARIOS[@]}"; do
    echo "=== Testing $scenario ==="

    case $scenario in
        "single_node_failure")
            /tests/dr/single_node_failure.sh
            ;;
        "database_corruption")
            /tests/dr/database_corruption.sh
            ;;
        "complete_site_failure")
            /tests/dr/site_failure.sh
            ;;
        "network_partition")
            /tests/dr/network_partition.sh
            ;;
        "data_center_loss")
            /tests/dc_loss.sh
            ;;
    esac

    # Record results
    /tests/record_result.sh --scenario $scenario --status $?
done
```

### 4. Recovery Time Objectives

| Scenario | RTO | RPO | Recovery Process |
|----------|-----|-----|------------------|
| **Disk Failure** | 15 min | 0 min | Replace disk, restore from ZFS |
| **Node Failure** | 30 min | 0 min | Failover to spare node |
| **Database Master Failure** | 10 min | < 1 min | Automated failover |
| **Network Partition** | 5 min | 0 min | Manual reconfiguration |
| **Complete Site Loss** | 4 hours | < 24 hours | Cloud recovery from offsite |

---

## 📊 Performance & Scaling

### 1. Performance Baselines

#### Load Testing
```bash
#!/bin/bash
# load_test.sh

CONCURRENT_USERS=${1:-100}
DURATION=${2:-300}
TARGET_URL="https://agl.local"

# Install k6 if not present
if ! command -v k6 &> /dev/null; then
    echo "Installing k6..."
    curl -sfL https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz | tar xz --strip-components 1
    sudo mv k6 /usr/local/bin/
fi

# Run load test
echo "Starting load test with $CONCURRENT_USERS users for $DURATION seconds"
./k6 run --vus $CONCURRENT_USERS --duration ${DURATION}s -e TARGET_URL=$TARGET_URL load_test.js

# Parse results
./k6 stats --json stats.json > summary.txt
grep -E "http_req_duration|http_req_failed" summary.txt
```

#### Load Test Script (k6)
```javascript
// load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },   // Warm up
    { duration: '5m', target: 100 },  // Sustain
    { duration: '2m', target: 200 },  // Stress
    { duration: '2m', target: 500 },  // Peak
    { duration: '5m', target: 100 },  // Sustain
    { duration: '2m', target: 0 },   // Cool down
  ],
};

export default function () {
  let res = http.get(__ENV.TARGET_URL + '/');
  check(res, {
    'status was 200': (r) => r.status == 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

### 2. Auto-scaling Configuration

#### Kubernetes HPA
```yaml
# k8s-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: 1000
```

#### Cluster Autoscaler
```yaml
# cluster-autoscaler.yaml
apiVersion: autoscaling/v2beta2
kind: ClusterAutoscaler
metadata:
  name: cluster-autoscaler
spec:
  scaleDown:
    enabled: true
    delayAfterAdd: 10m
    delayAfterDelete: 10s
    delayAfterFailure: 30s
    unneededTime: 10m
  scaleDownUnneededTime: 10m
  scaleDownUtilizationThreshold: 0.5
  balanceSimilarNodeGroups: true
  expander: most-pods
  ignoreDaemonSetPersistentVolumeClaims: true
```

### 3. Performance Optimization

#### Database Optimization
```sql
-- MySQL optimizations
SET GLOBAL innodb_buffer_pool_size = 4294967296;  -- 4GB
SET GLOBAL innodb_file_per_table = ON;
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL innodb_flush_method = O_DIRECT;
SET GLOBAL innodb_buffer_pool_instances = 4;

-- Query optimization
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- Index optimization
CREATE INDEX idx_users_email ON users(email);
```

#### Application Optimization
```php
<?php
// app_optimizations.php

// Enable OPcache
opcache_reset();
opcache_compile_file('index.php');

// Database connection pooling
$db = new PDO(
    'mysql:host=mysql-master;dbname=agl_database',
    'user',
    'password',
    [
        PDO::ATTR_PERSISTENT => true,
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]
);

// Caching
$cache = new Redis();
$cache->connect('redis-master', 6379);
$cache->set('user:123', json_encode($userData), 3600);

// Connection pooling
$pool = new \Swoole\Coroutine\MySQL();
$pool->create([
    'host' => 'mysql-master',
    'port' => 3306,
    'user' => 'app_user',
    'password' => 'password',
    'database' => 'agl_database',
    'charset' => 'utf8mb4',
    'timeout' => 5,
]);
```

---

## 🔒 Security & Compliance

### 1. Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY ZONES                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PUBLIC ZONE ───────────────────────────────────────────── │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   Internet      │  │   Web Server   │                  │
│  │   Access        │  │   (Nginx)      │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                  │           │                           │
│                  ↓           ↓                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   DMZ           │  │   WAF/ Firewall │                  │
│  │   (Isolated)    │  │   (ModSecurity)│                  │
│  └─────────────────┘  └─────────────────┘                  │
│                  │           │                           │
│                  ↓           ↓                           │
│                                                             │
│  PRIVATE ZONE ──────────────────────────────────────────── │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐│
│  │   Application   │  │   Database     │  │   Cache     ││
│  │   Server        │  │   Server       │  │   Server    ││
│  └─────────────────┘  └─────────────────┘  └─────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Network Security

#### Firewall Rules
```bash
#!/bin/bash
# configure_firewall.sh

# Reset iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH from management network
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/24 -j ACCEPT

# Allow web traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow database connections from app servers
iptables -A INPUT -p tcp --dport 3306 -s 10.0.2.0/24 -j ACCEPT

# Allow cache connections from app servers
iptables -A INPUT -p tcp --dport 6379 -s 10.0.2.0/24 -j ACCEPT

# Allow monitoring
iptables -A INPUT -p tcp --dport 9100-9103 -s 10.0.6.0/24 -j ACCEPT

# Log and drop
iptables -A INPUT -j LOG --log-prefix "DROP: "
iptables -A INPUT -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### 3. Database Security

#### MySQL Security Configuration
```ini
# /etc/mysql/mysql.conf.d/security.cnf
[mysqld]
# Remove anonymous users
skip-networking

# Bind to specific IP
bind-address = 10.0.3.0/24

# SSL/TLS
ssl-ca = /etc/ssl/certs/mysql-ca.pem
ssl-cert = /etc/ssl/certs/mysql-server.pem
ssl-key = /etc/ssl/certs/mysql-server-key.pem

# Password requirements
validate_password.policy = STRONG
validate_password.length = 12

# Logging
general_log = ON
general_log_file = /var/log/mysql/mysql.log
slow_query_log = ON
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 1
```

#### Access Control
```sql
-- Create restricted user
CREATE USER 'app_user'@'10.0.2.%'
    IDENTIFIED BY 'strong_password_here'
    REQUIRE SSL;

-- Grant limited privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON agl_database.*
    TO 'app_user'@'10.0.2.%';

-- Create monitoring user
CREATE USER 'monitor'@'10.0.6.%'
    IDENTIFIED BY 'monitor_password'
    REQUIRE SSL;

GRANT PROCESS, REPLICATION CLIENT ON *.*
    TO 'monitor'@'10.0.6.%';
```

### 4. Compliance Monitoring

#### Security Scanning
```bash
#!/bin/bash
# security_scan.sh

# Run vulnerability scan
echo "Running vulnerability scan..."
nmap -sV -O 10.0.2.0/24 --open > /tmp/nmap_scan.txt

# Run compliance check
echo "Running compliance check..."
lynis system audit > /tmp/compliance_report.txt

# Check for weak passwords
echo "Checking for weak passwords..."
john --wordlist=/usr/share/wordlists/rockyou.txt /etc/shadow > /tmp/password_check.txt

# Generate report
echo "Generating security report..."
cat > /tmp/security_report.md <<EOF
# Security Scan Report

## Vulnerability Scan
$(grep -E "open|filtered" /tmp/nmap_scan.txt | head -10)

## Compliance Check
grep -E "warning|suggestion" /tmp/compliance_report.txt | head -10

## Password Security
grep -E "crack" /tmp/password_check.txt | head -5

## Next Steps
1. Address high-priority vulnerabilities
2. Update weak passwords
3. Review firewall rules
EOF

echo "Security report generated: /tmp/security_report.md"
```

---

## 🛠️ Operational Procedures

### 1. Deployment Procedures

#### Rolling Update Process
```bash
#!/bin/bash
# rolling_deployment.sh

APP_NAME="app"
NAMESPACE="production"
VERSION="1.2.0"
BLUE_GREEN="green"

# 1. Deploy new version
echo "Deploying version $VERSION to $BLUE_GREEN environment"
kubectl set image deployment/$APP_NAME \
    $APP_NAME=registry.example.com/$APP_NAME:$VERSION \
    --namespace $NAMESPACE

# 2. Wait for deployment
kubectl rollout status deployment/$APP_NAME --namespace $NAMESPACE

# 3. Run health checks
for i in {1..3}; do
    if ! kubectl exec -it deployment/$APP_NAME --namespace $NAMESPACE -- curl -f http://localhost:8080/health; then
        echo "ERROR: Health check failed"
        exit 1
    fi
    sleep 10
done

# 4. Switch traffic (if blue-green)
if [ "$BLUE_GREEN" = "green" ]; then
    echo "Switching traffic to green environment"
    # Update load balancer configuration
fi

# 5. Monitor for errors
kubectl logs -f deployment/$APP_NAME --namespace $NAMESPACE | grep -i error

echo "Deployment successful"
```

### 2. Maintenance Procedures

#### Database Maintenance
```bash
#!/bin/bash
# database_maintenance.sh

# Stop application
systemctl stop app

# Create maintenance mode
echo "MAINTENANCE" > /var/www/app/maintenance.html

# Take database backup
mysqldump -u root -p'password' --single-transaction --routines --triggers agl_database \
    | gzip > /backup/maintenance_$(date +%Y%m%d).sql.gz

# Optimize tables
mysql -u root -p'password' -e "
    USE agl_database;
    OPTIMIZE TABLE users, orders, payments;
"

# Rebuild indexes
mysql -u root -p'password' -e "
    USE agl_database;
    ANALYZE TABLE users, orders, payments;
"

# Start application
systemctl start app

# Remove maintenance mode
rm /var/www/app/maintenance.html

echo "Maintenance complete"
```

#### Cache Maintenance
```bash
#!/bin/bash
# cache_maintenance.sh

# Stop cache service
systemctl stop redis

# Clear data
rm -rf /var/lib/redis/dump.rdb
rm -rf /var/lib/redis/appendonly.aof

# Reconfigure
cp /etc/redis/redis.conf.maintenance /etc/redis/redis.conf
systemctl start redis

# Warm up cache
curl http://localhost/health
curl http://localhost/api/users
curl http://localhost/api/products

# Switch to production config
cp /etc/redis/redis.conf.production /etc/redis/redis.conf
systemctl restart redis

echo "Cache maintenance complete"
```

### 3. Incident Response

#### Incident Response Process
```bash
#!/bin/bash
# incident_response.sh

INCIDENT_ID=$1
SEVERITY=$2

# Record incident
echo "INCIDENT $INCIDENT_ID - Severity: $SEVERITY - $(date)" >> /var/incidents.log

# Notify team
case $SEVERITY in
    "CRITICAL")
        /scripts/alert/pagerduty.sh "CRITICAL: Incident $INCIDENT_ID"
        /scripts/alert/email.sh ops@agl.local "CRITICAL Incident $INCIDENT_ID"
        ;;
    "HIGH")
        /scripts/alert/slack.sh "#alerts" "HIGH: Incident $INCIDENT_ID"
        /scripts/alert/email.sh ops@agl.local "Incident $INCIDENT_ID"
        ;;
esac

# Create ticket
curl -X POST "$TICKET_API" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"Incident $INCIDENT_ID\",
        \"severity\": \"$SEVERITY\",
        \"description\": \"Automated incident report\"
    }"

echo "Incident response initiated for $INCIDENT_ID"
```

#### Post-Incident Review
```bash
#!/bin/bash
# post_incident_review.sh

INCIDENT_ID=$1
INCIDENT_DATE=$(date -d "1 week ago" +%Y%m-%d)

# Generate report
cat > /tmp/incident_report_${INCIDENT_ID}.md <<EOF
# Incident Report: $INCIDENT_ID

## Summary
Incident occurred on $(date -d "@$INCIDENT_DATE")

## Timeline
- $(date -d "@$INCIDENT_DATE + 5min") - Detection
- $(date -d "@$INCIDENT_DATE + 10min") - Response initiated
- $(date -d "@$INCIDENT_DATE + 30min") - Contained
- $(date -d "@$INCIDENT_DATE + 45min") - Resolved

## Root Cause
[Analysis of incident cause]

## Resolution Steps
[Steps taken to resolve]

## Impact
- Downtime: 30 minutes
- Users affected: 100
- Business impact: Medium

## Prevention Measures
1. [Measure 1]
2. [Measure 2]
3. [Measure 3]

## Follow-up Actions
- [ ] Update monitoring
- [ ] Improve response procedures
- [ ] Team training

EOF

# Schedule review meeting
curl -X POST "$CALENDAR_API" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"Post-Incident Review: $INCIDENT_ID\",
        \"start\": \"$(date -d "tomorrow 10:00" -Iseconds)\",
        \"attendees\": [\"ops@agl.local\", \"dba@agl.local\"]
    }"

echo "Incident report generated: /tmp/incident_report_${INCIDENT_ID}.md"
```

---

## 📖 Implementation Guide

### 1. Prerequisites

#### Hardware Requirements
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 4 cores | 8+ cores |
| **Memory** | 16 GB | 32+ GB |
| **Storage** | 500 GB SSD | 1+ TB NVMe |
| **Network** | 1 Gbps | 10+ Gbps |

#### Software Requirements
- **OS**: Ubuntu 20.04 LTS or CentOS 8
- **Docker**: 20.10+
- **Kubernetes**: 1.23+
- **MySQL**: 8.0+
- **Redis**: 6.2+
- **HAProxy**: 2.4+

### 2. Installation Steps

#### Step 1: Infrastructure Setup
```bash
#!/bin/bash
# setup_infrastructure.sh

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y docker.io kubectl haproxy keepalived mysql-server redis-server

# Start services
systemctl enable --now docker
systemctl enable --now mysql
systemctl enable --now redis
systemctl enable --now haproxy
systemctl enable --now keepalived

# Configure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3306/tcp
ufw allow 6379/tcp
ufw allow 8404/tcp
ufw enable

echo "Infrastructure setup complete"
```

#### Step 2: Database Setup
```bash
#!/bin/bash
# setup_database.sh

# Configure MySQL
cat > /etc/mysql/mysql.conf.d/replication.cnf <<EOF
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog-format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
EOF

# Restart MySQL
systemctl restart mysql

# Create replication user
mysql -u root -e "
    CREATE USER 'repl_user'@'%' IDENTIFIED BY 'repl_password';
    GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
    FLUSH PRIVILEGES;
"

# Create application database
mysql -u root -e "
    CREATE DATABASE agl_database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER 'app_user'@'%' IDENTIFIED BY 'app_password';
    GRANT ALL PRIVILEGES ON agl_database.* TO 'app_user'@'%';
    FLUSH PRIVILEGES;
"

echo "Database setup complete"
```

#### Step 3: Load Balancer Setup
```bash
#!/bin/bash
# setup_load_balancer.sh

# Configure HAProxy
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 4000
    chroot /var/lib/haproxy
    user haproxy
    group haproxy

frontend main
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/agl.local.pem
    option httplog
    option forwardfor
    default_backend app_servers

backend app_servers
    balance roundrobin
    option httpchk GET /health
    server app1 10.0.2.10:8080 check inter 2000 fall 3
    server app2 10.0.2.11:8080 check inter 2000 fall 3
    server app3 10.0.2.12:8080 check inter 2000 fall 3
EOF

# Configure Keepalived
cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_script check_haproxy {
    script "curl -f http://localhost/health"
    interval 2
    timeout 2
    rise 2
    fall 3
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    virtual_ipaddress {
        10.0.1.10/24 dev eth0
    }
    track_script {
        check_haproxy
    }
}
EOF

# Start services
systemctl restart haproxy
systemctl restart keepalived

echo "Load balancer setup complete"
```

#### Step 4: Application Setup
```bash
#!/bin/bash
# setup_application.sh

# Create Docker network
docker network create app-network

# Deploy containers
docker run -d \
    --name app1 \
    --network app-network \
    -e DB_HOST=10.0.3.10 \
    -e REDIS_HOST=10.0.4.10 \
    registry.example.com/app:latest

docker run -d \
    --name app2 \
    --network app-network \
    -e DB_HOST=10.0.3.10 \
    -e REDIS_HOST=10.0.4.10 \
    registry.example.com/app:latest

docker run -d \
    --name app3 \
    --network app-network \
    -e DB_HOST=10.0.3.10 \
    -e REDIS_HOST=10.0.4.10 \
    registry.example.com/app:latest

# Verify containers
docker ps

echo "Application setup complete"
```

### 3. Validation Procedures

#### Health Check
```bash
#!/bin/bash
# validate_deployment.sh

echo "=== Deployment Validation ==="

# Check services
services=("haproxy" "mysql" "redis" "docker")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
        exit 1
    fi
done

# Check database connectivity
if mysql -u app_user -p'app_password' -h 10.0.3.10 -e "SELECT 1"; then
    echo "✓ Database connectivity OK"
else
    echo "✗ Database connectivity failed"
    exit 1
fi

# Check cache connectivity
if redis-cli -h 10.0.4.10 PING; then
    echo "✓ Cache connectivity OK"
else
    echo "✗ Cache connectivity failed"
    exit 1
fi

# Check load balancer
if curl -f http://10.0.1.10/health; then
    echo "✓ Load balancer OK"
else
    echo "✗ Load balancer failed"
    exit 1
fi

# Check application endpoints
for i in {1..3}; do
    if curl -f http://10.0.2.$i:8080/health; then
        echo "✓ Application app$i OK"
    else
        echo "✗ Application app$i failed"
        exit 1
    fi
done

echo "=== All validations passed ==="
```

### 4. Documentation

#### Update Documentation
```bash
#!/bin/bash
# update_documentation.sh

# Generate architecture diagram
/plantuml-generator.sh > /docs/architecture.uml

# Update configuration reference
/plantuml-generator.sh --config > /docs/configuration-reference.uml

# Generate monitoring dashboards
/grafana-dashboard-generator.sh > /docs/dashboards/

# Update runbooks
/failover-generator.sh > /docs/runbooks/

echo "Documentation updated"
```

---

## 📝 Document Control

### Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-10-14 | Initial document creation | System Architect |
| 2.0 | 2026-02-11 | Complete HA architecture documentation | DevOps Team |

### Review Schedule

- **Monthly**: Architecture review
- **Quarterly**: Complete documentation review
- **Annually**: Major revision

### Related Documentation

- [Operations Manual](./operations-manual.md)
- [Disaster Recovery Runbook](./disaster-recovery-runbook.md)
- [SLA Compliance Guide](./sla-compliance-guide.md)
- [Backup Operations Guide](./backup-operations-guide.md)

---

**Document Control**:
- **Version**: 2.0
- **Status**: Active
- **Next Review**: 2026-05-11
- **Approver**: DevOps Team

**END OF HA ARCHITECTURE DOCUMENTATION**