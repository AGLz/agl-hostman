<?php

namespace App\Services;

use App\Repositories\ProxmoxContainerRepository;
use App\DTOs\ContainerMetrics;
use App\Events\ContainerCritical;
use App\Events\ResourceExhaustionPredicted;
use App\Models\ContainerHealthLog;
use App\Models\PerformanceTrend;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Carbon\Carbon;

/**
 * Real-time Container Health Monitoring Service
 *
 * Monitors container health across Proxmox nodes, tracks trends,
 * detects anomalies, and triggers alerts for critical conditions.
 *
 * Features:
 * - Real-time health status monitoring
 * - Historical trend analysis
 * - Anomaly detection
 * - Predictive alerts
 * - Multi-threshold alerting (warning, critical)
 *
 * @package App\Services
 */
class ContainerHealthMonitor
{
    protected ProxmoxContainerRepository $repository;
    protected PredictiveMaintenanceService $predictiveService;
    protected AlertDispatcher $alertDispatcher;

    /**
     * Health check thresholds
     */
    protected array $thresholds = [
        'cpu' => [
            'warning' => 70,
            'critical' => 90,
        ],
        'memory' => [
            'warning' => 70,
            'critical' => 85,
        ],
        'disk' => [
            'warning' => 60,
            'critical' => 80,
        ],
        'uptime' => [
            'minimum' => 300, // 5 minutes - flag containers restarting frequently
        ],
    ];

    /**
     * Monitoring intervals (seconds)
     */
    protected array $intervals = [
        'realtime' => 30,      // Real-time monitoring every 30s
        'analysis' => 300,     // Trend analysis every 5 minutes
        'prediction' => 1800,  // Predictive analysis every 30 minutes
    ];

    public function __construct(
        ProxmoxContainerRepository $repository,
        PredictiveMaintenanceService $predictiveService,
        AlertDispatcher $alertDispatcher
    ) {
        $this->repository = $repository;
        $this->predictiveService = $predictiveService;
        $this->alertDispatcher = $alertDispatcher;
    }

    /**
     * Monitor all containers across specified nodes
     *
     * @param array $nodes Node codes to monitor (e.g., ['pve1', 'pve2'])
     * @return array Monitoring results
     */
    public function monitorNodes(array $nodes): array
    {
        $results = [
            'timestamp' => now()->toIso8601String(),
            'nodes' => [],
            'summary' => [
                'total_containers' => 0,
                'healthy' => 0,
                'warning' => 0,
                'critical' => 0,
                'stopped' => 0,
            ],
            'alerts_triggered' => 0,
        ];

        foreach ($nodes as $node) {
            $nodeResults = $this->monitorNode($node);
            $results['nodes'][$node] = $nodeResults;

            // Aggregate summary
            $results['summary']['total_containers'] += $nodeResults['total_containers'];
            $results['summary']['healthy'] += $nodeResults['healthy'];
            $results['summary']['warning'] += $nodeResults['warning'];
            $results['summary']['critical'] += $nodeResults['critical'];
            $results['summary']['stopped'] += $nodeResults['stopped'];
            $results['alerts_triggered'] += $nodeResults['alerts_triggered'];
        }

        // Store aggregated monitoring result
        $this->storeMonitoringSnapshot($results);

        return $results;
    }

    /**
     * Monitor containers on a single node
     *
     * @param string $node Node code
     * @return array Node monitoring results
     */
    public function monitorNode(string $node): array
    {
        try {
            $containers = $this->repository->getAllContainers($node);

            $results = [
                'node' => $node,
                'timestamp' => now()->toIso8601String(),
                'total_containers' => $containers->count(),
                'healthy' => 0,
                'warning' => 0,
                'critical' => 0,
                'stopped' => 0,
                'containers' => [],
                'alerts_triggered' => 0,
            ];

            foreach ($containers as $container) {
                $healthCheck = $this->checkContainerHealth($node, $container);
                $results['containers'][] = $healthCheck;

                // Count by health status
                $status = $healthCheck['health_status'];
                $results[$status] = ($results[$status] ?? 0) + 1;

                // Trigger alerts if needed
                if ($healthCheck['requires_alert']) {
                    $this->triggerAlert($node, $container, $healthCheck);
                    $results['alerts_triggered']++;
                }

                // Log health status
                $this->logContainerHealth($node, $container, $healthCheck);
            }

            return $results;

        } catch (\Exception $e) {
            Log::error("Failed to monitor node {$node}: {$e->getMessage()}");
            return [
                'node' => $node,
                'error' => $e->getMessage(),
                'timestamp' => now()->toIso8601String(),
            ];
        }
    }

