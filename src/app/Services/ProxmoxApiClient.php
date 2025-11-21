<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\DTOs\ProxmoxApiResponse;

/**
 * ProxmoxApiClient - API abstraction layer for Proxmox VE
 *
 * Implements circuit breaker pattern, retry logic, and connection pooling
 * Based on IMPLEMENTATION-SUMMARY.md recommendations
 *
 * @see https://pve.proxmox.com/wiki/Proxmox_VE_API
 */
class ProxmoxApiClient
{
    protected string $baseUrl;
    protected string $username;
    protected string $password;
    protected ?string $apiToken = null;
    protected ?string $csrfToken = null;
    protected int $timeout = 30;
    protected int $maxRetries = 3;
    protected array $circuitBreaker = [
        'failures' => 0,
        'last_failure' => null,
        'threshold' => 5,
        'timeout' => 60, // seconds
    ];

    /**
     * Create Proxmox API client instance
     *
     * @param string $host Proxmox host (e.g., '192.168.0.245' or 'pve1.local')
     * @param int $port Proxmox API port (default: 8006)
     * @param string $username Username (e.g., 'root@pam')
     * @param string $password Password or API token
     * @param bool $verifySSL Verify SSL certificates (default: false for self-signed)
     */
    public function __construct(
        string $host,
        int $port = 8006,
        ?string $username = null,
        ?string $password = null,
        bool $verifySSL = false
    ) {
        $this->baseUrl = "https://{$host}:{$port}/api2/json";
        $this->username = $username ?? config('proxmox.username', 'root@pam');
        $this->password = $password ?? config('proxmox.password');

        // Configure HTTP client defaults
        Http::withOptions([
            'verify' => $verifySSL,
            'timeout' => $this->timeout,
        ]);
    }

