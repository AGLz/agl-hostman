<?php

declare(strict_types=1);

namespace App\Services\Proxmox;

use App\DTO\ProxmoxApiResponse;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Psr\Log\LoggerInterface;

/**
 * Proxmox VE API Client
 *
 * Robust HTTP client for Proxmox VE API interactions with:
 * - Automatic authentication and token refresh
 * - Connection pooling and retry logic
 * - Rate limiting and circuit breaker
 * - Comprehensive error handling
 */
class ProxmoxApiClient
{
    private const TOKEN_CACHE_PREFIX = 'proxmox_token_';

    private const CIRCUIT_BREAKER_PREFIX = 'proxmox_circuit_';

    private const RATE_LIMIT_PREFIX = 'proxmox_rate_';

    private const MAX_RETRIES = 3;

    private const RETRY_DELAY_MS = 500;

    private const REQUEST_TIMEOUT = 30;

    private const TOKEN_TTL = 7200; // 2 hours

    private ?string $authToken = null;

    private ?string $csrfToken = null;

    public function __construct(
        private readonly string $host,
        private readonly int $port,
        private readonly string $username,
        private readonly string $password,
        private readonly string $realm = 'pam',
        private readonly bool $verifySSL = false,
        private readonly LoggerInterface $logger = new \Psr\Log\NullLogger,
    ) {}

    /**
     * Create from config
     *
     * @param  array<string, mixed>  $config
     */
    public static function fromConfig(array $config): self
    {
        return new self(
            host: $config['host'] ?? throw new \InvalidArgumentException('Host is required'),
            port: (int) ($config['port'] ?? 8006),
            username: $config['username'] ?? throw new \InvalidArgumentException('Username is required'),
            password: $config['password'] ?? throw new \InvalidArgumentException('Password is required'),
            realm: $config['realm'] ?? 'pam',
            verifySSL: (bool) ($config['verify_ssl'] ?? false),
            logger: Log::channel($config['log_channel'] ?? 'default'),
        );
    }

    /**
     * Authenticate and get API ticket
     *
     * @throws \RuntimeException
     */
    public function authenticate(): ProxmoxApiResponse
    {
        $cacheKey = self::TOKEN_CACHE_PREFIX.md5($this->host.$this->username);

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached) {
            $this->authToken = $cached['ticket'];
            $this->csrfToken = $cached['csrf_token'];

            return ProxmoxApiResponse::success(['cached' => true]);
        }

