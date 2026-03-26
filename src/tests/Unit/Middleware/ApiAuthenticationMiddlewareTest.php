<?php

declare(strict_types=1);

namespace Tests\Unit\Middleware;

use App\Http\Middleware\ApiAuthentication;
use App\Models\ApiKey;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Request;
use Tests\TestCase;

/**
 * API Authentication Middleware Test
 *
 * Tests for the ApiAuthentication middleware.
 */
class ApiAuthenticationMiddlewareTest extends TestCase
{
    private ApiAuthentication $middleware;

    protected function setUp(): void
    {
        parent::setUp();

        $this->middleware = new ApiAuthentication;
    }

    /**
     * Test successful authentication with valid API key
     */
    public function test_authenticates_with_valid_api_key(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->andReturn(true);

        RateLimiter::shouldReceive('remaining')
            ->once()
            ->andReturn(59);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertEquals('success', $response->getContent());
        $this->assertEquals((string) $apiKey->id, $response->headers->get('X-API-Key-ID'));
    }

    /**
     * Test fails when API key is missing
     */
    public function test_fails_when_api_key_missing(): void
    {
        $request = Request::create('/api/test', 'GET');

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $this->assertJson($response->getContent());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('API key required', $responseData['error']);
    }

    /**
     * Test fails when API key is invalid
     */
    public function test_fails_with_invalid_api_key(): void
    {
        Cache::shouldReceive('remember')
            ->once()
            ->andReturn(null);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', 'invalid-key');

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Invalid API key', $responseData['error']);
    }

    /**
     * Test fails when API key is expired
     */
    public function test_fails_when_api_key_expired(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
            'expires_at' => now()->subDay(),
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        Cache::shouldReceive('forget')
            ->once()
            ->with('api_key:'.substr($apiKey->key, 0, 8));

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('API key expired', $responseData['error']);
    }

    /**
     * Test fails when permission is required but not granted
     */
    public function test_fails_when_permission_required_but_not_granted(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
            'permissions' => ['read'],
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->willReturn(true);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'), 'write');

        $this->assertEquals(403, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Insufficient permissions', $responseData['error']);
    }

    /**
     * Test passes when permission is granted
     */
    public function test_passes_when_permission_granted(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
            'permissions' => ['read', 'write'],
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->willReturn(true);

        RateLimiter::shouldReceive('remaining')
            ->once()
            ->andReturn(59);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'), 'write');

        $this->assertEquals(200, $response->getStatusCode());
    }

    /**
     * Test rate limiting
     */
    public function test_rate_limiting(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
            'rate_limit' => 5,
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->with('api_rate:'.$apiKey->id, 5, \Closure::class, 60)
            ->andReturn(false);

        RateLimiter::shouldReceive('availableIn')
            ->once()
            ->with('api_rate:'.$apiKey->id)
            ->andReturn(30);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(429, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Rate limit exceeded', $responseData['error']);
        $this->assertEquals('30', $response->headers->get('Retry-After'));
    }

    /**
     * Test extracting API key from X-API-Key header
     */
    public function test_extract_api_key_from_header(): void
    {
        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', 'test-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('test-key', $result);
    }

    /**
     * Test extracting API key from Authorization Bearer header
     */
    public function test_extract_api_key_from_authorization_bearer(): void
    {
        $request = Request::create('/api/test', 'GET');
        $request->headers->set('Authorization', 'Bearer test-bearer-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('test-bearer-key', $result);
    }

    /**
     * Test extracting API key from query parameter
     */
    public function test_extract_api_key_from_query_parameter(): void
    {
        $request = Request::create('/api/test?api_key=test-query-key', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('test-query-key', $result);
    }

    /**
     * Test X-API-Key header takes priority over others
     */
    public function test_x_api_key_header_takes_priority(): void
    {
        $request = Request::create('/api/test?api_key=query-key', 'GET');
        $request->headers->set('X-API-Key', 'header-key');
        $request->headers->set('Authorization', 'Bearer bearer-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('header-key', $result);
    }

    /**
     * Test Authorization header takes priority over query parameter
     */
    public function test_authorization_header_priority_over_query(): void
    {
        $request = Request::create('/api/test?api_key=query-key', 'GET');
        $request->headers->set('Authorization', 'Bearer bearer-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('bearer-key', $result);
    }

    /**
     * Test returns null when no API key is provided
     */
    public function test_returns_null_when_no_api_key(): void
    {
        $request = Request::create('/api/test', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertNull($result);
    }

    /**
     * Test rate limit headers are added
     */
    public function test_rate_limit_headers_added(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
            'rate_limit' => 100,
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->andReturn(true);

        RateLimiter::shouldReceive('remaining')
            ->once()
            ->with('api_rate:'.$apiKey->id, 100)
            ->andReturn(95);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals('100', $response->headers->get('X-RateLimit-Limit'));
        $this->assertEquals('95', $response->headers->get('X-RateLimit-Remaining'));
    }

    /**
     * Test API key ID is added to response headers
     */
    public function test_api_key_id_added_to_response_headers(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.str_random(32),
            'is_active' => true,
        ]);

        Cache::shouldReceive('remember')
            ->once()
            ->andReturn($apiKey);

        RateLimiter::shouldReceive('attempt')
            ->once()
            ->andReturn(true);

        RateLimiter::shouldReceive('remaining')
            ->once()
            ->andReturn(59);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals((string) $apiKey->id, $response->headers->get('X-API-Key-ID'));
    }
}
