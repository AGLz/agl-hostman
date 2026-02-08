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

    // Metrics collection interval (seconds)
    'collection_interval' => (int) env('MONITORING_COLLECTION_INTERVAL', 60),

    // Data retention period (days)
    'retention_days' => (int) env('MONITORING_RETENTION_DAYS', 90),

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
            'load' => [
                'warning' => 1.0,  // Load > cores = warning
                'critical' => 2.0, // Load > 2x cores = critical
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
            'disk' => [
                'warning' => 80,  // Disk > 80% = warning
                'critical' => 90, // Disk > 90% = critical
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

    // Custom metrics support
    'custom_metrics' => [
        'enabled' => env('MONITORING_CUSTOM_METRICS_ENABLED', true),
        'storage' => env('MONITORING_CUSTOM_METRICS_STORAGE', 'database'), // database, redis, prometheus
    ],

    // Alert settings
    'alerts' => [
        'enabled' => env('MONITORING_ALERTS_ENABLED', true),
        'deduplication_window_minutes' => (int) env('MONITORING_DEDUP_WINDOW', 15),
        'max_per_rule_hourly' => (int) env('MONITORING_MAX_ALERTS_PER_HOUR', 10),
        'auto_resolve_hours' => (int) env('MONITORING_AUTO_RESOLVE_HOURS', 24),
    ],

    // Performance trend settings
    'trends' => [
        'enabled' => env('MONITORING_TRENDS_ENABLED', true),
        'aggregation_interval' => (int) env('MONITORING_TREND_AGGREGATION', 5), // minutes
        'analysis_window_hours' => (int) env('MONITORING_TREND_WINDOW', 24),
    ],

    // Scheduled tasks
    'schedules' => [
        'metrics_collection' => (int) env('MONITORING_SCHEDULE_COLLECTION', 60), // seconds
        'health_check' => (int) env('MONITORING_SCHEDULE_HEALTH', 300), // seconds
        'cleanup' => env('MONITORING_SCHEDULE_CLEANUP', '0 2 * * *'), // cron expression
    ],

    // External integrations
    'integrations' => [
        'prometheus' => [
            'enabled' => env('MONITORING_PROMETHEUS_ENABLED', false),
            'pushgateway_url' => env('PROMETHEUS_PUSHGATEWAY_URL'),
            'job_name' => env('PROMETHEUS_JOB_NAME', 'agl-hostman'),
        ],
        'grafana' => [
            'enabled' => env('MONITORING_GRAFANA_ENABLED', false),
            'url' => env('GRAFANA_URL'),
            'api_key' => env('GRAFANA_API_KEY'),
        ],
    ],

    // Enable/disable features
    'features' => [
        'websocket_updates' => env('MONITORING_WEBSOCKET_ENABLED', true),
        'export_metrics' => env('MONITORING_EXPORT_ENABLED', true),
        'auto_refresh' => env('MONITORING_AUTO_REFRESH', true),
        'predictive_analysis' => env('MONITORING_PREDICTIVE_ENABLED', false),
    ],
];
