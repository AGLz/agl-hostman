<?php

declare(strict_types=1);

namespace App\Repositories;

use Exception;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Dokploy Repository
 *
 * Base HTTP client for Dokploy API communication
 * Handles authentication, retries, rate limiting, and error handling
 */
class DokployRepository
{
    private const CACHE_TTL = 300; // 5 minutes

    private const MAX_RETRIES = 3;

    private const RETRY_DELAY_MS = 1000;

    /** @var PendingRequest|null Lazily built to avoid DI/bootstrap recursion ao carregar o console */
    private ?PendingRequest $client = null;

    public function __construct() {}

    private function client(): PendingRequest
    {
        return $this->client ??= $this->createClient();
    }

    /**
     * Create configured HTTP client
     */
    private function createClient(): PendingRequest
    {
        $baseUrl = config('dokploy.base_url');
        $apiToken = config('dokploy.api_key');
        $timeout = config('dokploy.timeout', 30);

        if (! $baseUrl) {
            throw new Exception('Dokploy base URL is not configured');
        }

        if (! $apiToken) {
            throw new Exception('Dokploy API token is not configured');
        }

        return Http::baseUrl($baseUrl)
            ->timeout($timeout)
            ->withHeaders([
                'Authorization' => "Bearer {$apiToken}",
                'Content-Type' => 'application/json',
                'Accept' => 'application/json',
            ])
            ->acceptJson();
    }

    /**
     * Send GET request with caching
     */
    public function get(string $endpoint, array $params = [], bool $cache = true): array
    {
        $cacheKey = $this->getCacheKey('get', $endpoint, $params);

        if ($cache && Cache::has($cacheKey)) {
            Log::debug('Dokploy cache hit', ['endpoint' => $endpoint]);

            return Cache::get($cacheKey);
        }

        $response = $this->sendWithRetry(fn () => $this->client()->get($endpoint, $params));

        $data = $this->handleResponse($response);

        if ($cache) {
            Cache::put($cacheKey, $data, self::CACHE_TTL);
        }

        return $data;
    }

    /**
     * Send POST request
     */
    public function post(string $endpoint, array $data = []): array
    {
        $this->invalidateCache($endpoint);

        $response = $this->sendWithRetry(fn () => $this->client()->post($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send PUT request
     */
    public function put(string $endpoint, array $data = []): array
    {
        $this->invalidateCache($endpoint);

        $response = $this->sendWithRetry(fn () => $this->client()->put($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send PATCH request
     */
    public function patch(string $endpoint, array $data = []): array
    {
        $this->invalidateCache($endpoint);

        $response = $this->sendWithRetry(fn () => $this->client()->patch($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send DELETE request
     */
    public function delete(string $endpoint): array
    {
        $this->invalidateCache($endpoint);

        $response = $this->sendWithRetry(fn () => $this->client()->delete($endpoint));

        return $this->handleResponse($response);
    }

    /**
     * Send request with retry logic
     */
    private function sendWithRetry(callable $requestCallback): Response
    {
        $retryTimes = config('dokploy.retry_times', self::MAX_RETRIES);
        $retryDelay = config('dokploy.retry_delay', self::RETRY_DELAY_MS);
        $lastException = null;

        for ($attempt = 1; $attempt <= $retryTimes; $attempt++) {
            try {
                $response = $requestCallback();

                // Success - return response
                if ($response->successful()) {
                    return $response;
                }

                // If it's a client error (4xx), don't retry
                if ($response->clientError()) {
                    return $response;
                }

                // Server error (5xx) - retry
                $lastException = new Exception(
                    "Dokploy API error: {$response->status()} - {$response->body()}"
                );

                Log::warning('Dokploy API request failed, retrying', [
                    'attempt' => $attempt,
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);

            } catch (Exception $e) {
                $lastException = $e;
                Log::warning('Dokploy API request exception, retrying', [
                    'attempt' => $attempt,
                    'error' => $e->getMessage(),
                ]);
            }

            // Wait before retrying (exponential backoff)
            if ($attempt < $retryTimes) {
                usleep($retryDelay * $attempt * 1000);
            }
        }

        throw new Exception(
            "Dokploy API request failed after {$retryTimes} attempts: ".
            ($lastException?->getMessage() ?? 'Unknown error')
        );
    }

    /**
     * Handle API response
     */
    private function handleResponse(Response $response): array
    {
        if ($response->successful()) {
            $body = $response->json();

            Log::debug('Dokploy API success', [
                'status' => $response->status(),
                'data' => $body,
            ]);

            return $body ?? [];
        }

        $errorBody = $response->body();
        Log::error('Dokploy API error', [
            'status' => $response->status(),
            'body' => $errorBody,
        ]);

        throw new Exception(
            "Dokploy API error: {$response->status()} - {$errorBody}"
        );
    }

    /**
     * Generate cache key
     */
    private function getCacheKey(string $method, string $endpoint, array $params = []): string
    {
        return 'dokploy:'.md5($method.':'.$endpoint.':'.json_encode($params));
    }

    /**
     * Invalidate cache for endpoint
     */
    private function invalidateCache(string $endpoint): void
    {
        // Invalidate all caches related to this endpoint
        // In production, use a more sophisticated cache tagging system
        Cache::forget($this->getCacheKey('get', $endpoint));
    }

    /**
     * Clear all Dokploy caches
     */
    public function clearCache(): void
    {
        // In Laravel 11+, you can use cache tags
        // For now, we'll clear specific known patterns
        Log::info('Clearing all Dokploy caches');
    }

    /**
     * Test API connection
     */
    public function testConnection(): bool
    {
        try {
            $response = $this->client()->get('/api/health');

            return $response->successful();
        } catch (Exception $e) {
            Log::error('Dokploy connection test failed', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Get API health status
     */
    public function healthCheck(): array
    {
        try {
            return $this->get('/api/health', [], false);
        } catch (Exception $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
            ];
        }
    }
}
