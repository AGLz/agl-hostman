---
name: laravel-performance-optimization
description: "Comprehensive Laravel performance optimization covering caching strategies, query optimization, eager loading, lazy evaluation, and HTTP caching. Use when API responses are slow, database queries are inefficient, or memory usage is high."
category: development
priority: P0
tags: [laravel, performance, optimization, caching]
---

# Laravel Performance Optimization Skill

## Overview

This skill provides comprehensive performance optimization strategies for Laravel applications, targeting **50-70% improvement** in response times, database efficiency, and memory usage. It integrates with existing AGL Hostman services including `DatabaseQueryOptimizer` and `RedisCacheStrategy`.

## Performance Targets

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| API Response Time | 500-2000ms | 100-300ms | **50-85%** |
| Database Query Count | 100-500 N+1 | 1-10 queries | **90% reduction** |
| Memory Usage | 256-512MB | 64-128MB | **50-75%** |
| Cache Hit Rate | 0-20% | 80-95% | **4-5x increase** |
| Throughput | 10-50 req/s | 200-500 req/s | **10-20x increase** |

## When to Use This Skill

Use this skill when:
- API endpoints are slow (>500ms response time)
- Database queries show N+1 problems (Laravel Debugbar shows 100+ queries)
- Memory usage is high (>256MB per request)
- Cache hit rate is low (<50%)
- Queue workers are processing slowly
- Server CPU usage is consistently high (>70%)

## Quick Start

### 1. Measurement & Benchmarking

First, measure current performance:

```bash
# Enable query logging
php artisan tinker
>>> DB::enableQueryLog();
>>> // Run your slow endpoint
>>> dd(DB::getQueryLog());

# Check cache statistics
php artisan tinker
>>> app(App\Services\RedisCacheStrategy::class)->getPerformanceMetrics();

# Run performance profiler
./agent/skills/development/laravel-performance-optimization/scripts/perf-profile.sh
```

### 2. Common Performance Bottlenecks

Check for these issues first:

1. **N+1 Query Problem** - Loading relationships in loops
2. **Missing Eager Loading** - Not using `with()` for relationships
3. **Excessive Data Loading** - Selecting all columns instead of specific ones
4. **No Caching** - Every request hits the database
5. **Inefficient Pagination** - Using `paginate()` on large datasets
6. **Missing Indexes** - Full table scans on filtered queries
7. **Eager Loading Too Much** - Loading unnecessary relationships

## Measurement & Profiling

### Tools & Techniques

#### 1. Laravel Debugbar

Install to visualize performance issues:

```bash
composer require barryvdh/laravel-debugbar --dev
php artisan vendor:publish --provider="Barryvdh\Debugbar\ServiceProvider"
```

Check these metrics in Debugbar:
- **Queries tab**: Look for >20 queries or duplicate queries
- **Timeline tab**: Look for >500ms total execution time
- **Memory tab**: Look for >100MB memory usage

#### 2. Telescope for Production

```bash
composer require laravel/telescope
php artisan telescope:install
php artisan migrate
```

Monitor in production at `/telescope`:
- Slow requests (>1000ms)
- Duplicate queries
- High memory allocations

#### 3. Clockwork for API Development

```bash
composer require itsgoingd/clockwork
php artisan clockwork:install
```

View in Chrome DevTools under Clockwork tab.

#### 4. Custom Performance Logging

```php
// Start timer
$start = microtime(true);
$memoryBefore = memory_get_usage();

// Your code here
$results = Model::with(['relation1', 'relation2'])->get();

// Log metrics
Log::info('Performance metrics', [
    'duration_ms' => (microtime(true) - $start) * 1000,
    'memory_mb' => (memory_get_usage() - $memoryBefore) / 1024 / 1024,
    'query_count' => count(DB::getQueryLog()),
    'result_count' => $results->count(),
]);
```

#### 5. Database Query Logging

