<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Http\Concerns\ExtractsApiKeyFromRequest;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;

class ApiKeyAuth
{
    use ExtractsApiKeyFromRequest;

    /**
     * Handle an incoming request.
     *
     * Validates API key from X-API-Key or Authorization: Bearer (query only if ALLOW_QUERY_API_KEY).
     */
    public function handle(Request $request, Closure $next)
    {
        $apiKey = $this->extractApiKeyFromRequest($request);

        if (! $apiKey) {
            return response()->json([
                'success' => false,
                'error' => 'API key required',
                'message' => 'Provide API key via X-API-Key header or Authorization Bearer token.',
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
     * Get valid API keys from config/env.
     *
     * @return list<string>
     */
    private function getValidKeys(): array
    {
        $keys = [];

        $primaryKey = config('services.hostman.api_key');
        if (is_string($primaryKey) && $primaryKey !== '') {
            $keys[] = $primaryKey;
        }

        $additionalKeys = config('services.hostman.api_keys');
        if (is_string($additionalKeys) && $additionalKeys !== '') {
            $keys = array_merge($keys, array_map('trim', explode(',', $additionalKeys)));
        }

        if (app()->environment('local')) {
            $keys[] = 'dev';
        }

        return array_values(array_filter($keys));
    }
}
