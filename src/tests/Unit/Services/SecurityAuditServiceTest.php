<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Services\SecurityAuditService;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Process;
use Tests\TestCase;

/**
 * Security Audit Service Test
 *
 * Tests for the SecurityAuditService class.
 */
class SecurityAuditServiceTest extends TestCase
{
    private SecurityAuditService $auditService;

    protected function setUp(): void
    {
        parent::setUp();

        $this->auditService = new SecurityAuditService;
    }

    /**
     * Test running full security audit
     */
    public function test_run_full_audit(): void
    {
        Config::set('app.debug', false);
        Config::set('app.key', 'base64:'.str_repeat('a', 44));

        $results = $this->auditService->runFullAudit();

        $this->assertIsArray($results);
        $this->assertArrayHasKey('timestamp', $results);
        $this->assertArrayHasKey('checks', $results);
        $this->assertArrayHasKey('findings', $results);
        $this->assertArrayHasKey('summary', $results);
        $this->assertArrayHasKey('grade', $results['summary']);
    }

    /**
     * Test dependency vulnerability check
     */
    public function test_check_dependency_vulnerabilities(): void
    {
        Process::fake([
            'composer audit --no-dev' => Process::result(exitCode: 0, output: 'No vulnerabilities found.'),
            'npm audit --json' => Process::result(exitCode: 0, output: json_encode([
                'metadata' => ['vulnerabilities' => ['critical' => 0, 'high' => 0, 'moderate' => 0, 'low' => 0, 'info' => 0]],
            ])),
        ]);

        $result = $this->auditService->checkDependencyVulnerabilities();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('details', $result);
    }

    /**
     * Test code security audit
     */
    public function test_audit_code_security(): void
    {
        $result = $this->auditService->auditCodeSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('hardcoded_secrets', $result['checks']);
        $this->assertArrayHasKey('sql_injection', $result['checks']);
        $this->assertArrayHasKey('xss_vulnerabilities', $result['checks']);
    }

    /**
     * Test authentication security audit
     */
    public function test_audit_authentication_security(): void
    {
        Config::set('session.lifetime', 60);
        Config::set('session.secure', true);
        Config::set('session.http_only', true);
        Config::set('session.same_site', 'lax');

        $result = $this->auditService->auditAuthenticationSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('password_policy', $result['checks']);
        $this->assertArrayHasKey('session_config', $result['checks']);
    }

    /**
     * Test authorization security audit
     */
    public function test_audit_authorization_security(): void
    {
        $result = $this->auditService->auditAuthorizationSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('rbac', $result['checks']);
        $this->assertArrayHasKey('policies', $result['checks']);
    }

    /**
     * Test data protection audit
     */
    public function test_audit_data_protection(): void
    {
        Config::set('app.env', 'production');
        Config::set('app.url', 'https://example.com');

        $result = $this->auditService->auditDataProtection();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('encryption_at_rest', $result['checks']);
        $this->assertArrayHasKey('tls_configuration', $result['checks']);
    }

    /**
     * Test API security audit
     */
    public function test_audit_api_security(): void
    {
        Config::set('cors.paths', ['api/*']);
        Config::set('cors.allowed_origins', ['https://example.com']);

        $result = $this->auditService->auditApiSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('rate_limiting', $result['checks']);
        $this->assertArrayHasKey('authentication', $result['checks']);
    }

    /**
     * Test configuration security audit
     */
    public function test_audit_configuration_security(): void
    {
        Config::set('app.debug', false);
        Config::set('app.key', 'base64:'.str_repeat('a', 44));

        $result = $this->auditService->auditConfigurationSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
    }

    /**
     * Test logging security audit
     */
    public function test_audit_logging_security(): void
    {
        Config::set('logging.default', 'stack');

        $result = $this->auditService->auditLoggingSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertArrayHasKey('log_channels', $result['checks']);
        $this->assertArrayHasKey('audit_logging', $result['checks']);
    }

    /**
     * Test checking for hardcoded secrets
     */
    public function test_check_hardcoded_secrets(): void
    {
        $result = $this->auditService->checkHardcodedSecrets();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking for SQL injection risks
     */
    public function test_check_sql_injection_risks(): void
    {
        $result = $this->auditService->checkSqlInjectionRisks();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking for XSS vulnerabilities
     */
    public function test_check_xss_vulnerabilities(): void
    {
        $result = $this->auditService->checkXssVulnerabilities();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking file handling security
     */
    public function test_check_file_handling_security(): void
    {
        $result = $this->auditService->checkFileHandlingSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking insecure configurations
     */
    public function test_check_insecure_configurations(): void
    {
        Config::set('app.debug', false);
        Config::set('app.key', 'base64:'.str_repeat('a', 44));

        $result = $this->auditService->checkInsecureConfigurations();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking password policy
     */
    public function test_check_password_policy(): void
    {
        $result = $this->auditService->checkPasswordPolicy();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking session configuration
     */
    public function test_check_session_configuration(): void
    {
        Config::set('session.lifetime', 60);
        Config::set('session.secure', true);
        Config::set('session.http_only', true);
        Config::set('session.same_site', 'lax');

        $result = $this->auditService->checkSessionConfiguration();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking two-factor availability
     */
    public function test_check_two_factor_availability(): void
    {
        Config::set('services.workos.enabled', false);

        $result = $this->auditService->checkTwoFactorAvailability();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test checking auth rate limiting
     */
    public function test_check_auth_rate_limiting(): void
    {
        $result = $this->auditService->checkAuthRateLimiting();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('findings', $result);
    }

    /**
     * Test summary calculation
     */
    public function test_calculate_summary(): void
    {
        $result = $this->auditService->runFullAudit();

        $this->assertArrayHasKey('summary', $result);
        $this->assertArrayHasKey('total_findings', $result['summary']);
        $this->assertArrayHasKey('critical', $result['summary']);
        $this->assertArrayHasKey('high', $result['summary']);
        $this->assertArrayHasKey('medium', $result['summary']);
        $this->assertArrayHasKey('low', $result['summary']);
        $this->assertArrayHasKey('info', $result['summary']);
        $this->assertArrayHasKey('score', $result['summary']);
        $this->assertArrayHasKey('grade', $result['summary']);
    }

    /**
     * Test grade calculation
     */
    public function test_grade_calculation(): void
    {
        $result = $this->auditService->runFullAudit();

        $grade = $result['summary']['grade'];

        $this->assertContains($grade, ['A', 'B', 'C', 'D', 'F']);
    }
}
