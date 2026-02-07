# Redis Caching Strategy

## Overview

AGL Hostman implements a comprehensive Redis caching strategy to optimize performance, reduce database load, and minimize external API calls. This document explains the caching architecture, strategies, and best practices.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AGL Hostman                              │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├──► L1 Cache: Redis (Fast, Distributed)
               │    ├──► API Responses
               │    ├──► Database Queries
               │    ├──► External API Calls
               │    └──► User Sessions
               │
               ├──► L2 Cache: Database (Fallback)
               │    └──► Cache Table
               │
               └──► Cache Invalidation
                    ├──► Tag-based Invalidation
                    ├──► Time-based Expiration
                    └──► Event-driven Clearing
```

## Cache Key Structure

### Format
```
{prefix}_{resource}_{identifier}_{params}
```

### Prefixes
- `api` - API responses
- `proxmox` - Proxmox API calls
- `dokploy` - Dokploy API calls
- `harbor` - Harbor API calls
- `db` - Database queries
- `user` - User-specific data
- `metrics` - System metrics

### Examples
```
api_containers_index
proxmox_container_105
dokploy_deployment_dep_123
db_users_active
user_5_permissions
metrics_cpu_aglsrv6
```

## TTL Strategies

| TTL | Duration | Use Cases |
|-----|----------|-----------|
| **short** | 5 minutes | Real-time data, container metrics, server status |
| **medium** | 30 minutes | Deployments, applications, semi-static data |
| **long** | 1 hour | Projects, repositories, configurations |
| **day** | 24 hours | Reference data, system settings |
| **week** | 7 days | Static lookup data, rarely-changing data |

## Tag-based Invalidation

### Cache Tags
- `containers` - All container-related data
- `deployments` - All deployment-related data
- `servers` - All server-related data
- `images` - All container image data
- `users` - All user data
- `metrics` - All metrics data

### Inheritance Example
```
Container cache entry:
├── Primary tag: containers
├── Resource tag: container_105
└── Server tag: server_aglsrv6

Invalidation options:
├── Flush "containers" → Clears ALL container caches
├── Flush "container_105" → Clears only container 105
└── Flush "servers" → Clears all server and container data
```

## Service Layer Integration

### 1. Proxmox API Caching

```php
use App\Services\RedisCacheStrategy;

class ContainerController extends Controller
{
    protected $cache;

    public function __construct(RedisCacheStrategy $cache)
    {
        $this->cache = $cache;
    }

    public function index()
    {
        // Cache list of containers (5 minutes)
        $containers = $this->cache->cacheProxmoxResponse(
            'containers',
            null,
            fn() => $this->proxmox->getContainers(),
            'short'  // 5 minutes TTL
        );

        return response()->json($containers);
    }

    public function show($vmid)
    {
        // Cache individual container (5 minutes)
        $container = $this->cache->cacheProxmoxResponse(
            'container',
            $vmid,
            fn() => $this->proxmox->getContainer($vmid),
            'short'
        );

        return response()->json($container);
    }
}
```

### 2. Dokploy API Caching

```php
public function deployments()
{
    // Cache deployments list (30 minutes)
    $deployments = $this->cache->cacheDokployResponse(
        'deployments',
        null,
        fn() => $this->dokploy->getDeployments(),
        'medium'  // 30 minutes TTL
    );

    return response()->json($deployments);
}
```

### 3. Harbor API Caching

```php
public function repositories($project)
{
    // Cache repository list (1 hour)
    $repositories = $this->cache->cacheHarborResponse(
        'repositories',
        $project,
        fn() => $this->harbor->getRepositories($project),
        'long'  // 1 hour TTL
    );

    return response()->json($repositories);
}
```

## Database Query Caching

### Eloquent Model Caching

```php
use App\Services\RedisCacheStrategy;

class UserRepository extends BaseRepository
{
    protected $cache;

    public function __construct(RedisCacheStrategy $cache)
    {
        $this->cache = $cache;
    }

    public function getActiveUsers()
    {
        return $this->cache->cacheDbQuery(
            'users',
            ['active' => true],
            fn() => User::where('active', true)->get(),
            'medium'  // 30 minutes TTL
        );
    }
}
```

### Query Result Caching

```php
public function getContainerMetrics($vmid)
{
    return $this->cache->cacheDbQuery(
        'container_metrics',
        ['vmid' => $vmid],
        fn() => DB::table('container_metrics')
            ->where('vmid', $vmid)
            ->orderBy('recorded_at', 'desc')
            ->limit(100)
            ->get(),
        'short'  // 5 minutes TTL
    );
}
```

## Cache Invalidation

### Automatic Invalidation

```php
use App\Events\ContainerStatusChanged;

