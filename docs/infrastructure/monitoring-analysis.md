# Monitoring and Observability Infrastructure Analysis

## Executive Summary

This project implements a comprehensive monitoring and observability stack for managing Proxmox-based infrastructure, containers, networks, and storage. The system provides real-time metrics collection, intelligent alerting, health checking, performance trend analysis, and integration with external observability platforms.

**Key Strengths:**
- Multi-layered monitoring (servers, containers, network, storage)
- Intelligent alert deduplication and rate limiting
- Blue-green deployment monitoring with health checks
- Real-time WebSocket broadcasting
- Performance trend analysis and predictive maintenance
- Prometheus/Grafana integration capabilities

**Areas for Enhancement:**
- Log aggregation infrastructure (placeholder implementations)
- Statistical anomaly detection (not implemented)
- Advanced predictive analytics (feature flag disabled)
- Metrics export to external systems (partial implementation)

---

## 1. Current Monitoring Capabilities

### 1.1 Core Components

| Component | File | Purpose | Status |
|-----------|------|---------|--------|
| **MonitoringService** | `app/Services/MonitoringService.php` | Core orchestration service | ✅ Full Implementation |
| **MetricsCollector** | Referenced but not analyzed | Metrics collection from Proxmox | ✅ Implemented |
| **AlertService** | `app/Services/AlertService.php` | Alert lifecycle management | ✅ Full Implementation |
| **AlertRuleEngine** | `app/Services/AlertRuleEngine.php` | Rule-based alert evaluation | ⚠️ Partial (threshold only) |
| **ContainerHealthMonitor** | `app/Services/ContainerHealthMonitor.php` | Container health monitoring | ✅ Full Implementation |
| **HealthCheckService** | `app/Services/Health/HealthCheckService.php` | System health checks | ✅ Full Implementation |
| **ProductionMonitoringService** | `app/Services/Monitoring/ProductionMonitoringService.php` | Production metrics & Grafana dashboards | ⚠️ Partial (template only) |

### 1.2 Data Models

**Alert Model** (`app/Models/Alert.php`)
```php
// Key fields
- type: 'critical', 'warning', 'info'
- severity: 0-100 (integer)
- status: 'active', 'acknowledged', 'resolved'
- source: 'server', 'container', 'network', 'storage', 'system'
- metadata: JSON (flexible data storage)
- muted_until: datetime (alert suppression)
- auto_resolve_after_hours: TTL-based resolution

// Polymorphic relationship
- resource_type, resource_id: Link to any monitored resource

// Scopes
- active(), acknowledged(), resolved(), critical(), warning()
- byType(), bySeverity(), bySource(), byResource()
- recent(hours), notMuted()
```

**PerformanceTrend Model** (`app/Models/PerformanceTrend.php`)
```php
// Time-series metrics storage
- resource_type, resource_id: Polymorphic resource tracking
- metric_type: 'cpu_usage', 'memory_usage', 'load_average', etc.
- value: decimal(2) precision
- unit: '%', 'ms', etc.
- recorded_at: Timestamp for trend analysis
- metadata: JSON context

// Scopes
- byResource(), byMetricType(), recent(hours)
- betweenDates(), ordered(), latestPerResource()
- forTimeRange(minHours, maxHours)

// Methods
- record(): Static factory for metric recording
- cleanupOldTrends(days): Data retention
```

### 1.3 Monitoring Configuration

**File:** `config/monitoring.php`

