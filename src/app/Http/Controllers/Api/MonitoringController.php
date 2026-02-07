<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MonitoringService;
use App\Services\MetricsCollector;
use App\Services\AlertService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use OpenApi\Annotations as OA;

/**
 * MonitoringController - Monitoring API endpoints
 *
 * Provides REST API for infrastructure monitoring, metrics,
 * health status, and alert management.
 *
 * @package App\Http\Controllers\Api
 */
class MonitoringController extends Controller
{
    protected MonitoringService $monitoringService;
    protected MetricsCollector $metricsCollector;
    protected AlertService $alertService;

    public function __construct(
        MonitoringService $monitoringService,
        MetricsCollector $metricsCollector,
        AlertService $alertService
    ) {
        $this->monitoringService = $monitoringService;
        $this->metricsCollector = $metricsCollector;
        $this->alertService = $alertService;
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/metrics",
     *     tags={"Monitoring"},
     *     summary="Get current infrastructure metrics",
     *     description="Retrieve comprehensive metrics from all infrastructure sources",
     *     operationId="getMonitoringMetrics",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="refresh",
     *         in="query",
     *         description="Force refresh metrics from source",
     *         required=false,
     *         @OA\Schema(type="boolean", default=false)
     *     ),
     *     @OA\Parameter(
     *         name="server",
     *         in="query",
     *         description="Filter by server code",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Metrics retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="servers", type="array", @OA\Items(type="object")),
     *             @OA\Property(property="containers", type="array", @OA\Items(type="object")),
     *             @OA\Property(property="network", type="object"),
     *             @OA\Property(property="storage", type="object"),
     *             @OA\Property(property="summary", type="object"),
     *             @OA\Property(property="timestamp", type="string", format="date-time")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function metrics(Request $request): JsonResponse
    {
        $refresh = $request->boolean('refresh', false);
        $serverCode = $request->query('server');

        if ($refresh) {
            $this->metricsCollector->refreshAllMetrics();
        }

        if ($serverCode) {
            $serverMetrics = $this->metricsCollector->collectServerMetrics($serverCode);
            $containerMetrics = $this->metricsCollector->collectContainerMetrics($serverCode);

            return response()->json([
                'success' => true,
                'server' => $serverMetrics,
                'containers' => $containerMetrics,
                'timestamp' => now()->toIso8601String(),
            ]);
        }

        $metrics = $this->metricsCollector->aggregateAllMetrics();

        return response()->json($metrics);
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/health",
     *     tags={"Monitoring"},
     *     summary="Get system health status",
     *     description="Get comprehensive health status of all infrastructure components",
     *     operationId="getHealthStatus",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Health status retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="overall_health", type="string", example="healthy"),
     *             @OA\Property(property="servers", type="object"),
     *             @OA\Property(property="containers", type="object"),
     *             @OA\Property(property="network", type="object"),
     *             @OA\Property(property="storage", type="object"),
     *             @OA\Property(property="active_alerts", type="integer", example=3),
     *             @OA\Property(property="last_collected", type="string", format="date-time")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function health(): JsonResponse
    {
        $health = $this->monitoringService->getHealthStatus();

        return response()->json($health);
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/alerts",
     *     tags={"Monitoring"},
     *     summary="Get monitoring alerts",
     *     description="Retrieve alerts with optional filtering",
     *     operationId="getMonitoringAlerts",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         description="Filter by alert status",
     *         required=false,
     *         @OA\Schema(type="string", enum={"active", "acknowledged", "resolved"})
     *     ),
     *     @OA\Parameter(
     *         name="type",
     *         in="query",
     *         description="Filter by alert type",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="source",
     *         in="query",
     *         description="Filter by source",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="limit",
     *         in="query",
     *         description="Limit number of results",
     *         required=false,
     *         @OA\Schema(type="integer", default=100)
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Alerts retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object")),
     *             @OA\Property(property="total", type="integer"),
     *             @OA\Property(property="stats", type="object")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function alerts(Request $request): JsonResponse
    {
        $status = $request->query('status');
        $type = $request->query('type');
        $source = $request->query('source');
        $limit = (int) $request->query('limit', 100);

        $query = \App\Models\Alert::query();

        if ($status) {
            $query->where('status', $status);
        }

        if ($type) {
            $query->where('type', $type);
        }

        if ($source) {
            $query->where('source', $source);
        }

        $alerts = $query->orderByDesc('created_at')
            ->limit($limit)
            ->get();

        $stats = $this->alertService->getAlertStats();

        return response()->json([
            'data' => $alerts,
            'total' => $alerts->count(),
            'stats' => $stats,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/api/monitoring/alerts/read",
     *     tags={"Monitoring"},
     *     summary="Mark alerts as read/acknowledged",
     *     description="Mark one or more alerts as acknowledged",
     *     operationId="markAlertsRead",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="alert_ids", type="array", @OA\Items(type="string"), description="Array of alert IDs to acknowledge"),
     *             @OA\Property(property="all", type="boolean", description="Acknowledge all active alerts")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Alerts acknowledged successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean"),
     *             @OA\Property(property="acknowledged", type="integer", description="Number of alerts acknowledged")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated"),
     *     @OA\Response(response=422, description="Validation error")
     * )
     */
    public function markAlertsRead(Request $request): JsonResponse
    {
        $request->validate([
            'alert_ids' => 'sometimes|array',
            'alert_ids.*' => 'required|string',
            'all' => 'sometimes|boolean',
        ]);

        $userId = auth()->id();
        $acknowledged = 0;

        if ($request->boolean('all')) {
            $activeAlerts = $this->alertService->getActiveAlerts();
            $alertIds = $activeAlerts->pluck('id')->toArray();
            $acknowledged = $this->alertService->bulkAcknowledge($alertIds, $userId);
        } elseif ($request->has('alert_ids')) {
            $alertIds = $request->input('alert_ids');
            $acknowledged = $this->alertService->bulkAcknowledge($alertIds, $userId);
        }

        return response()->json([
            'success' => true,
            'acknowledged' => $acknowledged,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/api/monitoring/alerts/{alertId}/resolve",
     *     tags={"Monitoring"},
     *     summary="Resolve an alert",
     *     description="Mark an alert as resolved",
     *     operationId="resolveAlert",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="alertId",
     *         in="path",
     *         description="Alert ID",
     *         required=true,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\RequestBody(
     *         required=false,
     *         @OA\JsonContent(
     *             @OA\Property(property="resolution_notes", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Alert resolved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean"),
     *             @OA\Property(property="message", type="string")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated"),
     *     @OA\Response(response=404, description="Alert not found")
     * )
     */
    public function resolveAlert(Request $request, string $alertId): JsonResponse
    {
        $resolutionNotes = $request->input('resolution_notes', '');
        $userId = auth()->id();

        $success = $this->alertService->resolveAlert($alertId, $userId);

        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to resolve alert. Alert may not exist.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Alert resolved successfully',
        ]);
    }

    /**
     * @OA\Post(
     *     path="/api/monitoring/collect",
     *     tags={"Monitoring"},
     *     summary="Trigger metrics collection",
     *     description="Manually trigger metrics collection and alert evaluation",
     *     operationId="collectMetrics",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Collection completed",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean"),
     *             @OA\Property(property="metrics_collected", type="boolean"),
     *             @OA\Property(property="alerts_generated", type="integer"),
     *             @OA\Property(property="trends_recorded", type="integer"),
     *             @OA\Property(property="timestamp", type="string", format="date-time")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function collect(): JsonResponse
    {
        $result = $this->monitoringService->collectAndMonitor();

        return response()->json($result);
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/trends",
     *     tags={"Monitoring"},
     *     summary="Get performance trends",
     *     description="Retrieve performance trend analysis",
     *     operationId="getPerformanceTrends",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="resource_type",
     *         in="query",
     *         description="Filter by resource type (ProxmoxServer, LxcContainer, Network, Storage)",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="resource_id",
     *         in="query",
     *         description="Filter by resource ID",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="hours",
     *         in="query",
     *         description="Time period in hours",
     *         required=false,
     *         @OA\Schema(type="integer", default=24)
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Trends retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="cpu_usage", type="object"),
     *             @OA\Property(property="memory_usage", type="object"),
     *             @OA\Property(property="load_average", type="object")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function trends(Request $request): JsonResponse
    {
        $resourceType = $request->query('resource_type');
        $resourceId = $request->query('resource_id');
        $hours = (int) $request->query('hours', 24);

        $trends = $this->monitoringService->getPerformanceTrends(
            $resourceType,
            $resourceId,
            $hours
        );

        return response()->json($trends);
    }

    /**
     * @OA\Post(
     *     path="/api/monitoring/refresh",
     *     tags={"Monitoring"},
     *     summary="Force refresh all monitoring data",
     *     description="Clear cache and refresh all metrics from source",
     *     operationId="refreshMonitoring",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Refresh completed",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean"),
     *             @OA\Property(property="message", type="string")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function refresh(): JsonResponse
    {
        $result = $this->monitoringService->refreshAll();

        return response()->json([
            'success' => $result['success'],
            'message' => 'Monitoring data refreshed successfully',
            'alerts_generated' => $result['alerts_generated'],
            'timestamp' => $result['timestamp'],
        ]);
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/server/{serverCode}",
     *     tags={"Monitoring"},
     *     summary="Get server-specific metrics",
     *     description="Retrieve detailed metrics for a specific server",
     *     operationId="getServerMetrics",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="serverCode",
     *         in="path",
     *         description="Server code (e.g., aglsrv1)",
     *         required=true,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Server metrics retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean"),
     *             @OA\Property(property="server", type="object"),
     *             @OA\Property(property="metrics", type="object"),
     *             @OA\Property(property="health_status", type="string")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated"),
     *     @OA\Response(response=404, description="Server not found")
     * )
     */
    public function serverMetrics(string $serverCode): JsonResponse
    {
        $metrics = $this->metricsCollector->collectServerMetrics($serverCode);

        if (!$metrics['success'] && $metrics['health_status'] === 'unknown') {
            return response()->json([
                'success' => false,
                'message' => $metrics['error'] ?? 'Server not found',
            ], 404);
        }

        return response()->json($metrics);
    }

    /**
     * @OA\Get(
     *     path="/api/monitoring/stats",
     *     tags={"Monitoring"},
     *     summary="Get monitoring statistics",
     *     description="Get aggregated monitoring statistics",
     *     operationId="getMonitoringStats",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Statistics retrieved successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="alerts", type="object"),
     *             @OA\Property(property="infrastructure", type="object"),
     *             @OA\Property(property="trends", type="object")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Unauthenticated")
     * )
     */
    public function stats(): JsonResponse
    {
        $alertStats = $this->alertService->getAlertStats();
        $health = $this->monitoringService->getHealthStatus();

        return response()->json([
            'alerts' => $alertStats,
            'infrastructure' => [
                'overall_health' => $health['overall_health'],
                'servers' => $health['servers'],
                'containers' => $health['containers'],
                'network' => $health['network'],
                'storage' => $health['storage'],
            ],
            'last_collected' => $health['last_collected'],
        ]);
    }
}
