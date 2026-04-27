# Laravel Caching Guide

Comprehensive caching strategies for Laravel applications, using the RedisCacheStrategy service from AGL Hostman.

## Table of Contents

1. [Overview](#overview)
2. [Cache TTL Strategy](#cache-ttl-strategy)
3. [Cache Key Patterns](#cache-key-patterns)
4. [Cache Tagging](#cache-tagging)
5. [Query Caching](#query-caching)
6. [API Response Caching](#api-response-caching)
7. [External Service Caching](#external-service-caching)
8. [Cache Invalidation](#cache-invalidation)
9. [Cache Warming](#cache-warming)
10. [Cache Monitoring](#cache-monitoring)

## Overview

Caching is one of the most effective ways to improve Laravel application performance. The AGL Hostman project includes a comprehensive `RedisCacheStrategy` service that provides:

- Multi-layer caching (Redis + fallback)
- Intelligent cache invalidation
- Hierarchical cache tagging
- TTL-based expiration
- Cache stampede prevention

**Expected improvements**:
- 50-85% faster response times
- 80-95% reduction in database queries
- 10-20x increase in throughput

## Cache TTL Strategy

Use appropriate TTLs based on data volatility:

| TTL | Duration | Data Type | Examples |
|-----|----------|-----------|----------|
| **Short** | 300s (5 min) | Real-time data | Container status, metrics, node health |
| **Medium** | 1800s (30 min) | Semi-static data | Deployment lists, application status |
| **Long** | 3600s (1 hour) | Static data | User permissions, configuration |
| **Daily** | 86400s (24 hours) | Reference data | Statistics, aggregated metrics |
| **Weekly** | 604800s (7 days) | Rarely changing data | Lookup tables, reference data |

**From AGL Hostman**: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/RedisCacheStrategy.php`

```php
private const TTL_SHORT = 300;        // 5 minutes
private const TTL_MEDIUM = 1800;      // 30 minutes
private const TTL_LONG = 3600;        // 1 hour
private const TTL_DAILY = 86400;      // 24 hours
private const TTL_WEEKLY = 604800;    // 7 days
```

### TTL Selection Guidelines

```php
// Use SHORT for:
// - Real-time metrics
// - Container/server status
// - Health checks
// - Current user activity

// Use MEDIUM for:
// - API responses
// - Deployment lists
// - Application status
// - Recent activity

// Use LONG for:
// - User permissions
// - Configuration data
// - Role/permission mappings
// - User preferences

// Use DAILY for:
// - Statistics
// - Aggregated metrics
// - Historical data
// - Trend analysis

// Use WEEKLY for:
// - Reference data
// - Lookup tables
// - Static configuration
// - System settings
```

## Cache Key Patterns

### Consistent Key Naming

Use consistent, descriptive cache keys:

```php
// Format: {prefix}:{resource}:{identifier}:{params}
$cache->cacheApiResponse(
    '/api/containers',
    ['status' => 'running', 'page' => 1],
    fn() => $this->getContainers(),
    'medium'
);
// Key: api_api_containers_{md5_hash}

$cache->cacheProxmoxResponse(
    'containers',
    '101',
    fn() => $proxmox->getContainer('101'),
    'short'
);
// Key: proxmox_containers_101

$cache->cacheDbQuery(
    'users',
    ['active' => true],
    fn() => User::where('active', true)->get(),
    'long'
);
// Key: db_users_{md5_hash}
```

### Key Generation

**From AGL Hostman**:

```php
private function makeApiKey(string $endpoint, array $parameters): string
{
    $params = empty($parameters) ? '' : '_' . md5(json_encode($parameters));
    return self::PREFIX_API . '_' . str_replace('/', '_', $endpoint) . $params;
}

private function makeProxmoxKey(string $resource, ?string $identifier): string
{
    $key = self::PREFIX_PROXMOX . '_' . $resource;
    if ($identifier) {
        $key .= '_' . $identifier;
    }
    return $key;
}

private function makeDbKey(string $table, array $conditions): string
{
    $params = empty($conditions) ? '' : '_' . md5(json_encode($conditions));
    return self::PREFIX_DB . '_' . $table . $params;
}
```

## Cache Tagging

Use tags for hierarchical cache invalidation:

```php
// Tag resources
Cache::tags(['containers', 'server_1'])
    ->remember('containers_server_1', 3600, function () {
        return LxcContainer::where('server_id', 1)->get();
    });

// Invalidate all container cache
Cache::tags(['containers'])->flush();

// Invalidate specific server cache
Cache::tags(['server_1'])->flush();
```

**From AGL Hostman**:

```php
private const TAG_CONTAINERS = 'containers';
private const TAG_DEPLOYMENTS = 'deployments';
private const TAG_SERVERS = 'servers';
private const TAG_IMAGES = 'images';
private const TAG_USERS = 'users';
private const TAG_METRICS = 'metrics';

private function extractTagsFromEndpoint(string $endpoint): array
{
    $tags = [];

    if (Str::contains($endpoint, 'containers')) {
        $tags[] = self::TAG_CONTAINERS;
    }

    if (Str::contains($endpoint, 'deployments')) {
        $tags[] = self::TAG_DEPLOYMENTS;
    }

    if (Str::contains($endpoint, 'servers')) {
        $tags[] = self::TAG_SERVERS;
    }

    return $tags;
}

private function getResourceTags(string $resource): array
{
    return match($resource) {
        'containers', 'container' => [self::TAG_CONTAINERS],
        'deployments', 'deployment', 'applications' => [self::TAG_DEPLOYMENTS],
        'nodes', 'servers' => [self::TAG_SERVERS],
        'images', 'artifacts', 'repositories' => [self::TAG_IMAGES],
        default => [],
    };
}
```

## Query Caching

Cache expensive database queries:

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

// Cache query with conditions
$containers = $cache->cacheDbQuery(
    'lxc_containers',
    ['status' => 'running'],
    fn() => LxcContainer::where('status', 'running')->get(),
    'short'  // 5 minute TTL
);

// Cache with joins
$deployments = $cache->cacheDbQuery(
    'dokploy_deployments',
    ['with' => ['application', 'user']],
    fn() => DokployDeployment::with(['application', 'user'])->get(),
    'medium'
);
```

### Complex Query Caching

Cache complex queries with aggregations:

```php
$stats = Cache::remember('deployment_statistics_30d', 3600, function () {
    return DokployDeployment::where('created_at', '>=', now()->subDays(30))
        ->selectRaw('
            COUNT(*) as total,
            SUM(CASE WHEN status = "success" THEN 1 ELSE 0 END) as successful,
            AVG(CASE WHEN status = "success" THEN duration_seconds END) as avg_duration
        ')
        ->first();
});
```

## API Response Caching

Cache entire API responses:

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

public function index(Request $request)
{
    $endpoint = '/api/containers';
    $params = $request->only(['status', 'server_id', 'page']);

    $containers = $cache->cacheApiResponse(
        $endpoint,
        $params,
        fn() => $this->getContainersData($request),
        'medium'
    );

    return response()->json($containers);
}
```

### Cache-Control Headers

Add HTTP cache headers:

```php
public function show($id)
{
    $container = LxcContainer::findOrFail($id);

    return response()->json($container)
        ->header('Cache-Control', 'public, max-age=300')
        ->setEtag(md5($container->toJson()));
}
```

## External Service Caching

Cache responses from external APIs to reduce latency and rate limit issues:

### Proxmox API Caching

```php
$nodes = $cache->cacheProxmoxResponse(
    'nodes',
    null,
    fn() => $proxmoxClient->getNodes(),
    'short'  // 5 minutes - node status changes
);

$container = $cache->cacheProxmoxResponse(
    'containers',
    $vmid,
    fn() => $proxmoxClient->getContainer($vmid),
    'short'
);
```

### Dokploy API Caching

```php
$applications = $cache->cacheDokployResponse(
    'applications',
    null,
    fn() => $dokployClient->getApplications(),
    'medium'  // 30 minutes - application list changes slowly
);

$deployment = $cache->cacheDokployResponse(
    'deployments',
    $deploymentId,
    fn() => $dokployClient->getDeployment($deploymentId),
    'short'
);
```

### Harbor API Caching

```php
$projects = $cache->cacheHarborResponse(
    'projects',
    null,
    fn() => $harborClient->getProjects(),
    'long'  // 1 hour - project list changes rarely
);

$repositories = $cache->cacheHarborResponse(
    'repositories',
    $projectId,
    fn() => $harborClient->getRepositories($projectId),
    'medium'
);
```

### Cache Stampede Prevention

Prevent cache stampede for high-traffic resources:

```php
// Use cache stampede prevention (locks during regeneration)
$resource = $cache->cacheProxmoxResponse(
    'high_traffic_resource',
    null,
    fn() => $this->expensiveOperation(),
    'short'
);

// This uses rememberWithLock internally:
public function cacheProxmoxResponse(...): mixed
{
    return $this->cacheService->rememberWithLock(
        $key,
        $callback,
        $resolvedTtl,
        10  // 10 second lock
    );
}
```

## Cache Invalidation

### Manual Invalidation

Invalidate cache explicitly:

```php
$cache = app(RedisCacheStrategy::class);

// Invalidate specific resource
$cache->invalidateResource('containers', '101');

// Invalidate all containers
$cache->invalidateContainers();

// Invalidate deployments
$cache->invalidateDeployments($deploymentId);

// Invalidate images
$cache->invalidateImages($imageId);

// Invalidate user cache
$cache->invalidateUser($userId);
```

### Automatic Invalidation

Use model events for automatic invalidation:

```php
// In your model
protected static function booted()
{
    static::saved(function ($model) {
        app(RedisCacheStrategy::class)
            ->invalidateResource('containers', $model->id);
    });

    static::deleted(function ($model) {
        app(RedisCacheStrategy::class)
            ->invalidateResource('containers', $model->id);
    });

    // Related invalidation
    static::saved(function ($model) {
        app(RedisCacheStrategy::class)
            ->invalidateContainers();  // Invalidate all containers
    });
}
```

### Tag-Based Invalidation

Invalidate by tags:

```php
// Invalidate all container cache
Cache::tags(['containers'])->flush();

// Invalidate multiple tags
Cache::tags(['containers', 'servers'])->flush();

// Invalidate by pattern
Cache::flush();  // Clear all cache (use sparingly!)
```

## Cache Warming

Pre-populate cache with frequently accessed data:

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

// Warm container data
$runningContainers = LxcContainer::where('status', 'running')->get();
$cache->warmCache([
    'containers_running' => $runningContainers,
    'container_status_counts' => $this->getStatusCounts(),
], 'containers');

// Warm deployment data
$recentDeployments = DokployDeployment::latest()->limit(50)->get();
$cache->warmCache([
    'deployments_recent' => $recentDeployments,
    'deployment_statistics' => $this->getStatistics(),
], 'deployments');

// Warm user permissions
$users = User::with(['roles', 'permissions'])->get();
foreach ($users as $user) {
    $cache->cacheUserData(
        $user->id,
        'permissions',
        fn() => $user->load('roles', 'permissions'),
        'long'
    );
}
```

### Scheduled Cache Warming

Schedule cache warming with cron:

```php
// In app/Console/Kernel.php
protected function schedule(Schedule $schedule)
{
    // Warm cache every 15 minutes
    $schedule->command('cache:warm')
        ->everyFifteenMinutes()
        ->runInBackground();

    // Warm specific cache
    $schedule->call(function () {
        app(RedisCacheStrategy::class)->warmCache([
            'containers_running' => LxcContainer::where('status', 'running')->get(),
        ], 'containers');
    })->everyFiveMinutes();
}
```

Or use the provided script:

```bash
# Add to crontab
*/15 * * * * /path/to/project/agent/skills/development/laravel-performance-optimization/scripts/perf-cache-warm.sh quick
```

## Cache Monitoring

### Cache Metrics

Monitor cache performance:

```php
$metrics = $cache->getPerformanceMetrics();

/*
Returns:
[
    'hits' => 1000,
    'misses' => 100,
    'hit_rate' => 90.91,
    'redis_info' => [
        'version' => '7.0.0',
        'used_memory' => '256M',
        'keyspace_hits' => 1000,
        'keyspace_misses' => 100,
    ],
    'memory_usage' => [
        'used_memory' => 268435456,
        'used_memory_peak' => 536870912,
    ],
    'key_count' => 5000,
]
*/
```

**From AGL Hostman**:

```php
public function getPerformanceMetrics(): array
{
    $metrics = $this->cacheService->getMetrics();

    // Add custom metrics
    $metrics['redis_info'] = $this->getRedisInfo();
    $metrics['memory_usage'] = $this->getRedisMemoryUsage();
    $metrics['key_count'] = $this->getRedisKeyCount();

    return $metrics;
}
```

### Cache Hit Rate Monitoring

Track cache hit rates:

```php
use Illuminate\Support\Facades\Log;

$metrics = $cache->getPerformanceMetrics();
$hitRate = $metrics['hit_rate'] ?? 0;

if ($hitRate < 70) {
    Log::warning('Low cache hit rate', [
        'hit_rate' => $hitRate,
        'recommendation' => 'Increase cache TTL or warm cache more frequently',
    ]);
} elseif ($hitRate > 95) {
    Log::info('Excellent cache hit rate', [
        'hit_rate' => $hitRate,
    ]);
}
```

### Cache Size Monitoring

Monitor cache size:

```php
$metrics = $cache->getPerformanceMetrics();
$keyCount = $metrics['key_count'] ?? 0;

if ($keyCount > 10000) {
    Log::warning('High cache key count', [
        'key_count' => $keyCount,
        'recommendation' => 'Review cache TTL and invalidation strategy',
    ]);
}
```

## Cache Best Practices

### DO's

1. **Cache expensive operations** - Database queries, API calls, complex computations
2. **Use appropriate TTLs** - Match TTL to data volatility
3. **Use cache tags** - For hierarchical invalidation
4. **Implement cache warming** - For frequently accessed data
5. **Monitor cache performance** - Track hit rates and adjust TTLs
6. **Use cache stampede prevention** - For high-traffic resources
7. **Invalidate on changes** - Keep cache fresh with model events
8. **Use selective caching** - Only cache what's expensive

### DON'Ts

1. **Don't cache everything** - Not all data needs caching
2. **Don't use long TTLs for volatile data** - Leads to stale cache
3. **Don't forget invalidation** - Stale cache is worse than no cache
4. **Don't ignore cache size** - Unbounded cache growth causes issues
5. **Don't cache user-specific data without user tags** - Security risk
6. **Don't cache sensitive data** - Security risk
7. **Don't use Cache::flush() in production** - Clears all cache
8. **Don't cache for the sake of caching** - Measure first!

## Cache Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Hit Rate | >80% | Excellent: >90%, Good: >80%, Needs work: <70% |
| Memory Usage | <500MB | Depends on dataset size |
| Key Count | <10,000 | Varies by application |
| Response Time (cache hit) | <5ms | Should be very fast |
| Response Time (cache miss) | <100ms | Includes regeneration |

## Expected Improvements

Implementing comprehensive caching should result in:

- **50-85% faster** API response times
- **80-95% reduction** in database queries for cached data
- **10-20x increase** in throughput capacity
- **70-90% reduction** in external API calls
- **Lower database CPU usage** (30-50% reduction)

## Troubleshooting

### Low Hit Rate

**Problem**: Hit rate <70%

**Solutions**:
- Increase cache TTL
- Implement cache warming
- Review cache key patterns
- Check cache invalidation strategy

### High Memory Usage

**Problem**: Redis memory >1GB

**Solutions**:
- Reduce cache TTL
- Implement cache eviction policies
- Review cached data size
- Use selective caching

### Stale Cache

**Problem**: Cache contains outdated data

**Solutions**:
- Implement proper invalidation
- Use model events for automatic invalidation
- Reduce cache TTL for volatile data
- Implement cache versioning

### Cache Stampede

**Problem**: Multiple processes regenerating same cache

**Solutions**:
- Use cache stampede prevention (locks)
- Implement cache warming
- Add random jitter to cache expiration

## References

- AGL Hostman RedisCacheStrategy: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/RedisCacheStrategy.php`
- Laravel Cache Documentation: https://laravel.com/docs/cache
- Redis Documentation: https://redis.io/documentation
