# AGL Hostman - Database Persistence Layer Analysis

**Date:** February 7, 2026
**Analyzed By:** Database Optimization Specialist
**Project:** AGL Hostman - Infrastructure Management Platform
**Framework:** Laravel 12 | PHP 8.4
**Primary Database:** SQLite (default), with support for MySQL/MariaDB/PostgreSQL

---

## Executive Summary

This document provides a comprehensive analysis of the data persistence layer infrastructure for the AGL Hostman project. The system implements a multi-database architecture with Redis caching, comprehensive indexing strategies, and specialized services for query optimization.

**Key Findings:**
- **58 Database Tables** across infrastructure, monitoring, deployment, and notification domains
- **Redis-backed caching** with multi-layer strategies (L1: Redis, L2: Database)
- **Performance indexes** on all high-traffic tables
- **Polymorphic relationships** for flexible resource tracking
- **No ClickHouse integration** detected (despite git status mentions)
- **3-tier cache strategy** with TTL-based invalidation

---

## 1. Database Configuration

### 1.1 Supported Database Engines

| Database | Driver | Status | Default | Configured |
|----------|--------|--------|---------|------------|
| SQLite | `sqlite` | Primary | Yes | `database.sqlite` |
| MySQL | `mysql` | Supported | No | Configured |
| MariaDB | `mariadb` | Supported | No | Configured |
| PostgreSQL | `pgsql` | Supported | No | Configured |
| SQL Server | `sqlsrv` | Supported | No | Configured |

### 1.2 Redis Configuration

```php
// src/config/database.php
'default' => [
    'url' => env('REDIS_URL'),
    'host' => env('REDIS_HOST', '127.0.0.1'),
    'port' => env('REDIS_PORT', '6379'),
    'database' => env('REDIS_DB', '0'),
    'max_retries' => env('REDIS_MAX_RETRIES', 3),
    'backoff_algorithm' => env('REDIS_BACKOFF_ALGORITHM', 'decorrelated_jitter'),
]

'cache' => [
    'url' => env('REDIS_URL'),
    'host' => env('REDIS_HOST', '127.0.0.1'),
    'port' => env('REDIS_PORT', '6379'),
    'database' => env('REDIS_CACHE_DB', '1'),
]
```

**Redis Databases:**
- DB 0: Default cache/data
- DB 1: Dedicated cache layer
- Prefix: `agl-hostman-cache-`

---

## 2. Database Schema Inventory

### 2.1 Core Tables (15)

| Table | Purpose | Key Columns | Indexes |
|-------|---------|-------------|---------|
| `users` | User accounts | id, email, workos_id | email, created_at, workos_id |
| `physical_locations` | Datacenter locations | id, name, location_type | name, parent_id, server_code |
| `user_locations` | User-location mapping | user_id, physical_location_id | user_id, permission_level |
| `api_keys` | API authentication | id, user_id, token | user_id, token, is_active |
| `permissions` | RBAC permissions | id, name | name |
| `roles` | RBAC roles | id, name | name |
| `permission_user` | User permissions | permission_id, user_id | user_id |
| `role_user` | User roles | role_id, user_id | user_id |
| `cache` | Laravel cache table | key, value | key |
| `jobs` | Queue jobs | id, queue, payload | queue, reserved_at |
| `failed_jobs` | Failed queue jobs | id, queue, exception | failed_at, uuid |
| `job_batches` | Job batching | id, name | - |
| `telescope_entries` | Debug entries | id, type, batch_id | type, uuid |
| `sprints` | Agile sprints | id, name, status | status, created_at |
| `tasks` | Agile tasks | id, sprint_id, status | sprint_id, status, story_id |

### 2.2 Infrastructure Tables (12)

| Table | Purpose | Key Columns | Relationships |
|-------|---------|-------------|---------------|
| `proxmox_servers` | Proxmox hosts | id, code, status | BelongsTo: physical_location |
| `lxc_containers` | LXC containers | id, vmid, status | BelongsTo: proxmox_server |
| `container_health_logs` | Health metrics | id, container_id | BelongsTo: lxc_container |
| `performance_trends` | Time-series metrics | id, resource_type, metric_type | Polymorphic: resource |
| `alerts` | System alerts | id, type, severity | Polymorphic: resource |
| `alert_rules` | Alert configuration | id, resource_type, condition | - |
| `container_backups` | Backup records | id, container_id | BelongsTo: lxc_container |
| `container_snapshots` | Snapshot records | id, container_id | BelongsTo: lxc_container |
| `container_migrations` | Migration records | id, container_id | BelongsTo: lxc_container |
| `backups` | General backups | id, resource_type, resource_id | Polymorphic: resource |
| `scaling_events` | Auto-scaling events | id, resource_type | - |
| `metrics_aggregates` | Aggregated metrics | id, resource_type, metric_type | - |