```php
// In AppServiceProvider::boot()
if (config('app.debug')) {
    DB::listen(function ($query) {
        Log::info('Query executed', [
            'sql' => $query->sql,
            'bindings' => $query->bindings,
            'time' => $query->time . 'ms',
        ]);

        // Alert on slow queries
        if ($query->time > 100) {
            Log::warning('Slow query detected', [
                'sql' => $query->sql,
                'time' => $query->time . 'ms',
            ]);
        }
    });
}
```

#### 6. Performance Monitoring Service

Create `app/Services/PerformanceMonitor.php`:

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PerformanceMonitor
{
    private array $metrics = [];

    public function start(string $operation): self
    {
        $this->metrics[$operation] = [
            'start_time' => microtime(true),
            'start_memory' => memory_get_usage(),
            'start_queries' => count(DB::getQueryLog()),
        ];

        DB::enableQueryLog();

        return $this;
    }

    public function end(string $operation, array $context = []): void
    {
        if (!isset($this->metrics[$operation])) {
            return;
        }

        $metrics = $this->metrics[$operation];
        $duration = (microtime(true) - $metrics['start_time']) * 1000;
        $memory = (memory_get_usage() - $metrics['start_memory']) / 1024 / 1024;
        $queries = count(DB::getQueryLog()) - $metrics['start_queries'];

        $data = array_merge($context, [
            'duration_ms' => round($duration, 2),
            'memory_mb' => round($memory, 2),
            'query_count' => $queries,
        ]);

        // Log warning if slow
        if ($duration > 500) {
            Log::warning("Slow operation: {$operation}", $data);
        } else {
            Log::info("Operation: {$operation}", $data);
        }

        unset($this->metrics[$operation]);
    }
}

// Usage
app(PerformanceMonitor::class)
    ->start('api_containers_index')
    ->end('api_containers_index', ['endpoint' => '/api/containers']);
```

## Database Optimization

### N+1 Query Prevention

#### Problem: N+1 Queries

```php
// BAD: N+1 problem - 1 query for users + N queries for posts
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count(); // N additional queries
}
// Total: 1 + N queries
```

#### Solution: Eager Loading

```php
// GOOD: Eager loading - 2 queries total
$users = User::with('posts')->get();
foreach ($users as $user) {
    echo $user->posts->count(); // No additional query
}
// Total: 2 queries (users + posts)
```

### Selective Column Loading

```php
// BAD: Selects all columns
$users = User::with('posts')->get();

// GOOD: Selects only needed columns
$users = User::with(['posts:id,user_id,title'])
    ->select(['id', 'name', 'email'])
    ->get();
```

### Nested Eager Loading

```php
// Load nested relationships efficiently
$users = User::with([
    'posts.comments.user',  // Nested eager loading
    'roles.permissions',     // Multiple levels
    'profile' => function ($query) {
        $query->select('id', 'user_id', 'avatar_url');
    }
])->get();
```

### Lazy Eager Loading

```php
// Load relationships on-demand for already loaded models
$users = User::all();

// Later, if you need relationships
$users->load('posts', 'roles');

// Or with constraints
$users->load(['posts' => function ($query) {
    $query->where('published', true)->orderBy('created_at', 'desc');
}]);
```

### Preventing Lazy Loading in Production

In `AppServiceProvider`:

```php
use Illuminate\Database\Eloquent\Model;

public function boot()
{
    // Prevent N+1 in production
    if (!app()->environment('local')) {
        Model::preventLazyLoading();
    }
}
```

### Chunked Processing for Large Datasets

```php
// BAD: Loads all records into memory
User::all()->each(function ($user) {
    // Process user
});

// GOOD: Process in chunks
User::chunk(1000, function ($users) {
    foreach ($users as $user) {
        // Process user
    }
});

// BETTER: Use lazy collections for memory efficiency
User::lazy()->each(function ($user) {
    // Process user
});

