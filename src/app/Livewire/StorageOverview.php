<?php

declare(strict_types=1);

namespace App\Livewire;

use Livewire\Component;
use App\Services\MetricsCollector;
use Illuminate\Support\Facades\Log;

/**
 * StorageOverview - NFS storage usage monitoring
 *
 * Real-time storage metrics across all Proxmox servers
 * Shows NFS mounts, usage, and performance indicators
 *
 * Health Status:
 * - Green: <70% used
 * - Yellow: 70-85% used
 * - Red: >85% used
 *
 * @property array|null $metrics Storage metrics data
 * @property bool $showMountDetails Show individual mount details
 */
class StorageOverview extends Component
{
    public ?array $metrics = null;
    public ?string $error = null;
    public bool $loading = true;
    public bool $showMountDetails = false;

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
     * Load storage metrics
     */
    public function loadMetrics(): void
    {
        try {
            $this->loading = true;
            $this->metrics = $this->metricsCollector->collectStorageMetrics();

            if (!$this->metrics['success']) {
                $this->error = 'Failed to load storage metrics';
            } else {
                $this->error = null;
            }
        } catch (\Exception $e) {
            Log::error("StorageOverview failed to load", [
                'error' => $e->getMessage(),
            ]);
            $this->error = 'Failed to load storage metrics';
            $this->metrics = null;
        } finally {
            $this->loading = false;
        }
    }

    /**
     * Toggle mount details view
     */
    public function toggleMountDetails(): void
    {
        $this->showMountDetails = !$this->showMountDetails;
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
     * Get mount usage color
     */
    public function getMountUsageColor(float $percentUsed): string
    {
        if ($percentUsed > 85) {
            return 'red';
        }

        if ($percentUsed > 70) {
            return 'yellow';
        }

        return 'green';
    }

    /**
     * Get mount usage class
     */
    public function getMountUsageClass(float $percentUsed): string
    {
        if ($percentUsed > 85) {
            return 'text-red-600 font-bold';
        }

        if ($percentUsed > 70) {
            return 'text-yellow-600 font-semibold';
        }

        return 'text-green-600';
    }

    /**
     * Get overall usage percentage
     */
    public function getOverallUsagePercentage(): int
    {
        if (!$this->metrics || !isset($this->metrics['summary'])) {
            return 0;
        }

        return (int) round($this->metrics['summary']['avg_usage_percent'] ?? 0);
    }

    public function render()
    {
        return view('livewire.storage-overview');
    }
}
