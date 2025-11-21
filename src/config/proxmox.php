<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Proxmox VE API Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Proxmox VE API client including host connection
    | details, authentication credentials, and behavior settings.
    |
    */

    'host' => env('PROXMOX_HOST', '192.168.0.245'),
    'port' => env('PROXMOX_PORT', 8006),
    'username' => env('PROXMOX_USERNAME', 'root@pam'),
    'password' => env('PROXMOX_PASSWORD', ''),
    'realm' => env('PROXMOX_REALM', 'pam'),

    /*
    |--------------------------------------------------------------------------
    | SSL/TLS Configuration
    |--------------------------------------------------------------------------
    |
    | Control SSL certificate verification. Disable for self-signed certs
    | in development environments. Always enable for production.
    |
    */

    'verify_ssl' => env('PROXMOX_VERIFY_SSL', false),

    /*
    |--------------------------------------------------------------------------
    | Logging Configuration
    |--------------------------------------------------------------------------
    |
    | Specify which log channel to use for Proxmox API operations.
    | Set to 'null' to disable logging.
    |
    */

    'log_channel' => env('PROXMOX_LOG_CHANNEL', 'default'),

    /*
    |--------------------------------------------------------------------------
    | Default Node
    |--------------------------------------------------------------------------
    |
    | The default Proxmox node to use when no node is specified.
    | This should be the primary node in your cluster.
    |
    */

    'default_node' => env('PROXMOX_DEFAULT_NODE', 'AGLSRV1'),

    /*
    |--------------------------------------------------------------------------
    | Cluster Configuration
    |--------------------------------------------------------------------------
    |
    | List of all nodes in your Proxmox cluster for multi-node operations.
    |
    */

    'cluster_nodes' => [
        'AGLSRV1' => [
            'host' => env('PROXMOX_NODE1_HOST', '192.168.0.245'),
            'wireguard_ip' => env('PROXMOX_NODE1_WG', '10.6.0.11'),
            'tailscale_ip' => env('PROXMOX_NODE1_TS', '100.107.113.33'),
        ],
        'AGLSRV6' => [
            'host' => env('PROXMOX_NODE2_HOST', ''),
            'wireguard_ip' => env('PROXMOX_NODE2_WG', '10.6.0.12'),
            'tailscale_ip' => env('PROXMOX_NODE2_TS', ''),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Cache Configuration
    |--------------------------------------------------------------------------
    |
    | Control caching behavior for Proxmox API responses.
    |
    */

    'cache' => [
        'enabled' => env('PROXMOX_CACHE_ENABLED', true),
        'ttl' => env('PROXMOX_CACHE_TTL', 300), // 5 minutes
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate Limiting
    |--------------------------------------------------------------------------
    |
    | Configure rate limiting for Proxmox API requests to prevent
    | overwhelming the API server.
    |
    */

    'rate_limit' => [
        'enabled' => env('PROXMOX_RATE_LIMIT_ENABLED', true),
        'max_requests' => env('PROXMOX_RATE_LIMIT_MAX', 100),
        'per_minutes' => env('PROXMOX_RATE_LIMIT_MINUTES', 1),
    ],

    /*
    |--------------------------------------------------------------------------
    | Circuit Breaker
    |--------------------------------------------------------------------------
    |
    | Circuit breaker configuration to handle API failures gracefully.
    |
    */

    'circuit_breaker' => [
        'enabled' => env('PROXMOX_CIRCUIT_BREAKER_ENABLED', true),
        'failure_threshold' => env('PROXMOX_CIRCUIT_BREAKER_THRESHOLD', 5),
        'timeout_seconds' => env('PROXMOX_CIRCUIT_BREAKER_TIMEOUT', 300),
    ],
];
