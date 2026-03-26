<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Services\MetricsCollector;
use Illuminate\Support\Facades\Log;
use Livewire\Component;

/**
 * MonitoringDashboardEnhanced - Main real-time monitoring dashboard
 *
 * Orchestrates all monitoring components and provides unified dashboard view
 * Integrates: ServerHealthCard, ContainerGrid, NetworkMetrics, StorageOverview
 *
 * Features:
 * - Real-time metrics polling (configurable interval)
 * - WebSocket event listeners
 * - Quick refresh button
 * - Export metrics functionality
 * - Auto-pause when tab inactive (save resources)
 *
 * @property array $summary Overall infrastructure summary
 * @property array $servers List of all servers
 * @property string $selectedServer Currently selected server filter
 * @property bool $autoRefresh Auto-refresh enabled
 * @property int $refreshInterval Refresh interval in seconds
 */
class MonitoringDashboardEnhanced extends Component
{
    public array $summary = [];

    public array $servers = [];

    public ?string $selectedServer = null;

    public bool $autoRefresh = true;

    public int $refreshInterval;

    public bool $loading = true;

    public ?string $error = null;

    public string $lastUpdated = '';

    protected MetricsCollector $metricsCollector;

    // Real-time event listeners
    protected $listeners = [
        'server.metrics.updated' => 'handleServerMetricsUpdated',
        'container.status.changed' => 'handleContainerStatusChanged',
        'network.peer.status' => 'handleNetworkPeerStatus',
        'refreshDashboard' => 'refreshAllMetrics',
    ];

    public function boot(MetricsCollector $metricsCollector): void
    {
        $this->metricsCollector = $metricsCollector;
    }

    public function mount(): void
    {
        $this->refreshInterval = (int) config('monitoring.poll_interval', 10);
        $this->loadDashboard();
    }

    /**
     * Load complete dashboard data
     */
    public function loadDashboard(): void
    {
        try {
            $this->loading = true;

            // Aggregate all metrics
            $aggregatedMetrics = $this->metricsCollector->aggregateAllMetrics();

            if ($aggregatedMetrics['success']) {
                $this->summary = $aggregatedMetrics['summary'];
                $this->servers = $this->formatServers($aggregatedMetrics['servers']);
                $this->lastUpdated = $aggregatedMetrics['timestamp'];
                $this->error = null;
            } else {
                $this->error = 'Failed to load dashboard metrics';
            }

        } catch (\Exception $e) {
            Log::error('MonitoringDashboard failed to load', [
                'error' => $e->getMessage(),
            ]);
            $this->error = 'Dashboard error: '.$e->getMessage();
        } finally {
            $this->loading = false;
        }
    }

    /**
     * Refresh all metrics (bypass cache)
     */
    public function refreshAllMetrics(): void
    {
        $this->metricsCollector->refreshAllMetrics();
        $this->loadDashboard();

        $this->dispatch('metrics-refreshed', [
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    /**
     * Toggle auto-refresh
     */
    public function toggleAutoRefresh(): void
    {
        $this->autoRefresh = ! $this->autoRefresh;

        $this->dispatch('auto-refresh-toggled', [
            'enabled' => $this->autoRefresh,
        ]);
    }

    /**
     * Handle server metrics updated event
     */
    public function handleServerMetricsUpdated($event): void
    {
        if ($this->autoRefresh) {
            $this->loadDashboard();
        }

        $this->dispatch('alert-toast', [
            'type' => 'info',
            'message' => "Server {$event['server']} metrics updated",
        ]);
    }

    /**
     * Handle container status changed event
     */
    public function handleContainerStatusChanged($event): void
    {
        if ($this->autoRefresh) {
            $this->loadDashboard();
        }

        $type = $event['status'] === 'running' ? 'success' : 'warning';
        $this->dispatch('alert-toast', [
            'type' => $type,
            'message' => "Container {$event['name']} is now {$event['status']}",
        ]);
    }

    /**
     * Handle network peer status event
     */
    public function handleNetworkPeerStatus($event): void
    {
        $type = $event['status'] === 'connected' ? 'success' : 'warning';
        $this->dispatch('alert-toast', [
            'type' => $type,
            'message' => "Peer {$event['peer']} is {$event['status']}",
        ]);
    }

    /**
     * Export all metrics as JSON
     */
    public function exportAllMetrics(): void
    {
        try {
            $metrics = $this->metricsCollector->aggregateAllMetrics();

            $json = json_encode($metrics, JSON_PRETTY_PRINT);
            $filename = 'infrastructure-metrics-'.now()->format('Y-m-d-His').'.json';

            $this->dispatch('download-json', [
                'filename' => $filename,
                'content' => $json,
            ]);

        } catch (\Exception $e) {
            $this->dispatch('alert-toast', [
                'type' => 'error',
                'message' => 'Failed to export metrics: '.$e->getMessage(),
            ]);
        }
    }

    /**
     * Format servers data for display
     */
    protected function formatServers(array $servers): array
    {
        return collect($servers)->map(function ($server) {
            return [
                'code' => $server['server']['code'] ?? 'unknown',
                'name' => $server['server']['name'] ?? 'Unknown',
                'status' => $server['health_status'] ?? 'unknown',
                'metrics' => $server['metrics'] ?? null,
            ];
        })->toArray();
    }

    /**
     * Get overall health badge color
     */
    public function getOverallHealthColor(): string
    {
        if (! isset($this->summary['overall_health'])) {
            return 'gray';
        }

        return match ($this->summary['overall_health']) {
            'healthy' => 'green',
            'degraded' => 'yellow',
            'warning' => 'yellow',
            'critical' => 'red',
            default => 'gray',
        };
    }

    /**
     * Get health score (0-100)
     */
    public function getHealthScore(): int
    {
        $total = $this->summary['total_containers'] ?? 0;

        if ($total === 0) {
            return 100;
        }

        $running = $this->summary['running_containers'] ?? 0;
        $warning = $this->summary['warning_containers'] ?? 0;
        $critical = $this->summary['critical_containers'] ?? 0;

        $healthy = $running - $warning - $critical;

        $score = (
            ($healthy * 100) +
            ($warning * 50) +
            ($critical * 0)
        ) / $total;

        return (int) round($score);
    }

    public function render()
    {
        return view('livewire.monitoring-dashboard-enhanced');
    }
}
