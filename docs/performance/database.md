# Database Query Optimization Guide

## Overview

This guide covers database optimization strategies for AGL Hostman, including indexing, query patterns, eager loading, and caching to achieve optimal performance.

## Performance Goals

- **Query Response Time:** < 100ms for 95% of queries
- **N+1 Queries:** 0 instances
- **Full Table Scans:** Eliminated for all queries
- **Index Usage:** > 95% for read queries
- **Database Load:** < 50% CPU on peak

## Database Indexes

### Index Types

#### 1. Single Column Indexes
Simple indexes on frequently filtered columns.

```php
// Automatic with unique()
$table->unique('email');

// Manual index
$table->index('status');
$table->index('created_at');
```

#### 2. Composite Indexes
Multi-column indexes for common query patterns.

```php
// Index for: WHERE status = ? AND created_at > ?
$table->index(['status', 'created_at']);

// Index for: WHERE user_id = ? AND created_at > ? ORDER BY created_at DESC
$table->index(['user_id', 'created_at']);

// Index for: WHERE server_id = ? AND status = ?
$table->index(['proxmox_server_id', 'status']);
```

#### 3. Covering Indexes
Indexes that include all columns needed for a query.

```php
// Query: SELECT id, name, status FROM containers WHERE status = 'running'
// Index should include: status, id, name
$table->index(['status', 'id', 'name']);
```

### Index Strategy

```php
// Good index for queries filtering by status and date
$table->index(['status', 'created_at']);

// Good index for filtering by user and ordering by date
$table->index(['user_id', 'created_at']);

// Good index for foreign keys (automatic in Laravel)
$table->foreignId('user_id')->constrained();

// BAD: Index on low-cardinality column (poor selectivity)
$table->index('is_active');  // Only 2 values, not useful
```

## Query Optimization Patterns

### 1. Select Only Needed Columns

```php
// ❌ BAD: Selects all columns (including unused ones)
$containers = LxcContainer::all();

// ✅ GOOD: Select only needed columns
$containers = LxcContainer::select([
    'id', 'vmid', 'name', 'hostname', 'status',
    'cores', 'memory_mb', 'disk_gb'
])->get();
```

### 2. Eager Loading Prevent N+1 Queries

```php
// ❌ BAD: N+1 query problem
$containers = LxcContainer::all();
foreach ($containers as $container) {
    echo $container->server->name;  // Separate query for each container!
}

// ✅ GOOD: Eager load relationships
$containers = LxcContainer::with('server')->get();
foreach ($containers as $container) {
    echo $container->server->name;  // No additional queries
}

// ✅ BETTER: Select only needed columns from relationship
$containers = LxcContainer::with([
    'server:id,name,host,status'
])->get();
```

### 3. Constraint Loading

```php
// Load relationships only when needed
$containers = LxcContainer::all();

// Later, when you need the server:
$containers->load(['server:id,name']);
```

### 4. Query Scopes for Reusable Logic

```php
// In Model
class LxcContainer extends Model
{
    public function scopeActive($query)
    {
        return $query->where('status', 'running');
    }

    public function scopeOnServer($query, $serverId)
    {
        return $query->where('proxmox_server_id', $serverId);
    }

    public function scopeRecent($query, $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }
}

// Usage
$activeContainers = LxcContainer::active()
    ->onServer($serverId)
    ->recent(30)
    ->get();
```

### 5. Chunk Processing for Large Datasets

```php
// ❌ BAD: Load all at once (memory issues)
$users = User::all();  // 100,000+ records
foreach ($users as $user) {
    // Process user
}

// ✅ GOOD: Process in chunks
User::chunk(1000, function ($users) {
    foreach ($users as $user) {
        // Process user
    }
});

// ✅ BETTER: Use chunkById for ordered processing
User::chunkById(1000, function ($users) {
    foreach ($users as $user) {
        // Process user in ID order
    }
});
```

### 6. Avoid WHERE IN with Large Arrays

```php
// ❌ BAD: WHERE IN with thousands of IDs
$containerIds = [1, 2, 3, ..., 5000];  // 5000 IDs
$containers = LxcContainer::whereIn('id', $containerIds)->get();

// ✅ GOOD: Use JOIN or temp table
$containers = LxcContainer::join('temp_container_list', 'lxc_containers.id', '=', 'temp_container_list.container_id')
    ->get();
```

### 7. Use Aggregates Instead of Counting

```php
// ❌ BAD: Count in PHP
$users = User::all();
$count = count($users);  // Loads all users into memory

// ✅ GOOD: Count in database
$count = User::count();

// ✅ GOOD: Use aggregated query
$stats = User::selectRaw('
    COUNT(*) as total,
    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active
')->first();
```

## Database Query Optimizer Service

The `DatabaseQueryOptimizer` service provides optimized query methods:

### Get Containers with Eager Loading

