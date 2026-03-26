<?php

namespace App\Jobs;

use App\Models\ProxmoxServer;
use App\Services\MetricsCollector;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Metrics Collection Job
 *
 * Collects and aggregates system metrics from all infrastructure components.
 * Stores metrics in database for trend analysis and alerting.
 */
class MetricsCollectionJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds)
     */
    public int $timeout = 180;

    /**
     * Number of retry attempts
     */
    public int $tries = 3;

    /**
     * Backoff delay between retries (seconds)
     */
    public int $backoff = 30;

    /**
     * Collection type: 'full', 'quick', 'containers', 'system'
     */
    protected string $collectionType;

    /**
     * Whether to aggregate metrics after collection
     */
    protected bool $aggregate;

    /**
     * Create a new job instance.
     */
    public function __construct(string $collectionType = 'full', bool $aggregate = true)
    {
        $this->collectionType = $collectionType;
        $this->aggregate = $aggregate;

        // Set queue based on priority
        $this->onQueue('metrics-collection');
    }

    /**
     * Execute the job.
     */
    public function handle(MetricsCollector $collector): void
    {
        $startTime = microtime(true);
        $cacheKey = "metrics_collection:{$this->collectionType}:running";

        // Prevent overlapping collections
        if (Cache::get($cacheKey)) {
            Log::warning('Metrics collection already running', [
                'type' => $this->collectionType,
            ]);

            return;
        }

        Cache::put($cacheKey, true, 180);

        try {
            $servers = ProxmoxServer::online()->get();

            if ($servers->isEmpty()) {
                Log::warning('No online servers for metrics collection');

                return;
            }

            Log::info('Starting metrics collection', [
                'type' => $this->collectionType,
                'servers' => $servers->count(),
                'aggregate' => $this->aggregate,
            ]);

            $metrics = [];

            // Collect metrics based on type
            switch ($this->collectionType) {
                case 'quick':
                    $metrics = $this->collectQuickMetrics($collector, $servers);
                    break;
                case 'containers':
                    $metrics = $this->collectContainerMetrics($collector, $servers);
                    break;
                case 'system':
                    $metrics = $this->collectSystemMetrics($collector, $servers);
                    break;
                case 'full':
                default:
                    $metrics = $this->collectAllMetrics($collector, $servers);
                    break;
            }

            // Store metrics for dashboard
            Cache::put('metrics:latest', $metrics, 300);
            Cache::put('metrics:last_collection', now()->toIso8601String(), 300);

            // Aggregation if enabled
            if ($this->aggregate) {
                $this->aggregateMetrics($metrics);
            }

            $duration = round(microtime(true) - $startTime, 2);

            Log::info('Metrics collection completed', [
                'type' => $this->collectionType,
                'metrics_collected' => count($metrics),
                'duration' => $duration,
            ]);

        } catch (\Exception $e) {
            Log::error('Metrics collection failed', [
                'type' => $this->collectionType,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        } finally {
            Cache::forget($cacheKey);
        }
    }

    /**
     * Collect quick metrics (CPU, memory, disk usage only)
     */
    protected function collectQuickMetrics(MetricsCollector $collector, $servers): array
    {
        $metrics = [];

        foreach ($servers as $server) {
            try {
                $serverMetrics = $collector->collectQuickMetrics($server->code);
                $metrics[$server->code] = $serverMetrics;

                // Store in cache for quick access
                Cache::put("metrics:{$server->code}:quick", $serverMetrics, 300);
            } catch (\Exception $e) {
                Log::warning('Failed to collect quick metrics for server', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $metrics;
    }

    /**
     * Collect container-specific metrics
     */
    protected function collectContainerMetrics(MetricsCollector $collector, $servers): array
    {
        $metrics = [];

        foreach ($servers as $server) {
            try {
                $containerMetrics = $collector->collectContainerMetrics($server->code);
                $metrics[$server->code] = $containerMetrics;

                Cache::put("metrics:{$server->code}:containers", $containerMetrics, 300);
            } catch (\Exception $e) {
                Log::warning('Failed to collect container metrics', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $metrics;
    }

    /**
     * Collect system-level metrics
     */
    protected function collectSystemMetrics(MetricsCollector $collector, $servers): array
    {
        $metrics = [];

        foreach ($servers as $server) {
            try {
                $systemMetrics = $collector->collectSystemMetrics($server->code);
                $metrics[$server->code] = $systemMetrics;

                Cache::put("metrics:{$server->code}:system", $systemMetrics, 300);
            } catch (\Exception $e) {
                Log::warning('Failed to collect system metrics', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $metrics;
    }

    /**
     * Collect all metrics (full collection)
     */
    protected function collectAllMetrics(MetricsCollector $collector, $servers): array
    {
        return array_merge(
            $this->collectQuickMetrics($collector, $servers),
            $this->collectContainerMetrics($collector, $servers),
            $this->collectSystemMetrics($collector, $servers)
        );
    }

    /**
     * Aggregate metrics for trending and reporting
     */
    protected function aggregateMetrics(array $metrics): void
    {
        try {
            $aggregation = [
                'timestamp' => now()->toIso8601String(),
                'total_servers' => count($metrics),
                'averages' => [
                    'cpu_usage' => collect($metrics)->avg(fn ($m) => $m['cpu'] ?? 0),
                    'memory_usage' => collect($metrics)->avg(fn ($m) => $m['memory'] ?? 0),
                    'disk_usage' => collect($metrics)->avg(fn ($m) => $m['disk'] ?? 0),
                ],
                'totals' => [
                    'containers_running' => collect($metrics)->sum(fn ($m) => $m['containers_running'] ?? 0),
                    'containers_stopped' => collect($metrics)->sum(fn ($m) => $m['containers_stopped'] ?? 0),
                ],
            ];

            // Store aggregated metrics
            Cache::put('metrics:aggregated', $aggregation, 600);

            // Store in database for historical analysis
            DB::table('metrics_aggregates')->insert($aggregation);

        } catch (\Exception $e) {
            Log::warning('Failed to aggregate metrics', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Metrics collection job failed permanently', [
            'type' => $this->collectionType,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return [
            'metrics',
            'collection',
            $this->collectionType,
        ];
    }
}
