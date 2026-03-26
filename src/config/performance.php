<?php

declare(strict_types=1);

return [

    /*
    |--------------------------------------------------------------------------
    | Performance Profiling
    |--------------------------------------------------------------------------
    |
    | Enable/disable performance profiling for the application.
    | This tracks response times, query counts, and memory usage.
    |
    */

    'profiling_enabled' => env('PERFORMANCE_PROFILING_ENABLED', true),

    'log_queries' => env('PERFORMANCE_LOG_QUERIES', true),

    /*
    |--------------------------------------------------------------------------
    | Performance Thresholds
    |--------------------------------------------------------------------------
    |
    | Define thresholds for performance warnings and alerts.
    | Requests exceeding these thresholds will be logged.
    |
    */

    'thresholds' => [
        'response_time_ms' => env('PERFORMANCE_THRESHOLD_RESPONSE_MS', 100),
        'max_queries' => env('PERFORMANCE_THRESHOLD_MAX_QUERIES', 50),
        'memory_mb' => env('PERFORMANCE_THRESHOLD_MEMORY_MB', 128),
        'slow_query_threshold_ms' => env('PERFORMANCE_SLOW_QUERY_THRESHOLD_MS', 50),
    ],

    /*
    |--------------------------------------------------------------------------
    | Caching Configuration
    |--------------------------------------------------------------------------
    |
    | Configure default caching behavior for different data types.
    | These values can be overridden in CacheStrategyService.
    |
    */

    'cache' => [
        'default_ttl' => env('CACHE_DEFAULT_TTL', 300), // 5 minutes

        'strategies' => [
            'short' => [
                'ttl' => 30, // 30 seconds - for rapidly changing data
                'description' => 'For real-time data like metrics and monitoring',
            ],
            'medium' => [
                'ttl' => 300, // 5 minutes - for semi-static data
                'description' => 'For data that changes occasionally',
            ],
            'long' => [
                'ttl' => 3600, // 1 hour - for rarely changing data
                'description' => 'For configuration and reference data',
            ],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Database Optimization
    |--------------------------------------------------------------------------
    |
    | Settings for database query optimization and index management.
    |
    */

    'database' => [
        'log_slow_queries' => env('DB_LOG_SLOW_QUERIES', true),
        'slow_query_threshold_ms' => env('DB_SLOW_QUERY_THRESHOLD_MS', 100),
        'analyze_queries' => env('DB_ANALYZE_QUERIES', false),
        'auto_index_recommendations' => env('DB_AUTO_INDEX_RECOMMENDATIONS', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | API Response Optimization
    |--------------------------------------------------------------------------
    |
    | Settings for API response optimization.
    |
    */

    'api' => [
        'enable_compression' => env('API_ENABLE_COMPRESSION', true),
        'enable_pagination' => env('API_ENABLE_PAGINATION', true),
        'default_page_size' => env('API_DEFAULT_PAGE_SIZE', 25),
        'max_page_size' => env('API_MAX_PAGE_SIZE', 100),

        // Response size limits
        'max_response_size_kb' => env('API_MAX_RESPONSE_SIZE_KB', 1024),

        // Fields to exclude from responses by default
        'exclude_fields' => [
            'password',
            'remember_token',
            'created_at',
            'updated_at',
            'deleted_at',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Performance Monitoring
    |--------------------------------------------------------------------------
    |
    | Configure performance monitoring and alerting.
    |
    */

    'monitoring' => [
        'enabled' => env('PERFORMANCE_MONITORING_ENABLED', true),
        'sample_rate' => env('PERFORMANCE_SAMPLE_RATE', 1.0), // 1.0 = 100%
        'retention_days' => env('PERFORMANCE_RETENTION_DAYS', 30),

        // Metrics to track
        'track' => [
            'response_times',
            'query_counts',
            'memory_usage',
            'slow_queries',
            'n_plus_one_queries',
            'cache_hit_rates',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Eager Loading Rules
    |--------------------------------------------------------------------------
    |
    | Define automatic eager loading rules for models to prevent N+1 queries.
    |
    */

    'eager_loading' => [
        'User' => ['roles', 'permissions', 'physicalLocations'],
        'Alert' => ['resource'],
        'N8NWorkflow' => ['executions'],
        'Task' => ['story', 'assignee'],
        'Story' => ['sprint'],
        'Bug' => ['assignee'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Query Optimization
    |--------------------------------------------------------------------------
    |
    | Automatic query optimization settings.
    |
    */

    'query_optimization' => [
        'enable_chunking' => true, // Use chunk() for large result sets
        'chunk_size' => 500,
        'enable_cursor_pagination' => true,
        'prevent_duplicate_queries' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Memory Limits
    |--------------------------------------------------------------------------
    |
    | Memory limits for different operations.
    |
    */

    'memory' => [
        'max_export_rows' => 10000,
        'max_report_generation_mb' => 256,
        'max_cache_item_mb' => 1,
    ],

];
