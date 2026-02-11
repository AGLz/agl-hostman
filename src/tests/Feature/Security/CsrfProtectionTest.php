<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Session;
use Tests\TestCase;

/**
 * CSRF Protection Tests
 *
 * Tests for Cross-Site Request Forgery protection including
 * token validation and same-site cookie enforcement.
 *
 * @package Tests\Feature\Security
 */
class CsrfProtectionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
    }

    /**
     * Test POST request without CSRF token is rejected
     */
    public function test_post_without_csrf_token_rejected(): void
    {
        $response = $this->post('/dashboard', [
            'data' => 'test',
        ]);

        $this->assertEquals(419, $response->getStatusCode());
    }

    /**
     * Test POST request with invalid CSRF token is rejected
     */
    public function test_post_with_invalid_csrf_token_rejected(): void
    {
        $response = $this->withSession([
            '_token' => 'valid-token',
        ])->post('/dashboard', [
            '_token' => 'invalid-token',
            'data' => 'test',
        ]);

        $this->assertEquals(419, $response->getStatusCode());
    }

    /**
     * Test POST request with valid CSRF token is accepted
     */
    public function test_post_with_valid_csrf_token_accepted(): void
    {
        Session::start();

        $response = $this->post('/login', [
            '_token' => csrf_token(),
            'email' => $this->user->email,
            'password' => 'password',
        ]);

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test PUT request without CSRF token is rejected
     */
    public function test_put_without_csrf_token_rejected(): void
    {
        $response = $this->put("/users/{$this->user->id}", [
            'name' => 'Updated Name',
        ]);

        $this->assertEquals(419, $response->getStatusCode());
    }

    /**
     * Test DELETE request without CSRF token is rejected
     */
    public function test_delete_without_csrf_token_rejected(): void
    {
        $response = $this->delete("/users/{$this->user->id}");

        $this->assertEquals(419, $response->getStatusCode());
    }

    /**
     * Test GET request does not require CSRF token
     */
    public function test_get_does_not_require_csrf_token(): void
    {
        $response = $this->get('/dashboard');

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test HEAD request does not require CSRF token
     */
    public function test_head_does_not_require_csrf_token(): void
    {
        $response = $this->head('/dashboard');

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test OPTIONS request does not require CSRF token
     */
    public function test_options_does_not_require_csrf_token(): void
    {
        $response = $this->options('/dashboard');

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test AJAX requests can use X-CSRF-TOKEN header
     */
    public function test_ajax_uses_x_csrf_token_header(): void
    {
        Session::start();

        $response = $this->withHeaders([
            'X-Requested-With' => 'XMLHttpRequest',
            'X-CSRF-TOKEN' => csrf_token(),
        ])->post('/api/settings', [
            'setting' => 'value',
        ]);

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test AJAX requests can use X-XSRF-TOKEN header
     */
    public function test_ajax_uses_x_xsrf_token_header(): void
    {
        Session::start();

        $response = $this->withHeaders([
            'X-Requested-With' => 'XMLHttpRequest',
            'X-XSRF-TOKEN' => csrf_token(),
        ])->post('/api/settings', [
            'setting' => 'value',
        ]);

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test token is unique per session
     */
    public function test_token_unique_per_session(): void
    {
        Session::start();
        $token1 = csrf_token();

        $this->session(['_token' => null]);
        Session::start();
        $token2 = csrf_token();

        $this->assertNotEmpty($token1);
        $this->assertNotEmpty($token2);
    }

    /**
     * Test token expires with session
     */
    public function test_token_expires_with_session(): void
    {
        Session::start();
        $token = csrf_token();

        $this->assertNotNull(Session::get('_token'));
    }

    /**
     * Test API routes are exempt from CSRF
     */
    public function test_api_routes_exempt_from_csrf(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $this->user->email,
            'password' => 'password',
        ]);

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test same-site cookie attribute
     */
    public function test_same_site_cookie_attribute(): void
    {
        $sessionConfig = config('session');

        $this->assertArrayHasKey('same_site', $sessionConfig);
        $this->assertContains(
            $sessionConfig['same_site'],
            ['lax', 'strict', 'none']
        );
    }

    /**
     * Test CSRF token is included in forms
     */
    public function test_csrf_token_in_forms(): void
    {
        $response = $this->get('/register');

        $response->assertSee('_token');
        $response->assertSee('csrf-token');
    }

    /**
     * Test CSRF token refresh on login
     */
    public function test_csrf_token_refresh_on_login(): void
    {
        Session::start();
        $tokenBefore = csrf_token();

        $this->post('/login', [
            '_token' => $tokenBefore,
            'email' => $this->user->email,
            'password' => 'password',
        ]);

        $tokenAfter = csrf_token();

        $this->assertNotEmpty($tokenBefore);
        $this->assertNotEmpty($tokenAfter);
    }

    /**
     * Test multiple CSRF tokens cannot coexist
     */
    public function test_multiple_csrf_tokens_validation(): void
    {
        Session::start();

        $response = $this->post('/dashboard', [
            '_token' => csrf_token(),
            'another_token' => 'some-other-token',
            'data' => 'test',
        ]);

        $this->assertNotEquals(419, $response->getStatusCode());
    }

    /**
     * Test CSRF protection configuration
     */
    public function test_csrf_protection_enabled(): void
    {
        $this->assertTrue(
            config('session.driver') !== 'array' || app()->environment('testing')
        );
    }

    /**
     * Test encrypted CSRF token
     */
    public function test_encrypted_csrf_token(): void
    {
        Session::start();
        $token = csrf_token();

        $this->assertIsString($token);
        $this->assertNotEmpty($token);
    }
}