    /**
     * Authenticate and get API ticket
     *
     * @return bool Success status
     */
    public function authenticate(): bool
    {
        // Check if circuit breaker is open
        if ($this->isCircuitBreakerOpen()) {
            Log::warning('Proxmox API circuit breaker is open, skipping authentication');
            return false;
        }

        try {
            $response = Http::asForm()->post("{$this->baseUrl}/access/ticket", [
                'username' => $this->username,
                'password' => $this->password,
            ]);

            if ($response->successful()) {
                $data = $response->json()['data'] ?? [];
                $this->apiToken = $data['ticket'] ?? null;
                $this->csrfToken = $data['CSRFPreventionToken'] ?? null;

                // Cache authentication tokens (1 hour)
                Cache::put('proxmox_auth_token', $this->apiToken, now()->addHour());
                Cache::put('proxmox_csrf_token', $this->csrfToken, now()->addHour());

                $this->resetCircuitBreaker();

                Log::info('Proxmox API authenticated successfully');
                return true;
            }

            $this->recordFailure();
            Log::error('Proxmox API authentication failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return false;

        } catch (\Exception $e) {
            $this->recordFailure();
            Log::error('Proxmox API authentication exception', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Get list of nodes in cluster
     *
     * @return ProxmoxApiResponse
     */
    public function getNodes(): ProxmoxApiResponse
    {
        return $this->request('GET', '/nodes');
    }

    /**
     * Get node status
     *
     * @param string $node Node name (e.g., 'pve1')
     * @return ProxmoxApiResponse
     */
    public function getNodeStatus(string $node): ProxmoxApiResponse
    {
        return $this->request('GET', "/nodes/{$node}/status");
    }

    /**
     * Get list of LXC containers on node
     *
     * @param string $node Node name
     * @return ProxmoxApiResponse
     */
    public function getContainers(string $node): ProxmoxApiResponse
    {
        return $this->request('GET', "/nodes/{$node}/lxc");
    }

    /**
     * Get container status
     *
     * @param string $node Node name
     * @param int $vmid Container ID (e.g., 179)
     * @return ProxmoxApiResponse
     */
    public function getContainerStatus(string $node, int $vmid): ProxmoxApiResponse
    {
        return $this->request('GET', "/nodes/{$node}/lxc/{$vmid}/status/current");
    }

    /**
     * Get container configuration
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @return ProxmoxApiResponse
     */
    public function getContainerConfig(string $node, int $vmid): ProxmoxApiResponse
    {
        return $this->request('GET', "/nodes/{$node}/lxc/{$vmid}/config");
    }

    /**
     * Start container
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @return ProxmoxApiResponse
     */
    public function startContainer(string $node, int $vmid): ProxmoxApiResponse
    {
        return $this->request('POST', "/nodes/{$node}/lxc/{$vmid}/status/start");
    }

    /**
     * Stop container
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @return ProxmoxApiResponse
     */
    public function stopContainer(string $node, int $vmid): ProxmoxApiResponse
    {
        return $this->request('POST', "/nodes/{$node}/lxc/{$vmid}/status/stop");
    }

    /**
     * Get cluster resources (overview of all VMs/containers)
     *
     * @param string|null $type Filter by type (vm, storage, node)
     * @return ProxmoxApiResponse
     */
    public function getClusterResources(?string $type = null): ProxmoxApiResponse
    {
        $params = $type ? ['type' => $type] : [];
        return $this->request('GET', '/cluster/resources', $params);
    }

    /**
     * Execute generic API request with retry logic
     *
     * @param string $method HTTP method
     * @param string $endpoint API endpoint
     * @param array $params Request parameters
     * @return ProxmoxApiResponse
     */
    protected function request(string $method, string $endpoint, array $params = []): ProxmoxApiResponse
    {
        // Check circuit breaker
        if ($this->isCircuitBreakerOpen()) {
            return new ProxmoxApiResponse(
                success: false,
                data: [],
                error: 'Circuit breaker is open',
                statusCode: 503
            );
        }

        // Ensure authenticated
        if (!$this->apiToken) {
            $cachedToken = Cache::get('proxmox_auth_token');
            $cachedCsrf = Cache::get('proxmox_csrf_token');

            if ($cachedToken && $cachedCsrf) {
                $this->apiToken = $cachedToken;
                $this->csrfToken = $cachedCsrf;
            } else {
                if (!$this->authenticate()) {
                    return new ProxmoxApiResponse(
                        success: false,
                        data: [],
                        error: 'Authentication failed',
                        statusCode: 401
                    );
                }
            }
        }

        $attempt = 0;
        $lastException = null;

        while ($attempt < $this->maxRetries) {
            try {
                $response = $this->executeRequest($method, $endpoint, $params);

                if ($response->successful()) {
                    $this->resetCircuitBreaker();

                    return new ProxmoxApiResponse(
                        success: true,
                        data: $response->json()['data'] ?? [],
                        statusCode: $response->status()
                    );
                }

                // Handle 401 - re-authenticate
                if ($response->status() === 401 && $attempt === 0) {
                    $this->apiToken = null;
                    $this->csrfToken = null;
                    Cache::forget('proxmox_auth_token');
                    Cache::forget('proxmox_csrf_token');

                    if ($this->authenticate()) {
                        $attempt++;
                        continue;
                    }
                }

                $this->recordFailure();

                return new ProxmoxApiResponse(
                    success: false,
                    data: [],
                    error: $response->body(),
                    statusCode: $response->status()
                );

            } catch (\Exception $e) {
                $lastException = $e;
                $attempt++;

                Log::warning("Proxmox API request failed, attempt {$attempt}/{$this->maxRetries}", [
                    'endpoint' => $endpoint,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < $this->maxRetries) {
                    usleep(500000 * $attempt); // 0.5s, 1s, 1.5s backoff
                }
            }
        }

        $this->recordFailure();

        return new ProxmoxApiResponse(
            success: false,
            data: [],
            error: $lastException ? $lastException->getMessage() : 'Request failed after retries',
            statusCode: 500
        );
    }

    /**
     * Execute HTTP request
     */
    protected function executeRequest(string $method, string $endpoint, array $params = [])
    {
        $url = $this->baseUrl . $endpoint;

        $headers = [
            'Cookie' => "PVEAuthCookie={$this->apiToken}",
            'CSRFPreventionToken' => $this->csrfToken,
        ];

        return Http::withHeaders($headers)
            ->{strtolower($method)}($url, $params);
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
            Log::warning('Proxmox API circuit breaker opened', [
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
     * @param string $endpoint API endpoint
     * @param array $params Query parameters
     * @return array Response data ['data' => mixed, 'status' => int]
     * @throws \Exception When the request fails
     */
    public function get(string $endpoint, array $params = []): array
    {
        $response = $this->request('GET', $endpoint, $params);

        if (!$response->success) {
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
     * @param string $endpoint API endpoint
     * @param array $params Request body parameters
     * @return array Response data ['data' => mixed, 'status' => int]
     * @throws \Exception When the request fails
     */
    public function post(string $endpoint, array $params = []): array
    {
        $response = $this->request('POST', $endpoint, $params);

        if (!$response->success) {
            throw new \Exception($response->error ?? 'Request failed');
        }

        return [
            'data' => $response->data,
            'status' => $response->statusCode,
        ];
    }
}
