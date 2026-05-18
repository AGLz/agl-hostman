<?php

declare(strict_types=1);

namespace Tests\Unit\Middleware;

use App\Http\Middleware\ApiAuthentication;
use App\Models\ApiKey;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * API Authentication Middleware Test
 *
 * Tests for the ApiAuthentication middleware.
 */
class ApiAuthenticationMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    private ApiAuthentication $middleware;

    protected function setUp(): void
    {
        parent::setUp();

        $this->middleware = new ApiAuthentication;
        Cache::flush();
    }

    public function test_authenticates_with_valid_api_key(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
        ]);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertEquals('success', $response->getContent());
        $this->assertEquals((string) $apiKey->id, $response->headers->get('X-API-Key-ID'));
    }

    public function test_fails_when_api_key_missing(): void
    {
        $request = Request::create('/api/test', 'GET');

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $this->assertJson($response->getContent());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('API key required', $responseData['error']);
    }

    public function test_fails_with_invalid_api_key(): void
    {
        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', 'invalid-key');

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Invalid API key', $responseData['error']);
    }

    public function test_fails_when_api_key_expired(): void
    {
        $apiKey = ApiKey::factory()->expired()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
        ]);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals(401, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('API key expired', $responseData['error']);
    }

    public function test_fails_when_permission_required_but_not_granted(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
            'permissions' => ['read'],
        ]);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'), 'write');

        $this->assertEquals(403, $response->getStatusCode());
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Insufficient permissions', $responseData['error']);
    }

    public function test_passes_when_permission_granted(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
            'permissions' => ['read', 'write'],
        ]);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'), 'write');

        $this->assertEquals(200, $response->getStatusCode());
    }

    public function test_rate_limiting(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
            'rate_limit' => 1,
        ]);

        RateLimiter::clear('api_rate:'.$apiKey->id);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $first = $this->middleware->handle($request, fn ($req) => response('success'));
        $this->assertEquals(200, $first->getStatusCode());

        $second = $this->middleware->handle($request, fn ($req) => response('success'));
        $this->assertEquals(429, $second->getStatusCode());
        $responseData = json_decode($second->getContent(), true);
        $this->assertEquals('Rate limit exceeded', $responseData['error']);
        $this->assertNotEmpty($second->headers->get('Retry-After'));
    }

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

    public function test_extract_api_key_from_query_parameter_when_allowed(): void
    {
        config(['security.allow_query_api_key' => true]);

        $request = Request::create('/api/test?api_key=test-query-key', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('test-query-key', $result);
    }

    public function test_extract_api_key_ignores_query_when_disabled(): void
    {
        config(['security.allow_query_api_key' => false]);

        $request = Request::create('/api/test?api_key=test-query-key', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertNull($result);
    }

    public function test_x_api_key_header_takes_priority(): void
    {
        config(['security.allow_query_api_key' => true]);

        $request = Request::create('/api/test?api_key=query-key', 'GET');
        $request->headers->set('X-API-Key', 'header-key');
        $request->headers->set('Authorization', 'Bearer bearer-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('header-key', $result);
    }

    public function test_authorization_header_priority_over_query(): void
    {
        config(['security.allow_query_api_key' => true]);

        $request = Request::create('/api/test?api_key=query-key', 'GET');
        $request->headers->set('Authorization', 'Bearer bearer-key');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertEquals('bearer-key', $result);
    }

    public function test_returns_null_when_no_api_key(): void
    {
        $request = Request::create('/api/test', 'GET');

        $reflection = new \ReflectionClass($this->middleware);
        $method = $reflection->getMethod('extractApiKey');
        $method->setAccessible(true);

        $result = $method->invoke($this->middleware, $request);

        $this->assertNull($result);
    }

    public function test_rate_limit_headers_added(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
            'rate_limit' => 100,
        ]);

        RateLimiter::clear('api_rate:'.$apiKey->id);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals('100', $response->headers->get('X-RateLimit-Limit'));
        $this->assertEquals('99', $response->headers->get('X-RateLimit-Remaining'));
    }

    public function test_api_key_id_added_to_response_headers(): void
    {
        $apiKey = ApiKey::factory()->create([
            'key' => 'test-api-key-'.Str::random(32),
            'is_active' => true,
        ]);

        RateLimiter::clear('api_rate:'.$apiKey->id);

        $request = Request::create('/api/test', 'GET');
        $request->headers->set('X-API-Key', $apiKey->key);

        $response = $this->middleware->handle($request, fn ($req) => response('success'));

        $this->assertEquals((string) $apiKey->id, $response->headers->get('X-API-Key-ID'));
    }
}
