# Phase 3: Real-Time Monitoring Dashboard

> **Version**: 1.0.0
> **Last Updated**: 2025-11-20
> **Status**: ✅ Complete

## 📋 Overview

The Real-Time Monitoring Dashboard provides comprehensive infrastructure visibility across the entire AGL infrastructure (AGLSRV1, AGLSRV6, 68+ containers). Built with Laravel Livewire, it delivers real-time metrics updates, visual health indicators, and intelligent caching for optimal performance.

## 🏗️ Architecture

### Component Hierarchy

```
MonitoringDashboardEnhanced (Main Orchestrator)
├── ServerHealthCard (x2 - AGLSRV1, AGLSRV6)
├── NetworkMetrics (WireGuard Mesh Status)
├── StorageOverview (NFS Mounts)
└── ContainerGrid (68+ Containers)
```

### Data Flow

```
ProxmoxApiClient → MetricsCollector → [Cache Layer] → Livewire Components → Blade Views
                                              ↓
                                      WebSocket Events
                                              ↓
                                    Real-Time UI Updates
```

### Caching Strategy

| Metric Type | Cache TTL | Reason |
|-------------|-----------|--------|
| Server Metrics | 10s | Frequently changing (CPU, RAM) |
| Container Metrics | 10s | Real-time status needed |
| Network Metrics | 30s | Less frequent changes |
| Storage Metrics | 60s | Least frequently changing |

## 📦 Components

### 1. MetricsCollector Service

**Location**: `app/Services/MetricsCollector.php`

**Responsibilities**:
- Aggregate metrics from all infrastructure sources
- Implement intelligent caching with configurable TTL
- Calculate health status based on thresholds
- Provide fail-fast error handling with graceful degradation

**Key Methods**:

```php
// Collect server metrics (CPU, RAM, uptime, load)
public function collectServerMetrics(string $serverCode): array

// Collect container metrics for all containers on a server
public function collectContainerMetrics(string $serverId): Collection

// Collect network metrics (WireGuard mesh status)
public function collectNetworkMetrics(): array

// Collect storage metrics (NFS mount usage)
public function collectStorageMetrics(): array

// Aggregate all metrics (complete infrastructure snapshot)
public function aggregateAllMetrics(): array

// Force refresh all metrics (bypass cache)
public function refreshAllMetrics(): void
```

**Example Usage**:

```php
use App\Services\MetricsCollector;

$collector = app(MetricsCollector::class);

// Get server metrics
$serverMetrics = $collector->collectServerMetrics('aglsrv1');
// Returns: ['success' => true, 'server' => [...], 'metrics' => [...], 'health_status' => 'healthy']

// Get all containers on a server
$containers = $collector->collectContainerMetrics('aglsrv1');
// Returns: Collection of container metrics with health status

// Get complete infrastructure snapshot
$allMetrics = $collector->aggregateAllMetrics();
// Returns: ['servers' => [...], 'containers' => [...], 'network' => [...], 'storage' => [...], 'summary' => [...]]
```

### 2. ServerHealthCard Component

**Location**: `app/Livewire/ServerHealthCard.php`

**Features**:
- Individual server health display
- Visual status indicators (Green/Yellow/Red/Gray)
- CPU, Memory, Load Average, Uptime metrics
- Collapsible detailed view
- Auto-refresh every 10 seconds (configurable)

**Health Status Colors**:
- **Green (Healthy)**: CPU <70%, RAM <80%, load <cores
- **Yellow (Warning)**: CPU 70-85%, RAM 80-90%, load = cores
- **Red (Critical)**: CPU >85%, RAM >90%, load >cores
- **Gray (Offline)**: Server unreachable

**Usage**:

```blade
<livewire:server-health-card serverCode="aglsrv1" />
<livewire:server-health-card serverCode="aglsrv6" />
```

### 3. ContainerGrid Component

**Location**: `app/Livewire/ContainerGrid.php`

**Features**:
- Grid display of all 68+ containers
- Real-time status updates
- Filters: Server, Status (running/stopped/error), Resource Usage (normal/high/critical)
- Search by container name, hostname, or ID
- Sort by name, status, CPU, RAM, uptime
- Export metrics as JSON
- Virtual scrolling for performance

**Filters**:

```php
$filterServer = 'aglsrv1';     // Filter by server
$filterStatus = 'running';      // Filter by status
$filterUsage = 'critical';      // Filter by resource usage
$search = 'ct179';              // Search query
```

**Usage**:

```blade
<livewire:container-grid />
```

### 4. NetworkMetrics Component

**Location**: `app/Livewire/NetworkMetrics.php`

**Features**:
- WireGuard mesh network status (10.6.0.0/24)
- Peer connection status and latency
- Visual connection percentage indicator
- Collapsible peer details

