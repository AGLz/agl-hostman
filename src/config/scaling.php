<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Auto-Scaling Configuration
    |--------------------------------------------------------------------------
    |
    | Configure automatic container scaling based on resource metrics.
    | Integrates with Dokploy for deployment scaling.
    |
    */

    'enabled' => env('AUTO_SCALING_ENABLED', false),

    /*
    |--------------------------------------------------------------------------
    | Scaling Limits
    |--------------------------------------------------------------------------
    */

    'limits' => [
        'min_replicas' => env('SCALING_MIN_REPLICAS', 2),
        'max_replicas' => env('SCALING_MAX_REPLICAS', 10),
        'max_scale_up_step' => env('SCALING_MAX_UP_STEP', 2),    // Max replicas to add at once
        'max_scale_down_step' => env('SCALING_MAX_DOWN_STEP', 1), // Max replicas to remove at once
    ],

    /*
    |--------------------------------------------------------------------------
    | Scaling Triggers - CPU
    |--------------------------------------------------------------------------
    */

    'triggers' => [
        'cpu' => [
            'enabled' => true,
            'scale_up' => [
                'threshold' => 70,      // Percentage
                'duration' => 180,       // Seconds (3 minutes)
                'cooldown' => 300,       // Seconds (5 minutes)
            ],
            'scale_down' => [
                'threshold' => 30,      // Percentage
                'duration' => 600,       // Seconds (10 minutes)
                'cooldown' => 600,       // Seconds (10 minutes)
            ],
        ],

        /*
        |--------------------------------------------------------------------------
        | Scaling Triggers - Memory
        |--------------------------------------------------------------------------
        */

        'memory' => [
            'enabled' => true,
            'scale_up' => [
                'threshold' => 80,      // Percentage
                'duration' => 120,       // Seconds (2 minutes)
                'cooldown' => 300,       // Seconds (5 minutes)
            ],
            'scale_down' => [
                'threshold' => 40,      // Percentage
                'duration' => 600,       // Seconds (10 minutes)
                'cooldown' => 600,       // Seconds (10 minutes)
            ],
        ],

        /*
        |--------------------------------------------------------------------------
        | Scaling Triggers - Request Rate
        |--------------------------------------------------------------------------
        */

        'request_rate' => [
            'enabled' => true,
            'scale_up' => [
                'threshold' => 1000,    // Requests per minute
                'duration' => 60,        // Seconds (1 minute)
                'cooldown' => 180,       // Seconds (3 minutes)
            ],
            'scale_down' => [
                'threshold' => 200,     // Requests per minute
                'duration' => 600,       // Seconds (10 minutes)
                'cooldown' => 600,       // Seconds (10 minutes)
            ],
        ],

        /*
        |--------------------------------------------------------------------------
        | Scaling Triggers - Response Time
        |--------------------------------------------------------------------------
        */

        'response_time' => [
            'enabled' => true,
            'scale_up' => [
                'threshold' => 500,     // Milliseconds
                'duration' => 120,       // Seconds (2 minutes)
                'cooldown' => 300,       // Seconds (5 minutes)
            ],
            'scale_down' => [
                'threshold' => 100,     // Milliseconds
                'duration' => 600,       // Seconds (10 minutes)
                'cooldown' => 600,       // Seconds (10 minutes)
            ],
        ],

        /*
        |--------------------------------------------------------------------------
        | Scaling Triggers - Queue Length
        |--------------------------------------------------------------------------
        */

        'queue_length' => [
            'enabled' => true,
            'scale_up' => [
                'threshold' => 100,     // Number of jobs
                'duration' => 60,        // Seconds (1 minute)
                'cooldown' => 180,       // Seconds (3 minutes)
            ],
            'scale_down' => [
                'threshold' => 10,      // Number of jobs
                'duration' => 600,       // Seconds (10 minutes)
                'cooldown' => 600,       // Seconds (10 minutes)
            ],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Metric Collection
    |--------------------------------------------------------------------------
    */

    'metrics' => [
        'collection_interval' => 30,  // Seconds
        'retention_period' => 86400,  // Seconds (24 hours)
        'aggregation_window' => 60,   // Seconds (1 minute)
    ],

    /*
    |--------------------------------------------------------------------------
    | Dokploy Integration
    |--------------------------------------------------------------------------
    */

    'dokploy' => [
        'api_url' => env('DOKPLOY_API_URL', 'https://dok.aglz.io/api'),
        'api_token' => env('DOKPLOY_API_TOKEN'),
        'application_id' => env('DOKPLOY_APPLICATION_ID'),
        'timeout' => 30, // Seconds
    ],

    /*
    |--------------------------------------------------------------------------
    | Notification Settings
    |--------------------------------------------------------------------------
    */

    'notifications' => [
        'enabled' => true,
        'channels' => ['slack', 'log'], // Available: slack, pagerduty, email, log
        'events' => [
            'scale_up' => true,
            'scale_down' => true,
            'scale_failed' => true,
            'limit_reached' => true,
        ],
        'severity' => [
            'scale_up' => 'info',
            'scale_down' => 'info',
            'scale_failed' => 'error',
            'limit_reached' => 'warning',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Advanced Settings
    |--------------------------------------------------------------------------
    */

    'advanced' => [
        // Require multiple metrics to agree before scaling
        'require_consensus' => true,
        'consensus_threshold' => 2, // Number of metrics that must trigger

        // Prevent scaling during specific time windows
        'blackout_windows' => [
            // ['start' => '02:00', 'end' => '04:00'], // Backup window
        ],

        // Gradual scaling - increase/decrease replicas incrementally
        'gradual_scaling' => true,
        'gradual_step_delay' => 60, // Seconds between steps

        // Health check before scaling down
        'health_check_before_scale_down' => true,

        // Predictive scaling based on historical patterns
        'predictive_scaling' => [
            'enabled' => false, // Future enhancement
            'lookback_period' => 604800, // 7 days
            'confidence_threshold' => 0.8,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Environment-Specific Scaling
    |--------------------------------------------------------------------------
    */

    'environments' => [
        'production' => [
            'min_replicas' => 3,
            'max_replicas' => 15,
            'aggressive_scaling' => true,
        ],
        'staging' => [
            'min_replicas' => 2,
            'max_replicas' => 5,
            'aggressive_scaling' => false,
        ],
        'development' => [
            'min_replicas' => 1,
            'max_replicas' => 2,
            'aggressive_scaling' => false,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Logging
    |--------------------------------------------------------------------------
    */

    'logging' => [
        'enabled' => true,
        'channel' => 'scaling', // Custom log channel
        'level' => 'info',
        'log_metrics' => true,
        'log_decisions' => true,
    ],
];
