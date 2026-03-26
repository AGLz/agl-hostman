<?php

namespace App\Livewire;

use App\Services\ContainerHealthMonitor;
use Livewire\Component;

/**
 * Container Health Card Component
 *
 * Displays health status for a single container with metrics and trends.
 */
class ContainerHealthCard extends Component
{
    public string $node;

    public int $vmid;

    public array $containerData = [];

    public bool $expanded = false;

    public int $historyHours = 24;

    protected $listeners = [
        'containerUpdated' => 'loadContainerData',
        'echo:node.{node},ContainerCritical' => 'handleContainerUpdate',
    ];

    public function mount(string $node, int $vmid)
    {
        $this->node = $node;
        $this->vmid = $vmid;
        $this->loadContainerData();
    }

    public function render()
    {
        return view('livewire.container-health-card', [
            'containerData' => $this->containerData,
            'expanded' => $this->expanded,
        ]);
    }

    /**
     * Load container health data
     */
    public function loadContainerData()
    {
        try {
            $monitor = app(ContainerHealthMonitor::class);
            $results = $monitor->monitorNode($this->node);

            // Find this container in results
            $container = collect($results['containers'])
                ->firstWhere('vmid', $this->vmid);

            if ($container) {
                $this->containerData = [
                    'vmid' => $container['vmid'],
                    'name' => $container['name'],
                    'health_status' => $container['health_status'],
                    'severity' => $container['severity'],
                    'metrics' => $container['metrics'],
                    'issues' => $container['issues'] ?? [],
                    'trend' => $container['trend'] ?? null,
                ];
            } else {
                $this->containerData = [
                    'error' => 'Container not found',
                ];
            }

        } catch (\Exception $e) {
            $this->containerData = [
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Handle real-time container update
     */
    public function handleContainerUpdate($event)
    {
        if ($event['vmid'] == $this->vmid) {
            $this->loadContainerData();

            $this->dispatch('containerAlertReceived', [
                'vmid' => $this->vmid,
                'severity' => $event['severity'],
            ]);
        }
    }

    /**
     * Toggle expanded view
     */
    public function toggleExpanded()
    {
        $this->expanded = ! $this->expanded;

        if ($this->expanded) {
            $this->dispatch('containerExpanded', [
                'node' => $this->node,
                'vmid' => $this->vmid,
            ]);
        }
    }

    /**
     * Change history duration
     */
    public function setHistoryHours(int $hours)
    {
        $this->historyHours = min(max($hours, 1), 168); // 1 hour to 7 days
    }

    /**
     * Get severity badge color
     */
    public function getSeverityColor(string $severity): string
    {
        return match ($severity) {
            'critical' => 'red',
            'warning' => 'yellow',
            'info' => 'blue',
            default => 'gray',
        };
    }

    /**
     * Get health status icon
     */
    public function getHealthIcon(string $status): string
    {
        return match ($status) {
            'healthy' => 'check-circle',
            'warning' => 'exclamation-triangle',
            'critical' => 'exclamation-circle',
            'stopped' => 'stop-circle',
            default => 'question-circle',
        };
    }

    /**
     * Format metric value
     */
    public function formatMetric(float $value, string $type = 'percent'): string
    {
        return match ($type) {
            'percent' => round($value, 1).'%',
            'bytes' => $this->formatBytes($value),
            default => (string) $value,
        };
    }

    /**
     * Format bytes to human-readable
     */
    protected function formatBytes(float $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $power = $bytes > 0 ? floor(log($bytes, 1024)) : 0;

        return round($bytes / pow(1024, $power), 2).' '.$units[$power];
    }
}
