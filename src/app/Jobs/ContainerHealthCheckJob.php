<?php

namespace App\Jobs;

use App\Services\ContainerHealthMonitor;
use App\Services\AlertService;
use App\Models\ProxmoxServer;
use App\Models\Alert;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

/**
 * Container Health Check Job
 *
 * Periodically checks the health of all containers across Proxmox nodes.
 * Runs every minute via Laravel Horizon scheduler.
 *
 * @package App\Jobs
 */
class ContainerHealthCheckJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds) - increased for large deployments
     */
    public int $timeout = 300;

    /**
     * Number of retry attempts
     */
    public int $tries = 3;

    /**
     * Backoff delay between retries (seconds)
     */
    public int $backoff = 60;

    /**
     * The number of seconds the job can run before reaching a maintenance window.
     */
    public int $retryAfter = 120;

    /**
     * Optional node code to check specific node only
     */
    protected ?string $nodeCode = null;

    /**
     * Whether to trigger alerts on health issues
     */
    protected bool $triggerAlerts = true;

    /**
     * Create a new job instance.
     */
    public function __construct(?string $nodeCode = null, bool $triggerAlerts = true)
    {
        $this->nodeCode = $nodeCode;
        $this->triggerAlerts = $triggerAlerts;

        // Set queue based on priority
        $this->onQueue('health-checks');
    }

    /**
     * Execute the job.
     */
    public function handle(
        ContainerHealthMonitor $monitor,
        AlertService $alertService
    ): void {
        $startTime = microtime(true);
        $cacheKey = 'health_check:running:' . ($this->nodeCode ?? 'all');

        // Prevent overlapping health checks
        if (Cache::get($cacheKey)) {
            Log::warning('Health check already running', [
                'node' => $this->nodeCode ?? 'all',
            ]);
            return;
        }

        Cache::put($cacheKey, true, 300);

        try {
            // Get servers to check
            $servers = $this->nodeCode
                ? ProxmoxServer::where('code', $this->nodeCode)->online()->get()
                : ProxmoxServer::online()->get();

            if ($servers->isEmpty()) {
                Log::warning('No online Proxmox servers found for health check', [
                    'node' => $this->nodeCode ?? 'all',
                ]);
                return;
            }

            $nodes = $servers->pluck('code')->toArray();

            Log::info('Starting container health check', [
                'nodes' => $nodes,
                'server_count' => $servers->count(),
                'trigger_alerts' => $this->triggerAlerts,
            ]);

            // Run health monitoring
            $results = $monitor->monitorNodes($nodes);

            // Process critical alerts
            if ($this->triggerAlerts && isset($results['alerts'])) {
                foreach ($results['alerts'] as $alertData) {
                    if ($alertData['severity'] === 'critical') {
                        $alertService->createAlert([
                            'type' => 'container_health',
                            'severity' => 'critical',
                            'title' => "Critical container health issue on {$alertData['node']}",
                            'description' => $alertData['message'],
                            'metadata' => $alertData,
                        ]);
                    }
                }
            }

            $duration = round(microtime(true) - $startTime, 2);

            Log::info('Container health check completed', [
                'total_containers' => $results['summary']['total_containers'] ?? 0,
                'healthy' => $results['summary']['healthy'] ?? 0,
                'warning' => $results['summary']['warning'] ?? 0,
                'critical' => $results['summary']['critical'] ?? 0,
                'alerts_triggered' => $results['alerts_triggered'] ?? 0,
                'duration' => $duration,
            ]);

            // Update server last_seen_at timestamps
            foreach ($servers as $server) {
                $server->update(['last_seen_at' => now()]);
            }

            // Store health metrics for dashboard
            Cache::put('health_metrics:latest', $results['summary'] ?? [], 60);

        } catch (\Exception $e) {
            Log::error('Container health check failed', [
                'node' => $this->nodeCode ?? 'all',
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        } finally {
            Cache::forget($cacheKey);
        }
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Container health check job failed permanently', [
            'node' => $this->nodeCode ?? 'all',
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return array_filter([
            'health-check',
            'container',
            $this->nodeCode,
        ]);
    }

    /**
     * Calculate the number of seconds to wait before retrying the job.
     */
    public function backoff(): int
    {
        return $this->backoff;
    }
}
