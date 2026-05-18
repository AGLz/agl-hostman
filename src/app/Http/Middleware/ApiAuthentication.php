<?php

namespace App\Http\Middleware;

use App\Http\Concerns\ExtractsApiKeyFromRequest;
use App\Models\ApiKey;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

class ApiAuthentication
{
    use ExtractsApiKeyFromRequest;

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, ?string $permission = null): Response
    {
        $apiKey = $this->extractApiKey($request);

        if (! $apiKey) {
            return response()->json([
                'error' => 'API key required',
                'message' => 'Please provide an API key via X-API-Key header or Authorization Bearer token',
            ], 401);
        }

        // Check cache first
        $cacheKey = 'api_key:' . substr($apiKey, 0, 8);
        $apiKeyModel = Cache::remember($cacheKey, 300, function () use ($apiKey) {
            return ApiKey::query()->where('key', $apiKey)->first();
        });

        if (! $apiKeyModel || ! $apiKeyModel->is_active) {
            return response()->json([
                'error' => 'Invalid API key',
                'message' => 'The provided API key is invalid or inactive',
            ], 401);
        }

        if ($apiKeyModel->isExpired()) {
            Cache::forget($cacheKey);

            return response()->json([
                'error' => 'API key expired',
                'message' => 'Your API key has expired. Please renew it.',
            ], 401);
        }

        // Check permissions
        if ($permission && ! $apiKeyModel->hasPermission($permission)) {
            return response()->json([
                'error' => 'Insufficient permissions',
                'message' => "Your API key does not have the '{$permission}' permission",
            ], 403);
        }

        // Rate limiting
        $rateLimitKey = 'api_rate:' . $apiKeyModel->id;
        $limit = $apiKeyModel->rate_limit ?: 60;

        if (! RateLimiter::attempt($rateLimitKey, $limit, function () {}, 60)) {
            $seconds = RateLimiter::availableIn($rateLimitKey);

            return response()->json([
                'error' => 'Rate limit exceeded',
                'message' => "Too many requests. Please try again in {$seconds} seconds.",
                'retry_after' => $seconds,
            ], 429)->header('Retry-After', $seconds);
        }

        // Record usage
        $apiKeyModel->recordUsage($request->ip());

        // Attach to request
        $request->attributes->set('api_key', $apiKeyModel);

        // Add API key ID to response headers
        $response = $next($request);
        $response->headers->set('X-API-Key-ID', $apiKeyModel->id);
        $response->headers->set('X-RateLimit-Limit', $limit);
        $response->headers->set('X-RateLimit-Remaining', RateLimiter::remaining($rateLimitKey, $limit));

        return $response;
    }

    /**
     * Extract API key from request
     */
    protected function extractApiKey(Request $request): ?string
    {
        return $this->extractApiKeyFromRequest($request);
    }
}
