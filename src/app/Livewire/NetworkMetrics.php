<?php

declare(strict_types=1);

namespace App\Livewire;

use Livewire\Component;
use App\Services\MetricsCollector;
use Illuminate\Support\Facades\Log;

/**
 * NetworkMetrics - WireGuard mesh network status display
 *
 * Real-time network monitoring with peer status and latency
 * Shows WireGuard mesh connectivity across all 14 active nodes
 *
 * Health Status:
 * - Green: All peers connected, latency <50ms
 * - Yellow: Some peers down, or latency 50-150ms
 * - Red: Multiple peers down, or latency >150ms
 *
 * @property array|null $metrics Network metrics data
 * @property bool $showPeerDetails Show individual peer details
 */
class NetworkMetrics extends Component
{
    public ?array $metrics = null;
    public ?string $error = null;
    public bool $loading = true;
    public bool $showPeerDetails = false;

    protected MetricsCollector $metricsCollector;

    public function boot(MetricsCollector $metricsCollector): void
    {
        $this->metricsCollector = $metricsCollector;
    }

    public function mount(): void
    {
        $this->loadMetrics();
    }

    /**
     * Load network metrics
     */
    public function loadMetrics(): void
    {
        try {
            $this->loading = true;
            $this->metrics = $this->metricsCollector->collectNetworkMetrics();

            if (!$this->metrics['success']) {
                $this->error = 'Failed to load network metrics';
            } else {
                $this->error = null;
            }
        } catch (\Exception $e) {
            Log::error("NetworkMetrics failed to load", [
                'error' => $e->getMessage(),
            ]);
            $this->error = 'Failed to load network metrics';
            $this->metrics = null;
        } finally {
            $this->loading = false;
        }
    }

    /**
     * Toggle peer details view
     */
    public function togglePeerDetails(): void
    {
        $this->showPeerDetails = !$this->showPeerDetails;
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
     * Get health badge color
     */
    public function getHealthBadgeColor(): string
    {
        if (!$this->metrics) {
            return 'gray';
        }

        return match ($this->metrics['health_status']) {
            'healthy' => 'green',
            'warning' => 'yellow',
            'critical' => 'red',
            default => 'gray',
        };
    }

    /**
     * Get peer status badge color
     */
    public function getPeerStatusColor(string $status): string
    {
        return match ($status) {
            'connected' => 'green',
            'disconnected' => 'red',
            'timeout' => 'yellow',
            default => 'gray',
        };
    }

    /**
     * Get latency class for color coding
     */
    public function getLatencyClass(float $latencyMs): string
    {
        if ($latencyMs > 150) {
            return 'text-red-600 font-bold';
        }

        if ($latencyMs > 50) {
            return 'text-yellow-600 font-semibold';
        }

        return 'text-green-600';
    }

    /**
     * Get connection percentage
     */
    public function getConnectionPercentage(): int
    {
        if (!$this->metrics || !isset($this->metrics['summary'])) {
            return 0;
        }

        $summary = $this->metrics['summary'];
        $total = $summary['total_peers'] ?? 0;
        $connected = $summary['connected_peers'] ?? 0;

        if ($total === 0) {
            return 0;
        }

        return (int) round(($connected / $total) * 100);
    }

    public function render()
    {
        return view('livewire.network-metrics');
    }
}
