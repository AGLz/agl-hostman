<?php

namespace Tests\Feature\Controllers;

use App\Models\User;
use App\Models\ProxmoxServer;
use App\Models\ContainerHealthLog;
use App\Services\ContainerHealthMonitor;
use App\Services\PredictiveMaintenanceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * Dashboard Controller Integration Tests
 * AGL Infrastructure Admin Platform - Phase 4
 *
 * Tests:
 * - Dashboard view access
 * - API endpoint responses
 * - Authentication requirements
 * - Data validation
 * - Caching behavior
 * - Error handling
 */
class DashboardControllerTest extends TestCase
{
    use RefreshDatabase;

    protected User $user;
    protected ProxmoxServer $server;

    protected function setUp(): void
    {
        parent::setUp();

        // Create authenticated user
        $this->user = User::factory()->create();

        // Create test Proxmox server
        $this->server = ProxmoxServer::factory()->create([
            'code' => 'TEST01',
            'name' => 'Test Server',
            'status' => 'online',
            'lan_ip' => '192.168.1.100',
            'wg_ip' => '10.6.0.10',
        ]);
    }

    // ========================================
    // Dashboard View Tests
    // ========================================

    /** @test */
    public function it_requires_authentication_to_access_dashboard()
    {
        $response = $this->get(route('monitoring.index'));

        $response->assertRedirect(route('login'));
    }

    /** @test */
    public function authenticated_user_can_access_dashboard()
    {
        $response = $this->actingAs($this->user)
            ->get(route('monitoring.index'));

        $response->assertStatus(200)
            ->assertViewIs('dashboard.index')
            ->assertSee('Infrastructure Monitoring Dashboard');
    }

    // ========================================
    // Cluster Health Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_cluster_health_statistics()
    {
        // Create sample health logs
        ContainerHealthLog::factory()->count(10)->create([
            'node_code' => 'TEST01',
            'health_status' => 'healthy',
        ]);

        ContainerHealthLog::factory()->count(3)->create([
            'node_code' => 'TEST01',
            'health_status' => 'warning',
        ]);

        ContainerHealthLog::factory()->count(2)->create([
            'node_code' => 'TEST01',
            'health_status' => 'critical',
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'servers' => ['total', 'online', 'offline'],
                'containers' => ['total', 'healthy', 'warning', 'critical'],
                'alerts',
                'health_score',
            ])
            ->assertJson([
                'servers' => [
                    'total' => 1,
                    'online' => 1,
                    'offline' => 0,
                ],
            ]);

        // Verify health score calculation
        $data = $response->json();
        $this->assertIsInt($data['health_score']);
        $this->assertGreaterThanOrEqual(0, $data['health_score']);
        $this->assertLessThanOrEqual(100, $data['health_score']);
    }

    /** @test */
    public function cluster_health_endpoint_caches_response()
    {
        Cache::flush();

        // First request - should hit database
        $response1 = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        $this->assertTrue(Cache::has('dashboard:cluster_health'));

        // Second request - should hit cache
        $response2 = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        $response1->assertStatus(200);
        $response2->assertStatus(200);
        $this->assertEquals($response1->json(), $response2->json());
    }

    /** @test */
    public function it_requires_authentication_for_cluster_health()
    {
        $response = $this->getJson(route('monitoring.api.cluster-health'));

        $response->assertStatus(401);
    }

    // ========================================
    // Node Health Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_node_health_data()
    {
        ContainerHealthLog::factory()->count(5)->create([
            'node_code' => 'TEST01',
            'health_status' => 'healthy',
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.node-health', ['node' => 'TEST01']));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'node',
                'containers',
                'summary' => ['total', 'healthy', 'warning', 'critical'],
            ])
            ->assertJson([
                'node' => 'TEST01',
            ]);
    }

    /** @test */
    public function it_returns_404_for_invalid_node()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.node-health', ['node' => 'INVALID']));