```php
// Polling & Caching
'poll_interval' => 10 seconds (Livewire)
'cache_ttl' => 10 seconds
'api_timeout' => 5 seconds (Proxmox API)
'retry_attempts' => 3

// Metrics Collection
'collection_interval' => 60 seconds
'retention_days' => 90 days

// Health Thresholds
'server' => [
    'cpu' => ['warning' => 70%, 'critical' => 85%],
    'memory' => ['warning' => 80%, 'critical' => 90%],
    'load' => ['warning' => 1.0, 'critical' => 2.0]
]
'container' => [
    'cpu' => ['warning' => 60%, 'critical' => 80%],
    'memory' => ['warning' => 75%, 'critical' => 90%],
    'disk' => ['warning' => 80%, 'critical' => 90%]
]
'storage' => [
    'warning' => 70%, 'critical' => 85%
]
'network' => [
    'connection_rate' => ['warning' => 95%, 'critical' => 80%],
    'latency' => ['warning' => 50ms, 'critical' => 150ms]
]

// Alert Settings
'alerts' => [
    'enabled' => true,
    'deduplication_window_minutes' => 15,
    'max_per_rule_hourly' => 10,
    'auto_resolve_hours' => 24
]

// Trend Analysis
'trends' => [
    'enabled' => true,
    'aggregation_interval' => 5 minutes,
    'analysis_window_hours' => 24
]

// External Integrations
'prometheus' => [
    'enabled' => false (env: MONITORING_PROMETHEUS_ENABLED),
    'pushgateway_url' (env: PROMETHEUS_PUSHGATEWAY_URL),
    'job_name' => 'agl-hostman'
]
'grafana' => [
    'enabled' => false (env: MONITORING_GRAFANA_ENABLED),
    'url' (env: GRAFANA_URL),
    'api_key' (env: GRAFANA_API_KEY)
]

// Features
'websocket_updates' => true,
'export_metrics' => true,
'auto_refresh' => true,
'predictive_analysis' => false
```

---

## 2. Alert Patterns and Workflows

### 2.1 Alert Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    ALERT LIFECYCLE                              │
└─────────────────────────────────────────────────────────────────┘

  Triggered                    Acknowledged              Resolved
     │                              │                        │
     ▼                              ▼                        ▼
┌─────────┐                   ┌─────────┐              ┌─────────┐
│  ACTIVE │ ────────────────► │  ACKED  │ ──────────► │ RESOLVED│
│         │                   │         │              │         │
└────┬────┘                   └─────────┘              └─────────┘
     │                                                           │
     │ Can be muted                                             │ Can be
     │ (muted_until)                                            │ reopened
     │                                                           │
     ▼                                                           ▼
┌─────────┐                                                  ┌─────────┐
│  MUTED  │◄────────────────────────────────────────────────│ REOPEN  │
│         │                                                  │         │
└─────────┘                                                  └─────────┘

Auto-resolution (after TTL)
```

### 2.2 Alert Generation Flow

```php
// MonitoringService::collectAndMonitor()

1. Collect Metrics
   ├─ MetricsCollector::aggregateAllMetrics()
   ├─ Server metrics (CPU, RAM, Load)
   ├─ Container metrics (CPU, RAM, Disk, Uptime)
   ├─ Network metrics (WireGuard peers, latency)
   └─ Storage metrics (Disk usage per mount)

2. Evaluate Thresholds
   ├─ evaluateServerAlerts()
   ├─ evaluateContainerAlerts()
   ├─ evaluateNetworkAlerts()
   └─ evaluateStorageAlerts()

3. Create Alerts (with deduplication)
   ├─ AlertService::createAlert()
   ├─ isDuplicate() check (15-min window)
   ├─ isRateLimited() check (max 10/hour per rule)
   ├─ Alert::create() in database
   └─ broadcast(new AlertCreated($alert))

4. Record Performance Trends
   ├─ PerformanceTrend::record() for each metric
   ├─ Server: cpu_usage, memory_usage, load_average
   ├─ Container: cpu_usage, memory_usage
   ├─ Network: connection_rate, avg_latency
   └─ Storage: usage_percent

5. Update Cache
   ├─ Cache::put('monitoring:latest', 5 min)
   ├─ Cache::put('monitoring:summary', 5 min)
   └─ Cache::put('monitoring:last_collected', 5 min)