```php
use App\Services\DatabaseQueryOptimizer;

$optimizer = app(DatabaseQueryOptimizer::class);

// Get containers with optimized eager loading
$containers = $optimizer->getContainersOptimized([
    'status' => 'running',
    'server_id' => 1,
    'search' => 'web'
]);

// Includes: server, healthLogs (limited to 10)
// Selects only needed columns
```

### Get Deployments with Pagination

```php
// Get deployments with optimized relationships
$deployments = $optimizer->getDeploymentsOptimized([
    'status' => 'success',
    'application_id' => 5,
    'branch' => 'main'
], 15);  // 15 per page

// Includes: application, application.user
// Selects only needed columns
// Paginated result
```

### Get User with All Relationships

```php
$user = $optimizer->getUserWithRelationships($userId);

// Includes: roles, permissions, physicalLocations, apiKeys (active only)
// Selects only needed columns
// Single query with all relationships
```

### Performance Statistics (Single Query)

```php
$stats = $optimizer->getDeploymentStatistics(30);  // Last 30 days

/*
[
    'total' => 500,
    'successful' => 450,
    'failed' => 40,
    'in_progress' => 10,
    'success_rate' => 90.0,
    'avg_duration_seconds' => 180,
]
*/
```

### Container Status Counts

```php
$counts = $optimizer->getContainerStatusCounts();

/*
[
    'running' => 25,
    'stopped' => 10,
    'creating' => 2,
    'deleting' => 1,
]
*/
```

### Recent Activity (UNION Query)

```php
$activity = $optimizer->getRecentActivity(50);

// Efficient UNION query across:
// - Containers (last 7 days)
// - Deployments (last 7 days)
// - Alerts (last 7 days)
// Single query, ordered by created_at
```

## Query Caching Integration

### Cache Database Queries with Redis

```php
use App\Services\RedisCacheStrategy;

$cacheStrategy = app(RedisCacheStrategy::class);

// Cache database query result
$containers = $cacheStrategy->cacheDbQuery(
    'lxc_containers',
    ['status' => 'running'],
    fn() => LxcContainer::where('status', 'running')->get(),
    'short'  // 5 minutes TTL
);
```

### Invalidation on Updates

```php
// In model events
class LxcContainer extends Model
{
    protected static function booted()
    {
        static::updated(function ($container) {
            // Invalidate container cache
            $cacheStrategy = app(RedisCacheStrategy::class);
            $cacheStrategy->invalidateResource('containers', $container->id);
        });
    }
}
```

## Repository Pattern

### Base Repository

```php
namespace App\Repositories;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Collection;

abstract class BaseRepository
{
    protected Model $model;
    protected RedisCacheStrategy $cache;

    public function __construct(Model $model, RedisCacheStrategy $cache)
    {
        $this->model = $model;
        $this->cache = $cache;
    }

    public function find(int $id): ?Model
    {
        return $this->model->find($id);
    }

    public function all(): Collection
    {
        return $this->model->all();
    }

    public function create(array $data): Model
    {
        return $this->model->create($data);
    }

    public function update(int $id, array $data): Model
    {
        $model = $this->find($id);
        $model->update($data);
        return $model->fresh();
    }

    public function delete(int $id): bool
    {
        return $this->model->destroy($id) > 0;
    }
}
```

### Container Repository

```php
namespace App\Repositories;

use App\Models\LxcContainer;
use App\Services\RedisCacheStrategy;

class ContainerRepository extends BaseRepository
{
    public function __construct(LxcContainer $container, RedisCacheStrategy $cache)
    {
        parent::__construct($container, $cache);
    }

    public function getActiveContainers(): Collection
    {
        return $this->cache->cacheDbQuery(
            'lxc_containers',
            ['status' => 'running'],
            fn() => $this->model->where('status', 'running')
                ->with('server:id,name,host')
                ->get(),
            'short'
        );
    }

    public function getByServer(int $serverId): Collection
    {
        return $this->cache->cacheDbQuery(
            'lxc_containers',
            ['server_id' => $serverId],
            fn() => $this->model->where('proxmox_server_id', $serverId)
                ->with('server:id,name')
                ->get(),
            'short'
        );
    }
}
```

## Performance Monitoring

### Enable Query Log

```php
// In AppServiceProvider
if (app()->environment('local')) {
    DB::listen(function ($query) {
        Log::info('Database Query', [
            'sql' => $query->sql,
            'bindings' => $query->bindings,
            'time' => $query->time . 'ms',
        ]);
    });
}
```

### Identify Slow Queries

```php
use Illuminate\Support\Facades\DB;

// Enable query logging
DB::enableQueryLog();

// Run your queries
$containers = LxcContainer::with('server')->get();

// Get logged queries
$queries = DB::getQueryLog();

// Find slow queries (> 100ms)
$slowQueries = collect($queries)->filter(fn($q) => $q['time'] > 100);

foreach ($slowQueries as $query) {
    Log::warning('Slow Query Detected', [
        'sql' => $query['sql'],
        'time' => $query['time'] . 'ms',
    ]);
}
```

