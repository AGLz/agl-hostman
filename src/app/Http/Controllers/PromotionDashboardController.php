<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Promotion;
use App\Models\Environment;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class PromotionDashboardController extends Controller
{
    /**
     * Get complete promotion pipeline status
     */
    public function getPromotionPipeline(): JsonResponse
    {
        $environments = Environment::whereIn('type', ['development', 'qa', 'uat', 'production'])
            ->with('latestDeployment')
            ->get()
            ->keyBy('type');

        $pendingPromotions = Promotion::whereIn('status', ['pending_approval', 'approved', 'deploying'])
            ->with(['sourceEnvironment', 'targetEnvironment'])
            ->get();

        return response()->json([
            'environments' => $environments->map(fn($env) => [
                'type' => $env->type,
                'current_version' => $env->current_version,
                'last_deployed' => $env->latestDeployment?->completed_at,
                'status' => $env->status,
            ]),
            'pending_promotions' => $pendingPromotions,
        ]);
    }

    /**
     * Get promotion metrics
     */
    public function getPromotionMetrics(): JsonResponse
    {
        $metrics = [
            'dev_to_qa' => $this->calculatePromotionMetrics('development', 'qa'),
            'qa_to_uat' => $this->calculatePromotionMetrics('qa', 'uat'),
            'uat_to_production' => $this->calculatePromotionMetrics('uat', 'production'),
        ];

        return response()->json($metrics);
    }

    /**
     * Get active promotions
     */
    public function getActivePromotions(): JsonResponse
    {
        $active = Promotion::whereIn('status', ['pending_approval', 'approved', 'deploying'])
            ->with(['sourceEnvironment', 'targetEnvironment', 'approvals'])
            ->orderBy('requested_at', 'desc')
            ->get();

        return response()->json([
            'promotions' => $active,
            'count' => $active->count(),
        ]);
    }

    /**
     * Get promotion history
     */
    public function getPromotionHistory(Request $request): JsonResponse
    {
        $days = $request->input('days', 30);

        $history = Promotion::where('created_at', '>', now()->subDays($days))
            ->with(['sourceEnvironment', 'targetEnvironment'])
            ->orderBy('created_at', 'desc')
            ->paginate(50);

        return response()->json($history);
    }

    /**
     * Calculate promotion metrics for environment pair
     */
    private function calculatePromotionMetrics(string $sourceType, string $targetType): array
    {
        $promotions = Promotion::whereHas('sourceEnvironment', fn($q) => $q->where('type', $sourceType))
            ->whereHas('targetEnvironment', fn($q) => $q->where('type', $targetType))
            ->where('created_at', '>', now()->subDays(30))
            ->get();

        $completed = $promotions->where('status', 'completed');
        $failed = $promotions->where('status', 'failed');
        $rolledBack = $promotions->where('status', 'rolled_back');

        return [
            'total' => $promotions->count(),
            'completed' => $completed->count(),
            'failed' => $failed->count(),
            'rolled_back' => $rolledBack->count(),
            'success_rate' => $promotions->count() > 0 
                ? round(($completed->count() / $promotions->count()) * 100, 2) 
                : 0,
            'average_duration' => $completed->isNotEmpty()
                ? round($completed->avg(fn($p) => $p->getDuration() ?? 0), 2)
                : 0,
        ];
    }
}
