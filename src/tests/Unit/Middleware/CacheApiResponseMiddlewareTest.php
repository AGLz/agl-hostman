<?php

declare(strict_types=1);

namespace Tests\Unit\Middleware;

use App\Http\Middleware\CacheApiResponse;
use App\Services\RedisCacheStrategy;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * Cache API Response Middleware Test
 *
 * Tests for the CacheApiResponse middleware.
 *
 * @package Tests\Unit\Middleware
 */
class CacheApiResponseMiddlewareTest extends TestCase
{
    private CacheApiResponse $middleware;
    private RedisCacheStrategy $cacheStrategy;

    protected function setUp(): void
    {
        parent::setUp();

        $this->cacheStrategy = $this->createMock(RedisCacheStrategy::class);
        $this->middleware = new CacheApiResponse($this->cacheStrategy);
    }

    /**
     * Test non-GET requests pass through without caching
     */
    public function test_non_get_requests_pass_through(): void
    {
        $request = Request::create('/api/test', 'POST');
        $response = $this->middleware->handle($request, fn($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertFalse($response->headers->has('X-Cache'));
    }

    /**
     * Test excluded routes are not cached
     */
    public function test_excluded_routes_not_cached(): void
    {
        $request = Request::create('/api/auth/login', 'GET');

        $response = $this->middleware->handle($request, fn($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertFalse($response->headers->has('X-Cache'));
    }

    /**
     * Test webhook routes are excluded from caching
     */
    public function test_webhook_routes_excluded(): void
    {
        $request = Request::create('/api/webhooks/n8n', 'GET');

        $response = $this->middleware->handle($request, fn($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertFalse($response->headers->has('X-Cache'));
    }

    /**
     * Test logs routes are excluded from caching
     */
    public function test_logs_routes_excluded(): void
    {
        $request = Request::create('/api/containers/logs', 'GET');

        $response = $this->middleware->handle($request, fn($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertFalse($response->hasHeader('X-Cache'));
    }

    /**
     * Test successful response is cached
     */
    public function test_successful_response_is_cached(): void
    {
        $request = Request::create('/api/containers', 'GET');

        Cache::shouldReceive('get')
            ->once()
            ->andReturn(null);

        Cache::shouldReceive('put')
            ->once()
            ->with(
                \PHPUnit\Framework\Constraint\RegularExpression::class,
                \PHPUnit\Framework\Constraint\Callback::class,
                1800
            );

        $response = $this->middleware->handle($request, fn($req) => response('success', 200));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertEquals('success', $response->getContent());
    }

    /**
     * Test error responses are not cached
     */
    public function test_error_responses_not_cached(): void
    {
        $request = Request::create('/api/containers', 'GET');

        Cache::shouldReceive('get')
            ->once()
            ->andReturn(null);

        Cache::shouldReceive('put')
            ->never();

        $response = $this->middleware->handle($request, fn($req) => response('error', 500));

        $this->assertEquals(500, $response->getStatusCode());
        $this->assertFalse($response->headers->has('X-Cache'));
    }

    /**
     * Test cached response is returned
     */
    public function test_cached_response_returned(): void
    {
        $request = Request::create('/api/containers', 'GET');

        $cachedData = [
            'content' => 'cached content',
            'status' => 200,
            'headers' => ['Content-Type' => ['application/json']],
            'cached_at' => now()->toIso8601String(),
        ];

        Cache::shouldReceive('get')
            ->once()
            ->andReturn($cachedData);

        Cache::shouldReceive('put')
            ->never();

        $response = $this->middleware->handle($request, fn($req) => response('fresh'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertEquals('cached content', $response->getContent());
        $this->assertEquals('HIT', $response->headers->get('X-Cache'));
    }

    /**
     * Test cache key includes query parameters
     */
    public function test_cache_key_includes_query_params(): void
    {
        $request = Request::create('/api/containers?status=running&page=1', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('generateCacheKey');
        $method->setAccessible(true);

        $key = $method->invoke($this->middleware, $request);

        $this->assertStringContainsString('_api_containers:', $key);
        $this->assertNotEmpty($key);
    }

    /**
     * Test cache key includes user ID when authenticated
     */
    public function test_cache_key_includes_user_id(): void
    {
        $request = Request::create('/api/containers', 'GET');
        $request->setUserResolver(fn() => (object) ['id' => 123]);

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('generateCacheKey');
        $method->setAccessible(true);

        $key = $method->invoke($this->middleware, $request);

        $this->assertStringContainsString('user_123', $key);
    }

    /**
     * Test TTL determination by endpoint pattern
     */
    public function test_ttl_determination_by_endpoint(): void
    {
        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('determineTtl');
        $method->setAccessible(true);

        $shortTtl = $method->invoke($this->middleware, '/api/infrastructure/metrics');
        $mediumTtl = $method->invoke($this->middleware, '/api/deployments');
        $longTtl = $method->invoke($this->middleware, '/api/harbors/projects');
        $defaultTtl = $method->invoke($this->middleware, '/api/unknown');

        $this->assertEquals('short', $shortTtl);
        $this->assertEquals('medium', $mediumTtl);
        $this->assertEquals('long', $longTtl);
        $this->assertEquals('medium', $defaultTtl);
    }

    /**
     * Test short TTL for metrics endpoint
     */
    public function test_short_ttl_for_metrics(): void
    {
        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('determineTtl');
        $method->setAccessible(true);

        $ttl = $method->invoke($this->middleware, '/api/infrastructure/metrics');

        $this->assertEquals('short', $ttl);
    }

    /**
     * Test short TTL for containers endpoint
     */
    public function test_short_ttl_for_containers(): void
    {
        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('determineTtl');
        $method->setAccessible(true);

        $ttl = $method->invoke($this->middleware, '/api/proxmox/containers');

        $this->assertEquals('short', $ttl);
    }

    /**
     * Test long TTL for projects endpoint
     */
    public function test_long_ttl_for_projects(): void
    {
        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('determineTtl');
        $method->setAccessible(true);

        $ttl = $method->invoke($this->middleware, '/api/harbors/projects');

        $this->assertEquals('long', $ttl);
    }

    /**
     * Test TTL resolution
     */
    public function test_ttl_resolution(): void
    {
        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('resolveTtl');
        $method->setAccessible(true);

        $short = $method->invoke($this->middleware, 'short');
        $medium = $method->invoke($this->middleware, 'medium');
        $long = $method->invoke($this->middleware, 'long');
        $day = $method->invoke($this->middleware, 'day');
        $invalid = $method->invoke($this->middleware, 'invalid');

        $this->assertEquals(300, $short);
        $this->assertEquals(1800, $medium);
        $this->assertEquals(3600, $long);
        $this->assertEquals(86400, $day);
        $this->assertEquals(1800, $invalid);
    }

    /**
     * Test response with existing cache control headers is not cached
     */
    public function test_response_with_cache_control_not_cached(): void
    {
        $request = Request::create('/api/containers', 'GET');

        Cache::shouldReceive('get')
            ->once()
            ->andReturn(null);

        Cache::shouldReceive('put')
            ->never();

        $response = $this->middleware->handle(
            $request,
            fn($req) => response('success')->header('Cache-Control', 'max-age=60')
        );

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertFalse($response->headers->has('X-Cache'));
    }

    /**
     * Test only 200 status responses are cached
     */
    public function test_only_200_responses_cached(): void
    {
        $request = Request::create('/api/containers', 'GET');

        Cache::shouldReceive('get')
            ->andReturn(null);

        Cache::shouldReceive('put')
            ->never();

        // Test 404
        $response = $this->middleware->handle($request, fn($req) => response('not found', 404));
        $this->assertEquals(404, $response->getStatusCode());

        // Test 301 redirect
        $response = $this->middleware->handle($request, fn($req) => response('redirect', 301));
        $this->assertEquals(301, $response->getStatusCode());
    }

    /**
     * Test cache HIT header on cached response
     */
    public function test_cache_hit_header(): void
    {
        $request = Request::create('/api/containers', 'GET');

        $cachedData = [
            'content' => 'cached',
            'status' => 200,
            'headers' => [],
            'cached_at' => now()->toIso8601String(),
        ];

        Cache::shouldReceive('get')
            ->once()
            ->andReturn($cachedData);

        $response = $this->middleware->handle($request, fn($req) => response('fresh'));

        $this->assertEquals('HIT', $response->headers->get('X-Cache'));
    }
}
