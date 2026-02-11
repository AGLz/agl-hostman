<?php

declare(strict_types=1);

namespace App\Services\Performance;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Collection;

/**
 * Query Performance Monitoring Service
 *
 * Real-time query performance tracking and N+1 detection for AGL-23.
 * Tracks all database queries with execution time and identifies N+1 problems.
 */
class QueryPerformanceMonitor
{
    // Performance thresholds (in milliseconds)
    private const THRESHOLD_FAST = 10;      // Excellent: < 10ms
    private const THRESHOLD_NORMAL = 50;    // Good: < 50ms
    private const THRESHOLD_SLOW = 200;     // Warning: < 200ms
    private const THRESHOLD_CRITICAL = 500;  // Critical: >= 500ms

    // N+1 detection threshold
    private const N1_WARNING_THRESHOLD = 10;   // Warn if more than 10 similar queries
    private const N1_CRITICAL_THRESHOLD = 50;  // Critical if more than 50 similar queries

    private array $queries = [];
    private array $queryPatterns = [];
    private bool $enabled = true;
    private ?int $requestId = null;

    public function __construct()
    {
        $this->requestId = (int) crc32(uniqid('', true));

        if (config('app.env') === 'production') {
            $this->enabled = config('database.monitoring.enabled', true);
        }
    }

    /**
     * Start monitoring database queries
     */
    public function start(): void
    {
        if (!$this->enabled) {
            return;
        }

        DB::enableQueryLog();
        DB::listen(function ($query) {
            $this->recordQuery($query);
        });

        register_shutdown_function([$this, 'analyzeQueries']);
    }

    /**
     * Record individual query execution
     */
    private function recordQuery(object $query): void
    {
        $sql = $this->normalizeQuery($query->sql);
        $time = $query->time;

        $this->queries[] = [
            'sql' => $sql,
            'bindings' => $query->bindings ?? [],
            'time' => $time,
            'connection' => $query->connectionName,
            'timestamp' => microtime(true),
        ];

        // Track query patterns for N+1 detection
        $pattern = $this->extractQueryPattern($sql);
        if (!isset($this->queryPatterns[$pattern])) {
            $this->queryPatterns[$pattern] = [
                'count' => 0,
                'total_time' => 0,
                'max_time' => 0,
                'tables' => $this->extractTables($sql),
            ];
        }

        $this->queryPatterns[$pattern]['count']++;
        $this->queryPatterns[$pattern]['total_time'] += $time;
        $this->queryPatterns[$pattern]['max_time'] = max($time, $this->queryPatterns[$pattern]['max_time']);
    }

    /**
     * Analyze queries at request end
     */
    public function analyzeQueries(): void
    {
        if (!$this->enabled || empty($this->queries)) {
            return;
        }

        $metrics = $this->calculateMetrics();
        $this->logSlowQueries($metrics);
        $this->detectN1Problems($metrics);
        $this->storeSlowQueryLog($metrics);
    }

    /**
     * Calculate query performance metrics
     */
    private function calculateMetrics(): array
    {
        $totalQueries = count($this->queries);
        $totalTime = array_sum(array_column($this->queries, 'time'));

        $categorized = [
            'fast' => 0,
            'normal' => 0,
            'slow' => 0,
            'critical' => 0,
        ];

        foreach ($this->queries as $query) {
            if ($query['time'] < self::THRESHOLD_FAST) {
                $categorized['fast']++;
            } elseif ($query['time'] < self::THRESHOLD_NORMAL) {
                $categorized['normal']++;
            } elseif ($query['time'] < self::THRESHOLD_SLOW) {
                $categorized['slow']++;
            } else {
                $categorized['critical']++;
            }
        }

        return [
            'request_id' => $this->requestId,
            'total_queries' => $totalQueries,
            'total_time_ms' => round($totalTime, 2),
            'avg_time_ms' => round($totalTime / max(1, $totalQueries), 2),
            'max_time_ms' => round(max(array_column($this->queries, 'time')), 2),
            'min_time_ms' => round(min(array_column($this->queries, 'time')), 2),
            'p95_time_ms' => $this->calculatePercentile(array_column($this->queries, 'time'), 95),
            'p99_time_ms' => $this->calculatePercentile(array_column($this->queries, 'time'), 99),
            'categorized' => $categorized,
            'slow_queries' => array_filter($this->queries, fn($q) => $q['time'] > self::THRESHOLD_NORMAL),
            'n1_candidates' => $this->identifyN1Candidates(),
            'query_patterns' => $this->queryPatterns,
            'timestamp' => now()->toDateTimeString(),
        ];
    }

