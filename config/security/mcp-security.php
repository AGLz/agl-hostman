<?php

declare(strict_types=1);

/**
 * MCP Server Security Configuration
 *
 * Provides security configuration for Model Context Protocol (MCP) servers.
 * Implements authentication, rate limiting, and access controls.
 *
 * @package config
 */

return [
    /*
    |--------------------------------------------------------------------------
    | MCP API Keys
    |--------------------------------------------------------------------------
    |
    | Define API keys for MCP server authentication. These keys should be
    | stored in environment variables for security. Use Laravel's
    | php artisan key:generate to create secure keys.
    |
    */

    'api_keys' => [
        'laravel_boost' => env('MCP_LARAVEL_BOOST_KEY'),
        'shadcn' => env('MCP_SHADCN_KEY'),
        'ruv_swarm' => env('MCP_RUV_SWARM_KEY'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate Limiting
    |--------------------------------------------------------------------------
    |
    | Configure rate limiting for MCP endpoints to prevent abuse and
    | ensure fair usage across all clients.
    |
    */

    'rate_limiting' => [
        'enabled' => env('MCP_RATE_LIMITING_ENABLED', true),
        'max_attempts' => env('MCP_RATE_LIMIT_MAX_ATTEMPTS', 60),
        'decay_minutes' => env('MCP_RATE_LIMIT_DECAY_MINUTES', 1),
        'per_minute' => env('MCP_RATE_LIMIT_PER_MINUTE', 100),
    ],

    /*
    |--------------------------------------------------------------------------
    | IP Whitelist
    |--------------------------------------------------------------------------
    |
    | Define allowed IP addresses or CIDR blocks that can access MCP
    | servers. Leave empty to allow all IPs (not recommended for production).
    |
    */

    'ip_whitelist' => [
        'enabled' => env('MCP_IP_WHITELIST_ENABLED', false),
        'allowed_ips' => array_filter(explode(',', env('MCP_ALLOWED_IPS', ''))),
    ],

    /*
    |--------------------------------------------------------------------------
    | Request Validation
    |--------------------------------------------------------------------------
    |
    | Configure validation rules for incoming MCP requests to prevent
    | injection attacks and ensure data integrity.
    |
    */

    'validation' => [
        'max_request_size' => env('MCP_MAX_REQUEST_SIZE', 10240), // 10MB
        'allowed_content_types' => ['application/json'],
        'sanitize_input' => env('MCP_SANITIZE_INPUT', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Security Headers
    |--------------------------------------------------------------------------
    |
    | Additional security headers specific to MCP endpoints.
    |
    */

    'headers' => [
        'X-MCP-Version' => '1.0',
        'X-Content-Type-Options' => 'nosniff',
        'X-Frame-Options' => 'DENY',
    ],

    /*
    |--------------------------------------------------------------------------
    | Audit Logging
    |--------------------------------------------------------------------------
    |
    | Enable or disable audit logging for MCP server requests.
    | Logs all requests, responses, and security events.
    |
    */

    'audit_logging' => [
        'enabled' => env('MCP_AUDIT_LOGGING_ENABLED', true),
        'log_channel' => env('MCP_LOG_CHANNEL', 'mcp'),
        'log_requests' => env('MCP_LOG_REQUESTS', true),
        'log_responses' => env('MCP_LOG_RESPONSES', false),
        'exclude_fields' => ['password', 'token', 'secret', 'key'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Timeout Configuration
    |--------------------------------------------------------------------------
    |
    | Set timeout values for MCP server operations to prevent
    | resource exhaustion attacks.
    |
    */

    'timeouts' => [
        'request_timeout' => env('MCP_REQUEST_TIMEOUT', 30), // seconds
        'execution_timeout' => env('MCP_EXECUTION_TIMEOUT', 120), // seconds
    ],

    /*
    |--------------------------------------------------------------------------
    | Encryption
    |--------------------------------------------------------------------------
    |
    | Configure encryption settings for MCP server communications.
    |
    */

    'encryption' => [
        'enabled' => env('MCP_ENCRYPTION_ENABLED', true),
        'algorithm' => env('MCP_ENCRYPTION_ALGORITHM', 'AES-256-GCM'),
        'key' => env('MCP_ENCRYPTION_KEY'),
    ],

    /*
    |--------------------------------------------------------------------------
    | CORS Configuration
    |--------------------------------------------------------------------------
    |
    | Configure Cross-Origin Resource Sharing for MCP endpoints.
    |
    */

    'cors' => [
        'enabled' => env('MCP_CORS_ENABLED', false),
        'allowed_origins' => array_filter(explode(',', env('MCP_CORS_ORIGINS', ''))),
        'allowed_methods' => ['POST', 'GET', 'OPTIONS'],
        'allowed_headers' => ['Content-Type', 'X-API-Key', 'Authorization'],
        'max_age' => 86400,
    ],
];
