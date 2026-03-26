<?php

declare(strict_types=1);

namespace Tests\Feature\Integration;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * UAT Smoke Tests
 *
 * Lightweight critical path testing for UAT environment
 * Designed to complete in < 2 minutes
 *
 * @group smoke
 * @group uat
 */
class UATSmokeTests extends TestCase
{
    use RefreshDatabase;

    private string $baseUrl;

    protected function setUp(): void
    {
        parent::setUp();
        $this->baseUrl = config('app.url');
    }

    /**
     * Test health endpoint
     *
     * @test
     */
    public function health_endpoint_returns_200(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'healthy',
            ]);
    }

    /**
     * Test database connectivity
     *
     * @test
     */
    public function database_connection_works(): void
    {
        $this->assertDatabaseCount('environments', 0);

        // Create test record
        \App\Models\Environment::create([
            'name' => 'Test Environment',
            'type' => 'dev',
            'harbor_project' => 'test-project',
            'git_branch' => 'main',
            'auto_deploy' => false,
            'auto_test' => false,
            'status' => 'active',
            'domains' => ['test.local'],
            'env_vars' => ['TEST' => 'value'],
            'resources' => ['cpu_limit' => '1'],
        ]);

        $this->assertDatabaseCount('environments', 1);
    }

    /**
     * Test Redis connectivity
     *
     * @test
     */
    public function redis_connection_works(): void
    {
        $key = 'smoke_test_'.time();
        $value = 'test_value';

        \Illuminate\Support\Facades\Redis::set($key, $value);
        $retrieved = \Illuminate\Support\Facades\Redis::get($key);

        $this->assertEquals($value, $retrieved);

        \Illuminate\Support\Facades\Redis::del($key);
    }

    /**
     * Test authentication endpoint
     *
     * @test
     */
    public function auth_endpoints_respond(): void
    {
        // Login endpoint should be accessible
        $response = $this->postJson('/api/auth/login', [
            'email' => 'nonexistent@example.com',
            'password' => 'wrong',
        ]);

        // Should fail authentication but endpoint should work
        $response->assertStatus(422); // Validation error or 401
    }

    /**
     * Test environment list endpoint
     *
     * @test
     */
    public function environment_list_endpoint_works(): void
    {
        $response = $this->getJson('/api/environments');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data',
            ]);
    }

    /**
     * Test Dokploy service configuration
     *
     * @test
     */
    public function dokploy_service_is_configured(): void
    {
        $this->assertNotEmpty(config('dokploy.api_url'));
        $this->assertNotEmpty(config('dokploy.token'));
    }

    /**
     * Test Harbor configuration
     *
     * @test
     */
    public function harbor_is_configured(): void
    {
        $this->assertNotEmpty(config('harbor.registry'));
        $this->assertNotEmpty(config('harbor.username'));
        $this->assertNotEmpty(config('harbor.password'));
    }

    /**
     * Test deployment controller endpoints
     *
     * @test
     */
    public function deployment_endpoints_accessible(): void
    {
        // Health check endpoint
        $response = $this->getJson('/api/deployments/health');
        $this->assertContains($response->status(), [200, 401]); // May require auth

        // Status endpoint
        $response = $this->getJson('/api/deployments/status');
        $this->assertContains($response->status(), [200, 401]); // May require auth
    }

    /**
     * Test promotion endpoints exist
     *
     * @test
     */
    public function promotion_endpoints_exist(): void
    {
        // Test that routes are defined
        $response = $this->postJson('/api/promotion/qa-to-uat', []);
        $this->assertContains($response->status(), [401, 422]); // Auth required or validation

        $response = $this->getJson('/api/promotion/fake-id/status');
        $this->assertContains($response->status(), [401, 404]); // Auth required or not found
    }

    /**
     * Test queue connection
     *
     * @test
     */
    public function queue_connection_works(): void
    {
        $this->assertNotNull(\Illuminate\Support\Facades\Queue::connection());
    }

    /**
     * Test cache connection
     *
     * @test
     */
    public function cache_works(): void
    {
        $key = 'smoke_test_cache_'.time();
        $value = 'cached_value';

        \Illuminate\Support\Facades\Cache::put($key, $value, 60);
        $retrieved = \Illuminate\Support\Facades\Cache::get($key);

        $this->assertEquals($value, $retrieved);

        \Illuminate\Support\Facades\Cache::forget($key);
    }

    /**
     * Test logging works
     *
     * @test
     */
    public function logging_works(): void
    {
        $this->assertNotNull(\Illuminate\Support\Facades\Log::getLogger());

        // Log a test message
        \Illuminate\Support\Facades\Log::info('UAT Smoke test log entry');

        $this->assertTrue(true); // If we got here, logging works
    }

    /**
     * Comprehensive smoke test summary
     *
     * Runs all critical checks and reports results
     *
     * @test
     */
    public function comprehensive_smoke_check(): void
    {
        $results = [];

        // Database
        try {
            \Illuminate\Support\Facades\DB::connection()->getPdo();
            $results['database'] = 'PASS';
        } catch (\Exception $e) {
            $results['database'] = 'FAIL: '.$e->getMessage();
        }

        // Redis
        try {
            \Illuminate\Support\Facades\Redis::ping();
            $results['redis'] = 'PASS';
        } catch (\Exception $e) {
            $results['redis'] = 'FAIL: '.$e->getMessage();
        }

        // Cache
        try {
            \Illuminate\Support\Facades\Cache::get('test');
            $results['cache'] = 'PASS';
        } catch (\Exception $e) {
            $results['cache'] = 'FAIL: '.$e->getMessage();
        }

        // Queue
        try {
            \Illuminate\Support\Facades\Queue::connection();
            $results['queue'] = 'PASS';
        } catch (\Exception $e) {
            $results['queue'] = 'FAIL: '.$e->getMessage();
        }

        // Config
        $results['dokploy_configured'] = ! empty(config('dokploy.api_url')) ? 'PASS' : 'FAIL';
        $results['harbor_configured'] = ! empty(config('harbor.registry')) ? 'PASS' : 'FAIL';

        // Report results
        \Illuminate\Support\Facades\Log::info('UAT Smoke Test Summary', $results);

        // Assert all passed
        foreach ($results as $check => $result) {
            $this->assertEquals('PASS', $result, "Smoke check failed: {$check}");
        }
    }
}