```

### 2.3 Alert Rule Types

**File:** `app/Services/AlertRuleEngine.php`

| Rule Type | Status | Implementation Details |
|-----------|--------|------------------------|
| **Threshold** | ✅ Implemented | CPU/RAM/Disk threshold monitoring |
| **Pattern** | ❌ Placeholder | Log pattern matching (requires log aggregation) |
| **Anomaly** | ❌ Placeholder | Statistical anomaly detection (requires historical metrics) |

**Threshold Rule Structure:**
```json
{
  "metric": "cpu" | "memory" | "disk" | "load",
  "target": "server" | "container",
  "target_id": "aglsrv1" | "179",
  "operator": ">" | ">=" | "<" | "<=" | "==" | "!=",
  "value": 90,
  "duration_minutes": 5,
  "actions": {
    "alert_type": "critical" | "warning" | "info",
    "title": "Custom alert title",
    "severity": 90
  }
}
```

### 2.4 Alert Deduplication Strategy

```php
// AlertService::isDuplicate()

protected function isDuplicate(array $data): bool
{
    $windowStart = now()->subMinutes($this->deduplicationWindowMinutes); // 15 min

    $existing = Alert::active()
        ->where('type', $data['type'])
        ->where('source', $data['source'])
        ->where('source_id', $data['source_id'] ?? null)
        ->where('created_at', '>=', $windowStart)
        ->exists();

    return $existing;
}

// Rate limiting per rule
protected function isRateLimited(string $ruleId): bool
{
    $hourAgo = now()->subHour();
    $count = Alert::where('metadata->rule_id', $ruleId)
        ->where('created_at', '>=', $hourAgo)
        ->count();
    return $count >= $this->maxAlertsPerRuleHourly; // 10
}
```

### 2.5 Real-time Alert Broadcasting

**Events:**
```php
// app/Events/AlertCreated.php
broadcast(new AlertCreated($alert))->toOthers();

// app/Events/AlertAcknowledged.php
broadcast(new AlertAcknowledged($alert))->toOthers();

// app/Events/AlertResolved.php
broadcast(new AlertResolved($alert))->toOthers();

// WebSocket Channel
// routes/channels.php
Broadcast::channel('alerts', function ($user) {
    return $user !== null;
});
```

**Frontend Integration:**
```javascript
// resources/js/hooks/useAlerts.js
useEcho(['alerts']);

// resources/js/hooks/useAlertNotifications.js
// Browser notifications for critical/warning alerts
```

---

## 3. Performance Tracking Patterns

### 3.1 Metrics Collection Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   METRICS COLLECTION                            │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │ MonitoringService│
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ Proxmox API   │   │ Health Checks │   │ External APIs │
│ (Servers)     │   │ (Database)    │   │ (Dokploy)     │
│               │   │ (Redis)       │   │ (Harbor)      │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                   ┌──────────────────┐
                   │ MetricsCollector │
                   └────────┬─────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  Server       │   │  Container    │   │  Network      │
│  Metrics      │   │  Metrics      │   │  Metrics      │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                   ┌──────────────────┐
                   │ PerformanceTrend │
                   │   (Database)     │
                   └──────────────────┘
```

### 3.2 Time-Series Data Storage

**PerformanceTrend Table Schema:**
```php
Schema::create('performance_trends', function (Blueprint $table) {
    $table->id();
    $table->string('resource_type'); // ProxmoxServer, LxcContainer, Network
    $table->string('resource_id');   // Polymorphic ID
    $table->string('metric_type');   // cpu_usage, memory_usage, etc.
    $table->decimal('value', 8, 2);  // Precision: 2 decimal places
    $table->string('unit');          // %, ms, MB, etc.
    $table->json('metadata')->nullable();
    $table->timestamp('recorded_at'); // Actual metric timestamp
    $table->timestamps();

    // Indexes for efficient querying
    $table->index(['resource_type', 'resource_id']);
    $table->index('metric_type');
    $table->index('recorded_at');
    $table->index(['resource_type', 'resource_id', 'metric_type', 'recorded_at']);
});
```

**Metric Types Collected:**
- **Server:** `cpu_usage`, `memory_usage`, `load_average`
- **Container:** `cpu_usage`, `memory_usage`, `disk_usage`
- **Network:** `connection_rate`, `avg_latency`
- **Storage:** `usage_percent`
- **Cluster:** `monitoring_snapshot` (aggregated health)

### 3.3 Trend Analysis

