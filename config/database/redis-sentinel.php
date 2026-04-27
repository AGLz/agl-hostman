<?php
/**
 * Redis Sentinel Configuration for Laravel
 *
 * Laravel Redis configuration with Sentinel support for automatic failover.
 * This configuration provides high availability with automatic master discovery.
 *
 * @package AGL Hostman
 */

return [
    /*
    |--------------------------------------------------------------------------
    | Redis Sentinel Configuration
    |--------------------------------------------------------------------------
    |
    | Redis Sentinel provides high availability with automatic failover.
    | When using Sentinel, Laravel will automatically discover the current
    | master and handle failover transparently.
    |
    | Supported clients: 'predis' (recommended for Sentinel), 'phpredis'
    |
    */

    'client' => env('REDIS_CLIENT', 'predis'),

    'options' => [
        'prefix' => env('REDIS_PREFIX', 'agl_'),
        'exceptions' => true,

        // Sentinel cluster options
        'replication' => env('REDIS_REPLICATION', true),
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Default Redis Connection
    |--------------------------------------------------------------------------
    |
    | The default connection uses Sentinel for automatic master discovery.
    | All write operations go through this connection.
    |
    */

    'default' => [
        // Sentinel configuration
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
        'sentinel_master' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),

        // Connection settings for Sentinel
        'scheme' => 'tcp',
        'path' => null,
        'host' => env('REDIS_SENTINEL_HOST', env('REDIS_HOST', '127.0.0.1')),
        'port' => env('REDIS_SENTINEL_PORT', 26379),

        // Authentication
        'password' => env('REDIS_PASSWORD', null),

        // Database selection (0-15)
        'database' => env('REDIS_DB', 0),

        // Connection pooling
        'persistent' => env('REDIS_PERSISTENT', false),
        'timeout' => env('REDIS_TIMEOUT', 5.0),

        // Retry settings
        'retry_interval' => env('REDIS_RETRY_INTERVAL', 100), // milliseconds
        'read_timeout' => env('REDIS_READ_TIMEOUT', 2.0),
        'read_write_timeout' => env('REDIS_READ_WRITE_TIMEOUT', 5.0),
    ],

    /*
    |--------------------------------------------------------------------------
    | Cache Connection
    |--------------------------------------------------------------------------
    |
    | Dedicated connection for Laravel cache. Uses Sentinel for HA.
    |
    */

    'cache' => [
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
        'sentinel_master' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),
        'scheme' => 'tcp',
        'host' => env('REDIS_SENTINEL_HOST', env('REDIS_HOST', '127.0.0.1')),
        'port' => env('REDIS_SENTINEL_PORT', 26379),
        'password' => env('REDIS_PASSWORD', null),
        'database' => env('REDIS_CACHE_DB', 1),
        'persistent' => env('REDIS_PERSISTENT', true),
        'timeout' => 5.0,
        'read_timeout' => 2.0,
    ],

    /*
    |--------------------------------------------------------------------------
    | Session Connection
    |--------------------------------------------------------------------------
    |
    | Dedicated connection for Laravel session storage.
    |
    */

    'session' => [
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
        'sentinel_master' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),
        'scheme' => 'tcp',
        'host' => env('REDIS_SENTINEL_HOST', env('REDIS_HOST', '127.0.0.1')),
        'port' => env('REDIS_SENTINEL_PORT', 26379),
        'password' => env('REDIS_PASSWORD', null),
        'database' => env('REDIS_SESSION_DB', 2),
        'persistent' => true,
        'timeout' => 5.0,
    ],

    /*
    |--------------------------------------------------------------------------
    | Queue Connection
    |--------------------------------------------------------------------------
    |
    | Dedicated connection for Laravel queue (Horizon).
    |
    */

    'horizon' => [
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
        'sentinel_master' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),
        'scheme' => 'tcp',
        'host' => env('REDIS_SENTINEL_HOST', env('REDIS_HOST', '127.0.0.1')),
        'port' => env('REDIS_SENTINEL_PORT', 26379),
        'password' => env('REDIS_PASSWORD', null),
        'database' => env('REDIS_QUEUE_DB', 3),
        'persistent' => true,
        'timeout' => 5.0,
        'read_write_timeout' => 10.0, // Queue needs longer timeout
    ],

    /*
    |--------------------------------------------------------------------------
    | Read-Only Slaves (for read scaling)
    |--------------------------------------------------------------------------
    |
    | Optional configuration for direct read operations on slaves.
    | Sentinel will return the closest healthy slave for reads.
    |
    | Usage: Redis::connection('slave')->get(...)
    |
    */

    'slave' => [
        'sentinel' => env('REDIS_SENTINEL_ENABLED', false),
        'sentinel_master' => env('REDIS_SENTINEL_MASTER', 'aglmaster'),
        'replica' => true, // Use replica instead of master
        'scheme' => 'tcp',
        'host' => env('REDIS_SENTINEL_HOST', env('REDIS_HOST', '127.0.0.1')),
        'port' => env('REDIS_SENTINEL_PORT', 26379),
        'password' => env('REDIS_PASSWORD', null),
        'database' => env('REDIS_DB', 0),
        'timeout' => 5.0,
        'read_timeout' => 3.0,
    ],

    /*
    |--------------------------------------------------------------------------
    | Fallback Connection (without Sentinel)
    |--------------------------------------------------------------------------
    |
    | Direct connection to Redis node when Sentinel is not available.
    | Used for development or single-node deployments.
    |
    */

    'direct' => [
        'scheme' => 'tcp',
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'port' => env('REDIS_PORT', 6379),
        'password' => env('REDIS_PASSWORD', null),
        'database' => env('REDIS_DB', 0),
        'persistent' => env('REDIS_PERSISTENT', false),
        'timeout' => 5.0,
    ],
];
