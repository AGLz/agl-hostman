<?php

namespace App\Jobs;

use App\Services\ContainerHealthMonitor;
use App\Models\ProxmoxServer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Monitor Container Health Job
 *
 * Background job that monitors container health across all Proxmox nodes.
 * Runs periodically via Laravel Horizon scheduler.
 *
 * @package App\Jobs
 */
class MonitorContainerHealth implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds)
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
     * Execute the job
     */
    public function handle(ContainerHealthMonitor $monitor): void
    {
        try {
            // Get all online Proxmox servers
            $servers = ProxmoxServer::online()->get();

            if ($servers->isEmpty()) {
                Log::warning('No online Proxmox servers found for monitoring');
                return;
            }

            // Get node codes
            $nodes = $servers->pluck('code')->toArray();

            Log::info('Starting container health monitoring', [
                'nodes' => $nodes,
                'server_count' => $servers->count(),
            ]);

            // Monitor all nodes
            $results = $monitor->monitorNodes($nodes);

            // Log summary
            Log::info('Container health monitoring completed', [
                'total_containers' => $results['summary']['total_containers'],
                'healthy' => $results['summary']['healthy'],
                'warning' => $results['summary']['warning'],
                'critical' => $results['summary']['critical'],
                'alerts_triggered' => $results['alerts_triggered'],
            ]);

            // Update server last_seen_at timestamps
            foreach ($servers as $server) {
                $server->update(['last_seen_at' => now()]);
            }

        } catch (\Exception $e) {
            Log::error('Container health monitoring failed: ' . $e->getMessage(), [
                'exception' => $e,
            ]);

            throw $e; // Re-throw to allow job retry
        }
    }

    /**
     * Handle job failure
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Container health monitoring job failed permanently', [
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }
}