    /**
     * Check individual container health
     *
     * @param string $node Node code
     * @param ContainerMetrics $container Container metrics
     * @return array Health check results
     */
    protected function checkContainerHealth(string $node, ContainerMetrics $container): array
    {
        $healthStatus = $container->getHealthStatus();
        $issues = [];
        $requiresAlert = false;
        $severity = 'info';

        // Check CPU
        if ($container->cpuUsagePercent >= $this->thresholds['cpu']['critical']) {
            $issues[] = "Critical CPU usage: {$container->cpuUsagePercent}%";
            $requiresAlert = true;
            $severity = 'critical';
        } elseif ($container->cpuUsagePercent >= $this->thresholds['cpu']['warning']) {
            $issues[] = "High CPU usage: {$container->cpuUsagePercent}%";
            if ($healthStatus !== 'critical') {
                $severity = 'warning';
            }
        }

        // Check Memory
        $memoryPercent = $container->getMemoryUsagePercent();
        if ($memoryPercent >= $this->thresholds['memory']['critical']) {
            $issues[] = "Critical memory usage: {$memoryPercent}%";
            $requiresAlert = true;
            $severity = 'critical';
        } elseif ($memoryPercent >= $this->thresholds['memory']['warning']) {
            $issues[] = "High memory usage: {$memoryPercent}%";
            if ($severity !== 'critical') {
                $severity = 'warning';
            }
        }

        // Check Disk
        $diskPercent = $container->getDiskUsagePercent();
        if ($diskPercent >= $this->thresholds['disk']['critical']) {
            $issues[] = "Critical disk usage: {$diskPercent}%";
            $requiresAlert = true;
            $severity = 'critical';
        } elseif ($diskPercent >= $this->thresholds['disk']['warning']) {
            $issues[] = "High disk usage: {$diskPercent}%";
            if ($severity !== 'critical') {
                $severity = 'warning';
            }
        }

        // Check for frequent restarts
        if ($container->isRunning() && $container->uptimeSeconds < $this->thresholds['uptime']['minimum']) {
            $issues[] = "Container recently restarted (uptime: {$container->getUptimeHuman()})";
            if ($severity === 'info') {
                $severity = 'warning';
            }
        }

        // Get historical trend
        $trend = $this->getHealthTrend($node, $container->vmid);

        return [
            'vmid' => $container->vmid,
            'name' => $container->name,
            'health_status' => $healthStatus,
            'severity' => $severity,
            'issues' => $issues,
            'requires_alert' => $requiresAlert,
            'metrics' => [
                'cpu_percent' => round($container->cpuUsagePercent, 2),
                'memory_percent' => round($memoryPercent, 2),
                'disk_percent' => round($diskPercent, 2),
                'uptime' => $container->getUptimeHuman(),
            ],
            'trend' => $trend,
            'checked_at' => now()->toIso8601String(),
        ];
    }

    /**
     * Get health trend for a container
     *
     * @param string $node Node code
     * @param int $vmid Container VMID
     * @return array Trend analysis
     */
    protected function getHealthTrend(string $node, int $vmid): array
    {
        $cacheKey = "health_trend:{$node}:{$vmid}";

        return Cache::remember($cacheKey, now()->addMinutes(5), function () use ($node, $vmid) {
            // Get last 24 hours of health logs
            $logs = ContainerHealthLog::where('node_code', $node)
                ->where('vmid', $vmid)
                ->where('created_at', '>=', now()->subDay())
                ->orderBy('created_at', 'desc')
                ->limit(100)
                ->get();

            if ($logs->isEmpty()) {
                return [
                    'status' => 'insufficient_data',
                    'message' => 'Not enough historical data',
                ];
            }

            $cpuTrend = $this->calculateTrend($logs->pluck('cpu_usage_percent'));
            $memoryTrend = $this->calculateTrend($logs->pluck('memory_usage_percent'));
            $diskTrend = $this->calculateTrend($logs->pluck('disk_usage_percent'));

            return [
                'cpu' => $cpuTrend,
                'memory' => $memoryTrend,
                'disk' => $diskTrend,
                'data_points' => $logs->count(),
                'period' => '24h',
            ];
        });
    }

    /**
     * Calculate trend from time series data
     *
     * @param Collection $data Data points
     * @return array Trend analysis (increasing, stable, decreasing)
     */
    protected function calculateTrend(Collection $data): array
    {
        if ($data->count() < 2) {
            return ['direction' => 'unknown', 'change_percent' => 0];
        }

        $recent = $data->take(10)->avg();
        $older = $data->skip(10)->take(10)->avg();

        if ($older == 0) {
            return ['direction' => 'stable', 'change_percent' => 0];
        }

        $changePercent = (($recent - $older) / $older) * 100;

        if (abs($changePercent) < 5) {
            $direction = 'stable';
        } elseif ($changePercent > 0) {
            $direction = 'increasing';
        } else {
            $direction = 'decreasing';
        }

        return [
            'direction' => $direction,
            'change_percent' => round($changePercent, 2),
            'recent_avg' => round($recent, 2),
            'older_avg' => round($older, 2),
        ];
    }

