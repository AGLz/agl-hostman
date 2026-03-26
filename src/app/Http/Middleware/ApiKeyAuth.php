<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;

class ApiKeyAuth
{
    /**
     * Handle an incoming request.
     *
     * Validates API key from:
     * - X-API-Key header
     * - api_key query parameter
     * - Authorization: Bearer <api_key>
     */
    public function handle(Request $request, Closure $next)
    {
        $apiKey = $this->extractApiKey($request);

        if (! $apiKey) {
            return response()->json([
                'success' => false,
                'error' => 'API key required',
                'message' => 'Provide API key via X-API-Key header, api_key query param, or Authorization Bearer token.',
            ], Response::HTTP_UNAUTHORIZED);
        }

        $validKeys = $this->getValidKeys();

        if (! in_array($apiKey, $validKeys, true)) {
            Log::warning('Invalid API key attempt', [
                'ip' => $request->ip(),
                'key_prefix' => substr($apiKey, 0, 8).'...',
            ]);

            return response()->json([
                'success' => false,
                'error' => 'Invalid API key',
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }

    /**
     * Extract API key from various sources.
     */
    private function extractApiKey(Request $request): ?string
    {
        // Check header first
        if ($request->hasHeader('X-API-Key')) {
            return $request->header('X-API-Key');
        }

        // Check query parameter
        if ($request->has('api_key')) {
            return $request->input('api_key');
        }

        // Check Authorization Bearer
        $authHeader = $request->header('Authorization');
        if ($authHeader && str_starts_with($authHeader, 'Bearer ')) {
            return substr($authHeader, 7);
        }

        return null;
    }

    /**
     * Get valid API keys from config/env.
     */
    private function getValidKeys(): array
    {
        $keys = [];

        // Primary key from env
        $primaryKey = env('API_KEY');
        if ($primaryKey) {
            $keys[] = $primaryKey;
        }

        // Additional keys from env (comma-separated)
        $additionalKeys = env('API_KEYS');
        if ($additionalKeys) {
            $keys = array_merge($keys, array_map('trim', explode(',', $additionalKeys)));
        }

        // Development mode: allow 'dev' key
        if (app()->environment('local')) {
            $keys[] = 'dev';
        }

        return array_filter($keys);
    }
}
