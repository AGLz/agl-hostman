<?php

/**
 * Staging Environment Configuration
 *
 * This file contains configuration specific to the staging environment.
 * Values here override the base .env configuration when APP_ENV=staging.
 */

return [
    /*
    |--------------------------------------------------------------------------
    | Staging Application Configuration
    |--------------------------------------------------------------------------
    */
    'app' => [
        'name' => env('STAGING_APP_NAME', 'AGL Hostman - Staging'),
        'url' => env('STAGING_APP_URL', 'https://staging-agl.aglz.io'),
        'debug' => env('STAGING_DEBUG', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Database Configuration
    |--------------------------------------------------------------------------
    */
    'database' => [
        'connection' => env('STAGING_DB_CONNECTION', 'pgsql'),
        'host' => env('STAGING_DB_HOST', '192.168.0.180'),
        'port' => env('STAGING_DB_PORT', '5432'),
        'database' => env('STAGING_DB_DATABASE', 'agl_hostman_staging'),
        'username' => env('STAGING_DB_USERNAME', 'agl_staging'),
        'password' => env('STAGING_DB_PASSWORD'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Cache Configuration
    |--------------------------------------------------------------------------
    */
    'cache' => [
        'default' => env('STAGING_CACHE_DRIVER', 'redis'),
        'prefix' => env('STAGING_CACHE_PREFIX', 'agl_staging_'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Redis Configuration
    |--------------------------------------------------------------------------
    */
    'redis' => [
        'host' => env('STAGING_REDIS_HOST', '192.168.0.180'),
        'port' => env('STAGING_REDIS_PORT', '6379'),
        'password' => env('STAGING_REDIS_PASSWORD'),
        'database' => env('STAGING_REDIS_DB', '1'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Deployment Configuration
    |--------------------------------------------------------------------------
    */
    'deployment' => [
        'dokploy_url' => env('STAGING_DOKPLOY_URL', 'http://192.168.0.180:3000'),
        'dokploy_token' => env('STAGING_DOKPLOY_TOKEN'),
        'domain' => env('STAGING_DOMAIN', 'staging-agl.aglz.io'),
        'harbor_project' => env('STAGING_HARBOR_PROJECT', 'agl-hostman-staging'),
        'harbor_registry' => env('STAGING_HARBOR_REGISTRY', 'harbor.aglz.io:5000'),
        'harbor_username' => env('STAGING_HARBOR_USERNAME'),
        'harbor_password' => env('STAGING_HARBOR_PASSWORD'),
        'webhook_url' => env('STAGING_WEBHOOK_URL'),
        'webhook_secret' => env('STAGING_WEBHOOK_SECRET'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Logging Configuration
    |--------------------------------------------------------------------------
    */
    'logging' => [
        'channel' => env('STAGING_LOG_CHANNEL', 'stack'),
        'level' => env('STAGING_LOG_LEVEL', 'debug'),
        'days' => env('STAGING_LOG_DAYS', '14'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Monitoring Configuration
    |--------------------------------------------------------------------------
    */
    'monitoring' => [
        'enabled' => env('STAGING_MONITORING_ENABLED', true),
        'health_check_interval' => env('STAGING_HEALTH_CHECK_INTERVAL', 60),
        'metrics_retention_days' => env('STAGING_METRICS_RETENTION_DAYS', 30),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Queue Configuration
    |--------------------------------------------------------------------------
    */
    'queue' => [
        'driver' => env('STAGING_QUEUE_DRIVER', 'redis'),
        'connection' => env('STAGING_QUEUE_CONNECTION', 'staging'),
        'tries' => env('STAGING_QUEUE_TRIES', 3),
        'timeout' => env('STAGING_QUEUE_TIMEOUT', 300),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Mail Configuration
    |--------------------------------------------------------------------------
    */
    'mail' => [
        'mailer' => env('STAGING_MAIL_MAILER', 'smtp'),
        'host' => env('STAGING_MAIL_HOST', 'mailhog'),
        'port' => env('STAGING_MAIL_PORT', '1025'),
        'encryption' => env('STAGING_MAIL_ENCRYPTION', null),
        'username' => env('STAGING_MAIL_USERNAME'),
        'password' => env('STAGING_MAIL_PASSWORD'),
        'from' => [
            'address' => env('STAGING_MAIL_FROM_ADDRESS', 'staging@agl.aglz.io'),
            'name' => env('STAGING_MAIL_FROM_NAME', 'AGL Staging'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Session Configuration
    |--------------------------------------------------------------------------
    */
    'session' => [
        'driver' => env('STAGING_SESSION_DRIVER', 'redis'),
        'lifetime' => env('STAGING_SESSION_LIFETIME', 120),
    ],

    /*
    |--------------------------------------------------------------------------
    | Staging Performance Configuration
    |--------------------------------------------------------------------------
    */
    'performance' => [
        'query_timeout' => env('STAGING_QUERY_TIMEOUT', 30),
        'max_connections' => env('STAGING_MAX_CONNECTIONS', 50),
        'memory_limit' => env('STAGING_MEMORY_LIMIT', '512M'),
        'cpu_cores' => env('STAGING_CPU_CORES', 2),
    ],
];