    /**
     * Trigger alert for critical container
     *
     * @param string $node Node code
     * @param ContainerMetrics $container Container metrics
     * @param array $healthCheck Health check results
     * @return void
     */
    protected function triggerAlert(string $node, ContainerMetrics $container, array $healthCheck): void
    {
        // Prevent alert spam - only alert once per hour for same issue
        $alertKey = "alert:{$node}:{$container->vmid}:{$healthCheck['severity']}";

        if (Cache::has($alertKey)) {
            return;
        }

        Cache::put($alertKey, true, now()->addHour());

        // Dispatch event
        event(new ContainerCritical(
            $node,
            $container->vmid,
            $container->name,
            $healthCheck['severity'],
            $healthCheck['issues'],
            $healthCheck['metrics']
        ));

        // Send alerts via dispatcher
        $this->alertDispatcher->dispatch(
            'container_critical',
            [
                'node' => $node,
                'container' => $container->name,
                'vmid' => $container->vmid,
                'severity' => $healthCheck['severity'],
                'issues' => $healthCheck['issues'],
                'metrics' => $healthCheck['metrics'],
            ],
            $healthCheck['severity']
        );

        Log::warning("Critical alert triggered for {$container->name} on {$node}", [
            'vmid' => $container->vmid,
            'issues' => $healthCheck['issues'],
        ]);
    }

    /**
     * Log container health status
     *
     * @param string $node Node code
     * @param ContainerMetrics $container Container metrics
     * @param array $healthCheck Health check results
     * @return void
     */
    protected function logContainerHealth(string $node, ContainerMetrics $container, array $healthCheck): void
    {
        ContainerHealthLog::create([
            'node_code' => $node,
            'vmid' => $container->vmid,
            'container_name' => $container->name,
            'health_status' => $healthCheck['health_status'],
            'cpu_usage_percent' => $container->cpuUsagePercent,
            'memory_usage_percent' => $container->getMemoryUsagePercent(),
            'disk_usage_percent' => $container->getDiskUsagePercent(),
            'uptime_seconds' => $container->uptimeSeconds,
            'issues' => $healthCheck['issues'],
            'metrics' => $healthCheck['metrics'],
        ]);
    }

    /**
     * Store monitoring snapshot for analysis
     *
     * @param array $results Monitoring results
     * @return void
     */
    protected function storeMonitoringSnapshot(array $results): void
    {
        Cache::put('latest_monitoring_snapshot', $results, now()->addHour());

        PerformanceTrend::create([
            'metric_type' => 'cluster_health',
            'metric_name' => 'monitoring_snapshot',
            'value' => $results['summary']['total_containers'],
            'metadata' => [
                'healthy' => $results['summary']['healthy'],
                'warning' => $results['summary']['warning'],
                'critical' => $results['summary']['critical'],
                'stopped' => $results['summary']['stopped'],
                'alerts_triggered' => $results['alerts_triggered'],
            ],
            'recorded_at' => now(),
        ]);
    }

    /**
     * Get latest monitoring snapshot
     *
     * @return array|null Latest snapshot or null
     */
    public function getLatestSnapshot(): ?array
    {
        return Cache::get('latest_monitoring_snapshot');
    }

    /**
     * Get container health history
     *
     * @param string $node Node code
     * @param int $vmid Container VMID
     * @param int $hours Hours of history (default 24)
     * @return Collection Health logs
     */
    public function getContainerHistory(string $node, int $vmid, int $hours = 24): Collection
    {
        return ContainerHealthLog::where('node_code', $node)
            ->where('vmid', $vmid)
            ->where('created_at', '>=', now()->subHours($hours))
            ->orderBy('created_at', 'desc')
            ->get();
    }

    /**
     * Get cluster-wide health statistics
     *
     * @return array Cluster statistics
     */
    public function getClusterHealthStatistics(): array
    {
        $last24h = now()->subDay();

        return [
            'current' => $this->getLatestSnapshot()['summary'] ?? [],
            'alerts_last_24h' => ContainerHealthLog::where('created_at', '>=', $last24h)
                ->whereJsonLength('issues', '>', 0)
                ->count(),
            'critical_incidents' => ContainerHealthLog::where('created_at', '>=', $last24h)
                ->where('health_status', 'critical')
                ->count(),
            'most_critical_containers' => $this->getMostCriticalContainers(10),
        ];
    }

    /**
     * Get containers with most critical issues
     *
     * @param int $limit Number of containers to return
     * @return Collection Most critical containers
     */
    protected function getMostCriticalContainers(int $limit = 10): Collection
    {
        return ContainerHealthLog::select('node_code', 'vmid', 'container_name')
            ->selectRaw('COUNT(*) as critical_count')
            ->where('created_at', '>=', now()->subDay())
            ->where('health_status', 'critical')
            ->groupBy('node_code', 'vmid', 'container_name')
            ->orderByDesc('critical_count')
            ->limit($limit)
            ->get();
    }
}
