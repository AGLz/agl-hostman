<?php

namespace App\Http\Controllers;

use App\Models\ContainerHealthLog;
use App\Models\PerformanceTrend;
use App\Models\ProxmoxServer;
use App\Services\ContainerHealthMonitor;
use App\Services\PredictiveMaintenanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/**
 * Dashboard Controller
 *
 * Provides API endpoints for the monitoring dashboard,
 * serving real-time health data, trends, and predictions.
 */
class DashboardController extends Controller
{
    protected ContainerHealthMonitor $healthMonitor;

    protected PredictiveMaintenanceService $predictiveService;

    public function __construct(
        ContainerHealthMonitor $healthMonitor,
        PredictiveMaintenanceService $predictiveService
    ) {
        $this->healthMonitor = $healthMonitor;
        $this->predictiveService = $predictiveService;
    }

    /**
     * Dashboard home view
     */
    public function index()
    {
        return view('dashboard.index', [
            'pageTitle' => 'Infrastructure Monitoring Dashboard',
            'nodes' => ProxmoxServer::online()->get(),
        ]);
    }

    /**
     * Get cluster-wide health summary
     */
    public function getClusterHealth(): JsonResponse
    {
        $cacheKey = 'dashboard:cluster_health';

        $data = Cache::remember($cacheKey, now()->addSeconds(30), function () {
            $stats = $this->healthMonitor->getClusterHealthStatistics();
            $servers = ProxmoxServer::online()->get();

            return [
                'timestamp' => now()->toIso8601String(),
                'servers' => [
                    'total' => $servers->count(),
                    'online' => $servers->where('status', 'online')->count(),
                    'offline' => $servers->where('status', 'offline')->count(),
                ],
                'containers' => $stats['current'] ?? [
                    'total' => 0,
                    'healthy' => 0,
                    'warning' => 0,
                    'critical' => 0,
                ],
                'alerts' => [
                    'last_24h' => $stats['alerts_last_24h'] ?? 0,
                    'critical_incidents' => $stats['critical_incidents'] ?? 0,
                ],
                'health_score' => $this->calculateHealthScore($stats),
            ];
        });

        return response()->json($data);
    }

    /**
     * Get node-specific health data
     */
    public function getNodeHealth(string $node): JsonResponse
    {
        $cacheKey = "dashboard:node_health:{$node}";

        $data = Cache::remember($cacheKey, now()->addSeconds(30), function () use ($node) {
            try {
                $results = $this->healthMonitor->monitorNode($node);

                return [
                    'timestamp' => now()->toIso8601String(),
                    'node' => $node,
                    'status' => 'online',
                    'containers' => [
                        'total' => $results['total_containers'],
                        'healthy' => $results['healthy'],
                        'warning' => $results['warning'],
                        'critical' => $results['critical'],
                    ],
                    'container_details' => collect($results['containers'])
                        ->map(fn ($container) => [
                            'vmid' => $container['vmid'],
                            'name' => $container['name'],
                            'health_status' => $container['health_status'],
                            'severity' => $container['severity'],
                            'metrics' => $container['metrics'],
                            'issues' => $container['issues'],
                            'trend' => $container['trend'] ?? null,
                        ])
                        ->toArray(),
                ];
            } catch (\Exception $e) {
                return [
                    'timestamp' => now()->toIso8601String(),
                    'node' => $node,
                    'status' => 'error',
                    'error' => $e->getMessage(),
                ];
            }
        });

        return response()->json($data);
    }

