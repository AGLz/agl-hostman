<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Services\RedisCacheStrategy;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Cache API Responses Middleware
 *
 * Caches GET API responses in Redis to improve performance.
 * Supports cache tags, TTL strategies, and intelligent invalidation.
 *
 * @package App\Http\Middleware
 */
class CacheApiResponse
{
    private RedisCacheStrategy $cacheStrategy;

    // Default TTL by endpoint pattern
    private array $ttlPatterns = [
        // Real-time data - 5 minutes
        '/api/infrastructure/metrics' => 'short',
        '/api/proxmox/containers' => 'short',
        '/api/proxmox/servers' => 'short',

        // Semi-static data - 30 minutes
        '/api/deployments' => 'medium',
        '/api/dokploy/applications' => 'medium',
        '/api/users' => 'medium',

        // Static data - 1 hour
        '/api/harbors/projects' => 'long',
        '/api/harbors/repositories' => 'long',
    ];

    // Routes to exclude from caching
    private array $excludePatterns = [
        '/api/auth/*',
        '/api/webhooks/*',
        '/api/*/logs',
    ];

    public function __construct(RedisCacheStrategy $cacheStrategy)
    {
        $this->cacheStrategy = $cacheStrategy;
    }

    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Only cache GET requests
        if ($request->method() !== 'GET') {
            return $next($request);
        }

        // Check if route should be excluded
        if ($this->shouldExclude($request->getPathInfo())) {
            return $next($request);
        }

        // Generate cache key
        $cacheKey = $this->generateCacheKey($request);

        // Determine TTL strategy
        $ttl = $this->determineTtl($request->getPathInfo());

        // Try to get from cache
        $cachedResponse = $this->getCachedResponse($cacheKey);

        if ($cachedResponse !== null) {
            return $this->buildCachedResponse($cachedResponse);
        }

        // Process request
        $response = $next($request);

        // Cache successful responses
        if ($this->shouldCacheResponse($response)) {
            $this->cacheResponse($cacheKey, $response, $ttl);
        }

        return $response;
    }

    /**
     * Check if route should be excluded from caching
     *
     * @param string $path
     * @return bool
     */
    private function shouldExclude(string $path): bool
    {
        foreach ($this->excludePatterns as $pattern) {
            if (fnmatch($pattern, $path)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Generate cache key from request
     *
     * @param Request $request
     * @return string
     */
    private function generateCacheKey(Request $request): string
    {
        $path = $request->getPathInfo();
        $query = $request->getQueryString();

        $key = 'api_response:' . str_replace('/', '_', $path);

        if ($query) {
            $key .= ':' . md5($query);
        }

        // Include user-specific data if authenticated
        if ($request->user()) {
            $key .= ':user_' . $request->user()->id;
        }

        return $key;
    }

    /**
     * Determine TTL strategy for endpoint
     *
     * @param string $path
     * @return string
     */
    private function determineTtl(string $path): string
    {
        foreach ($this->ttlPatterns as $pattern => $ttl) {
            if (str_starts_with($path, $pattern)) {
                return $ttl;
            }
        }

        return 'medium'; // Default 30 minutes
    }

    /**
     * Get cached response
     *
     * @param string $key
     * @return array|null
     */
    private function getCachedResponse(string $key): ?array
    {
        $cached = Cache::get($key);

        return is_array($cached) ? $cached : null;
    }

    /**
     * Build response from cached data
     *
     * @param array $cached
     * @return Response
     */
    private function buildCachedResponse(array $cached): Response
    {
        $response = response(
            $cached['content'],
            $cached['status']
        );

        // Restore headers
        foreach ($cached['headers'] as $name => $value) {
            $response->headers->set($name, $value);
        }

        // Add cache header
        $response->headers->set('X-Cache', 'HIT');

        return $response;
    }

    /**
     * Check if response should be cached
     *
     * @param Response $response
     * @return bool
     */
    private function shouldCacheResponse(Response $response): bool
    {
        // Only cache successful responses
        if ($response->getStatusCode() !== 200) {
            return false;
        }

        // Don't cache if already has cache headers
        if ($response->headers->has('Cache-Control')) {
            return false;
        }

        return true;
    }

    /**
     * Cache response
     *
     * @param string $key
     * @param Response $response
     * @param string $ttl
     * @return void
     */
    private function cacheResponse(string $key, Response $response, string $ttl): void
    {
        $ttlSeconds = $this->resolveTtl($ttl);

        $cached = [
            'content' => $response->getContent(),
            'status' => $response->getStatusCode(),
            'headers' => $response->headers->all(),
            'cached_at' => now()->toIso8601String(),
        ];

        Cache::put($key, $cached, $ttlSeconds);
    }

    /**
     * Resolve TTL strategy to seconds
     *
     * @param string $ttl
     * @return int
     */
    private function resolveTtl(string $ttl): int
    {
        return match($ttl) {
            'short' => 300,      // 5 minutes
            'medium' => 1800,    // 30 minutes
            'long' => 3600,      // 1 hour
            'day' => 86400,      // 24 hours
            default => 1800,
        };
    }
}
