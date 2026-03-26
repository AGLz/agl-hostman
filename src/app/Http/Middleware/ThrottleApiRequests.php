<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

/**
 * ThrottleApiRequests - Advanced rate limiting for API endpoints
 *
 * Implements per-user and per-IP rate limiting
 * Based on CODE-ANALYSIS-REPORT.md security hardening requirements
 */
class ThrottleApiRequests
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, int $maxAttempts = 100, int $decayMinutes = 1): Response
    {
        // Determine rate limit key (prefer user, fallback to IP)
        $key = $this->resolveRequestSignature($request);

        // Check if rate limit exceeded
        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $retryAfter = RateLimiter::availableIn($key);

            Log::warning('API rate limit exceeded', [
                'key' => $key,
                'ip' => $request->ip(),
                'user_id' => $request->user()?->id,
                'route' => $request->path(),
                'retry_after' => $retryAfter,
            ]);

            return response()->json([
                'error' => 'Too many requests',
                'message' => "Rate limit exceeded. Try again in {$retryAfter} seconds.",
                'retry_after' => $retryAfter,
            ], 429)->withHeaders([
                'X-RateLimit-Limit' => $maxAttempts,
                'X-RateLimit-Remaining' => 0,
                'Retry-After' => $retryAfter,
            ]);
        }

        // Increment attempts
        RateLimiter::hit($key, $decayMinutes * 60);

        // Get remaining attempts
        $remaining = $maxAttempts - RateLimiter::attempts($key);

        // Process request
        $response = $next($request);

        // Add rate limit headers
        return $response->withHeaders([
            'X-RateLimit-Limit' => $maxAttempts,
            'X-RateLimit-Remaining' => max(0, $remaining),
            'X-RateLimit-Reset' => now()->addMinutes($decayMinutes)->timestamp,
        ]);
    }

    /**
     * Resolve request signature for rate limiting
     */
    protected function resolveRequestSignature(Request $request): string
    {
        // Authenticated users: rate limit by user ID
        if ($user = $request->user()) {
            return 'api:user:'.$user->id;
        }

        // Guest users: rate limit by IP + User-Agent
        return 'api:ip:'.sha1(
            $request->ip().'|'.$request->userAgent()
        );
    }

    /**
     * Clear rate limiter for specific user/IP (admin function)
     */
    public static function clearRateLimit(string $key): void
    {
        RateLimiter::clear($key);
        Log::info("Rate limit cleared for key: {$key}");
    }

    /**
     * Get current rate limit status
     */
    public static function getRateLimitStatus(Request $request, int $maxAttempts = 100): array
    {
        $middleware = new self;
        $key = $middleware->resolveRequestSignature($request);

        return [
            'key' => $key,
            'attempts' => RateLimiter::attempts($key),
            'remaining' => max(0, $maxAttempts - RateLimiter::attempts($key)),
            'available_in' => RateLimiter::tooManyAttempts($key, $maxAttempts)
                ? RateLimiter::availableIn($key)
                : 0,
        ];
    }
}
