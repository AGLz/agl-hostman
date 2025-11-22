<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Dokploy Base URL
    |--------------------------------------------------------------------------
    |
    | The base URL for your Dokploy instance (CT180)
    | LAN IP: 192.168.0.180
    | Public URL: https://dok.aglz.io
    |
    */
    'base_url' => env('DOKPLOY_BASE_URL', 'https://dok.aglz.io'),

    /*
    |--------------------------------------------------------------------------
    | Dokploy API Key
    |--------------------------------------------------------------------------
    |
    | JWT API token generated at /settings/profile
    | This key is used for all Dokploy API requests via x-api-key header
    |
    */
    'api_key' => env('DOKPLOY_API_KEY', 'dummy-build-token'),

    /*
    |--------------------------------------------------------------------------
    | Harbor Registry Configuration
    |--------------------------------------------------------------------------
    |
    | Harbor container registry integration
    | URL: harbor.aglz.io:5000
    | Admin credentials for push/pull operations
    |
    */
    'harbor' => [
        'url' => env('HARBOR_URL', 'harbor.aglz.io:5000'),
        'username' => env('HARBOR_USERNAME', 'admin'),
        'password' => env('HARBOR_PASSWORD'),
        'project' => env('HARBOR_PROJECT', 'agl'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Harbor Webhook Secret
    |--------------------------------------------------------------------------
    |
    | Optional HMAC secret for verifying Harbor webhook authenticity
    | Set in Harbor project settings: Webhooks > Add Webhook > Secret
    |
    */
    'harbor_webhook_secret' => env('HARBOR_WEBHOOK_SECRET'),

    /*
    |--------------------------------------------------------------------------
    | Default Server ID
    |--------------------------------------------------------------------------
    |
    | Default Dokploy server ID for deployments
    | Get from Dokploy UI: Settings > Servers
    |
    */
    'default_server_id' => env('DOKPLOY_DEFAULT_SERVER_ID'),

    /*
    |--------------------------------------------------------------------------
    | Circuit Breaker Configuration
    |--------------------------------------------------------------------------
    |
    | DokployApiClient circuit breaker settings
    | Prevents cascading failures when Dokploy is down
    |
    */
    'circuit_breaker' => [
        'threshold' => env('DOKPLOY_CIRCUIT_BREAKER_THRESHOLD', 5),
        'timeout' => env('DOKPLOY_CIRCUIT_BREAKER_TIMEOUT', 60), // seconds
    ],

    /*
    |--------------------------------------------------------------------------
    | Retry Configuration
    |--------------------------------------------------------------------------
    |
    | Maximum retry attempts for failed API requests
    | Uses exponential backoff: 0.5s, 1s, 1.5s
    |
    */
    'max_retries' => env('DOKPLOY_MAX_RETRIES', 3),
    'timeout' => env('DOKPLOY_TIMEOUT', 30), // seconds

    /*
    |--------------------------------------------------------------------------
    | Auto-Deployment Configuration
    |--------------------------------------------------------------------------
    |
    | Automatic deployment triggers via Harbor webhooks
    | Enable/disable per environment
    |
    */
    'auto_deploy' => [
        'enabled' => env('DOKPLOY_AUTO_DEPLOY', true),
        'environments' => [
            'production' => env('DOKPLOY_AUTO_DEPLOY_PRODUCTION', false),
            'staging' => env('DOKPLOY_AUTO_DEPLOY_STAGING', true),
            'development' => env('DOKPLOY_AUTO_DEPLOY_DEVELOPMENT', true),
        ],
    ],
];
