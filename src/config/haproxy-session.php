<?php

/**
 * AGL Hostman - HAProxy Session Configuration
 *
 * Configuration for session management with HAProxy load balancing
 */

return [
    /*
    |--------------------------------------------------------------------------
    | Session Driver
    |--------------------------------------------------------------------------
    |
    | Use Redis for distributed session storage across multiple app nodes
    | This enables seamless failover between application servers
    |
    */
    'driver' => env('SESSION_DRIVER', 'redis'),

    /*
    |--------------------------------------------------------------------------
    | Session Lifetime
    |--------------------------------------------------------------------------
    |
    | Session lifetime in minutes
    |
    */
    'lifetime' => env('SESSION_LIFETIME', 120),

    /*
    |--------------------------------------------------------------------------
    | Session Expiration On Close
    |--------------------------------------------------------------------------
    |
    | Expire session on browser close
    |
    */
    'expire_on_close' => false,

    /*
    |--------------------------------------------------------------------------
    | Session Encryption
    |--------------------------------------------------------------------------
    |
    | Encrypt session data
    |
    */
    'encrypt' => false,

    /*
    |--------------------------------------------------------------------------
    | Session File Path
    |--------------------------------------------------------------------------
    |
    | Not used with Redis driver
    |
    */
    'files' => storage_path('framework/sessions'),

    /*
    |--------------------------------------------------------------------------
    | Session Database Connection
    |--------------------------------------------------------------------------
    |
    | Database connection for sessions (not used)
    |
    */
    'connection' => env('SESSION_CONNECTION', null),

    /*
    |--------------------------------------------------------------------------
    | Session Table
    |--------------------------------------------------------------------------
    |
    | Database table for sessions (not used)
    |
    */
    'table' => 'sessions',

    /*
    |--------------------------------------------------------------------------
    | Session Cache Store
    |--------------------------------------------------------------------------
    |
    | Cache store for sessions (Redis)
    |
    */
    'store' => env('SESSION_STORE', 'redis'),

    /*
    |--------------------------------------------------------------------------
    | Session Lottery
    |--------------------------------------------------------------------------
    |
    | Garbage collection lottery (2/100)
    |
    */
    'lottery' => [2, 100],

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Name
    |--------------------------------------------------------------------------
    |
    | Cookie name for sessions
    | HAProxy uses this for sticky sessions if needed
    |
    */
    'cookie' => env('SESSION_COOKIE_NAME', 'agl_hostman_session'),

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Path
    |--------------------------------------------------------------------------
    |
    | Cookie path
    |
    */
    'path' => '/',

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Domain
    |--------------------------------------------------------------------------
    |
    | Cookie domain (null = current domain)
    |
    */
    'domain' => env('SESSION_COOKIE_DOMAIN', null),

    /*
    |--------------------------------------------------------------------------
    | Session Secure
    |--------------------------------------------------------------------------
    |
    | Only send cookie over HTTPS
    |
    */
    'secure' => env('SESSION_SECURE_COOKIE', true),

    /*
    |--------------------------------------------------------------------------
    | Session HTTP Only
    |--------------------------------------------------------------------------
    |
    | HTTP only cookie (not accessible via JavaScript)
    |
    */
    'http_only' => true,

    /*
    |--------------------------------------------------------------------------
    | Same-Site Cookies
    |--------------------------------------------------------------------------
    |
    | Same-site cookie policy (lax, strict, none)
    | Use 'lax' for better compatibility with load balancers
    |
    */
    'same_site' => 'lax',

    /*
    |--------------------------------------------------------------------------
    | HAProxy Session Stickiness
    |--------------------------------------------------------------------------
    |
    | Configuration for HAProxy cookie-based stickiness
    | This provides fallback session persistence
    |
    */
    'haproxy' => [
        // Enable HAProxy stickiness
        'enabled' => env('HAPROXY_STICKY_ENABLED', true),

        // Cookie name used by HAProxy
        'cookie_name' => env('HAPROXY_COOKIE_NAME', 'SRVNAME'),

        // Cookie prefix for application
        'cookie_prefix' => 'agl_',

        // Session affinity TTL (in seconds)
        // After this time, sessions can be rebalanced
        'affinity_ttl' => env('SESSION_AFFINITY_TTL', 3600),

        // Enable session persistence across nodes
        'persistence_enabled' => env('SESSION_PERSISTENCE_ENABLED', true),

        // Session data backup nodes (Redis replication)
        'backup_nodes' => [
            'redis-master' => env('REDIS_HOST', '127.0.0.1'),
            'redis-slave-1' => env('REDIS_SLAVE_1', '127.0.0.1'),
            'redis-slave-2' => env('REDIS_SLAVE_2', '127.0.0.1'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Failover Configuration
    |--------------------------------------------------------------------------
    |
    | Session behavior during failover scenarios
    |
    */
    'failover' => [
        // Grace period for session migration (in seconds)
        'grace_period' => env('SESSION_FAILOVER_GRACE', 30),

        // Retry connection to session store
        'retry_attempts' => env('SESSION_RETRY_ATTEMPTS', 3),

        // Retry delay (in milliseconds)
        'retry_delay' => env('SESSION_RETRY_DELAY', 100),

        // Use fallback cache if Redis unavailable
        'fallback_cache' => env('SESSION_FALLBACK_CACHE', 'file'),

        // Log session failures
        'log_failures' => env('SESSION_LOG_FAILURES', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Distributed Session Locking
    |--------------------------------------------------------------------------
    |
    | Enable distributed session locking for concurrent requests
    | Prevents race conditions in distributed environment
    |
    */
    'locking' => [
        'enabled' => env('SESSION_LOCKING_ENABLED', true),

        // Lock timeout (in seconds)
        'timeout' => env('SESSION_LOCK_TIMEOUT', 10),

        // Lock retry interval (in milliseconds)
        'retry_interval' => env('SESSION_LOCK_RETRY', 100),

        // Maximum lock retry attempts
        'max_retries' => env('SESSION_LOCK_MAX_RETRIES', 10),
    ],

    /*
    |--------------------------------------------------------------------------
    | Session Replication
    |--------------------------------------------------------------------------
    |
    | Configure session replication to backup nodes
    |
    */
    'replication' => [
        // Enable async replication to backup Redis instances
        'enabled' => env('SESSION_REPLICATION_ENABLED', true),

        // Replication mode: async, sync
        'mode' => env('SESSION_REPLICATION_MODE', 'async'),

        // Number of replicas required for write confirmation
        'quorum' => env('SESSION_REPLICATION_QUORUM', 1),

        // Replication timeout (in milliseconds)
        'timeout' => env('SESSION_REPLICATION_TIMEOUT', 100),
    ],
];
