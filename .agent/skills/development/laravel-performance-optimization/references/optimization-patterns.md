# Laravel Optimization Patterns

This document provides common optimization patterns used in Laravel applications, with examples from the AGL Hostman codebase.

## Table of Contents

1. [Eager Loading Patterns](#eager-loading-patterns)
2. [Query Optimization Patterns](#query-optimization-patterns)
3. [Caching Patterns](#caching-patterns)
4. [Lazy Collection Patterns](#lazy-collection-patterns)
5. [API Optimization Patterns](#api-optimization-patterns)
6. [Memory Optimization Patterns](#memory-optimization-patterns)

## Eager Loading Patterns

### Basic Eager Loading

Load relationships with the main query to prevent N+1 problems:

```php
// BAD: N+1 query problem
$containers = LxcContainer::all();
foreach ($containers as $container) {
    echo $container->server->name;  // N additional queries
}

// GOOD: Eager loading
$containers = LxcContainer::with('server')->get();
foreach ($containers as $container) {
    echo $container->server->name;  // No additional query
}
```

**From AGL Hostman**: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/DatabaseQueryOptimizer.php`

```php
public function getContainersOptimized(array $filters = []): Collection
{
    return LxcContainer::with([
        'server:id,name,host,status',  // Select only needed fields
        'healthLogs' => function ($query) {
            $query->latest()->limit(10);  // Limit related records
        },
    ])
    ->select([
        'id', 'vmid', 'name', 'hostname', 'status',
        'cores', 'memory_mb', 'disk_gb',
        'proxmox_server_id', 'created_at', 'updated_at'
    ])
    ->get();
}
```

### Nested Eager Loading

Load nested relationships:

```php
$users = User::with([
    'posts.comments.user',  // Three levels deep
    'roles.permissions',    // Multiple levels
])->get();
```

### Constrained Eager Loading

Load relationships with constraints:

```php
$containers = LxcContainer::with([
    'healthLogs' => function ($query) {
        $query->latest()->limit(10);
    }
])->get();
```

### Lazy Eager Loading

Load relationships after the main query:

```php
$containers = LxcContainer::all();

// Later, if needed
$containers->load('server', 'healthLogs');

// With constraints
$containers->load(['healthLogs' => function ($query) {
    $query->where('status', 'alert')->latest()->limit(5);
}]);
```

## Query Optimization Patterns

### Selective Column Loading

Only select columns you need:

```php
// BAD: Selects all columns
$users = User::all();

// GOOD: Selects only needed columns
$users = User::select(['id', 'name', 'email'])->get();
```

**From AGL Hostman**:

```php
return DokployDeployment::with([
    'application:id,name,type,project_id',
    'application.user:id,name,email',
])
->select([
    'id', 'application_id', 'status', 'title',
    'commit_hash', 'branch', 'triggered_by',
    'duration_seconds', 'started_at', 'completed_at',
    'created_at', 'updated_at'
])
->paginate($perPage);
```

### Chunked Processing

Process large datasets in chunks:

```php
// BAD: Loads all records
User::all()->each(function ($user) {
    // Process user
});

// GOOD: Processes in chunks
User::chunk(1000, function ($users) {
    foreach ($users as $user) {
        // Process user
    }
});
```

**From AGL Hostman**:

```php
public function chunkedProcessing(Builder $query, int $chunkSize, callable $callback): void
{
    $query->chunk($chunkSize, function ($records) use ($callback) {
        $callback($records);
    });
}
```

### Efficient Aggregates

Use database aggregates instead of loading records:

```php
// BAD
$count = User::all()->count();

// GOOD
$count = User::count();
```

**From AGL Hostman**:

```php
public function getDeploymentStatistics(int $days = 30): array
{
    $stats = DokployDeployment::where('created_at', '>=', now()->subDays($days))
        ->selectRaw('
            COUNT(*) as total,
            SUM(CASE WHEN status = "success" THEN 1 ELSE 0 END) as successful,
            SUM(CASE WHEN status = "failed" THEN 1 ELSE 0 END) as failed,
            AVG(CASE WHEN status = "success" THEN duration_seconds END) as avg_duration
        ')
        ->first();

    return [
        'total' => (int) ($stats->total ?? 0),
        'successful' => (int) ($stats->successful ?? 0),
        'failed' => (int) ($stats->failed ?? 0),
        'success_rate' => $stats->total > 0
            ? round((($stats->successful ?? 0) / $stats->total) * 100, 2)
            : 0,
        'avg_duration_seconds' => (int) ($stats->avg_duration ?? 0),
    ];
}
```

### Cursor-based Pagination

For large datasets, use cursor pagination:

```php
// GOOD: Cursor pagination
$containers = LxcContainer::orderBy('id')->cursorPaginate(50);

// Better: Custom cursor pagination
$optimizer = app(DatabaseQueryOptimizer::class);
$result = $optimizer->cursorPaginate(
    LxcContainer::query(),
    50,
    $cursor
);
// Returns: ['data', 'next_cursor', 'has_more']
```

**From AGL Hostman**:

```php
public function cursorPaginate(Builder $query, int $perPage = 50, ?string $cursor = null): array
{
    if ($cursor) {
        $query->where('id', '>', $cursor);
    }

    $results = $query->orderBy('id', 'asc')
        ->limit($perPage + 1)
        ->get();

    $hasMore = $results->count() > $perPage;
    $items = $results->take($perPage);
    $nextCursor = $hasMore ? $items->last()->id : null;

    return [
        'data' => $items,
        'next_cursor' => $nextCursor,
        'has_more' => $hasMore,
    ];
}
```

### Upsert for Batch Operations

Use upsert for batch insert/update:

```php
DB::table('lxc_containers')->upsert(
    $data,
    ['vmid'],  // Unique constraint
    ['name', 'hostname', 'status', 'updated_at']  // Columns to update
);
```

## Caching Patterns

### Query Result Caching

Cache expensive queries:

```php
$users = Cache::remember('users.active', 3600, function () {
    return User::where('active', true)->get();
});
```

**From AGL Hostman**: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/RedisCacheStrategy.php`

```php
public function cacheDbQuery(
    string $table,
    array $conditions,
    Closure $callback,
    ?string $ttl = 'short'
): mixed {
    $key = $this->makeDbKey($table, $conditions);
    $tags = $this->getTableTags($table);
    $resolvedTtl = $this->resolveTtl($ttl);

    return $this->cacheService->remember(
        $key,
        $callback,
        $resolvedTtl,
        $tags
    );
}
```

### Cache Tags

Use tags for hierarchical invalidation:

```php
Cache::tags(['containers', 'server_' . $serverId])
    ->remember('containers_' . $serverId, 3600, function () {
        return LxcContainer::where('server_id', $serverId)->get();
    });

// Flush all container cache
Cache::tags(['containers'])->flush();
```

**From AGL Hostman**:

```php
private const TAG_CONTAINERS = 'containers';
private const TAG_DEPLOYMENTS = 'deployments';
private const TAG_SERVERS = 'servers';

private function extractTagsFromEndpoint(string $endpoint): array
{
    $tags = [];

    if (Str::contains($endpoint, 'containers')) {
        $tags[] = self::TAG_CONTAINERS;
    }

    if (Str::contains($endpoint, 'deployments')) {
        $tags[] = self::TAG_DEPLOYMENTS;
    }

    return $tags;
}
```

### Cache Invalidation

Invalidate cache on model changes:

```php
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

### TTL Strategy

Use appropriate TTLs for different data types:

**From AGL Hostman**:

```php
private const TTL_SHORT = 300;        // 5 minutes - Real-time data
private const TTL_MEDIUM = 1800;      // 30 minutes - Semi-static data
private const TTL_LONG = 3600;        // 1 hour - Static data
private const TTL_DAILY = 86400;      // 24 hours - Rarely changing data
private const TTL_WEEKLY = 604800;    // 7 days - Reference data

private function resolveTtl(?string $ttl): int
{
    return match($ttl) {
        'short' => self::TTL_SHORT,
        'medium' => self::TTL_MEDIUM,
        'long' => self::TTL_LONG,
        'day' => self::TTL_DAILY,
        'week' => self::TTL_WEEKLY,
        default => self::TTL_MEDIUM,
    };
}
```

## Lazy Collection Patterns

### Memory-Efficient Processing

Use lazy collections for large datasets:

```php
// BAD: Loads all into memory
User::all()->each(function ($user) {
    // Process user
});

// GOOD: Lazy collection
User::lazy()->each(function ($user) {
    // Process user
});

// BETTER: With chunk size
User::lazy(500)->each(function ($user) {
    // Process user
});
```

### Filtering and Mapping

Chain operations without loading all records:

```php
$activeUsers = User::lazy()
    ->filter(fn($user) => $user->is_active)
    ->map(fn($user) => [
        'id' => $user->id,
        'name' => $user->name,
    ])
    ->take(100);
```

## API Optimization Patterns

### API Resources

Use API resources to format responses:

```php
use App\Http\Resources\ContainerResource;

return ContainerResource::collection($containers);
```

### Pagination

Implement efficient pagination:

```php
// Cursor-based pagination (better)
$containers = LxcContainer::orderBy('id')
    ->cursorPaginate(50);

// Traditional pagination
$containers = LxcContainer::orderBy('created_at', 'desc')
    ->paginate(50);

// Simple pagination (faster, no total)
$containers = LxcContainer::orderBy('created_at', 'desc')
    ->simplePaginate(50);
```

### Response Compression

Compress API responses:

```php
return response()->json($data)
    ->header('Content-Encoding', 'gzip');
```

### HTTP Caching

Add cache headers:

```php
return response()->json($data)
    ->header('Cache-Control', 'public, max-age=300')
    ->setEtag(md5(json_encode($data)));
```

## Memory Optimization Patterns

### Prevent Lazy Loading

Prevent lazy loading in production:

```php
// In AppServiceProvider
Model::preventLazyLoading(!app()->isProduction());
```

### Disable Query Logging

Disable query logging in production:

```php
// In AppServiceProvider
if (!app()->isProduction()) {
    DB::listen(function ($query) {
        Log::info('Query executed', [
            'sql' => $query->sql,
            'time' => $query->time . 'ms',
        ]);
    });
}
```

### Memory Limit

Set memory limit for workers:

```php
// In supervisor config
'memory' => 128,  // 128MB memory limit
```

## Performance Monitoring

### Query Timing

Monitor query execution time:

```php
DB::listen(function ($query) {
    if ($query->time > 100) {
        Log::warning('Slow query detected', [
            'sql' => $query->sql,
            'time' => $query->time . 'ms',
        ]);
    }
});
```

### Performance Metrics

Track performance metrics:

```php
$start = microtime(true);
$memoryBefore = memory_get_usage();

// Your code here

$duration = (microtime(true) - $start) * 1000;
$memory = (memory_get_usage() - $memoryBefore) / 1024 / 1024;

Log::info('Performance metrics', [
    'duration_ms' => $duration,
    'memory_mb' => $memory,
]);
```

## Best Practices Summary

1. **Always eager load relationships** accessed in views/loops
2. **Select only needed columns** instead of using `*`
3. **Use chunking or lazy collections** for large datasets
4. **Implement caching** with appropriate TTLs
5. **Use cursor pagination** for large datasets
6. **Add database indexes** for filtered/ordered columns
7. **Monitor query performance** with logging
8. **Prevent lazy loading** in production
9. **Use API resources** for consistent responses
10. **Profile before optimizing** - measure first!

## Expected Improvements

Following these patterns should result in:

- **90% reduction** in database queries (N+1 prevention)
- **50-70% faster** response times (caching, indexing)
- **75% reduction** in memory usage (lazy collections)
- **10-20x increase** in throughput capacity
- **80-95%** cache hit rate (with proper caching)

## References

- AGL Hostman DatabaseQueryOptimizer: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/DatabaseQueryOptimizer.php`
- AGL Hostman RedisCacheStrategy: `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/RedisCacheStrategy.php`
- Laravel Documentation: https://laravel.com/docs/eloquent
- Laravel Debugbar: https://github.com/barryvdh/laravel-debugbar
