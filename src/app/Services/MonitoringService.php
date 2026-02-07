<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Alert;
use App\Models\PerformanceTrend;
use App\Models\ProxmoxServer;
use App\Models\LxcContainer;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Collection;
use Carbon\Carbon;

/**
 * MonitoringService - Core monitoring orchestration service
 *
 * Provides centralized monitoring capabilities including:
 * - Metrics collection coordination
 * - Alert generation and evaluation
 * - Health check scheduling
 * - Performance trend analysis
 *
 * @package App\Services
 */
class MonitoringService
{
    protected MetricsCollector $metricsCollector;
    protected AlertService $alertService;
    protected int $collectionInterval;
    protected int $retentionDays;
    protected array $thresholds;

    public function __construct(
        MetricsCollector $metricsCollector,
        AlertService $alertService
    ) {
        $this->metricsCollector = $metricsCollector;
        $this->alertService = $alertService;
        $this->collectionInterval = (int) config('monitoring.collection_interval', 60);
        $this->retentionDays = (int) config('monitoring.retention_days', 90);
        $this->thresholds = config('monitoring.thresholds', []);
    }

    /**
     * Collect all infrastructure metrics and generate alerts
     *
     * @return array{
     *   success: bool,
     *   metrics_collected: bool,
     *   alerts_generated: int,
     *   trends_recorded: int,
     *   errors: array,
     *   timestamp: string
     * }
     */
    public function collectAndMonitor(): array
    {
        $result = [
            'success' => true,
            'metrics_collected' => false,
            'alerts_generated' => 0,
            'trends_recorded' => 0,
            'errors' => [],
            'timestamp' => now()->toIso8601String(),
        ];

        try {
            // Collect metrics
            $metrics = $this->metricsCollector->aggregateAllMetrics();
            $result['metrics_collected'] = $metrics['success'];

            if (!$metrics['success']) {
                $result['success'] = false;
                $result['errors'][] = 'Failed to collect metrics';
                return $result;
            }

            // Evaluate and generate alerts
            $alerts = $this->evaluateAlerts($metrics);
            $result['alerts_generated'] = count($alerts);

            // Record performance trends
            $trendsCount = $this->recordPerformanceTrends($metrics);
            $result['trends_recorded'] = $trendsCount;

            // Update monitoring cache
            $this->updateMonitoringCache($metrics);

            Log::info('Monitoring collection completed', [
                'alerts_generated' => $result['alerts_generated'],
                'trends_recorded' => $result['trends_recorded'],
            ]);

        } catch (\Exception $e) {
            $result['success'] = false;
            $result['errors'][] = $e->getMessage();
            Log::error('Monitoring collection failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
        }

        return $result;
    }

    /**
     * Evaluate metrics against thresholds and generate alerts
     *
     * @param array $metrics Collected metrics
     * @return array<Alert> Generated alerts
     */
    protected function evaluateAlerts(array $metrics): array
    {
        $alerts = [];

        // Evaluate server alerts
        foreach ($metrics['servers'] ?? [] as $server) {
            $alerts = array_merge($alerts, $this->evaluateServerAlerts($server));
        }

        // Evaluate container alerts
        foreach ($metrics['containers'] ?? [] as $container) {
            $alerts = array_merge($alerts, $this->evaluateContainerAlerts($container));
        }

        // Evaluate network alerts
        $alerts = array_merge($alerts, $this->evaluateNetworkAlerts($metrics['network'] ?? []));

        // Evaluate storage alerts
        $alerts = array_merge($alerts, $this->evaluateStorageAlerts($metrics['storage'] ?? []));

        // Create alerts through service
        $createdAlerts = [];
        foreach ($alerts as $alertData) {
            $alert = $this->alertService->createAlert($alertData);
            if ($alert) {
                $createdAlerts[] = $alert;
            }
        }

        return $createdAlerts;
    }

    /**
     * Evaluate server-specific alerts
     */
    protected function evaluateServerAlerts(array $server): array
    {
        $alerts = [];
        $serverInfo = $server['server'] ?? [];
        $serverMetrics = $server['metrics'] ?? [];

        if (empty($serverMetrics) || $server['health_status'] === 'offline') {
            $alerts[] = [
                'type' => 'critical',
                'title' => "Server Offline: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} ({$serverInfo['code']}) is offline",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 90,
                'metadata' => [
                    'server_code' => $serverInfo['code'],
                    'health_status' => $server['health_status'],
                    'error' => $server['error'] ?? null,
                ],
            ];
            return $alerts;
        }

        $cpuThreshold = $this->thresholds['server']['cpu'] ?? ['warning' => 70, 'critical' => 85];
        $memThreshold = $this->thresholds['server']['memory'] ?? ['warning' => 80, 'critical' => 90];

        // CPU alerts
        $cpuUsage = $serverMetrics['cpu']['usage_percent'] ?? 0;
        if ($cpuUsage >= $cpuThreshold['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => "Critical CPU Usage: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} CPU usage is at {$cpuUsage}%",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 90,
                'metadata' => ['server_code' => $serverInfo['code'], 'cpu_usage' => $cpuUsage],
            ];
        } elseif ($cpuUsage >= $cpuThreshold['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => "High CPU Usage: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} CPU usage is at {$cpuUsage}%",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 70,
                'metadata' => ['server_code' => $serverInfo['code'], 'cpu_usage' => $cpuUsage],
            ];
        }

        // Memory alerts
        $memUsage = $serverMetrics['memory']['usage_percent'] ?? 0;
        if ($memUsage >= $memThreshold['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => "Critical Memory Usage: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} memory usage is at {$memUsage}%",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 90,
                'metadata' => ['server_code' => $serverInfo['code'], 'memory_usage' => $memUsage],
            ];
        } elseif ($memUsage >= $memThreshold['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => "High Memory Usage: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} memory usage is at {$memUsage}%",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 70,
                'metadata' => ['server_code' => $serverInfo['code'], 'memory_usage' => $memUsage],
            ];
        }

        // Load average alerts
        $load = $serverMetrics['load']['1min'] ?? 0;
        $cores = $serverMetrics['cpu']['cores'] ?? 1;
        if ($load > $cores) {
            $alerts[] = [
                'type' => 'warning',
                'title' => "High Load Average: {$serverInfo['name']}",
                'message' => "Server {$serverInfo['name']} load average ({$load}) exceeds CPU cores ({$cores})",
                'source' => 'server',
                'source_id' => $serverInfo['id'],
                'severity' => 60,
                'metadata' => ['server_code' => $serverInfo['code'], 'load' => $load, 'cores' => $cores],
            ];
        }

        return $alerts;
    }

    /**
     * Evaluate container-specific alerts
     */
    protected function evaluateContainerAlerts(array $container): array
    {
        $alerts = [];

        if ($container['status'] !== 'running') {
            // Don't alert for stopped containers (might be intentional)
            return $alerts;
        }

        $containerThreshold = $this->thresholds['container'] ?? [
            'cpu' => ['warning' => 60, 'critical' => 80],
            'memory' => ['warning' => 75, 'critical' => 90],
        ];

        $cpuThreshold = $containerThreshold['cpu'];
        $memThreshold = $containerThreshold['memory'];

        // CPU alerts
        $cpuUsage = $container['cpu']['usage_percent'] ?? 0;
        if ($cpuUsage >= $cpuThreshold['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => "Critical CPU Usage: {$container['name']}",
                'message' => "Container {$container['name']} (CT{$container['vmid']}) CPU usage is at {$cpuUsage}%",
                'source' => 'container',
                'source_id' => $container['id'],
                'severity' => 90,
                'metadata' => [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                    'cpu_usage' => $cpuUsage,
                ],
            ];
        } elseif ($cpuUsage >= $cpuThreshold['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => "High CPU Usage: {$container['name']}",
                'message' => "Container {$container['name']} (CT{$container['vmid']}) CPU usage is at {$cpuUsage}%",
                'source' => 'container',
                'source_id' => $container['id'],
                'severity' => 70,
                'metadata' => [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                    'cpu_usage' => $cpuUsage,
                ],
            ];
        }

        // Memory alerts
        $memUsage = $container['memory']['usage_percent'] ?? 0;
        if ($memUsage >= $memThreshold['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => "Critical Memory Usage: {$container['name']}",
                'message' => "Container {$container['name']} (CT{$container['vmid']}) memory usage is at {$memUsage}%",
                'source' => 'container',
                'source_id' => $container['id'],
                'severity' => 90,
                'metadata' => [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                    'memory_usage' => $memUsage,
                ],
            ];
        } elseif ($memUsage >= $memThreshold['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => "High Memory Usage: {$container['name']}",
                'message' => "Container {$container['name']} (CT{$container['vmid']}) memory usage is at {$memUsage}%",
                'source' => 'container',
                'source_id' => $container['id'],
                'severity' => 70,
                'metadata' => [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                    'memory_usage' => $memUsage,
                ],
            ];
        }

        return $alerts;
    }

    /**
     * Evaluate network-specific alerts
     */
    protected function evaluateNetworkAlerts(array $network): array
    {
        $alerts = [];

        if (!$network['success'] ?? false) {
            return $alerts;
        }

        $threshold = $this->thresholds['network'] ?? [
            'connection_rate' => ['warning' => 95, 'critical' => 80],
            'latency' => ['warning' => 50, 'critical' => 150],
        ];

        $summary = $network['summary'] ?? [];
        $connectedRate = $summary['total_peers'] > 0
            ? ($summary['connected_peers'] / $summary['total_peers']) * 100
            : 100;
        $avgLatency = $summary['avg_latency_ms'] ?? 0;

        // Connection rate alerts
        if ($connectedRate <= $threshold['connection_rate']['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => 'Critical Network Connectivity',
                'message' => "Only {$summary['connected_peers']}/{$summary['total_peers']} WireGuard peers connected",
                'source' => 'network',
                'source_id' => null,
                'severity' => 90,
                'metadata' => [
                    'connected_peers' => $summary['connected_peers'],
                    'total_peers' => $summary['total_peers'],
                    'connection_rate' => round($connectedRate, 1),
                ],
            ];
        } elseif ($connectedRate < $threshold['connection_rate']['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => 'Network Connectivity Degraded',
                'message' => "Only {$summary['connected_peers']}/{$summary['total_peers']} WireGuard peers connected",
                'source' => 'network',
                'source_id' => null,
                'severity' => 70,
                'metadata' => [
                    'connected_peers' => $summary['connected_peers'],
                    'total_peers' => $summary['total_peers'],
                    'connection_rate' => round($connectedRate, 1),
                ],
            ];
        }

        // Latency alerts
        if ($avgLatency >= $threshold['latency']['critical']) {
            $alerts[] = [
                'type' => 'critical',
                'title' => 'High Network Latency',
                'message' => "Average WireGuard latency is {$avgLatency}ms",
                'source' => 'network',
                'source_id' => null,
                'severity' => 80,
                'metadata' => ['avg_latency_ms' => $avgLatency],
            ];
        } elseif ($avgLatency >= $threshold['latency']['warning']) {
            $alerts[] = [
                'type' => 'warning',
                'title' => 'Elevated Network Latency',
                'message' => "Average WireGuard latency is {$avgLatency}ms",
                'source' => 'network',
                'source_id' => null,
                'severity' => 60,
                'metadata' => ['avg_latency_ms' => $avgLatency],
            ];
        }

        return $alerts;
    }

    /**
     * Evaluate storage-specific alerts
     */
    protected function evaluateStorageAlerts(array $storage): array
    {
        $alerts = [];

        if (!$storage['success'] ?? false) {
            return $alerts;
        }

        $threshold = $this->thresholds['storage'] ?? ['warning' => 70, 'critical' => 85];

        foreach ($storage['mounts'] ?? [] as $mount) {
            $usage = $mount['percent_used'] ?? 0;

            if ($usage >= $threshold['critical']) {
                $alerts[] = [
                    'type' => 'critical',
                    'title' => "Critical Disk Usage: {$mount['server']}",
                    'message' => "Storage {$mount['name']} on {$mount['server']} is at {$usage}%",
                    'source' => 'storage',
                    'source_id' => $mount['server'],
                    'severity' => 90,
                    'metadata' => [
                        'server' => $mount['server'],
                        'storage_name' => $mount['name'],
                        'usage_percent' => $usage,
                        'used_gb' => $mount['used_gb'],
                        'total_gb' => $mount['total_gb'],
                    ],
                ];
            } elseif ($usage >= $threshold['warning']) {
                $alerts[] = [
                    'type' => 'warning',
                    'title' => "High Disk Usage: {$mount['server']}",
                    'message' => "Storage {$mount['name']} on {$mount['server']} is at {$usage}%",
                    'source' => 'storage',
                    'source_id' => $mount['server'],
                    'severity' => 70,
                    'metadata' => [
                        'server' => $mount['server'],
                        'storage_name' => $mount['name'],
                        'usage_percent' => $usage,
                        'used_gb' => $mount['used_gb'],
                        'total_gb' => $mount['total_gb'],
                    ],
                ];
            }
        }

        return $alerts;
    }

    /**
     * Record performance trends for analysis
     *
     * @param array $metrics Collected metrics
     * @return int Number of trends recorded
     */
    protected function recordPerformanceTrends(array $metrics): int
    {
        $count = 0;

        // Record server trends
        foreach ($metrics['servers'] ?? [] as $server) {
            if (!isset($server['metrics'])) {
                continue;
            }

            $serverInfo = $server['server'];
            $serverMetrics = $server['metrics'];

            // CPU trend
            PerformanceTrend::record(
                'ProxmoxServer',
                (string) $serverInfo['id'],
                'cpu_usage',
                $serverMetrics['cpu']['usage_percent'],
                '%',
                ['server_code' => $serverInfo['code']]
            );
            $count++;

            // Memory trend
            PerformanceTrend::record(
                'ProxmoxServer',
                (string) $serverInfo['id'],
                'memory_usage',
                $serverMetrics['memory']['usage_percent'],
                '%',
                ['server_code' => $serverInfo['code']]
            );
            $count++;

            // Load average trend
            PerformanceTrend::record(
                'ProxmoxServer',
                (string) $serverInfo['id'],
                'load_average',
                $serverMetrics['load']['1min'],
                '',
                ['server_code' => $serverInfo['code']]
            );
            $count++;
        }

        // Record container trends
        foreach ($metrics['containers'] ?? [] as $container) {
            if ($container['status'] !== 'running') {
                continue;
            }

            // CPU trend
            PerformanceTrend::record(
                'LxcContainer',
                (string) $container['id'],
                'cpu_usage',
                $container['cpu']['usage_percent'],
                '%',
                [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                ]
            );
            $count++;

            // Memory trend
            PerformanceTrend::record(
                'LxcContainer',
                (string) $container['id'],
                'memory_usage',
                $container['memory']['usage_percent'],
                '%',
                [
                    'container_name' => $container['name'],
                    'vmid' => $container['vmid'],
                ]
            );
            $count++;
        }

        // Record network trends
        if (isset($metrics['network']['summary'])) {
            $summary = $metrics['network']['summary'];
            PerformanceTrend::record(
                'Network',
                'wireguard-mesh',
                'connection_rate',
                $summary['total_peers'] > 0
                    ? ($summary['connected_peers'] / $summary['total_peers']) * 100
                    : 100,
                '%',
                ['total_peers' => $summary['total_peers']]
            );
            $count++;

            PerformanceTrend::record(
                'Network',
                'wireguard-mesh',
                'avg_latency',
                $summary['avg_latency_ms'],
                'ms',
                ['total_peers' => $summary['total_peers']]
            );
            $count++;
        }

        // Record storage trends
        if (isset($metrics['storage']['summary'])) {
            $summary = $metrics['storage']['summary'];
            PerformanceTrend::record(
                'Storage',
                'aggregate',
                'usage_percent',
                $summary['avg_usage_percent'],
                '%',
                ['mount_count' => $summary['mount_count']]
            );
            $count++;
        }

        return $count;
    }

    /**
     * Update monitoring cache with latest metrics
     */
    protected function updateMonitoringCache(array $metrics): void
    {
        Cache::put('monitoring:latest', $metrics, 300); // 5 minutes
        Cache::put('monitoring:summary', $metrics['summary'] ?? [], 300);
        Cache::put('monitoring:last_collected', now()->toIso8601String(), 300);
    }

    /**
     * Get comprehensive health status
     *
     * @return array{
     *   overall_health: string,
     *   servers: array,
     *   containers: array,
     *   network: array,
     *   storage: array,
     *   active_alerts: int,
     *   last_collected: string
     * }
     */
    public function getHealthStatus(): array
    {
        $cached = Cache::get('monitoring:latest');

        if ($cached) {
            $summary = $cached['summary'] ?? [];
        } else {
            $metrics = $this->metricsCollector->aggregateAllMetrics();
            $summary = $metrics['summary'] ?? [];
        }

        $activeAlerts = $this->alertService->getActiveAlerts()->count();

        return [
            'overall_health' => $summary['overall_health'] ?? 'unknown',
            'servers' => [
                'total' => $summary['total_servers'] ?? 0,
                'online' => $summary['online_servers'] ?? 0,
                'offline' => ($summary['total_servers'] ?? 0) - ($summary['online_servers'] ?? 0),
            ],
            'containers' => [
                'total' => $summary['total_containers'] ?? 0,
                'running' => $summary['running_containers'] ?? 0,
                'stopped' => $summary['stopped_containers'] ?? 0,
                'warning' => $summary['warning_containers'] ?? 0,
                'critical' => $summary['critical_containers'] ?? 0,
            ],
            'network' => [
                'status' => $cached['network']['health_status'] ?? 'unknown',
                'summary' => $cached['network']['summary'] ?? [],
            ],
            'storage' => [
                'status' => $cached['storage']['health_status'] ?? 'unknown',
                'summary' => $cached['storage']['summary'] ?? [],
            ],
            'active_alerts' => $activeAlerts,
            'last_collected' => Cache::get('monitoring:last_collected', 'never'),
        ];
    }

    /**
     * Get performance trend analysis
     *
     * @param string|null $resourceType Filter by resource type
     * @param string|null $resourceId Filter by resource ID
     * @param int $hours Time period in hours
     * @return array
     */
    public function getPerformanceTrends(
        ?string $resourceType = null,
        ?string $resourceId = null,
        int $hours = 24
    ): array {
        $query = PerformanceTrend::recent($hours)->ordered();

        if ($resourceType && $resourceId) {
            $query->byResource($resourceType, $resourceId);
        } elseif ($resourceType) {
            $query->where('resource_type', $resourceType);
        }

        $trends = $query->get();

        // Group by metric type
        $grouped = $trends->groupBy('metric_type');

        $result = [];
        foreach ($grouped as $metricType => $metrics) {
            $values = $metrics->pluck('value')->toArray();
            $result[$metricType] = [
                'current' => end($values),
                'min' => min($values),
                'max' => max($values),
                'avg' => round(array_sum($values) / count($values), 2),
                'trend' => $this->calculateTrendDirection($values),
                'data_points' => count($values),
            ];
        }

        return $result;
    }

    /**
     * Calculate trend direction
     */
    protected function calculateTrendDirection(array $values): string
    {
        if (count($values) < 2) {
            return 'stable';
        }

        $first = array_slice($values, 0, max(1, (int) (count($values) / 3)));
        $last = array_slice($values, -max(1, (int) (count($values) / 3)));

        $firstAvg = array_sum($first) / count($first);
        $lastAvg = array_sum($last) / count($last);

        $change = (($lastAvg - $firstAvg) / $firstAvg) * 100;

        if (abs($change) < 5) {
            return 'stable';
        }

        return $change > 0 ? 'increasing' : 'decreasing';
    }

    /**
     * Cleanup old performance trends
     */
    public function cleanupOldData(): int
    {
        $trendsDeleted = PerformanceTrend::cleanupOldTrends($this->retentionDays);
        $alertsDeleted = $this->alertService->cleanupOldAlerts($this->retentionDays);

        Log::info('Monitoring cleanup completed', [
            'trends_deleted' => $trendsDeleted,
            'alerts_deleted' => $alertsDeleted,
            'retention_days' => $this->retentionDays,
        ]);

        return $trendsDeleted + $alertsDeleted;
    }

    /**
     * Force refresh all monitoring data
     */
    public function refreshAll(): array
    {
        $this->metricsCollector->refreshAllMetrics();
        Cache::forget('monitoring:latest');
        Cache::forget('monitoring:summary');
        Cache::forget('monitoring:last_collected');

        return $this->collectAndMonitor();
    }
}