### 2.3 Deployment Tables (9)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `dokploy_projects` | Dokploy projects | id, name, project_id |
| `dokploy_applications` | Application configs | id, name, project_id |
| `dokploy_deployments` | Deployment history | id, application_id, status |
| `dokploy_domains` | Domain mappings | id, application_id |
| `environments` | Deployment environments | id, name, type |
| `promotions` | Promotion records | id, environment_id, status |
| `production_deployments` | Production history | id, status |
| `production_approvals` | Approval workflow | id, promotion_id |
| `dora_metrics` | DORA metrics | id, deployment_id |

### 2.4 Notification Tables (6)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `notifications` | User notifications | id, user_id, read_at |
| `notification_channels` | Channel config | id, type, is_active |
| `notification_rules` | Routing rules | id, channel_id, condition |
| `notification_history` | Sent history | id, channel_id, status |
| `on_call_schedules` | On-call rotations | id, user_id, rotation |

### 2.5 Harbor Registry Tables (3)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `harbor_projects` | Harbor projects | id, harbor_id, name |
| `harbor_repositories` | Image repositories | id, project_id, name |
| `harbor_artifacts` | Image artifacts | id, repository_id, digest |

### 2.6 N8N Workflow Tables (2)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `n8n_workflows` | N8N workflows | id, workflow_id, name |
| `n8n_workflow_executions` | Execution history | id, workflow_id, status |

### 2.7 AI/ML Tracking Tables (1)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `ai_model_usage` | AI API tracking | id, provider, model, total_tokens |

### 2.8 Scrum/Agile Tables (3)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `stories` | User stories | id, sprint_id, status |
| `bugs` | Bug tracking | id, sprint_id, severity |
| `sprint_members` | Sprint membership | id, sprint_id, user_id |

### 2.9 Security Tables (2)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `audit_logs` | Audit trail | id, user_id, action |
| `security_audit_logs` | Security events | id, severity, event_type |

### 2.10 Integration Tables (2)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `archon_sync_logs` | Archon KB sync | id, status, sync_type |
| `watchables` | Watch subscriptions | id, user_id, watchable_type |

---

## 3. Data Modeling Patterns

### 3.1 Polymorphic Relationships

Used extensively for flexible resource tracking:

```php
// Alerts can relate to any resource
$table->string('resource_type')->nullable();
$table->string('resource_id')->nullable();

// In model:
public function resource(): MorphTo
{
    return $this->morphTo();
}
```

**Tables with polymorphic relationships:**
- `alerts` -> servers, containers, networks, storage
- `backups` -> any resource
- `performance_trends` -> any metric source
- `notifications` -> any entity

### 3.2 Soft Deletes

Implemented on critical entities for data recovery:

```php
$table->softDeletes();
```

**Tables with soft deletes:**
- `users`
- `proxmox_servers`
- `lxc_containers`
- `dokploy_projects`
- `harbor_projects`

### 3.3 UUID Primary Keys

Used for distributed systems integration:

```php
$table->uuid('id')->primary();
// Or via trait:
use HasUuids;
```

**Tables with UUIDs:**
- `alerts`
- `ai_model_usage`
- `notifications`

### 3.4 Composite Indexes

Performance optimization for common query patterns:

```php
// Example: Container queries by server and status
$table->index(['proxmox_server_id', 'status'], 'lxc_containers_server_status_index');

// Example: Alert filtering by status, type, and date
$table->index(['status', 'type', 'created_at']);
```

### 3.5 JSON Metadata Columns

Flexible schema for extensible data:

```php
$table->json('metadata')->nullable();
```

**Tables using JSON columns:**
- `proxmox_servers` - versions, capabilities
- `lxc_containers` - tags, notes
- `alerts` - metrics, thresholds
- `performance_trends` - additional dimensions

---

## 4. Caching Strategies

### 4.1 Multi-Layer Architecture

