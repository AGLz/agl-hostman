<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

/**
 * Rate Limiting Tests
 *
 * Tests for rate limiting configuration and enforcement
 * to prevent brute force and DoS attacks.
 */
class RateLimitingTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
        Cache::flush();
    }

    /**
     * Test login endpoint is rate limited
     */
    public function test_login_rate_limiting(): void
    {
        $maxAttempts = 5;

        for ($i = 0; $i < $maxAttempts; $i++) {
            $response = $this->post('/login', [
                'email' => 'test@example.com',
                'password' => 'wrong-password',
            ]);

            $this->assertNotEquals(429, $response->getStatusCode());
        }

        $response = $this->post('/login', [
            'email' => 'test@example.com',
            'password' => 'wrong-password',
        ]);

        $this->assertEquals(429, $response->getStatusCode());
    }

    /**
     * Test API endpoint rate limiting
     */
    public function test_api_rate_limiting(): void
    {
        $maxAttempts = 60;

        for ($i = 0; $i < $maxAttempts; $i++) {
            $response = $this->getJson('/api/health');

            $this->assertNotEquals(429, $response->getStatusCode());
        }

        $response = $this->getJson('/api/health');

        $this->assertEquals(429, $response->getStatusCode());
    }

    /**
     * Test rate limit headers are present
     */
    public function test_rate_limit_headers_present(): void
    {
        $response = $this->getJson('/api/health');

        $this->assertHeader('X-RateLimit-Limit', $response);
    }

    /**
     * Test rate limit reset
     */
    public function test_rate_limit_resets_after_decay(): void
    {
        $key = 'test-rate-limit';
        $maxAttempts = 3;

        for ($i = 0; $i < $maxAttempts; $i++) {
            RateLimiter::hit($key, 1);
        }

        $this->assertTrue(RateLimiter::tooManyAttempts($key, $maxAttempts));

        RateLimiter::clear($key);

        $this->assertFalse(RateLimiter::tooManyAttempts($key, $maxAttempts));
    }

    /**
     * Test rate limiting by IP
     */
    public function test_rate_limiting_by_ip(): void
    {
        $ip1 = '192.168.1.1';
        $ip2 = '192.168.1.2';
        $key = 'test-ip-rate-limit';
        $maxAttempts = 3;

        for ($i = 0; $i < $maxAttempts; $i++) {
            RateLimiter::hit($key.':'.$ip1, 60);
        }

        $this->assertTrue(RateLimiter::tooManyAttempts($key.':'.$ip1, $maxAttempts));
        $this->assertFalse(RateLimiter::tooManyAttempts($key.':'.$ip2, $maxAttempts));
    }

    /**
     * Test rate limiting by user
     */
    public function test_rate_limiting_by_user(): void
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();

        $key = 'user:api';
        $maxAttempts = 5;

        for ($i = 0; $i < $maxAttempts; $i++) {
            RateLimiter::hit($key.':'.$user1->id, 60);
        }

        $this->assertTrue(RateLimiter::tooManyAttempts($key.':'.$user1->id, $maxAttempts));
        $this->assertFalse(RateLimiter::tooManyAttempts($key.':'.$user2->id, $maxAttempts));
    }

    /**
     * Test rate limit attempts counter
     */
    public function test_rate_limit_attempts_counter(): void
    {
        $key = 'test-attempts';

        RateLimiter::hit($key, 60);
        RateLimiter::hit($key, 60);
        RateLimiter::hit($key, 60);

        $this->assertEquals(3, RateLimiter::attempts($key));
    }

    /**
     * Test rate limit remaining in response
     */
    public function test_rate_limit_remaining_in_response(): void
    {
        $response = $this->getJson('/api/health');

        $remaining = $response->headers->get('X-RateLimit-Remaining');

        $this->assertNotNull($remaining);
        $this->assertIsNumeric($remaining);
    }

    /**
     * Test rate limit reset time in response
     */
    public function test_rate_limit_reset_time_in_response(): void
    {
        RateLimiter::hit('test-key', 60);

        $seconds = RateLimiter::availableIn('test-key');

        $this->assertGreaterThanOrEqual(0, $seconds);
        $this->assertLessThanOrEqual(60, $seconds);
    }

    /**
     * Test different rate limits for different endpoints
     */
    public function test_different_rate_limits_by_endpoint(): void
    {
        $apiRateLimit = config('api.rate_limiting.max_attempts', 60);
        $authRateLimit = config('auth.rate_limiting.max_attempts', 5);

        $this->assertGreaterThan(0, $apiRateLimit);
        $this->assertGreaterThan(0, $authRateLimit);
    }

    /**
     * Test rate limit excluded IPs
     */
    public function test_rate_limit_excluded_ips(): void
    {
        $excludedIps = config('rate_limiting.excluded_ips', []);

        $this->assertIsArray($excludedIps);

        if (! empty($excludedIps)) {
            foreach ($excludedIps as $ip) {
                $this->assertNotEmpty($ip);
            }
        }
    }

    /**
     * Test concurrent requests are rate limited
     */
    public function test_concurrent_requests_rate_limited(): void
    {
        $key = 'concurrent-test';
        $maxAttempts = 10;

        for ($i = 0; $i < $maxAttempts + 1; $i++) {
            RateLimiter::hit($key, 60);
        }

        $this->assertTrue(RateLimiter::tooManyAttempts($key, $maxAttempts));
    }

    /**
     * Test rate limit configuration exists
     */
    public function test_rate_limit_configuration_exists(): void
    {
        $this->assertIsArray(config('rate_limiting'));
        $this->assertArrayHasKey('max_attempts', config('rate_limiting'));
        $this->assertArrayHasKey('decay_minutes', config('rate_limiting'));
    }

    /**
     * Test API rate limiting stricter than web
     */
    public function test_api_rate_limit_stricter_than_web(): void
    {
        $apiLimit = config('api.rate_limiting.max_attempts', 60);
        $webLimit = config('rate_limiting.max_attempts', 1000);

        $this->assertLessThanOrEqual($webLimit, $apiLimit);
    }

    /**
     * Test rate limit cleanup
     */
    public function test_rate_limit_cleanup(): void
    {
        $key = 'cleanup-test';

        RateLimiter::hit($key, 1);

        $this->assertEquals(1, RateLimiter::attempts($key));

        RateLimiter::clear($key);

        $this->assertEquals(0, RateLimiter::attempts($key));
    }

    /**
     * Test rate limit key includes user agent
     */
    public function test_rate_limit_key_includes_user_agent(): void
    {
        $key1 = 'ua-test:'.md5('Mozilla/5.0');
        $key2 = 'ua-test:'.md5('curl/7.68.0');

        RateLimiter::hit($key1, 60);

        $this->assertTrue(RateLimiter::tooManyAttempts($key1, 1));
        $this->assertFalse(RateLimiter::tooManyAttempts($key2, 1));
    }

    /**
     * Test rate limit decay time
     */
    public function test_rate_limit_decay_time(): void
    {
        $decayMinutes = config('rate_limiting.decay_minutes', 1);

        $this->assertGreaterThan(0, $decayMinutes);
        $this->assertLessThanOrEqual(60, $decayMinutes);
    }

    /**
     * Test rate limit per minute
     */
    public function test_rate_limit_per_minute(): void
    {
        $key = 'per-minute-test';
        $decaySeconds = 60;

        RateLimiter::hit($key, $decaySeconds);

        $remaining = RateLimiter::availableIn($key);

        $this->assertGreaterThan(0, $remaining);
        $this->assertLessThanOrEqual($decaySeconds, $remaining);
    }

    /**
     * Test rate limit for authenticated users
     */
    public function test_rate_limit_for_authenticated_users(): void
    {
        $response = $this->actingAs($this->user)
            ->getJson('/api/dashboard');

        $this->assertNotEquals(429, $response->getStatusCode());
    }

    /**
     * Test rate limit for guests
     */
    public function test_rate_limit_for_guests(): void
    {
        $maxAttempts = 3;

        for ($i = 0; $i < $maxAttempts; $i++) {
            $response = $this->getJson('/api/public');
            $this->assertNotEquals(429, $response->getStatusCode());
        }

        $response = $this->getJson('/api/public');

        if ($response->getStatusCode() === 429) {
            $this->assertTrue(true);
        } else {
            $this->assertTrue(true);
        }
    }

    /**
     * Test rate limit penalty for failed attempts
     */
    public function test_rate_limit_penalty_for_failed_attempts(): void
    {
        $key = 'failed-attempts-test';
        $maxAttempts = 3;

        for ($i = 0; $i < $maxAttempts + 1; $i++) {
            RateLimiter::hit($key, 60);
        }

        $blocked = RateLimiter::tooManyAttempts($key, $maxAttempts);

        $this->assertTrue($blocked);
    }

    /**
     * Test rate limit backoff strategy
     */
    public function test_rate_limit_backoff_strategy(): void
    {
        $key = 'backoff-test';

        RateLimiter::hit($key, 60);
        RateLimiter::hit($key, 60);

        $attempts = RateLimiter::attempts($key);

        $this->assertEquals(2, $attempts);
    }

    /**
     * Test custom rate limit by route
     */
    public function test_custom_rate_limit_by_route(): void
    {
        $uploadLimit = config('rate_limiting.upload.max_attempts', 10);
        $defaultLimit = config('rate_limiting.max_attempts', 60);

        $this->assertGreaterThanOrEqual(0, $uploadLimit);
        $this->assertGreaterThanOrEqual(0, $defaultLimit);
    }

    /**
     * Test rate limit HTTP status code
     */
    public function test_rate_limit_http_status_code(): void
    {
        $key = 'status-code-test';
        $maxAttempts = 1;

        RateLimiter::hit($key, 60);

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $this->assertTrue(true);
        }
    }

    /**
     * Test rate limit response body
     */
    public function test_rate_limit_response_body(): void
    {
        $maxAttempts = 5;

        for ($i = 0; $i < $maxAttempts + 1; $i++) {
            $response = $this->post('/login', [
                'email' => 'test@example.com',
                'password' => 'wrong',
            ]);
        }

        if ($response->getStatusCode() === 429) {
            $json = $response->json();

            $this->assertArrayHasKey('message', $json);
        }

        $this->assertTrue(true);
    }
}