```php
// MonitoringService::getPerformanceTrends()

// Time window queries
PerformanceTrend::recent(24)  // Last 24 hours
    ->byResource('ProxmoxServer', 'server-id')
    ->byMetricType('cpu_usage')
    ->ordered()
    ->get();

// Statistical analysis
$result = [
    'cpu_usage' => [
        'current' => 75.5,      // Latest value
        'min' => 45.2,          // Minimum in period
        'max' => 89.7,          // Maximum in period
        'avg' => 68.3,          // Average
        'trend' => 'increasing', // Direction analysis
        'data_points' => 288    // Samples (5-min intervals)
    ]
];

// Trend calculation
protected function calculateTrendDirection(array $values): string
{
    // Compare first 1/3 vs last 1/3
    $change = (($lastAvg - $firstAvg) / $firstAvg) * 100;

    if (abs($change) < 5) return 'stable';
    return $change > 0 ? 'increasing' : 'decreasing';
}
```

### 3.4 Container Health Monitoring

**File:** `app/Services/ContainerHealthMonitor.php`

```php
// Real-time health checks every 30 seconds
$intervals = [
    'realtime' => 30,      // Real-time monitoring
    'analysis' => 300,     // Trend analysis every 5 min
    'prediction' => 1800,  // Predictive analysis every 30 min
];

// Health check thresholds
$thresholds = [
    'cpu' => ['warning' => 70, 'critical' => 90],
    'memory' => ['warning' => 70, 'critical' => 85],
    'disk' => ['warning' => 60, 'critical' => 80],
    'uptime' => ['minimum' => 300] // Detect frequent restarts
];

// Health status evaluation
$healthStatus = $container->getHealthStatus(); // healthy/warning/critical

// Issue detection
if ($cpuUsage >= $criticalThreshold) {
    $issues[] = "Critical CPU usage: {$cpuUsage}%";
    $severity = 'critical';
    $requiresAlert = true;
}

// Trend analysis
$trend = $this->getHealthTrend($node, $vmid);
// Returns: cpu, memory, disk trends over 24h
```

### 3.5 Predictive Maintenance

**Event-Driven Prediction:**
```php
// app/Events/ResourceExhaustionPredicted.php

class PredictiveMaintenanceService
{
    // Analyze trends to predict resource exhaustion
    public function predictExhaustion(string $resourceType, string $resourceId): array
    {
        $trends = $this->getHistoricalTrends($resourceType, $resourceId, 168); // 7 days

        // Linear regression to predict when threshold will be reached
        $prediction = $this->linearRegression($trends);

        return [
            'resource' => "{$resourceType}:{$resourceId}",
            'current_value' => $trends->last()->value,
            'predicted_exhaustion_date' => $prediction['exhaustion_date'],
            'days_until_exhaustion' => $prediction['days_remaining'],
            'confidence' => $prediction['r_squared'],
        ];
    }
}
```

---

## 4. Health Check Patterns

### 4.1 Comprehensive Health Checking

**File:** `app/Services/Health/HealthCheckService.php`

```php
public function checkAll(): array
{
    // Core infrastructure
    $this->checkDatabase();      // PostgreSQL connectivity
    $this->checkRedis();         // Redis connectivity
    $this->checkStorage();       // Disk write & space check
    $this->checkQueueWorkers();  // Job queue status

    // External services
    $this->checkExternalServices(); // Proxmox, Dokploy, Harbor, GitHub
    $this->checkWebSocketServer();  // Laravel Reverb health
    $this->checkSSLCertificates();  // Certificate expiry warnings

    return [
        'healthy' => $this->allHealthy,
        'checks' => $this->results,
        'timestamp' => now()->toIso8601String(),
    ];
}
```

### 4.2 Health Check Categories

| Category | Checks | Severity | Failure Handling |
|----------|--------|----------|------------------|
| **Database** | PostgreSQL PDO connection | Critical | Block deployments |
| **Redis** | Ping response | Critical | Block deployments |
| **Storage** | Write test + disk space | Critical (90%+) | Warning at 90% |
| **Queue Workers** | Stuck jobs, queue backlog | Important | Warning only |
| **External Services** | Proxmox, Dokploy, Harbor | Optional | Warning only |
| **WebSocket** | Reverb health endpoint | Optional | Warning only |
| **SSL Certs** | Certificate expiry | Critical (<7 days) | Warning at 30 days |

