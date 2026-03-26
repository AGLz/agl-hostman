<?php

declare(strict_types=1);

namespace App\Services\Performance;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Redis;

/**
 * Performance Monitoring Service
 *
 * Tracks and reports application performance metrics
 * including response times, query performance, and resource usage.
 */
class PerformanceMonitoringService
{
    private string $prefix = 'perf:';

    /**
     * Record response time for endpoint
     */
    public function recordResponseTime(string $endpoint, float $timeMs, string $method = 'GET'): void
    {
        $key = $this->prefix.'response_time:'.$endpoint.':'.$method;

        // Store in Redis sorted set for time-series analysis
        Redis::zadd($key, now()->timestamp, $timeMs);

        // Set expiration (24 hours)
        Redis::expire($key, 86400);

        // Check SLA compliance
        $threshold = config('performance.thresholds.response_time_ms', 100);

        if ($timeMs > $threshold) {
            Log::warning('Performance SLA exceeded', [
                'endpoint' => $endpoint,
                'method' => $method,
                'time_ms' => $timeMs,
                'threshold_ms' => $threshold,
            ]);

            // Increment SLA violation counter
            Redis::incr($this->prefix.'sla_violations:'.$endpoint);
        }

        // Update histogram for P50, P95, P99 calculation
        $this->updateHistogram($endpoint, $method, $timeMs);
    }

    /**
     * Record query count for request
     */
    public function recordQueryCount(string $endpoint, int $count): void
    {
        $key = $this->prefix.'queries:'.$endpoint;

        Redis::incrby($key, $count);
        Redis::expire($key, 3600); // 1 hour

        // Check for query count violations
        $threshold = config('performance.thresholds.max_queries', 50);

        if ($count > $threshold) {
            Log::warning('Query count threshold exceeded', [
                'endpoint' => $endpoint,
                'count' => $count,
                'threshold' => $threshold,
            ]);
        }
    }

    /**
     * Record memory usage
     */
    public function recordMemoryUsage(string $endpoint, float $memoryMb): void
    {
        $key = $this->prefix.'memory:'.$endpoint;

        Redis::zadd($key, now()->timestamp, $memoryMb);
        Redis::expire($key, 3600);
    }

    /**
     * Record cache hit/miss
     */
    public function recordCacheHit(string $key, bool $hit): void
    {
        $counterKey = $this->prefix.'cache:'.($hit ? 'hits' : 'misses');

        Redis::incr($counterKey);
        Redis::expire($counterKey, 3600);
    }

    /**
     * Get performance metrics for endpoint
     */
    public function getEndpointMetrics(string $endpoint, string $method = 'GET'): array
    {
        $responseTimeKey = $this->prefix.'response_time:'.$endpoint.':'.$method;
        $queryKey = $this->prefix.'queries:'.$endpoint;
        $memoryKey = $this->prefix.'memory:'.$endpoint;

        return [
            'endpoint' => $endpoint,
            'method' => $method,
            'response_times' => $this->getResponseTimePercentiles($responseTimeKey),
            'query_count' => Redis::get($queryKey) ?? 0,
            'memory_usage_mb' => $this->getAverageMemory($memoryKey),
            'sla_violations' => Redis::get($this->prefix.'sla_violations:'.$endpoint) ?? 0,
        ];
    }

    /**
     * Get all performance metrics
     */
    public function getAllMetrics(): array
    {
        $endpoints = $this->getTrackedEndpoints();

        $metrics = [
            'summary' => $this->getSummaryMetrics(),
            'endpoints' => [],
            'cache' => $this->getCacheMetrics(),
            'database' => $this->getDatabaseMetrics(),
        ];

        foreach ($endpoints as $endpoint) {
            $metrics['endpoints'][$endpoint] = $this->getEndpointMetrics($endpoint);
        }

        return $metrics;
    }

    /**
     * Get summary metrics
     */
    protected function getSummaryMetrics(): array
    {
        $hits = (int) Redis::get($this->prefix.'cache:hits') ?? 0;
        $misses = (int) Redis::get($this->prefix.'cache:misses') ?? 0;
        $total = $hits + $misses;

        return [
            'cache_hit_rate' => $total > 0 ? round(($hits / $total) * 100, 2) : 0,
            'total_requests' => $total,
            'cache_hits' => $hits,
            'cache_misses' => $misses,
        ];
    }

    /**
     * Get cache metrics
     */
    protected function getCacheMetrics(): array
    {
        $redis = Redis::connection();

        return [
            'keys' => $redis->dbSize(),
            'memory_used_mb' => round($redis->info('memory')['used_memory'] / 1024 / 1024, 2),
            'hit_rate' => $this->getSummaryMetrics()['cache_hit_rate'],
        ];
    }

    /**
     * Get database metrics
     */
    protected function getDatabaseMetrics(): array
    {
        try {
            $connectionCount = DB::select("SHOW STATUS LIKE 'Threads_connected'")[0]->Value ?? 0;
            $slowQueries = DB::select("SHOW STATUS LIKE 'Slow_queries'")[0]->Value ?? 0;

            return [
                'active_connections' => (int) $connectionCount,
                'slow_queries' => (int) $slowQueries,
            ];
        } catch (\Exception $e) {
            return ['error' => $e->getMessage()];
        }
    }

