<?php

declare(strict_types=1);

namespace Tests\Feature\Api;

use App\Models\ApiKey;
use App\Models\User;
use App\Models\SecurityAuditLog;
use App\Services\SecurityAuditService;
use App\Services\SecurityComplianceService;
use Illuminate\Support\Facades\Process;
use Tests\TestCase;

/**
 * Security API Endpoints Comprehensive Test
 *
 * Comprehensive tests for security-related API endpoints.
 *
 * @package Tests\Feature\Api
 */
class SecurityEndpointsComprehensiveTest extends TestCase
{

    /**
     * Test running security audit endpoint
     */
    public function test_run_security_audit(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        Process::fake([
            'composer audit --no-dev' => Process::result(exitCode: 0, output: 'No vulnerabilities found.'),
            'npm audit --json' => Process::result(exitCode: 0, output: json_encode([
                'metadata' => ['vulnerabilities' => ['critical' => 0, 'high' => 0]],
            ])),
        ]);

        $response = $this->postJson('/api/security/audit');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'checks',
                'findings',
                'summary' => [
                    'total_findings',
                    'critical',
                    'high',
                    'medium',
                    'grade',
                ],
            ]);
    }

    /**
     * Test running compliance check endpoint
     */
    public function test_run_compliance_check(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->postJson('/api/security/compliance');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'timestamp',
                'checks' => [
                    'owasp_top_10',
                    'gdpr',
                    'best_practices',
                ],
                'summary' => [
                    'overall_compliance',
                    'owasp_compliance',
                    'gdpr_compliance',
                    'best_practices_compliance',
                    'grade',
                ],
            ]);
    }

    /**
     * Test getting security findings
     */
    public function test_get_security_findings(): void
    {
        SecurityAuditLog::factory()->count(5)->create([
            'severity' => 'high',
        ]);

        SecurityAuditLog::factory()->count(3)->create([
            'severity' => 'critical',
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/findings');

        $response->assertStatus(200)
            ->assertJsonCount(8);
    }

    /**
     * Test getting security findings filtered by severity
     */
    public function test_get_security_findings_filtered_by_severity(): void
    {
        SecurityAuditLog::factory()->count(5)->create([
            'severity' => 'high',
        ]);

        SecurityAuditLog::factory()->count(3)->create([
            'severity' => 'critical',
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/findings?severity=critical');

        $response->assertStatus(200)
            ->assertJsonCount(3);
    }

    /**
     * Test getting security findings recent
     */
    public function test_get_recent_security_findings(): void
    {
        SecurityAuditLog::factory()->create([
            'severity' => 'high',
            'created_at' => now()->subDays(3),
        ]);

        SecurityAuditLog::factory()->create([
            'severity' => 'critical',
            'created_at' => now()->subDays(10),
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/findings?days=7');

        $response->assertStatus(200)
            ->assertJsonCount(1);
    }

    /**
     * Test getting security statistics
     */
    public function test_get_security_statistics(): void
    {
        SecurityAuditLog::factory()->count(5)->create(['severity' => 'critical']);
        SecurityAuditLog::factory()->count(10)->create(['severity' => 'high']);
        SecurityAuditLog::factory()->count(15)->create(['severity' => 'medium']);
        SecurityAuditLog::factory()->count(20)->create(['severity' => 'low']);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/statistics');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'total_findings',
                'by_severity' => [
                    'critical',
                    'high',
                    'medium',
                    'low',
                    'info',
                ],
                'recent_trends',
            ])
            ->assertJsonPath('by_severity.critical', 5)
            ->assertJsonPath('by_severity.high', 10)
            ->assertJsonPath('by_severity.medium', 15)
            ->assertJsonPath('by_severity.low', 20);
    }

    /**
     * Test unauthorized user cannot access security endpoints
     */
    public function test_unauthorized_user_cannot_access_security(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user);

        $response = $this->postJson('/api/security/audit');

        $response->assertStatus(403);
    }

    /**
     * Test guest cannot access security endpoints
     */
    public function test_guest_cannot_access_security(): void
    {
        $response = $this->postJson('/api/security/audit');

        $response->assertStatus(401);
    }

    /**
     * Test resolving a security finding
     */
    public function test_resolve_security_finding(): void
    {
        $finding = SecurityAuditLog::factory()->create([
            'severity' => 'high',
            'is_resolved' => false,
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->postJson("/api/security/findings/{$finding->id}/resolve", [
            'resolution_notes' => 'Fixed by updating configuration',
        ]);

        $response->assertStatus(200);

        $this->assertDatabaseHas('security_audit_logs', [
            'id' => $finding->id,
            'is_resolved' => true,
        ]);
    }

    /**
     * Test bulk resolving security findings
     */
    public function test_bulk_resolve_security_findings(): void
    {
        $findings = SecurityAuditLog::factory()->count(5)->create([
            'severity' => 'medium',
            'is_resolved' => false,
        ]);

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->postJson('/api/security/findings/bulk-resolve', [
            'finding_ids' => $findings->pluck('id')->toArray(),
            'resolution_notes' => 'Bulk resolved during security sprint',
        ]);

        $response->assertStatus(200);

        foreach ($findings as $finding) {
            $this->assertDatabaseHas('security_audit_logs', [
                'id' => $finding->id,
                'is_resolved' => true,
            ]);
        }
    }

    /**
     * Test exporting security findings
     */
    public function test_export_security_findings(): void
    {
        SecurityAuditLog::factory()->count(10)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/findings/export');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data',
                'meta' => [
                    'total',
                    'exported_at',
                ],
            ]);
    }

    /**
     * Test exporting security findings as CSV
     */
    public function test_export_security_findings_as_csv(): void
    {
        SecurityAuditLog::factory()->count(5)->create();

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/findings/export?format=csv');

        $response->assertStatus(200)
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    /**
     * Test getting OWASP Top 10 compliance details
     */
    public function test_get_owasp_compliance_details(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/compliance/owasp');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'compliance_percentage',
                'passed',
                'total',
                'checks' => [
                    'A01_2021_Broken_Access_Control',
                    'A02_2021_Cryptographic_Failures',
                    'A03_2021_Injection',
                ],
            ]);
    }

    /**
     * Test getting GDPR compliance details
     */
    public function test_get_gdpr_compliance_details(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/compliance/gdpr');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'compliance_percentage',
                'passed',
                'total',
                'checks' => [
                    'data_minimization',
                    'right_to_access',
                    'right_to_erasure',
                ],
            ]);
    }

    /**
     * Test getting security best practices details
     */
    public function test_get_best_practices_details(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/compliance/best-practices');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'compliance_percentage',
                'passed',
                'total',
                'checks' => [
                    'password_policy',
                    'session_management',
                    'api_security',
                ],
            ]);
    }

    /**
     * Test getting security recommendations
     */
    public function test_get_security_recommendations(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/recommendations');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'priority' => [
                    '*' => [
                        'category',
                        'recommendation',
                        'severity',
                    ],
                ],
                'total_count',
            ]);
    }

    /**
     * Test dismissing a security recommendation
     */
    public function test_dismiss_security_recommendation(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->postJson('/api/security/recommendations/1/dismiss', [
            'dismissal_reason' => 'Not applicable to our environment',
        ]);

        $response->assertStatus(200);
    }

    /**
     * Test getting security scan history
     */
    public function test_get_security_scan_history(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/history');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'id',
                        'scan_type',
                        'started_at',
                        'completed_at',
                        'status',
                        'findings_count',
                    ],
                ],
            ]);
    }

    /**
     * Test triggering manual security scan
     */
    public function test_trigger_manual_security_scan(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->postJson('/api/security/scan', [
            'scan_types' => ['code_security', 'dependency_check'],
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'scan_id',
                'status',
                'estimated_completion',
            ]);
    }

    /**
     * Test getting scan results
     */
    public function test_get_scan_results(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $this->actingAs($admin);

        $response = $this->getJson('/api/security/scan/latest/results');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'scan_id',
                'status',
                'results' => [
                    'code_security',
                    'dependency_check',
                ],
            ]);
    }
}