    /**
     * Get container-specific health history
     */
    public function getContainerHistory(string $node, int $vmid, Request $request): JsonResponse
    {
        $hours = $request->input('hours', 24);
        $hours = min(max($hours, 1), 168); // Limit between 1 hour and 7 days

        $history = $this->healthMonitor->getContainerHistory($node, $vmid, $hours);

        $data = [
            'node' => $node,
            'vmid' => $vmid,
            'hours' => $hours,
            'container_name' => $history->first()->container_name ?? 'Unknown',
            'data_points' => $history->count(),
            'history' => $history->map(fn ($log) => [
                'timestamp' => $log->created_at->toIso8601String(),
                'health_status' => $log->health_status,
                'cpu_percent' => $log->cpu_usage_percent,
                'memory_percent' => $log->memory_usage_percent,
                'disk_percent' => $log->disk_usage_percent,
                'uptime_seconds' => $log->uptime_seconds,
                'issues' => $log->issues,
            ])->values()->toArray(),
            'statistics' => [
                'avg_cpu' => round($history->avg('cpu_usage_percent'), 2),
                'avg_memory' => round($history->avg('memory_usage_percent'), 2),
                'avg_disk' => round($history->avg('disk_usage_percent'), 2),
                'max_cpu' => round($history->max('cpu_usage_percent'), 2),
                'max_memory' => round($history->max('memory_usage_percent'), 2),
                'max_disk' => round($history->max('disk_usage_percent'), 2),
                'critical_incidents' => $history->where('health_status', 'critical')->count(),
                'warning_incidents' => $history->where('health_status', 'warning')->count(),
            ],
        ];

        return response()->json($data);
    }

    /**
     * Get resource trend data for charts
     */
    public function getResourceTrends(Request $request): JsonResponse
    {
        $metricType = $request->input('metric_type', 'cluster_health');
        $metricName = $request->input('metric_name', 'avg_cpu_usage');
        $hours = $request->input('hours', 24);
        $node = $request->input('node');
        $vmid = $request->input('vmid');

        $hours = min(max($hours, 1), 168);

        $stats = PerformanceTrend::getTrendStats(
            $metricType,
            $metricName,
            $hours,
            $node,
            $vmid
        );

        // Get detailed trend data points
        $query = PerformanceTrend::ofType($metricType)
            ->named($metricName)
            ->recent($hours)
            ->chronological();

        if ($node) {
            $query->forNode($node);
        }

        if ($vmid) {
            $query->where('vmid', $vmid);
        }

        $dataPoints = $query->get()->map(fn ($trend) => [
            'timestamp' => $trend->recorded_at->toIso8601String(),
            'value' => $trend->value,
            'metadata' => $trend->metadata,
        ])->toArray();

        return response()->json([
            'metric_type' => $metricType,
            'metric_name' => $metricName,
            'hours' => $hours,
            'node' => $node,
            'vmid' => $vmid,
            'statistics' => $stats,
            'data_points' => $dataPoints,
        ]);
    }

    /**
     * Get alert history
     */
    public function getAlertHistory(Request $request): JsonResponse
    {
        $hours = $request->input('hours', 24);
        $severity = $request->input('severity');
        $node = $request->input('node');
        $limit = $request->input('limit', 50);

        $hours = min(max($hours, 1), 168);
        $limit = min(max($limit, 10), 200);

        $query = ContainerHealthLog::query()
            ->where('created_at', '>=', now()->subHours($hours))
            ->orderBy('created_at', 'desc')
            ->limit($limit);

        if ($severity) {
            if ($severity === 'unhealthy') {
                $query->unhealthy();
            } elseif ($severity === 'critical') {
                $query->critical();
            } else {
                $query->where('health_status', $severity);
            }
        } else {
            // By default, only show warning and critical
            $query->unhealthy();
        }

        if ($node) {
            $query->forNode($node);
        }

        $alerts = $query->get();

        return response()->json([
            'hours' => $hours,
            'severity' => $severity,
            'node' => $node,
            'total_alerts' => $alerts->count(),
            'alerts' => $alerts->map(fn ($alert) => [
                'timestamp' => $alert->created_at->toIso8601String(),
                'node' => $alert->node_code,
                'vmid' => $alert->vmid,
                'container' => $alert->container_name,
                'health_status' => $alert->health_status,
                'cpu_percent' => $alert->cpu_usage_percent,
                'memory_percent' => $alert->memory_usage_percent,
                'disk_percent' => $alert->disk_usage_percent,
                'issues' => $alert->issues,
                'uptime' => $alert->formatted_uptime,
            ])->toArray(),
        ]);
    }

