<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Monitoring Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for the real-time infrastructure monitoring dashboard
    |
    */

    // Polling interval for Livewire components (seconds)
    'poll_interval' => (int) env('MONITORING_POLL_INTERVAL', 10),

    // Cache TTL for metrics (seconds)
    'cache_ttl' => (int) env('MONITORING_CACHE_TTL', 10),

    // API timeout for Proxmox requests (seconds)
    'api_timeout' => (int) env('MONITORING_API_TIMEOUT', 5),

    // Number of retry attempts for failed API calls
    'retry_attempts' => (int) env('MONITORING_RETRY_ATTEMPTS', 3),

    // Health status thresholds
    'thresholds' => [
        'server' => [
            'cpu' => [
                'warning' => 70,  // CPU > 70% = warning
                'critical' => 85, // CPU > 85% = critical
            ],
            'memory' => [
                'warning' => 80,  // RAM > 80% = warning
                'critical' => 90, // RAM > 90% = critical
            ],
        ],
        'container' => [
            'cpu' => [
                'warning' => 60,  // CPU > 60% = warning
                'critical' => 80, // CPU > 80% = critical
            ],
            'memory' => [
                'warning' => 75,  // RAM > 75% = warning
                'critical' => 90, // RAM > 90% = critical
            ],
        ],
        'storage' => [
            'warning' => 70,  // Usage > 70% = warning
            'critical' => 85, // Usage > 85% = critical
        ],
        'network' => [
            'connection_rate' => [
                'warning' => 95,  // < 95% connected = warning
                'critical' => 80, // < 80% connected = critical
            ],
            'latency' => [
                'warning' => 50,   // > 50ms = warning
                'critical' => 150, // > 150ms = critical
            ],
        ],
    ],

    // Enable/disable features
    'features' => [
        'websocket_updates' => env('MONITORING_WEBSOCKET_ENABLED', true),
        'export_metrics' => env('MONITORING_EXPORT_ENABLED', true),
        'auto_refresh' => env('MONITORING_AUTO_REFRESH', true),
    ],
];
