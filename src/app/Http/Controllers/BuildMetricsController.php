<?php

namespace App\Http\Controllers;

use App\Services\Monitoring\BuildPerformanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class BuildMetricsController extends Controller
{
    private BuildPerformanceService $buildPerformanceService;

    public function __construct(BuildPerformanceService $buildPerformanceService)
    {
        $this->buildPerformanceService = $buildPerformanceService;
    }

    /**
     * Get latest build metrics
     *
     * @return JsonResponse
     */
    public function getLatestMetrics(): JsonResponse
    {
        $metrics = $this->buildPerformanceService->getLatestMetrics();
        $improvements = $this->buildPerformanceService->calculateImprovements();

        if (!$metrics) {
            return response()->json([
                'message' => 'No build metrics available yet',
                'latest' => null,
                'improvements' => $improvements,
            ], 404);
        }

        return response()->json([
            'latest' => $metrics,
            'improvements' => $improvements,
        ]);
    }

    /**
     * Get build metrics history
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function getBuildHistory(Request $request): JsonResponse
    {
        $limit = (int) $request->query('limit', 50);
        $limit = min($limit, 100); // Cap at 100

        $history = $this->buildPerformanceService->getHistory($limit);

        return response()->json($history);
    }

    /**
     * Get build performance trends
     *
     * @return JsonResponse
     */
    public function getBuildTrends(): JsonResponse
    {
        $trends = $this->buildPerformanceService->getTrends();

        return response()->json($trends);
    }

    /**
     * Get metrics for specific environment
     *
     * @param Request $request
     * @param string $environment
     * @return JsonResponse
     */
    public function getEnvironmentMetrics(Request $request, string $environment): JsonResponse
    {
        $limit = (int) $request->query('limit', 20);
        $limit = min($limit, 100);

        $metrics = $this->buildPerformanceService->getEnvironmentMetrics($environment, $limit);

        return response()->json($metrics);
    }

    /**
     * Record new build metrics (webhook endpoint)
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function recordMetrics(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'build_time_seconds' => 'required|numeric|min:0',
            'environment' => 'string|max:50',
            'git_sha' => 'string|max:40',
            'git_branch' => 'string|max:100',
            'cache_hit' => 'boolean',
            'cache_hit_rate' => 'numeric|min:0|max:100',
            'layer_reuse_rate' => 'numeric|min:0|max:100',
            'image_size_mb' => 'numeric|min:0',
            'timestamp' => 'string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $this->buildPerformanceService->recordBuildMetrics($request->all());

            return response()->json([
                'message' => 'Build metrics recorded successfully',
                'data' => $request->all(),
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to record build metrics',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get performance comparison
     *
     * @return JsonResponse
     */
    public function getComparison(): JsonResponse
    {
        $improvements = $this->buildPerformanceService->calculateImprovements();

        if (isset($improvements['insufficient_data'])) {
            return response()->json([
                'message' => $improvements['message'],
                'comparison' => null,
            ], 404);
        }

        $comparison = [
            'performance_gain' => [
                'build_time_reduction' => $improvements['build_time_improvement'] . '%',
                'time_saved_per_build' => $improvements['time_saved_per_build'] . 's',
                'total_builds_analyzed' => $improvements['total_builds'],
            ],
            'baseline' => [
                'average_build_time' => $improvements['baseline_build_time'] . 's',
                'description' => 'Average of first 10 builds',
            ],
            'current' => [
                'average_build_time' => $improvements['current_build_time'] . 's',
                'cache_hit_rate' => $improvements['cache_hit_rate'] . '%',
                'layer_reuse_rate' => $improvements['layer_reuse_rate'] . '%',
                'description' => 'Average of last 10 builds',
            ],
            'targets' => [
                'build_time_reduction_target' => '75%',
                'cache_hit_rate_target' => '80%',
                'layer_reuse_target' => '90%',
            ],
            'status' => [
                'build_time_target_met' => $improvements['build_time_improvement'] >= 75,
                'cache_hit_target_met' => $improvements['cache_hit_rate'] >= 80,
                'layer_reuse_target_met' => $improvements['layer_reuse_rate'] >= 90,
            ],
        ];

        return response()->json($comparison);
    }
}
