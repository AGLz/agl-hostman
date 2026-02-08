<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\DTOs\ApiResponse;
use Exception;

/**
 * Harbor API Client
 *
 * API abstraction layer for Harbor Container Registry
 * Implements circuit breaker pattern, retry logic, and HTTP authentication
 *
 * @see https://goharbor.io/docs/2.10.0/swagger-api-definitions/
 */
class HarborApiClient
{
    protected string $baseUrl;
    protected ?string $username = null;
    protected ?string $password = null;
    protected int $timeout = 30;
    protected int $maxRetries = 3;
    protected array $circuitBreaker = [
        'failures' => 0,
        'last_failure' => null,
        'threshold' => 5,
        'timeout' => 60,
    ];

    public function __construct(
        ?string $baseUrl = null,
        ?string $username = null,
        ?string $password = null
    ) {
        $this->baseUrl = rtrim($baseUrl ?? config('harbor.base_url', 'https://harbor.aglz.io'), '/');
        $this->username = $username ?? config('harbor.username');
        $this->password = $password ?? config('harbor.password');
        $this->timeout = config('harbor.timeout', 30);

        if (empty($this->username) || empty($this->password)) {
            throw new \InvalidArgumentException('Harbor credentials are required. Set HARBOR_USERNAME and HARBOR_PASSWORD.');
        }
    }

    /**
     * Execute GET request
     */
    public function get(string $endpoint, array $params = []): ApiResponse
    {
        return $this->request('GET', $endpoint, $params);
    }

    /**
     * Execute POST request
     */
    public function post(string $endpoint, array $data = []): ApiResponse
    {
        return $this->request('POST', $endpoint, $data);
    }

    /**
     * Execute PUT request
     */
    public function put(string $endpoint, array $data = []): ApiResponse
    {
        return $this->request('PUT', $endpoint, $data);
    }

    /**
     * Execute PATCH request
     */
    public function patch(string $endpoint, array $data = []): ApiResponse
    {
        return $this->request('PATCH', $endpoint, $data);
    }

    /**
     * Execute DELETE request
     */
    public function delete(string $endpoint): ApiResponse
    {
        return $this->request('DELETE', $endpoint);
    }

    /**
     * Execute request with retry logic
     */
    protected function request(string $method, string $endpoint, array $params = []): ApiResponse
    {
        if ($this->isCircuitBreakerOpen()) {
            return new ApiResponse(
                success: false,
                data: [],
                error: 'Circuit breaker is open',
                statusCode: 503
            );
        }

        $attempt = 0;
        $lastException = null;

        while ($attempt < $this->maxRetries) {
            try {
                $response = $this->executeRequest($method, $endpoint, $params);

                if ($response->successful()) {
                    $this->resetCircuitBreaker();

                    $data = $response->json();

                    return new ApiResponse(
                        success: true,
                        data: is_array($data) ? $data : [$data],
                        statusCode: $response->status()
                    );
                }

                $this->recordFailure();

                $errorMessage = $response->body();
                if ($response->json()) {
                    $json = $response->json();
                    $errorMessage = $json['error'] ?? $json['message'] ?? $errorMessage;
                }

                return new ApiResponse(
                    success: false,
                    data: [],
                    error: is_string($errorMessage) ? $errorMessage : json_encode($errorMessage),
                    statusCode: $response->status()
                );

            } catch (Exception $e) {
                $lastException = $e;
                $attempt++;

                Log::warning("Harbor API request failed, attempt {$attempt}/{$this->maxRetries}", [
                    'endpoint' => $endpoint,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < $this->maxRetries) {
                    usleep(500000 * $attempt);
                }
            }
        }

        $this->recordFailure();

        return new ApiResponse(
            success: false,
            data: [],
            error: $lastException ? $lastException->getMessage() : 'Request failed after retries',
            statusCode: 500
        );
    }

    /**
     * Execute HTTP request with Basic Authentication
     */
    protected function executeRequest(string $method, string $endpoint, array $params = [])
    {
        $url = $this->baseUrl . $endpoint;

        $http = Http::withBasicAuth($this->username, $this->password)
            ->timeout($this->timeout)
            ->acceptJson()
            ->asJson();

        if (strtoupper($method) === 'GET' && !empty($params)) {
            return $http->get($url, $params);
        }

        return $http->{strtolower($method)}($url, $params);
    }

    /**
     * Check if circuit breaker is open
     */
    protected function isCircuitBreakerOpen(): bool
    {
        if ($this->circuitBreaker['failures'] < $this->circuitBreaker['threshold']) {
            return false;
        }

        $lastFailure = $this->circuitBreaker['last_failure'];
        if (!$lastFailure) {
            return false;
        }

        $elapsed = now()->diffInSeconds($lastFailure);
        return $elapsed < $this->circuitBreaker['timeout'];
    }

    /**
     * Record API failure for circuit breaker
     */
    protected function recordFailure(): void
    {
        $this->circuitBreaker['failures']++;
        $this->circuitBreaker['last_failure'] = now();

        if ($this->circuitBreaker['failures'] >= $this->circuitBreaker['threshold']) {
            Log::warning('Harbor API circuit breaker opened', [
                'failures' => $this->circuitBreaker['failures'],
            ]);
        }
    }

    /**
     * Reset circuit breaker
     */
    protected function resetCircuitBreaker(): void
    {
        $this->circuitBreaker['failures'] = 0;
        $this->circuitBreaker['last_failure'] = null;
    }

    /**
     * Get circuit breaker status
     */
    public function getCircuitBreakerStatus(): array
    {
        return [
            'is_open' => $this->isCircuitBreakerOpen(),
            'failures' => $this->circuitBreaker['failures'],
            'threshold' => $this->circuitBreaker['threshold'],
            'last_failure' => $this->circuitBreaker['last_failure']?->toIso8601String(),
        ];
    }

    /**
     * Test API connectivity
     */
    public function testConnection(): bool
    {
        try {
            $response = $this->get('/api/v2.0/systeminfo');
            return $response->isSuccess();
        } catch (Exception $e) {
            Log::error('Harbor connection test failed', [
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }
}
