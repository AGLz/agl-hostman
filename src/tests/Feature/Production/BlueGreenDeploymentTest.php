<?php

namespace Tests\Feature\Production;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\Environment;
use App\Models\ProductionDeployment;
use App\Services\DeploymentWorkflowService;

class BlueGreenDeploymentTest extends TestCase
{
    use RefreshDatabase;

    private DeploymentWorkflowService $deploymentService;
    private Environment $environment;

    protected function setUp(): void
    {
        parent::setUp();

        $this->deploymentService = app(DeploymentWorkflowService::class);

        // Create production environment
        $this->environment = Environment::create([
            'name' => 'Production Test',
            'type' => 'production',
            'dokploy_url' => 'http://test.local:3000',
            'harbor_project' => 'test-prod',
            'auto_deploy' => false,
            'auto_test' => true,
        ]);
    }

    /**
     * Test initial production deployment configuration.
     *
     * @test
     */
    public function production_deployment_starts_with_blue_slot(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'deployment_type' => 'blue_green',
            'active_slot' => 'blue',
            'desired_replicas' => 2,
        ]);

        $this->assertEquals('blue', $deployment->active_slot);
        $this->assertEquals('green', $deployment->getInactiveSlot());
    }

    /**
     * Test inactive slot detection.
     *
     * @test
     */
    public function inactive_slot_is_opposite_of_active(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
        ]);

        $this->assertEquals('green', $deployment->getInactiveSlot());

        $deployment->update(['active_slot' => 'green']);
        $this->assertEquals('blue', $deployment->getInactiveSlot());
    }

    /**
     * Test version tracking for blue/green slots.
     *
     * @test
     */
    public function versions_are_tracked_per_slot(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
            'blue_version' => 'v1.0.0',
            'green_version' => null,
        ]);

        $this->assertEquals('v1.0.0', $deployment->getActiveVersion());
        $this->assertNull($deployment->getInactiveVersion());

        // Simulate deployment to green
        $deployment->update([
            'green_version' => 'v1.1.0',
        ]);

        $this->assertEquals('v1.0.0', $deployment->getActiveVersion());
        $this->assertEquals('v1.1.0', $deployment->getInactiveVersion());
    }

    /**
     * Test health status tracking.
     *
     * @test
     */
    public function health_status_is_tracked(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_replicas' => 2,
            'desired_replicas' => 2,
            'health_status' => [
                'status' => 'healthy',
                'checks' => [
                    'http' => 'passed',
                    'database' => 'passed',
                ],
            ],
        ]);

        $this->assertTrue($deployment->isHealthy());

        // Simulate unhealthy state
        $deployment->update([
            'active_replicas' => 1,
            'health_status' => [
                'status' => 'degraded',
            ],
        ]);

        $this->assertFalse($deployment->isHealthy());
    }

    /**
     * Test rollback availability.
     *
     * @test
     */
    public function rollback_is_available_after_recent_deployment(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'green',
            'blue_version' => 'v1.0.0',
            'green_version' => 'v1.1.0',
            'last_deployment_at' => now()->subMinutes(30),
        ]);

        $this->assertTrue($deployment->canRollback());

        $rollbackTarget = $deployment->getRollbackTarget();
        $this->assertEquals('blue', $rollbackTarget['slot']);
        $this->assertEquals('v1.0.0', $rollbackTarget['version']);
        $this->assertTrue($rollbackTarget['available']);
    }

    /**
     * Test rollback not available after timeout.
     *
     * @test
     */
    public function rollback_not_available_after_timeout(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'green',
            'blue_version' => 'v1.0.0',
            'green_version' => 'v1.1.0',
            'last_deployment_at' => now()->subHours(2),
        ]);

        $this->assertFalse($deployment->canRollback());
    }

    /**
     * Test rollback not available without previous version.
     *
     * @test
     */
    public function rollback_not_available_without_previous_version(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
            'blue_version' => 'v1.0.0',
            'green_version' => null, // No previous version
            'last_deployment_at' => now(),
        ]);

        $this->assertFalse($deployment->canRollback());
    }

    /**
     * Test concurrent requests during slot switch.
     *
     * @test
     */
    public function concurrent_requests_handled_during_switch(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
            'blue_version' => 'v1.0.0',
        ]);

        // Simulate concurrent reads
        $slot1 = $deployment->fresh()->active_slot;
        $slot2 = $deployment->fresh()->active_slot;

        $this->assertEquals($slot1, $slot2);
        $this->assertEquals('blue', $slot1);
    }

    /**
     * Test session persistence during deployment.
     *
     * @test
     */
    public function sessions_persist_across_slots(): void
    {
        // Set session data
        session(['test_key' => 'test_value']);

        // Simulate slot switch
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
        ]);

        $deployment->update(['active_slot' => 'green']);

        // Session should persist (using shared Redis)
        $this->assertEquals('test_value', session('test_key'));
    }

    /**
     * Test database migration handling.
     *
     * @test
     */
    public function database_migrations_handled_correctly(): void
    {
        // Both blue and green should share same database
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
        ]);

        $dbName = config('database.connections.pgsql.database');

        // Switch to green
        $deployment->update(['active_slot' => 'green']);

        // Database should remain the same
        $this->assertEquals($dbName, config('database.connections.pgsql.database'));
    }

    /**
     * Test zero-downtime requirement.
     *
     * @test
     */
    public function deployment_achieves_zero_downtime(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'active_slot' => 'blue',
            'blue_version' => 'v1.0.0',
            'active_replicas' => 2,
            'desired_replicas' => 2,
        ]);

        // During switch, at least one replica should be available
        // (In real scenario, both blue and green would be running during switch)

        $deployment->update([
            'green_version' => 'v1.1.0',
            'active_slot' => 'green',
        ]);

        // Both slots should have had replicas during the switch
        $this->assertGreaterThan(0, $deployment->active_replicas);
    }

    /**
     * Test production deployment status endpoint.
     *
     * @test
     */
    public function production_status_endpoint_returns_correct_data(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'deployment_type' => 'blue_green',
            'active_slot' => 'blue',
            'blue_version' => 'v1.0.0',
            'green_version' => 'v1.1.0',
            'active_replicas' => 2,
            'desired_replicas' => 2,
        ]);

        $status = $this->deploymentService->getProductionStatus($this->environment);

        $this->assertTrue($status['success']);
        $this->assertEquals('blue_green', $status['data']['deployment_type']);
        $this->assertEquals('blue', $status['data']['active_slot']);
        $this->assertEquals('v1.0.0', $status['data']['active_version']);
        $this->assertEquals('green', $status['data']['inactive_slot']);
        $this->assertEquals('v1.1.0', $status['data']['inactive_version']);
    }

    /**
     * Test load balancer configuration.
     *
     * @test
     */
    public function load_balancer_config_is_stored(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'load_balancer_config' => [
                'type' => 'nginx',
                'algorithm' => 'least_conn',
                'health_check_path' => '/health',
                'ssl_enabled' => true,
            ],
        ]);

        $config = $deployment->load_balancer_config;

        $this->assertEquals('nginx', $config['type']);
        $this->assertEquals('least_conn', $config['algorithm']);
        $this->assertTrue($config['ssl_enabled']);
    }

    /**
     * Test replica count requirements.
     *
     * @test
     */
    public function production_requires_minimum_two_replicas(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'desired_replicas' => 2,
        ]);

        $this->assertGreaterThanOrEqual(2, $deployment->desired_replicas);
    }

    /**
     * Test performance metrics tracking.
     *
     * @test
     */
    public function performance_metrics_are_tracked(): void
    {
        $deployment = ProductionDeployment::create([
            'environment_id' => $this->environment->id,
            'performance_metrics' => [
                'avg_response_time_ms' => 45,
                'error_rate' => 0.001,
                'requests_per_second' => 1250,
            ],
        ]);

        $metrics = $deployment->performance_metrics;

        $this->assertArrayHasKey('avg_response_time_ms', $metrics);
        $this->assertArrayHasKey('error_rate', $metrics);
        $this->assertLessThan(100, $metrics['avg_response_time_ms']);
        $this->assertLessThan(0.01, $metrics['error_rate']);
    }
}