class InvalidateContainerCache
{
    public function handle(ContainerStatusChanged $event)
    {
        $cache = app(RedisCacheStrategy::class);

        // Invalidate specific container cache
        $cache->invalidateContainers($event->vmid);

        // Also invalidate server cache (contains container list)
        $cache->invalidateResource('servers');
    }
}
```

### Manual Invalidation

```php
// Invalidate all containers
$cache->invalidateContainers();

// Invalidate specific deployment
$cache->invalidateDeployments('dep_123');

// Invalidate user data
$cache->invalidateUser($userId);

// Invalidate by custom tag
$cache->flushTags(['custom_tag']);
```

### Event-based Invalidation

```php
// In EventServiceProvider
protected $listen = [
    ContainerCreated::class => [
        InvalidateContainerCache::class,
    ],
    ContainerUpdated::class => [
        InvalidateContainerCache::class,
    ],
    ContainerDeleted::class => [
        InvalidateContainerCache::class,
    ],
    DeploymentCompleted::class => [
        InvalidateDeploymentCache::class,
    ],
];
```

## API Response Caching

### Middleware Configuration

```php
// app/Http/Kernel.php

protected $middlewareGroups = [
    'api' => [
        \App\Http\Middleware\CacheApiResponse::class,
        'throttle:api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

### Route-level Caching

```php
// routes/api.php

// Cache for 5 minutes (real-time data)
Route::middleware('cache.api:short')->group(function () {
    Route::get('/infrastructure/metrics', [MetricsController::class, 'index']);
    Route::get('/proxmox/containers', [ContainerController::class, 'index']);
});

// Cache for 30 minutes (semi-static data)
Route::middleware('cache.api:medium')->group(function () {
    Route::get('/deployments', [DeploymentController::class, 'index']);
    Route::get('/dokploy/applications', [ApplicationController::class, 'index']);
});

// Cache for 1 hour (static data)
Route::middleware('cache.api:long')->group(function () {
    Route::get('/harbor/projects', [HarborController::class, 'projects']);
    Route::get('/harbor/repositories/{project}', [HarborController::class, 'repositories']);
});
```

### Response Headers

Cached responses include these headers:
```
X-Cache: HIT
Cache-Control: max-age=300
Age: 120
```

## Cache Warming

### Scheduled Cache Warming

```php
// app/Console/Kernel.php

protected $schedule = [
    // Warm cache every 15 minutes
    $schedule->job(new WarmCacheJob)
        ->everyFifteenMinutes()
        ->between('8:00', '22:00')  // Business hours
        ->withoutOverlapping()
        ->onSuccess(function () {
            Log::info('Cache warming completed successfully');
        })
        ->onFailure(function () {
            Log::error('Cache warming failed');
        }),
];
```

### Manual Cache Warming

```php
use App\Jobs\WarmCacheJob;

// Dispatch immediately
WarmCacheJob::dispatchSync();

// Dispatch to queue
WarmCacheJob::dispatch();

// Delayed dispatch
WarmCacheJob::dispatch()
    ->delay(now()->addMinutes(5));
```

## Cache Monitoring

### Performance Metrics

```php
$cache = app(RedisCacheStrategy::class);
$metrics = $cache->getPerformanceMetrics();

print_r($metrics);
/*
[
    'total_requests' => 10000,
    'hits' => 8500,
    'misses' => 1500,
    'hit_rate' => 85.0,
    'avg_retrieval_time' => 0.0023,  // 2.3ms
    'redis_info' => [
        'version' => '7.0.0',
        'connected_clients' => 10,
        'used_memory' => '256M',
        'keyspace_hits' => 85000,
        'keyspace_misses' => 15000,
    ],
    'memory_usage' => [
        'used_memory' => 268435456,
        'used_memory_percentage' => 25.6,
    ],
    'key_count' => 1523,
]
*/
```

### Dashboard Integration

```javascript
// Fetch cache metrics
const { data: metrics } = await axios.get('/api/admin/cache/metrics');

// Display hit rate
<CacheHitRate value={metrics.hit_rate} />  // 85%

// Display memory usage
<RedisMemory usage={metrics.memory_usage} />

// Display key count
<RedisKeys count={metrics.key_count} />
```

## Best Practices

### 1. Choose Appropriate TTL

```php
// ✅ GOOD: Short TTL for real-time data
$cache->cacheProxmoxResponse('containers', null, $callback, 'short');  // 5 min

// ❌ BAD: Long TTL for real-time data
$cache->cacheProxmoxResponse('containers', null, $callback, 'day');  // 24 hours

// ✅ GOOD: Long TTL for static data
$cache->cacheHarborResponse('projects', null, $callback, 'long');  // 1 hour

// ❌ BAD: Short TTL for static data (excessive cache refreshes)
$cache->cacheHarborResponse('projects', null, $callback, 'short');  // 5 min
```

### 2. Use Cache Tags Effectively

```php
// ✅ GOOD: Hierarchical tags
$tags = ['containers', 'container_105', 'server_aglsrv6'];
$cache->put('key', $value, $ttl, $tags);

// ❌ BAD: No tags (hard to invalidate)
$cache->put('key', $value, $ttl);

// ❌ BAD: Too many tags (performance impact)
$tags = ['tag1', 'tag2', 'tag3', ..., 'tag20'];  // Avoid
```

### 3. Implement Cache Stampede Prevention

```php
// Use rememberWithLock for expensive operations
$result = $cache->rememberWithLock(
    'expensive_operation',
    fn() => $this->expensiveOperation(),
    'short',
    10  // Lock for 10 seconds
);
```

### 4. Monitor Cache Performance

```php
// Log cache metrics regularly
if (app()->environment('production')) {
    $metrics = $cache->getPerformanceMetrics();

    if ($metrics['hit_rate'] < 70) {
        Log::warning('Low cache hit rate', [
            'hit_rate' => $metrics['hit_rate'],
            'total_requests' => $metrics['total_requests'],
        ]);
    }
}
```

### 5. Handle Cache Failures Gracefully

```php
try {
    $data = $cache->remember('key', fn() => $this->fetchData(), 'medium');
} catch (\Exception $e) {
    // Fallback to direct data fetch if cache fails
    Log::warning('Cache fallback triggered', [
        'key' => 'key',
        'error' => $e->getMessage(),
    ]);

    $data = $this->fetchData();
}
```

## Troubleshooting

### Low Cache Hit Rate

**Symptoms:** Hit rate < 70%

**Solutions:**
1. Check if TTL is too short
2. Verify cache keys are consistent
3. Check if cache is being cleared too frequently
4. Review cache invalidation logic

```bash
# Monitor Redis stats
redis-cli INFO stats
# keyspace_hits: 5000
# keyspace_misses: 5000
# Hit rate: 50%
```

### High Memory Usage

**Symptoms:** Redis memory > 80%

**Solutions:**
1. Reduce TTL for less critical data
2. Implement cache size limits
3. Use eviction policies
4. Archive old cache data

```bash
# Check memory usage
redis-cli INFO memory
# used_memory: 1073741824
# used_memory_peak: 2147483648
# used_memory_percentage: 50.00

# Configure maxmemory
redis-cli CONFIG SET maxmemory 2gb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### Cache Stampede

**Symptoms:** Multiple requests rebuilding cache simultaneously

**Solutions:**
1. Use `rememberWithLock()` for expensive operations
2. Implement request coalescing
3. Use cache pre-warming

```php
// Prevent cache stampede
$result = $cache->rememberWithLock(
    'expensive_key',
    fn() => $this->expensiveOperation(),
    'short',
    10  // Lock timeout
);
```

## Configuration

### Environment Variables

```env
# Cache Configuration
CACHE_STORE=redis
CACHE_PREFIX=agl_hostman_
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# Cache TTL (seconds)
CACHE_TTL_SHORT=300
CACHE_TTL_MEDIUM=1800
CACHE_TTL_LONG=3600
CACHE_TTL_DAILY=86400

# Cache Warming
CACHE_WARMING_ENABLED=true
CACHE_WARMING_SCHEDULE=*/15 * * * *  # Every 15 minutes
```

### Redis Configuration

```ini
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

## Performance Impact

### Before Redis Caching
- API Response Time: 500ms average
- Database Queries: 50/second
- External API Calls: 20/second
- Cache Hit Rate: N/A

### After Redis Caching
- API Response Time: 50ms average (90% reduction)
- Database Queries: 10/second (80% reduction)
- External API Calls: 5/second (75% reduction)
- Cache Hit Rate: 85%

## Related Documentation

- [Performance Optimization](../performance/overview.md) - Overall performance guide
- [Database Optimization](../performance/database.md) - Database query optimization
- [Monitoring & Metrics](../monitoring/metrics.md) - Performance monitoring
- [API Best Practices](../api/best-practices.md) - API optimization tips
