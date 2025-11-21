<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Alert System Configuration
    |--------------------------------------------------------------------------
    |
    | Phase 3 Alert Center configuration
    | Controls alert behavior, rate limiting, and notification settings
    |
    */

    // Enable/disable alert system
    'enabled' => env('ALERTS_ENABLED', true),

    // Rate limiting: Maximum alerts per rule per hour
    'max_per_rule_hourly' => env('ALERTS_MAX_PER_RULE_HOURLY', 10),

    // Deduplication window in minutes
    // Prevents duplicate alerts within this timeframe
    'deduplication_window_minutes' => env('ALERTS_DEDUPLICATION_WINDOW_MINUTES', 15),

    // Alert history retention in days
    // Resolved alerts older than this will be automatically cleaned up
    'history_retention_days' => env('ALERTS_HISTORY_RETENTION_DAYS', 90),

    /*
    |--------------------------------------------------------------------------
    | Browser Notifications
    |--------------------------------------------------------------------------
    */

    'browser_notifications' => env('ALERTS_BROWSER_NOTIFICATIONS', true),
    'sound_enabled' => env('ALERTS_SOUND_ENABLED', true),
    'critical_sound' => env('ALERTS_CRITICAL_SOUND', '/sounds/alert-critical.mp3'),

    /*
    |--------------------------------------------------------------------------
    | Do Not Disturb Hours
    |--------------------------------------------------------------------------
    |
    | Disable notifications during these hours (24-hour format)
    |
    */

    'dnd_start' => env('ALERTS_DND_START', '22:00'),
    'dnd_end' => env('ALERTS_DND_END', '08:00'),

    /*
    |--------------------------------------------------------------------------
    | External Notification Channels
    |--------------------------------------------------------------------------
    */

    'slack' => [
        'enabled' => env('ALERTS_SLACK_ENABLED', false),
        'webhook_url' => env('ALERTS_SLACK_WEBHOOK_URL'),
    ],

    'discord' => [
        'enabled' => env('ALERTS_DISCORD_ENABLED', false),
        'webhook_url' => env('ALERTS_DISCORD_WEBHOOK_URL'),
    ],

    'email' => [
        'enabled' => env('ALERTS_EMAIL_ENABLED', false),
        'recipients' => env('ALERTS_EMAIL_RECIPIENTS', ''),
    ],

    /*
    |--------------------------------------------------------------------------
    | Health Check Thresholds
    |--------------------------------------------------------------------------
    |
    | Default thresholds for infrastructure health monitoring
    |
    */

    'thresholds' => [
        'cpu' => [
            'warning' => env('HEALTH_CPU_WARNING', 70),
            'critical' => env('HEALTH_CPU_CRITICAL', 90),
        ],
        'memory' => [
            'warning' => env('HEALTH_MEMORY_WARNING', 70),
            'critical' => env('HEALTH_MEMORY_CRITICAL', 85),
        ],
        'disk' => [
            'warning' => env('HEALTH_DISK_WARNING', 60),
            'critical' => env('HEALTH_DISK_CRITICAL', 80),
        ],
        'load' => [
            'warning' => env('HEALTH_LOAD_WARNING', 1.0),
            'critical' => env('HEALTH_LOAD_CRITICAL', 2.0),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Monitoring Intervals (seconds)
    |--------------------------------------------------------------------------
    */

    'intervals' => [
        'realtime' => env('MONITORING_INTERVAL_REALTIME', 30),
        'analysis' => env('MONITORING_INTERVAL_ANALYSIS', 300),
        'prediction' => env('MONITORING_INTERVAL_PREDICTION', 1800),
    ],
];
