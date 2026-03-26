<?php

declare(strict_types=1);

namespace Tests\Unit\Middleware;

use App\Http\Middleware\RateLimiting;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Symfony\Component\HttpFoundation\Response;
use Tests\TestCase;

/**
 * Rate Limiting Middleware Test
 *
 * Tests for the RateLimiting middleware.
 */
class RateLimitingMiddlewareTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
    }

    /**
     * Test rate limiting applies to authenticated users
     */
    public function test_rate_limits_authenticated_user(): void
    {
        $user = User::factory()->create();
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->setUserResolver(fn () => $user);

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 5,
            'decay_minutes' => 1,
        ]);

        // First 5 requests should pass
        for ($i = 0; $i < 5; $i++) {
            $response = $middleware->handle($request, fn () => new Response('OK'));
            $this->assertEquals(200, $response->getStatusCode());
        }

        // 6th request should be rate limited
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(429, $response->getStatusCode());
    }

    /**
     * Test rate limiting applies to unauthenticated users by IP
     */
    public function test_rate_limits_unauthenticated_user_by_ip(): void
    {
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->server->set('REMOTE_ADDR', '192.168.1.1');

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 3,
            'decay_minutes' => 1,
        ]);

        // First 3 requests should pass
        for ($i = 0; $i < 3; $i++) {
            $response = $middleware->handle($request, fn () => new Response('OK'));
            $this->assertEquals(200, $response->getStatusCode());
        }

        // 4th request should be rate limited
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(429, $response->getStatusCode());
    }

    /**
     * Test different rate limit types
     */
    public function test_different_rate_limit_types(): void
    {
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->server->set('REMOTE_ADDR', '192.168.1.2');

        // Test strict rate limit
        Config::set('middleware.rate_limiting.strict', [
            'max_attempts' => 2,
            'decay_minutes' => 1,
        ]);

        $request->attributes->set('rate_limit_type', 'strict');

        // First 2 requests should pass
        for ($i = 0; $i < 2; $i++) {
            $response = $middleware->handle($request, fn () => new Response('OK'));
            $this->assertEquals(200, $response->getStatusCode());
        }

        // 3rd request should be rate limited
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(429, $response->getStatusCode());
    }

    /**
     * Test rate limit headers are added
     */
    public function test_rate_limit_headers_added(): void
    {
        $user = User::factory()->create();
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->setUserResolver(fn () => $user);

        Config::set('middleware.rate_limiting.api', [
            'max_attempts' => 10,
            'decay_minutes' => 1,
        ]);

        $response = $middleware->handle($request, fn () => new Response('OK'));

        $this->assertArrayHasKey('X-RateLimit-Limit', $response->headers->all());
        $this->assertArrayHasKey('X-RateLimit-Remaining', $response->headers->all());
        $this->assertArrayHasKey('X-RateLimit-Reset', $response->headers->all());
    }

    /**
     * Test rate limit response format
     */
    public function test_rate_limit_response_format(): void
    {
        $user = User::factory()->create();
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->setUserResolver(fn () => $user);

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 1,
            'decay_minutes' => 1,
        ]);

        // First request passes
        $middleware->handle($request, fn () => new Response('OK'));

        // Second request hits rate limit
        $response = $middleware->handle($request, fn () => new Response('OK'));

        $this->assertEquals(429, $response->getStatusCode());
        $this->assertArrayHasKey('error', json_decode($response->getContent(), true));
        $this->assertArrayHasKey('retry_after', json_decode($response->getContent(), true));
    }

    /**
     * Test rate limit key generation
     */
    public function test_rate_limit_key_generation(): void
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();

        $middleware = new RateLimiting;

        $request1 = Request::create('/api/test', 'GET');
        $request1->setUserResolver(fn () => $user1);

        $request2 = Request::create('/api/test', 'GET');
        $request2->setUserResolver(fn () => $user2);

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 2,
            'decay_minutes' => 1,
        ]);

        // User 1 makes 2 requests
        $middleware->handle($request1, fn () => new Response('OK'));
        $middleware->handle($request1, fn () => new Response('OK'));

        // User 1 should be rate limited
        $response1 = $middleware->handle($request1, fn () => new Response('OK'));
        $this->assertEquals(429, $response1->getStatusCode());

        // User 2 should still be able to make requests
        $response2 = $middleware->handle($request2, fn () => new Response('OK'));
        $this->assertEquals(200, $response2->getStatusCode());
    }

    /**
     * Test rate limit decay after time
     */
    public function test_rate_limit_decay_after_time(): void
    {
        $user = User::factory()->create();
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->setUserResolver(fn () => $user);

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 2,
            'decay_minutes' => 1,
        ]);

        // Make 2 requests
        $middleware->handle($request, fn () => new Response('OK'));
        $middleware->handle($request, fn () => new Response('OK'));

        // Should be rate limited
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(429, $response->getStatusCode());

        // Simulate time passing (clear cache)
        Cache::flush();

        // Should now be able to make requests again
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test per-IP rate limiting for unauthenticated requests
     */
    public function test_per_ip_rate_limiting(): void
    {
        $middleware = new RateLimiting;

        $request1 = Request::create('/api/test', 'GET');
        $request1->server->set('REMOTE_ADDR', '192.168.1.10');

        $request2 = Request::create('/api/test', 'GET');
        $request2->server->set('REMOTE_ADDR', '192.168.1.11');

        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 1,
            'decay_minutes' => 1,
        ]);

        // IP 1 makes 1 request
        $middleware->handle($request1, fn () => new Response('OK'));

        // IP 1 should be rate limited
        $response1 = $middleware->handle($request1, fn () => new Response('OK'));
        $this->assertEquals(429, $response1->getStatusCode());

        // IP 2 should still be able to make requests
        $response2 = $middleware->handle($request2, fn () => new Response('OK'));
        $this->assertEquals(200, $response2->getStatusCode());
    }

    /**
     * Test rate limit bypass for whitelisted IPs
     */
    public function test_rate_limit_whitelist(): void
    {
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->server->set('REMOTE_ADDR', '127.0.0.1');

        Config::set('middleware.rate_limiting.whitelist', ['127.0.0.1']);
        Config::set('middleware.rate_limiting.default', [
            'max_attempts' => 1,
            'decay_minutes' => 1,
        ]);

        // Make many requests - should all pass for whitelisted IP
        for ($i = 0; $i < 10; $i++) {
            $response = $middleware->handle($request, fn () => new Response('OK'));
            $this->assertEquals(200, $response->getStatusCode());
        }
    }

    /**
     * Test rate limit with custom decay time
     */
    public function test_custom_decay_time(): void
    {
        $user = User::factory()->create();
        $middleware = new RateLimiting;
        $request = Request::create('/api/test', 'GET');
        $request->setUserResolver(fn () => $user);

        Config::set('middleware.rate_limiting.auth', [
            'max_attempts' => 2,
            'decay_minutes' => 15,
        ]);

        $request->attributes->set('rate_limit_type', 'auth');

        // Make 2 requests
        $middleware->handle($request, fn () => new Response('OK'));
        $middleware->handle($request, fn () => new Response('OK'));

        // Should be rate limited
        $response = $middleware->handle($request, fn () => new Response('OK'));
        $this->assertEquals(429, $response->getStatusCode());

        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('retry_after', $data);
        $this->assertGreaterThan(0, $data['retry_after']);
    }
}
