<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Services\SecurityComplianceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * Security Compliance Service Test
 *
 * Tests for the SecurityComplianceService class.
 *
 * @package Tests\Unit\Services
 */
class SecurityComplianceServiceTest extends TestCase
{
    private SecurityComplianceService $complianceService;

    protected function setUp(): void
    {
        parent::setUp();

        $this->complianceService = new SecurityComplianceService();
    }

    /**
     * Test running full compliance check
     */
    public function test_run_compliance_check(): void
    {
        Config::set('app.debug', false);
        Config::set('app.url', 'https://example.com');

        $results = $this->complianceService->runComplianceCheck();

        $this->assertIsArray($results);
        $this->assertArrayHasKey('timestamp', $results);
        $this->assertArrayHasKey('checks', $results);
        $this->assertArrayHasKey('summary', $results);
        $this->assertArrayHasKey('owasp_top_10', $results['checks']);
        $this->assertArrayHasKey('gdpr', $results['checks']);
        $this->assertArrayHasKey('best_practices', $results['checks']);
    }

    /**
     * Test OWASP Top 10 compliance check
     */
    public function test_check_owasp_top_10(): void
    {
        Config::set('app.env', 'production');
        Config::set('app.url', 'https://example.com');
        Config::set('app.debug', false);
        Config::set('session.secure', true);
        Config::set('session.http_only', true);

        $result = $this->complianceService->checkOWASPTop10();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliance_percentage', $result);
        $this->assertArrayHasKey('passed', $result);
        $this->assertArrayHasKey('total', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertEquals(10, $result['total']);
    }

    /**
     * Test checking broken access control (A01)
     */
    public function test_check_broken_access_control(): void
    {
        $result = $this->complianceService->checkBrokenAccessControl();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
        $this->assertIsBool($result['compliant']);
    }

    /**
     * Test checking cryptographic failures (A02)
     */
    public function test_check_cryptographic_failures(): void
    {
        Config::set('app.env', 'production');
        Config::set('app.url', 'https://example.com');
        Config::set('session.encrypt', true);
        Config::set('hashing.driver', 'bcrypt');
        Config::set('app.key', 'base64:' . str_repeat('a', 44));

        $result = $this->complianceService->checkCryptographicFailures();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking injection vulnerabilities (A03)
     */
    public function test_check_injection(): void
    {
        $result = $this->complianceService->checkInjection();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking insecure design (A04)
     */
    public function test_check_insecure_design(): void
    {
        $result = $this->complianceService->checkInsecureDesign();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking security misconfiguration (A05)
     */
    public function test_check_security_misconfiguration(): void
    {
        Config::set('app.debug', false);
        Config::set('app.env', 'production');

        $result = $this->complianceService->checkSecurityMisconfiguration();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking vulnerable components (A06)
     */
    public function test_check_vulnerable_components(): void
    {
        $result = $this->complianceService->checkVulnerableComponents();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking authentication failures (A07)
     */
    public function test_check_auth_failures(): void
    {
        Config::set('session.secure', true);
        Config::set('session.http_only', true);

        $result = $this->complianceService->checkAuthFailures();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking integrity failures (A08)
     */
    public function test_check_integrity_failures(): void
    {
        $result = $this->complianceService->checkIntegrityFailures();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking logging failures (A09)
     */
    public function test_check_logging_failures(): void
    {
        Config::set('logging.default', 'stack');

        $result = $this->complianceService->checkLoggingFailures();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking SSRF (A10)
     */
    public function test_check_ssrf(): void
    {
        $result = $this->complianceService->checkSSRF();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test GDPR compliance check
     */
    public function test_check_gdpr_compliance(): void
    {
        $result = $this->complianceService->checkGDPRCompliance();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliance_percentage', $result);
        $this->assertArrayHasKey('passed', $result);
        $this->assertArrayHasKey('total', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertEquals(7, $result['total']);
    }

    /**
     * Test checking data minimization
     */
    public function test_check_data_minimization(): void
    {
        $result = $this->complianceService->checkDataMinimization();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking right to access
     */
    public function test_check_right_to_access(): void
    {
        $result = $this->complianceService->checkRightToAccess();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking right to erasure
     */
    public function test_check_right_to_erasure(): void
    {
        $result = $this->complianceService->checkRightToErasure();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking right to portability
     */
    public function test_check_right_to_portability(): void
    {
        $result = $this->complianceService->checkRightToPortability();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking consent management
     */
    public function test_check_consent_management(): void
    {
        $result = $this->complianceService->checkConsentManagement();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking data breach notification
     */
    public function test_check_data_breach_notification(): void
    {
        $result = $this->complianceService->checkDataBreachNotification();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking data protection by design
     */
    public function test_check_data_protection_by_design(): void
    {
        $result = $this->complianceService->checkDataProtectionByDesign();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking best practices
     */
    public function test_check_best_practices(): void
    {
        Config::set('session.lifetime', 60);
        Config::set('session.expire_on_close', false);

        $result = $this->complianceService->checkBestPractices();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliance_percentage', $result);
        $this->assertArrayHasKey('passed', $result);
        $this->assertArrayHasKey('total', $result);
        $this->assertArrayHasKey('checks', $result);
        $this->assertEquals(7, $result['total']);
    }

    /**
     * Test checking password policy
     */
    public function test_check_password_policy(): void
    {
        $result = $this->complianceService->checkPasswordPolicy();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking session management
     */
    public function test_check_session_management(): void
    {
        Config::set('session.lifetime', 60);
        Config::set('session.expire_on_close', false);

        $result = $this->complianceService->checkSessionManagement();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking API security
     */
    public function test_check_api_security(): void
    {
        $result = $this->complianceService->checkAPISecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking file upload security
     */
    public function test_check_file_upload_security(): void
    {
        $result = $this->complianceService->checkFileUploadSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking error handling
     */
    public function test_check_error_handling(): void
    {
        Config::set('app.debug', false);

        $result = $this->complianceService->checkErrorHandling();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking backup security
     */
    public function test_check_backup_security(): void
    {
        $result = $this->complianceService->checkBackupSecurity();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test checking dependency management
     */
    public function test_check_dependency_management(): void
    {
        $result = $this->complianceService->checkDependencyManagement();

        $this->assertIsArray($result);
        $this->assertArrayHasKey('compliant', $result);
        $this->assertArrayHasKey('findings', $result);
        $this->assertArrayHasKey('recommendations', $result);
    }

    /**
     * Test compliance scores calculation
     */
    public function test_calculate_compliance_scores(): void
    {
        $result = $this->complianceService->runComplianceCheck();

        $this->assertArrayHasKey('summary', $result);
        $this->assertArrayHasKey('overall_compliance', $result['summary']);
        $this->assertArrayHasKey('owasp_compliance', $result['summary']);
        $this->assertArrayHasKey('gdpr_compliance', $result['summary']);
        $this->assertArrayHasKey('best_practices_compliance', $result['summary']);
        $this->assertArrayHasKey('grade', $result['summary']);

        $this->assertGreaterThanOrEqual(0, $result['summary']['overall_compliance']);
        $this->assertLessThanOrEqual(100, $result['summary']['overall_compliance']);

        $this->assertContains($result['summary']['grade'], ['A', 'B', 'C', 'D', 'F']);
    }
}
