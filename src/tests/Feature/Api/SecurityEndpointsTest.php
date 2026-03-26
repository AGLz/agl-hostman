<?php

declare(strict_types=1);

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Security Endpoints Test
 *
 * Tests for security-related API endpoints.
 */
class SecurityEndpointsTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');

        $this->user = User::factory()->create();
        $this->user->assignRole('common');
    }

    /**
     * Test security audit endpoint requires authentication
     */
    public function test_security_audit_requires_authentication(): void
    {
        $response = $this->getJson('/api/security/audit');

        $response->assertStatus(401);
    }

    /**
     * Test security audit endpoint requires authorization
     */
    public function test_security_audit_requires_authorization(): void
    {
        $response = $this->actingAs($this->user)
            ->getJson('/api/security/audit');

        $response->assertStatus(403);
    }

    /**
     * Test admin can run security audit
     */
    public function test_admin_can_run_security_audit(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'checks',
                'findings',
                'summary',
            ]);
    }

    /**
     * Test compliance check endpoint
     */
    public function test_compliance_check_endpoint(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/compliance');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'checks',
                'summary',
            ]);
    }

    /**
     * Test security audit results are cached
     */
    public function test_security_audit_results_cached(): void
    {
        // First request
        $response1 = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response1->assertStatus(200)
            ->assertHeader('X-Cache', 'MISS');

        // Second request should be cached
        $response2 = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response2->assertStatus(200)
            ->assertHeader('X-Cache', 'HIT');
    }

    /**
     * Test rate limiting on security audit endpoint
     */
    public function test_rate_limiting_on_security_audit(): void
    {
        // Make multiple requests quickly
        for ($i = 0; $i < 5; $i++) {
            $response = $this->actingAs($this->admin)
                ->getJson('/api/security/audit');
            $response->assertStatus(200);
        }

        // 6th request should be rate limited
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response->assertStatus(429);
    }

    /**
     * Test security audit returns proper grade
     */
    public function test_security_audit_returns_grade(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response->assertStatus(200)
            ->assertJsonPath('summary.grade', fn ($grade) => in_array($grade, ['A', 'B', 'C', 'D', 'F']));
    }

    /**
     * Test security audit returns findings
     */
    public function test_security_audit_returns_findings(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'findings' => [
                    '*' => [
                        'severity',
                        'category',
                        'message',
                    ],
                ],
            ]);
    }

    /**
     * Test compliance check includes OWASP Top 10
     */
    public function test_compliance_check_includes_owasp(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/compliance');

        $response->assertStatus(200)
            ->assertJsonPath('checks.owasp_top_10', fn ($owasp) => is_array($owasp))
            ->assertJsonPath('checks.owasp_top_10.compliance_percentage', fn ($percentage) => is_numeric($percentage));
    }

    /**
     * Test compliance check includes GDPR
     */
    public function test_compliance_check_includes_gdpr(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/compliance');

        $response->assertStatus(200)
            ->assertJsonPath('checks.gdpr', fn ($gdpr) => is_array($gdpr))
            ->assertJsonPath('checks.gdpr.compliance_percentage', fn ($percentage) => is_numeric($percentage));
    }

    /**
     * Test security headers are present on responses
     */
    public function test_security_headers_present(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit');

        $response->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-XSS-Protection', '1; mode=block')
            ->assertHeader('Strict-Transport-Security')
            ->assertHeader('Content-Security-Policy');
    }

    /**
     * Test audit log endpoint
     */
    public function test_audit_log_endpoint(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit-logs');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'id',
                        'event_type',
                        'severity',
                        'description',
                        'created_at',
                    ],
                ],
            ]);
    }

    /**
     * Test audit log filtering by severity
     */
    public function test_audit_log_filtering_by_severity(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit-logs?severity=critical');

        $response->assertStatus(200);

        $logs = $response->json('data');

        foreach ($logs as $log) {
            $this->assertEquals('critical', $log['severity']);
        }
    }

    /**
     * Test audit log filtering by event type
     */
    public function test_audit_log_filtering_by_event_type(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit-logs?event_type=auth.login');

        $response->assertStatus(200);

        $logs = $response->json('data');

        foreach ($logs as $log) {
            $this->assertEquals('auth.login', $log['event_type']);
        }
    }

    /**
     * Test audit log pagination
     */
    public function test_audit_log_pagination(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit-logs?page=1&per_page=10');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data',
                'links',
                'meta',
            ]);
    }

    /**
     * Test user cannot access admin security endpoints
     */
    public function test_user_cannot_access_admin_endpoints(): void
    {
        $response = $this->actingAs($this->user)
            ->getJson('/api/security/audit');

        $response->assertStatus(403);
    }

    /**
     * Test unauthenticated user cannot access security endpoints
     */
    public function test_unauthenticated_cannot_access_security_endpoints(): void
    {
        $endpoints = [
            '/api/security/audit',
            '/api/security/compliance',
            '/api/security/audit-logs',
        ];

        foreach ($endpoints as $endpoint) {
            $response = $this->getJson($endpoint);
            $response->assertStatus(401);
        }
    }

    /**
     * Test security audit async job dispatch
     */
    public function test_security_audit_async_job(): void
    {
        $response = $this->actingAs($this->admin)
            ->postJson('/api/security/audit/async');

        $response->assertStatus(202)
            ->assertJsonStructure([
                'message',
                'job_id',
            ]);
    }

    /**
     * Test security audit job status
     */
    public function test_security_audit_job_status(): void
    {
        // Start async job
        $startResponse = $this->actingAs($this->admin)
            ->postJson('/api/security/audit/async');

        $jobId = $startResponse->json('job_id');

        // Check job status
        $response = $this->actingAs($this->admin)
            ->getJson("/api/security/audit/async/{$jobId}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'job_id',
                'status',
                'progress',
            ]);
    }

    /**
     * Test security audit result download
     */
    public function test_security_audit_download(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/audit/download');

        $response->assertStatus(200)
            ->assertHeader('content-type', 'application/json');
    }

    /**
     * Test security metrics endpoint
     */
    public function test_security_metrics_endpoint(): void
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/security/metrics');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'total_findings',
                'critical',
                'high',
                'medium',
                'low',
                'grade',
            ]);
    }
}