        try {
            $response = $this->buildRequest(authenticated: false)
                ->post($this->buildUrl('/api2/json/access/ticket'), [
                    'username' => $this->username.'@'.$this->realm,
                    'password' => $this->password,
                ]);

            if (! $response->successful()) {
                return ProxmoxApiResponse::fromHttpResponse($response);
            }

            $data = $response->json('data');
            $this->authToken = $data['ticket'];
            $this->csrfToken = $data['CSRFPreventionToken'];

            // Cache tokens
            Cache::put($cacheKey, [
                'ticket' => $this->authToken,
                'csrf_token' => $this->csrfToken,
            ], self::TOKEN_TTL);

            $this->logger->info('Proxmox authentication successful', [
                'host' => $this->host,
                'username' => $this->username,
            ]);

            return ProxmoxApiResponse::success($data);

        } catch (\Exception $e) {
            $this->logger->error('Proxmox authentication failed', [
                'host' => $this->host,
                'error' => $e->getMessage(),
            ]);

            return ProxmoxApiResponse::error($e->getMessage(), 500);
        }
    }

    /**
     * Make authenticated GET request
     *
     * @param  array<string, mixed>  $query
     */
    public function get(string $endpoint, array $query = []): ProxmoxApiResponse
    {
        return $this->request('GET', $endpoint, [], $query);
    }

    /**
     * Make authenticated POST request
     *
     * @param  array<string, mixed>  $data
     */
    public function post(string $endpoint, array $data = []): ProxmoxApiResponse
    {
        return $this->request('POST', $endpoint, $data);
    }

    /**
     * Make authenticated PUT request
     *
     * @param  array<string, mixed>  $data
     */
    public function put(string $endpoint, array $data = []): ProxmoxApiResponse
    {
        return $this->request('PUT', $endpoint, $data);
    }

    /**
     * Make authenticated DELETE request
     */
    public function delete(string $endpoint): ProxmoxApiResponse
    {
        return $this->request('DELETE', $endpoint);
    }

    /**
     * Make HTTP request with retry logic
     *
     * @param  array<string, mixed>  $data
     * @param  array<string, mixed>  $query
     */
    private function request(
        string $method,
        string $endpoint,
        array $data = [],
        array $query = []
    ): ProxmoxApiResponse {
        // Check circuit breaker
        if ($this->isCircuitOpen()) {
            return ProxmoxApiResponse::error('Circuit breaker is open', 503);
        }

        // Rate limiting
        if (! $this->checkRateLimit()) {
            return ProxmoxApiResponse::error('Rate limit exceeded', 429);
        }

        // Ensure authenticated
        if (! $this->authToken) {
            $authResponse = $this->authenticate();
            if (! $authResponse->success) {
                return $authResponse;
            }
        }

        $attempt = 0;
        $lastException = null;

        while ($attempt < self::MAX_RETRIES) {
            try {
                $request = $this->buildRequest(authenticated: true);
                $url = $this->buildUrl($endpoint);

                $response = match ($method) {
                    'GET' => $request->get($url, $query),
                    'POST' => $request->post($url, $data),
                    'PUT' => $request->put($url, $data),
                    'DELETE' => $request->delete($url),
                    default => throw new \InvalidArgumentException("Unsupported method: {$method}"),
                };

                // Handle authentication expiry
                if ($response->status() === 401) {
                    $this->clearAuthCache();
                    $this->authToken = null;

                    if ($attempt < self::MAX_RETRIES - 1) {
                        $this->authenticate();
                        $attempt++;

                        continue;
                    }
                }

                if ($response->successful()) {
                    $this->recordSuccess();
                }

                return ProxmoxApiResponse::fromHttpResponse($response);

            } catch (\Exception $e) {
                $lastException = $e;
                $this->logger->warning('Proxmox API request failed', [
                    'method' => $method,
                    'endpoint' => $endpoint,
                    'attempt' => $attempt + 1,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < self::MAX_RETRIES - 1) {
                    usleep(self::RETRY_DELAY_MS * 1000 * ($attempt + 1)); // Exponential backoff
                }

                $attempt++;
            }
        }

        $this->recordFailure();

        return ProxmoxApiResponse::error(
            $lastException?->getMessage() ?? 'Request failed after retries',
            500
        );
    }

    /**
     * Build HTTP client request
     */
    private function buildRequest(bool $authenticated = false): PendingRequest
    {
        $request = Http::timeout(self::REQUEST_TIMEOUT)
            ->connectTimeout(5)
            ->withHeaders([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]);

        if (! $this->verifySSL) {
            $request = $request->withoutVerifying();
        }

        if ($authenticated && $this->authToken) {
            $request = $request->withHeaders([
                'Cookie' => 'PVEAuthCookie='.$this->authToken,
            ]);

            if ($this->csrfToken) {
                $request = $request->withHeaders([
                    'CSRFPreventionToken' => $this->csrfToken,
                ]);
            }
        }

        return $request;
    }

    /**
     * Build full API URL
     */
    private function buildUrl(string $endpoint): string
    {
        $endpoint = ltrim($endpoint, '/');

        if (! str_starts_with($endpoint, 'api2/json/')) {
            $endpoint = 'api2/json/'.$endpoint;
        }

        return sprintf('https://%s:%d/%s', $this->host, $this->port, $endpoint);
    }

    /**
     * Check circuit breaker status
     */
    private function isCircuitOpen(): bool
    {
        $key = self::CIRCUIT_BREAKER_PREFIX.md5($this->host);
        $failures = Cache::get($key, 0);

        return $failures >= 5; // Open circuit after 5 failures
    }

    /**
     * Record successful request
     */
    private function recordSuccess(): void
    {
        $key = self::CIRCUIT_BREAKER_PREFIX.md5($this->host);
        Cache::forget($key);
    }

    /**
     * Record failed request
     */
    private function recordFailure(): void
    {
        $key = self::CIRCUIT_BREAKER_PREFIX.md5($this->host);
        $failures = Cache::get($key, 0);
        Cache::put($key, $failures + 1, 300); // 5 minutes
    }

    /**
     * Check rate limit
     */
    private function checkRateLimit(): bool
    {
        $key = self::RATE_LIMIT_PREFIX.md5($this->host);
        $count = Cache::get($key, 0);

        if ($count >= 100) { // Max 100 requests per minute
            return false;
        }

        Cache::put($key, $count + 1, 60);

        return true;
    }

    /**
     * Clear authentication cache
     */
    private function clearAuthCache(): void
    {
        $cacheKey = self::TOKEN_CACHE_PREFIX.md5($this->host.$this->username);
        Cache::forget($cacheKey);
    }

    /**
     * Test connection
     */
    public function testConnection(): ProxmoxApiResponse
    {
        return $this->get('/version');
    }
}
