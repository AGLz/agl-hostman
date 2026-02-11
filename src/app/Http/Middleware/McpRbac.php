<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\SecurityAuditLog;
use App\Services\SecretsManagementService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * MCP RBAC Middleware
 *
 * Role-Based Access Control middleware for Model Context Protocol (MCP) servers.
 * Enforces fine-grained access control based on user roles and permissions.
 *
 * @package App\Http\Middleware
 */
class McpRbac
{
    /**
     * The secrets management service instance.
     */
    protected SecretsManagementService $secretsService;

    /**
     * RBAC configuration loaded from config/rbac.yaml.
     */
    protected array $rbacConfig;

    /**
     * Create a new middleware instance.
     */
    public function __construct(SecretsManagementService $secretsService)
    {
        $this->secretsService = $secretsService;
        $this->rbacConfig = $this->loadRbacConfig();
    }

    /**
     * Handle an incoming request to MCP server.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        $startTime = microtime(true);

        // Get authenticated user or API key
        $identity = $this->resolveIdentity($request);

        // Determine role level
        $role = $this->getUserRole($identity);
        $accessLevel = $this->rbacConfig['mcp_role_mapping'][$role['name']]['access_level'] ?? 'none';

        // Check tool-specific access
        $tool = $this->extractToolName($request);
        if (!$this->hasToolAccess($role['name'], $tool)) {
            return $this->denyAccess($request, $identity, 'tool_not_allowed', [
                'tool' => $tool,
                'role' => $role['name'],
            ]);
        }

        // Enforce rate limits based on role
        if (!$this->checkRateLimit($request, $role['name'])) {
            return $this->denyAccess($request, $identity, 'rate_limit_exceeded', [
                'role' => $role['name'],
            ]);
        }

        // Attach role info to request for downstream use
        $request->attributes->set('mcp_role', $role['name']);
        $request->attributes->set('mcp_access_level', $accessLevel);

        // Process request
        $response = $next($request);

        // Log successful access
        $this->logAccess($request, $response, $identity, $role, microtime(true) - $startTime);

        return $response;
    }

    /**
     * Resolve the authenticated identity (user or API key).
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array{type: 'user'|'api_key', id: string|int, name: string}
     */
    protected function resolveIdentity(Request $request): array
    {
        // Check for authenticated user
        if (auth()->check()) {
            $user = auth()->user();
            return [
                'type' => 'user',
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ];
        }

        // Check for API key
        $apiKey = $this->extractApiKey($request);
        if ($apiKey) {
            return [
                'type' => 'api_key',
                'id' => $apiKey['id'],
                'name' => $apiKey['name'] ?? 'API Key',
                'roles' => $apiKey['roles'] ?? [],
            ];
        }

        // No valid identity
        return [
            'type' => 'anonymous',
            'id' => null,
            'name' => 'Anonymous',
        ];
    }

    /**
     * Get user's primary role with permissions.
     *
     * @param  array  $identity
     * @return array{name: string, level: int, permissions: array}
     */
    protected function getUserRole(array $identity): array
    {
        if ($identity['type'] === 'user') {
            $user = auth()->user();
            $role = $user->roles()->orderBy('level', 'desc')->first();

            return [
                'name' => $role?->name ?? 'viewer',
                'level' => $role?->level ?? 0,
                'permissions' => $user->getAllPermissions()->pluck('name')->toArray(),
            ];
        }

        if ($identity['type'] === 'api_key') {
            // API keys have roles attached
            $apiRoles = $identity['roles'] ?? ['viewer'];
            $primaryRole = $apiRoles[0] ?? 'viewer';

            return [
                'name' => $primaryRole,
                'level' => $this->rbacConfig['roles'][$primaryRole]['level'] ?? 0,
                'permissions' => $this->rbacConfig['api_key_permissions'][$primaryRole . '_key']['permissions'] ?? [],
            ];
        }

        // Default to viewer with minimal access
        return [
            'name' => 'viewer',
            'level' => 25,
            'permissions' => ['view-dashboard'],
        ];
    }

