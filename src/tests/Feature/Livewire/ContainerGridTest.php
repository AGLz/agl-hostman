<?php

declare(strict_types=1);

use App\Livewire\ContainerGrid;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use App\Services\MetricsCollector;
use Livewire\Livewire;

beforeEach(function () {
    $this->metricsCollector = Mockery::mock(MetricsCollector::class);
    $this->app->instance(MetricsCollector::class, $this->metricsCollector);

    $this->server1 = ProxmoxServer::factory()->create([
        'code' => 'aglsrv1',
        'status' => 'online',
    ]);

    $this->server2 = ProxmoxServer::factory()->create([
        'code' => 'aglsrv6',
        'status' => 'online',
    ]);

    $this->containers = LxcContainer::factory()->count(10)->create([
        'proxmox_server_id' => $this->server1->id,
        'status' => 'running',
    ]);
});

afterEach(function () {
    Mockery::close();
});

describe('ContainerGrid - Component Mounting', function () {
    test('component can be mounted successfully', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->assertOk()
            ->assertSet('filterServer', null)
            ->assertSet('filterStatus', null)
            ->assertSet('search', '')
            ->assertSet('sortBy', 'vmid')
            ->assertSet('sortDirection', 'asc')
            ->assertSet('perPage', 50);
    });
});

describe('ContainerGrid - Container Loading', function () {
    test('loadContainers retrieves all container metrics', function () {
        $mockMetrics = collect([
            [
                'vmid' => '100',
                'name' => 'ct100',
                'status' => 'running',
                'cpu_percent' => 45.5,
                'memory_percent' => 60.2,
                'disk_percent' => 30.0,
                'health_status' => 'healthy',
            ],
            [
                'vmid' => '101',
                'name' => 'ct101',
                'status' => 'running',
                'cpu_percent' => 75.0,
                'memory_percent' => 85.5,
                'disk_percent' => 50.0,
                'health_status' => 'warning',
            ],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->call('loadContainers')
            ->assertSet('loading', false);
    });

    test('loadContainers handles empty results', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->call('loadContainers')
            ->assertSet('loading', false);
    });
});

describe('ContainerGrid - Filtering by Server', function () {
    test('filterServer filters containers by server code', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'server_code' => 'aglsrv1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '200', 'name' => 'ct200', 'server_code' => 'aglsrv6', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('filterServer', 'aglsrv1')
            ->call('loadContainers')
            ->assertOk();
    });

    test('clearFilters resets server filter', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('filterServer', 'aglsrv1')
            ->call('clearFilters')
            ->assertSet('filterServer', null);
    });
});

describe('ContainerGrid - Filtering by Status', function () {
    test('filterStatus filters containers by running status', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'ct101', 'status' => 'stopped', 'cpu_percent' => 0, 'memory_percent' => 0, 'disk_percent' => 30, 'health_status' => 'offline'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('filterStatus', 'running')
            ->call('loadContainers')
            ->assertOk();
    });

    test('clearFilters resets status filter', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('filterStatus', 'running')
            ->call('clearFilters')
            ->assertSet('filterStatus', null);
    });
});

describe('ContainerGrid - Filtering by Usage', function () {
    test('filterUsage filters high usage containers', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 90, 'memory_percent' => 85, 'disk_percent' => 30, 'health_status' => 'critical'],
            ['vmid' => '101', 'name' => 'ct101', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('filterUsage', 'high')
            ->call('loadContainers')
            ->assertOk();
    });

    test('clearFilters resets usage filter', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('filterUsage', 'high')
            ->call('clearFilters')
            ->assertSet('filterUsage', null);
    });
});

describe('ContainerGrid - Search Functionality', function () {
    test('search filters containers by name', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'webserver', 'hostname' => 'web1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'database', 'hostname' => 'db1', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('search', 'web')
            ->call('loadContainers')
            ->assertOk();
    });

    test('search filters containers by hostname', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'webserver', 'hostname' => 'web1.aglz.io', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'database', 'hostname' => 'db1.aglz.io', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('search', 'web1')
            ->call('loadContainers')
            ->assertOk();
    });

    test('search is case insensitive', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'WebServer', 'hostname' => 'web1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('search', 'webserver')
            ->call('loadContainers')
            ->assertOk();
    });
});

