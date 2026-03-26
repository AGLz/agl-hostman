<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Models\Alert;
use App\Models\DokployApplication;
use App\Models\DokployDeployment;
use App\Models\LxcContainer;
use App\Models\PerformanceTrend;
use App\Models\User;
use App\Services\DatabaseQueryOptimizer;
use Tests\TestCase;

/**
 * Database Query Optimizer Service Test
 *
 * Tests for the DatabaseQueryOptimizer class.
 */
class DatabaseQueryOptimizerTest extends TestCase
{
    private DatabaseQueryOptimizer $optimizer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->optimizer = new DatabaseQueryOptimizer;
    }

    /**
     * Test getting containers optimized
     */
    public function test_get_containers_optimized(): void
    {
        LxcContainer::factory()->create([
            'name' => 'test-container',
            'status' => 'running',
            'vmid' => '101',
        ]);

        $result = $this->optimizer->getContainersOptimized();

        $this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $result);
    }

    /**
     * Test getting containers with status filter
     */
    public function test_get_containers_with_status_filter(): void
    {
        LxcContainer::factory()->create([
            'name' => 'running-container',
            'status' => 'running',
            'vmid' => '101',
        ]);

        LxcContainer::factory()->create([
            'name' => 'stopped-container',
            'status' => 'stopped',
            'vmid' => '102',
        ]);

        $result = $this->optimizer->getContainersOptimized(['status' => 'running']);

        $this->assertCount(1, $result);
        $this->assertEquals('running', $result->first()->status);
    }

    /**
     * Test getting containers with server filter
     */
    public function test_get_containers_with_server_filter(): void
    {
        $server = \App\Models\ProxmoxServer::factory()->create();

        LxcContainer::factory()->create([
            'name' => 'test-container',
            'proxmox_server_id' => $server->id,
            'vmid' => '101',
        ]);

        $result = $this->optimizer->getContainersOptimized(['server_id' => $server->id]);

        $this->assertCount(1, $result);
        $this->assertEquals($server->id, $result->first()->proxmox_server_id);
    }

    /**
     * Test getting containers with search filter
     */
    public function test_get_containers_with_search_filter(): void
    {
        LxcContainer::factory()->create([
            'name' => 'production-container',
            'status' => 'running',
            'vmid' => '101',
        ]);

        LxcContainer::factory()->create([
            'name' => 'development-container',
            'status' => 'running',
            'vmid' => '102',
        ]);

        $result = $this->optimizer->getContainersOptimized(['search' => 'production']);

        $this->assertCount(1, $result);
        $this->assertStringContainsString('production', $result->first()->name);
    }

    /**
     * Test getting deployments optimized
     */
    public function test_get_deployments_optimized(): void
    {
        $application = DokployApplication::factory()->create();
        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'status' => 'success',
        ]);

        $result = $this->optimizer->getDeploymentsOptimized();

        $this->assertInstanceOf(\Illuminate\Contracts\Pagination\LengthAwarePaginator::class, $result);
    }

    /**
     * Test getting deployments with status filter
     */
    public function test_get_deployments_with_status_filter(): void
    {
        $application = DokployApplication::factory()->create();

        DokployDeployment::factory()->count(3)->create([
            'application_id' => $application->id,
            'status' => 'success',
        ]);

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'status' => 'failed',
        ]);

        $result = $this->optimizer->getDeploymentsOptimized(['status' => 'success']);

        $this->assertCount(3, $result);
    }

    /**
     * Test getting deployments with application filter
     */
    public function test_get_deployments_with_application_filter(): void
    {
        $app1 = DokployApplication::factory()->create();
        $app2 = DokployApplication::factory()->create();

        DokployDeployment::factory()->create([
            'application_id' => $app1->id,
            'status' => 'success',
        ]);

        DokployDeployment::factory()->create([
            'application_id' => $app2->id,
            'status' => 'success',
        ]);

        $result = $this->optimizer->getDeploymentsOptimized(['application_id' => $app1->id]);

        $this->assertCount(1, $result);
        $this->assertEquals($app1->id, $result->first()->application_id);
    }

    /**
     * Test getting deployments with branch filter
     */
    public function test_get_deployments_with_branch_filter(): void
    {
        $application = DokployApplication::factory()->create();

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'branch' => 'main',
            'status' => 'success',
        ]);

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'branch' => 'develop',
            'status' => 'success',
        ]);

        $result = $this->optimizer->getDeploymentsOptimized(['branch' => 'main']);

        $this->assertCount(1, $result);
        $this->assertEquals('main', $result->first()->branch);
    }

    /**
     * Test getting user with relationships
     */
    public function test_get_user_with_relationships(): void
    {
        $user = User::factory()->create();

        $result = $this->optimizer->getUserWithRelationships($user->id);

        $this->assertInstanceOf(User::class, $result);
        $this->assertEquals($user->id, $result->id);
        $this->assertTrue($result->relationLoaded('roles'));
        $this->assertTrue($result->relationLoaded('permissions'));
    }

    /**
     * Test getting non-existent user returns null
     */
    public function test_get_non_existent_user_returns_null(): void
    {
        $result = $this->optimizer->getUserWithRelationships(999);

        $this->assertNull($result);
    }

    /**
     * Test getting performance trends optimized
     */
    public function test_get_performance_trends_optimized(): void
    {
        PerformanceTrend::factory()->create([
            'resource_type' => 'container',
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'value' => 45.5,
            'unit' => '%',
            'recorded_at' => now()->subHours(1),
        ]);

        $result = $this->optimizer->getPerformanceTrendsOptimized('container', '101', 'cpu', 24);

        $this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $result);
        $this->assertCount(1, $result);
    }

    /**
     * Test getting alerts optimized
     */
    public function test_get_alerts_optimized(): void
    {
        Alert::factory()->create([
            'severity' => 'critical',
            'is_resolved' => false,
        ]);

        $result = $this->optimizer->getAlertsOptimized();

        $this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $result);
    }

    /**
     * Test getting alerts with severity filter
     */
    public function test_get_alerts_with_severity_filter(): void
    {
        Alert::factory()->create([
            'severity' => 'critical',
            'is_resolved' => false,
        ]);

        Alert::factory()->create([
            'severity' => 'low',
            'is_resolved' => false,
        ]);

        $result = $this->optimizer->getAlertsOptimized(['severity' => 'critical']);

        $this->assertCount(1, $result);
        $this->assertEquals('critical', $result->first()->severity);
    }

    /**
     * Test getting alerts with resolved filter
     */
    public function test_get_alerts_with_resolved_filter(): void
    {
        Alert::factory()->create([
            'severity' => 'critical',
            'is_resolved' => true,
        ]);

        Alert::factory()->create([
            'severity' => 'critical',
            'is_resolved' => false,
        ]);

        $result = $this->optimizer->getAlertsOptimized(['is_resolved' => true]);

        $this->assertCount(1, $result);
        $this->assertTrue($result->first()->is_resolved);
    }

    /**
     * Test getting container status counts
     */
    public function test_get_container_status_counts(): void
    {
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '101']);
        LxcContainer::factory()->create(['status' => 'running', 'vmid' => '102']);
        LxcContainer::factory()->create(['status' => 'stopped', 'vmid' => '103']);

        $result = $this->optimizer->getContainerStatusCounts();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('running', $result);
        $this->assertArrayHasKey('stopped', $result);
        $this->assertEquals(2, $result['running']);
        $this->assertEquals(1, $result['stopped']);
    }

    /**
     * Test getting deployment statistics
     */
    public function test_get_deployment_statistics(): void
    {
        $application = DokployApplication::factory()->create();

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'status' => 'success',
            'duration_seconds' => 120,
        ]);

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'status' => 'success',
            'duration_seconds' => 180,
        ]);

        DokployDeployment::factory()->create([
            'application_id' => $application->id,
            'status' => 'failed',
            'duration_seconds' => 60,
        ]);

        $result = $this->optimizer->getDeploymentStatistics(30);

        $this->assertIsArray($result);
        $this->assertArrayHasKey('total', $result);
        $this->assertArrayHasKey('successful', $result);
        $this->assertArrayHasKey('failed', $result);
        $this->assertArrayHasKey('success_rate', $result);
        $this->assertArrayHasKey('avg_duration_seconds', $result);
        $this->assertEquals(3, $result['total']);
        $this->assertEquals(2, $result['successful']);
        $this->assertEquals(1, $result['failed']);
        $this->assertEquals(66.67, $result['success_rate']);
    }

    /**
     * Test getting recent activity
     */
    public function test_get_recent_activity(): void
    {
        LxcContainer::factory()->create([
            'name' => 'recent-container',
            'vmid' => '101',
        ]);

        DokployDeployment::factory()->create([
            'title' => 'recent-deployment',
        ]);

        $result = $this->optimizer->getRecentActivity(50);

        $this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $result);
    }

    /**
     * Test upserting containers
     */
    public function test_upsert_containers(): void
    {
        $containers = [
            [
                'vmid' => '101',
                'name' => 'container-1',
                'hostname' => 'container-1.local',
                'status' => 'running',
                'cores' => 2,
                'memory_mb' => 2048,
                'disk_gb' => 20,
                'proxmox_server_id' => 1,
            ],
            [
                'vmid' => '102',
                'name' => 'container-2',
                'hostname' => 'container-2.local',
                'status' => 'running',
                'cores' => 4,
                'memory_mb' => 4096,
                'disk_gb' => 40,
                'proxmox_server_id' => 1,
            ],
        ];

        $result = $this->optimizer->upsertContainers($containers);

        $this->assertEquals(2, $result);
        $this->assertDatabaseHas('lxc_containers', ['vmid' => '101']);
        $this->assertDatabaseHas('lxc_containers', ['vmid' => '102']);
    }

    /**
     * Test upserting empty containers array
     */
    public function test_upsert_empty_containers(): void
    {
        $result = $this->optimizer->upsertContainers([]);

        $this->assertEquals(0, $result);
    }

    /**
     * Test chunked processing
     */
    public function test_chunked_processing(): void
    {
        LxcContainer::factory()->count(10)->create();

        $processed = [];
        $callback = function ($records) use (&$processed) {
            $processed = array_merge($processed, $records->toArray());
        };

        $this->optimizer->chunkedProcessing(
            LxcContainer::query(),
            5,
            $callback
        );

        $this->assertCount(10, $processed);
    }

    /**
     * Test getting containers by servers join
     */
    public function test_get_containers_by_servers_join(): void
    {
        $server = \App\Models\ProxmoxServer::factory()->create();

        LxcContainer::factory()->create([
            'name' => 'test-container',
            'proxmox_server_id' => $server->id,
            'vmid' => '101',
        ]);

        $result = $this->optimizer->getContainersByServersJoin([$server->id]);

        $this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $result);
        $this->assertCount(1, $result);
    }

    /**
     * Test getting aggregate metrics
     */
    public function test_get_aggregate_metrics(): void
    {
        PerformanceTrend::factory()->create([
            'resource_type' => 'container',
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'value' => 45.5,
            'unit' => '%',
            'recorded_at' => now()->subHours(1),
        ]);

        PerformanceTrend::factory()->create([
            'resource_type' => 'container',
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'value' => 55.5,
            'unit' => '%',
            'recorded_at' => now()->subHours(2),
        ]);

        $result = $this->optimizer->getAggregateMetrics('container', '101', 'cpu', 24);

        $this->assertIsArray($result);
        $this->assertArrayHasKey('min', $result);
        $this->assertArrayHasKey('max', $result);
        $this->assertArrayHasKey('avg', $result);
        $this->assertArrayHasKey('data_points', $result);
        $this->assertEquals(45.5, $result['min']);
        $this->assertEquals(55.5, $result['max']);
        $this->assertEquals(2, $result['data_points']);
    }

    /**
     * Test cursor pagination
     */
    public function test_cursor_paginate(): void
    {
        LxcContainer::factory()->count(20)->create();

        $result = $this->optimizer->cursorPaginate(
            LxcContainer::query()->select('id', 'name', 'vmid'),
            10
        );

        $this->assertIsArray($result);
        $this->assertArrayHasKey('data', $result);
        $this->assertArrayHasKey('next_cursor', $result);
        $this->assertArrayHasKey('has_more', $result);
        $this->assertCount(10, $result['data']);
        $this->assertTrue($result['has_more']);
    }

    /**
     * Test cursor pagination with next page
     */
    public function test_cursor_paginate_with_next_page(): void
    {
        $containers = LxcContainer::factory()->count(20)->create();
        $firstPageCursor = $containers->first()->id;

        $result = $this->optimizer->cursorPaginate(
            LxcContainer::query()->select('id', 'name', 'vmid'),
            10,
            $firstPageCursor
        );

        $this->assertCount(10, $result['data']);
        $this->assertTrue($result['has_more']);
    }

    /**
     * Test cursor pagination last page
     */
    public function test_cursor_paginate_last_page(): void
    {
        LxcContainer::factory()->count(5)->create();
        $firstId = LxcContainer::first()->id;

        $result = $this->optimizer->cursorPaginate(
            LxcContainer::query()->select('id', 'name', 'vmid'),
            10,
            $firstId
        );

        $this->assertLessThanOrEqual(5, count($result['data']));
        $this->assertFalse($result['has_more']);
        $this->assertNull($result['next_cursor']);
    }
}
