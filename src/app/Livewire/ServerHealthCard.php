<?php

declare(strict_types=1);

namespace App\Livewire;

use App\Services\MetricsCollector;
use Illuminate\Support\Facades\Log;
use Livewire\Component;

/**
 * ServerHealthCard - Display individual server health metrics
 *
 * Real-time server health monitoring with visual status indicators
 * Polls every 10 seconds (configurable via MONITORING_POLL_INTERVAL)
 *
 * Health Status Colors:
 * - Green (healthy): CPU <70%, RAM <80%, load <cores
 * - Yellow (warning): CPU 70-85%, RAM 80-90%, load = cores
 * - Red (critical): CPU >85%, RAM >90%, load >cores
 * - Gray (offline): Server unreachable
 *
 * @property string $serverCode Server code (e.g., 'aglsrv1')
 * @property bool $showDetails Show detailed metrics
 */
class ServerHealthCard extends Component
{
    public string $serverCode;

    public bool $showDetails = false;

    public ?array $metrics = null;

    public ?string $error = null;

    public bool $loading = true;

    protected MetricsCollector $metricsCollector;

    public function boot(MetricsCollector $metricsCollector): void
    {
        $this->metricsCollector = $metricsCollector;
    }

    public function mount(string $serverCode): void
    {
        $this->serverCode = $serverCode;
        $this->loadMetrics();
    }

    /**
     * Load server metrics
     */
    public function loadMetrics(): void
    {
        try {
            $this->loading = true;
            $result = $this->metricsCollector->collectServerMetrics($this->serverCode);

            if ($result['success']) {
                $this->metrics = $result;
                $this->error = null;
            } else {
                $this->error = $result['error'] ?? 'Failed to load metrics';
                $this->metrics = null;
            }
        } catch (\Exception $e) {
            Log::error("ServerHealthCard failed to load metrics for {$this->serverCode}", [
                'error' => $e->getMessage(),
            ]);
            $this->error = 'Failed to load server metrics';
            $this->metrics = null;
        } finally {
            $this->loading = false;
        }
    }

    /**
     * Toggle detailed metrics view
     */
    public function toggleDetails(): void
    {
        $this->showDetails = ! $this->showDetails;
    }

    /**
     * Refresh metrics (bypass cache)
     */
    public function refresh(): void
    {
        $this->metricsCollector->refreshAllMetrics();
        $this->loadMetrics();
    }

    /**
     * Get health status badge color
     */
    public function getHealthBadgeColor(): string
    {
        if (! $this->metrics) {
            return 'gray';
        }

        return match ($this->metrics['health_status']) {
            'healthy' => 'green',
            'warning' => 'yellow',
            'critical' => 'red',
            'offline' => 'gray',
            default => 'gray',
        };
    }

    /**
     * Get health status text
     */
    public function getHealthStatusText(): string
    {
        if (! $this->metrics) {
            return 'Unknown';
        }

        return match ($this->metrics['health_status']) {
            'healthy' => 'Healthy',
            'warning' => 'Warning',
            'critical' => 'Critical',
            'offline' => 'Offline',
            default => 'Unknown',
        };
    }

    /**
     * Get CPU usage class
     */
    public function getCpuUsageClass(): string
    {
        if (! isset($this->metrics['metrics']['cpu']['usage_percent'])) {
            return 'text-gray-600';
        }

        $usage = $this->metrics['metrics']['cpu']['usage_percent'];

        if ($usage > 85) {
            return 'text-red-600 font-bold';
        }

        if ($usage > 70) {
            return 'text-yellow-600 font-semibold';
        }

        return 'text-green-600';
    }

    /**
     * Get memory usage class
     */
    public function getMemoryUsageClass(): string
    {
        if (! isset($this->metrics['metrics']['memory']['usage_percent'])) {
            return 'text-gray-600';
        }

        $usage = $this->metrics['metrics']['memory']['usage_percent'];

        if ($usage > 90) {
            return 'text-red-600 font-bold';
        }

        if ($usage > 80) {
            return 'text-yellow-600 font-semibold';
        }

        return 'text-green-600';
    }

    public function render()
    {
        return view('livewire.server-health-card');
    }
}
