<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\Alert;
use App\Models\ContainerHealthLog;
use App\Models\LxcContainer;
use App\Models\PerformanceTrend;
use App\Models\ProxmoxServer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * LXC Container Model Test
 *
 * Tests for the LxcContainer model.
 */
class ContainerModelTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test creating a container
     */
    public function test_create_container(): void
    {
        $server = ProxmoxServer::factory()->create();
        $container = LxcContainer::factory()->create([
            'proxmox_server_id' => $server->id,
            'vmid' => '101',
            'name' => 'test-container',
        ]);

        $this->assertDatabaseHas('lxc_containers', [
            'id' => $container->id,
            'vmid' => '101',
            'name' => 'test-container',
            'proxmox_server_id' => $server->id,
        ]);
    }

    /**
     * Test container belongs to server
     */
    public function test_container_belongs_to_server(): void
    {
        $server = ProxmoxServer::factory()->create();
        $container = LxcContainer::factory()->create([
            'proxmox_server_id' => $server->id,
        ]);

        $this->assertInstanceOf(ProxmoxServer::class, $container->server);
        $this->assertEquals($server->id, $container->server->id);
    }

    /**
     * Test container has many health logs
     */
    public function test_container_has_many_health_logs(): void
    {
        $container = LxcContainer::factory()->create();
        ContainerHealthLog::factory()->count(3)->create([
            'container_id' => $container->id,
        ]);

        $this->assertCount(3, $container->healthLogs);
        $this->assertInstanceOf(ContainerHealthLog::class, $container->healthLogs->first());
    }

    /**
     * Test container has many performance trends
     */
    public function test_container_has_many_performance_trends(): void
    {
        $container = LxcContainer::factory()->create();
        PerformanceTrend::factory()->count(5)->create([
            'resource_type' => 'container',
            'resource_id' => $container->id,
        ]);

        $this->assertCount(5, $container->performanceTrends);
        $this->assertInstanceOf(PerformanceTrend::class, $container->performanceTrends->first());
    }

    /**
     * Test container has many alerts
     */
    public function test_container_has_many_alerts(): void
    {
        $container = LxcContainer::factory()->create();
        Alert::factory()->count(2)->create([
            'resource_type' => 'container',
            'resource_id' => $container->id,
        ]);

        $this->assertCount(2, $container->alerts);
        $this->assertInstanceOf(Alert::class, $container->alerts->first());
    }

    /**
     * Test network config casting
     */
    public function test_network_config_casting(): void
    {
        $networkConfig = [
            'ip_address' => '192.168.1.100',
            'gateway' => '192.168.1.1',
            'bridge' => 'vmbr0',
        ];

        $container = LxcContainer::factory()->create([
            'network_config' => $networkConfig,
        ]);

        $this->assertIsArray($container->network_config);
        $this->assertEquals('192.168.1.100', $container->network_config['ip_address']);
        $this->assertEquals('192.168.1.1', $container->network_config['gateway']);
        $this->assertEquals('vmbr0', $container->network_config['bridge']);
    }

    /**
     * Test metadata casting
     */
    public function test_metadata_casting(): void
    {
        $metadata = [
            'tags' => ['web', 'production'],
            'environment' => 'production',
            'owner' => 'team-a',
        ];

        $container = LxcContainer::factory()->create([
            'metadata' => $metadata,
        ]);

        $this->assertIsArray($container->metadata);
        $this->assertEquals('web', $container->metadata['tags'][0]);
        $this->assertEquals('production', $container->metadata['environment']);
    }

    /**
     * Test scope running
     */
    public function test_scope_running(): void
    {
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '101']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '102']);

        $running = LxcContainer::running()->get();

        $this->assertCount(1, $running);
        $this->assertEquals('running', $running->first()->status);
    }

    /**
     * Test scope stopped
     */
    public function test_scope_stopped(): void
    {
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '101']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '102']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '103']);

        $stopped = LxcContainer::stopped()->get();

        $this->assertCount(2, $stopped);
        $this->assertEquals('stopped', $stopped->first()->status);
    }

    /**
     * Test scope by server
     */
    public function test_scope_by_server(): void
    {
        $server1 = ProxmoxServer::factory()->create();
        $server2 = ProxmoxServer::factory()->create();

        LxcContainer::factory()->create(['proxmox_server_id' => $server1->id, 'vmid' => '101']);
        LxcContainer::factory()->create(['proxmox_server_id' => $server1->id, 'vmid' => '102']);
        LxcContainer::factory()->create(['proxmox_server_id' => $server2->id, 'vmid' => '103']);

        $server1Containers = LxcContainer::byServer($server1->id)->get();

        $this->assertCount(2, $server1Containers);
    }

    /**
     * Test scope with status
     */
    public function test_scope_with_status(): void
    {
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '101']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '102']);

        $running = LxcContainer::withStatus('running')->get();

        $this->assertCount(1, $running);
    }

    /**
     * Test scope active
     */
    public function test_scope_active(): void
    {
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '101']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '102']);

        $active = LxcContainer::active()->get();

        $this->assertCount(1, $active);
    }

    /**
     * Test resource identifier
     */
    public function test_resource_identifier(): void
    {
        $container = LxcContainer::factory()->create(['vmid' => '101']);

        $this->assertEquals('container:101', $container->resourceIdentifier());
    }

    /**
     * Test resource type
     */
    public function test_resource_type(): void
    {
        $container = LxcContainer::factory()->create();

        $this->assertEquals('container', $container->resourceType());
    }

    /**
     * Test is running method
     */
    public function test_is_running(): void
    {
        $runningContainer = LxcContainer::factory()->create(['status' => 'running']);
        $stoppedContainer = LxcContainer::factory()->create(['status' => 'stopped']);

        $this->assertTrue($runningContainer->isRunning());
        $this->assertFalse($stoppedContainer->isRunning());
    }

    /**
     * Test is stopped method
     */
    public function test_is_stopped(): void
    {
        $stoppedContainer = LxcContainer::factory()->create(['status' => 'stopped']);
        $runningContainer = LxcContainer::factory()->create(['status' => 'running']);

        $this->assertTrue($stoppedContainer->isStopped());
        $this->assertFalse($runningContainer->isStopped());
    }

    /**
     * Test memory in GB
     */
    public function test_memory_in_gb(): void
    {
        $container = LxcContainer::factory()->create(['memory_mb' => 2048]);

        $this->assertEquals(2.0, $container->memoryInGB());
    }

    /**
     * Test disk in GB
     */
    public function test_disk_in_gb(): void
    {
        $container = LxcContainer::factory()->create(['disk_gb' => 50]);

        $this->assertEquals(50, $container->diskInGB());
    }

    /**
     * Test cpu percentage
     */
    public function test_cpu_percentage(): void
    {
        $container = LxcContainer::factory()->create(['cpu_usage' => 0.45]);

        $this->assertEquals('45.00%', $container->cpuPercentage());
    }

    /**
     * Test memory percentage
     */
    public function test_memory_percentage(): void
    {
        $container = LxcContainer::factory()->create([
            'memory_mb' => 2048,
            'memory_usage_mb' => 1024,
        ]);

        $this->assertEquals('50.00%', $container->memoryPercentage());
    }

    /**
     * Test disk percentage
     */
    public function test_disk_percentage(): void
    {
        $container = LxcContainer::factory()->create([
            'disk_gb' => 100,
            'disk_usage_gb' => 75,
        ]);

        $this->assertEquals('75.00%', $container->diskPercentage());
    }

    /**
     * Test search scope
     */
    public function test_search_scope(): void
    {
        LxcContainer::factory()->create([
            'name' => 'production-web',
            'hostname' => 'web-01.example.com',
            'vmid' => '101',
        ]);

        LxcContainer::factory()->create([
            'name' => 'development-db',
            'hostname' => 'db-01.example.com',
            'vmid' => '102',
        ]);

        $results = LxcContainer::search('production')->get();

        $this->assertCount(1, $results);
        $this->assertStringContainsString('production', $results->first()->name);
    }

    /**
     * Test fillable attributes
     */
    public function test_fillable_attributes(): void
    {
        $container = new LxcContainer;

        $expectedFillable = [
            'vmid',
            'name',
            'hostname',
            'description',
            'status',
            'cores',
            'memory_mb',
            'disk_gb',
            'network_config',
            'metadata',
            'proxmox_server_id',
            'cpu_usage',
            'memory_usage_mb',
            'disk_usage_gb',
            'network_in_mb',
            'network_out_mb',
            'last_backup_at',
            'last_health_check_at',
        ];

        $this->assertEquals($expectedFillable, $container->getFillable());
    }

    /**
     * Test casts configuration
     */
    public function test_casts_configuration(): void
    {
        $container = new LxcContainer;

        $expectedCasts = [
            'network_config' => 'array',
            'metadata' => 'array',
            'last_backup_at' => 'datetime',
            'last_health_check_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];

        $this->assertEquals($expectedCasts, $container->getCasts());
    }
}