describe('ContainerGrid - Sorting', function () {
    test('sorting by vmid ascending', function () {
        $mockMetrics = collect([
            ['vmid' => '200', 'name' => 'ct200', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('sortBy', 'vmid')
            ->set('sortDirection', 'asc')
            ->call('loadContainers')
            ->assertOk();
    });

    test('sorting by CPU usage descending', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'ct101', 'status' => 'running', 'cpu_percent' => 85, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'warning'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('sortBy', 'cpu_percent')
            ->set('sortDirection', 'desc')
            ->call('loadContainers')
            ->assertOk();
    });

    test('toggleSort changes sort direction', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('sortBy', 'vmid')
            ->set('sortDirection', 'asc')
            ->call('toggleSort', 'vmid')
            ->assertSet('sortDirection', 'desc')
            ->call('toggleSort', 'vmid')
            ->assertSet('sortDirection', 'asc');
    });

    test('toggleSort changes sort column', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('sortBy', 'vmid')
            ->call('toggleSort', 'cpu_percent')
            ->assertSet('sortBy', 'cpu_percent')
            ->assertSet('sortDirection', 'desc');
    });
});

describe('ContainerGrid - Pagination', function () {
    test('pagination shows correct number of items per page', function () {
        $mockMetrics = collect(
            array_map(fn ($i) => [
                'vmid' => (string) (100 + $i),
                'name' => "ct{$i}",
                'status' => 'running',
                'cpu_percent' => rand(10, 90),
                'memory_percent' => rand(20, 80),
                'disk_percent' => rand(15, 75),
                'health_status' => 'healthy',
            ], range(1, 100))
        );

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('perPage', 50)
            ->call('loadContainers')
            ->assertOk();
    });

    test('perPage can be changed', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->set('perPage', 50)
            ->assertSet('perPage', 50)
            ->set('perPage', 100)
            ->assertSet('perPage', 100);
    });
});

describe('ContainerGrid - Export Functionality', function () {
    test('exportMetrics dispatches download event', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->call('exportMetrics')
            ->assertDispatched('download-json');
    });

    test('exportMetrics includes all container data', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'ct101', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->call('exportMetrics')
            ->assertDispatched('download-json');
    });
});

describe('ContainerGrid - View Rendering', function () {
    test('renders container cards', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'hostname' => 'web1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->assertSee('ct100')
            ->assertSee('web1');
    });

    test('renders empty state when no containers', function () {
        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn(collect([]));

        Livewire::test(ContainerGrid::class)
            ->assertSee('No containers found');
    });

    test('renders health status badges', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'ct101', 'status' => 'running', 'cpu_percent' => 75, 'memory_percent' => 85, 'disk_percent' => 50, 'health_status' => 'warning'],
            ['vmid' => '102', 'name' => 'ct102', 'status' => 'running', 'cpu_percent' => 95, 'memory_percent' => 95, 'disk_percent' => 90, 'health_status' => 'critical'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->assertSee('healthy')
            ->assertSee('warning')
            ->assertSee('critical');
    });
});

describe('ContainerGrid - Multiple Filters Combined', function () {
    test('applies server and status filters together', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'ct100', 'server_code' => 'aglsrv1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
            ['vmid' => '101', 'name' => 'ct101', 'server_code' => 'aglsrv1', 'status' => 'stopped', 'cpu_percent' => 0, 'memory_percent' => 0, 'disk_percent' => 30, 'health_status' => 'offline'],
            ['vmid' => '200', 'name' => 'ct200', 'server_code' => 'aglsrv6', 'status' => 'running', 'cpu_percent' => 50, 'memory_percent' => 70, 'disk_percent' => 40, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('filterServer', 'aglsrv1')
            ->set('filterStatus', 'running')
            ->call('loadContainers')
            ->assertOk();
    });

    test('applies all filters and search together', function () {
        $mockMetrics = collect([
            ['vmid' => '100', 'name' => 'webserver', 'hostname' => 'web1', 'server_code' => 'aglsrv1', 'status' => 'running', 'cpu_percent' => 90, 'memory_percent' => 85, 'disk_percent' => 30, 'health_status' => 'critical'],
            ['vmid' => '101', 'name' => 'database', 'hostname' => 'db1', 'server_code' => 'aglsrv1', 'status' => 'running', 'cpu_percent' => 45, 'memory_percent' => 60, 'disk_percent' => 30, 'health_status' => 'healthy'],
        ]);

        $this->metricsCollector->shouldReceive('collectContainerMetrics')
            ->andReturn($mockMetrics);

        Livewire::test(ContainerGrid::class)
            ->set('filterServer', 'aglsrv1')
            ->set('filterStatus', 'running')
            ->set('filterUsage', 'high')
            ->set('search', 'web')
            ->call('loadContainers')
            ->assertOk();
    });
});