    /**
     * Get tracked endpoints
     */
    protected function getTrackedEndpoints(): array
    {
        $keys = Redis::keys($this->prefix.'response_time:*');
        $endpoints = [];

        foreach ($keys as $key) {
            // Extract endpoint from key
            $parts = explode(':', $key);
            if (count($parts) >= 4) {
                $endpoint = $parts[2];
                $method = $parts[3];
                $endpoints[] = $endpoint;
            }
        }

        return array_unique($endpoints);
    }

    /**
     * Get response time percentiles
     */
    protected function getResponseTimePercentiles(string $key): array
    {
        $times = Redis::zrange($key, 0, -1, 'WITHSCORES');

        if (empty($times)) {
            return ['p50' => 0, 'p95' => 0, 'p99' => 0, 'avg' => 0];
        }

        $values = array_values($times);
        sort($values);

        $count = count($values);

        return [
            'p50' => $values[(int) ($count * 0.5)] ?? 0,
            'p95' => $values[(int) ($count * 0.95)] ?? 0,
            'p99' => $values[(int) ($count * 0.99)] ?? 0,
            'avg' => array_sum($values) / $count,
            'min' => min($values),
            'max' => max($values),
        ];
    }

    /**
     * Get average memory usage
     */
    protected function getAverageMemory(string $key): float
    {
        $values = Redis::zrange($key, 0, -1, 'WITHSCORES');

        if (empty($values)) {
            return 0;
        }

        $memories = array_values($values);

        return round(array_sum($memories) / count($memories), 2);
    }

    /**
     * Update histogram for percentile calculation
     */
    protected function updateHistogram(string $endpoint, string $method, float $timeMs): void
    {
        // Store in buckets for efficient percentile calculation
        $bucket = (int) floor($timeMs / 10) * 10; // 10ms buckets
        $key = $this->prefix.'histogram:'.$endpoint.':'.$method;

        Redis::hincrby($key, (string) $bucket, 1);
        Redis::expire($key, 86400);
    }

    /**
     * Clear old performance data
     */
    public function clearOldData(int $hours = 24): void
    {
        $keys = Redis::keys($this->prefix.'*');

        foreach ($keys as $key) {
            $ttl = Redis::ttl($key);

            if ($ttl > 0 && $ttl < ($hours * 3600)) {
                Redis::del($key);
            }
        }
    }

    /**
     * Get performance report
     */
    public function getPerformanceReport(int $hours = 24): array
    {
        return [
            'period_hours' => $hours,
            'generated_at' => now()->toIso8601String(),
            'metrics' => $this->getAllMetrics(),
            'sla_compliance' => $this->getSLACompliance(),
            'recommendations' => $this->getRecommendations(),
        ];
    }

    /**
     * Get SLA compliance report
     */
    protected function getSLACompliance(): array
    {
        $endpoints = $this->getTrackedEndpoints();
        $compliance = [];

        $threshold = config('performance.thresholds.response_time_ms', 100);

        foreach ($endpoints as $endpoint) {
            $metrics = $this->getEndpointMetrics($endpoint);
            $violations = $metrics['sla_violations'] ?? 0;

            $compliance[$endpoint] = [
                'compliant' => $violations === 0,
                'violations' => $violations,
                'p95_ms' => $metrics['response_times']['p95'] ?? 0,
                'threshold_ms' => $threshold,
            ];
        }

        return $compliance;
    }

    /**
     * Get optimization recommendations
     */
    protected function getRecommendations(): array
    {
        $recommendations = [];
        $metrics = $this->getAllMetrics();

        // Check cache hit rate
        if ($metrics['summary']['cache_hit_rate'] < 70) {
            $recommendations[] = [
                'type' => 'caching',
                'priority' => 'high',
                'message' => 'Cache hit rate is below 70%. Consider increasing cache TTL or implementing caching for more endpoints.',
                'current_value' => $metrics['summary']['cache_hit_rate'].'%',
            ];
        }

        // Check for slow endpoints
        foreach ($metrics['endpoints'] ?? [] as $endpoint => $endpointMetrics) {
            $p95 = $endpointMetrics['response_times']['p95'] ?? 0;

            if ($p95 > 100) {
                $recommendations[] = [
                    'type' => 'response_time',
                    'priority' => 'medium',
                    'message' => "Endpoint {$endpoint} has P95 response time of {$p95}ms. Consider optimization.",
                    'endpoint' => $endpoint,
                    'p95_ms' => $p95,
                ];
            }

            $queryCount = $endpointMetrics['query_count'] ?? 0;
            if ($queryCount > 30) {
                $recommendations[] = [
                    'type' => 'query_optimization',
                    'priority' => 'medium',
                    'message' => "Endpoint {$endpoint} averages {$queryCount} queries. Consider eager loading or caching.",
                    'endpoint' => $endpoint,
                    'query_count' => $queryCount,
                ];
            }
        }

        return $recommendations;
    }
}
