<?php

declare(strict_types=1);

namespace App\Services\Performance;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Performance Profiler Service
 *
 * Profiles application performance, identifies bottlenecks,
 * and tracks execution metrics.
 */
class PerformanceProfiler
{
    private array $queries = [];

    private float $startTime;

    private array $metrics = [];

    private bool $enabled;

    public function __construct()
    {
        $this->enabled = config('performance.profiling_enabled', false);
        $this->startTime = microtime(true);
    }

    /**
     * Start profiling a request
     */
    public function start(Request $request): self
    {
        if (! $this->enabled) {
            return $this;
        }

        $this->startTime = microtime(true);
        $this->queries = [];
        $this->metrics = [
            'request_id' => uniqid('perf_', true),
            'path' => $request->path(),
            'method' => $request->method(),
            'user_id' => auth()->id(),
        ];

        if (config('performance.log_queries')) {
            DB::enableQueryLog();
        }

        return $this;
    }

    /**
     * Stop profiling and log results
     */
    public function stop(): array
    {
        if (! $this->enabled) {
            return [];
        }

        $duration = microtime(true) - $this->startTime;
        $this->metrics['duration_ms'] = round($duration * 1000, 2);
        $this->metrics['memory_mb'] = round(memory_get_peak_usage(true) / 1024 / 1024, 2);

        if (config('performance.log_queries')) {
            $this->queries = DB::getQueryLog();
            $this->metrics['query_count'] = count($this->queries);
            $this->metrics['slow_queries'] = $this->identifySlowQueries();
        }

        // Log if exceeds thresholds
        $thresholds = config('performance.thresholds', []);
        if ($duration > ($thresholds['response_time_ms'] ?? 100) / 1000) {
            Log::warning('Performance: Slow request detected', $this->metrics);
        }

        if (count($this->queries) > ($thresholds['max_queries'] ?? 50)) {
            Log::warning('Performance: Too many queries', [
                'request_id' => $this->metrics['request_id'],
                'query_count' => count($this->queries),
                'path' => $this->metrics['path'],
            ]);
        }

        return $this->metrics;
    }

    /**
     * Identify slow queries (> 50ms)
     */
    protected function identifySlowQueries(): array
    {
        $threshold = config('performance.slow_query_threshold_ms', 50);
        $slowQueries = [];

        foreach ($this->queries as $query) {
            if (($query['time'] ?? 0) > $threshold) {
                $slowQueries[] = [
                    'sql' => $query['query'],
                    'bindings' => $query['bindings'] ?? [],
                    'time_ms' => $query['time'],
                ];
            }
        }

        return $slowQueries;
    }

    /**
     * Detect N+1 query problems
     */
    public function detectNPlusOne(): array
    {
        if (! $this->enabled || empty($this->queries)) {
            return [];
        }

        $queryPatterns = [];
        $nPlusOneWarnings = [];

        foreach ($this->queries as $query) {
            $sql = $this->normalizeQuery($query['query']);
            $queryPatterns[$sql] = ($queryPatterns[$sql] ?? 0) + 1;
        }

        // Look for patterns that repeat
        foreach ($queryPatterns as $pattern => $count) {
            if ($count > 3 && preg_match('/WHERE.*IN.*\(.*,.*\)/s', $pattern)) {
                $nPlusOneWarnings[] = [
                    'pattern' => $pattern,
                    'occurrences' => $count,
                    'suggestion' => 'Consider eager loading with with()',
                ];
            }
        }

        return $nPlusOneWarnings;
    }

    /**
     * Normalize query for pattern matching
     */
    protected function normalizeQuery(string $query): string
    {
        return preg_replace([
            '/\b\d+\b/',
            '/\'[^\']*\'/',
            '/\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b/i',
        ], ['?', '?', '?'], $query);
    }

    /**
     * Get memory usage breakdown
     */
    public function getMemoryUsage(): array
    {
        return [
            'current_mb' => round(memory_get_usage(true) / 1024 / 1024, 2),
            'peak_mb' => round(memory_get_peak_usage(true) / 1024 / 1024, 2),
            'limit_mb' => round(ini_get('memory_limit') === '-1' ? PHP_INT_MAX : (int) ini_get('memory_limit'), 2),
        ];
    }

    /**
     * Get performance metrics
     */
    public function getMetrics(): array
    {
        return $this->metrics;
    }

    /**
     * Check if profiling is enabled
     */
    public function isEnabled(): bool
    {
        return $this->enabled;
    }
}