// BEST: Use lazy() with chunk for large datasets
User::lazy(1000)->each(function ($user) {
    // Process user
});
```

### Efficient Aggregates

```php
// BAD: Load all records then count
$count = User::all()->count();

// GOOD: Use query builder
$count = User::count();

// For complex aggregates
$stats = User::selectRaw('
    COUNT(*) as total_users,
    SUM(CASE WHEN active = 1 THEN 1 ELSE 0 END) as active_users,
    AVG(age) as avg_age
')->first();
```

### Optimizing Subqueries

```php
// BAD: WHERE IN with subquery
$users = User::whereIn('id', function ($query) {
    $query->select('user_id')->from('posts')->where('published', true);
})->get();

// GOOD: Use JOIN
$users = User::join('posts', 'users.id', '=', 'posts.user_id')
    ->where('posts.published', true)
    ->select('users.*')
    ->distinct()
    ->get();
```

### Database Indexes

```php
// Create indexes for frequently filtered/ordered columns
Schema::table('users', function (Blueprint $table) {
    $table->index(['email', 'deleted_at']);  // Composite index
    $table->index('created_at');             // For ordering
    $table->index('status');                 // For filtering
});

// Use script to recommend indexes
./agent/skills/development/laravel-performance-optimization/scripts/perf-index-recommend.sh
```

### Query Caching

```php
// Cache query results
$users = Cache::remember('users.active', 3600, function () {
    return User::where('active', true)->get();
});

// Or use the RedisCacheStrategy service
$users = app(RedisCacheStrategy::class)->cacheDbQuery(
    'users',
    ['active' => true],
    fn() => User::where('active', true)->get(),
    'medium'
);
```

## Caching Strategies

### Cache TTL Strategy

Use the RedisCacheStrategy TTLs from `src/app/Services/RedisCacheStrategy.php`:

| Data Type | TTL | Use Case |
|-----------|-----|----------|
| **Short** | 300s (5 min) | Real-time metrics, container status |
| **Medium** | 1800s (30 min) | API responses, deployment lists |
| **Long** | 3600s (1 hour) | User permissions, configuration |
| **Daily** | 86400s (24 hours) | Reference data, statistics |
| **Weekly** | 604800s (7 days) | Static data, lookup tables |

### Query Result Caching

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

// Cache database query
$containers = $cache->cacheDbQuery(
    'lxc_containers',
    ['status' => 'running'],
    fn() => LxcContainer::where('status', 'running')->get(),
    'short'  // 5 minute TTL
);
```

### API Response Caching

```php
// Cache API responses
$cache->cacheApiResponse(
    '/api/containers',
    ['status' => 'running', 'page' => 1],
    fn() => $this->getContainersData(),
    'medium'
);
```

### External Service Caching

```php
// Cache Proxmox API responses
$nodes = $cache->cacheProxmoxResponse(
    'nodes',
    null,
    fn() => $proxmoxClient->getNodes(),
    'short'
);

// Cache Dokploy responses
$apps = $cache->cacheDokployResponse(
    'applications',
    null,
    fn() => $dokployClient->getApplications(),
    'medium'
);

// Cache Harbor responses
$projects = $cache->cacheHarborResponse(
    'projects',
    null,
    fn() => $harborClient->getProjects(),
    'long'
);
```

### Cache Invalidation

```php
// Invalidate by resource
$cache->invalidateResource('containers', '101');

// Invalidate all containers
$cache->invalidateContainers();

// Invalidate user-specific cache
$cache->invalidateUser($userId);
```

### Model Events for Cache Invalidation

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
}
```

### Cache Tags

```php
// Tag related cache keys
Cache::tags(['containers', 'server_' . $serverId])
    ->remember('containers_' . $serverId, 3600, function () {
        return LxcContainer::where('server_id', $serverId)->get();
    });

