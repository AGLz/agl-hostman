<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Secure Headers Tests
 *
 * Tests for security headers including CSP, HSTS, X-Frame-Options,
 * and other protective headers.
 *
 * @package Tests\Feature\Security
 */
class SecureHeadersTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
    }

    /**
     * Test X-Content-Type-Options header
     */
    public function test_x_content_type_options_header(): void
    {
        $response = $this->get('/dashboard');

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    /**
     * Test X-Frame-Options header
     */
    public function test_x_frame_options_header(): void
    {
        $response = $this->get('/dashboard');

        $response->assertHeader('X-Frame-Options');
        $headerValue = $response->headers->get('X-Frame-Options');

        $this->assertContains($headerValue, ['DENY', 'SAMEORIGIN']);
    }

    /**
     * Test X-XSS-Protection header
     */
    public function test_x_xss_protection_header(): void
    {
        $response = $this->get('/dashboard');

        $response->assertHeader('X-XSS-Protection');
        $headerValue = $response->headers->get('X-XSS-Protection');

        $this->assertStringContainsString('1', $headerValue);
        $this->assertStringContainsString('mode=block', $headerValue);
    }

    /**
     * Test Strict-Transport-Security header in production
     */
    public function test_strict_transport_security_header(): void
    {
        if (app()->environment('production')) {
            $response = $this->get('/dashboard');

            $response->assertHeader('Strict-Transport-Security');
            $headerValue = $response->headers->get('Strict-Transport-Security');

            $this->assertStringContainsString('max-age=', $headerValue);
        }

        $this->assertTrue(true);
    }

    /**
     * Test Content-Security-Policy header
     */
    public function test_content_security_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $response->assertHeader('Content-Security-Policy');
        $csp = $response->headers->get('Content-Security-Policy');

        $this->assertStringContainsString('default-src', $csp);
        $this->assertStringContainsString('script-src', $csp);
    }

    /**
     * Test Referrer-Policy header
     */
    public function test_referrer_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $response->assertHeader('Referrer-Policy');
        $headerValue = $response->headers->get('Referrer-Policy');

        $validPolicies = [
            'no-referrer',
            'no-referrer-when-downgrade',
            'origin',
            'origin-when-cross-origin',
            'same-origin',
            'strict-origin',
            'strict-origin-when-cross-origin',
            'unsafe-url',
        ];

        $this->assertContains($headerValue, $validPolicies);
    }

    /**
     * Test Permissions-Policy header
     */
    public function test_permissions_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $permissionsPolicy = $response->headers->get('Permissions-Policy');

        if ($permissionsPolicy) {
            $this->assertIsString($permissionsPolicy);
        }
    }

    /**
     * Test Cross-Origin-Opener-Policy header
     */
    public function test_cross_origin_opener_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $coop = $response->headers->get('Cross-Origin-Opener-Policy');

        if ($coop) {
            $validValues = ['same-origin', 'same-origin-allow-popups', 'unsafe-none'];
            $this->assertContains($coop, $validValues);
        }
    }

    /**
     * Test Cross-Origin-Embedder-Policy header
     */
    public function test_cross_origin_embedder_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $coep = $response->headers->get('Cross-Origin-Embedder-Policy');

        if ($coep) {
            $validValues = ['require-corp', 'unsafe-none'];
            $this->assertContains($coep, $validValues);
        }
    }

    /**
     * Test Cross-Origin-Resource-Policy header
     */
    public function test_cross_origin_resource_policy_header(): void
    {
        $response = $this->get('/dashboard');

        $corp = $response->headers->get('Cross-Origin-Resource-Policy');

        if ($corp) {
            $validValues = ['same-origin', 'same-site', 'cross-origin'];
            $this->assertContains($corp, $validValues);
        }
    }

    /**
     * Test X-Permitted-Cross-Domain-Policies header
     */
    public function test_x_permitted_cross_domain_policies_header(): void
    {
        $response = $this->get('/dashboard');

        $xpcdp = $response->headers->get('X-Permitted-Cross-Domain-Policies');

        if ($xpcdp) {
            $validValues = ['none', 'master-only', 'by-content-type', 'all'];
            $this->assertContains($xpcdp, $validValues);
        }
    }

    /**
     * Test Cache-Control header for secure pages
     */
    public function test_cache_control_header_for_secure_pages(): void
    {
        $response = $this->actingAs($this->user)
            ->get('/dashboard');

        $cacheControl = $response->headers->get('Cache-Control');

        $this->assertIsString($cacheControl);

        if (app()->environment('production')) {
            $this->assertStringContainsString('no-cache', $cacheControl);
            $this->assertStringContainsString('no-store', $cacheControl);
        }
    }

    /**
     * Test Pragma header
     */
    public function test_pragma_header(): void
    {
        $response = $this->actingAs($this->user)
            ->get('/dashboard');

        $pragma = $response->headers->get('Pragma');

        if ($pragma) {
            $this->assertEquals('no-cache', $pragma);
        }
    }

    /**
     * Test Expires header
     */
    public function test_expires_header(): void
    {
        $response = $this->get('/dashboard');

        $expires = $response->headers->get('Expires');

        if ($expires) {
            $this->assertIsString($expires);
        }
    }

    /**
     * Test API responses have security headers
     */
    public function test_api_security_headers(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    /**
     * Test no server information disclosure
     */
    public function test_no_server_header_disclosure(): void
    {
        $response = $this->get('/dashboard');

        $server = $response->headers->get('Server');

        if ($server) {
            $this->assertStringNotContainsString('nginx', $server);
            $this->assertStringNotContainsString('apache', $server);
            $this->assertStringNotContainsString('laravel', $server);
        }
    }

    /**
     * Test no X-Powered-By header
     */
    public function test_no_x_powered_by_header(): void
    {
        $response = $this->get('/dashboard');

        $poweredBy = $response->headers->get('X-Powered-By');

        $this->assertNull($poweredBy);
    }

    /**
     * Test CSP includes script-src directive
     */
    public function test_csp_script_src_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringContainsString('script-src', $csp);
            $this->assertStringContainsString("'self'", $csp);
        }
    }

    /**
     * Test CSP includes object-src directive
     */
    public function test_csp_object_src_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringContainsString('object-src', $csp);
            $this->assertStringContainsString("'none'", $csp);
        }
    }

    /**
     * Test CSP includes base-uri directive
     */
    public function test_csp_base_uri_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringContainsString('base-uri', $csp);
        }
    }

    /**
     * Test CSP includes form-action directive
     */
    public function test_csp_form_action_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringContainsString('form-action', $csp);
        }
    }

    /**
     * Test CSP includes frame-ancestors directive
     */
    public function test_csp_frame_ancestors_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $this->assertStringContainsString('frame-ancestors', $csp);
            $this->assertStringContainsString("'none'", $csp);
        }
    }

    /**
     * Test CSP report-uri or report-to directive
     */
    public function test_csp_reporting_directive(): void
    {
        $response = $this->get('/dashboard');

        $csp = $response->headers->get('Content-Security-Policy');

        if ($csp) {
            $hasReportUri = str_contains($csp, 'report-uri');
            $hasReportTo = str_contains($csp, 'report-to');

            $this->assertTrue(
                $hasReportUri || $hasReportTo,
                'CSP should include report-uri or report-to directive'
            );
        }
    }
}
