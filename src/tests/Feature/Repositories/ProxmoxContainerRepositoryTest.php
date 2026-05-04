<?php

namespace Tests\Feature\Repositories;

use App\DTOs\ContainerMetrics;
use App\DTOs\ProxmoxApiResponse;
use App\Repositories\ProxmoxContainerRepository;
use App\Services\FlexibleCacheService;
use App\Services\ProxmoxApiClient;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class ProxmoxContainerRepositoryTest extends TestCase
{
    protected ProxmoxContainerRepository $repository;

    protected $mockApiClient;

    protected $mockCacheService;

    protected function setUp(): void
    {
        parent::setUp();

        $this->mockApiClient = Mockery::mock(ProxmoxApiClient::class);
        $this->mockCacheService = Mockery::mock(FlexibleCacheService::class);

        $this->repository = new ProxmoxContainerRepository(
            $this->mockApiClient,
            $this->mockCacheService
        );
    }

    protected function tearDown(): void
    {
        Mockery::close();
        parent::tearDown();
    }

    /**
     * Test getAllContainers returns collection of ContainerMetrics
     */
    public function test_get_all_containers_returns_collection(): void
    {
        $mockData = [
            [
                'vmid' => 179,
                'name' => 'agldv03',
                'status' => 'running',
                'cpu' => 0.5,
                'mem' => 50000,
                'maxmem' => 100000,
                'disk' => 10000,
                'maxdisk' => 50000,
                'uptime' => 1000,
            ],
            [
                'vmid' => 180,
                'name' => 'dokploy',
                'status' => 'running',
                'cpu' => 0.3,
                'mem' => 30000,
                'maxmem' => 100000,
                'disk' => 8000,
                'maxdisk' => 50000,
                'uptime' => 2000,
            ],
        ];

        $this->mockCacheService
            ->shouldReceive('cacheContainerList')
            ->once()
            ->andReturn($mockData);

        $containers = $this->repository->getAllContainers('pve1');

        $this->assertCount(2, $containers);
        $this->assertInstanceOf(ContainerMetrics::class, $containers->first());
        $this->assertEquals(179, $containers->first()->vmid);
        $this->assertEquals('agldv03', $containers->first()->name);
    }

    /**
     * Test getRunningContainers filters by status
     */
    public function test_get_running_containers_filters_by_status(): void
    {
        $mockData = [
            [
                'vmid' => 179,
                'name' => 'agldv03',
                'status' => 'running',
                'cpu' => 0.5,
                'mem' => 50000,
                'maxmem' => 100000,
                'disk' => 10000,
                'maxdisk' => 50000,
                'uptime' => 1000,
            ],
            [
                'vmid' => 180,
                'name' => 'stopped-container',
                'status' => 'stopped',
                'cpu' => 0,
                'mem' => 0,
                'maxmem' => 100000,
                'disk' => 8000,
                'maxdisk' => 50000,
                'uptime' => 0,
            ],
        ];

        $this->mockCacheService
            ->shouldReceive('cacheContainerList')
            ->once()
            ->andReturn($mockData);

        $containers = $this->repository->getRunningContainers('pve1');

        $this->assertCount(1, $containers);
        $this->assertEquals(179, $containers->first()->vmid);
        $this->assertTrue($containers->first()->isRunning());
    }

    /**
     * Test getCriticalContainers filters by health status
     */
    public function test_get_critical_containers_filters_by_health(): void
    {
        $mockData = [
            [
                'vmid' => 179,
                'name' => 'healthy-container',
                'status' => 'running',
                'cpu' => 0.5,
                'mem' => 50000,
                'maxmem' => 100000,
                'disk' => 10000,
                'maxdisk' => 50000,
                'uptime' => 1000,
            ],
            [
                'vmid' => 180,
                'name' => 'critical-container',
                'status' => 'running',
                'cpu' => 0.95,  // Critical CPU
                'mem' => 87000,  // Critical memory
                'maxmem' => 100000,
                'disk' => 42000,  // Critical disk
                'maxdisk' => 50000,
                'uptime' => 2000,
            ],
        ];

        $this->mockCacheService
            ->shouldReceive('cacheContainerList')
            ->once()
            ->andReturn($mockData);

        $containers = $this->repository->getCriticalContainers('pve1');

        $this->assertCount(1, $containers);
        $this->assertEquals(180, $containers->first()->vmid);
        $this->assertEquals('critical', $containers->first()->getHealthStatus());
    }

    /**
     * Test getContainer returns single ContainerMetrics
     */
    public function test_get_container_returns_single_metrics(): void
    {
        $mockData = [
            'vmid' => 179,
            'name' => 'agldv03',
            'status' => 'running',
            'cpu' => 0.5,
            'mem' => 50000,
            'maxmem' => 100000,
            'disk' => 10000,
            'maxdisk' => 50000,
            'uptime' => 1000,
        ];

        $this->mockCacheService
            ->shouldReceive('cacheServerStatus')
            ->once()
            ->andReturn($mockData);

        $container = $this->repository->getContainer('pve1', 179);

        $this->assertInstanceOf(ContainerMetrics::class, $container);
        $this->assertEquals(179, $container->vmid);
        $this->assertEquals('agldv03', $container->name);
    }

    /**
     * Test getContainer returns null when not found
     */
    public function test_get_container_returns_null_when_not_found(): void
    {
        $this->mockCacheService
            ->shouldReceive('cacheServerStatus')
            ->once()
            ->andReturn(null);

        $container = $this->repository->getContainer('pve1', 999);

        $this->assertNull($container);
    }

    /**
     * Test getNodeStatistics calculates correct statistics
     */
    public function test_get_node_statistics_calculates_correctly(): void
    {
        $mockData = [
            [
                'vmid' => 179,
                'name' => 'container1',
                'status' => 'running',
                'cpu' => 0.5,
                'mem' => 50000,
                'maxmem' => 100000,
                'disk' => 10000,
                'maxdisk' => 50000,
                'uptime' => 1000,
            ],
            [
                'vmid' => 180,
                'name' => 'container2',
                'status' => 'running',
                'cpu' => 0.7,
                'mem' => 70000,
                'maxmem' => 100000,
                'disk' => 15000,
                'maxdisk' => 50000,
                'uptime' => 2000,
            ],
            [
                'vmid' => 181,
                'name' => 'container3',
                'status' => 'stopped',
                'cpu' => 0,
                'mem' => 0,
                'maxmem' => 100000,
                'disk' => 5000,
                'maxdisk' => 50000,
                'uptime' => 0,
            ],
        ];

        $this->mockCacheService
            ->shouldReceive('cacheContainerList')
            ->once()
            ->andReturn($mockData);

        $stats = $this->repository->getNodeStatistics('pve1');

        $this->assertEquals(3, $stats['total_containers']);
        $this->assertEquals(2, $stats['running_containers']);
        $this->assertEquals(0, $stats['critical_containers']);
        $this->assertEquals(40.0, $stats['avg_cpu_usage']); // (50 + 70 + 0) / 3
        $this->assertEquals(40.0, $stats['avg_memory_usage_percent']); // (50 + 70 + 0) / 3
    }

    /**
     * Test startContainer invalidates cache
     */
    public function test_start_container_invalidates_cache(): void
    {
        $mockResponse = new ProxmoxApiResponse(
            success: true,
            data: ['status' => 'running'],
            statusCode: 200
        );

        $this->mockApiClient
            ->shouldReceive('startContainer')
            ->once()
            ->with('pve1', 179)
            ->andReturn($mockResponse);

        Cache::shouldReceive('forget')
            ->once()
            ->with('container_list:pve1');

        Cache::shouldReceive('forget')
            ->once()
            ->with('container:pve1:179');

        $response = $this->repository->startContainer('pve1', 179);

        $this->assertTrue($response->isSuccess());
    }

    /**
     * Test stopContainer invalidates cache
     */
    public function test_stop_container_invalidates_cache(): void
    {
        $mockResponse = new ProxmoxApiResponse(
            success: true,
            data: ['status' => 'stopped'],
            statusCode: 200
        );

        $this->mockApiClient
            ->shouldReceive('stopContainer')
            ->once()
            ->with('pve1', 179)
            ->andReturn($mockResponse);

        Cache::shouldReceive('forget')
            ->once()
            ->with('container_list:pve1');

        Cache::shouldReceive('forget')
            ->once()
            ->with('container:pve1:179');

        $response = $this->repository->stopContainer('pve1', 179);

        $this->assertTrue($response->isSuccess());
    }

    /**
     * Test getClusterStatistics aggregates across nodes
     */
    public function test_get_cluster_statistics_aggregates_nodes(): void
    {
        $mockNodes = [
            'pve1' => [
                [
                    'vmid' => 179,
                    'name' => 'container1',
                    'status' => 'running',
                    'cpu' => 0.5,
                    'mem' => 50000,
                    'maxmem' => 100000,
                    'disk' => 10000,
                    'maxdisk' => 50000,
                    'uptime' => 1000,
                ],
            ],
            'pve2' => [
                [
                    'vmid' => 200,
                    'name' => 'container2',
                    'status' => 'running',
                    'cpu' => 0.7,
                    'mem' => 70000,
                    'maxmem' => 100000,
                    'disk' => 15000,
                    'maxdisk' => 50000,
                    'uptime' => 2000,
                ],
            ],
        ];

        foreach ($mockNodes as $node => $containers) {
            $this->mockCacheService
                ->shouldReceive('cacheContainerList')
                ->with($node, Mockery::any())
                ->andReturn($containers);
        }

        $stats = $this->repository->getClusterStatistics(['pve1', 'pve2']);

        $this->assertEquals(2, $stats['total_containers']);
        $this->assertEquals(2, $stats['running_containers']);
        $this->assertEquals(0, $stats['critical_containers']);
    }
}