    /**
     * Check if role has access to specific MCP tool.
     *
     * @param  string  $role
     * @param  string  $tool
     * @return bool
     */
    protected function hasToolAccess(string $role, string $tool): bool
    {
        $roleConfig = $this->rbacConfig['mcp_role_mapping'][$role] ?? null;
        if (!$roleConfig) {
            return false;
        }

        $allowedTools = $roleConfig['allowed_tools'] ?? [];

        // Wildcard access
        if (in_array('*', $allowedTools)) {
            return true;
        }

        // Pattern matching (e.g., "container.*" matches "container.start")
        foreach ($allowedTools as $allowed) {
            if ($this->matchToolPattern($allowed, $tool)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Match tool name against pattern.
     *
     * @param  string  $pattern
     * @param  string  $tool
     * @return bool
     */
    protected function matchToolPattern(string $pattern, string $tool): bool
    {
        if ($pattern === '*') {
            return true;
        }

        if (str_ends_with($pattern, '.*')) {
            $prefix = str_replace('.*', '', $pattern);
            return str_starts_with($tool, $prefix . '.');
        }

        return $pattern === $tool;
    }

    /**
     * Extract tool name from MCP request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return string
     */
    protected function extractToolName(Request $request): string
    {
        $body = $request->json()->all();

        // MCP request format: { method: "tools/call", params: { name: "tool_name" } }
        if (isset($body['params']['name'])) {
            return $body['params']['name'];
        }

        // Legacy format
        if (isset($body['tool'])) {
            return $body['tool'];
        }

        return 'unknown';
    }

    /**
     * Check rate limit for role.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  string  $role
     * @return bool
     */
    protected function checkRateLimit(Request $request, string $role): bool
    {
        $roleConfig = $this->rbacConfig['mcp_role_mapping'][$role] ?? null;
        if (!$roleConfig) {
            return false;
        }

        $rateLimit = $roleConfig['rate_limit'] ?? 100;

        // Use Laravel's rate limiter
        $key = 'mcp:rbac:' . $role . ':' . $request->ip();
        $attempts = \Illuminate\Support\Facades\RateLimiter::attempts($key);

        return $attempts < $rateLimit;
    }

    /**
     * Deny access with appropriate response.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  array  $identity
     * @param  string  $reason
     * @param  array  $context
     * @return \Symfony\Component\HttpFoundation\Response
     */
    protected function denyAccess(Request $request, array $identity, string $reason, array $context = []): Response
    {
        SecurityAuditLog::logSecurityEvent(
            $identity['type'] === 'user' ? auth()->user() : null,
            'mcp_access_denied',
            "MCP access denied: {$reason}",
            array_merge($context, [
                'identity_type' => $identity['type'],
                'identity_id' => $identity['id'],
                'ip' => $request->ip(),
                'url' => $request->fullUrl(),
            ])
        );

        return response()->json([
            'error' => 'Access Denied',
            'message' => "You do not have permission to access this resource. Reason: {$reason}",
            'context' => $context,
        ], 403);
    }

    /**
     * Log successful access.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Symfony\Component\HttpFoundation\Response  $response
     * @param  array  $identity
     * @param  array  $role
     * @param  float  $duration
     * @return void
     */
    protected function logAccess(Request $request, Response $response, array $identity, array $role, float $duration): void
    {
        if (!config('mcp.audit_logging.enabled', true)) {
            return;
        }

        SecurityAuditLog::log(
            'mcp.rbac_access',
            'MCP request processed with RBAC',
            [
                'identity_type' => $identity['type'],
                'identity_id' => $identity['id'],
                'role' => $role['name'],
                'access_level' => $request->attributes->get('mcp_access_level'),
                'tool' => $this->extractToolName($request),
                'ip' => $request->ip(),
                'status_code' => $response->getStatusCode(),
                'duration_ms' => round($duration * 1000, 2),
            ]
        );
    }

    /**
     * Extract API key from request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array|null
     */
    protected function extractApiKey(Request $request): ?array
    {
        // Check X-API-Key header
        if ($request->hasHeader('X-API-Key')) {
            $key = $request->header('X-API-Key');
            return $this->validateApiKey($key);
        }

        // Check Authorization header
        if ($request->hasHeader('Authorization')) {
            $auth = $request->header('Authorization');
            if (str_starts_with($auth, 'Bearer ')) {
                $key = substr($auth, 7);
                return $this->validateApiKey($key);
            }
        }

        return null;
    }

    /**
     * Validate API key and return metadata.
     *
     * @param  string  $key
     * @return array|null
     */
    protected function validateApiKey(string $key): ?array
    {
        // Check against configured API keys
        $validKeys = config('mcp.api_keys', []);

        foreach ($validKeys as $service => $storedKey) {
            if (hash_equals($storedKey, $key)) {
                return [
                    'id' => $service,
                    'name' => $service,
                    'roles' => [$this->getRoleForApiKey($service)],
                ];
            }
        }

        return null;
    }

    /**
     * Get role for API key service.
     *
     * @param  string  $service
     * @return string
     */
    protected function getRoleForApiKey(string $service): string
    {
        // Map known services to roles
        $mapping = [
            'laravel_boost' => 'operator',
            'shadcn' => 'viewer',
            'ruv_swarm' => 'admin',
        ];

        return $mapping[$service] ?? 'viewer';
    }

    /**
     * Load RBAC configuration from YAML file.
     *
     * @return array
     */
    protected function loadRbacConfig(): array
    {
        $configPath = base_path('config/rbac.yaml');

        if (!file_exists($configPath)) {
            return $this->getDefaultConfig();
        }

        $yaml = file_get_contents($configPath);

        // Parse YAML (basic implementation)
        return $this->parseYaml($yaml);
    }

    /**
     * Parse YAML to array (simple implementation).
     *
     * @param  string  $yaml
     * @return array
     */
    protected function parseYaml(string $yaml): array
    {
        // For now, return the default config
        // In production, use symfony/yaml component
        return $this->getDefaultConfig();
    }

    /**
     * Get default RBAC configuration.
     *
     * @return array
     */
    protected function getDefaultConfig(): array
    {
        return [
            'roles' => [
                'admin' => ['level' => 100],
                'operator' => ['level' => 75],
                'viewer' => ['level' => 25],
                'auditor' => ['level' => 50],
            ],
            'mcp_role_mapping' => [
                'admin' => [
                    'access_level' => 'full',
                    'allowed_tools' => ['*'],
                    'rate_limit' => 1000,
                ],
                'operator' => [
                    'access_level' => 'operational',
                    'allowed_tools' => ['container.*', 'deployment.*'],
                    'rate_limit' => 500,
                ],
                'viewer' => [
                    'access_level' => 'read-only',
                    'allowed_tools' => ['*.get', '*.list'],
                    'rate_limit' => 100,
                ],
                'auditor' => [
                    'access_level' => 'audit',
                    'allowed_tools' => ['audit.*', 'log.*'],
                    'rate_limit' => 200,
                ],
            ],
            'api_key_permissions' => [
                'admin_key' => [
                    'roles' => ['admin'],
                    'permissions' => ['*'],
                    'rate_limit' => 1000,
                ],
            ],
        ];
    }
}