**Health Status**:
- **Green**: All peers connected, latency <50ms
- **Yellow**: Some peers down, or latency 50-150ms
- **Red**: Multiple peers down, or latency >150ms

**Usage**:

```blade
<livewire:network-metrics />
```

### 5. StorageOverview Component

**Location**: `app/Livewire/StorageOverview.php`

**Features**:
- NFS mount usage across all servers
- Visual storage capacity indicators
- Collapsible mount details
- Server and mount type filtering

**Health Status**:
- **Green**: <70% used
- **Yellow**: 70-85% used
- **Red**: >85% used

**Usage**:

```blade
<livewire:storage-overview />
```

### 6. MonitoringDashboardEnhanced Component

**Location**: `app/Livewire/MonitoringDashboardEnhanced.php`

**Features**:
- Main dashboard orchestrator
- Summary cards (Servers, Containers, Warnings, Critical)
- Overall health score (0-100)
- Auto-refresh toggle
- Export all metrics functionality
- WebSocket event listeners

**Usage**:

```blade
<livewire:monitoring-dashboard-enhanced />
```

## 🔧 Configuration

### Environment Variables

Add to `.env`:

```bash
# Monitoring Dashboard Configuration
MONITORING_POLL_INTERVAL=10      # Livewire polling interval (seconds)
MONITORING_CACHE_TTL=10          # Metrics cache TTL (seconds)
MONITORING_API_TIMEOUT=5         # Proxmox API timeout (seconds)
MONITORING_RETRY_ATTEMPTS=3      # API retry attempts
MONITORING_WEBSOCKET_ENABLED=true # Enable WebSocket updates
MONITORING_EXPORT_ENABLED=true   # Enable metrics export
MONITORING_AUTO_REFRESH=true     # Enable auto-refresh by default
```

### Configuration File

**Location**: `config/monitoring.php`

```php
return [
    'poll_interval' => env('MONITORING_POLL_INTERVAL', 10),
    'cache_ttl' => env('MONITORING_CACHE_TTL', 10),
    'api_timeout' => env('MONITORING_API_TIMEOUT', 5),
    'retry_attempts' => env('MONITORING_RETRY_ATTEMPTS', 3),

    'thresholds' => [
        'server' => [
            'cpu' => ['warning' => 70, 'critical' => 85],
            'memory' => ['warning' => 80, 'critical' => 90],
        ],
        'container' => [
            'cpu' => ['warning' => 60, 'critical' => 80],
            'memory' => ['warning' => 75, 'critical' => 90],
        ],
        'storage' => ['warning' => 70, 'critical' => 85],
        'network' => [
            'connection_rate' => ['warning' => 95, 'critical' => 80],
            'latency' => ['warning' => 50, 'critical' => 150],
        ],
    ],
];
```

## 🌐 Routes

### Web Routes

```php
// Main Dashboard
GET /monitoring → MonitoringDashboardEnhanced

// Server Detail View
GET /monitoring/server/{code} → ServerDetailView

// Container Detail View
GET /monitoring/container/{id} → ContainerDetailView

// Force Refresh (bypass cache)
POST /monitoring/refresh → Force refresh all metrics
```

### API Routes

```php
// Get all aggregated metrics
GET /monitoring/api/metrics → Complete infrastructure snapshot

// Get server metrics
GET /monitoring/api/server/{code}/metrics → Server-specific metrics

// Get container metrics
GET /monitoring/api/server/{serverId}/containers → All containers on server

// Get network metrics
GET /monitoring/api/network → WireGuard mesh status

// Get storage metrics
GET /monitoring/api/storage → NFS mount usage
```

## 📊 Performance Optimization

### Caching Implementation

```php
// Server metrics cached for 10 seconds
Cache::remember("metrics:server:{$serverCode}", $this->cacheTtl, function () {
    // Fetch from Proxmox API
});

// Container metrics cached for 10 seconds
Cache::remember("metrics:containers:{$serverId}", $this->cacheTtl, function () {
    // Fetch from Proxmox API
});

// Network metrics cached for 30 seconds
Cache::remember("metrics:network", 30, function () {
    // Fetch WireGuard status
});

// Storage metrics cached for 60 seconds
Cache::remember("metrics:storage", 60, function () {
    // Fetch NFS mount usage
});
```

### Virtual Scrolling

ContainerGrid uses lazy loading with pagination for 68+ containers:

```php
public int $perPage = 50; // Show 50 containers per page
```

### Debounced Search

Frontend search input is debounced to 300ms to reduce API calls:

```blade
<input wire:model.live.debounce.300ms="search" />
```

### Tab Inactive Detection

Dashboard pauses polling when tab is inactive to save resources:

