<?php

/**
 * PostgreSQL Connection Pool Configuration
 *
 * Optimized connection pooling for AGL-23 to achieve < 50ms p95 target.
 *
 * Connection Pooling Strategies:
 * - PgBouncer: External pooling (recommended for production)
 * - Laravel Internal Pool: Framework-level connection management
 * - Persistent Connections: Keep connections open
 *
 * @see https://www.postgresql.org/docs/current/pgbouncer.html
 */

return [
    /*
    |--------------------------------------------------------------------------
    | Connection Pool Type
    |--------------------------------------------------------------------------
    |
    | Options:
    | - 'internal': Use Laravel's built-in connection management
    | - 'pgbouncer': Use PgBouncer external pooler
    | - 'swoole': Use Swoole coroutine connections
    |
    */
    'pool_type' => env('DB_POOL_TYPE', 'internal'),

    /*
    |--------------------------------------------------------------------------
    | Pool Configuration
    |--------------------------------------------------------------------------
    |
    | These settings apply to all pool types
    |
    */
    'pool' => [
        // Minimum connections to keep open
        'min_connections' => (int) env('DB_POOL_MIN', 5),

        // Maximum connections (must be <= PostgreSQL max_connections)
        'max_connections' => (int) env('DB_POOL_MAX', 100),

        // Connection idle timeout (seconds)
        'idle_timeout' => (int) env('DB_POOL_IDLE_TIMEOUT', 600),

        // Connection lifetime (seconds) - recycle after this time
        'max_lifetime' => (int) env('DB_POOL_MAX_LIFETIME', 3600),

        // Connection backoff strategy
        'backoff' => [
            'initial_delay_ms' => 100,
            'max_delay_ms' => 5000,
            'multiplier' => 1.5,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | PgBouncer Configuration (pool_type: 'pgbouncer')
    |--------------------------------------------------------------------------
    |
    | PgBouncer is a PostgreSQL connection pooler that provides:
    | - Connection pooling (reuse connections)
    | - Transaction pooling (use for Laravel)
    | - Session pooling (not recommended for Laravel)
    |
    */
    'pgbouncer' => [
        // Connection mode: 'transaction' (recommended for Laravel)
        'pool_mode' => env('PGBOUNCER_POOL_MODE', 'transaction'),

        // PgBouncer connection details
        'host' => env('PGBOUNCER_HOST', '127.0.0.1'),
        'port' => (int) env('PGBOUNCER_PORT', 6432),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD', ''),

        // Pool size configuration
        'pool_size' => (int) env('PGBOUNCER_POOL_SIZE', 50),
        'max_client_conn' => (int) env('PGBOUNCER_MAX_CLIENT', 200),
        'max_db_conn' => (int) env('PGBOUNCER_MAX_DB', 100),

        // Timeout settings
        'query_timeout' => (int) env('PGBOUNCER_QUERY_TIMEOUT', 30),
        'client_idle_timeout' => (int) env('PGBOUNCER_CLIENT_IDLE', 600),
        'server_idle_timeout' => (int) env('PGBOUNCER_SERVER_IDLE', 600),

        // Additional PgBouncer parameters
        'server_lifetime' => (int) env('PGBOUNCER_SERVER_LIFETIME', 3600),
        'server_connect_timeout' => (int) env('PGBOUNCER_CONNECT_TIMEOUT', 15),
        'server_login_retry' => (int) env('PGBOUNCER_LOGIN_RETRY', 15),

        // Auto-detect slow queries
        'autodetect_slow_queries' => env('PGBOUNCER_AUTODETECT_SLOW', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Internal Pool Configuration (pool_type: 'internal')
    |--------------------------------------------------------------------------
    |
    | Laravel's built-in connection management
    |
    */
    'internal' => [
        // Maximum connections per worker
        'max_connections_per_worker' => (int) env('DB_MAX_PER_WORKER', 10),

        // Persistent connections (PDO::ATTR_PERSISTENT)
        'persistent' => env('DB_PERSISTENT', false),

        // Persistent connection ID prefix
        'persistent_id' => env('DB_PERSISTENT_ID', 'agl_hostman_'),

        // Connection retry settings
        'retry' => [
            'enabled' => env('DB_RETRY_ENABLED', true),
            'max_attempts' => (int) env('DB_RETRY_MAX', 3),
            'delay_ms' => (int) env('DB_RETRY_DELAY', 100),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Read/Write Split Configuration (Optional)
    |--------------------------------------------------------------------------
    |
    | For read-heavy workloads, split reads to replica
    |
    */
    'read_write_split' => [
        'enabled' => env('DB_RW_SPLIT_ENABLED', false),

        // Read replica configuration
        'read' => [
            'host' => env('DB_READ_HOST', env('DB_HOST', '127.0.0.1')),
            'port' => (int) env('DB_READ_PORT', env('DB_PORT', 5432)),
            'database' => env('DB_DATABASE', 'agl_hostman'),
            'username' => env('DB_USERNAME', 'agl_user'),
            'password' => env('DB_PASSWORD', ''),
            'pool_size' => (int) env('DB_READ_POOL_SIZE', 50),
        ],

        // Write primary configuration
        'write' => [
            'host' => env('DB_WRITE_HOST', env('DB_HOST', '127.0.0.1')),
            'port' => (int) env('DB_WRITE_PORT', env('DB_PORT', 5432)),
            'database' => env('DB_DATABASE', 'agl_hostman'),
            'username' => env('DB_USERNAME', 'agl_user'),
            'password' => env('DB_PASSWORD', ''),
            'pool_size' => (int) env('DB_WRITE_POOL_SIZE', 20),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Health Check Configuration
    |--------------------------------------------------------------------------
    |
    | Connection pool health monitoring
    |
    */
    'health_check' => [
        'enabled' => env('DB_POOL_HEALTH_CHECK', true),

        // Check interval (seconds)
        'interval' => (int) env('DB_POOL_HEALTH_INTERVAL', 30),

        // Timeout for health check queries
        'timeout' => (int) env('DB_POOL_HEALTH_TIMEOUT', 5),

        // Failed check threshold before marking unhealthy
        'unhealthy_threshold' => (int) env('DB_POOL_UNHEALTHY_THRESHOLD', 3),

        // Health check query
        'query' => env('DB_POOL_HEALTH_QUERY', 'SELECT 1'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Monitoring & Metrics
    |--------------------------------------------------------------------------
    |
    | Track pool performance metrics
    |
    */
    'monitoring' => [
        'enabled' => env('DB_POOL_MONITORING', true),

        // Export Prometheus metrics
        'metrics_enabled' => env('DB_POOL_METRICS', true),

        // Metrics endpoint
        'metrics_path' => env('DB_POOL_METRICS_PATH', '/metrics/database_pool'),

        // Log slow connection acquisitions
        'log_slow_acquisition' => env('DB_POOL_LOG_SLOW', true),

        // Slow acquisition threshold (ms)
        'slow_acquisition_threshold' => (int) env('DB_POOL_SLOW_THRESHOLD', 100),
    ],

    /*
    |--------------------------------------------------------------------------
    | Statement Timeout Configuration
    |--------------------------------------------------------------------------
    |
    | Configure PostgreSQL statement timeouts
    |
    */
    'timeouts' => [
        // Statement timeout (milliseconds) - default 30s
        'statement_timeout' => (int) env('DB_STATEMENT_TIMEOUT_MS', 30000),

        // Lock timeout (milliseconds) - default 30s
        'lock_timeout' => (int) env('DB_LOCK_TIMEOUT_MS', 30000),

        // Idle in transaction timeout (milliseconds) - default 60s
        'idle_in_transaction_timeout' => (int) env('DB_IDLE_TRANSACTION_TIMEOUT_MS', 60000),
    ],

    /*
    |--------------------------------------------------------------------------
    | Prepared Statement Caching
    |--------------------------------------------------------------------------
    |
    | Enable prepared statement caching for better performance
    |
    */
    'prepared_statements' => [
        'enabled' => env('DB_PREPARED_STATEMENTS', true),

        // Max cached statements per connection
        'max_cache_size' => (int) env('DB_MAX_PREPARED', 100),
    ],

    /*
    |--------------------------------------------------------------------------
    | Environment-specific overrides
    |--------------------------------------------------------------------------
    |
    | Tune pool settings per environment
    |
    */
    'environments' => [
        'local' => [
            'max_connections' => 10,
            'min_connections' => 2,
        ],
        'testing' => [
            'max_connections' => 20,
            'min_connections' => 5,
        ],
        'production' => [
            'max_connections' => 200,
            'min_connections' => 20,
            'idle_timeout' => 300,
        ],
    ],
];