### 4.3 Container Health Job

**File:** `app/Jobs/ContainerHealthCheckJob.php`

```php
class ContainerHealthCheckJob implements ShouldQueue
{
    public $timeout = 300; // 5 minutes max
    public $tries = 3;
    public $backoff = [60, 300, 900]; // 1min, 5min, 15min

    public function handle(): void
    {
        // Prevent overlapping health checks
        $cacheKey = 'health_check:running:' . ($this->nodeCode ?? 'all');
        if (Cache::has($cacheKey)) {
            Log::warning('Health check already running');
            return;
        }
        Cache::put($cacheKey, true, 300);

        // Monitor all online Proxmox nodes
        $nodes = $this->getOnlineNodes();
        $monitor = app(ContainerHealthMonitor::class);
        $results = $monitor->monitorNodes($nodes);

        // Auto-trigger alerts for critical containers
        foreach ($results['nodes'] as $nodeResults) {
            foreach ($nodeResults['containers'] as $container) {
                if ($container['requires_alert']) {
                    $this->triggerAlert($node, $container);
                }
            }
        }
    }
}
```

**Scheduled Execution:**
```php
// app/Console/Kernel.php

// Full health checks - every minute
$schedule->job(new ContainerHealthCheckJob())
    ->everyMinute()
    ->onQueue('health-checks')
    ->withoutOverlapping();

// Quick health checks - every 30 seconds
$schedule->job(new ContainerHealthCheckJob(null, false))
    ->everySeconds(30)
    ->onQueue('health-checks')
    ->withoutOverlapping();
```

### 4.4 Deployment Health Checks

**Blue-Green Deployment Workflow:**
```php
// app/Services/DeploymentWorkflowService.php

private function runHealthChecks(Environment $env, string $slot): array
{
    $healthUrl = $this->getHealthUrl($env, $slot);

    // Retry with exponential backoff
    for ($i = 0; $i < $maxAttempts; $i++) {
        $response = Http::timeout(5)->get($healthUrl);

        if ($response->successful()) {
            return ['healthy' => true, 'response_code' => $response->status()];
        }

        sleep($this->getBackoff($i)); // 10s, 20s, 40s...
    }

    throw new Exception("Health check failed after {$maxAttempts} attempts");
}

// Rollback on health check failure
if (!$healthCheck['healthy']) {
    $this->performRollback($environment, $activeSlot);
    Log::critical('Deployment rolled back due to failed health checks');
}
```

---

## 5. Metrics Collection Strategies

### 5.1 Collection Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  METRICS COLLECTION LAYERS                      │
└─────────────────────────────────────────────────────────────────┘

LAYER 1: Scheduled Collection (Every 60 seconds)
├─ app/Console/Commands/CollectMetricsCommand.php
├─ Dispatches MetricsCollectionJob
└─ Calls MonitoringService::collectAndMonitor()

LAYER 2: Real-Time Polling (Every 10 seconds)
├─ Livewire components poll API
├─ GET /api/monitoring/metrics?refresh=true
└─ Cache::remember('monitoring:latest', 10)

LAYER 3: Event-Driven Collection
├─ Container status changes
├─ Deployment events
└─ System state transitions

LAYER 4: Manual Triggers
├─ POST /api/monitoring/collect
├─ GET /api/monitoring/refresh
└─ php artisan monitoring:collect
```

### 5.2 API Endpoints

**File:** `app/Http/Controllers/Api/MonitoringController.php`

| Endpoint | Method | Purpose | Cache |
|----------|--------|---------|-------|
| `/api/monitoring/metrics` | GET | Get all metrics | 10s |
| `/api/monitoring/health` | GET | Get health status | 10s |
| `/api/monitoring/alerts` | GET | Get alerts (filterable) | 60s |
| `/api/monitoring/trends` | GET | Get performance trends | Query |
| `/api/monitoring/stats` | GET | Get aggregated stats | 60s |
| `/api/monitoring/collect` | POST | Trigger collection | None |
| `/api/monitoring/refresh` | POST | Force refresh | None |
| `/api/monitoring/server/{code}` | GET | Server-specific metrics | 10s |
| `/api/monitoring/alerts/read` | POST | Acknowledge alerts | None |
| `/api/monitoring/alerts/{id}/resolve` | POST | Resolve alert | None |

### 5.3 Caching Strategy

```php
// Multi-level caching

