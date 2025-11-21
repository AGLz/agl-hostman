<?php

namespace App\Livewire;

use App\Models\ContainerHealthLog;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * Alert History Panel Component
 *
 * Displays paginated alert history with filtering and search capabilities.
 *
 * @package App\Livewire
 */
class AlertHistoryPanel extends Component
{
    use WithPagination;

    public int $hours = 24;
    public string $severityFilter = 'unhealthy'; // all, healthy, unhealthy, warning, critical
    public ?string $nodeFilter = null;
    public string $searchTerm = '';
    public int $perPage = 20;
    public string $sortBy = 'created_at';
    public string $sortDirection = 'desc';

    protected $queryString = [
        'hours' => ['except' => 24],
        'severityFilter' => ['except' => 'unhealthy'],
        'nodeFilter' => ['except' => null],
        'searchTerm' => ['except' => ''],
    ];

    protected $listeners = [
        'refreshAlerts' => '$refresh',
        'newAlertReceived' => 'handleNewAlert',
    ];

    public function render()
    {
        $alerts = $this->getAlerts();

        return view('livewire.alert-history-panel', [
            'alerts' => $alerts,
            'totalAlerts' => $this->getTotalAlertCount(),
            'criticalCount' => $this->getCriticalCount(),
            'warningCount' => $this->getWarningCount(),
        ]);
    }

    /**
     * Get filtered and paginated alerts
     */
    protected function getAlerts()
    {
        $query = ContainerHealthLog::query()
            ->where('created_at', '>=', now()->subHours($this->hours))
            ->orderBy($this->sortBy, $this->sortDirection);

        // Apply severity filter
        if ($this->severityFilter === 'unhealthy') {
            $query->unhealthy();
        } elseif ($this->severityFilter === 'critical') {
            $query->critical();
        } elseif ($this->severityFilter !== 'all') {
            $query->where('health_status', $this->severityFilter);
        }

        // Apply node filter
        if ($this->nodeFilter) {
            $query->forNode($this->nodeFilter);
        }

        // Apply search term
        if ($this->searchTerm) {
            $query->where(function ($q) {
                $q->where('container_name', 'like', "%{$this->searchTerm}%")
                  ->orWhere('vmid', 'like', "%{$this->searchTerm}%")
                  ->orWhere('node_code', 'like', "%{$this->searchTerm}%");
            });
        }

        return $query->paginate($this->perPage);
    }

    /**
     * Get total alert count
     */
    protected function getTotalAlertCount(): int
    {
        return ContainerHealthLog::unhealthy()
            ->where('created_at', '>=', now()->subHours($this->hours))
            ->count();
    }

    /**
     * Get critical alert count
     */
    protected function getCriticalCount(): int
    {
        return ContainerHealthLog::critical()
            ->where('created_at', '>=', now()->subHours($this->hours))
            ->count();
    }

    /**
     * Get warning alert count
     */
    protected function getWarningCount(): int
    {
        return ContainerHealthLog::where('health_status', 'warning')
            ->where('created_at', '>=', now()->subHours($this->hours))
            ->count();
    }

    /**
     * Change time range
     */
    public function setTimeRange(int $hours)
    {
        $this->hours = min(max($hours, 1), 168); // 1 hour to 7 days
        $this->resetPage();
    }

    /**
     * Change severity filter
     */
    public function setSeverityFilter(string $filter)
    {
        $this->severityFilter = $filter;
        $this->resetPage();
    }

    /**
     * Change node filter
     */
    public function setNodeFilter(?string $node)
    {
        $this->nodeFilter = $node;
        $this->resetPage();
    }

    /**
     * Update search term
     */
    public function updatedSearchTerm()
    {
        $this->resetPage();
    }

    /**
     * Change sort column
     */
    public function sortBy(string $column)
    {
        if ($this->sortBy === $column) {
            $this->sortDirection = $this->sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sortBy = $column;
            $this->sortDirection = 'desc';
        }

        $this->resetPage();
    }

    /**
     * Change items per page
     */
    public function setPerPage(int $perPage)
    {
        $this->perPage = min(max($perPage, 10), 100);
        $this->resetPage();
    }

    /**
     * Handle new alert received via broadcast
     */
    public function handleNewAlert($event)
    {
        $this->dispatch('alertToast', [
            'severity' => $event['severity'],
            'message' => "New {$event['severity']} alert for container {$event['vmid']} on {$event['node']}",
        ]);

        // Refresh the list if on first page
        if ($this->getPage() === 1) {
            $this->resetPage();
        }
    }

    /**
     * Clear all filters
     */
    public function clearFilters()
    {
        $this->hours = 24;
        $this->severityFilter = 'unhealthy';
        $this->nodeFilter = null;
        $this->searchTerm = '';
        $this->resetPage();
    }

    /**
     * Export alerts as CSV
     */
    public function exportCsv()
    {
        $alerts = $this->getAlerts()->items();

        $filename = "alerts_" . now()->format('Y-m-d_His') . '.csv';

        $csv = "Timestamp,Node,VMID,Container,Health Status,CPU %,Memory %,Disk %,Issues\n";

        foreach ($alerts as $alert) {
            $issues = is_array($alert->issues) ? implode('; ', $alert->issues) : '';
            $csv .= sprintf(
                "%s,%s,%s,%s,%s,%.2f,%.2f,%.2f,\"%s\"\n",
                $alert->created_at->toIso8601String(),
                $alert->node_code,
                $alert->vmid,
                $alert->container_name,
                $alert->health_status,
                $alert->cpu_usage_percent,
                $alert->memory_usage_percent,
                $alert->disk_usage_percent,
                $issues
            );
        }

        return response()->streamDownload(function () use ($csv) {
            echo $csv;
        }, $filename, [
            'Content-Type' => 'text/csv',
        ]);
    }

    /**
     * Get severity badge color
     */
    public function getSeverityColor(string $severity): string
    {
        return match ($severity) {
            'critical' => 'red',
            'warning' => 'yellow',
            'healthy' => 'green',
            default => 'gray',
        };
    }

    /**
     * Get severity icon
     */
    public function getSeverityIcon(string $severity): string
    {
        return match ($severity) {
            'critical' => 'exclamation-circle',
            'warning' => 'exclamation-triangle',
            'healthy' => 'check-circle',
            'stopped' => 'stop-circle',
            default => 'question-circle',
        };
    }
}
