# Query Optimization Skill

**Category**: Database Performance
**Based on**: `/src/app/Services/DatabaseQueryOptimizer.php`
**Related Models**: `LxcContainer`, `DokployDeployment`, `PerformanceTrend`, `Alert`, `User`

## Overview

Expert in preventing N+1 query problems, optimizing eager loading, reducing database load, and implementing efficient query patterns for Laravel applications targeting both MySQL and PostgreSQL.

## Core Capabilities

### 1. N+1 Query Prevention

#### Problem Example
```php
// BAD: N+1 query - 1 query for containers + N queries for servers
$containers = LxcContainer::all();
foreach ($containers as $container) {
    echo $container->server->name;  // Additional query per container
}
// Total: 1 + N queries
```

#### Solution: Eager Loading
```php
// GOOD: Eager load with select optimization
$containers = LxcContainer::with([
    'server:id,name,host,status',  // Select only needed fields
])->get();

foreach ($containers as $container) {
    echo $container->server->name;  // No additional query
}
// Total: 1 query with JOIN
```

### 2. Optimized Container Queries

```php
use App\Services\DatabaseQueryOptimizer;

$optimizer = app(DatabaseQueryOptimizer::class);

// Get containers with optimized relationships
$containers = $optimizer->getContainersOptimized([
    'status' => 'running',
    'server_id' => 1,
    'search' => 'app-',
]);

// Executes optimized query:
// SELECT id, vmid, name, hostname, status, cores, memory_mb, disk_gb,
//        proxmox_server_id, created_at, updated_at
// FROM lxc_containers
// WHERE status = 'running' AND proxmox_server_id = 1
//   AND (name LIKE '%app-%' OR hostname LIKE '%app-%' OR vmid LIKE '%app-%')
```

### 3. Optimized Deployment Queries

```php
// Paginated with eager loading
$deployments = $optimizer->getDeploymentsOptimized([
    'status' => 'success',
    'branch' => 'main',
], 15);  // 15 per page

// Includes:
// - Application with user
// - Only selected columns
// - Proper ordering
```

### 4. Selective Column Loading

```php
// GOOD: Select only needed columns
User::select(['id', 'name', 'email'])->get();

// GOOD: With relationships
User::with([
    'roles:id,name',
    'permissions:id,name',
])->select(['id', 'name', 'email'])
->get();

// AVOID: Selecting all columns
User::get();  // Fetches all columns including large text fields
```

### 5. Aggregate Queries

Replace multiple queries with single aggregate:

```php
// BAD: Multiple queries
$statuses = [];
$statuses['running'] = LxcContainer::where('status', 'running')->count();
$statuses['stopped'] = LxcContainer::where('status', 'stopped')->count();
$statuses['starting'] = LxcContainer::where('status', 'starting')->count();
// Total: 3 queries

// GOOD: Single aggregate query
$counts = $optimizer->getContainerStatusCounts();
// Returns: ['running' => 45, 'stopped' => 12, 'starting' => 3]
// Total: 1 query with GROUP BY
```

### 6. Deployment Statistics

```php
$stats = $optimizer->getDeploymentStatistics(30);
// Returns single query with:
// [
//     'total' => 150,
//     'successful' => 135,
//     'failed' => 10,
//     'in_progress' => 5,
//     'success_rate' => 90.0,
//     'avg_duration_seconds' => 245,
// ]
```

### 7. Efficient UNION Queries

Combine multiple data sources:

```php
$activity = $optimizer->getRecentActivity(50);
// Executes single query with UNION ALL:
// (SELECT id, 'container' as type, ... FROM lxc_containers LIMIT 50)
// UNION ALL
// (SELECT id, 'deployment' as type, ... FROM dokploy_deployments LIMIT 50)
// UNION ALL
// (SELECT id, 'alert' as type, ... FROM alerts LIMIT 50)
// ORDER BY created_at DESC LIMIT 50
```

### 8. Chunked Processing

Process large datasets efficiently:

```php
$optimizer->chunkedProcessing(
    LxcContainer::query(),
    100,  // Chunk size
    function ($containers) {
        foreach ($containers as $container) {
            // Process each chunk
            $this->processContainerMetrics($container);
        }
    }
);
```

### 9. JOIN Instead of WHERE IN

