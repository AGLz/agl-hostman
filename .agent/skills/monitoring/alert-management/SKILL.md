# Alert Management Skill

**Category**: Monitoring & Operations
**Based on**: `/src/app/Models/Alert.php`
**Related Config**: `/src/config/monitoring.php`

## Overview

Expert in creating, managing, and resolving alerts for infrastructure monitoring. Supports multiple severity levels, notification patterns, auto-resolution, and alert deduplication.

## Core Capabilities

### 1. Alert Creation

Create alerts for various infrastructure events:

```php
use App\Models\Alert;

// Critical server alert
Alert::create([
    'type' => 'critical',
    'title' => 'Server Down',
    'message' => 'Proxmox server px-server-01 is not responding',
    'source' => 'server',
    'source_id' => 'px-server-01',
    'severity' => 90,
    'status' => 'active',
    'resource_type' => 'server',
    'resource_id' => 'px-server-01',
    'alert_type' => 'availability',
    'auto_resolve_after_hours' => 4,
]);

// Container resource warning
Alert::create([
    'type' => 'warning',
    'title' => 'High Memory Usage',
    'message' => 'Container vm-105 memory usage at 87%',
    'source' => 'container',
    'source_id' => 'vm-105',
    'severity' => 70,
    'status' => 'active',
    'resource_type' => 'container',
    'resource_id' => 'vm-105',
    'alert_type' => 'performance',
    'metadata' => [
        'current_value' => 87,
        'threshold' => 75,
        'metric' => 'memory',
    ],
]);
```

### 2. Severity Levels

| Level | Severity Range | Color | Use Case |
|-------|----------------|-------|----------|
| Critical | 90-100 | #EF4444 | Service down, data loss |
| High | 70-89 | #F59E0B | Performance degradation |
| Medium | 40-69 | #FCD34D | Resource warnings |
| Low | 0-39 | #6B7280 | Informational |

### 3. Alert States

```php
// Active alerts (not muted)
$activeAlerts = Alert::active()->get();

// Acknowledged alerts
$acknowledged = Alert::acknowledged()->get();

// Resolved alerts
$resolved = Alert::resolved()->get();

// All unresolved
$unresolved = Alert::unresolved()->get();

// Not muted (consider muted_until)
$notMuted = Alert::notMuted()->get();
```

### 4. Alert Lifecycle

#### Acknowledge Alert
```php
$alert = Alert::find($id);
$alert->acknowledge($userId);
// Sets: status=acknowledged, acknowledged_by, acknowledged_at
```

#### Resolve Alert
```php
$alert->resolve('Fixed the issue by restarting the container');
// Sets: status=resolved, is_resolved=true, resolved_by, resolved_at
```

#### Reopen Alert
```php
$alert->reopen();
// Resets: status=active, is_resolved=false
```

#### Mute Alert
```php
// Mute for 60 minutes
$alert->mute(60);
// Sets muted_until = now() + 60 minutes
```

### 5. Query Patterns

#### By severity
```php
$critical = Alert::critical()->get();
$high = Alert::high()->get();
$medium = Alert::medium()->get();
$low = Alert::low()->get();
```

#### By resource
```php
$serverAlerts = Alert::byResource('server', 'px-server-01')
    ->unresolved()
    ->ordered()
    ->get();
```

#### By source
```php
$containerAlerts = Alert::bySource('container')
    ->recent(24)
    ->get();
```

#### Recent alerts
```php
$recent = Alert::recent(24)  // Last 24 hours
    ->unresolved()
    ->orderByRaw('FIELD(severity, "critical", "high", "medium", "low")')
    ->orderBy('created_at', 'desc')
    ->get();
```

### 6. Polymorphic Relationships

Alerts can be linked to any resource:

```php
$alert = Alert::create([
    'resource_type' => 'LxcContainer',
    'resource_id' => $container->id,
    // ... other fields
]);

// Retrieve the related resource
$container = $alert->resource; // Returns LxcContainer model
```

### 7. Notification Logic

Determine if an alert should send browser notifications:

```php
if ($alert->shouldNotify()) {
    // Send notification
    // Only notifies if:
    // - type is 'critical' or 'warning'
    // - not muted
    // - status is 'active'
}
```

### 8. Alert Attributes

#### Priority (for sorting)
```php
$priority = $alert->priority;
// Returns: 0 (resolved), 100 (critical), 80 (high), 60 (medium), 40 (low)
```

#### Color (for UI)
```php
$color = $alert->color;
// Returns hex color based on type
```

