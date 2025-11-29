<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Notification Channels
    |--------------------------------------------------------------------------
    |
    | Define which channels should receive notifications by default for each
    | notification type. These can be overridden by notification rules.
    |
    */

    'defaults' => [
        'deployment' => ['slack'],
        'alert' => ['slack', 'pagerduty'],
        'pr' => ['slack'],
        'custom' => ['slack'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Slack Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Slack webhook integration. You can configure multiple
    | workspaces by defining them in the NotificationChannel model.
    |
    */

    'slack' => [
        'webhook_url' => env('SLACK_WEBHOOK_URL'),
        'channels' => [
            'general' => env('SLACK_CHANNEL_GENERAL', '#general'),
            'deployments' => env('SLACK_CHANNEL_DEPLOYMENTS', '#deployments'),
            'alerts' => env('SLACK_CHANNEL_ALERTS', '#alerts'),
            'github' => env('SLACK_CHANNEL_GITHUB', '#github'),
        ],
        'username' => env('SLACK_USERNAME', 'AGL-HOSTMAN Bot'),
        'icon_emoji' => env('SLACK_ICON_EMOJI', ':robot_face:'),
    ],

    /*
    |--------------------------------------------------------------------------
    | PagerDuty Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for PagerDuty incident management integration.
    |
    */

    'pagerduty' => [
        'api_url' => env('PAGERDUTY_API_URL', 'https://api.pagerduty.com'),
        'api_key' => env('PAGERDUTY_API_KEY'),
        'service_id' => env('PAGERDUTY_SERVICE_ID'),
        'escalation_policy_id' => env('PAGERDUTY_ESCALATION_POLICY_ID'),
        'from_email' => env('PAGERDUTY_FROM_EMAIL', 'alerts@aglz.io'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Email Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for email notifications. Uses Laravel's mail configuration.
    |
    */

    'email' => [
        'from' => [
            'address' => env('MAIL_FROM_ADDRESS', 'notifications@aglz.io'),
            'name' => env('MAIL_FROM_NAME', 'AGL-HOSTMAN'),
        ],
        'to' => [
            'critical' => env('NOTIFICATION_EMAIL_CRITICAL', 'oncall@aglz.io'),
            'warning' => env('NOTIFICATION_EMAIL_WARNING', 'ops@aglz.io'),
            'info' => env('NOTIFICATION_EMAIL_INFO', 'team@aglz.io'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Notification Grouping
    |--------------------------------------------------------------------------
    |
    | Configuration for noise reduction through notification grouping.
    |
    */

    'grouping' => [
        'enabled' => env('NOTIFICATION_GROUPING_ENABLED', true),
        'window' => env('NOTIFICATION_GROUPING_WINDOW', 300), // 5 minutes in seconds
        'threshold' => env('NOTIFICATION_GROUPING_THRESHOLD', 3), // Group after 3 similar notifications
    ],

    /*
    |--------------------------------------------------------------------------
    | Retry Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for notification retry logic.
    |
    */

    'retry' => [
        'max_attempts' => env('NOTIFICATION_MAX_RETRIES', 3),
        'delay' => env('NOTIFICATION_RETRY_DELAY', 1000), // milliseconds
        'backoff' => env('NOTIFICATION_RETRY_BACKOFF', 'exponential'), // linear or exponential
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate Limiting
    |--------------------------------------------------------------------------
    |
    | Configuration for rate limiting notifications to prevent overwhelming
    | external services.
    |
    */

    'rate_limit' => [
        'enabled' => env('NOTIFICATION_RATE_LIMIT_ENABLED', true),
        'slack' => [
            'max_per_minute' => env('SLACK_MAX_PER_MINUTE', 60),
            'max_per_hour' => env('SLACK_MAX_PER_HOUR', 1000),
        ],
        'pagerduty' => [
            'max_per_minute' => env('PAGERDUTY_MAX_PER_MINUTE', 30),
            'max_per_hour' => env('PAGERDUTY_MAX_PER_HOUR', 500),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Noise Reduction
    |--------------------------------------------------------------------------
    |
    | Built-in rules for reducing notification noise.
    |
    */

    'noise_reduction' => [
        'suppress_duplicates_window' => 600, // 10 minutes
        'suppress_info_business_hours' => env('SUPPRESS_INFO_BUSINESS_HOURS', true),
        'group_container_restarts' => env('GROUP_CONTAINER_RESTARTS', true),
        'escalate_critical_production' => env('ESCALATE_CRITICAL_PRODUCTION', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Business Hours
    |--------------------------------------------------------------------------
    |
    | Define business hours for noise reduction rules.
    |
    */

    'business_hours' => [
        'timezone' => env('BUSINESS_HOURS_TIMEZONE', 'America/New_York'),
        'days' => ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
        'start' => env('BUSINESS_HOURS_START', '09:00'),
        'end' => env('BUSINESS_HOURS_END', '17:00'),
    ],

    /*
    |--------------------------------------------------------------------------
    | On-Call Rotation
    |--------------------------------------------------------------------------
    |
    | Configuration for on-call rotation management.
    |
    */

    'on_call' => [
        'default_rotation_type' => env('ON_CALL_ROTATION_TYPE', 'weekly'), // daily, weekly, custom
        'rotation_day' => env('ON_CALL_ROTATION_DAY', 'monday'), // For weekly rotations
        'rotation_hour' => env('ON_CALL_ROTATION_HOUR', 9), // Hour of day (0-23)
        'auto_rotate' => env('ON_CALL_AUTO_ROTATE', true),
        'notify_before_rotation' => env('ON_CALL_NOTIFY_BEFORE_ROTATION', 24), // hours
    ],

    /*
    |--------------------------------------------------------------------------
    | Notification Templates
    |--------------------------------------------------------------------------
    |
    | Predefined templates for common notification types.
    |
    */

    'templates' => [
        'deployment_started' => [
            'title' => 'Deployment Started',
            'color' => 'warning',
            'emoji' => ':rocket:',
        ],
        'deployment_completed' => [
            'title' => 'Deployment Completed',
            'color' => 'good',
            'emoji' => ':white_check_mark:',
        ],
        'deployment_failed' => [
            'title' => 'Deployment Failed',
            'color' => 'danger',
            'emoji' => ':x:',
        ],
        'alert_critical' => [
            'title' => 'Critical Alert',
            'color' => 'danger',
            'emoji' => ':rotating_light:',
        ],
        'alert_warning' => [
            'title' => 'Warning Alert',
            'color' => 'warning',
            'emoji' => ':warning:',
        ],
        'alert_info' => [
            'title' => 'Information',
            'color' => 'good',
            'emoji' => ':information_source:',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Feature Flags
    |--------------------------------------------------------------------------
    |
    | Enable or disable specific notification features.
    |
    */

    'features' => [
        'slack' => env('NOTIFICATIONS_SLACK_ENABLED', true),
        'pagerduty' => env('NOTIFICATIONS_PAGERDUTY_ENABLED', true),
        'email' => env('NOTIFICATIONS_EMAIL_ENABLED', false),
        'webhook' => env('NOTIFICATIONS_WEBHOOK_ENABLED', true),
        'rules_engine' => env('NOTIFICATIONS_RULES_ENGINE_ENABLED', true),
        'grouping' => env('NOTIFICATIONS_GROUPING_ENABLED', true),
        'history' => env('NOTIFICATIONS_HISTORY_ENABLED', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | History Retention
    |--------------------------------------------------------------------------
    |
    | How long to keep notification history records.
    |
    */

    'history_retention' => [
        'enabled' => env('NOTIFICATION_HISTORY_RETENTION_ENABLED', true),
        'days' => env('NOTIFICATION_HISTORY_RETENTION_DAYS', 90),
    ],

    /*
    |--------------------------------------------------------------------------
    | Logging
    |--------------------------------------------------------------------------
    |
    | Notification logging configuration.
    |
    */

    'logging' => [
        'enabled' => env('NOTIFICATION_LOGGING_ENABLED', true),
        'channel' => env('NOTIFICATION_LOG_CHANNEL', 'stack'),
        'level' => env('NOTIFICATION_LOG_LEVEL', 'info'),
    ],

];
