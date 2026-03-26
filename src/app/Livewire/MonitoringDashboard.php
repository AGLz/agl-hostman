<?php

namespace App\Livewire;

use App\Models\ProxmoxServer;
use App\Services\ContainerHealthMonitor;
use Illuminate\Support\Facades\Cache;
use Livewire\Component;

/**
 * Monitoring Dashboard Component
 *
 * Main dashboard component that orchestrates real-time monitoring display.
 * Listens to broadcast events and updates UI automatically.
 */
class MonitoringDashboard extends Component
{
    // Dashboard state
    public array $clusterStats = [];

    public array $nodes = [];

    public string $selectedNode = '';

    public int $refreshInterval = 30; // seconds

    public string $lastUpdated = '';

    // Filters
    public string $healthFilter = 'all'; // all, healthy, warning, critical

    public string $viewMode = 'grid'; // grid, list

    public bool $autoRefresh = true;

    // Real-time event listeners
    protected $listeners = [
        'containerCritical' => 'handleContainerCritical',
        'resourceExhaustionPredicted' => 'handleResourceExhaustion',
        'refreshDashboard' => 'loadDashboardData',
        'echo:infrastructure-alerts,ContainerCritical' => 'handleContainerCritical',
        'echo:infrastructure-alerts,ResourceExhaustionPredicted' => 'handleResourceExhaustion',
    ];

    public function mount()
    {
        $this->loadDashboardData();
        $this->lastUpdated = now()->toIso8601String();
    }

    public function render()
    {
        return view('livewire.monitoring-dashboard', [
            'clusterStats' => $this->clusterStats,
            'nodes' => $this->nodes,
            'lastUpdated' => $this->lastUpdated,
        ]);
    }

    /**
     * Load dashboard data from cache or API
     */
    public function loadDashboardData()
    {
        try {
            // Get cluster-wide statistics
            $this->clusterStats = Cache::remember(
                'dashboard:cluster_stats',
                now()->addSeconds(30),
                fn () => $this->getClusterStatistics()
            );

            // Get online nodes
            $servers = ProxmoxServer::online()->get();
            $this->nodes = $servers->map(fn ($server) => [
                'code' => $server->code,
                'name' => $server->name,
                'status' => $server->status,
                'last_seen' => $server->last_seen_at?->diffForHumans(),
            ])->toArray();

            // Set default selected node if none selected
            if (empty($this->selectedNode) && ! empty($this->nodes)) {
                $this->selectedNode = $this->nodes[0]['code'];
            }

            $this->lastUpdated = now()->toIso8601String();

            $this->dispatch('dashboardUpdated', [
                'timestamp' => $this->lastUpdated,
                'stats' => $this->clusterStats,
            ]);

        } catch (\Exception $e) {
            $this->dispatch('dashboardError', [
                'message' => 'Failed to load dashboard data: '.$e->getMessage(),
            ]);
        }
    }

    /**
     * Get cluster statistics
     */
    protected function getClusterStatistics(): array
    {
        $monitor = app(ContainerHealthMonitor::class);
        $stats = $monitor->getClusterHealthStatistics();

        return [
            'servers' => [
                'total' => ProxmoxServer::count(),
                'online' => ProxmoxServer::online()->count(),
                'offline' => ProxmoxServer::offline()->count(),
            ],
            'containers' => $stats['current'] ?? [
                'total' => 0,
                'healthy' => 0,
                'warning' => 0,
                'critical' => 0,
            ],
            'alerts' => [
                'last_24h' => $stats['alerts_last_24h'] ?? 0,
                'critical_incidents' => $stats['critical_incidents'] ?? 0,
            ],
            'health_score' => $this->calculateHealthScore($stats),
        ];
    }

    /**
     * Calculate overall health score
     */
    protected function calculateHealthScore(array $stats): int
    {
        $current = $stats['current'] ?? [];
        $total = $current['total'] ?? 1;

        if ($total === 0) {
            return 100;
        }

        $healthy = $current['healthy'] ?? 0;
        $warning = $current['warning'] ?? 0;
        $critical = $current['critical'] ?? 0;

        $score = (
            ($healthy * 100) +
            ($warning * 50) +
            ($critical * 0)
        ) / $total;

        return (int) round($score);
    }

    /**
     * Handle container critical event
     */
    public function handleContainerCritical($event)
    {
        $this->dispatch('alert', [
            'type' => 'critical',
            'title' => 'Container Critical Alert',
            'message' => "Container {$event['container']} on {$event['node']} is in critical state",
            'node' => $event['node'],
            'vmid' => $event['vmid'],
            'severity' => $event['severity'],
        ]);

        // Refresh dashboard to show updated stats
        if ($this->autoRefresh) {
            $this->loadDashboardData();
        }
    }

    /**
     * Handle resource exhaustion prediction event
     */
    public function handleResourceExhaustion($event)
    {
        $this->dispatch('alert', [
            'type' => 'warning',
            'title' => 'Resource Exhaustion Predicted',
            'message' => "Container {$event['vmid']} on {$event['node']} predicted to exhaust {$event['resource_type']} in {$event['hours_ahead']} hours",
            'node' => $event['node'],
            'vmid' => $event['vmid'],
            'resource_type' => $event['resource_type'],
            'predicted_usage' => $event['predicted_usage'],
        ]);
    }

    /**
     * Toggle auto-refresh
     */
    public function toggleAutoRefresh()
    {
        $this->autoRefresh = ! $this->autoRefresh;

        $this->dispatch('autoRefreshToggled', [
            'enabled' => $this->autoRefresh,
        ]);
    }

    /**
     * Change view mode
     */
    public function setViewMode(string $mode)
    {
        $this->viewMode = in_array($mode, ['grid', 'list']) ? $mode : 'grid';
    }

    /**
     * Change health filter
     */
    public function setHealthFilter(string $filter)
    {
        $this->healthFilter = in_array($filter, ['all', 'healthy', 'warning', 'critical'])
            ? $filter
            : 'all';
    }

    /**
     * Select a specific node
     */
    public function selectNode(string $nodeCode)
    {
        $this->selectedNode = $nodeCode;

        $this->dispatch('nodeSelected', [
            'node' => $nodeCode,
        ]);
    }

    /**
     * Manual refresh trigger
     */
    public function refresh()
    {
        $this->loadDashboardData();
    }

    /**
     * Get health status badge color
     */
    public function getHealthBadgeColor(string $status): string
    {
        return match ($status) {
            'healthy' => 'green',
            'warning' => 'yellow',
            'critical' => 'red',
            default => 'gray',
        };
    }

    /**
     * Get health score color
     */
    public function getHealthScoreColor(int $score): string
    {
        if ($score >= 90) {
            return 'green';
        }
        if ($score >= 70) {
            return 'yellow';
        }
        if ($score >= 50) {
            return 'orange';
        }

        return 'red';
    }
}