// Level 1: In-memory cache (short-lived)
Cache::put('monitoring:latest', $metrics, 10);     // 10 seconds
Cache::put('monitoring:summary', $summary, 10);    // 10 seconds
Cache::put('alert_stats', $stats, 60);            // 1 minute

// Level 2: Database trends (persistent)
PerformanceTrend::record(...);  // 90-day retention

// Level 3: Historical logs (for analysis)
ContainerHealthLog::create(...);  // Per-container logs

// Cache invalidation
public function refreshAll(): array
{
    Cache::forget('monitoring:latest');
    Cache::forget('monitoring:summary');
    Cache::forget('monitoring:last_collected');
    return $this->collectAndMonitor();
}
```

### 5.4 Data Retention Policies

| Data Type | Retention | Cleanup Method | Schedule |
|-----------|-----------|----------------|----------|
| **Performance Trends** | 90 days | `PerformanceTrend::cleanupOldTrends(90)` | Daily cron |
| **Alerts** | 90 days (resolved) | `AlertService::cleanupOldAlerts(90)` | Daily cron |
| **Health Logs** | 7 days | Database cleanup job | Daily cron |
| **Cache Data** | 5 minutes | Auto-expire | N/A |
| **Metrics (External)** | Configurable | Prometheus retention | External |

```php
// Scheduled cleanup
$schedule->call(function () {
    app(MonitoringService::class)->cleanupOldData();
})->dailyAt('02:00');
```

---

## 6. External Integrations

### 6.1 Prometheus Integration

**Status:** ⚠️ **Configured but not fully implemented**

```php
// config/monitoring.php
'prometheus' => [
    'enabled' => env('MONITORING_PROMETHEUS_ENABLED', false),
    'pushgateway_url' => env('PROMETHEUS_PUSHGATEWAY_URL'),
    'job_name' => env('PROMETHEUS_JOB_NAME', 'agl-hostman'),
]

// ProductionMonitoringService::getPrometheusMetrics()
// Returns Prometheus-formatted metrics
$metrics = [
    'deployment_active_slot' => 0 or 1,  // 0=Blue, 1=Green
    'deployment_active_replicas' => 3,
    'http_requests_total' => ...,
    'http_request_duration_seconds' => ...,
    'http_errors_total' => ...,
    'database_connections_active' => ...,
    'redis_hits_total' => ...,
    'queue_jobs_pending' => ...,
];

// API Endpoint
// routes/api-production.php
Route::get('/metrics', [MonitoringController::class, 'exportPrometheusMetrics'])
    ->name('metrics.prometheus');
```

**Docker Integration:**
```yaml
# docker/production/docker-compose.lb.yml
prometheus:
  image: prom/prometheus:latest
  container_name: prometheus-prod
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
  volumes:
    - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - ./prometheus/rules:/etc/prometheus/rules:ro
    - prometheus-data:/prometheus
  ports:
    - "9090:9090"
```

### 6.2 Grafana Integration

**Status:** ⚠️ **Template implementation only**

```php
// ProductionMonitoringService::getGrafanaDashboard()
// Returns Grafana dashboard JSON configuration
$dashboard = [
    'dashboard' => [
        'title' => 'AGL HostMan Production Monitoring',
        'tags' => ['production', 'laravel', 'blue-green'],
        'panels' => [
            $this->createErrorRatePanel(),        // Error rate over time
            $this->createResponseTimePanel(),     // P95/P99 latency
            $this->createThroughputPanel(),       // Requests per second
            $this->createDatabasePanel(),         // DB performance
            $this->createCachePanel(),            // Redis hit rate
            $this->createDeploymentPanel(),       // Blue-green status
        ],
    ],
];

