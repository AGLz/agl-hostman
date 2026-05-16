<?php

declare(strict_types=1);

return [
    /*
    |--------------------------------------------------------------------------
    | MCP API Keys Configuration
    |--------------------------------------------------------------------------
    |
    | API keys for MCP (Model Context Protocol) server authentication.
    | Generate secure keys using: php artisan tinker --execute="Str::random(64)"
    |
    */

    /*
    | Query-string API keys leak via logs and Referer — disabled by default outside local.
    */
    'allow_query_api_key' => env('MCP_ALLOW_QUERY_API_KEY', env('APP_ENV') === 'local'),

    'api_keys' => [
        // Laravel Boost MCP Server
        'laravel_boost' => env('MCP_LARAVEL_BOOST_KEY'),
        // Shadcn UI Components MCP Server
        'shadcn' => env('MCP_SHADCN_KEY'),
        // Ruv Swarm Coordination MCP Server
        'ruv_swarm' => env('MCP_RUV_SWARM_KEY'),
        // Test-only MCP Server key
        'test' => env('APP_ENV') === 'testing' ? 'test-key' : env('MCP_TEST_KEY'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate Limiting Configuration
    |--------------------------------------------------------------------------
    |
    | Configure rate limiting for MCP server endpoints to prevent abuse.
    |
    */

    'rate_limiting' => [
        'enabled' => env('MCP_RATE_LIMITING_ENABLED', true),
        'max_attempts' => env('MCP_RATE_LIMIT_MAX_ATTEMPTS', 60),
        'decay_minutes' => env('MCP_RATE_LIMIT_DECAY_MINUTES', 1),
    ],

    /*
    |--------------------------------------------------------------------------
    | IP Whitelist Configuration
    |--------------------------------------------------------------------------
    |
    | Configure IP whitelist for MCP server access. Set enabled to true
    | to restrict access to specific IP addresses or CIDR ranges.
    |
    */

    'ip_whitelist' => [
        'enabled' => env('MCP_IP_WHITELIST_ENABLED', false),
        'allowed_ips' => array_filter(explode(',', env('MCP_ALLOWED_IPS', ''))),
    ],

    /*
    |--------------------------------------------------------------------------
    | Request Validation Configuration
    |--------------------------------------------------------------------------
    |
    | Configure request size and content type validation.
    |
    */

    'validation' => [
        'max_request_size' => env('MCP_MAX_REQUEST_SIZE', 10240), // 10MB in KB
        'allowed_content_types' => ['application/json'],
        'require_content_type' => env('MCP_REQUIRE_CONTENT_TYPE', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Audit Logging Configuration
    |--------------------------------------------------------------------------
    |
    | Configure audit logging for MCP requests.
    |
    */

    'audit_logging' => [
        'enabled' => env('MCP_AUDIT_LOGGING_ENABLED', true),
        'log_all_requests' => env('MCP_LOG_ALL_REQUESTS', false),
        'log_failed_only' => env('MCP_LOG_FAILED_ONLY', true),
        'retention_days' => env('MCP_AUDIT_RETENTION_DAYS', 90),
    ],

    /*
    |--------------------------------------------------------------------------
    | Security Headers Configuration
    |--------------------------------------------------------------------------
    |
    | Security headers added to MCP responses.
    |
    */

    'headers' => [
        'X-Content-Type-Options' => 'nosniff',
        'X-Frame-Options' => 'DENY',
        'X-XSS-Protection' => '1; mode=block',
        'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
        'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'self'; object-src 'none'; base-uri 'self'; form-action 'self';",
        'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',
        'Referrer-Policy' => 'strict-origin-when-cross-origin',
    ],

    /*
    |--------------------------------------------------------------------------
    | Role-to-Service Mapping
    |--------------------------------------------------------------------------
    |
    | Map MCP service names to RBAC roles for authorization.
    |
    */

    'role_mapping' => [
        'laravel_boost' => 'operator',
        'shadcn' => 'viewer',
        'ruv_swarm' => 'admin',
    ],

    /*
    |--------------------------------------------------------------------------
    | RBAC Rate Limits by Role
    |--------------------------------------------------------------------------
    |
    | Custom rate limits per role for MCP access.
    |
    */

    'role_rate_limits' => [
        'admin' => 1000,
        'operator' => 500,
        'auditor' => 200,
        'viewer' => 100,
    ],
];