#### Icon (for UI)
```php
$icon = $alert->icon;
// Returns: server, box, network, hard-drive, alert-circle, info
```

### 9. Auto-Resolution

Alerts can auto-resolve based on TTL:

```php
if ($alert->shouldAutoResolve()) {
    $alert->resolve('Auto-resolved after TTL expired');
}
```

Configure TTL in monitoring config:
```php
'alerts' => [
    'auto_resolve_hours' => env('MONITORING_AUTO_RESOLVE_HOURS', 24),
],
```

### 10. Alert Deduplication

Prevent alert spam with deduplication:

```php
// Configuration
'alerts' => [
    'deduplication_window_minutes' => 15,
    'max_per_rule_hourly' => 10,
],
```

Implementation:
```php
$existingAlert = Alert::where('alert_type', $type)
    ->where('resource_type', $resourceType)
    ->where('resource_id', $resourceId)
    ->where('created_at', '>', now()->subMinutes(15))
    ->where('status', '!=', 'resolved')
    ->first();

if ($existingAlert) {
    // Update existing instead of creating new
    $existingAlert->update([
        'message' => $newMessage,
        'severity' => max($existingAlert->severity, $newSeverity),
    ]);
}
```

## Alert Types

| Type | Description | Auto-Resolve |
|------|-------------|--------------|
| `availability` | Service/host down | 4 hours |
| `performance` | High resource usage | 24 hours |
| `capacity` | Disk/storage full | 48 hours |
| `security` | Unauthorized access | Never |
| `deployment` | Deployment failure | 24 hours |
| `network` | Network issues | 4 hours |
| `backup` | Backup failures | 48 hours |

## Source Types

- `server` - Proxmox servers
- `container` - LXC containers
- `network` - Network interfaces
- `storage` - Storage volumes
- `system` - System-level alerts

## Best Practices

### 1. Use Severity Appropriately
```php
// GOOD: Critical for service down
Alert::create(['severity' => 90, 'type' => 'critical', ...]);

// GOOD: Warning for high usage
Alert::create(['severity' => 70, 'type' => 'warning', ...]);

// AVOID: Critical for non-critical issues
Alert::create(['severity' => 90, 'type' => 'info', ...]);  // Wrong!
```

### 2. Include Context in Metadata
```php
Alert::create([
    'metadata' => [
        'threshold' => 85,
        'current_value' => 92,
        'duration_minutes' => 15,
        'affected_resources' => ['vm-101', 'vm-102'],
        'suggested_action' => 'Scale up or restart services',
    ],
]);
```

### 3. Set Appropriate Auto-Resolve TTL
```php
// Temporary issues: Short TTL
'auto_resolve_after_hours' => 4,  // Server restart

// Persistent issues: Long TTL
'auto_resolve_after_hours' => 48,  // Capacity planning

// Security issues: Never auto-resolve
'auto_resolve_after_hours' => null,
```

### 4. Mute Noisy Alerts
```php
// Known maintenance window
$alert->mute(120);  // Mute for 2 hours during maintenance
```

## Integration Points

- **Performance Monitoring**: Create alerts when thresholds breached
- **Harbor Registry**: Alert on image scan vulnerabilities
- **Query Optimizer**: Alert on slow queries
- **Redis Cache**: Alert on cache failures

## Common Tasks

### Create alert from metric
```php
use App\Models\PerformanceTrend;

$metric = PerformanceTrend::latestPerResource([$resourceId], $metricType)->first();

if ($metric->value > $threshold) {
    Alert::create([
        'type' => $metric->value > 85 ? 'critical' : 'warning',
        'title' => "High {$metricType}",
        'message' => "{$resourceType} {$resourceId} {$metricType} at {$metric->value}%",
        'source' => $resourceType,
        'source_id' => $resourceId,
        'severity' => $metric->value > 85 ? 90 : 70,
        'alert_type' => 'performance',
        'metadata' => ['value' => $metric->value, 'threshold' => $threshold],
    ]);
}
```

### Alert dashboard query
```php
$dashboardAlerts = Alert::unresolved()
    ->notMuted()
    ->orderByRaw('FIELD(severity, "critical", "high", "medium", "low")')
    ->orderBy('created_at', 'desc')
    ->limit(50)
    ->get()
    ->sortByDesc('priority');
```

### Cleanup old resolved alerts
```php
$deleted = Alert::resolved()
    ->where('resolved_at', '<', now()->subDays(30))
    ->delete();
```

## See Also

- `performance-monitoring` - Metrics collection and thresholds
- `redis-caching` - Cache alert notifications
- `query-optimization` - Optimized alert queries
