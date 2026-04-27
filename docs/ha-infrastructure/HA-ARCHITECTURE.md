# AGL Hostman - High Availability Architecture Documentation

## Executive Summary

This document describes the High Availability (HA) architecture implemented for AGL Hostman. The architecture ensures 99.9% uptime through redundant components, automatic failover, and load balancing across multiple availability zones.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Architecture](#component-architecture)
3. [Network Topology](#network-topology)
4. [Failover Strategies](#failover-strategies)
5. [Data Replication](#data-replication)
6. [Monitoring and Alerting](#monitoring-and-alerting)
7. [Disaster Recovery](#disaster-recovery)
8. [Cost Analysis](#cost-analysis)
9. [Operational Procedures](#operational-procedures)

---

## Architecture Overview

### Design Principles

- **No Single Point of Failure**: Every component has at least one redundant instance
- **Automatic Failover**: Manual intervention not required for most failures
- **Horizontal Scalability**: Add capacity by adding more instances
- **Multi-AZ Deployment**: Services distributed across availability zones
- **Data Consistency**: Strong consistency guarantees for critical operations
- **Cost Optimization**: Right-sized resources with auto-scaling

### Service Availability Targets

| Service | Availability Target | RTO | RPO |
|---------|-------------------|-----|-----|
| Application | 99.9% | 5 min | 0 min |
| API | 99.95% | 2 min | 0 min |
| Database | 99.9% | 10 min | < 1 min |
| Cache | 99.95% | 1 min | 0 min |
| Load Balancer | 99.99% | 1 min | 0 min |

### Architecture Diagram

```
                            ┌─────────────────┐
                            │   DNS Round     │
                            │   Robin (Geo)   │
                            └────────┬────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │     HAProxy (Active-Active)    │
                    │   LB-1: 10.0.0.11              │
                    │   LB-2: 10.0.0.12              │
                    └──────────────┬─────────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
        ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
        │  App Node 1  │  │  App Node 2  │  │  App Node 3  │
        │  10.0.1.10   │  │  10.0.1.11   │  │  10.0.1.12   │
        │  (Blue)      │  │  (Blue)      │  │  (Green)     │
        └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
               │                 │                 │
               └─────────────────┼─────────────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                ▼                ▼                ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │MySQL Master  │ │MySQL Slave 1 │ │MySQL Slave 2 │
        │  10.0.2.10   │ │  10.0.2.20   │ │  10.0.2.21   │
        └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
               │                │                │
               └────────┬───────┴────────────────┘
                        │
                        ▼
                ┌──────────────────┐
                │   Redis Master   │
                │    10.0.3.10     │
                └────────┬─────────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
            ▼            ▼            ▼
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │Redis Rpl │ │Redis Rpl │ │Redis Rpl │
      │ 10.0.3.11│ │ 10.0.3.12│ │ 10.0.3.13│
      └──────────┘ └──────────┘ └──────────┘
         ▲            ▲            ▲
         │            │            │
         └────────────┼────────────┘
                      │
              ┌───────┴────────┐
              │  Redis Sentinel│
              │  x3 Instances  │
              └────────────────┘
```

---

## Component Architecture

### 1. Load Balancer Layer (HAProxy)

**Technology**: HAProxy 2.x

**Configuration**:
- Active-Active deployment with 2 instances
- Round-robin algorithm for stateless requests
- Source IP hash for admin panel (sticky sessions)
- Least connections for API endpoints
- Health checks every 2 seconds

**Features**:
- SSL termination at LB layer
- HTTP/2 support
- WebSocket support for Reverb
- Automatic server removal on health check failure
- Connection draining (graceful shutdown)

**Configuration Files**:
- `/infrastructure/haproxy/haproxy.cfg`

### 2. Application Layer (Laravel/FPM)

**Architecture**: Blue-Green Deployment

**Configuration**:
- 2+ application nodes per environment
- Shared storage via NFS
- Redis-backed sessions
- Stateless application design

**Features**:
- Zero-downtime deployments
- Automatic rollback on failure
- Horizontal pod autoscaling
- Resource limits (CPU, Memory)

**Environment Variables**:
```env
DB_CONNECTION=mysql
DB_HOST=mysql-master
DB_PORT=3306
REDIS_HOST=redis-master
REDIS_PORT=6379
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

### 3. Database Layer (MySQL)

**Technology**: MySQL 8.0 with GTID Replication

**Topology**: Master-Slave (1 master, 2 slaves)

**Configuration**:
- Master: 10.0.2.10 (read-write)
- Slave 1: 10.0.2.20 (read-only)
- Slave 2: 10.0.2.21 (read-only)

**Features**:
- GTID-based replication
- Semi-synchronous replication
- Automatic failover with Orchestrator
- Read queries distributed to slaves
- Automatic slave promotion

**Replication Settings**:
- Binlog format: ROW
- Sync binlog: 1
- Semi-sync timeout: 1000ms
- Parallel workers: 4

**Configuration Files**:
- `/infrastructure/mysql-replication/my-master.cnf`
- `/infrastructure/mysql-replication/my-slave.cnf`

### 4. Cache Layer (Redis)

**Technology**: Redis 7 with Sentinel

**Topology**: Master-Slave with 3 Sentinels

**Configuration**:
- Master: 10.0.3.10
- Slaves: 10.0.3.11, 10.0.3.12, 10.0.3.13
- Sentinels: 3 instances (monitoring)

**Features**:
- Automatic failover (< 10 seconds)
- Redis Sentinel for leader election
- AOF persistence
- Memory eviction policy: allkeys-lru
- Cluster mode disabled (using Sentinel)

**Sentinel Configuration**:
- Quorum: 2
- Down-after-milliseconds: 5000
- Failover-timeout: 10000
- Parallel-syncs: 1

**Configuration Files**:
- `/infrastructure/redis-sentinel/redis-master.conf`
- `/infrastructure/redis-sentinel/redis-slave.conf`
- `/infrastructure/redis-sentinel/sentinel.conf`

### 5. Monitoring Layer (Prometheus + Grafana)

**Technology**: Prometheus, Grafana, Alertmanager

**Components**:
- Prometheus: Metrics collection
- Grafana: Visualization
- Alertmanager: Alert routing
- Node Exporter: Host metrics
- MySQL Exporter: Database metrics
- Redis Exporter: Cache metrics
- HAProxy Exporter: LB metrics

**Metrics Tracked**:
- Service availability
- Response times (p50, p95, p99)
- Error rates
- Replication lag
- Queue depth
- CPU/Memory/Disk usage

---

## Network Topology

### Subnet Allocation

| Subnet | Purpose | CIDR |
|--------|---------|------|
| Management | Admin access | 10.0.0.0/24 |
| Application | App servers | 10.0.1.0/24 |
| Database | MySQL servers | 10.0.2.0/24 |
| Cache | Redis servers | 10.0.3.0/24 |
| Monitoring | Prometheus/Grafana | 10.0.4.0/24 |

### Firewall Rules

**Load Balancers**:
- IN: 80, 443 from anywhere
- OUT: 8080-8082 to app nodes

**Application Nodes**:
- IN: 8080-8082 from LB
- OUT: 3306 to MySQL, 6379 to Redis

**Database Nodes**:
- IN: 3306 from app nodes
- OUT: 3306 to slaves (replication)

**Cache Nodes**:
- IN: 6379 from app nodes
- OUT: 6379 to slaves (replication)

---

## Failover Strategies

### 1. Load Balancer Failover

**Detection**: Health check failure (> 3 consecutive)

**Action**:
- VIP (Virtual IP) moves to healthy LB
- Traffic rerouted automatically
- No manual intervention required

**RTO**: < 1 minute

### 2. Application Node Failover

**Detection**: Health check failure

**Action**:
- LB removes unhealthy node from rotation
- Traffic distributed to remaining nodes
- Auto-scaling may spin up new node

**RTO**: < 2 minutes

### 3. Database Master Failover

**Detection**: Automated monitoring (mysql-failover.sh)

**Action**:
1. Verify master is down
2. Check slave health and replication lag
3. Stop replication on chosen slave
4. Promote slave to master
5. Update application config
6. Reload PHP-FPM

**RTO**: < 10 minutes
**RPO**: < 1 minute (semi-sync)

**Script**: `/infrastructure/scripts/mysql-failover.sh`

### 4. Redis Master Failover

**Detection**: Sentinel quorum (2/3 sentinels agree)

**Action**:
1. Sentinels agree master is down
2. Leader sentinel initiates failover
3. Best slave promoted to master
4. Applications reconnect to new master

**RTO**: < 1 minute
**RPO**: 0 (async replication)

**Script**: `/infrastructure/scripts/redis-sentinel-failover.sh`

---

## Data Replication

### MySQL Replication

**Method**: GTID-based binlog replication

**Flow**:
```
Master (Write)
    ↓
Binary Log
    ↓
Slave 1 (Read) ←── Slave 2 (Read)
```

**Configuration**:
- Binlog format: ROW
- Sync mode: SEMI-SYNC
- Parallel workers: 4

**Lag Monitoring**:
- Alert if lag > 30 seconds
- Block promotion if lag > 5 minutes

### Redis Replication

**Method**: Async replication with Sentinel failover

**Flow**:
```
Master
    ↓
Async Replication
    ↓
Slave 1 ← Slave 2 ← Slave 3
```

**Sentinel Monitoring**:
- 3 sentinel instances
- Quorum: 2
- Automatic failover

---

## Monitoring and Alerting

### Health Checks

**Endpoint**: `/health` on all services

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "checks": {
    "database": "ok",
    "cache": "ok",
    "queue": "ok"
  }
}
```

**Health Check Script**: `/infrastructure/monitoring/health-check.sh`

### Alerting Rules

**Critical Alerts** (Page immediately):
- Master database down
- Redis master down
- All app nodes down
- Load balancer failure

**Warning Alerts** (Email within 5 min):
- High replication lag (> 30s)
- High memory usage (> 90%)
- High CPU usage (> 80%)
- Disk space low (< 20%)

### Metrics Dashboards

**Grafana Dashboards**:
1. HA Overview
2. Application Performance
3. Database Replication
4. Cache Performance
5. Infrastructure Resources

---

## Disaster Recovery

### Backup Strategy

**Database Backups**:
- Full daily: 2:00 AM UTC
- Binlog backup: Continuous
- Retention: 30 days
- Storage: S3 with cross-region replication

**Configuration Backups**:
- Terraform state: Remote backend
- Configuration files: Git repository
- Environment variables: Secrets manager

### Recovery Procedures

**Scenario 1: Single App Node Failure**
1. LB automatically removes node
2. Auto-scaling adds replacement
3. No manual intervention

**Scenario 2: Database Master Failure**
1. Failover script promotes slave
2. Applications reconnect to new master
3. Rebuild failed master as new slave
4. Manual verification required

**Scenario 3: Region Failure**
1. DNS failover to DR region
2. Warm standby activated
3. Read-only mode during sync
4. RTO: 1 hour

---

## Cost Analysis

### Infrastructure Costs (Monthly)

| Component | Instances | Unit Cost | Total |
|-----------|-----------|-----------|-------|
| Load Balancer (HAProxy) | 2 | $20 | $40 |
| Application Nodes | 3 | $80 | $240 |
| MySQL Master | 1 | $150 | $150 |
| MySQL Slaves | 2 | $100 | $200 |
| Redis Master | 1 | $80 | $80 |
| Redis Slaves | 3 | $60 | $180 |
| Monitoring Stack | 1 | $50 | $50 |
| **Total** | | | **$940/month** |

### Cost Optimization Opportunities

1. **Right-size instances**: Review CPU/memory utilization monthly
2. **Spot instances**: Use for non-critical workloads (save 60-70%)
3. **Reserved instances**: Commit to 1-3 years (save 30-50%)
4. **Auto-scaling**: Scale down during off-hours
5. **Shared services**: Use managed services where cost-effective

---

## Operational Procedures

### Deployments

**Blue-Green Deployment**:
1. Deploy new version to green environment
2. Run smoke tests against green
3. Update LB to send 10% traffic to green
4. Monitor for errors
5. Gradually shift traffic to 100%
6. Keep blue running for rollback window
7. Decommission blue after validation

**Rollback**:
1. Update LB to send 100% traffic to blue
2. Investigate green failure
3. Fix and redeploy when ready

### Scaling Operations

**Horizontal Scale-Up**:
```bash
# Add new app node
terraform apply -var='app_node_count=4'
# Verify health checks pass
# Load balancer automatically includes new node
```

**Horizontal Scale-Down**:
```bash
# Graceful shutdown
kubectl drain node-4
# Wait for connections to drain (60s)
# Remove from LB
# Terminate instance
```

### Maintenance Windows

**Database Maintenance**:
1. Promote slave to master
2. Maintenance on old master
3. Restore master role
4. Verify replication

**Redis Maintenance**:
1. Sentinel failover to new master
2. Maintenance on old master
3. Add back as slave

---

## Appendix

### Configuration Files

- HAProxy: `/infrastructure/haproxy/haproxy.cfg`
- MySQL Master: `/infrastructure/mysql-replication/my-master.cnf`
- MySQL Slave: `/infrastructure/mysql-replication/my-slave.cnf`
- Redis Master: `/infrastructure/redis-sentinel/redis-master.conf`
- Redis Slave: `/infrastructure/redis-sentinel/redis-slave.conf`
- Sentinel: `/infrastructure/redis-sentinel/sentinel.conf`

### Scripts

- Health Check: `/infrastructure/monitoring/health-check.sh`
- MySQL Failover: `/infrastructure/scripts/mysql-failover.sh`
- Redis Failover: `/infrastructure/scripts/redis-sentinel-failover.sh`

### Terraform Modules

- HA Load Balancer: `/infrastructure/terraform/modules/ha_load_balancer/`
- HA Database: `/infrastructure/terraform/modules/ha_database/`

### Related Documentation

- [DISASTER_RECOVERY.md](/DISASTER_RECOVERY.md)
- [BACKUP_DISASTER_RECOVERY.md](/BACKUP_DISASTER_RECOVERY.md)
- [CLUSTER-RISKS-AND-MAINTENANCE.md](/CLUSTER-RISKS-AND-MAINTENANCE.md)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-09
**Maintained By**: DevOps Team
