<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\InfrastructureService;
use App\Services\InfrastructureAnalyticsService;
use Illuminate\Http\Request;
use OpenApi\Annotations as OA;

class InfrastructureController extends Controller
{
    protected $infrastructureService;
    protected $analyticsService;

    public function __construct(
        InfrastructureService $infrastructureService,
        InfrastructureAnalyticsService $analyticsService
    ) {
        $this->infrastructureService = $infrastructureService;
        $this->analyticsService = $analyticsService;
    }

    /**
     * @OA\Get(
     *     path="/api/infrastructure/status",
     *     tags={"Infrastructure"},
     *     summary="Get infrastructure status",
     *     description="Get current status of all infrastructure components",
     *     operationId="getInfrastructureStatus",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Infrastructure status",
     *         @OA\JsonContent(
     *             @OA\Property(property="servers", type="array",
     *                 @OA\Items(
     *                     @OA\Property(property="name", type="string", example="AGLSRV1"),
     *                     @OA\Property(property="status", type="string", example="online"),
     *                     @OA\Property(property="cpu_usage", type="number", example=45.2),
     *                     @OA\Property(property="memory_usage", type="number", example=62.8),
     *                     @OA\Property(property="disk_usage", type="number", example=78.5),
     *                     @OA\Property(property="containers", type="integer", example=12),
     *                     @OA\Property(property="vms", type="integer", example=3)
     *                 )
     *             ),
     *             @OA\Property(property="summary", type="object",
     *                 @OA\Property(property="total_servers", type="integer", example=6),
     *                 @OA\Property(property="online_servers", type="integer", example=5),
     *                 @OA\Property(property="total_containers", type="integer", example=68),
     *                 @OA\Property(property="total_vms", type="integer", example=15),
     *                 @OA\Property(property="health_score", type="number", example=92.5)
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=401,
     *         description="Unauthenticated"
     *     )
     * )
     */
    public function status()
    {
        $status = $this->infrastructureService->getStatus();
        return response()->json($status);
    }

    /**
     * @OA\Get(
     *     path="/api/infrastructure/metrics",
     *     tags={"Infrastructure"},
     *     summary="Get infrastructure metrics",
     *     description="Get detailed metrics for infrastructure monitoring",
     *     operationId="getInfrastructureMetrics",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="server",
     *         in="query",
     *         description="Filter by server name",
     *         required=false,
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="period",
     *         in="query",
     *         description="Time period (1h, 6h, 24h, 7d, 30d)",
     *         required=false,
     *         @OA\Schema(type="string", enum={"1h", "6h", "24h", "7d", "30d"})
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Infrastructure metrics",
     *         @OA\JsonContent(
     *             @OA\Property(property="cpu", type="array", @OA\Items(
     *                 @OA\Property(property="timestamp", type="string"),
     *                 @OA\Property(property="value", type="number")
     *             )),
     *             @OA\Property(property="memory", type="array", @OA\Items(
     *                 @OA\Property(property="timestamp", type="string"),
     *                 @OA\Property(property="value", type="number")
     *             )),
     *             @OA\Property(property="disk", type="array", @OA\Items(
     *                 @OA\Property(property="timestamp", type="string"),
     *                 @OA\Property(property="value", type="number")
     *             )),
     *             @OA\Property(property="network", type="array", @OA\Items(
     *                 @OA\Property(property="timestamp", type="string"),
     *                 @OA\Property(property="rx", type="number"),
     *                 @OA\Property(property="tx", type="number")
     *             ))
     *         )
     *     )
     * )
     */
    public function metrics(Request $request)
    {
        $server = $request->query('server');
        $period = $request->query('period', '24h');
        
        $metrics = $this->infrastructureService->getMetrics($server, $period);
        return response()->json($metrics);
    }

    /**
     * @OA\Post(
     *     path="/api/infrastructure/analyze",
     *     tags={"Infrastructure"},
     *     summary="Analyze infrastructure with AI",
     *     description="Perform AI-powered analysis of infrastructure health and recommendations",
     *     operationId="analyzeInfrastructure",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=false,
     *         @OA\JsonContent(
     *             @OA\Property(property="focus", type="string", example="performance", description="Analysis focus area"),
     *             @OA\Property(property="servers", type="array", @OA\Items(type="string"), description="Specific servers to analyze")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Analysis results",
     *         @OA\JsonContent(
     *             @OA\Property(property="health_score", type="number", example=85.7),
     *             @OA\Property(property="issues", type="array", @OA\Items(
     *                 @OA\Property(property="severity", type="string", example="warning"),
     *                 @OA\Property(property="component", type="string", example="AGLSRV2"),
     *                 @OA\Property(property="description", type="string"),
     *                 @OA\Property(property="recommendation", type="string")
     *             )),
     *             @OA\Property(property="predictions", type="array", @OA\Items(
     *                 @OA\Property(property="metric", type="string"),
     *                 @OA\Property(property="trend", type="string"),
     *                 @OA\Property(property="alert_threshold", type="string")
     *             )),
     *             @OA\Property(property="recommendations", type="array", @OA\Items(
     *                 @OA\Property(property="priority", type="string"),
     *                 @OA\Property(property="action", type="string"),
     *                 @OA\Property(property="impact", type="string")
     *             ))
     *         )
     *     )
     * )
     */
    public function analyze(Request $request)
    {
        $focus = $request->input('focus', 'general');
        $servers = $request->input('servers', []);
        
        $metrics = $this->infrastructureService->getMetrics(null, '24h');
        $analysis = $this->analyticsService->analyzeInfrastructure($metrics);
        
        return response()->json($analysis);
    }
}