```
Application Layer
    ↓
L1 Cache: Redis (Hot data)
    ↓ (Cache miss)
L2 Cache: Database (Warm data)
    ↓ (Cache miss)
Source: API/External Service
```

### 4.2 Cache Services

| Service | Purpose | File |
|---------|---------|------|
| `CacheService` | Base caching operations | src/app/Services/CacheService.php |
| `RedisCacheStrategy` | Strategic caching patterns | src/app/Services/RedisCacheStrategy.php |
| `FlexibleCacheService` | Stale-while-revalidate | src/app/Services/FlexibleCacheService.php |
| `DatabaseQueryOptimizer` | Query result caching | src/app/Services/DatabaseQueryOptimizer.php |

### 4.3 TTL Strategies

| TTL | Duration | Use Case |
|-----|----------|----------|
| SHORT | 5 minutes (300s) | Real-time metrics, server status |
| MEDIUM | 30 minutes (1800s) | Semi-static data, deployments |
| LONG | 1 hour (3600s) | Static data, user permissions |
| DAILY | 24 hours (86400s) | Reference data, configurations |
| WEEKLY | 7 days (604800s) | Rarely changing data |

### 4.4 Cache Key Patterns

```php
// API responses
api_{endpoint}_{md5(parameters)}

// Proxmox resources
proxmox_{resource}_{identifier}

// Database queries
db_{table}_{md5(conditions)}

// User data
user_{userId}_{dataType}

// Metrics
metrics_{metricType}_{resource}
```

### 4.5 Cache Tagging

Hierarchical invalidation via tags:

```php
const TAG_CONTAINERS = 'containers';
const TAG_DEPLOYMENTS = 'deployments';
const TAG_SERVERS = 'servers';
const TAG_IMAGES = 'images';
const TAG_USERS = 'users';
const TAG_METRICS = 'metrics';
```

### 4.6 Cache Stampede Prevention

```php
// Lock-based cache warming
public function rememberWithLock(
    string $key,
    Closure $callback,
    int $ttl = null,
    int $lockSeconds = 10
): mixed {
    if (Cache::has($key)) {
        return Cache::get($key);
    }

    $lock = Cache::lock($key . '_lock', $lockSeconds);
    // ... single-flight pattern
}
```

### 4.7 Stale-While-Revalidate

Laravel 12 flexible caching pattern:

```php
Cache::flexible(
    key: 'server_status:AGLSRV1',
    ttl: [30, 60], // [fresh: 30s, stale: 60s]
    callback: fn() => $this->fetchServerStatus('AGLSRV1')
);
```

---

## 5. Query Optimization Patterns

### 5.1 Eager Loading

Prevent N+1 queries:

```php
// Instead of:
$containers = LxcContainer::all();
foreach ($containers as $container) {
    $container->server; // N+1 problem
}

// Use eager loading:
$containers = LxcContainer::with('server:id,name,host,status')->get();
```

### 5.2 Select Optimization

Fetch only required columns:

```php
LxcContainer::select([
    'id', 'vmid', 'name', 'hostname', 'status',
    'cores', 'memory_mb', 'disk_gb',
    'proxmox_server_id', 'created_at', 'updated_at'
])
```

### 5.3 Chunked Processing

Handle large datasets efficiently:

```php
DB::table('performance_trends')
    ->where('recorded_at', '<', $threshold)
    ->chunkById(1000, function ($trends) {
        // Process chunk
    });
```

### 5.4 Upsert Operations

Batch insert-or-update:

```php
DB::table('lxc_containers')->upsert(
    $data,
    ['vmid'], // Unique key
    ['name', 'hostname', 'status', 'updated_at'] // Update columns
);
```

### 5.5 Aggregate Queries

Single-query statistics:

```php
DB::table('dokploy_deployments')
    ->selectRaw('
        COUNT(*) as total,
        SUM(CASE WHEN status = "success" THEN 1 ELSE 0 END) as successful,
        AVG(CASE WHEN status = "success" THEN duration_seconds END) as avg_duration
    ')
    ->first();
```

---

## 6. Performance Indexes

### 6.1 Index Migration (2026_01_16_000002)

```php
// Users
$table->index('email');
$table->index('created_at');
$table->index('workos_id');

// Physical locations
$table->index(['parent_id', 'location_type']);
$table->index('server_code');

// Jobs (Horizon performance)
$table->index(['queue', 'reserved_at']);

// Failed jobs
$table->index('failed_at');
```

