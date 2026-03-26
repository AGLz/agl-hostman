<?php

namespace App\Services;

use App\DTOs\ApiResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * DokployApiClient - API abstraction layer for Dokploy platform
 *
 * Implements circuit breaker pattern, retry logic, and JWT authentication
 * Based on Dokploy API documentation and ProxmoxApiClient pattern
 *
 * @see https://docs.dokploy.com/docs/api
 */
class DokployApiClient
{
    protected string $baseUrl;

    protected ?string $apiKey = null;

    protected int $timeout = 30;

    protected int $maxRetries = 3;

    protected array $circuitBreaker = [
        'failures' => 0,
        'last_failure' => null,
        'threshold' => 5,
        'timeout' => 60, // seconds
    ];

    /**
     * Create Dokploy API client instance
     *
     * @param  string  $baseUrl  Dokploy base URL (e.g., 'https://dok.aglz.io')
     * @param  string  $apiKey  JWT API token from /settings/profile
     */
    public function __construct(
        ?string $baseUrl = null,
        ?string $apiKey = null
    ) {
        $this->baseUrl = rtrim($baseUrl ?? config('dokploy.base_url', 'https://dok.aglz.io'), '/');
        $this->apiKey = $apiKey ?? config('dokploy.api_key');

        if (empty($this->apiKey)) {
            throw new \InvalidArgumentException('Dokploy API key is required. Generate at /settings/profile');
        }
    }

    /**
     * Get all applications
     */
    public function getApplications(): ApiResponse
    {
        return $this->request('GET', '/api/application.all');
    }

    /**
     * Get single application by ID
     *
     * @param  string  $applicationId  Application ID
     */
    public function getApplication(string $applicationId): ApiResponse
    {
        return $this->request('GET', '/api/application.one', [
            'applicationId' => $applicationId,
        ]);
    }

    /**
     * Create new application
     *
     * @param  array  $data  Application configuration
     */
    public function createApplication(array $data): ApiResponse
    {
        return $this->request('POST', '/api/application.create', $data);
    }

    /**
     * Start application
     *
     * @param  string  $applicationId  Application ID
     */
    public function startApplication(string $applicationId): ApiResponse
    {
        return $this->request('POST', '/api/application.start', [
            'applicationId' => $applicationId,
        ]);
    }

    /**
     * Stop application
     *
     * @param  string  $applicationId  Application ID
     */
    public function stopApplication(string $applicationId): ApiResponse
    {
        return $this->request('POST', '/api/application.stop', [
            'applicationId' => $applicationId,
        ]);
    }

    /**
     * Redeploy application (trigger new deployment)
     *
     * @param  string  $applicationId  Application ID
     */
    public function redeployApplication(string $applicationId): ApiResponse
    {
        return $this->request('POST', '/api/application.redeploy', [
            'applicationId' => $applicationId,
        ]);
    }

    /**
     * Delete application
     *
     * @param  string  $applicationId  Application ID
     */
    public function deleteApplication(string $applicationId): ApiResponse
    {
        return $this->request('POST', '/api/application.delete', [
            'applicationId' => $applicationId,
        ]);
    }

    /**
     * Get all projects
     */
    public function getProjects(): ApiResponse
    {
        return $this->request('GET', '/api/project.all');
    }

    /**
     * Get single project by ID
     *
     * @param  string  $projectId  Project ID
     */
    public function getProject(string $projectId): ApiResponse
    {
        return $this->request('GET', '/api/project.one', [
            'projectId' => $projectId,
        ]);
    }

    /**
     * Create new project
     *
     * @param  array  $data  Project configuration
     */
    public function createProject(array $data): ApiResponse
    {
        return $this->request('POST', '/api/project.create', $data);
    }

    /**
     * Execute generic API request with retry logic
     *
     * @param  string  $method  HTTP method
     * @param  string  $endpoint  API endpoint
     * @param  array  $params  Request parameters
     */
    protected function request(string $method, string $endpoint, array $params = []): ApiResponse
    {
        // Check circuit breaker
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

                    // Dokploy returns data directly or in data field
                    $responseData = $response->json();
                    $data = isset($responseData['data']) ? $responseData['data'] : $responseData;

                    return new ApiResponse(
                        success: true,
                        data: is_array($data) ? $data : [$data],
                        statusCode: $response->status()
                    );
                }

                $this->recordFailure();

                $errorBody = $response->json();
                $errorMessage = $errorBody['message'] ?? $errorBody['error'] ?? $response->body();

                return new ApiResponse(
                    success: false,
                    data: [],
                    error: is_string($errorMessage) ? $errorMessage : json_encode($errorMessage),
                    statusCode: $response->status()
                );

            } catch (\Exception $e) {
                $lastException = $e;
                $attempt++;

                Log::warning("Dokploy API request failed, attempt {$attempt}/{$this->maxRetries}", [
                    'endpoint' => $endpoint,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < $this->maxRetries) {
                    usleep(500000 * $attempt); // 0.5s, 1s, 1.5s exponential backoff
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
     * Execute HTTP request with JWT authentication
     */
    protected function executeRequest(string $method, string $endpoint, array $params = [])
    {
        $url = $this->baseUrl.$endpoint;

        $headers = [
            'x-api-key' => $this->apiKey,
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];

        $http = Http::withHeaders($headers)
            ->timeout($this->timeout);

        // GET requests use query parameters, POST/PUT/DELETE use body
        if (strtoupper($method) === 'GET' && ! empty($params)) {
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
        if (! $lastFailure) {
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
            Log::warning('Dokploy API circuit breaker opened', [
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
     * Convenience method for GET requests
     *
     * @param  string  $endpoint  API endpoint
     * @param  array  $params  Query parameters
     * @return array Response data ['data' => mixed, 'status' => int]
     *
     * @throws \Exception When the request fails
     */
    public function get(string $endpoint, array $params = []): array
    {
        $response = $this->request('GET', $endpoint, $params);

        if (! $response->success) {
            throw new \Exception($response->error ?? 'Request failed');
        }

        return [
            'data' => $response->data,
            'status' => $response->statusCode,
        ];
    }

    /**
     * Convenience method for POST requests
     *
     * @param  string  $endpoint  API endpoint
     * @param  array  $params  Request body parameters
     * @return array Response data ['data' => mixed, 'status' => int]
     *
     * @throws \Exception When the request fails
     */
    public function post(string $endpoint, array $params = []): array
    {
        $response = $this->request('POST', $endpoint, $params);

        if (! $response->success) {
            throw new \Exception($response->error ?? 'Request failed');
        }

        return [
            'data' => $response->data,
            'status' => $response->statusCode,
        ];
    }

    /**
     * Test API connectivity and authentication
     *
     * @return bool True if API is accessible and authenticated
     */
    public function testConnection(): bool
    {
        try {
            $response = $this->getProjects();

            return $response->isSuccess();
        } catch (\Exception $e) {
            Log::error('Dokploy API connection test failed', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }
}
