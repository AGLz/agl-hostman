<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Harbor Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Harbor Container Registry integration
    | See: https://goharbor.io/docs/
    |
    */

    'base_url' => env('HARBOR_BASE_URL', 'https://harbor.aglz.io'),

    'username' => env('HARBOR_USERNAME'),

    'password' => env('HARBOR_PASSWORD'),

    'timeout' => env('HARBOR_TIMEOUT', 30),

    'retry_times' => env('HARBOR_RETRY_TIMES', 3),

    'retry_delay' => env('HARBOR_RETRY_DELAY', 1000),

    'cache' => [
        'enabled' => env('HARBOR_CACHE_ENABLED', true),
        'ttl' => env('HARBOR_CACHE_TTL', 300), // 5 minutes
    ],

    'webhook' => [
        'secret' => env('HARBOR_WEBHOOK_SECRET'),
        'verify_signature' => env('HARBOR_WEBHOOK_VERIFY', true),
    ],

    'circuit_breaker' => [
        'threshold' => env('HARBOR_CIRCUIT_THRESHOLD', 5),
        'timeout' => env('HARBOR_CIRCUIT_TIMEOUT', 60),
    ],

    'defaults' => [
        'project_public' => env('HARBOR_DEFAULT_PUBLIC', false),
        'auto_scan' => env('HARBOR_DEFAULT_AUTO_SCAN', true),
        'prevent_vul' => env('HARBOR_DEFAULT_PREVENT_VUL', false),
        'severity' => env('HARBOR_DEFAULT_SEVERITY', 'medium'),
    ],

    'retention' => [
        'enabled' => env('HARBOR_RETENTION_ENABLED', true),
        'keep_last_n' => env('HARBOR_RETENTION_KEEP_LAST_N', 10),
    ],
];
