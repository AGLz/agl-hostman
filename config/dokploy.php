<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Dokploy Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Dokploy deployment platform integration
    | See: https://docs.dokploy.com/
    |
    */

    'base_url' => env('DOKPLOY_BASE_URL', 'https://dok.aglz.io'),

    'api_key' => env('DOKPLOY_API_KEY'),

    'timeout' => env('DOKPLOY_TIMEOUT', 30),

    'retry_times' => env('DOKPLOY_RETRY_TIMES', 3),

    'retry_delay' => env('DOKPLOY_RETRY_DELAY', 1000),

    'cache' => [
        'enabled' => env('DOKPLOY_CACHE_ENABLED', true),
        'ttl' => env('DOKPLOY_CACHE_TTL', 300), // 5 minutes
    ],

    'webhook' => [
        'secret' => env('DOKPLOY_WEBHOOK_SECRET'),
        'verify_signature' => env('DOKPLOY_WEBHOOK_VERIFY', true),
    ],

    'circuit_breaker' => [
        'threshold' => env('DOKPLOY_CIRCUIT_THRESHOLD', 5),
        'timeout' => env('DOKPLOY_CIRCUIT_TIMEOUT', 60),
    ],

    'defaults' => [
        'auto_deploy' => env('DOKPLOY_DEFAULT_AUTO_DEPLOY', false),
        'replicas' => env('DOKPLOY_DEFAULT_REPLICAS', 1),
        'cpu_limit' => env('DOKPLOY_DEFAULT_CPU_LIMIT', 1000), // millicores
        'memory_limit' => env('DOKPLOY_DEFAULT_MEMORY_LIMIT', 512), // MB
    ],

    'deployment' => [
        'strategy' => env('DOKPLOY_DEPLOYMENT_STRATEGY', 'rolling'),
        'health_check_enabled' => env('DOKPLOY_HEALTH_CHECK_ENABLED', true),
        'health_check_path' => env('DOKPLOY_HEALTH_CHECK_PATH', '/health'),
        'health_check_interval' => env('DOKPLOY_HEALTH_CHECK_INTERVAL', 30),
    ],

    'ssl' => [
        'auto_generate' => env('DOKPLOY_SSL_AUTO_GENERATE', true),
        'provider' => env('DOKPLOY_SSL_PROVIDER', 'letsencrypt'),
    ],
];
