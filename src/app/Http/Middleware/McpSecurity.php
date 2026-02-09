<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\SecurityAuditLog;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

/**
 * MCP Security Middleware
 *
 * Provides comprehensive security controls for Model Context Protocol (MCP) servers.
 * Implements API key authentication, rate limiting, IP whitelisting, and audit logging.
 *
 * @package App\Http\Middleware
 */
class McpSecurity
{
    /**
     * Handle an incoming request to MCP server.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        $startTime = microtime(true);

        // Perform security checks
        $this->validateContentType($request);
        $this->validateRequestSize($request);
        $this->checkIpWhitelist($request);
        $this->authenticateApiKey($request);
        $this->applyRateLimiting($request);

        // Process request
        $response = $next($request);

        // Add security headers
        $this->addSecurityHeaders($response);

        // Log audit event
        $this->logAuditEvent($request, $response, microtime(true) - $startTime);

        return $response;
    }

    /**
     * Validate request content type.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return void
     *
     * @throws \Symfony\Component\HttpKernel\Exception\BadRequestHttpException
     */
    protected function validateContentType(Request $request): void
    {
        $allowedTypes = config('mcp.validation.allowed_content_types', ['application/json']);
        $contentType = $request->header('Content-Type');

        if ($contentType && !in_array($contentType, $allowedTypes)) {
            abort(415, 'Unsupported Media Type');
        }
    }

    /**
     * Validate request size.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return void
     *
     * @throws \Symfony\Component\HttpKernel\Exception\BadRequestHttpException
     */
    protected function validateRequestSize(Request $request): void
    {
        $maxSize = config('mcp.validation.max_request_size', 10240); // 10MB
        $contentLength = (int) $request->header('Content-Length', 0);

        if ($contentLength > $maxSize * 1024) {
            abort(413, 'Request Entity Too Large');
        }
    }

    /**
     * Check if client IP is whitelisted.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return void
     *
     * @throws \Symfony\Component\HttpKernel\Exception\ForbiddenHttpException
     */
    protected function checkIpWhitelist(Request $request): void
    {
        if (!config('mcp.ip_whitelist.enabled', false)) {
            return;
        }

        $allowedIps = config('mcp.ip_whitelist.allowed_ips', []);
        $clientIp = $request->ip();

        if (empty($allowedIps)) {
            return;
        }

        $isAllowed = false;
        foreach ($allowedIps as $allowed) {
            if ($this->ipInRange($clientIp, $allowed)) {
                $isAllowed = true;
                break;
            }
        }

        if (!$isAllowed) {
            SecurityAuditLog::logSecurityEvent(
                auth()->user(),
                'mcp_ip_blocked',
                'MCP request from non-whitelisted IP',
                [
                    'ip' => $clientIp,
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                ]
            );

            abort(403, 'IP address not whitelisted');
        }
    }

    /**
     * Authenticate API key.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return void
     *
     * @throws \Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException
     */
    protected function authenticateApiKey(Request $request): void
    {
        $apiKey = $this->extractApiKey($request);

        if (!$apiKey) {
            abort(401, 'API key required');
        }

        $validKeys = config('mcp.api_keys', []);
        $isValid = false;

        foreach ($validKeys as $service => $key) {
            if (hash_equals($key, $apiKey)) {
                $isValid = true;
                $request->attributes->set('mcp_service', $service);
                break;
            }
        }

        if (!$isValid) {
            SecurityAuditLog::alert('Invalid MCP API key provided', [
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            abort(401, 'Invalid API key');
        }
    }

    /**
     * Apply rate limiting.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return void
     *
     * @throws \Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException
     */
    protected function applyRateLimiting(Request $request): void
    {
        if (!config('mcp.rate_limiting.enabled', true)) {
            return;
        }

        $key = 'mcp:' . $request->ip();
        $maxAttempts = config('mcp.rate_limiting.max_attempts', 60);
        $decayMinutes = config('mcp.rate_limiting.decay_minutes', 1);

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($key);

            SecurityAuditLog::logSecurityEvent(
                auth()->user(),
                'mcp_rate_limit_exceeded',
                'MCP rate limit exceeded',
                [
                    'ip' => $request->ip(),
                    'attempts' => RateLimiter::attempts($key),
                ]
            );

            abort(429, 'Too many requests. Try again in ' . $seconds . ' seconds.');
        }

        RateLimiter::hit($key, $decayMinutes * 60);
    }

    /**
     * Add security headers to response.
     *
     * @param  \Symfony\Component\HttpFoundation\Response  $response
     * @return void
     */
    protected function addSecurityHeaders(Response $response): void
    {
        $headers = config('mcp.headers', []);

        foreach ($headers as $key => $value) {
            $response->headers->set($key, $value);
        }

        // Add rate limit headers
        $response->headers->set('X-RateLimit-Limit', config('mcp.rate_limiting.max_attempts', 60));
        $response->headers->set('X-RateLimit-Remaining', (string) max(0, config('mcp.rate_limiting.max_attempts', 60) - RateLimiter::attempts('mcp:' . request()->ip())));
    }

    /**
     * Log audit event for MCP request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Symfony\Component\HttpFoundation\Response  $response
     * @param  float  $duration
     * @return void
     */
    protected function logAuditEvent(Request $request, Response $response, float $duration): void
    {
        if (!config('mcp.audit_logging.enabled', true)) {
            return;
        }

        $logData = [
            'mcp_service' => $request->attributes->get('mcp_service'),
            'ip' => $request->ip(),
            'method' => $request->method(),
            'url' => $request->fullUrl(),
            'status_code' => $response->getStatusCode(),
            'duration_ms' => round($duration * 1000, 2),
            'user_agent' => $request->userAgent(),
        ];

        SecurityAuditLog::log(
            'mcp.request',
            'MCP server request processed',
            array_merge($logData, [
                'severity' => $response->getStatusCode() >= 400 ? 'high' : 'info',
            ])
        );
    }

    /**
     * Extract API key from request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return string|null
     */
    protected function extractApiKey(Request $request): ?string
    {
        // Check X-API-Key header
        if ($request->hasHeader('X-API-Key')) {
            return $request->header('X-API-Key');
        }

        // Check Authorization header
        if ($request->hasHeader('Authorization')) {
            $auth = $request->header('Authorization');
            if (str_starts_with($auth, 'Bearer ')) {
                return substr($auth, 7);
            }
        }

        // Check query parameter
        if ($request->has('api_key')) {
            return $request->input('api_key');
        }

        return null;
    }

    /**
     * Check if IP is in range (supports CIDR notation).
     *
     * @param  string  $ip
     * @param  string  $range
     * @return bool
     */
    protected function ipInRange(string $ip, string $range): bool
    {
        if (str_contains($range, '/')) {
            [$subnet, $bits] = explode('/', $range);
            $ipLong = ip2long($ip);
            $subnetLong = ip2long($subnet);
            $mask = -1 << (32 - $bits);

            return ($ipLong & $mask) === ($subnetLong & $mask);
        }

        return $ip === $range;
    }
}
