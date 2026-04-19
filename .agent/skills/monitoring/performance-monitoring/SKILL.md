# Performance Monitoring Skill

**Category**: Monitoring & Operations
**Based on**: `/src/app/Models/PerformanceTrend.php`
**Related Config**: `/src/config/monitoring.php`

## Overview

Expert in collecting, analyzing, and trending performance metrics for infrastructure resources including servers, containers, and storage. Provides capacity planning and predictive maintenance capabilities through time-series data analysis.

## Core Capabilities

### 1. Metrics Collection

Record performance metrics for any monitored resource:

```php
use App\Models\PerformanceTrend;

// Record CPU usage
PerformanceTrend::record(
    resourceType: 'server',
    resourceId: 'px-server-01',
    metricType: 'cpu',
    value: 78.5,
    unit: '%',
    metadata: ['cores' => 16, 'load' => 12.8]
);

// Record memory usage
PerformanceTrend::record(
    resourceType: 'container',
    resourceId: 'vm-105',
    metricType: 'memory',
    value: 45.2,
    unit: '%',
    metadata: ['limit_mb' => 4096, 'used_mb' => 1847]
);
```

### 2. Query Patterns

#### Latest metrics for a resource
```php
$trends = PerformanceTrend::byResource('server', 'px-server-01')
    ->byMetricType('cpu')
    ->recent(24)  // Last 24 hours
    ->ordered()
    ->get();
```

#### Time range analysis
```php
$start = now()->subDays(7);
$end = now();

$trends = PerformanceTrend::betweenDates($start, $end)
    ->byResource('container', 'vm-105')
    ->get();
```

#### Aggregate queries
```php
// Using DatabaseQueryOptimizer
$optimizer = app(DatabaseQueryOptimizer::class);

$metrics = $optimizer->getAggregateMetrics(
    resourceType: 'server',
    resourceId: 'px-server-01',
    metricType: 'cpu',
    hours: 24
);
// Returns: min, max, avg, data_points
```

### 3. Performance Thresholds

Based on monitoring configuration:

| Resource Type | Metric | Warning | Critical |
|---------------|--------|---------|----------|
| Server | CPU | 70% | 85% |
| Server | Memory | 80% | 90% |
| Server | Load | 1.0 x cores | 2.0 x cores |
| Container | CPU | 60% | 80% |
| Container | Memory | 75% | 90% |
| Container | Disk | 80% | 90% |
| Storage | Usage | 70% | 85% |

### 4. Trend Analysis

Calculate trends and predict capacity issues:

```php
$trends = PerformanceTrend::byResource('server', 'px-server-01')
    ->byMetricType('disk')
    ->recent(168)  // Last week
    ->get();

// Calculate growth rate
$firstValue = $trends->first()->value;
$lastValue = $trends->last()->value;
$growthRate = (($lastValue - $firstValue) / $firstValue) * 100;

// Predict when threshold will be reached
if ($growthRate > 0) {
    $currentValue = $lastValue;
    $threshold = 85; // Critical threshold
    $daysUntilFull = ((($threshold - $currentValue) / $currentValue) * 100) / ($growthRate / 7);
}
```

### 5. Data Retention

Automatically clean old trend data:

```php
// Keep data for 90 days (default)
$deleted = PerformanceTrend::cleanupOldTrends(90);

// Custom retention period
$deleted = PerformanceTrend::cleanupOldTrends(30);
```

## Metric Types

| Type | Unit | Description |
|------|------|-------------|
| `cpu` | % | CPU utilization percentage |
| `memory` | % | Memory usage percentage |
| `disk` | % | Disk usage percentage |
| `load` | number | System load average |
| `network_in` | Mbps | Network ingress rate |
| `network_out` | Mbps | Network egress rate |
| `io_read` | MB/s | Disk read rate |
| `io_write` | MB/s | Disk write rate |
| `connection_count` | number | Active connections |
| `temperature` | °C | Hardware temperature |

## Resource Types

- `server` - Proxmox servers/nodes
- `container` - LXC containers
- `vm` - Virtual machines
- `storage` - Storage volumes
- `network` - Network interfaces
- `application` - Deployed applications

## Configuration

Configure monitoring behavior via `/src/config/monitoring.php`:

```php
// Collection interval (seconds)
'collection_interval' => 60,

// Data retention (days)
'retention_days' => 90,

// Aggregation interval (minutes)
'aggregation_interval' => 5,

// Analysis window (hours)
'analysis_window_hours' => 24,
```

## Best Practices

### 1. Efficient Collection
- Collect metrics at appropriate intervals (60s default)
- Use batch inserts for multiple metrics
- Cache recent metrics to avoid duplicate queries

### 2. Query Optimization
```php
// GOOD: Select only needed columns
PerformanceTrend::select(['id', 'value', 'recorded_at'])
    ->byResource('server', 'px-server-01')
    ->recent(24)
    ->get();

// AVOID: Selecting all columns when not needed
PerformanceTrend::where(...)->get();
```

### 3. Index Strategy
Ensure indexes exist on:
- `(resource_type, resource_id, metric_type)`
- `recorded_at` (descending)
- Composite: `(resource_type, resource_id, metric_type, recorded_at)`

### 4. Alert Integration
Create alerts based on trend analysis:
```php
use App\Models\Alert;

if ($avgCpu > 85) {
    Alert::create([
        'type' => 'critical',
        'title' => 'High CPU Detected',
        'message' => "Server {$serverId} CPU averaged {$avgCpu}% over {$hours}h",
        'source' => 'monitoring',
        'severity' => 90,
        'resource_type' => 'server',
        'resource_id' => $serverId,
        'alert_type' => 'performance',
        'auto_resolve_after_hours' => 24,
    ]);
}
```

## Integration Points

- **Alert Management**: Trigger alerts when thresholds breached
- **Query Optimizer**: Use optimized queries for metrics retrieval
- **Redis Cache**: Cache recent metrics and aggregates
- **Harbor Registry**: Monitor image pull/push performance

## Common Tasks

### Track container performance
```bash
php artisan monitoring:collect-containers
```

### Generate performance report
```bash
php artisan monitoring:report --resource=server --id=px-01 --days=7
```

### Analyze trends for capacity planning
```bash
php artisan monitoring:trends --predict --metric=disk
```

## See Also

- `alert-management` - Alert creation and threshold management
- `query-optimization` - Optimized metrics queries
- `redis-caching` - Caching strategies for metrics