```php
// BAD: WHERE IN (can be slow)
$containers = LxcContainer::whereIn('proxmox_server_id', $serverIds)
    ->with('server')
    ->get();

// GOOD: JOIN with optimization
$containers = $optimizer->getContainersByServersJoin($serverIds);
// Uses JOIN for better query plan
```

### 10. Cursor-Based Pagination

For large datasets, cursor pagination is more efficient:

```php
$result = $optimizer->cursorPaginate(
    LxcContainer::query(),
    50,
    $cursor  // null for first page
);
// Returns:
// [
//     'data' => Collection,
//     'next_cursor' => 'abc123',
//     'has_more' => true,
// ]
```

## Query Optimization Techniques

### 1. Use EXPLAIN ANALYZE

```php
// PostgreSQL
DB::statement('EXPLAIN ANALYZE ' . $query->toSql());

// MySQL
DB::statement('EXPLAIN ' . $query->toSql());
```

Look for:
- **Seq Scan** on large tables → Add index
- **Nested Loop** with high cost → Rewrite query
- **High actual time** → Missing index or inefficient join

### 2. Index Strategy

Essential indexes for monitoring:

```sql
-- Performance trends (time-series)
CREATE INDEX idx_performance_trends_resource_metric
ON performance_trends (resource_type, resource_id, metric_type, recorded_at DESC);

-- Alerts (status filtering)
CREATE INDEX idx_alerts_status_severity
ON alerts (status, severity, created_at DESC);

-- Containers (status + server)
CREATE INDEX idx_containers_status_server
ON lxc_containers (status, proxmox_server_id);

-- Deployments (application + created_at)
CREATE INDEX idx_deployments_app_created
ON dokploy_deployments (application_id, created_at DESC);
```

### 3. Avoid SELECT *

```php
// AVOID
LxcContainer::with('server')->get();

// PREFER
LxcContainer::with(['server:id,name,host'])
    ->select(['id', 'vmid', 'name', 'status', 'proxmox_server_id'])
    ->get();
```

### 4. Use Pluck for Single Columns

```php
// BAD
$userIds = User::all()->pluck('id');

// GOOD
$userIds = User::pluck('id');
```

### 5. Exists vs Count

```php
// BAD: Counts all records
if (LxcContainer::where('status', 'running')->count() > 0) {
    // ...
}

// GOOD: Stops at first match
if (LxcContainer::where('status', 'running')->exists()) {
    // ...
}
```

## Upsert Operations

Batch insert or update efficiently:

```php
$containers = [
    ['vmid' => 101, 'name' => 'container-1', 'status' => 'running'],
    ['vmid' => 102, 'name' => 'container-2', 'status' => 'running'],
];

$affected = $optimizer->upsertContainers($containers);
// Uses single query with ON DUPLICATE KEY UPDATE (MySQL)
// or ON CONFLICT (PostgreSQL)
```

## Common Query Patterns

### Performance Metrics
```php
$optimizer->getPerformanceTrendsOptimized(
    resourceType: 'server',
    resourceId: 'px-server-01',
    metricType: 'cpu',
    hours: 24
);
```

### Alert Dashboard
```php
$optimizer->getAlertsOptimized([
    'is_resolved' => false,
    'severity' => 'critical',
]);
```

### User with Relationships
```php
$optimizer->getUserWithRelationships($userId);
```

## Performance Benchmarks

| Operation | Unoptimized | Optimized | Improvement |
|-----------|-------------|-----------|-------------|
| 100 containers with server | 101 queries | 1 query | 99% reduction |
| Container status counts | 4 queries | 1 query | 75% reduction |
| Recent activity | 3 queries | 1 query | 67% reduction |

## Integration Points

- **Performance Monitoring**: Optimized metric queries
- **Alert Management**: Efficient alert filtering
- **Redis Caching**: Cache query results
- **Migration Best Practices**: Index creation

## Best Practices

1. **Always use eager loading** for relationships accessed in loops
2. **Select only needed columns** to reduce memory and network overhead
3. **Use aggregate queries** instead of multiple counts
4. **Add indexes** on columns used in WHERE, ORDER BY, JOIN
5. **Use chunking** for processing large datasets
6. **Consider cursor pagination** for large result sets
7. **Use EXISTS instead of COUNT** for existence checks
8. **Monitor slow query logs** for optimization opportunities

## See Also

- `performance-monitoring` - Metrics being queried
- `alert-management` - Alerts being filtered
- `redis-caching` - Cache query results
