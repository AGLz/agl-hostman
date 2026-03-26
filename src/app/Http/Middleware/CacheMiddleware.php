<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Services\Performance\CacheStrategyService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;

/**
 * API Response Caching Middleware
 *
 * Caches GET requests for improved performance.
 * Supports cache invalidation by tags.
 */
class CacheMiddleware
{
    private CacheStrategyService $cache;

    private array $cacheablePaths = [
        'api/monitoring/health',
        'api/infrastructure/status',
        'api/n8n/statistics',
    ];

    private array $cacheDurations = [
        'api/monitoring/health' => 30,
        'api/infrastructure/status' => 30,
        'api/n8n/statistics' => 300,
    ];

    public function __construct(CacheStrategyService $cache)
    {
        $this->cache = $cache;
    }

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Only cache GET requests
        if ($request->method() !== 'GET') {
            return $next($request);
        }

        // Check if path is cacheable
        $cacheKey = $this->getCacheKey($request);
        $duration = $this->getCacheDuration($request);

        if (! $cacheKey || ! $duration) {
            return $next($request);
        }

        // Try to get cached response
        $cachedResponse = Cache::get($cacheKey);

        if ($cachedResponse) {
            return response($cachedResponse['content'])
                ->headers->set('X-Cache', 'HIT')
                ->headers->set('X-Cache-Key', $cacheKey);
        }

        // Process request and cache response
        $response = $next($request);

        // Only cache successful responses
        if ($response->getStatusCode() === 200) {
            Cache::put($cacheKey, [
                'content' => $response->getContent(),
                'status' => $response->getStatusCode(),
            ], $duration);

            $response->headers->set('X-Cache', 'MISS');
            $response->headers->set('X-Cache-Key', $cacheKey);
        }

        return $response;
    }

    /**
     * Get cache key for request
     */
    protected function getCacheKey(Request $request): ?string
    {
        $path = $request->path();

        foreach ($this->cacheablePaths as $cacheablePath) {
            if (str_starts_with($path, $cacheablePath)) {
                $queryParams = $request->query->all();
                ksort($queryParams); // Ensure consistent ordering
                $queryString = http_build_query($queryParams);

                return "api_response:{$path}".($queryString ? ":{$queryString}" : '');
            }
        }

        return null;
    }

    /**
     * Get cache duration for request
     */
    protected function getCacheDuration(Request $request): ?int
    {
        $path = $request->path();

        foreach ($this->cacheDurations as $pattern => $duration) {
            if (str_starts_with($path, $pattern)) {
                return $duration;
            }
        }

        return null;
    }

    /**
     * Clear cache for specific path pattern
     */
    public function clearCache(string $pattern): void
    {
        $pattern = "api_response:{$pattern}*";

        // This would require Redis SCAN operation
        // For now, use tag-based invalidation
        Cache::tags(['api_responses'])->flush();
    }
}
