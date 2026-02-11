<?php
/**
 * =============================================================================
 * Database High Availability Configuration for Laravel
 * AGL Hostman - MySQL Read/Write Splitting with ProxySQL
 * =============================================================================
 *
 * This configuration provides:
 *   - Automatic read/write splitting via ProxySQL
 *   - Connection pooling
 *   - Automatic failover
 *   - Health monitoring
 *
 * Connection Architecture:
 *   Application
 *       ↓
 *   ProxySQL (Port 6032 for writes, 6033 for reads)
 *       ↓ (Write queries)    (Read queries)
 *   MySQL Master        MySQL Slaves
 *
 * Configuration:
 *   DB_READ_WRITE_SPLITTING=true to enable ProxySQL routing
 *   Set DB_WRITE_HOST and DB_READ_HOST environment variables
 *
 * =============================================================================
 */

return [
    // =============================================================================
    // Default Connection (Write)
    // =============================================================================
    'default' => [
        'driver' => 'mysql',
        'url' => env('DATABASE_URL'),
        'host' => env('DB_WRITE_HOST', env('DB_HOST', '127.0.0.1')),
        'port' => env('DB_WRITE_PORT', env('DB_PORT', '6032')),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'engine' => null,
        'options' => extension_loaded('pdo_mysql') ? array_filter([
            PDO::MYSQL_ATTR_SSL_DISABLE => env('DB_SSL_DISABLED', true),
            PDO::MYSQL_ATTR_INIT_COMMAND => 'SET sql_mode="STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"',
        ]) : [],
    ],

    // =============================================================================
    // Read Connection (ProxySQL Read Port)
    // =============================================================================
    'read' => [
        'driver' => 'mysql',
        'host' => env('DB_READ_HOST', env('DB_HOST', '127.0.0.1')),
        'port' => env('DB_READ_PORT', '6033'),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'engine' => null,
        'sticky' => env('DB_STICKY', true),
    ],

    // =============================================================================
    // Write Connection (Explicit)
    // =============================================================================
    'write' => [
        'driver' => 'mysql',
        'host' => env('DB_WRITE_HOST', env('DB_HOST', '127.0.0.1')),
        'port' => env('DB_WRITE_PORT', '6032')),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'engine' => null,
    ],

    // =============================================================================
    // Direct Master Connection (Failover)
    // =============================================================================
    // Use this connection when ProxySQL is unavailable or for failover scenarios
    'mysql_master' => [
        'driver' => 'mysql',
        'host' => env('DB_MASTER_HOST', 'mysql-master'),
        'port' => env('DB_MASTER_PORT', '3306')),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'engine' => null,
    ],

    // =============================================================================
    // Direct Slave Connection (Read Failover)
    // =============================================================================
    'mysql_slave_1' => [
        'driver' => 'mysql',
        'host' => env('DB_SLAVE1_HOST', 'mysql-slave-1'),
        'port' => env('DB_SLAVE_PORT', '3306')),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'read_only' => true,
    ],

    'mysql_slave_2' => [
        'driver' => 'mysql',
        'host' => env('DB_SLAVE2_HOST', 'mysql-slave-2'),
        'port' => env('DB_SLAVE_PORT', '3306')),
        'database' => env('DB_DATABASE', 'agl_hostman'),
        'username' => env('DB_USERNAME', 'agl_user'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'prefix_indexes' => true,
        'strict' => true,
        'read_only' => true,
    ],

    // =============================================================================
    // Connection Pooling Configuration
    // =============================================================================
    // Laravel doesn't have built-in pooling, but we can configure
    // ProxySQL to handle connection pooling for us
    'pooling' => [
        'min_connections' => env('DB_POOL_MIN', 10),
        'max_connections' => env('DB_POOL_MAX', 100),
        'connection_timeout' => env('DB_POOL_TIMEOUT', 5),
        'idle_timeout' => env('DB_POOL_IDLE_TIMEOUT', 60),
    ],
];