// Flush all tagged cache
Cache::tags(['containers'])->flush();
```

### Cache Warming

```bash
# Run cache warming script
./agent/skills/development/laravel-performance-optimization/scripts/perf-cache-warm.sh
```

## Eager Loading

### Basic Eager Loading

```php
// Load relationships with main query
$users = User::with('posts')->get();

// Multiple relationships
$users = User::with(['posts', 'comments', 'roles'])->get();
```

### Nested Eager Loading

```php
// Load nested relationships
$posts = Post::with(['user.roles', 'comments.user'])->get();
```

### Constrained Eager Loading

```php
// Eager load with constraints
$users = User::with(['posts' => function ($query) {
    $query->where('published', true)
          ->orderBy('created_at', 'desc')
          ->limit(10);
}])->get();
```

### Lazy Eager Loading

```php
// Load relationships after main query
$users = User::all();
$users->load('posts');

// With constraints
$users->load(['posts' => function ($query) {
    $query->where('published', true);
}]);
```

### Preventing Lazy Loading

In `config/app.php` or `AppServiceProvider`:

```php
Model::preventLazyLoading(!app()->isProduction());
```

### Eager Loading Pagination

```php
// Paginate with eager loading
$posts = Post::with('user')
    ->orderBy('created_at', 'desc')
    ->paginate(20);
```

## Lazy Collections

### Memory-Efficient Processing

```php
// Use lazy() for large datasets
User::lazy()->each(function ($user) {
    // Process user one at a time
});

// Chunk size control
User::lazy(500)->each(function ($user) {
    // Process in chunks of 500
});
```

### Lazy Collection Methods

```php
// Filter and map without loading all records
$activeUsers = User::lazy()
    ->filter(fn($user) => $user->is_active)
    ->map(fn($user) => [
        'id' => $user->id,
        'name' => $user->name,
    ])
    ->take(100);
```

### Cursor Pagination

Use the `DatabaseQueryOptimizer::cursorPaginate()` method:

```php
$optimizer = app(DatabaseQueryOptimizer::class);

$result = $optimizer->cursorPaginate(
    LxcContainer::query()->select('id', 'name', 'vmid'),
    50,  // per page
    $cursor  // next cursor
);

// Returns: ['data', 'next_cursor', 'has_more']
```

## API Optimization

### Pagination

```php
// Cursor-based pagination (better for large datasets)
$containers = LxcContainer::orderBy('id')
    ->cursorPaginate(50);

// Traditional pagination
$containers = LxcContainer::orderBy('created_at', 'desc')
    ->paginate(50);

// Simple pagination (faster, no total count)
$containers = LxcContainer::orderBy('created_at', 'desc')
    ->simplePaginate(50);
```

### API Resource Optimization

```php
// Use API resources to format responses efficiently
use App\Http\Resources\ContainerResource;

// Single item
return new ContainerResource($container);

// Collection
return ContainerResource::collection($containers);

// With pagination
return ContainerResource::collection($containers)->additional([
    'meta' => [
        'total' => $containers->total(),
        'per_page' => $containers->perPage(),
    ]
]);
```

### Efficient Filtering

```php
// Build query with filters
$query = LxcContainer::query();

if ($request->has('status')) {
    $query->where('status', $request->status);
}

if ($request->has('server_id')) {
    $query->where('proxmox_server_id', $request->server_id);
}

if ($request->has('search')) {
    $query->where(function ($q) use ($request) {
        $q->where('name', 'like', '%' . $request->search . '%')
          ->orWhere('hostname', 'like', '%' . $request->search . '%');
    });
}

return $query->paginate(50);
```

### Sorting Optimization

```php
// Use database indexes for sorting
$query = LxcContainer::query();

$allowedSorts = ['name', 'created_at', 'status', 'vmid'];

if ($request->has('sort') && in_array($request->sort, $allowedSorts)) {
    $direction = $request->get('direction', 'asc');
    $query->orderBy($request->sort, $direction);
}