```javascript
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        pollingEnabled = false; // Pause polling
    } else {
        pollingEnabled = true; // Resume polling
        Livewire.dispatch('refreshDashboard'); // Immediate refresh
    }
});
```

## 🔄 Real-Time Updates

### WebSocket Events

The dashboard listens to these broadcast events:

```php
// Server metrics updated
'server.metrics.updated' => handleServerMetricsUpdated()

// Container status changed
'container.status.changed' => handleContainerStatusChanged()

// Network peer status
'network.peer.status' => handleNetworkPeerStatus()

// Manual refresh trigger
'refreshDashboard' => refreshAllMetrics()
```

### Livewire Polling

Components auto-refresh using `wire:poll` directive:

```blade
<div wire:poll.{{ config('monitoring.poll_interval', 10) }}s="loadMetrics">
    <!-- Component content -->
</div>
```

## 🎨 Visual Indicators

### Health Status Badge Colors

```php
'healthy' => 'bg-green-100 text-green-800',
'warning' => 'bg-yellow-100 text-yellow-800',
'critical' => 'bg-red-100 text-red-800',
'offline' => 'bg-gray-100 text-gray-800',
```

### Progress Bars

```blade
{{-- CPU Usage Bar --}}
<div class="w-full bg-gray-200 rounded-full h-2">
    <div class="h-2 rounded-full {{
        $cpuUsage > 85 ? 'bg-red-600' : (
        $cpuUsage > 70 ? 'bg-yellow-500' : 'bg-green-500'
    ) }}" style="width: {{ min($cpuUsage, 100) }}%"></div>
</div>
```

## 🧪 Testing

### Run Pest Tests

```bash
# Run all monitoring tests
php artisan test --filter=Monitoring

# Run specific component tests
php artisan test tests/Feature/MonitoringDashboardTest.php
php artisan test tests/Feature/Livewire/ServerHealthCardTest.php
php artisan test tests/Feature/Livewire/ContainerGridTest.php
php artisan test tests/Unit/MetricsCollectorTest.php
```

### Coverage Target

Target: **85%+ coverage**

## 📈 Usage Examples

### Basic Usage

```php
// In a controller or route
use App\Services\MetricsCollector;

$collector = app(MetricsCollector::class);

// Get complete infrastructure snapshot
$snapshot = $collector->aggregateAllMetrics();

return view('monitoring.dashboard', [
    'servers' => $snapshot['servers'],
    'containers' => $snapshot['containers'],
    'network' => $snapshot['network'],
    'storage' => $snapshot['storage'],
    'summary' => $snapshot['summary'],
]);
```

### Export Metrics

```php
// Export all metrics as JSON
Route::get('/monitoring/export', function (MetricsCollector $collector) {
    $metrics = $collector->aggregateAllMetrics();
    $filename = 'metrics-' . now()->format('Y-m-d-His') . '.json';

    return response()->json($metrics)
        ->header('Content-Disposition', "attachment; filename={$filename}");
});
```

### Custom Thresholds

```php
// Override thresholds in config/monitoring.php
'thresholds' => [
    'server' => [
        'cpu' => [
            'warning' => 60,  // Lower threshold
            'critical' => 75,
        ],
    ],
],
```

## 🐛 Troubleshooting

### Dashboard Not Loading

**Symptom**: Dashboard shows loading spinner indefinitely

**Solution**:
1. Check Proxmox API connectivity:
   ```bash
   curl -k https://192.168.0.245:8006/api2/json/nodes
   ```
2. Verify environment variables in `.env`
3. Clear cache:
   ```bash
   php artisan cache:clear
   php artisan config:clear
   ```

### Metrics Not Updating

**Symptom**: Metrics show stale data

**Solution**:
1. Check cache TTL configuration
2. Force refresh:
   ```bash
   curl -X POST http://localhost/monitoring/refresh
   ```
3. Verify polling interval:
   ```bash
   grep MONITORING_POLL_INTERVAL .env
   ```

### High CPU Usage

**Symptom**: Laravel process consuming high CPU

**Solution**:
1. Increase polling interval:
   ```env
   MONITORING_POLL_INTERVAL=30  # Increase from 10 to 30 seconds
   ```
2. Reduce container count per page:
   ```php
   public int $perPage = 25; // Reduce from 50
   ```

### WebSocket Events Not Working

**Symptom**: No real-time updates even when events are triggered

**Solution**:
1. Check Laravel Reverb is running:
   ```bash
   php artisan reverb:start
   ```
2. Verify Reverb configuration in `.env`:
   ```env
   BROADCAST_CONNECTION=reverb
   REVERB_HOST=0.0.0.0
   REVERB_PORT=8080
   ```

## 📚 API Reference

### MetricsCollector Methods

