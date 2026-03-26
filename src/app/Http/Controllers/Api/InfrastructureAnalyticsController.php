<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\MonitorInfrastructure;
use App\Services\InfrastructureAnalyticsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class InfrastructureAnalyticsController extends Controller
{
    protected InfrastructureAnalyticsService $analyticsService;

    public function __construct(InfrastructureAnalyticsService $analyticsService)
    {
        $this->analyticsService = $analyticsService;
    }

    /**
     * Get current infrastructure status
     */
    public function status(Request $request)
    {
        $status = Cache::get('infrastructure_status', []);

        if (empty($status)) {
            // Trigger monitoring if no cached data
            dispatch(new MonitorInfrastructure(
                ['AGLSRV1', 'AGLSRV2', 'AGLSRV3', 'AGLSRV4', 'AGLSRV5', 'AGLSRV6']
            ));

            return response()->json([
                'message' => 'Monitoring initiated. Please wait...',
                'status' => 'pending',
            ], 202);
        }

        return response()->json($status);
    }

    /**
     * Get infrastructure analytics
     */
    public function analytics(Request $request)
    {
        $analysis = Cache::get('infrastructure_analysis');

        if (! $analysis) {
            $status = Cache::get('infrastructure_status', []);
            if (! empty($status)) {
                $analysis = $this->analyticsService->analyzeInfrastructure($status);
            } else {
                return response()->json([
                    'message' => 'No data available for analysis',
                ], 404);
            }
        }

        return response()->json($analysis);
    }

    /**
     * Get server-specific metrics
     */
    public function serverMetrics(Request $request, string $serverCode)
    {
        $status = Cache::get("server_status_{$serverCode}");

        if (! $status) {
            return response()->json([
                'message' => 'Server data not found',
            ], 404);
        }

        return response()->json($status);
    }

    /**
     * Trigger manual monitoring
     */
    public function triggerMonitoring(Request $request)
    {
        $request->validate([
            'servers' => 'array',
            'servers.*' => 'string|in:AGLSRV1,AGLSRV2,AGLSRV3,AGLSRV4,AGLSRV5,AGLSRV6',
            'type' => 'string|in:health,performance,security',
        ]);

        $servers = $request->input('servers', ['AGLSRV1', 'AGLSRV6']);
        $type = $request->input('type', 'health');

        dispatch(new MonitorInfrastructure($servers, $type));

        return response()->json([
            'message' => 'Monitoring triggered',
            'servers' => $servers,
            'type' => $type,
        ]);
    }

    /**
     * Get historical metrics
     */
    public function history(Request $request)
    {
        $request->validate([
            'server' => 'string',
            'metric' => 'string|in:cpu,memory,disk,network',
            'period' => 'string|in:1h,6h,24h,7d,30d',
        ]);

        // This would typically fetch from a time-series database
        // For now, return simulated data
        $period = $request->input('period', '24h');
        $metric = $request->input('metric', 'cpu');

        $data = $this->generateHistoricalData($period, $metric);

        return response()->json($data);
    }

    /**
     * Get predictions
     */
    public function predictions(Request $request)
    {
        $analysis = Cache::get('infrastructure_analysis');

        if (! $analysis || ! isset($analysis['predictions'])) {
            return response()->json([
                'predictions' => [],
                'message' => 'No predictions available',
            ]);
        }

        return response()->json([
            'predictions' => $analysis['predictions'],
            'generated_at' => Cache::get('infrastructure_analysis_timestamp', now()),
        ]);
    }

    /**
     * Get optimization recommendations
     */
    public function optimizations(Request $request)
    {
        $analysis = Cache::get('infrastructure_analysis');

        if (! $analysis) {
            return response()->json([
                'optimizations' => [],
                'recommendations' => [],
                'message' => 'No optimization data available',
            ]);
        }

        return response()->json([
            'optimizations' => $analysis['optimization_opportunities'] ?? [],
            'recommendations' => $analysis['recommendations'] ?? [],
            'ai_insights' => $analysis['ai_insights'] ?? [],
        ]);
    }

    /**
     * Generate historical data (simulated for demo)
     */
    protected function generateHistoricalData(string $period, string $metric): array
    {
        $points = match ($period) {
            '1h' => 60,
            '6h' => 72,
            '24h' => 96,
            '7d' => 168,
            '30d' => 360,
            default => 24,
        };

        $data = [];
        $now = now();

        for ($i = $points; $i > 0; $i--) {
            $timestamp = match ($period) {
                '1h' => $now->copy()->subMinutes($i),
                '6h' => $now->copy()->subMinutes($i * 5),
                '24h' => $now->copy()->subMinutes($i * 15),
                '7d' => $now->copy()->subHours($i),
                '30d' => $now->copy()->subHours($i * 2),
                default => $now->copy()->subHours($i),
            };

            $data[] = [
                'timestamp' => $timestamp->toIso8601String(),
                'value' => $this->generateMetricValue($metric, $i),
            ];
        }

        return [
            'metric' => $metric,
            'period' => $period,
            'data' => $data,
        ];
    }

    /**
     * Generate metric value (simulated)
     */
    protected function generateMetricValue(string $metric, int $index): float
    {
        $base = match ($metric) {
            'cpu' => 45,
            'memory' => 60,
            'disk' => 35,
            'network' => 20,
            default => 50,
        };

        // Add some variation
        $variation = sin($index / 10) * 15 + rand(-5, 5);

        return max(0, min(100, $base + $variation));
    }
}
