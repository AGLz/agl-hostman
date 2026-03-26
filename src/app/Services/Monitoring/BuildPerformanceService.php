<?php

namespace App\Services\Monitoring;

use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class BuildPerformanceService
{
    private const CACHE_KEY_LATEST = 'build:metrics:latest';

    private const CACHE_KEY_HISTORY = 'build:metrics:history';

    private const CACHE_KEY_TRENDS = 'build:metrics:trends';

    private const HISTORY_LIMIT = 100;

    private const CACHE_TTL_LATEST = 86400; // 24 hours

    private const CACHE_TTL_HISTORY = 604800; // 7 days

    private const CACHE_TTL_TRENDS = 3600; // 1 hour

    /**
     * Record build metrics for a deployment
     *
     * @param  array  $metrics  Build metrics data
     */
    public function recordBuildMetrics(array $metrics): void
    {
        // Validate required fields
        $validated = $this->validateMetrics($metrics);

        // Add timestamp if not present
        if (! isset($validated['timestamp'])) {
            $validated['timestamp'] = Carbon::now()->toIso8601String();
        }

        // Calculate derived metrics
        $validated = $this->calculateDerivedMetrics($validated);

        // Store in cache for quick access
        Cache::put(self::CACHE_KEY_LATEST, $validated, self::CACHE_TTL_LATEST);

        // Store in time-series for historical analysis
        $this->addToHistory($validated);

        // Update trends cache
        $this->updateTrends();

        Log::info('Build metrics recorded', [
            'environment' => $validated['environment'] ?? 'unknown',
            'build_time_seconds' => $validated['build_time_seconds'],
            'cache_hit_rate' => $validated['cache_hit_rate'] ?? 0,
        ]);
    }

    /**
     * Get the latest build metrics
     */
    public function getLatestMetrics(): ?array
    {
        return Cache::get(self::CACHE_KEY_LATEST);
    }

    /**
     * Get build metrics history
     *
     * @param  int  $limit  Maximum number of builds to return
     */
    public function getHistory(int $limit = 50): array
    {
        $history = Cache::get(self::CACHE_KEY_HISTORY, []);

        return [
            'builds' => array_slice($history, -$limit),
            'count' => count($history),
            'total_count' => count($history),
        ];
    }

    /**
     * Calculate performance improvements over baseline
     */
    public function calculateImprovements(): array
    {
        $history = Cache::get(self::CACHE_KEY_HISTORY, []);

        if (count($history) < 2) {
            return [
                'insufficient_data' => true,
                'message' => 'Need at least 2 builds to calculate improvements',
            ];
        }

        // Use first 10 builds as baseline average
        $baselineBuilds = array_slice($history, 0, min(10, count($history)));
        $baseline = $this->calculateAverageMetrics($baselineBuilds);

        // Use last 10 builds as current average
        $currentBuilds = array_slice($history, -10);
        $current = $this->calculateAverageMetrics($currentBuilds);

        return [
            'build_time_improvement' => $this->calculatePercentageImprovement(
                $baseline['build_time_seconds'],
                $current['build_time_seconds']
            ),
            'cache_hit_rate' => $current['cache_hit_rate'] ?? 0,
            'layer_reuse_rate' => $current['layer_reuse_rate'] ?? 0,
            'total_builds' => count($history),
            'baseline_build_time' => round($baseline['build_time_seconds'], 2),
            'current_build_time' => round($current['build_time_seconds'], 2),
            'time_saved_per_build' => round(
                $baseline['build_time_seconds'] - $current['build_time_seconds'],
                2
            ),
        ];
    }

    /**
     * Get build trends over time
     */
    public function getTrends(): array
    {
        return Cache::get(self::CACHE_KEY_TRENDS, [
            'average_build_time' => 0,
            'average_cache_hit_rate' => 0,
            'total_time_saved' => 0,
            'builds_analyzed' => 0,
        ]);
    }

    /**
     * Get build metrics for a specific environment
     */
    public function getEnvironmentMetrics(string $environment, int $limit = 20): array
    {
        $history = Cache::get(self::CACHE_KEY_HISTORY, []);

        $filtered = array_filter($history, function ($build) use ($environment) {
            return ($build['environment'] ?? '') === $environment;
        });

        return [
            'environment' => $environment,
            'builds' => array_slice($filtered, -$limit),
            'count' => count($filtered),
            'average_build_time' => $this->calculateAverageBuildTime($filtered),
        ];
    }

    /**
     * Validate build metrics
     */
    private function validateMetrics(array $metrics): array
    {
        $required = ['build_time_seconds'];

        foreach ($required as $field) {
            if (! isset($metrics[$field])) {
                throw new \InvalidArgumentException("Missing required field: {$field}");
            }
        }

        return $metrics;
    }

    /**
     * Calculate derived metrics
     */
    private function calculateDerivedMetrics(array $metrics): array
    {
        // Calculate cache hit rate if not provided
        if (! isset($metrics['cache_hit_rate'])) {
            $metrics['cache_hit_rate'] = $metrics['cache_hit'] ?? false ? 100 : 0;
        }

        // Estimate layer reuse if not provided
        if (! isset($metrics['layer_reuse_rate'])) {
            // Fast builds (< 180s) likely have good cache reuse
            if ($metrics['build_time_seconds'] < 180) {
                $metrics['layer_reuse_rate'] = 90;
            } else {
                $metrics['layer_reuse_rate'] = 50;
            }
        }

        return $metrics;
    }

    /**
     * Add metrics to history
     */
    private function addToHistory(array $metrics): void
    {
        $history = Cache::get(self::CACHE_KEY_HISTORY, []);
        $history[] = $metrics;

        // Keep last N builds
        if (count($history) > self::HISTORY_LIMIT) {
            $history = array_slice($history, -self::HISTORY_LIMIT);
        }

        Cache::put(self::CACHE_KEY_HISTORY, $history, self::CACHE_TTL_HISTORY);
    }

    /**
     * Update trends cache
     */
    private function updateTrends(): void
    {
        $history = Cache::get(self::CACHE_KEY_HISTORY, []);

        if (empty($history)) {
            return;
        }

        $trends = [
            'average_build_time' => $this->calculateAverageBuildTime($history),
            'average_cache_hit_rate' => $this->calculateAverageCacheHitRate($history),
            'total_time_saved' => $this->calculateTotalTimeSaved($history),
            'builds_analyzed' => count($history),
            'last_updated' => Carbon::now()->toIso8601String(),
        ];

        Cache::put(self::CACHE_KEY_TRENDS, $trends, self::CACHE_TTL_TRENDS);
    }

    /**
     * Calculate average metrics from builds
     */
    private function calculateAverageMetrics(array $builds): array
    {
        $count = count($builds);

        if ($count === 0) {
            return [
                'build_time_seconds' => 0,
                'cache_hit_rate' => 0,
                'layer_reuse_rate' => 0,
            ];
        }

        $totalBuildTime = array_sum(array_column($builds, 'build_time_seconds'));
        $totalCacheHitRate = array_sum(array_column($builds, 'cache_hit_rate'));
        $totalLayerReuse = array_sum(array_column($builds, 'layer_reuse_rate'));

        return [
            'build_time_seconds' => $totalBuildTime / $count,
            'cache_hit_rate' => $totalCacheHitRate / $count,
            'layer_reuse_rate' => $totalLayerReuse / $count,
        ];
    }

    /**
     * Calculate percentage improvement
     */
    private function calculatePercentageImprovement(float $before, float $after): float
    {
        if ($before == 0) {
            return 0;
        }

        return round((($before - $after) / $before) * 100, 2);
    }

    /**
     * Calculate average build time
     */
    private function calculateAverageBuildTime(array $builds): float
    {
        if (empty($builds)) {
            return 0;
        }

        $total = array_sum(array_column($builds, 'build_time_seconds'));

        return round($total / count($builds), 2);
    }

    /**
     * Calculate average cache hit rate
     */
    private function calculateAverageCacheHitRate(array $builds): float
    {
        if (empty($builds)) {
            return 0;
        }

        $rates = array_column($builds, 'cache_hit_rate');
        $rates = array_filter($rates); // Remove null/empty values

        if (empty($rates)) {
            return 0;
        }

        return round(array_sum($rates) / count($rates), 2);
    }

    /**
     * Calculate total time saved
     */
    private function calculateTotalTimeSaved(array $builds): int
    {
        if (count($builds) < 2) {
            return 0;
        }

        $baseline = array_slice($builds, 0, min(10, count($builds)));
        $baselineAvg = $this->calculateAverageBuildTime($baseline);

        $saved = 0;
        foreach ($builds as $build) {
            $timeSaved = $baselineAvg - $build['build_time_seconds'];
            if ($timeSaved > 0) {
                $saved += $timeSaved;
            }
        }

        return (int) round($saved);
    }
}
