<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\SecurityAuditLog;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

/**
 * MCP Security Middleware
 *
 * Provides comprehensive security controls for Model Context Protocol (MCP) servers.
 * Implements API key authentication, rate limiting, IP whitelisting, and audit logging.
 */
class McpSecurity
{
    /**
     * Handle an incoming request to MCP server.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $startTime = microtime(true);

        try {
            $this->validateRequestSize($request);
            $this->validateContentType($request);
            $this->checkIpWhitelist($request);
            $this->authenticateApiKey($request);
            $this->applyRateLimiting($request);
        } catch (HttpExceptionInterface $exception) {
            return response($exception->getMessage(), $exception->getStatusCode());
        }

        // Process request
        $response = $next($request);

        // Add security headers
        $this->addSecurityHeaders($response, $request);

        // Log audit event
        $this->logAuditEvent($request, $response, microtime(true) - $startTime);

        return $response;
    }

    /**
     * Validate request content type.
     *
     *
     * @throws \Symfony\Component\HttpKernel\Exception\BadRequestHttpException
     */
    protected function validateContentType(Request $request): void
    {
        $allowedTypes = config('mcp.validation.allowed_content_types', ['application/json']);
        $contentType = $request->header('Content-Type');
        $isEmptyRequest = (int) $request->header('Content-Length', 0) === 0 && $request->getContent() === '';

        if ($contentType && ! in_array($contentType, $allowedTypes) && ! ($isEmptyRequest && str_starts_with($contentType, 'application/x-www-form-urlencoded'))) {
            abort(415, 'Unsupported Media Type');
        }

        if ($isEmptyRequest) {
            return;
        }
    }

    /**
     * Validate request size.
     *
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
     *
     * @throws \Symfony\Component\HttpKernel\Exception\ForbiddenHttpException
     */
    protected function checkIpWhitelist(Request $request): void
    {
        if (! config('mcp.ip_whitelist.enabled', false)) {
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

        if (! $isAllowed) {
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
     * Authenticate API key and determine role.
     *
     *
     * @throws \Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException
     */
    protected function authenticateApiKey(Request $request): void
    {
        $apiKey = $this->extractApiKey($request);

        if (! $apiKey) {
            // Allow authenticated users to proceed without API key
            if (auth()->check()) {
                $request->attributes->set('mcp_service', 'user');
                $request->attributes->set('mcp_role', auth()->user()->getPrimaryRoleAttribute()?->name ?? 'viewer');

                return;
            }
            abort(401, 'API key required');
        }

        $validKeys = config('mcp.api_keys', []);
        $isValid = false;

        foreach ($validKeys as $service => $key) {
            if (! is_string($key)) {
                continue;
            }

            if (hash_equals($key, $apiKey)) {
                $isValid = true;
                $request->attributes->set('mcp_service', $service);
                // Map service to role based on RBAC configuration
                $role = $this->getRoleForService($service);
                $request->attributes->set('mcp_role', $role);
                break;
            }
        }

        if (! $isValid) {
            SecurityAuditLog::alert('Invalid MCP API key provided', [
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            abort(401, 'Invalid API key');
        }
    }

    /**
     * Get role for MCP service.
     */
    protected function getRoleForService(string $service): string
    {
        $roleMapping = [
            'laravel_boost' => 'operator',
            'shadcn' => 'viewer',
            'ruv_swarm' => 'admin',
        ];

        return $roleMapping[$service] ?? 'viewer';
    }

    /**
     * Apply rate limiting based on role.
     *
     *
     * @throws \Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException
     */
    protected function applyRateLimiting(Request $request): void
    {
        if (! config('mcp.rate_limiting.enabled', true)) {
            return;
        }

        // Get rate limit based on role
        $role = $request->attributes->get('mcp_role', 'viewer');
        $roleLimits = [
            'admin' => 1000,
            'operator' => 500,
            'auditor' => 200,
            'viewer' => 100,
        ];

        $maxAttempts = config('mcp.rate_limiting.max_attempts') ?? ($roleLimits[$role] ?? 60);
        $decayMinutes = config('mcp.rate_limiting.decay_minutes', 1);
        $key = 'mcp:rbac:'.$role.':'.$request->ip();

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($key);

            SecurityAuditLog::logSecurityEvent(
                auth()->user(),
                'mcp_rate_limit_exceeded',
                'MCP rate limit exceeded',
                [
                    'ip' => $request->ip(),
                    'role' => $role,
                    'attempts' => RateLimiter::attempts($key),
                ]
            );

            abort(429, 'Too many requests. Try again in '.$seconds.' seconds.');
        }

        RateLimiter::hit($key, $decayMinutes * 60);
    }

    /**
     * Add security headers to response.
     */
    protected function addSecurityHeaders(Response $response, Request $request): void
    {
        $headers = config('mcp.headers', []);

        foreach ($headers as $key => $value) {
            $response->headers->set($key, $value);
        }

        // Add rate limit headers based on role
        $role = $request->attributes->get('mcp_role', 'viewer');
        $roleLimits = [
            'admin' => 1000,
            'operator' => 500,
            'auditor' => 200,
            'viewer' => 100,
        ];
        $maxAttempts = config('mcp.rate_limiting.max_attempts') ?? ($roleLimits[$role] ?? 60);
        $key = 'mcp:rbac:'.$role.':'.$request->ip();

        $response->headers->set('X-RateLimit-Limit', (string) $maxAttempts);
        $response->headers->set('X-RateLimit-Remaining', (string) max(0, $maxAttempts - RateLimiter::attempts($key)));
        $response->headers->set('X-MCP-Role', $role);
    }

    /**
     * Log audit event for MCP request.
     */
    protected function logAuditEvent(Request $request, Response $response, float $duration): void
    {
        if (! config('mcp.audit_logging.enabled', true)) {
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
