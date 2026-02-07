<?php

return [
    /*
    |--------------------------------------------------------------------------
    | N8N Base URL
    |--------------------------------------------------------------------------
    |
    | The base URL for your N8N instance
    | Internal Docker network: http://n8n:5678
    | Public URL: https://n8n.aglz.io
    |
    */
    'api_url' => env('N8N_API_URL', 'http://n8n:5678'),

    /*
    |--------------------------------------------------------------------------
    | N8N API Key
    |--------------------------------------------------------------------------
    |
    | API key for authenticating with N8N REST API
    | Generated at: /settings/api
    | Used for workflow management and execution queries
    |
    */
    'api_key' => env('N8N_API_KEY'),

    /*
    |--------------------------------------------------------------------------
    | Webhook Secret
    |--------------------------------------------------------------------------
    |
    | HMAC secret for verifying incoming N8N webhooks
    | Set in N8N workflow nodes for security
    |
    */
    'webhook_secret' => env('N8N_WEBHOOK_SECRET'),

    /*
    |--------------------------------------------------------------------------
    | Webhook Base URL
    |--------------------------------------------------------------------------
    |
    | Base URL for triggering N8N webhooks
    | May differ from api_url if using public webhook endpoint
    |
    */
    'webhook_base_url' => env('N8N_WEBHOOK_BASE_URL', env('N8N_API_URL', 'http://n8n:5678')),

    /*
    |--------------------------------------------------------------------------
    | Default Workflows
    |--------------------------------------------------------------------------
    |
    | Default workflow IDs for common operations
    | Configure these in N8N and copy the workflow IDs
    |
    */
    'workflows' => [
        'monitoring' => env('N8N_WORKFLOW_MONITORING'),
        'ai_agent' => env('N8N_WORKFLOW_AI_AGENT'),
        'deployment' => env('N8N_WORKFLOW_DEPLOYMENT'),
        'backup' => env('N8N_WORKFLOW_BACKUP'),
        'alert' => env('N8N_WORKFLOW_ALERT'),
        'scaling' => env('N8N_WORKFLOW_SCALING'),
        'security_scan' => env('N8N_WORKFLOW_SECURITY_SCAN'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Retry Configuration
    |--------------------------------------------------------------------------
    |
    | Maximum retry attempts for failed workflow executions
    | Uses exponential backoff: 0.5s, 0.75s, 1.125s, ...
    |
    */
    'max_retries' => env('N8N_MAX_RETRIES', 3),

    /*
    |--------------------------------------------------------------------------
    | Timeout Configuration
    |--------------------------------------------------------------------------
    |
    | Request timeout in seconds for N8N API calls
    |
    */
    'timeout' => env('N8N_TIMEOUT', 30),

    /*
    |--------------------------------------------------------------------------
    | Circuit Breaker Configuration
    |--------------------------------------------------------------------------
    |
    | Circuit breaker settings to prevent cascading failures
    | threshold: Number of failures before opening circuit
    | timeout: Seconds to wait before attempting recovery
    |
    */
    'circuit_breaker' => [
        'threshold' => env('N8N_CIRCUIT_BREAKER_THRESHOLD', 5),
        'timeout' => env('N8N_CIRCUIT_BREAKER_TIMEOUT', 60),
    ],

    /*
    |--------------------------------------------------------------------------
    | Workflow Sync Settings
    |--------------------------------------------------------------------------
    |
    | Automatic synchronization of workflows from N8N
    | sync_interval: How often to sync (in minutes)
    | auto_sync: Enable/disable automatic sync
    |
    */
    'sync' => [
        'enabled' => env('N8N_SYNC_ENABLED', true),
        'interval' => env('N8N_SYNC_INTERVAL', 60), // minutes
    ],

    /*
    |--------------------------------------------------------------------------
    | Execution History Settings
    |--------------------------------------------------------------------------
    |
    | Store workflow execution history in database
    | retention_days: How long to keep execution logs
    |
    */
    'execution_history' => [
        'enabled' => env('N8N_EXECUTION_HISTORY_ENABLED', true),
        'retention_days' => env('N8N_EXECUTION_RETENTION_DAYS', 30),
    ],

    /*
    |--------------------------------------------------------------------------
    | Workflow Categories
    |--------------------------------------------------------------------------
    |
    | Predefined categories for organizing workflows
    |
    */
    'categories' => [
        'automation' => 'Process Automation',
        'monitoring' => 'Infrastructure Monitoring',
        'deployment' => 'Deployment Workflows',
        'backup' => 'Backup and Recovery',
        'security' => 'Security Scanning',
        'notification' => 'Notifications and Alerts',
        'integration' => 'Third-party Integrations',
    ],

    /*
    |--------------------------------------------------------------------------
    | Error Handling
    |--------------------------------------------------------------------------
    |
    | Global error handling settings
    | log_errors: Log all N8N errors
    | notify_on_failure: Send notification on workflow failure
    |
    */
    'error_handling' => [
        'log_errors' => env('N8N_LOG_ERRORS', true),
        'notify_on_failure' => env('N8N_NOTIFY_ON_FAILURE', true),
        'notification_channels' => env('N8N_FAILURE_NOTIFICATION_CHANNELS', 'slack,email'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Performance Settings
    |--------------------------------------------------------------------------
    |
    | Performance optimization settings
    | cache_workflows: Cache workflow list for faster access
    | async_execution: Execute workflows asynchronously via queue
    |
    */
    'performance' => [
        'cache_workflows' => env('N8N_CACHE_WORKFLOWS', true),
        'cache_ttl' => env('N8N_CACHE_TTL', 3600), // seconds
        'async_execution' => env('N8N_ASYNC_EXECUTION', false),
        'queue_name' => env('N8N_QUEUE_NAME', 'n8n'),
    ],
];