#### collectServerMetrics(string $serverCode)

```php
/**
 * Collect server metrics (CPU, RAM, uptime, load)
 *
 * @param string $serverCode Server code (e.g., 'aglsrv1')
 * @return array{
 *   success: bool,
 *   server: ?array,
 *   metrics: ?array,
 *   health_status: string,
 *   error: ?string
 * }
 */
```

**Example Response**:

```json
{
  "success": true,
  "server": {
    "id": 1,
    "name": "aglsrv1.local",
    "code": "aglsrv1",
    "ip_address": "192.168.0.245",
    "status": "online"
  },
  "metrics": {
    "cpu": {
      "cores": 32,
      "usage_percent": 45.2,
      "model": "AMD EPYC 7543"
    },
    "memory": {
      "total_gb": 256.0,
      "used_gb": 128.5,
      "free_gb": 127.5,
      "usage_percent": 50.2
    },
    "load": {
      "1min": 8.45,
      "5min": 7.23,
      "15min": 6.89
    },
    "uptime": {
      "seconds": 2592000,
      "formatted": "30d 0h 0m"
    }
  },
  "health_status": "healthy",
  "error": null
}
```

#### collectContainerMetrics(string $serverId)

```php
/**
 * Collect container metrics for all containers on a server
 *
 * @param string $serverId Server ID or code
 * @return Collection<int, array>
 */
```

**Example Response** (single container):

```json
{
  "id": 123,
  "vmid": "179",
  "name": "agldv03",
  "hostname": "agldv03.local",
  "status": "running",
  "uptime": 86400,
  "uptime_formatted": "1d 0h 0m",
  "cpu": {
    "usage_percent": 35.5,
    "cores": 8
  },
  "memory": {
    "total_mb": 49152,
    "used_mb": 24576,
    "usage_percent": 50.0
  },
  "disk": {
    "total_gb": 200,
    "used_gb": 85.5,
    "usage_percent": 42.8
  },
  "health_status": "healthy",
  "error": null
}
```

## 🔒 Security Considerations

### API Authentication

All monitoring endpoints require authentication:

```php
Route::middleware(['auth'])->prefix('monitoring')->group(function () {
    // Protected routes
});
```

### Password Encryption

Proxmox passwords are encrypted in database:

```php
// Auto-encrypted before saving
protected static function boot()
{
    static::saving(function ($server) {
        if ($server->isDirty('password') && $server->password) {
            $server->password = encrypt($server->password);
        }
    });
}
```

### Rate Limiting

Implement rate limiting for API endpoints:

```php
Route::middleware(['auth', 'throttle:60,1'])->prefix('monitoring/api')->group(function () {
    // API routes limited to 60 requests per minute
});
```

## 📝 Best Practices

### 1. Cache Management

Always use cache for frequently accessed data:

```php
// Good: Cached for 10 seconds
$metrics = Cache::remember('metrics:server:aglsrv1', 10, fn() => $api->getMetrics());

// Bad: No caching, hits API every time
$metrics = $api->getMetrics();
```

### 2. Error Handling

Implement graceful degradation:

```php
try {
    $metrics = $collector->collectServerMetrics($code);
} catch (\Exception $e) {
    // Log error
    Log::error("Failed to collect metrics", ['error' => $e->getMessage()]);

    // Show user-friendly error
    $this->error = 'Unable to load server metrics';

    // Continue with other operations
}
```

### 3. Resource Optimization

Use pagination for large datasets:

```php
// Good: Paginated results
$containers = $containers->paginate(50);

// Bad: Load all 68+ containers at once
$containers = $containers->get();
```

### 4. Health Status Consistency

Always use configured thresholds:

```php
// Good: Use config
$cpuWarning = config('monitoring.thresholds.server.cpu.warning');

// Bad: Hardcoded values
if ($cpuUsage > 70) { ... }
```

## 🚀 Future Enhancements

### Planned Features

1. **Historical Metrics**
   - Store metrics in database
   - Display trend charts
   - Compare metrics over time

2. **Alert Rules**
   - Custom alert thresholds per container
   - Email/Slack notifications
   - Alert escalation policies

3. **Predictive Analytics**
   - Resource exhaustion prediction
   - Anomaly detection
   - Capacity planning recommendations

4. **Mobile App**
   - Native iOS/Android apps
   - Push notifications
   - Mobile-optimized dashboard

5. **Advanced Filtering**
   - Save filter presets
   - Tag-based filtering
   - Custom views per user

## 📞 Support

For issues or questions:

1. Check troubleshooting section above
2. Review logs: `tail -f storage/logs/laravel.log`
3. Check infrastructure documentation: `docs/INFRA.md`
4. Contact infrastructure team

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Maintainer**: AGL Infrastructure Team
