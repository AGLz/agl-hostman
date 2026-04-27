<?php

/**
 * Production Environment Configuration
 *
 * This file contains configuration specific to the production environment.
 * Values here override the base .env configuration when APP_ENV=production.
 */

return [
    /*
    |--------------------------------------------------------------------------
    | Production Application Configuration
    |--------------------------------------------------------------------------
    */
    'app' => [
        'name' => env('PRODUCTION_APP_NAME', 'AGL Hostman'),
        'url' => env('PRODUCTION_APP_URL', 'https://prod-agl.aglz.io'),
        'debug' => false, // Always false in production
        'force_https' => env('PRODUCTION_FORCE_HTTPS', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Database Configuration
    |--------------------------------------------------------------------------
    */
    'database' => [
        'connection' => env('PRODUCTION_DB_CONNECTION', 'pgsql'),
        'host' => env('PRODUCTION_DB_HOST', '192.168.0.182'),
        'port' => env('PRODUCTION_DB_PORT', '5432'),
        'database' => env('PRODUCTION_DB_DATABASE', 'agl_hostman_prod'),
        'username' => env('PRODUCTION_DB_USERNAME', 'agl_prod'),
        'password' => env('PRODUCTION_DB_PASSWORD'),
        'read_host' => env('PRODUCTION_DB_READ_HOST'), // Read replica
        'pool_size' => env('PRODUCTION_DB_POOL_SIZE', 20),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Cache Configuration
    |--------------------------------------------------------------------------
    */
    'cache' => [
        'default' => env('PRODUCTION_CACHE_DRIVER', 'redis'),
        'prefix' => env('PRODUCTION_CACHE_PREFIX', 'agl_prod_'),
        'ttl' => env('PRODUCTION_CACHE_TTL', 3600),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Redis Configuration
    |--------------------------------------------------------------------------
    */
    'redis' => [
        'host' => env('PRODUCTION_REDIS_HOST', '192.168.0.182'),
        'port' => env('PRODUCTION_REDIS_PORT', '6379'),
        'password' => env('PRODUCTION_REDIS_PASSWORD'),
        'database' => env('PRODUCTION_REDIS_DB', '0'),
        'cluster' => env('PRODUCTION_REDIS_CLUSTER', false),
        'sentinel' => env('PRODUCTION_REDIS_SENTINEL', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Deployment Configuration
    |--------------------------------------------------------------------------
    */
    'deployment' => [
        // Dokploy Configuration
        'dokploy_url' => env('PRODUCTION_DOKPLOY_URL', 'http://192.168.0.182:3000'),
        'dokploy_token' => env('PRODUCTION_DOKPLOY_TOKEN'),

        // Domain Configuration
        'domain' => env('PRODUCTION_DOMAIN', 'prod-agl.aglz.io'),
        'domains' => array_filter(explode(',', env('PRODUCTION_DOMAINS', 'prod-agl.aglz.io,agl-hostman.aglz.io'))),

        // Blue-Green Configuration
        'blue_green_enabled' => env('BLUE_GREEN_ENABLED', true),
        'active_slot' => env('ACTIVE_SLOT', 'blue'),
        'traffic_switch_gradual' => env('TRAFFIC_SWITCH_GRADUAL', true),
        'traffic_intervals' => [10, 50, 100],

        // Harbor Registry Configuration
        'harbor_project' => env('PRODUCTION_HARBOR_PROJECT', 'agl-hostman-prod'),
        'harbor_registry' => env('PRODUCTION_HARBOR_REGISTRY', 'harbor.aglz.io:5000'),
        'harbor_username' => env('PRODUCTION_HARBOR_USERNAME'),
        'harbor_password' => env('PRODUCTION_HARBOR_PASSWORD'),

        // Load Balancer Configuration
        'lb_api_url' => env('PRODUCTION_LB_API_URL'),
        'lb_token' => env('PRODUCTION_LB_TOKEN'),
        'lb_type' => env('PRODUCTION_LB_TYPE', 'nginx'),
        'lb_algorithm' => env('PRODUCTION_LB_ALGORITHM', 'least_conn'),
        'lb_health_check_path' => env('PRODUCTION_LB_HEALTH_CHECK_PATH', '/health'),
        'lb_health_check_interval' => env('PRODUCTION_LB_HEALTH_CHECK_INTERVAL', 30),

        // Webhook Configuration
        'webhook_url' => env('PRODUCTION_WEBHOOK_URL'),
        'webhook_secret' => env('PRODUCTION_WEBHOOK_SECRET'),

        // Approval Configuration
        'approval_required' => env('PRODUCTION_APPROVAL_REQUIRED', true),
        'approvers' => array_filter(explode(',', env('PRODUCTION_APPROVERS', 'lead-developer,admin'))),
        'min_approvals' => env('PRODUCTION_MIN_APPROVALS', 2),
        'approval_timeout' => env('PRODUCTION_APPROVAL_TIMEOUT', 86400), // 24 hours

        // Rollback Configuration
        'rollback_enabled' => env('ROLLBACK_ENABLED', true),
        'rollback_target_mttr' => env('ROLLBACK_TARGET_MTTR', 120), // 2 minutes
        'rollback_keep_previous' => env('ROLLBACK_KEEP_PREVIOUS', true),
        'rollback_window_hours' => env('ROLLBACK_WINDOW_HOURS', 1),

        // Replicas Configuration
        'replicas' => env('PRODUCTION_REPLICAS', 2),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Logging Configuration
    |--------------------------------------------------------------------------
    */
    'logging' => [
        'channel' => env('PRODUCTION_LOG_CHANNEL', 'stack'),
        'level' => env('PRODUCTION_LOG_LEVEL', 'error'),
        'days' => env('PRODUCTION_LOG_DAYS', '30'),
        'channels' => ['daily', 'slack'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Monitoring Configuration
    |--------------------------------------------------------------------------
    */
    'monitoring' => [
        'enabled' => env('PRODUCTION_MONITORING_ENABLED', true),
        'prometheus_enabled' => env('PROMETHEUS_ENABLED', true),
        'prometheus_port' => env('PROMETHEUS_PORT', 9090),
        'grafana_url' => env('GRAFANA_URL'),
        'grafana_password' => env('GRAFANA_PASSWORD'),
        'health_check_interval' => env('PRODUCTION_HEALTH_CHECK_INTERVAL', 30),
        'metrics_retention_days' => env('PRODUCTION_METRICS_RETENTION_DAYS', 90),
        'alert_email' => env('ALERT_EMAIL', 'ops@agl.com'),
        'alert_slack_webhook' => env('ALERT_SLACK_WEBHOOK'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Queue Configuration
    |--------------------------------------------------------------------------
    */
    'queue' => [
        'driver' => env('PRODUCTION_QUEUE_DRIVER', 'redis'),
        'connection' => env('PRODUCTION_QUEUE_CONNECTION', 'production'),
        'tries' => env('PRODUCTION_QUEUE_TRIES', 5),
        'timeout' => env('PRODUCTION_QUEUE_TIMEOUT', 600),
        'sleep' => env('PRODUCTION_QUEUE_SLEEP', 3),
        'max_tries' => env('PRODUCTION_QUEUE_MAX_TRIES', 3),
        'force' => env('PRODUCTION_QUEUE_FORCE', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Mail Configuration
    |--------------------------------------------------------------------------
    */
    'mail' => [
        'mailer' => env('PRODUCTION_MAIL_MAILER', 'smtp'),
        'host' => env('PRODUCTION_MAIL_HOST'),
        'port' => env('PRODUCTION_MAIL_PORT', '587'),
        'encryption' => env('PRODUCTION_MAIL_ENCRYPTION', 'tls'),
        'username' => env('PRODUCTION_MAIL_USERNAME'),
        'password' => env('PRODUCTION_MAIL_PASSWORD'),
        'from' => [
            'address' => env('PRODUCTION_MAIL_FROM_ADDRESS', 'noreply@agl.aglz.io'),
            'name' => env('PRODUCTION_MAIL_FROM_NAME', 'AGL Hostman'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Session Configuration
    |--------------------------------------------------------------------------
    */
    'session' => [
        'driver' => env('PRODUCTION_SESSION_DRIVER', 'redis'),
        'lifetime' => env('PRODUCTION_SESSION_LIFETIME', 120),
        'encrypt' => env('PRODUCTION_SESSION_ENCRYPT', true),
        'cookie_name' => env('PRODUCTION_SESSION_COOKIE', 'agl_hostman_session'),
        'secure' => env('PRODUCTION_SESSION_SECURE', true),
        'http_only' => env('PRODUCTION_SESSION_HTTP_ONLY', true),
        'same_site' => env('PRODUCTION_SESSION_SAME_SITE', 'lax'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Performance Configuration
    |--------------------------------------------------------------------------
    */
    'performance' => [
        'query_timeout' => env('PRODUCTION_QUERY_TIMEOUT', 30),
        'max_connections' => env('PRODUCTION_MAX_CONNECTIONS', 100),
        'memory_limit' => env('PRODUCTION_MEMORY_LIMIT', '8192M'),
        'cpu_cores' => env('PRODUCTION_CPU_CORES', 4),
        'disk_gb' => env('PRODUCTION_DISK_GB', 100),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Security Configuration
    |--------------------------------------------------------------------------
    */
    'security' => [
        'waf_enabled' => env('PRODUCTION_WAF_ENABLED', true),
        'rate_limit_max' => env('PRODUCTION_RATE_LIMIT_MAX', 100),
        'rate_limit_window' => env('PRODUCTION_RATE_LIMIT_WINDOW', 60),
        'ip_whitelist_admin' => env('PRODUCTION_IP_WHITELIST_ADMIN', ''),
        'audit_log_enabled' => env('PRODUCTION_AUDIT_LOG_ENABLED', true),
        'secrets_rotation_days' => env('PRODUCTION_SECRETS_ROTATION_DAYS', 90),
        'ssl_enforce' => env('PRODUCTION_SSL_ENFORCE', true),
        'hsts_enabled' => env('PRODUCTION_HSTS_ENABLED', true),
        'hsts_max_age' => env('PRODUCTION_HSTS_MAX_AGE', 31536000),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Backup Configuration
    |--------------------------------------------------------------------------
    */
    'backup' => [
        'enabled' => env('BACKUP_ENABLED', true),
        'schedule' => env('BACKUP_SCHEDULE', '0 2 * * *'),
        'retention_days' => env('BACKUP_RETENTION_DAYS', 30),
        'incremental_schedule' => env('BACKUP_INCREMENTAL_SCHEDULE', '0 * * * *'),
        'incremental_retention_days' => env('BACKUP_INCREMENTAL_RETENTION_DAYS', 7),
        'storage' => env('BACKUP_STORAGE', 's3'),
        's3_bucket' => env('BACKUP_S3_BUCKET', 'agl-hostman-backups'),
        'verify_enabled' => env('BACKUP_VERIFY_ENABLED', true),
        'test_restore_monthly' => env('BACKUP_TEST_RESTORE_MONTHLY', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Production Disaster Recovery Configuration
    |--------------------------------------------------------------------------
    */
    'disaster_recovery' => [
        'enabled' => env('DR_ENABLED', true),
        'rto_hours' => env('DR_RTO_HOURS', 1),
        'rpo_hours' => env('DR_RPO_HOURS', 1),
        'secondary_region' => env('DR_SECONDARY_REGION', 'us-west-2'),
        'failover_manual' => env('DR_FAILOVER_MANUAL', true),
    ],
];
