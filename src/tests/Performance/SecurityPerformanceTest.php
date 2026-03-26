<?php

declare(strict_types=1);

namespace Tests\Performance;

use App\Models\SecurityAuditLog;
use App\Models\User;
use App\Services\SecurityAuditService;
use App\Services\SecurityComplianceService;
use Illuminate\Support\Facades\Process;
use Tests\TestCase;

/**
 * Security Performance Test
 *
 * Performance tests for security operations.
 */
class SecurityPerformanceTest extends TestCase
{
    /**
     * Test security audit service performance
     */
    public function test_security_audit_performance(): void
    {
        $service = new SecurityAuditService;

        Process::fake([
            'composer audit --no-dev' => Process::result(exitCode: 0, output: 'No vulnerabilities.'),
            'npm audit --json' => Process::result(exitCode: 0, output: json_encode([
                'metadata' => ['vulnerabilities' => []],
            ])),
        ]);

        $startTime = microtime(true);
        $result = $service->runFullAudit();
        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(5000, $duration, 'Security audit should complete in less than 5 seconds');
        $this->assertIsArray($result);
        $this->assertArrayHasKey('summary', $result);
    }

    /**
     * Test compliance check performance
     */
    public function test_compliance_check_performance(): void
    {
        $service = new SecurityComplianceService;

        $startTime = microtime(true);
        $result = $service->runComplianceCheck();
        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(3000, $duration, 'Compliance check should complete in less than 3 seconds');
        $this->assertIsArray($result);
    }

    /**
     * Test bulk security log creation performance
     */
    public function test_bulk_security_log_creation_performance(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user);

        $startTime = microtime(true);

        SecurityAuditLog::factory()->count(100)->create([
            'user_id' => $user->id,
        ]);

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(1000, $duration, 'Creating 100 security logs should take less than 1 second');
        $this->assertDatabaseCount('security_audit_logs', 100);
    }

    /**
     * Test security findings query performance with large dataset
     */
    public function test_security_findings_query_performance(): void
    {
        SecurityAuditLog::factory()->count(1000)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/findings');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(500, $duration, 'Query should complete in less than 500ms');
        $response->assertStatus(200);
    }

    /**
     * Test security statistics aggregation performance
     */
    public function test_security_statistics_aggregation_performance(): void
    {
        SecurityAuditLog::factory()->count(500)->create([
            'severity' => 'critical',
        ]);

        SecurityAuditLog::factory()->count(1000)->create([
            'severity' => 'high',
        ]);

        SecurityAuditLog::factory()->count(1500)->create([
            'severity' => 'medium',
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/statistics');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(1000, $duration, 'Statistics aggregation should complete in less than 1 second');
        $response->assertStatus(200);
    }

    /**
     * Test security log filtering performance
     */
    public function test_security_log_filtering_performance(): void
    {
        SecurityAuditLog::factory()->count(100)->create(['severity' => 'critical']);
        SecurityAuditLog::factory()->count(200)->create(['severity' => 'high']);
        SecurityAuditLog::factory()->count(300)->create(['severity' => 'medium']);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/findings?severity=high');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(200, $duration, 'Filtered query should complete in less than 200ms');
        $response->assertStatus(200)
            ->assertJsonCount(200);
    }

    /**
     * Test security search performance
     */
    public function test_security_search_performance(): void
    {
        SecurityAuditLog::factory()->count(1000)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/findings?search=authentication');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(300, $duration, 'Search query should complete in less than 300ms');
        $response->assertStatus(200);
    }

    /**
     * Test concurrent security audit requests
     */
    public function test_concurrent_security_audit_requests(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $startTime = microtime(true);

        $responses = [];
        for ($i = 0; $i < 5; $i++) {
            $responses[] = $this->actingAs($admin)->postJson('/api/security/audit');
        }

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(10000, $duration, '5 concurrent requests should complete in less than 10 seconds');

        foreach ($responses as $response) {
            $response->assertStatus(200);
        }
    }

    /**
     * Test memory usage during security audit
     */
    public function test_memory_usage_during_security_audit(): void
    {
        $service = new SecurityAuditService;

        Process::fake([
            'composer audit --no-dev' => Process::result(exitCode: 0),
            'npm audit --json' => Process::result(exitCode: 0, output: json_encode(['metadata' => ['vulnerabilities' => []]])),
        ]);

        $initialMemory = memory_get_usage(true);

        $service->runFullAudit();

        $peakMemory = memory_get_usage(true);
        $memoryUsed = ($peakMemory - $initialMemory) / 1024 / 1024; // Convert to MB

        $this->assertLessThan(50, $memoryUsed, 'Security audit should use less than 50MB of memory');
    }

    /**
     * Test cache performance for security data
     */
    public function test_cache_performance_for_security_data(): void
    {
        SecurityAuditLog::factory()->count(100)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        // First request (not cached)
        $startTime = microtime(true);
        $response1 = $this->getJson('/api/security/statistics');
        $duration1 = (microtime(true) - $startTime) * 1000;

        // Second request (potentially cached)
        $startTime = microtime(true);
        $response2 = $this->getJson('/api/security/statistics');
        $duration2 = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(500, $duration1, 'First request should complete in less than 500ms');
        $this->assertLessThan(500, $duration2, 'Second request should complete in less than 500ms');

        $response1->assertStatus(200);
        $response2->assertStatus(200);
    }

    /**
     * Test pagination performance for large datasets
     */
    public function test_pagination_performance_for_large_datasets(): void
    {
        SecurityAuditLog::factory()->count(5000)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/findings?page=1&per_page=50');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(200, $duration, 'Paginated query should complete in less than 200ms');
        $response->assertStatus(200)
            ->assertJsonCount(50, 'data');
    }

    /**
     * Test security report generation performance
     */
    public function test_security_report_generation_performance(): void
    {
        SecurityAuditLog::factory()->count(1000)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $startTime = microtime(true);

        $response = $this->getJson('/api/security/report?format=json');

        $duration = (microtime(true) - $startTime) * 1000;

        $this->assertLessThan(2000, $duration, 'Report generation should complete in less than 2 seconds');
        $response->assertStatus(200);
    }

    /**
     * Test database query optimization for security logs
     */
    public function test_database_query_optimization_for_security_logs(): void
    {
        SecurityAuditLog::factory()->count(500)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        // Enable query log
        \DB::enableQueryLog();

        $response = $this->getJson('/api/security/findings?severity=critical');

        $queries = \DB::getQueryLog();

        $this->assertLessThan(10, count($queries), 'Should use less than 10 database queries');
        $response->assertStatus(200);
    }

    /**
     * Test N+1 query prevention for security logs with relationships
     */
    public function test_n_plus_1_query_prevention(): void
    {
        $users = User::factory()->count(10)->create();

        foreach ($users as $user) {
            SecurityAuditLog::factory()->count(5)->create(['user_id' => $user->id]);
        }

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        \DB::enableQueryLog();

        $response = $this->getJson('/api/security/findings?include=user');

        $queries = \DB::getQueryLog();

        // Should use eager loading to avoid N+1
        // Expected queries: 1 for finding logs, 1 for users
        $this->assertLessThan(5, count($queries), 'Should use eager loading to avoid N+1 queries');
        $response->assertStatus(200);
    }
}
