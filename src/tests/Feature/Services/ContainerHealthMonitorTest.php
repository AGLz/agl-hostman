<?php

namespace Tests\Feature\Services;

use App\Services\ContainerHealthMonitor;
use App\Services\PredictiveMaintenanceService;
use App\Services\AlertDispatcher;
use App\Repositories\ProxmoxContainerRepository;
use App\DTOs\ContainerMetrics;
use App\Models\ContainerHealthLog;
use App\Models\PerformanceTrend;
use App\Events\ContainerCritical;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;
use Mockery;

class ContainerHealthMonitorTest extends TestCase
{
    protected ContainerHealthMonitor $monitor;
    protected $mockRepository;
    protected $mockPredictive;
    protected $mockAlertDispatcher;

    protected function setUp(): void
    {
        parent::setUp();

        $this->mockRepository = Mockery::mock(ProxmoxContainerRepository::class);
        $this->mockPredictive = Mockery::mock(PredictiveMaintenanceService::class);
        $this->mockAlertDispatcher = Mockery::mock(AlertDispatcher::class);

        $this->monitor = new ContainerHealthMonitor(
            $this->mockRepository,
            $this->mockPredictive,
            $this->mockAlertDispatcher
        );
    }

    protected function tearDown(): void
    {
        Mockery::close();
        parent::tearDown();
    }

    /**
     * Test monitoring single node returns proper structure
     */
    public function test_monitor_node_returns_proper_structure(): void
    {
        $mockContainers = collect([
            ContainerMetrics::fromProxmoxResponse([
                'vmid' => 179,
                'name' => 'agldv03',
                'status' => 'running',
                'cpu' => 0.5,
                'mem' => 50000,
                'maxmem' => 100000,
                'disk' => 10000,
                'maxdisk' => 50000,
                'uptime' => 1000,
            ]),
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->once()
            ->with('pve1')
            ->andReturn($mockContainers);

        $results = $this->monitor->monitorNode('pve1');

        $this->assertArrayHasKey('node', $results);
        $this->assertArrayHasKey('total_containers', $results);
        $this->assertArrayHasKey('healthy', $results);
        $this->assertArrayHasKey('warning', $results);
        $this->assertArrayHasKey('critical', $results);
        $this->assertArrayHasKey('containers', $results);
        $this->assertEquals('pve1', $results['node']);
        $this->assertEquals(1, $results['total_containers']);
    }

    /**
     * Test critical container triggers alert
     */
    public function test_critical_container_triggers_alert(): void
    {
        Event::fake([ContainerCritical::class]);

        $criticalContainer = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 180,
            'name' => 'critical-container',
            'status' => 'running',
            'cpu' => 0.95,   // Critical CPU
            'mem' => 87000,  // Critical memory
            'maxmem' => 100000,
            'disk' => 42000,  // Critical disk
            'maxdisk' => 50000,
            'uptime' => 2000,
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->once()
            ->andReturn(collect([$criticalContainer]));

        $this->mockAlertDispatcher
            ->shouldReceive('dispatch')
            ->once()
            ->with('container_critical', Mockery::any(), 'critical')
            ->andReturn([]);

        $results = $this->monitor->monitorNode('pve1');

        $this->assertEquals(1, $results['critical']);
        $this->assertGreaterThan(0, $results['alerts_triggered']);

        Event::assertDispatched(ContainerCritical::class);
    }

    /**
     * Test monitoring multiple nodes aggregates correctly
     */
    public function test_monitor_nodes_aggregates_correctly(): void
    {
        $healthyContainer = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 179,
            'name' => 'healthy',
            'status' => 'running',
            'cpu' => 0.3,
            'mem' => 30000,
            'maxmem' => 100000,
            'disk' => 10000,
            'maxdisk' => 50000,
            'uptime' => 5000,
        ]);

        $warningContainer = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 180,
            'name' => 'warning',
            'status' => 'running',
            'cpu' => 0.75,  // Warning level
            'mem' => 72000, // Warning level
            'maxmem' => 100000,
            'disk' => 15000,
            'maxdisk' => 50000,
            'uptime' => 3000,
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->with('pve1')
            ->andReturn(collect([$healthyContainer]));

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->with('pve2')
            ->andReturn(collect([$warningContainer]));

        $this->mockAlertDispatcher
            ->shouldReceive('dispatch')
            ->zeroOrMoreTimes();

        $results = $this->monitor->monitorNodes(['pve1', 'pve2']);

        $this->assertEquals(2, $results['summary']['total_containers']);
        $this->assertEquals(1, $results['summary']['healthy']);
        $this->assertEquals(1, $results['summary']['warning']);
        $this->assertEquals(0, $results['summary']['critical']);
    }

