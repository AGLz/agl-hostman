# Redis Caching Skill

**Category**: Performance & Caching
**Based on**: `/src/app/Services/RedisCacheStrategy.php`

## Overview

Expert in implementing comprehensive Redis caching strategies for Laravel applications, including multi-layer caching, intelligent invalidation, cache stampede prevention, and performance monitoring.

## Core Capabilities

### 1. TTL Strategies

Use appropriate TTL for different data types:

| TTL | Duration | Use Case |
|-----|----------|----------|
| SHORT | 5 minutes | Real-time metrics, API responses |
| MEDIUM | 30 minutes | Semi-static data, deployments |
| LONG | 1 hour | Configuration, user data |
| DAILY | 24 hours | Daily statistics, reports |
| WEEKLY | 7 days | Reference data, infrequently changing |

### 2. Cache API Responses

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

$data = $cache->cacheApiResponse(
    endpoint: '/api/containers',
    parameters: ['status' => 'running', 'page' => 1],
    callback: fn() => $this->fetchContainersFromApi(),
    ttl: 'short'  // 5 minutes
);
```

### 3. Cache External Service Responses

#### Proxmox (with stampede prevention)
```php
$containers = $cache->cacheProxmoxResponse(
    resource: 'containers',
    identifier: null,  // All containers
    callback: fn() => $proxmox->getContainers(),
    ttl: 'short'
);
// Uses rememberWithLock to prevent cache stampede
```

#### Dokploy
```php
$deployments = $cache->cacheDokployResponse(
    resource: 'deployments',
    identifier: $applicationId,
    callback: fn() => $dokploy->getDeployments($applicationId),
    ttl: 'medium'
);
```

#### Harbor
```php
$repositories = $cache->cacheHarborResponse(
    resource: 'repositories',
    identifier: $projectId,
    callback: fn() => $harbor->getRepositories($projectId),
    ttl: 'long'  // Harbor data changes less frequently
);
```

### 4. Cache Database Queries

```php
$stats = $cache->cacheDbQuery(
    table: 'performance_trends',
    conditions: ['resource_type' => 'server', 'metric_type' => 'cpu'],
    callback: fn() => DB::table('performance_trends')
        ->where('resource_type', 'server')
        ->where('metric_type', 'cpu')
        ->avg('value'),
    ttl: 'short'
);
```

### 5. Cache User Data

```php
$permissions = $cache->cacheUserData(
    userId: $user->id,
    dataType: 'permissions',
    callback: fn() => $user->permissions()->pluck('name'),
    ttl: 'long'  // Permissions don't change often
);
```

### 6. Cache Metrics

```php
$cpuUsage = $cache->cacheMetrics(
    metricType: 'cpu',
    resource: 'server-px-01',
    callback: fn() => $this->collectCpuMetrics('server-px-01'),
    ttl: 'short'
);
```

### 7. Cache Invalidation

#### By resource type
```php
// Invalidate all container cache
$cache->invalidateResource('containers');

// Invalidate specific container
$cache->invalidateResource('containers', 'vm-105');
```

#### Specific invalidation methods
```php
// Container cache
$cache->invalidateContainers($vmid);

// Deployment cache
$cache->invalidateDeployments($deploymentId);

// Image cache
$cache->invalidateImages($imageId);

// User cache
$cache->invalidateUser($userId);
```

#### Hierarchical invalidation with tags
```php
// These use cache tags for bulk invalidation
Cache::tags(['containers', 'server-px-01'])->flush();

// All container-related cache
Cache::tags(['containers'])->flush();