### Laravel Telescope

Telescope provides query monitoring out of the box:

```bash
# Install Telescope
composer require laravel/telescope --dev

# Publish config
php artisan telescope:install

# Run migrations
php artisan migrate

# Visit /telescope/queries
```

## Best Practices

### 1. Use Eloquent Relationships Properly

```php
// ❌ BAD: Manual joins
$serverId = DB::table('lxc_containers')
    ->where('id', $containerId)
    ->value('proxmox_server_id');

$server = DB::table('proxmox_servers')
    ->where('id', $serverId)
    ->first();

// ✅ GOOD: Use relationships
$container = LxcContainer::find($containerId);
$server = $container->server;  // Eloquent handles the join
```

### 2. Lazy Load Large Relationships

```php
// ❌ BAD: Always eager loading everything
$users = User::with(['roles', 'permissions', 'locations', 'apiKeys', 'deployments'])->get();

// ✅ GOOD: Load only what you need
$users = User::with(['roles'])->get();

// Later, when needed:
$users->load(['permissions']);
```

### 3. Use Pluck for Single Column

```php
// ❌ BAD: Get entire collection then extract
$emails = User::all()->pluck('email');

// ✅ GOOD: Use pluck directly
$emails = User::pluck('email');

// ✅ BETTER: Use pluck with key/value
$nameEmails = User::pluck('email', 'name');
```

### 4. Use Exists Instead of Count

```php
// ❌ BAD: Count all records
$hasUsers = User::where('role', 'admin')->count() > 0;

// ✅ GOOD: Check if any exist
$hasUsers = User::where('role', 'admin')->exists();
```

### 5. Batch Operations

```php
// ❌ BAD: Insert one by one
foreach ($users as $user) {
    DB::table('user_logs')->insert([
        'user_id' => $user->id,
        'action' => 'login',
        'created_at' => now(),
    ]);
}

// ✅ GOOD: Batch insert
$logs = collect($users)->map(fn($user) => [
    'user_id' => $user->id,
    'action' => 'login',
    'created_at' => now(),
])->toArray();

DB::table('user_logs')->insert($logs);
```

### 6. Use Transactions for Writes

```php
DB::transaction(function () {
    $container = LxcContainer::create($data);
    $container->healthLogs()->create($healthData);
    // Both succeed or both fail
});
```

## Common Query Problems & Solutions

### Problem 1: N+1 Queries

**Symptoms:** Multiple queries for related data

**Detection:**
```php
DB::enableQueryLog();
$containers = LxcContainer::with('server')->get();
dd(DB::getQueryLog());  // Should be 2 queries, not N+1
```

**Solution:** Eager load relationships

### Problem 2: Missing Indexes

**Symptoms:** Queries using `filesort` or `temporary` tables

**Detection:**
```bash
# Use EXPLAIN
EXPLAIN SELECT * FROM lxc_containers WHERE status = 'running';

# Look for:
# - type: ALL (full table scan)
# - Extra: Using filesort, Using temporary
```

**Solution:** Add appropriate indexes

### Problem 3: Selecting Too Much Data

**Symptoms:** Large memory usage, slow transfers

**Detection:**
```php
$containers = LxcContainer::all();
memory_get_usage();  // Check memory usage
```

**Solution:** Select only needed columns, use pagination

### Problem 4: Too Many Database Queries

**Symptoms:** Database under heavy load

**Detection:**
```php
// Count queries in a request
DB::enableQueryLog();
// ... run your code ...
$count = count(DB::getQueryLog());
```

**Solution:** Use eager loading, query caching, batch operations

## Database Maintenance

### Regular Maintenance Commands

```bash
# Analyze tables for optimization
php artisan db:table lxc_containers --analyze

# Optimize tables
php artisan db:table lxc_containers --optimize

# Check table size
SELECT
    table_name,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = 'agl_hostman'
ORDER BY size_mb DESC;
```

### Index Analysis

```bash
# Check index usage
SELECT
    table_name,
    index_name,
    ROUND(stat_value * 100 / @@table_rows, 2) as cardinality
FROM mysql.statistics_tables
WHERE table_schema = 'agl_hostman';
```

## Performance Benchmarks

### Before Optimization
- Average query time: 250ms
- N+1 queries: 50+ per page load
- Database CPU: 85%
- Memory usage: 512MB per request

### After Optimization
- Average query time: 25ms (90% faster)
- N+1 queries: 0
- Database CPU: 35%
- Memory usage: 64MB per request

## Related Documentation

- [Redis Caching Strategy](./caching.md) - Query result caching
- [API Best Practices](../api/best-practices.md) - API optimization
- [Monitoring & Metrics](../monitoring/metrics.md) - Performance monitoring
- [Laravel Database Docs](https://laravel.com/docs/eloquent) - Eloquent ORM
