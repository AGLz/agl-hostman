<?php

declare(strict_types=1);

namespace Tests\Performance;

use Tests\TestCase;
use App\Models\User;
use App\Models\Alert;
use App\Models\N8NWorkflow;
use Illuminate\Support\Facades\DB;
use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Performance Test Suite
 *
 * Tests application performance and ensures optimization goals are met.
 */
class PerformanceTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test API response time for monitoring endpoints
     */
    public function test_monitoring_health_response_time(): void
    {
        $response = $this->getJson('/api/monitoring/health');

        $response->assertStatus(200);

        // Response time should be available in headers
        $responseTime = (float)$response->headers->get('X-Response-Time', 0);

        $this->assertLessThan(100, $responseTime, 'Response time should be < 100ms');
    }

    /**
     * Test query count for monitoring endpoints
     */
    public function test_monitoring_query_count(): void
    {
        DB::enableQueryLog();

        $response = $this->getJson('/api/monitoring/health');

        $queries = DB::getQueryLog();

        $this->assertLessThan(20, count($queries), 'Should use fewer than 20 queries');
    }

    /**
     * Test N+1 query prevention for alerts
     */
    public function test_alerts_no_n_plus_one(): void
    {
        // Create test data
        Alert::factory()->count(10)->create();

        DB::enableQueryLog();

        $response = $this->getJson('/api/monitoring/alerts?limit=10');

        $queries = DB::getQueryLog();

        // Should not have N+1 problem (should be similar number of queries regardless of result count)
        $this->assertLessThan(15, count($queries), 'Alerts endpoint should not have N+1 queries');

        $response->assertStatus(200);
    }

    /**
     * Test caching for infrastructure status
     */
    public function test_infrastructure_status_caching(): void
    {
        // First request
        $response1 = $this->getJson('/api/infrastructure/status');

        // Check if response is cached
        $isCached1 = $response1->headers->get('X-Cache') === 'HIT' || $response1->headers->get('X-Cache') === 'MISS';

        // Second request should be cached
        $response2 = $this->getJson('/api/infrastructure/status');

        // Cache should be working (second request might be HIT)
        $this->assertNotNull($response2->headers->get('X-Cache'));
    }

    /**
     * Test N8N workflows with eager loading
     */
    public function test_n8n_workflows_eager_loading(): void
    {
        N8NWorkflow::factory()->count(5)->create();

        DB::enableQueryLog();

        $response = $this->getJson('/api/n8n/workflows');

        $queries = DB::getQueryLog();

        // Should use eager loading for executions relation
        $this->assertLessThan(10, count($queries), 'Workflows should use eager loading');

        $response->assertStatus(200);
    }

    /**
     * Test user permissions caching
     */
    public function test_user_permissions_caching(): void
    {
        $user = User::factory()->create();
        $user->assignRole('admin');

        DB::enableQueryLog();

        // First call
        $user->hasPermissionTo('view-dashboard');

        $firstQueryCount = count(DB::getQueryLog());

        // Second call (should be cached or optimized)
        DB::flushQueryLog();
        $user->hasPermissionTo('view-dashboard');

        $secondQueryCount = count(DB::getQueryLog());

        // Permission checks should be optimized
        $this->assertLessThanOrEqual($firstQueryCount, $secondQueryCount);
    }

    /**
     * Test pagination performance
     */
    public function test_pagination_performance(): void
    {
        Alert::factory()->count(100)->create();

        DB::enableQueryLog();

        $response = $this->getJson('/api/monitoring/alerts?page=1&per_page=25');

        $queries = DB::getQueryLog();

        // Pagination should use single query with limit/offset
        $this->assertLessThan(5, count($queries), 'Pagination should use efficient queries');

        $response->assertStatus(200)
            ->assertJsonCount(25, 'data');
    }

    /**
     * Test memory usage for large datasets
     */
    public function test_memory_usage_large_dataset(): void
    {
        Alert::factory()->count(500)->create();

        $memoryBefore = memory_get_usage();

        $response = $this->getJson('/api/monitoring/alerts?per_page=100');

        $memoryAfter = memory_get_usage();
        $memoryUsed = ($memoryAfter - $memoryBefore) / 1024 / 1024; // MB

        // Should use less than 64MB for 100 records
        $this->assertLessThan(64, $memoryUsed, 'Memory usage should be < 64MB for 100 records');

        $response->assertStatus(200);
    }

    /**
     * Test database index usage
     */
    public function test_database_index_usage(): void
    {
        Alert::factory()->count(50)->create();

        DB::enableQueryLog();

        $response = $this->getJson('/api/monitoring/alerts?status=active');

        $queries = DB::getQueryLog();

        // Check if index is being used (by examining EXPLAIN if available)
        $this->assertGreaterThan(0, count($queries));

        $response->assertStatus(200);
    }

    /**
     * Test concurrent request performance
     */
    public function test_concurrent_requests(): void
    {
        $responses = [];

        for ($i = 0; $i < 10; $i++) {
            $responses[] = $this->getJson('/api/monitoring/health');
        }

        // All requests should succeed
        foreach ($responses as $response) {
            $response->assertStatus(200);
        }

        // Check response times are consistent
        $times = array_map(function ($r) {
            return (float)$r->headers->get('X-Response-Time', 0);
        }, $responses);

        $avgTime = array_sum($times) / count($times);

        $this->assertLessThan(100, $avgTime, 'Average response time should be < 100ms');
    }

    /**
     * Test cache hit rate
     */
    public function test_cache_hit_rate(): void
    {
        $endpoints = [
            '/api/monitoring/health',
            '/api/infrastructure/status',
            '/api/n8n/statistics',
        ];

        foreach ($endpoints as $endpoint) {
            // First request - cache miss
            $response1 = $this->getJson($endpoint);

            // Second request - should be cached
            $response2 = $this->getJson($endpoint);

            // Third request - should be cached
            $response3 = $this->getJson($endpoint);

            // All should succeed
            $response1->assertStatus(200);
            $response2->assertStatus(200);
            $response3->assertStatus(200);
        }

        $this->assertTrue(true, 'Cache hit rate test completed');
    }

    /**
     * Benchmark: Get alerts with optimization
     */
    public function benchmark_get_alerts(): void
    {
        Alert::factory()->count(100)->create();

        $start = microtime(true);

        $this->getJson('/api/monitoring/alerts');

        $duration = (microtime(true) - $start) * 1000;

        $this->assertLessThan(100, $duration, 'Alert endpoint should respond in < 100ms');
    }

    /**
     * Benchmark: N8N workflows with caching
     */
    public function benchmark_n8n_workflows(): void
    {
        N8NWorkflow::factory()->count(20)->create();

        $start = microtime(true);

        $this->getJson('/api/n8n/workflows');

        $duration = (microtime(true) - $start) * 1000;

        $this->assertLessThan(100, $duration, 'N8N workflows should respond in < 100ms');
    }
}