// Multiple related tags
Cache::tags(['containers', 'deployments', 'metrics'])->flush();
```

### 8. Cache Warming

Pre-populate cache with critical data:

```php
$cache->warmCache([
    'api_containers_running' => $runningContainers,
    'proxmox_nodes' => $nodes,
    'system_metrics' => $metrics,
], 'infrastructure');
```

### 9. Performance Monitoring

Get cache performance metrics:

```php
$metrics = $cache->getPerformanceMetrics();
// Returns:
// [
//     'hits' => 1250,
//     'misses' => 85,
//     'hit_rate' => 93.6,
//     'redis_info' => [...],
//     'memory_usage' => [...],
//     'key_count' => 1520,
// ]
```

### 10. Cache Stampede Prevention

For high-traffic keys, use locking:

```php
// Implemented in cacheProxmoxResponse
return $this->cacheService->rememberWithLock(
    $key,
    $callback,
    $ttl,
    10  // 10 second lock timeout
);
```

## Cache Key Design

### Key Patterns

```php
// API endpoints
api_api_containers_<md5 of params>

// External services
proxmox_containers
proxmox_containers_101
dokploy_deployments
dokploy_applications_app-123

// Database queries
db_performance_trends_<md5 of conditions>

// User data
user_123_permissions
user_123_preferences

// Metrics
metrics_cpu_server-px-01
metrics_memory_vm-105
```

### Tags for Hierarchical Invalidation

```php
const TAG_CONTAINERS = 'containers';
const TAG_DEPLOYMENTS = 'deployments';
const TAG_SERVERS = 'servers';
const TAG_IMAGES = 'images';
const TAG_USERS = 'users';
const TAG_METRICS = 'metrics';
```

## Common Patterns

### 1. Remember Pattern

```php
$value = Cache::remember('key', 300, function () {
    return DB::table('data')->value('field');
});
```

### 2. Remember Forever

```php
$config = Cache::rememberForever('app_config', function () {
    return config('app');
});

// Manually invalidate when needed
Cache::forget('app_config');
```

### 3. Cache Tags

```php
// Store with tags
Cache::tags(['containers', 'server-1'])->remember('container_101', 3600, fn() => [...]);

// Flush by tag
Cache::tags(['containers'])->flush();
```

## Best Practices

### 1. Use Descriptive Keys
```php
// GOOD
'proxmox_containers_server_px01_running'

// AVOID
'cache_12345_data'
```

### 2. Set Appropriate TTL
```php
// GOOD: Short TTL for real-time data
$cache->cacheApiResponse(..., ttl: 'short');  // 5 min

// GOOD: Long TTL for static data
$cache->cacheUserData(..., ttl: 'long');  // 1 hour

// AVOID: Too long TTL for changing data
Cache::remember('current_time', 86400, fn() => now());  // WRONG!
```

### 3. Invalidate Strategically
```php
// After deployment
$cache->invalidateDeployments($deploymentId);

// After container update
$cache->invalidateContainers($container->vmid);

// After user permission change
$cache->invalidateUser($userId);
```

### 4. Handle Cache Failures
```php
try {
    $data = Cache::remember('key', 300, fn() => $this->expensiveOperation());
} catch (\Exception $e) {
    // Fallback to direct query
    $data = $this->expensiveOperation();
    Log::warning('Cache fallback used', ['error' => $e->getMessage()]);
}
```

### 5. Monitor Cache Health
```php
$metrics = $cache->getPerformanceMetrics();
if ($metrics['hit_rate'] < 80) {
    Log::warning('Low cache hit rate', ['hit_rate' => $metrics['hit_rate']]);
}
```

## Redis Memory Management

### Memory Usage Monitoring
```php
$memory = $cache->getPerformanceMetrics()['memory_usage'];
// Returns used_memory, used_memory_peak, maxmemory
```

### Key Count
```php
$keyCount = $cache->getPerformanceMetrics()['key_count'];
// Monitor to prevent memory bloat
```

## Integration Points

- **Query Optimizer**: Cache query results
- **Performance Monitoring**: Cache metrics
- **Alert Management**: Cache alert counts
- **Harbor Registry**: Cache repository data

## Common Tasks

### Clear all cache
```php
$cache->clearAll();
```

### Invalidate by resource
```php
$cache->invalidateResource('containers', 'vm-105');
```

### Warm cache on deployment
```php
Artisan::call('cache:warm');
```

## See Also

- `query-optimization` - Database query caching
- `performance-monitoring` - Metrics caching
- `alert-management` - Alert notification caching