    /**
     * Get predictive maintenance forecasts
     */
    public function getPredictiveMaintenance(Request $request): JsonResponse
    {
        $node = $request->input('node');
        $vmid = $request->input('vmid');
        $resourceType = $request->input('resource_type', 'memory');
        $horizon = $request->input('horizon', 'medium_term');

        if (! $node || ! $vmid) {
            return response()->json([
                'error' => 'Node and VMID are required for predictive maintenance',
            ], 400);
        }

        try {
            $prediction = $this->predictiveService->predictResourceExhaustion(
                $node,
                (int) $vmid,
                $resourceType,
                $horizon
            );

            return response()->json([
                'node' => $node,
                'vmid' => $vmid,
                'resource_type' => $resourceType,
                'horizon' => $horizon,
                'prediction' => $prediction,
                'timestamp' => now()->toIso8601String(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Get cluster-wide predictive forecasts
     */
    public function getClusterForecasts(): JsonResponse
    {
        try {
            $servers = ProxmoxServer::online()->get();
            $nodes = $servers->pluck('code')->toArray();

            $forecasts = $this->predictiveService->predictClusterFailures($nodes);

            return response()->json([
                'timestamp' => now()->toIso8601String(),
                'nodes_analyzed' => count($nodes),
                'forecasts' => $forecasts,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Get real-time monitoring snapshot
     */
    public function getRealtimeSnapshot(): JsonResponse
    {
        $snapshot = $this->healthMonitor->getLatestSnapshot();

        if (! $snapshot) {
            return response()->json([
                'error' => 'No monitoring snapshot available. Please wait for the monitoring job to run.',
            ], 404);
        }

        return response()->json([
            'snapshot' => $snapshot,
            'cache_timestamp' => now()->toIso8601String(),
        ]);
    }

    /**
     * Calculate overall health score (0-100)
     */
    protected function calculateHealthScore(array $stats): int
    {
        $current = $stats['current'] ?? [];
        $total = $current['total'] ?? 1; // Prevent division by zero

        if ($total === 0) {
            return 100; // No containers = perfect health
        }

        $healthy = $current['healthy'] ?? 0;
        $warning = $current['warning'] ?? 0;
        $critical = $current['critical'] ?? 0;

        // Weighted scoring: healthy=100%, warning=50%, critical=0%
        $score = (
            ($healthy * 100) +
            ($warning * 50) +
            ($critical * 0)
        ) / $total;

        return (int) round($score);
    }

    /**
     * Get dashboard statistics for quick overview
     */
    public function getDashboardStats(): JsonResponse
    {
        $cacheKey = 'dashboard:stats';

        $data = Cache::remember($cacheKey, now()->addSeconds(30), function () {
            $servers = ProxmoxServer::all();
            $onlineServers = $servers->where('status', 'online');

            $totalContainers = 0;
            $healthyContainers = 0;
            $warningContainers = 0;
            $criticalContainers = 0;

            foreach ($onlineServers as $server) {
                try {
                    $results = $this->healthMonitor->monitorNode($server->code);
                    $totalContainers += $results['total_containers'];
                    $healthyContainers += $results['healthy'];
                    $warningContainers += $results['warning'];
                    $criticalContainers += $results['critical'];
                } catch (\Exception $e) {
                    // Skip failed nodes
                    continue;
                }
            }

            $alerts24h = ContainerHealthLog::unhealthy()
                ->recent(24)
                ->count();

            $criticalIncidents = ContainerHealthLog::critical()
                ->recent(24)
                ->count();

            return [
                'servers' => [
                    'total' => $servers->count(),
                    'online' => $onlineServers->count(),
                    'offline' => $servers->count() - $onlineServers->count(),
                ],
                'containers' => [
                    'total' => $totalContainers,
                    'healthy' => $healthyContainers,
                    'warning' => $warningContainers,
                    'critical' => $criticalContainers,
                ],
                'alerts' => [
                    'last_24h' => $alerts24h,
                    'critical_incidents' => $criticalIncidents,
                ],
                'health_score' => $this->calculateHealthScore([
                    'current' => [
                        'total' => $totalContainers,
                        'healthy' => $healthyContainers,
                        'warning' => $warningContainers,
                        'critical' => $criticalContainers,
                    ],
                ]),
                'timestamp' => now()->toIso8601String(),
            ];
        });

        return response()->json($data);
    }
}
