# AGL Hostman Performance Optimization Guide

## Overview

This guide documents the performance optimization strategies implemented in the AGL Hostman Laravel application. The goal is to achieve:

- **API Response Time**: < 100ms (P95)
- **Database Query Time**: < 50ms
- **Query Count per Request**: < 50
- **Memory Usage**: < 128MB per request
- **Cache Hit Rate**: > 70%

## Architecture

### Performance Services

```
app/Services/Performance/
├── PerformanceProfiler.php          # Request profiling and bottleneck detection
├── CacheStrategyService.php          # Intelligent caching strategies
├── DatabaseOptimizationService.php   # Database optimization and indexing
└── PerformanceMonitoringService.php  # Metrics collection and reporting
```

### Middleware

```
app/Http/Middleware/
├── PerformanceMiddleware.php         # Tracks response times, queries, memory
└── CacheMiddleware.php               # Caches API responses
```

## Caching Strategy

### Cache Hierarchies

| Type          | TTL    | Use Case                           |
|---------------|--------|------------------------------------|
| Short         | 30s    | Real-time monitoring data          |
| Medium        | 5m     | Semi-static data (workflows, etc)  |
| Long          | 1h     | Rarely changing data (permissions) |
| Static        | Forever | Configuration and reference data   |

### Cache Keys Structure

```
{prefix}:{category}:{identifier}:{params}
```

Examples:
- `agl_cache:infrastructure:status`
- `agl_cache:user:permissions:123`
- `agl_cache:n8n:workflows`
- `agl_cache:monitoring:alerts:active`

### Cache Invalidation

1. **Time-based**: Automatic expiration via TTL
2. **Tag-based**: Invalidate by data type (e.g., `Cache::tags(['user', '123'])->flush()`)
3. **Event-based**: Clear cache on model events

## Database Optimization

### Index Recommendations

#### Alerts Table
```sql
-- Foreign key indexes
CREATE INDEX idx_alerts_user ON alerts(user_id);

-- WHERE clause optimization
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_resolved_at ON alerts(resolved_at);

-- Composite index for common queries
CREATE INDEX idx_alerts_status_resolved ON alerts(status, resolved_at);
```

#### N8N Workflows Table
```sql
CREATE INDEX idx_n8n_workflows_active ON n8n_workflows(active);
CREATE INDEX idx_n8n_workflows_category ON n8n_workflows(category);
CREATE INDEX idx_n8n_workflows_last_executed ON n8n_workflows(last_executed_at DESC);
```

#### Users Table
```sql
CREATE INDEX idx_users_active_last_login ON users(is_active, last_login_at DESC);
CREATE INDEX idx_users_workos_id ON users(workos_id);
```

### Query Optimization Patterns

#### Eager Loading (Prevent N+1)
```php
// ❌ Bad - N+1 query
$workflows = N8NWorkflow::all();
foreach ($workflows as $workflow) {
    echo $workflow->executions->count();
}

// ✅ Good - Eager loading
$workflows = N8NWorkflow::with('executions')->get();
foreach ($workflows as $workflow) {
    echo $workflow->executions->count();
}
```

#### Chunking (Large Datasets)
```php
// ✅ Process large datasets efficiently
Alert::chunk(500, function ($alerts) {
    foreach ($alerts as $alert) {
        // Process alert
    }
});
```

#### Select Only Needed Columns
```php
// ✅ Select specific columns
$users = User::select('id', 'name', 'email')->get();
```

## API Optimization

### Response Optimization

1. **Pagination**: Limit result sets (default: 25, max: 100)
2. **Compression**: Enable gzip for JSON responses
3. **Field Filtering**: Exclude unnecessary fields
4. **Response Caching**: Cache GET requests

### Performance Headers

All API responses include:
```
X-Response-Time: 45.2ms
X-Memory-Usage: 12.5MB
X-Query-Count: 8
X-Request-ID: req_abc123
X-Cache: HIT/MISS
```

## Monitoring & Metrics

### Key Metrics Tracked