### 6.2 Alert Table Indexes

```php
$table->index(['status', 'type', 'created_at']); // Most common query
$table->index(['source', 'source_id']);
$table->index(['resource_type', 'resource_id']); // Polymorphic
$table->index('severity');
$table->index('is_resolved');
```

### 6.3 AI Model Usage Indexes

```php
$table->index(['provider', 'model'], 'provider_model_index');
$table->index(['task_type', 'created_at'], 'task_type_created_index');
$table->index(['user_id', 'created_at'], 'user_usage_index');
```

---

## 7. Special Database Technologies

### 7.1 ClickHouse Integration

**Status:** NOT DETECTED in codebase

**Findings:**
- No ClickHouse client libraries found
- No ClickHouse-specific migrations
- No time-series optimization for analytics
- Mentioned in research docs but not implemented

**Recommendation:**
ClickHouse would be beneficial for:
- Performance trend analytics (billions of metrics)
- Real-time alert aggregation
- Log analysis and pattern detection
- Cost-effective long-term data retention

### 7.2 Redis Usage

**Current Implementation:**
- Cache layer (via Laravel Cache facade)
- Queue backend (via Laravel Queue)
- Session storage (optional)
- Horizon dashboard (queue monitoring)

**Redis Info Monitoring:**
```php
$redis->info(); // Version, uptime, memory
$redis->info('memory'); // Memory usage stats
$redis->info('keyspace'); // Key counts per DB
```

### 7.3 SQLite (Default)

**Use Case:** Development, single-instance deployments

**Configuration:**
- Database file: `database/database.sqlite`
- Journal mode: Default
- Foreign key constraints: Enabled
- Transaction mode: DEFERRED

**Considerations:**
- Not suitable for high-concurrency production
- No network access for distributed deployments
- Recommended: PostgreSQL/MySQL for production

---

## 8. Data Retention & Cleanup

### 8.1 Performance Trends

```php
// Cleanup old trends (default: 90 days)
PerformanceTrend::cleanupOldTrends(90);
```

### 8.2 Audit Logs

Manual cleanup recommended:
```php
// Delete logs older than 1 year
AuditLog::where('created_at', '<', now()->subYear())->delete();
```

### 8.3 Failed Jobs

Automatic pruning via Horizon:
```bash
php artisan horizon:purge
```

---

## 9. Migration Strategy

### 9.1 Current Migration Count

**Total:** 58 migrations

### 9.2 Migration Naming Convention

```
YYYY_MM_DD_HHMMSS_description.php
```

### 9.3 Rollback Procedures

All migrations include `down()` method for rollback:

```bash
# Rollback last migration
php artisan migrate:rollback

# Rollback specific steps
php artisan migrate:rollback --step=5

# Reset all migrations
php artisan migrate:fresh
# Or with data seeding
php artisan migrate:fresh --seed
```

### 9.4 Production Deployment

```bash
# Backup before migration
php artisan db:backup

# Run migrations
php artisan migrate --force

# Clear and warm cache
php artisan cache:clear
php artisan config:cache
php artisan route:cache
```

---

## 10. Recommended Skills for Data Operations

Based on the analysis, these skills would benefit data operations:

### 10.1 Database Administration

| Skill | Priority | Description |
|-------|----------|-------------|
| PostgreSQL Administration | HIGH | For production deployments |
| MySQL/MariaDB Optimization | HIGH | Query tuning, indexing |
| Redis Operations | HIGH | Cache management, monitoring |
| Database Backup/Recovery | HIGH | Disaster recovery procedures |
| Migration Management | MEDIUM | Schema versioning |

### 10.2 Performance Optimization

| Skill | Priority | Description |
|-------|----------|-------------|
| Query Analysis (EXPLAIN) | HIGH | Query plan optimization |
| Index Design | HIGH | Optimal index strategies |
| N+1 Query Detection | HIGH | Eager loading patterns |
| Cache Strategy Design | HIGH | Multi-layer caching |
| Partitioning | MEDIUM | Large table partitioning |

### 10.3 Monitoring & Observability

| Skill | Priority | Description |
|-------|----------|-------------|
| Slow Query Analysis | HIGH | Identify bottlenecks |
| Cache Hit Rate Monitoring | HIGH | Cache effectiveness |
| Database Metrics Collection | HIGH | Performance baselines |
| Alert Threshold Tuning | MEDIUM | Noise reduction |