// Panel example: Error Rate
private function createErrorRatePanel(): array
{
    return [
        'title' => 'Error Rate',
        'type' => 'graph',
        'targets' => [
            [
                'expr' => 'rate(http_errors_total[5m])',
                'legendFormat' => 'Error Rate',
            ],
        ],
        'yaxes' => [
            ['format' => 'percentunit', 'max' => 0.05],
        ],
    ];
}
```

**Docker Integration:**
```yaml
# docker/production/docker-compose.lb.yml
grafana:
  image: grafana/grafana:latest
  container_name: grafana-prod
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  volumes:
    - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    - ./grafana/datasources:/etc/grafana/provisioning/datasources:ro
    - grafana-data:/var/lib/grafana
  ports:
    - "3000:3000"
  depends_on:
    - prometheus
```

### 6.3 Docker Health Checks

**Container-level health checks:**
```dockerfile
# Dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan health:check || exit 1
```

**Docker Compose health checks:**
```yaml
# docker-compose services
app:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s

nginx:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost/health"]
    interval: 30s
    timeout: 5s
    retries: 3

postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME}"]
    interval: 10s
    timeout: 5s
    retries: 5
```

---

## 7. Recommended Skills for Observability

Based on the analysis, here are the recommended skills for enhancing and maintaining this monitoring infrastructure:

### 7.1 Core Competencies

| Skill Area | Relevance | Current State | Recommended Development |
|------------|-----------|---------------|------------------------|
| **Prometheus & Querying (PromQL)** | High | Configured but not used | Learn metric types, PromQL queries, alerting rules |
| **Grafana Dashboarding** | High | Template only | Master panel configuration, variables, annotations |
| **Time-Series Data Modeling** | High | Basic implementation | Learn data retention, downsampling, aggregation |
| **Distributed Tracing** | Medium | Not implemented | Consider OpenTelemetry, Jaeger integration |
| **Log Aggregation (ELK/Loki)** | High | Placeholder only | Implement Elasticsearch/Loki for pattern matching |
| **Statistical Anomaly Detection** | Medium | Placeholder | Learn z-score, MAD, LSTM-based anomaly detection |
| **WebSocket/Real-time Streaming** | Medium | Implemented | Enhance with Pusher/Ably for better scalability |

### 7.2 Specialized Skills

**For Alert Engineering:**
- Alert fatigue management strategies
- Multi-level escalation policies
- Incident response workflows
- On-call rotation management (PagerDuty integration)

**For Performance Analysis:**
- Profiling and optimization techniques
- Database query optimization
- Cache hit/miss analysis
- Memory leak detection

**For Predictive Analytics:**
- Time-series forecasting (ARIMA, Prophet)
- Machine learning for capacity planning
- Resource exhaustion prediction
- Seasonal pattern detection

### 7.3 Tool Proficiency

| Tool | Purpose | Proficiency Level |
|------|---------|------------------|
| **Laravel Telescope** | Debugging and monitoring | Intermediate |
| **Laravel Horizon** | Queue monitoring | Intermediate |
| **Prometheus** | Metrics storage and querying | Beginner → Intermediate |
| **Grafana** | Visualization and dashboards | Beginner → Intermediate |
| **Loki** | Log aggregation | Beginner |
| **Jaeger** | Distributed tracing | Beginner |
| **AlertManager** | Alert routing and deduplication | Beginner |
| **Pushgateway** | Batch metrics push | Beginner |

### 7.4 Architecture Skills

- **Metrics Collection Patterns:** Push vs. Pull, metric cardinality management
- **Observability Pillars:** Metrics, Logs, Traces (M-L-T model)
- **Service Level Objectives (SLOs):** Defining and measuring SLIs
- **Error Budgets:** Balancing reliability with feature velocity
- **Observability-driven Development:** Building observability in from the start

---

## 8. Gap Analysis and Recommendations

### 8.1 Critical Gaps

| Gap | Impact | Effort | Priority |
|-----|--------|--------|----------|
| **Log Aggregation** | High - Cannot implement pattern alerting | Medium | High |
| **Prometheus Export** | Medium - External observability limited | Low | High |
| **Statistical Anomaly Detection** | Medium - Proactive alerts missing | High | Medium |
| **Distributed Tracing** | Medium - Request flow visibility | High | Low |
| **SLO/SLI Tracking** | High - No reliability measurement | Medium | High |

### 8.2 Quick Wins (1-2 weeks)

1. **Enable Prometheus Metrics Export**
   - Implement actual metric push to Pushgateway
   - Set up basic Prometheus queries
   - Create 3-5 core Grafana dashboards

2. **Implement Basic Log Aggregation**
   - Deploy Loki or Elasticsearch
   - Configure Laravel log channels
   - Implement pattern-based alerting

3. **Enhance Alert Rules**
   - Add multi-condition rules
   - Implement alert grouping
   - Add escalation policies

### 8.3 Medium-term Projects (1-2 months)

1. **Statistical Anomaly Detection**
   - Implement z-score based anomaly detection
   - Add baseline learning period
   - Create anomaly visualization

2. **SLO/SLI Framework**
   - Define service level indicators
   - Track error budgets
   - Implement SLO-based alerting

3. **Observability Dashboard Suite**
   - Infrastructure overview
   - Application performance
   - Business metrics
   - Deployment pipeline health

### 8.4 Long-term Enhancements (3-6 months)

1. **Distributed Tracing with OpenTelemetry**
   - Instrument Laravel application
   - Trace requests across services
   - Visualize in Jaeger

2. **Advanced Predictive Analytics**
   - Machine learning models for forecasting
   - Automated capacity planning
   - Cost optimization recommendations

3. **Observability as Code**
   - Terraform/Ansible provisioning
   - GitOps for dashboard configs
   - Automated testing of alert rules

---

## 9. Monitoring Best Practices Observed

### 9.1 Strengths

✅ **Multi-layered monitoring** (infrastructure + application + business)
✅ **Intelligent alert deduplication** (15-min window, rate limiting)
✅ **Real-time broadcasting** (WebSocket updates)
✅ **Polymorphic resource tracking** (flexible data model)
✅ **Comprehensive health checks** (7 categories)
✅ **Performance trend analysis** (time-series data)
✅ **Auto-resolution with TTL** (reduces noise)
✅ **Muting capability** (maintenance windows)
✅ **Deployment health integration** (blue-green safety)

### 9.2 Areas for Improvement

⚠️ **Log aggregation missing** (pattern alerting incomplete)
⚠️ **Prometheus integration partial** (no actual data export)
⚠️ **Anomaly detection placeholder** (not implemented)
⚠️ **Predictive analytics disabled** (feature flag off)
⚠️ **Alert escalation basic** (no multi-level routing)
⚠️ **SLO/SLI not defined** (no reliability measurement)
⚠️ **Distributed tracing absent** (request flow invisible)

---

## 10. Conclusion

This monitoring infrastructure demonstrates a solid foundation for observability with comprehensive metrics collection, intelligent alerting, and real-time updates. The system effectively monitors servers, containers, networks, and storage with appropriate threshold-based alerting.

The primary opportunities for enhancement lie in:
1. Completing Prometheus/Grafana integration for external visibility
2. Implementing log aggregation for pattern-based alerting
3. Adding statistical anomaly detection for proactive alerts
4. Defining SLOs and SLIs for reliability measurement
5. Introducing distributed tracing for request flow analysis

**Maturity Level:** **Intermediate** (3/5)
- Strong fundamentals in place
- Some advanced features incomplete
- Good architecture for scalability
- Ready for production use with enhancements

**Recommended Next Steps:**
1. Enable Prometheus metrics export (Quick Win)
2. Deploy log aggregation (ELK/Loki)
3. Implement SLO tracking framework
4. Enhance Grafana dashboards
5. Add anomaly detection capabilities

---

**Document Version:** 1.0
**Analysis Date:** 2026-02-07
**Project:** AGL HostMan - Infrastructure Monitoring