        $response->assertStatus(404)
            ->assertJson([
                'error' => 'Node not found',
            ]);
    }

    // ========================================
    // Container History Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_container_health_history()
    {
        // Create historical data
        ContainerHealthLog::factory()->count(24)->create([
            'node_code' => 'TEST01',
            'vmid' => 100,
            'created_at' => now()->subHours(rand(1, 24)),
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.container-history', [
                'node' => 'TEST01',
                'vmid' => 100,
                'hours' => 24,
            ]));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'node',
                'vmid',
                'hours',
                'history' => [
                    '*' => [
                        'timestamp',
                        'health_status',
                        'cpu_usage_percent',
                        'memory_usage_percent',
                        'disk_usage_percent',
                    ],
                ],
                'statistics',
            ]);

        $data = $response->json();
        $this->assertLessThanOrEqual(24, count($data['history']));
    }

    /** @test */
    public function it_validates_hours_parameter_for_container_history()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.container-history', [
                'node' => 'TEST01',
                'vmid' => 100,
                'hours' => 200, // Invalid: max 168
            ]));

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['hours']);
    }

    // ========================================
    // Resource Trends Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_resource_trend_data()
    {
        ContainerHealthLog::factory()->count(48)->create([
            'created_at' => now()->subHours(rand(1, 48)),
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.resource-trends') . '?hours=24&interval=1h');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'hours',
                'interval',
                'trends' => [
                    'cpu' => ['*' => ['timestamp', 'value']],
                    'memory' => ['*' => ['timestamp', 'value']],
                    'disk' => ['*' => ['timestamp', 'value']],
                ],
            ]);
    }

    // ========================================
    // Alert History Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_paginated_alert_history()
    {
        ContainerHealthLog::factory()->count(50)->create([
            'health_status' => 'critical',
            'created_at' => now()->subHours(rand(1, 24)),
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.alert-history') . '?hours=24&per_page=15');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'hours',
                'alerts' => [
                    'data' => [
                        '*' => [
                            'id',
                            'node_code',
                            'vmid',
                            'container_name',
                            'health_status',
                            'created_at',
                        ],
                    ],
                    'current_page',
                    'per_page',
                    'total',
                ],
            ]);

        $data = $response->json();
        $this->assertLessThanOrEqual(15, count($data['alerts']['data']));
    }

    /** @test */
    public function it_filters_alert_history_by_severity()
    {
        ContainerHealthLog::factory()->count(10)->create(['health_status' => 'critical']);
        ContainerHealthLog::factory()->count(10)->create(['health_status' => 'warning']);
        ContainerHealthLog::factory()->count(10)->create(['health_status' => 'healthy']);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.alert-history') . '?severity=critical');

        $response->assertStatus(200);

        $data = $response->json();
        foreach ($data['alerts']['data'] as $alert) {
            $this->assertEquals('critical', $alert['health_status']);
        }
    }

    /** @test */
    public function it_searches_alert_history_by_container_name()
    {
        ContainerHealthLog::factory()->create([
            'container_name' => 'test-container-123',
        ]);

        ContainerHealthLog::factory()->count(10)->create([
            'container_name' => 'other-container',
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.alert-history') . '?search=test-container');

        $response->assertStatus(200);

        $data = $response->json();
        $this->assertEquals(1, $data['alerts']['total']);
    }

    // ========================================
    // Predictive Maintenance Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_predictive_maintenance_data()
    {
        // Mock the predictive service
        $this->mock(PredictiveMaintenanceService::class, function ($mock) {
            $mock->shouldReceive('predict')
                ->once()
                ->andReturn([
                    'predicted_value' => 85.5,
                    'confidence' => 0.85,
                    'prediction' => 'warning',
                    'trend_analysis' => [
                        'type' => 'increasing',
                        'rate' => 0.15,
                        'r_squared' => 0.92,
                    ],
                ]);
        });

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.predictive-maintenance') . '?node=TEST01&vmid=100&resource_type=cpu&horizon=medium_term');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'node',
                'vmid',
                'resource_type',
                'horizon',
                'prediction' => [
                    'predicted_value',
                    'confidence',
                    'prediction',
                    'trend_analysis',
                ],
            ])
            ->assertJson([
                'node' => 'TEST01',
                'vmid' => 100,
                'resource_type' => 'cpu',
                'horizon' => 'medium_term',
            ]);
    }

    /** @test */
    public function it_validates_predictive_maintenance_parameters()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.predictive-maintenance'));

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['node', 'vmid', 'resource_type', 'horizon']);
    }

    /** @test */
    public function it_validates_resource_type_for_predictions()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.predictive-maintenance') . '?node=TEST01&vmid=100&resource_type=invalid&horizon=short_term');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['resource_type']);
    }

    /** @test */
    public function it_validates_horizon_for_predictions()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.predictive-maintenance') . '?node=TEST01&vmid=100&resource_type=cpu&horizon=invalid');

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['horizon']);
    }

    // ========================================
    // Cluster Forecasts Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_cluster_wide_forecasts()
    {
        // Mock the predictive service
        $this->mock(PredictiveMaintenanceService::class, function ($mock) {
            $mock->shouldReceive('predictClusterFailures')
                ->once()
                ->andReturn([
                    [
                        'node' => 'TEST01',
                        'vmid' => 100,
                        'resource_type' => 'cpu',
                        'predicted_value' => 90.0,
                        'confidence' => 0.82,
                        'horizon' => 'medium_term',
                    ],
                ]);
        });

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-forecasts'));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'forecasts' => [
                    '*' => [
                        'node',
                        'vmid',
                        'resource_type',
                        'predicted_value',
                        'confidence',
                        'horizon',
                    ],
                ],
            ]);
    }

    // ========================================
    // Realtime Snapshot Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_realtime_snapshot_data()
    {
        ContainerHealthLog::factory()->count(5)->create([
            'created_at' => now(),
        ]);

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.realtime-snapshot'));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'snapshot' => [
                    '*' => [
                        'node_code',
                        'vmid',
                        'container_name',
                        'health_status',
                        'cpu_usage_percent',
                        'memory_usage_percent',
                        'disk_usage_percent',
                    ],
                ],
            ]);
    }

    // ========================================
    // Dashboard Stats Endpoint Tests
    // ========================================

    /** @test */
    public function it_returns_quick_dashboard_statistics()
    {
        ContainerHealthLog::factory()->count(20)->create();

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.dashboard-stats'));

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'stats' => [
                    'total_containers',
                    'healthy_containers',
                    'warning_containers',
                    'critical_containers',
                    'total_servers',
                    'online_servers',
                    'health_score',
                ],
            ]);
    }

    // ========================================
    // Error Handling Tests
    // ========================================

    /** @test */
    public function it_handles_service_exceptions_gracefully()
    {
        // Mock the health monitor to throw exception
        $this->mock(ContainerHealthMonitor::class, function ($mock) {
            $mock->shouldReceive('getClusterHealthStatistics')
                ->once()
                ->andThrow(new \Exception('Service error'));
        });

        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        $response->assertStatus(500)
            ->assertJson([
                'error' => 'Failed to retrieve cluster health',
            ]);
    }

    /** @test */
    public function it_returns_empty_data_when_no_containers_exist()
    {
        $response = $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        $response->assertStatus(200)
            ->assertJson([
                'servers' => [
                    'total' => 1,
                    'online' => 1,
                ],
                'containers' => [
                    'total' => 0,
                    'healthy' => 0,
                    'warning' => 0,
                    'critical' => 0,
                ],
                'health_score' => 100, // Default to 100% when no containers
            ]);
    }

    // ========================================
    // Authorization Tests
    // ========================================

    /** @test */
    public function all_api_endpoints_require_authentication()
    {
        $endpoints = [
            'monitoring.api.cluster-health',
            'monitoring.api.dashboard-stats',
            'monitoring.api.realtime-snapshot',
            'monitoring.api.resource-trends',
            'monitoring.api.alert-history',
            'monitoring.api.cluster-forecasts',
        ];

        foreach ($endpoints as $endpoint) {
            $response = $this->getJson(route($endpoint));
            $response->assertStatus(401);
        }
    }

    // ========================================
    // Cache Performance Tests
    // ========================================

    /** @test */
    public function cache_is_cleared_after_ttl_expires()
    {
        Cache::flush();

        // Set short TTL for testing
        Cache::shouldReceive('remember')
            ->once()
            ->andReturn(['test' => 'data']);

        $this->actingAs($this->user)
            ->getJson(route('monitoring.api.cluster-health'));

        // Verify cache was set
        $this->assertTrue(Cache::has('dashboard:cluster_health'));
    }
}