1. **Response Times**: P50, P95, P99
2. **Query Counts**: Per endpoint
3. **Memory Usage**: Peak and average
4. **Cache Hit Rate**: Overall and per-key
5. **Slow Queries**: > 50ms threshold
6. **SLA Compliance**: Track violations

### Performance Dashboard

Access via: `/api/monitoring/stats`

```json
{
  "alerts": {
    "active": 12,
    "resolved_today": 45
  },
  "infrastructure": {
    "overall_health": "healthy",
    "servers": {...}
  },
  "performance": {
    "avg_response_time_ms": 45.2,
    "p95_response_time_ms": 78.5,
    "cache_hit_rate": 85.3,
    "sla_compliance": 98.5
  }
}
```

## Testing

### Performance Test Suite

Run performance tests:
```bash
cd src
php artisan test --testsuite=Performance
```

### Benchmarking

```bash
# Run benchmarks
php artisan benchmark:endpoint /api/monitoring/health

# Profile specific endpoint
php artisan profile:endpoint /api/monitoring/alerts
```

## Configuration

### Environment Variables

```env
# Performance Profiling
PERFORMANCE_PROFILING_ENABLED=true
PERFORMANCE_LOG_QUERIES=true

# Cache Configuration
CACHE_DRIVER=redis
CACHE_DEFAULT_TTL=300
CACHE_PREFIX=agl_cache

# Performance Thresholds
PERFORMANCE_THRESHOLD_RESPONSE_MS=100
PERFORMANCE_THRESHOLD_MAX_QUERIES=50
PERFORMANCE_THRESHOLD_MEMORY_MB=128
PERFORMANCE_SLOW_QUERY_THRESHOLD_MS=50

# API Optimization
API_ENABLE_COMPRESSION=true
API_ENABLE_PAGINATION=true
API_DEFAULT_PAGE_SIZE=25
API_MAX_PAGE_SIZE=100
```

## Best Practices

### 1. Always Eager Load Relations

```php
// Define in model
protected $alwaysEagerLoad = ['roles', 'permissions'];

// Or use scope
User::with(['roles', 'permissions'])->get();
```

### 2. Use Scopes for Common Queries

```php
// In model scope
public function scopeActive($query) {
    return $query->where('is_active', true);
}

// Usage
User::active()->get();
```

### 3. Implement Caching

```php
// Use cache service
$cache = app(CacheStrategyService::class);
$result = $cache->remember('key', fn() => expensiveOperation(), 'strategy_key');
```

### 4. Monitor Performance

```php
// Track custom metrics
$monitoring = app(PerformanceMonitoringService::class);
$monitoring->recordResponseTime('/api/custom', 45.2);
```

## Troubleshooting

### High Response Times

1. Check query count: `X-Query-Count` header
2. Identify N+1 queries: Check profiler output
3. Review slow query log
4. Check cache hit rate

### Memory Issues

1. Review result set sizes
2. Use chunking for large datasets
3. Enable query result caching
4. Check for memory leaks in services

### Cache Not Working

1. Verify Redis connection: `php artisan cache:clear`
2. Check cache configuration
3. Review cache keys for collisions
4. Monitor cache hit rate

## Performance Tuning Checklist

- [ ] Enable performance profiling
- [ ] Implement caching for all GET endpoints
- [ ] Add database indexes for common queries
- [ ] Optimize N+1 queries with eager loading
- [ ] Enable response compression
- [ ] Set up performance monitoring
- [ ] Configure alerts for SLA violations
- [ ] Run performance tests
- [ ] Document baseline metrics
- [ ] Set up continuous performance monitoring

## Related Documentation

- [Laravel Performance Optimization](https://laravel.com/docs/12.x/performance)
- [Redis Caching](https://laravel.com/docs/12.x/redis)
- [Database Query Optimization](https://laravel.com/docs/12.x/queries)
- [Laravel Telescope](https://laravel.com/docs/12.x/telescope)

---

Last Updated: 2025-02-08
Maintained by: AGL Infrastructure Team
