<?php

declare(strict_types=1);

namespace App\Livewire;

use Livewire\Component;
use Livewire\WithPagination;
use App\Services\MetricsCollector;
use App\Models\ProxmoxServer;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * ContainerGrid - Grid display of all containers with filtering and sorting
 *
 * Features:
 * - Real-time container status updates (polling every 10s)
 * - Filter by server, status, resource usage
 * - Search by container name/ID
 * - Sort by name, status, CPU, RAM, uptime
 * - Virtual scrolling for 68+ containers
 * - Quick actions (start/stop/restart)
 *
 * @property string|null $filterServer Filter by server code
 * @property string|null $filterStatus Filter by status (running, stopped, error)
 * @property string|null $filterUsage Filter by resource usage (normal, high, critical)
 * @property string $search Search query
 * @property string $sortBy Sort field
 * @property string $sortDirection Sort direction (asc, desc)
 */
class ContainerGrid extends Component
{
    use WithPagination;

    public ?string $filterServer = null;
    public ?string $filterStatus = null;
    public ?string $filterUsage = null;
    public string $search = '';
    public string $sortBy = 'vmid';
    public string $sortDirection = 'asc';
    public int $perPage = 50;

    protected Collection $containers;
    protected MetricsCollector $metricsCollector;
    protected string $queryString = 'page';

    protected $listeners = [
        'containerStatusChanged' => 'refreshContainers',
    ];

    public function boot(MetricsCollector $metricsCollector): void
    {
        $this->metricsCollector = $metricsCollector;
    }

    /**
     * Update search query (debounced in frontend)
     */
    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * Update filter server
     */
    public function updatedFilterServer(): void
    {
        $this->resetPage();
    }

    /**
     * Update filter status
     */
    public function updatedFilterStatus(): void
    {
        $this->resetPage();
    }

    /**
     * Update filter usage
     */
    public function updatedFilterUsage(): void
    {
        $this->resetPage();
    }

    /**
     * Sort by field
     */
    public function sortBy(string $field): void
    {
        if ($this->sortBy === $field) {
            $this->sortDirection = $this->sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sortBy = $field;
            $this->sortDirection = 'asc';
        }
    }

    /**
     * Clear all filters
     */
    public function clearFilters(): void
    {
        $this->filterServer = null;
        $this->filterStatus = null;
        $this->filterUsage = null;
        $this->search = '';
        $this->resetPage();
    }

    /**
     * Refresh containers (bypass cache)
     */
    public function refreshContainers(): void
    {
        $this->metricsCollector->refreshAllMetrics();
    }

    /**
     * Get containers with filters and sorting applied
     */
    public function getContainersProperty(): Collection
    {
        try {
            $servers = ProxmoxServer::all();
            $allContainers = collect([]);

            foreach ($servers as $server) {
                // Apply server filter
                if ($this->filterServer && $server->code !== $this->filterServer) {
                    continue;
                }

                $containerMetrics = $this->metricsCollector->collectContainerMetrics($server->id);
                $allContainers = $allContainers->merge($containerMetrics);
            }

            // Apply search filter
            if ($this->search) {
                $search = strtolower($this->search);
                $allContainers = $allContainers->filter(function ($container) use ($search) {
                    return str_contains(strtolower($container['name'] ?? ''), $search) ||
                           str_contains(strtolower($container['hostname'] ?? ''), $search) ||
                           str_contains((string) ($container['vmid'] ?? ''), $search);
                });
            }

            // Apply status filter
            if ($this->filterStatus) {
                $allContainers = $allContainers->filter(function ($container) {
                    return ($container['status'] ?? 'unknown') === $this->filterStatus;
                });
            }

            // Apply usage filter
            if ($this->filterUsage) {
                $allContainers = $allContainers->filter(function ($container) {
                    $healthStatus = $container['health_status'] ?? 'unknown';

                    return match ($this->filterUsage) {
                        'normal' => $healthStatus === 'healthy',
                        'high' => $healthStatus === 'warning',
                        'critical' => $healthStatus === 'critical',
                        default => true,
                    };
                });
            }

            // Apply sorting
            $allContainers = $allContainers->sortBy(function ($container) {
                return match ($this->sortBy) {
                    'name' => strtolower($container['name'] ?? ''),
                    'status' => $container['status'] ?? '',
                    'cpu' => $container['cpu']['usage_percent'] ?? 0,
                    'memory' => $container['memory']['usage_percent'] ?? 0,
                    'uptime' => $container['uptime'] ?? 0,
                    default => $container['vmid'] ?? 0,
                };
            }, SORT_REGULAR, $this->sortDirection === 'desc');

            return $allContainers->values();

        } catch (\Exception $e) {
            Log::error("Failed to load containers", [
                'error' => $e->getMessage(),
            ]);

            return collect([]);
        }
    }

    /**
     * Get available servers for filter dropdown
     */
    public function getServersProperty(): Collection
    {
        return ProxmoxServer::all()->pluck('name', 'code');
    }

    /**
     * Get health status badge color
     */
    public function getHealthBadgeColor(string $healthStatus): string
    {
        return match ($healthStatus) {
            'healthy' => 'green',
            'warning' => 'yellow',
            'critical' => 'red',
            'stopped' => 'gray',
            'offline' => 'gray',
            'error' => 'red',
            default => 'gray',
        };
    }

    /**
     * Get status badge color
     */
    public function getStatusBadgeColor(string $status): string
    {
        return match ($status) {
            'running' => 'green',
            'stopped' => 'gray',
            'paused' => 'yellow',
            'error' => 'red',
            'offline' => 'gray',
            default => 'gray',
        };
    }

    /**
     * Export metrics as JSON
     */
    public function exportMetrics(): void
    {
        $containers = $this->containers;

        $json = json_encode([
            'timestamp' => now()->toIso8601String(),
            'total_containers' => $containers->count(),
            'filters' => [
                'server' => $this->filterServer,
                'status' => $this->filterStatus,
                'usage' => $this->filterUsage,
                'search' => $this->search,
            ],
            'containers' => $containers->toArray(),
        ], JSON_PRETTY_PRINT);

        $filename = 'container-metrics-' . now()->format('Y-m-d-His') . '.json';

        $this->dispatch('download-json', [
            'filename' => $filename,
            'content' => $json,
        ]);
    }

    public function render()
    {
        return view('livewire.container-grid', [
            'containers' => $this->containers,
            'servers' => $this->servers,
        ]);
    }
}