    /**
     * Calculate percentile value
     */
    private function calculatePercentile(array $values, int $percentile): float
    {
        if (empty($values)) {
            return 0;
        }

        sort($values);
        $index = ceil(count($values) * $percentile / 100) - 1;

        return $values[$index] ?? 0;
    }

    /**
     * Identify potential N+1 query problems
     */
    private function identifyN1Candidates(): array
    {
        $candidates = [];

        foreach ($this->queryPatterns as $pattern => $data) {
            if ($data['count'] > self::N1_WARNING_THRESHOLD) {
                $candidates[] = [
                    'pattern' => $pattern,
                    'count' => $data['count'],
                    'total_time_ms' => round($data['total_time'], 2),
                    'avg_time_ms' => round($data['total_time'] / $data['count'], 2),
                    'tables' => $data['tables'],
                    'severity' => $data['count'] > self::N1_CRITICAL_THRESHOLD ? 'critical' : 'warning',
                    'recommendation' => $this->suggestN1Fix($pattern, $data),
                ];
            }
        }

        // Sort by count (most frequent first)
        usort($candidates, fn($a, $b) => $b['count'] - $a['count']);

        return $candidates;
    }

    /**
     * Suggest fix for N+1 query pattern
     */
    private function suggestN1Fix(string $pattern, array $data): string
    {
        $tables = $data['tables'];
        $suggestions = [];

        // Check if pattern looks like relationship lazy loading
        if (preg_match('/SELECT.*FROM\s+(\w+).*WHERE.*id\s*[=IN]/i', $pattern)) {
            $suggestions[] = 'Use eager loading with with() to load relationships';
            $suggestions[] = 'Example: Model::with([\'relation1\', \'relation2\'])->get()';
        }

        // Check for repeated WHERE IN queries
        if (preg_match('/WHERE.*IN\s*\([^)]+\)/i', $pattern)) {
            $suggestions[] = 'Use JOIN instead of WHERE IN for large datasets';
        }

        // Check for missing SELECT specific columns
        if (preg_match('/SELECT\s+\*/i', $pattern) && $data['count'] > 20) {
            $suggestions[] = 'Select only needed columns instead of SELECT *';
        }

        return empty($suggestions) ? 'Review query pattern for optimization opportunities' : implode('; ', $suggestions);
    }

    /**
     * Normalize query for pattern matching
     */
    private function normalizeQuery(string $sql): string
    {
        // Remove bindings placeholders
        $sql = preg_replace('/\?|:\w+/', '?', $sql);

        // Remove extra whitespace
        $sql = preg_replace('/\s+/', ' ', trim($sql));

        // Convert to uppercase for consistency
        $sql = strtoupper($sql);

        return $sql;
    }

    /**
     * Extract query pattern for grouping
     */
    private function extractQueryPattern(string $sql): string
    {
        // Normalize the query
        $sql = $this->normalizeQuery($sql);

        // Extract main query structure
        if (preg_match('/(SELECT|INSERT|UPDATE|DELETE)\s+(.*?)(?:\s+FROM\s+(\w+)|)/i', $sql, $matches)) {
            $type = strtoupper($matches[1] ?? 'SELECT');
            $columns = $matches[2] ?? '*';
            $table = $matches[3] ?? 'unknown';

            // For SELECT, create pattern from columns selected and WHERE clause
            if ($type === 'SELECT') {
                preg_match('/WHERE\s+(.+?)(?:\s+GROUP BY|\s+ORDER BY|\s+LIMIT|$)/i', $sql, $whereMatches);
                $whereClause = $whereMatches[1] ?? '';

                return "{$type} {$table} [{$whereClause}]";
            }

            return "{$type} {$table}";
        }

        // Fallback to first 100 chars
        return substr($sql, 0, 100);
    }

    /**
     * Extract table names from query
     */
    private function extractTables(string $sql): array
    {
        preg_match_all('/FROM\s+(\w+)|JOIN\s+(\w+)|INTO\s+(\w+)/i', $sql, $matches);

        $tables = array_unique(array_merge(
            $matches[1] ?? [],
            $matches[2] ?? [],
            $matches[3] ?? []
        ));

        return array_values($tables);
    }

