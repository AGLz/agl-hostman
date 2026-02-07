<?php

declare(strict_types=1);

namespace Tests\Unit\Middleware;

use App\Http\Middleware\SecurityHeaders;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Tests\TestCase;

/**
 * Security Headers Middleware Test
 *
 * Tests for the SecurityHeaders middleware.
 *
 * @package Tests\Unit\Middleware
 */
class SecurityHeadersMiddlewareTest extends TestCase
{
    /**
     * Test security headers are added to response
     */
    public function test_security_headers_added(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertEquals('nosniff', $response->headers->get('X-Content-Type-Options'));
        $this->assertEquals('DENY', $response->headers->get('X-Frame-Options'));
        $this->assertEquals('1; mode=block', $response->headers->get('X-XSS-Protection'));
        $this->assertNotEmpty($response->headers->get('Strict-Transport-Security'));
        $this->assertNotEmpty($response->headers->get('Content-Security-Policy'));
        $this->assertNotEmpty($response->headers->get('Referrer-Policy'));
    }

    /**
     * Test X-Content-Type-Options header
     */
    public function test_x_content_type_options_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertEquals('nosniff', $response->headers->get('X-Content-Type-Options'));
    }

    /**
     * Test X-Frame-Options header
     */
    public function test_x_frame_options_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertEquals('DENY', $response->headers->get('X-Frame-Options'));
    }

    /**
     * Test X-XSS-Protection header
     */
    public function test_x_xss_protection_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertEquals('1; mode=block', $response->headers->get('X-XSS-Protection'));
    }

    /**
     * Test Strict-Transport-Security header
     */
    public function test_strict_transport_security_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $hsts = $response->headers->get('Strict-Transport-Security');

        $this->assertNotEmpty($hsts);
        $this->assertStringContainsString('max-age=', $hsts);
        $this->assertStringContainsString('includeSubDomains', $hsts);
        $this->assertStringContainsString('preload', $hsts);
    }

    /**
     * Test Content-Security-Policy header
     */
    public function test_content_security_policy_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $csp = $response->headers->get('Content-Security-Policy');

        $this->assertNotEmpty($csp);
        $this->assertStringContainsString("default-src 'self'", $csp);
        $this->assertStringContainsString("script-src 'self'", $csp);
        $this->assertStringContainsString("style-src 'self'", $csp);
        $this->assertStringContainsString("frame-ancestors 'none'", $csp);
    }

    /**
     * Test Referrer-Policy header
     */
    public function test_referrer_policy_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertNotEmpty($response->headers->get('Referrer-Policy'));
        $this->assertEquals('strict-origin-when-cross-origin', $response->headers->get('Referrer-Policy'));
    }

    /**
     * Test Permissions-Policy header
     */
    public function test_permissions_policy_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $permissions = $response->headers->get('Permissions-Policy');

        $this->assertNotEmpty($permissions);
        $this->assertStringContainsString('geolocation=', $permissions);
        $this->assertStringContainsString('microphone=', $permissions);
    }

    /**
     * Test X-Permitted-Cross-Domain-Policies header
     */
    public function test_x_permitted_cross_domain_policies_header(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertEquals('none', $response->headers->get('X-Permitted-Cross-Domain-Policies'));
    }

    /**
     * Test server information is removed
     */
    public function test_server_information_removed(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $this->assertNull($response->headers->get('X-Powered-By'));
        $this->assertNull($response->headers->get('Server'));
    }

    /**
     * Test middleware does not modify existing headers
     */
    public function test_does_not_modify_existing_headers(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $existingResponse = new Response('Content');
        $existingResponse->headers->set('X-Custom-Header', 'custom-value');

        $response = $middleware->handle($request, fn () => $existingResponse);

        $this->assertEquals('custom-value', $response->headers->get('X-Custom-Header'));
    }

    /**
     * Test CSP allows images from data URLs
     */
    public function test_csp_allows_data_images(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $csp = $response->headers->get('Content-Security-Policy');

        $this->assertStringContainsString("img-src 'self' data:", $csp);
    }

    /**
     * Test CSP allows fonts from data URLs
     */
    public function test_csp_allows_data_fonts(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Content'));

        $csp = $response->headers->get('Content-Security-Policy');

        $this->assertStringContainsString("font-src 'self' data:", $csp);
    }

    /**
     * Test middleware applies to API routes
     */
    public function test_applies_to_api_routes(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/api/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('API Content'));

        $this->assertNotNull($response->headers->get('Strict-Transport-Security'));
        $this->assertNotNull($response->headers->get('Content-Security-Policy'));
    }

    /**
     * Test middleware applies to web routes
     */
    public function test_applies_to_web_routes(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = $middleware->handle($request, fn () => new Response('Web Content'));

        $this->assertNotNull($response->headers->get('Strict-Transport-Security'));
        $this->assertNotNull($response->headers->get('Content-Security-Policy'));
    }

    /**
     * Test multiple middleware calls don't duplicate headers
     */
    public function test_multiple_calls_dont_duplicate_headers(): void
    {
        $middleware = new SecurityHeaders();
        $request = Request::create('/test', 'GET');

        $response = new Response('Content');

        // Apply middleware twice
        $response = $middleware->handle($request, fn () => $response);

        $csp1 = $response->headers->get('Content-Security-Policy');

        $response = $middleware->handle($request, fn () => $response);

        $csp2 = $response->headers->get('Content-Security-Policy');

        // CSP should be the same (not duplicated)
        $this->assertEquals($csp1, $csp2);
    }
}
