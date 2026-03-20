<?php

declare(strict_types=1);

namespace App\Repositories;

use Exception;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Harbor Repository
 *
 * Base HTTP client for Harbor API communication
 * Handles authentication, retries, rate limiting, and error handling
 */
class HarborRepository
{
    private const CACHE_TTL = 300;

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
        $baseUrl = config('harbor.base_url');
        $username = config('harbor.username');
        $password = config('harbor.password');
        $timeout = config('harbor.timeout', 30);

        if (! $baseUrl) {
            throw new Exception('Harbor base URL is not configured');
        }

        if (! $username || ! $password) {
            throw new Exception('Harbor credentials are not configured');
        }

        return Http::baseUrl($baseUrl)
            ->timeout($timeout)
            ->withBasicAuth($username, $password)
            ->withHeaders([
                'Content-Type' => 'application/json',
                'Accept' => 'application/json',
            ])
            ->acceptJson();
    }

    /**
     * Send GET request
     */
    public function get(string $endpoint, array $params = []): array
    {
        $response = $this->sendWithRetry(fn () => $this->client()->get($endpoint, $params));

        return $this->handleResponse($response);
    }

    /**
     * Send POST request
     */
    public function post(string $endpoint, array $data = []): array
    {
        $response = $this->sendWithRetry(fn () => $this->client()->post($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send PUT request
     */
    public function put(string $endpoint, array $data = []): array
    {
        $response = $this->sendWithRetry(fn () => $this->client()->put($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send PATCH request
     */
    public function patch(string $endpoint, array $data = []): array
    {
        $response = $this->sendWithRetry(fn () => $this->client()->patch($endpoint, $data));

        return $this->handleResponse($response);
    }

    /**
     * Send DELETE request
     */
    public function delete(string $endpoint): array
    {
        $response = $this->sendWithRetry(fn () => $this->client()->delete($endpoint));

        return $this->handleResponse($response);
    }

    /**
     * Send request with retry logic
     */
    private function sendWithRetry(callable $requestCallback): Response
    {
        $retryTimes = config('harbor.retry_times', self::MAX_RETRIES);
        $retryDelay = config('harbor.retry_delay', self::RETRY_DELAY_MS);
        $lastException = null;

        for ($attempt = 1; $attempt <= $retryTimes; $attempt++) {
            try {
                $response = $requestCallback();

                if ($response->successful()) {
                    return $response;
                }

                if ($response->clientError()) {
                    return $response;
                }

                $lastException = new Exception(
                    "Harbor API error: {$response->status()} - {$response->body()}"
                );

                Log::warning('Harbor API request failed, retrying', [
                    'attempt' => $attempt,
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);

            } catch (Exception $e) {
                $lastException = $e;
                Log::warning('Harbor API request exception, retrying', [
                    'attempt' => $attempt,
                    'error' => $e->getMessage(),
                ]);
            }

            if ($attempt < $retryTimes) {
                usleep($retryDelay * $attempt * 1000);
            }
        }

        throw new Exception(
            "Harbor API request failed after {$retryTimes} attempts: ".
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

            Log::debug('Harbor API success', [
                'status' => $response->status(),
            ]);

            return $body ?? [];
        }

        $errorBody = $response->body();
        Log::error('Harbor API error', [
            'status' => $response->status(),
            'body' => $errorBody,
        ]);

        throw new Exception(
            "Harbor API error: {$response->status()} - {$errorBody}"
        );
    }

    /**
     * Test API connection
     */
    public function testConnection(): bool
    {
        try {
            $response = $this->client()->get('/api/v2.0/systeminfo');

            return $response->successful();
        } catch (Exception $e) {
            Log::error('Harbor connection test failed', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }
}