    /**
     * Log slow queries for analysis
     */
    private function logSlowQueries(array $metrics): void
    {
        $slowQueries = array_filter($this->queries, fn($q) => $q['time'] > self::THRESHOLD_SLOW);

        if (empty($slowQueries)) {
            return;
        }

        Log::warning('Slow queries detected', [
            'request_id' => $this->requestId,
            'count' => count($slowQueries),
            'total_time_ms' => array_sum(array_column($slowQueries, 'time')),
            'queries' => array_map(fn($q) => [
                'sql' => substr($q['sql'], 0, 200),
                'time_ms' => round($q['time'], 2),
            ], $slowQueries),
        ]);
    }

    /**
     * Detect and log N+1 problems
     */
    private function detectN1Problems(array $metrics): void
    {
        $n1Candidates = $metrics['n1_candidates'] ?? [];

        if (empty($n1Candidates)) {
            return;
        }

        foreach ($n1Candidates as $candidate) {
            if ($candidate['severity'] === 'critical') {
                Log::error('N+1 query problem detected', [
                    'request_id' => $this->requestId,
                    'pattern' => $candidate['pattern'],
                    'count' => $candidate['count'],
                    'avg_time_ms' => $candidate['avg_time_ms'],
                    'recommendation' => $candidate['recommendation'],
                ]);
            } elseif ($candidate['severity'] === 'warning') {
                Log::warning('Potential N+1 query problem', [
                    'request_id' => $this->requestId,
                    'pattern' => $candidate['pattern'],
                    'count' => $candidate['count'],
                    'recommendation' => $candidate['recommendation'],
                ]);
            }
        }
    }

    /**
     * Store slow query in database log
     */
    private function storeSlowQueryLog(array $metrics): void
    {
        $slowQueries = $metrics['slow_queries'] ?? [];

        if (empty($slowQueries)) {
            return;
        }

        foreach ($slowQueries as $query) {
            try {
                DB::table('query_execution_samples')->insert([
                    'query_id' => md5($query['sql']),
                    'exec_time_ms' => round($query['time'], 2),
                    'rows_affected' => 0,
                    'rows_returned' => 0,
                    'blks_read' => 0,
                    'blks_hit' => 0,
                    'bind_values' => !empty($query['bindings']) ? json_encode($query['bindings']) : null,
                    'application_name' => config('app.name'),
                    'user_name' => auth()->id() ?? 'system',
                    'client_ip' => request()->ip() ?? 'cli',
                    'executed_at' => now(),
                ]);
            } catch (\Exception $e) {
                Log::error('Failed to store slow query sample', [
                    'error' => $e->getMessage(),
                    'sql' => substr($query['sql'], 0, 200),
                ]);
            }
        }
    }

    /**
     * Get performance report for current request
     */
    public function getReport(): array
    {
        return $this->calculateMetrics();
    }

    /**
     * Check if p95 target is met (< 50ms)
     */
    public function meetsTarget(): bool
    {
        $metrics = $this->calculateMetrics();

        return $metrics['p95_time_ms'] < 50;
    }

    /**
     * Get slow query count
     */
    public function getSlowQueryCount(): int
    {
        return count(array_filter($this->queries, fn($q) => $q['time'] > self::THRESHOLD_SLOW));
    }

    /**
     * Get metrics summary
     */
    public function getMetricsSummary(): array
    {
        $metrics = $this->calculateMetrics();

        return [
            'target_met' => $this->meetsTarget(),
            'p95_ms' => $metrics['p95_time_ms'],
            'p99_ms' => $metrics['p99_time_ms'],
            'avg_ms' => $metrics['avg_time_ms'],
            'total_queries' => $metrics['total_queries'],
            'slow_queries' => count($metrics['slow_queries']),
            'n1_problems' => count($metrics['n1_candidates']),
            'status' => $this->getStatus($metrics),
        ];
    }

    /**
     * Get status label
     */
    private function getStatus(array $metrics): string
    {
        $p95 = $metrics['p95_time_ms'] ?? 0;

        if ($p95 < 10) {
            return 'excellent';
        } elseif ($p95 < 50) {
            return 'good';
        } elseif ($p95 < 200) {
            return 'degraded';
        } else {
            return 'critical';
        }
    }
}
