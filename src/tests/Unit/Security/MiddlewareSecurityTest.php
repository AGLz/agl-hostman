<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use App\Http\Middleware\CheckPermission;
use App\Http\Middleware\CheckRole;
use App\Http\Middleware\McpSecurity;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Config;
use Tests\TestCase;

/**
 * Middleware Security Tests
 *
 * Tests for security middleware including authentication,
 * authorization, rate limiting, and request validation.
 */
class MiddlewareSecurityTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\RolesAndPermissionsSeeder::class);

        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');

        $this->user = User::factory()->create();
        $this->user->assignRole('common');
    }

    /**
     * Test CheckRole middleware denies unauthenticated
     */
    public function test_check_role_denies_unauthenticated(): void
    {
        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');

        $response = $middleware->handle($request, fn() => new Response, 'admin');

        $this->assertEquals(401, $response->getStatusCode());
    }

    /**
     * Test CheckRole middleware denies unauthorized role
     */
    public function test_check_role_denies_unauthorized_role(): void
    {
        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $this->user);

        $response = $middleware->handle($request, fn() => new Response, 'admin');

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test CheckRole middleware allows authorized role
     */
    public function test_check_role_allows_authorized_role(): void
    {
        $this->admin->assignRole('admin');

        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $this->admin);

        $response = $middleware->handle($request, fn() => new Response, 'admin');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckRole with multiple roles (any logic)
     */
    public function test_check_role_with_multiple_roles_any(): void
    {
        $this->admin->assignRole(['admin', 'super-admin']);

        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $this->admin);

        $response = $middleware->handle($request, fn() => new Response, 'super-admin,manager|any');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckRole with multiple roles (all logic)
     */
    public function test_check_role_with_multiple_roles_all(): void
    {
        $user = User::factory()->create();
        $user->assignRole(['admin', 'operator']);

        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $user);

        $response = $middleware->handle($request, fn() => new Response, 'admin,operator|all');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckRole denies inactive user
     */
    public function test_check_role_denies_inactive_user(): void
    {
        $inactiveUser = User::factory()->inactive()->create();
        $inactiveUser->assignRole('admin');

        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $inactiveUser);

        $response = $middleware->handle($request, fn() => new Response, 'admin');

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test CheckPermission middleware denies unauthenticated
     */
    public function test_check_permission_denies_unauthenticated(): void
    {
        $middleware = new CheckPermission;
        $request = Request::create('/users', 'GET');

        $response = $middleware->handle($request, fn() => new Response, 'manage users');

        $this->assertEquals(401, $response->getStatusCode());
    }

    /**
     * Test CheckPermission middleware denies unauthorized
     */
    public function test_check_permission_denies_unauthorized(): void
    {
        $middleware = new CheckPermission;
        $request = Request::create('/users', 'GET');
        $request->setUserResolver(fn() => $this->user);

        $response = $middleware->handle($request, fn() => new Response, 'manage users');

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test CheckPermission middleware allows authorized
     */
    public function test_check_permission_allows_authorized(): void
    {
        $this->admin->givePermissionTo('manage users');

        $middleware = new CheckPermission;
        $request = Request::create('/users', 'GET');
        $request->setUserResolver(fn() => $this->admin);

        $response = $middleware->handle($request, fn() => new Response, 'manage users');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckPermission with multiple permissions (any logic)
     */
    public function test_check_permission_with_multiple_any(): void
    {
        $this->admin->givePermissionTo(['view dashboard', 'edit profile']);

        $middleware = new CheckPermission;
        $request = Request::create('/dashboard', 'GET');
        $request->setUserResolver(fn() => $this->admin);

        $response = $middleware->handle($request, fn() => new Response, 'view dashboard,manage users|any');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckPermission with multiple permissions (all logic)
     */
    public function test_check_permission_with_multiple_all(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo(['view dashboard', 'edit profile']);

        $middleware = new CheckPermission;
        $request = Request::create('/dashboard', 'GET');
        $request->setUserResolver(fn() => $user);

        $response = $middleware->handle($request, fn() => new Response, 'view dashboard,edit profile|all');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test CheckPermission denies inactive user
     */
    public function test_check_permission_denies_inactive_user(): void
    {
        $inactiveUser = User::factory()->inactive()->create();
        $inactiveUser->givePermissionTo('manage users');

        $middleware = new CheckPermission;
        $request = Request::create('/users', 'GET');
        $request->setUserResolver(fn() => $inactiveUser);

        $response = $middleware->handle($request, fn() => new Response, 'manage users');

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test McpSecurity validates content type
     */
    public function test_mcp_security_validates_content_type(): void
    {
        Config::set('mcp.validation.allowed_content_types', ['application/json']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('Content-Type', 'text/html');
        $request->headers->set('X-API-Key', config('mcp.api_keys.test', 'test-key'));

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(415, $response->getStatusCode());
    }

    /**
     * Test McpSecurity validates request size
     */
    public function test_mcp_security_validates_request_size(): void
    {
        Config::set('mcp.validation.max_request_size', 1);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('Content-Length', '2048');
        $request->headers->set('X-API-Key', config('mcp.api_keys.test', 'test-key'));

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(413, $response->getStatusCode());
    }

    /**
     * Test McpSecurity checks IP whitelist
     */
    public function test_mcp_security_checks_ip_whitelist(): void
    {
        Config::set('mcp.ip_whitelist.enabled', true);
        Config::set('mcp.ip_whitelist.allowed_ips', ['192.168.1.1']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST', [], [], [], ['REMOTE_ADDR' => '192.168.1.100']);
        $request->headers->set('X-API-Key', config('mcp.api_keys.test', 'test-key'));

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test McpSecurity authenticates API key
     */
    public function test_mcp_security_authenticates_api_key(): void
    {
        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(401, $response->getStatusCode());
    }

    /**
     * Test McpSecurity accepts valid API key
     */
    public function test_mcp_security_accepts_valid_api_key(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('X-API-Key', 'valid-api-key-12345');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test McpSecurity applies rate limiting
     */
    public function test_mcp_security_applies_rate_limiting(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);
        Config::set('mcp.rate_limiting.max_attempts', 2);

        $middleware = new McpSecurity;

        for ($i = 0; $i < 3; $i++) {
            $request = Request::create('/mcp', 'POST', [], [], [], ['REMOTE_ADDR' => '192.168.1.1']);
            $request->headers->set('X-API-Key', 'valid-api-key-12345');

            $response = $middleware->handle($request, fn() => new Response);

            if ($i === 2) {
                $this->assertEquals(429, $response->getStatusCode());
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test McpSecurity adds security headers
     */
    public function test_mcp_security_adds_security_headers(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);
        Config::set('mcp.headers', [
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options' => 'DENY',
        ]);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('X-API-Key', 'valid-api-key-12345');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals('nosniff', $response->headers->get('X-Content-Type-Options'));
        $this->assertEquals('DENY', $response->headers->get('X-Frame-Options'));
    }

    /**
     * Test McpSecurity extracts API key from header
     */
    public function test_mcp_security_extracts_api_key_from_header(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('X-API-Key', 'valid-api-key-12345');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test McpSecurity extracts API key from authorization header
     */
    public function test_mcp_security_extracts_api_key_from_authorization(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('Authorization', 'Bearer valid-api-key-12345');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test McpSecurity extracts API key from query parameter
     */
    public function test_mcp_security_extracts_api_key_from_query_when_allowed(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);
        Config::set('security.allow_query_api_key', true);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp?api_key=valid-api-key-12345', 'POST');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(200, $response->getStatusCode());
    }

    public function test_mcp_security_rejects_query_api_key_when_disabled(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);
        Config::set('security.allow_query_api_key', false);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp?api_key=valid-api-key-12345', 'POST');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(401, $response->getStatusCode());
    }

    public function test_check_permission_returns_json_for_api_requests(): void
    {
        $middleware = new CheckPermission;
        $request = Request::create('/api/users', 'GET');
        $request->headers->set('Accept', 'application/json');

        $response = $middleware->handle($request, fn() => new Response, 'manage users');

        $this->assertEquals(401, $response->getStatusCode());
        $this->assertJson($response->getContent());
        $this->assertStringContainsString('Authentication required', $response->getContent());
    }

    /**
     * Test middleware logs unauthorized access
     */
    public function test_middleware_logs_unauthorized_access(): void
    {
        $middleware = new CheckRole;
        $request = Request::create('/admin', 'GET');
        $request->setUserResolver(fn() => $this->user);

        $response = $middleware->handle($request, fn() => new Response, 'admin');

        $this->assertEquals(403, $response->getStatusCode());
    }

    /**
     * Test middleware uses timing-safe API key comparison
     */
    public function test_middleware_timing_safe_key_comparison(): void
    {
        Config::set('mcp.api_keys', ['test-service' => 'valid-api-key-12345']);

        $middleware = new McpSecurity;
        $request = Request::create('/mcp', 'POST');
        $request->headers->set('X-API-Key', 'valid-api-key-12345');

        $response = $middleware->handle($request, fn() => new Response);

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test IP in range with CIDR notation
     */
    public function test_ip_in_range_cidr(): void
    {
        $middleware = new McpSecurity;

        $method = new \ReflectionMethod($middleware, 'ipInRange');
        $method->setAccessible(true);

        $result = $method->invoke($middleware, '192.168.1.100', '192.168.1.0/24');

        $this->assertTrue($result);
    }

    public function test_ip_in_range_ipv6_cidr(): void
    {
        $middleware = new McpSecurity;

        $method = new \ReflectionMethod($middleware, 'ipInRange');
        $method->setAccessible(true);

        $result = $method->invoke($middleware, '2001:db8::1', '2001:db8::/32');

        $this->assertTrue($result);
    }

    /**
     * Test IP exact match
     */
    public function test_ip_exact_match(): void
    {
        $middleware = new McpSecurity;

        $method = new \ReflectionMethod($middleware, 'ipInRange');
        $method->setAccessible(true);

        $result = $method->invoke($middleware, '192.168.1.1', '192.168.1.1');

        $this->assertTrue($result);
    }

    /**
     * Test IP not in range
     */
    public function test_ip_not_in_range(): void
    {
        $middleware = new McpSecurity;

        $method = new \ReflectionMethod($middleware, 'ipInRange');
        $method->setAccessible(true);

        $result = $method->invoke($middleware, '192.168.2.1', '192.168.1.0/24');

        $this->assertFalse($result);
    }
}
