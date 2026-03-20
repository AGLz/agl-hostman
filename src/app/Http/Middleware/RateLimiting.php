<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rate Limiting Middleware
 *
 * Applies rate limiting to API endpoints to prevent abuse.
 */
class RateLimiting
{
    private array $rateLimits = [
        'default' => [
            'max_attempts' => 60,
            'decay_minutes' => 1,
        ],
        'strict' => [
            'max_attempts' => 5,
            'decay_minutes' => 1,
        ],
        'api' => [
            'max_attempts' => 100,
            'decay_minutes' => 1,
        ],
        'auth' => [
            'max_attempts' => 5,
            'decay_minutes' => 15,
        ],
    ];

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, ?string $limitType = null): Response
    {
        $key = $this->resolveRateLimitKey($request, $limitType);
        $limit = $this->getRateLimit($limitType);

        if ($this->isRateLimited($request, $key, $limit)) {
            return $this->buildRateLimitResponse($request, $limit);
        }

        $response = $next($request);

        // Add rate limit headers to response
        return $this->addRateLimitHeaders($response, $key, $limit);
    }

    /**
     * Resolve rate limit key
     */
    private function resolveRateLimitKey(Request $request, ?string $limitType): string
    {
        $keyParts = ['rate_limit', $limitType ?? 'default'];

        // Add user ID if authenticated
        if (auth()->check()) {
            $keyParts[] = 'user_'.auth()->id();
        } else {
            $keyParts[] = 'ip_'.$request->ip();
        }

        return implode(':', $keyParts);
    }

    /**
     * Get rate limit configuration
     */
    private function getRateLimit(?string $limitType): array
    {
        return $this->rateLimits[$limitType] ?? $this->rateLimits['default'];
    }

    /**
     * Check if request is rate limited
     */
    private function isRateLimited(Request $request, string $key, array $limit): bool
    {
        $cache = cache();
        $attempts = $cache->get($key, 0);

        if ($attempts >= $limit['max_attempts']) {
            Log::warning('Rate limit exceeded', [
                'key' => $key,
                'attempts' => $attempts,
                'ip' => $request->ip(),
                'user_id' => auth()->id(),
            ]);

            return true;
        }

        // Increment attempts
        $cache->put($key, $attempts + 1, now()->addMinutes($limit['decay_minutes']));

        return false;
    }

    /**
     * Build rate limit response
     */
    private function buildRateLimitResponse(Request $request, array $limit): Response
    {
        if ($request->expectsJson()) {
            return response()->json([
                'error' => 'Too many attempts',
                'message' => 'Rate limit exceeded. Please try again later.',
                'retry_after' => $limit['decay_minutes'] * 60,
            ], 429);
        }

        return response()->view('errors.rate-limit', [
            'retry_after' => $limit['decay_minutes'] * 60,
        ], 429);
    }

    /**
     * Add rate limit headers to response
     */
    private function addRateLimitHeaders(Response $response, string $key, array $limit): Response
    {
        $cache = cache();
        $attempts = $cache->get($key, 0);
        $remaining = max(0, $limit['max_attempts'] - $attempts);

        $response->headers->set('X-RateLimit-Limit', (string) $limit['max_attempts']);
        $response->headers->set('X-RateLimit-Remaining', (string) $remaining);
        $response->headers->set('X-RateLimit-Reset', (string) now()->addMinutes($limit['decay_minutes'])->getTimestamp());

        return $response;
    }
}