### 10.4 Data Modeling

| Skill | Priority | Description |
|-------|----------|-------------|
| Polymorphic Relationships | MEDIUM | Flexible resource tracking |
| JSON Schema Design | MEDIUM | Metadata column usage |
| Soft Delete Strategies | MEDIUM | Data retention compliance |
| UUID vs Integer IDs | LOW | Distributed system design |

---

## 11. Configuration Files

| File | Purpose |
|------|---------|
| `src/config/database.php` | Database connections |
| `src/config/cache.php` | Cache stores |
| `src/config/queue.php` | Queue backends |
| `src/config/horizon.php` | Queue monitoring |
| `src/config/monitoring.php` | Metrics collection |

---

## 12. Environment Variables

```bash
# Database
DB_CONNECTION=sqlite
DB_DATABASE=database.sqlite

# For MySQL/PostgreSQL:
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=agl_hostman
DB_USERNAME=root
DB_PASSWORD=

# Redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_DB=0
REDIS_CACHE_DB=1

# Cache
CACHE_STORE=redis

# Queue
QUEUE_CONNECTION=database
```

---

## 13. Recommendations

### 13.1 Immediate Actions

1. **Switch to PostgreSQL** for production
   - Better concurrent write performance
   - Superior JSON column support
   - Native array types

2. **Implement ClickHouse** for analytics
   - Performance trends: billions of rows
   - Alert aggregation: real-time rollups
   - Cost-effective: 10x compression

3. **Add read replicas**
   - Offload read-heavy queries
   - Improve reporting performance
   - Enable horizontal scaling

4. **Implement connection pooling**
   - PgBouncer for PostgreSQL
   - Reduce connection overhead
   - Improve scalability

### 13.2 Performance Optimizations

1. **Add composite indexes** for common query patterns
2. **Implement partitioning** for `performance_trends`
3. **Use database views** for complex aggregations
4. **Enable query caching** for expensive operations
5. **Add read-through caching** for hot data

### 13.3 Monitoring Enhancements

1. **Slow query logging** with thresholds
2. **Cache hit/miss metrics** dashboard
3. **Database connection pool** monitoring
4. **Index usage statistics** tracking
5. **Query performance regression** alerts

---

## Appendix A: Complete Table List

```
1. alerts
2. alert_rules
3. ai_model_usage
4. api_keys
5. archon_sync_logs
6. audit_logs
7. backups
8. cache
9. container_backups
10. container_health_logs
11. container_migrations
12. container_snapshots
13. dora_metrics
14. dokploy_applications
15. dokploy_deployments
16. dokploy_domains
17. dokploy_projects
18. environments
19. failed_jobs
20. harbor_artifacts
21. harbor_projects
22. harbor_repositories
23. jobs
24. job_batches
25. lxc_containers
26. metrics_aggregates
27. migrations
28. n8n_workflow_executions
29. n8n_workflows
30. notification_channels
31. notification_history
32. notification_rules
33. notifications
34. on_call_schedules
35. password_reset_tokens
36. permission_user
37. permissions
38. personal_access_tokens
39. physical_location_user
40. physical_locations
41. production_approvals
42. production_deployments
43. proxmox_servers
44. role_user
45. roles
46. scaling_events
47. security_audit_logs
48. sprints
49. sprint_members
50. stories
51. tasks
52. telescope_entries
53. users
54. watchables
55. bugs
56. failed_jobs
57. metrics_aggregates
58. performance_trends
```

---

## Appendix B: Database Services

### Service Files

| Service | Location | Purpose |
|---------|----------|---------|
| `CacheService` | src/app/Services/ | Base caching operations |
| `RedisCacheStrategy` | src/app/Services/ | Strategic caching |
| `FlexibleCacheService` | src/app/Services/ | Stale-while-revalidate |
| `DatabaseQueryOptimizer` | src/app/Services/ | Query optimization |

### Model Files

| Model | Location | Purpose |
|-------|----------|---------|
| `Alert` | src/app/Models/ | Alert management |
| `PerformanceTrend` | src/app/Models/ | Time-series metrics |
| `LxcContainer` | src/app/Models/ | Container entities |
| `ProxmoxServer` | src/app/Models/ | Server entities |
| `DokployDeployment` | src/app/Models/ | Deployment tracking |

---

**Document Version:** 1.0
**Last Updated:** February 7, 2026
**Next Review:** March 7, 2026