return $query->paginate(50);
```

### Limit Response Size

```php
// Always limit response size
$containers = LxcContainer::with(['server:id,name,host'])
    ->select(['id', 'name', 'status', 'vmid', 'proxmox_server_id'])
    ->limit(100)
    ->get();
```

## HTTP Caching

### ETag Support

```php
// Generate ETag for response
use Illuminate\Support\Facades\Cache;

public function show($id)
{
    $container = LxcContainer::findOrFail($id);

    $etag = md5($container->toJson());

    if (request()->getETags() && in_array($etag, request()->getETags())) {
        return response()->noContent()->setEtag($etag);
    }

    return response()->json($container)->setEtag($etag);
}
```

### Last-Modified Headers

```php
public function index()
{
    $lastModified = LxcContainer::max('updated_at');

    if (request()->header('If-Modified-Since') &&
        strtotime(request()->header('If-Modified-Since')) >= strtotime($lastModified)) {
        return response()->noContent()->setLastModified($lastModified);
    }

    $containers = LxcContainer::paginate(50);

    return response()->json($containers)->setLastModified($lastModified);
}
```

### Cache-Control Headers

```php
// Public cache
return response()->json($data)
    ->header('Cache-Control', 'public, max-age=300');  // 5 minutes

// Private cache
return response()->json($data)
    ->header('Cache-Control', 'private, max-age=3600');  // 1 hour

// No cache
return response()->json($data)
    ->header('Cache-Control', 'no-cache, no-store, must-revalidate');
```

### HTTP Cache Middleware

```php
// Create middleware
namespace App\Http\Middleware;

class CacheControl
{
    public function handle($request, Closure $next, $ttl = 300)
    {
        $response = $next($request);

        if ($request->isMethod('GET')) {
            $response->header('Cache-Control', "public, max-age={$ttl}");
        }

        return $response;
    }
}

// Apply to routes
Route::get('/api/containers', [ContainerController::class, 'index'])
    ->middleware('cache.control:300');
```

## Worker Optimization

### Queue Configuration

In `config/queue.php`:

```php
'connections' => [
    'redis' => [
        'driver' => 'redis',
        'connection' => 'default',
        'queue' => env('REDIS_QUEUE', 'default'),
        'retry_after' => 90,  // Retry after 90 seconds
        'block_for' => null,
        'after_commit' => false,  // Don't dispatch until after commit
    ],
],

'workers' => [
    'redis' => [
        'driver' => 'redis',
        'queue' => ['default', 'high', 'low'],
        'balance' => 'auto',  // Auto-balance work
        'max_tries' => 3,
        'timeout' => 60,  // Max job time
        'sleep' => 3,
        'max_jobs' => 0,  // Unlimited jobs per worker
        'memory' => 128,  // 128MB memory limit
    ],
],
```

### Supervisor Configuration

In `/etc/supervisor/conf.d/laravel-worker.conf`:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/html/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
numprocs=4
redirect_stderr=true
stdout_logfile=/var/www/html/storage/logs/worker.log
stopwaitsecs=3600
```

### Batch Processing

```php
use Illuminate\Bus\Batch;
use Illuminate\Support\Facades\Bus;

use App\Jobs\ProcessContainer;

$containers = LxcContainer::all();

$batch = Bus::batch(
    $containers->map(fn($c) => new ProcessContainer($c))
)->then(function (Batch $batch) {
    // All jobs completed successfully
})->catch(function (Batch $batch, Throwable $e) {
    // First batch failure detected
})->finally(function (Batch $batch) {
    // Batch finished
})->dispatch();
```

### Job Chaining

```php
use App\Jobs\DeployApplication;
use App\Jobs\RunTests;
use App\Jobs\NotifyDeployment;

DeployApplication::withChain([
    new RunTests($deployment),
    new NotifyDeployment($deployment),
])->dispatch();
```

### Rate Limiting Jobs