    /**
     * Test health logs are created
     */
    public function test_health_logs_are_created(): void
    {
        $container = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 179,
            'name' => 'test-container',
            'status' => 'running',
            'cpu' => 0.5,
            'mem' => 50000,
            'maxmem' => 100000,
            'disk' => 10000,
            'maxdisk' => 50000,
            'uptime' => 1000,
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->once()
            ->andReturn(collect([$container]));

        $this->monitor->monitorNode('pve1');

        $this->assertDatabaseHas('container_health_logs', [
            'node_code' => 'pve1',
            'vmid' => 179,
            'container_name' => 'test-container',
        ]);
    }

    /**
     * Test monitoring snapshot is stored
     */
    public function test_monitoring_snapshot_is_stored(): void
    {
        $container = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 179,
            'name' => 'test',
            'status' => 'running',
            'cpu' => 0.5,
            'mem' => 50000,
            'maxmem' => 100000,
            'disk' => 10000,
            'maxdisk' => 50000,
            'uptime' => 1000,
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->once()
            ->andReturn(collect([$container]));

        $this->monitor->monitorNodes(['pve1']);

        $snapshot = $this->monitor->getLatestSnapshot();

        $this->assertNotNull($snapshot);
        $this->assertArrayHasKey('summary', $snapshot);
        $this->assertArrayHasKey('nodes', $snapshot);
    }

    /**
     * Test rate limiting prevents alert spam
     */
    public function test_rate_limiting_prevents_alert_spam(): void
    {
        Event::fake([ContainerCritical::class]);

        $criticalContainer = ContainerMetrics::fromProxmoxResponse([
            'vmid' => 180,
            'name' => 'critical',
            'status' => 'running',
            'cpu' => 0.95,
            'mem' => 87000,
            'maxmem' => 100000,
            'disk' => 42000,
            'maxdisk' => 50000,
            'uptime' => 2000,
        ]);

        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->twice()
            ->andReturn(collect([$criticalContainer]));

        // First monitoring - should trigger alert
        $this->mockAlertDispatcher
            ->shouldReceive('dispatch')
            ->once()
            ->andReturn([]);

        $this->monitor->monitorNode('pve1');

        // Second monitoring immediately after - should NOT trigger alert (rate limited)
        $this->monitor->monitorNode('pve1');

        // Only one alert should have been triggered
        Event::assertDispatched(ContainerCritical::class, function ($event) {
            return $event->vmid === 180;
        });
    }

    /**
     * Test container history retrieval
     */
    public function test_get_container_history(): void
    {
        // Create sample health logs
        ContainerHealthLog::create([
            'node_code' => 'pve1',
            'vmid' => 179,
            'container_name' => 'test',
            'health_status' => 'healthy',
            'cpu_usage_percent' => 50.0,
            'memory_usage_percent' => 60.0,
            'disk_usage_percent' => 30.0,
            'uptime_seconds' => 1000,
        ]);

        $history = $this->monitor->getContainerHistory('pve1', 179, 24);

        $this->assertGreaterThan(0, $history->count());
        $this->assertEquals('pve1', $history->first()->node_code);
        $this->assertEquals(179, $history->first()->vmid);
    }

    /**
     * Test cluster health statistics
     */
    public function test_get_cluster_health_statistics(): void
    {
        // Create sample data
        ContainerHealthLog::create([
            'node_code' => 'pve1',
            'vmid' => 179,
            'container_name' => 'test1',
            'health_status' => 'critical',
            'cpu_usage_percent' => 95.0,
            'memory_usage_percent' => 90.0,
            'disk_usage_percent' => 85.0,
            'uptime_seconds' => 1000,
            'issues' => ['High CPU usage'],
        ]);

        Cache::put('latest_monitoring_snapshot', [
            'summary' => [
                'total_containers' => 10,
                'healthy' => 7,
                'warning' => 2,
                'critical' => 1,
            ],
        ], now()->addHour());

        $stats = $this->monitor->getClusterHealthStatistics();

        $this->assertArrayHasKey('current', $stats);
        $this->assertArrayHasKey('alerts_last_24h', $stats);
        $this->assertArrayHasKey('critical_incidents', $stats);
        $this->assertGreaterThan(0, $stats['critical_incidents']);
    }

    /**
     * Test error handling for unavailable node
     */
    public function test_error_handling_for_unavailable_node(): void
    {
        $this->mockRepository
            ->shouldReceive('getAllContainers')
            ->once()
            ->andThrow(new \Exception('Node unreachable'));

        $results = $this->monitor->monitorNode('pve1');

        $this->assertArrayHasKey('error', $results);
        $this->assertEquals('pve1', $results['node']);
    }
}