```php
use Illuminate\Bus\Batch;
use Illuminate\Support\Facades\RateLimiter;

class ProcessContainer implements ShouldQueue
{
    public $tries = 3;
    public $timeout = 120;

    public function middleware()
    {
        return [new RateLimited('proxmox-api')];
    }
}
```

Define rate limit in `AppServiceProvider`:

```php
RateLimiter::for('proxmox-api', function (Job $job) {
    return Limit::perMinute(60);
});
```

## Advanced Optimization

### Octane for High Performance

```bash
composer require laravel/octane

# Start Octane server
php artisan octane:start

# Use RoadRunner
php artisan octane:start --server=roadrunner

# Use Swoole
php artisan octane:start --server=swoole
```

### Database Connection Pooling

```php
// In config/database.php
'connections' => [
    'mysql' => [
        'driver' => 'mysql',
        'pool' => [
            'max_connections' => 100,
            'min_connections' => 10,
        ],
    ],
],
```

### Read/Write Splitting

```php
'mysql' => [
    'read' => [
        'host' => [
            '192.168.1.1',
            '192.168.1.2',
        ],
    ],
    'write' => [
        'host' => [
            '196.168.1.3',
        ],
    ],
    'sticky' => true,  // Ensure subsequent reads go to write server
],
```

### Full-Page Caching

```bash
# Cache entire routes
php artisan route:cache

# Cache configuration
php artisan config:cache

# Cache views
php artisan view:cache

# Clear all caches
php artisan cache:clear
php artisan route:clear
php artisan config:clear
php artisan view:clear
```

## Scripts

Run the provided scripts for automated optimization:

```bash
# Profile application performance
./agent/skills/development/laravel-performance-optimization/scripts/perf-profile.sh

# Analyze queries for N+1 problems
./agent/skills/development/laravel-performance-optimization/scripts/perf-query-analyzer.sh

# Warm up cache
./agent/skills/development/laravel-performance-optimization/scripts/perf-cache-warm.sh

# Get index recommendations
./agent/skills/development/laravel-performance-optimization/scripts/perf-index-recommend.sh
```

## References

- `references/optimization-patterns.md` - Common optimization patterns
- `references/laravel-caching-guide.md` - Complete caching strategies

## Monitoring & Metrics

Use existing monitoring from `src/config/monitoring.php`:

```php
// Monitoring thresholds
'thresholds' => [
    'cpu' => ['warning' => 70, 'critical' => 85],
    'memory' => ['warning' => 80, 'critical' => 90],
    'latency' => ['warning' => 50, 'critical' => 150],
],
```

## Performance Checklist

Before deploying to production:

- [ ] Enable eager loading for all relationships
- [ ] Add database indexes for frequently filtered columns
- [ ] Implement caching with appropriate TTLs
- [ ] Enable HTTP caching headers (ETag, Cache-Control)
- [ ] Use pagination or cursor pagination for large datasets
- [ ] Optimize N+1 queries (verify with Debugbar)
- [ ] Enable query caching for expensive operations
- [ ] Use lazy collections for memory-intensive operations
- [ ] Configure queue workers properly
- [ ] Enable Octane for high-performance applications
- [ ] Set up monitoring and alerting
- [ ] Profile application with Blackfire/XHProf
- [ ] Test load capacity with Apache Bench/Locust

## Expected Improvements

Following these optimization strategies, you should achieve:

- **50-85% faster** API response times
- **90% reduction** in database queries
- **50-75% reduction** in memory usage
- **10-20x increase** in throughput capacity
- **80-95%** cache hit rate
- **<100ms** p95 response time for most endpoints

## Integration with AGL Hostman

This skill integrates with existing AGL Hostman services:

- `DatabaseQueryOptimizer` - Optimized query methods
- `RedisCacheStrategy` - Multi-layer caching with Redis
- `PerformanceTrend` model - Performance metrics tracking
- `Alert` model - Performance alerting

See the service implementations for examples:
- `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/DatabaseQueryOptimizer.php`
- `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/RedisCacheStrategy.php`
