<?php

return [
    /*
    |--------------------------------------------------------------------------
    | GitHub Webhook Configuration
    |--------------------------------------------------------------------------
    */
    'github_webhook_secret' => env('GITHUB_WEBHOOK_SECRET'),

    /*
    |--------------------------------------------------------------------------
    | Promotion Workflow Configuration
    |--------------------------------------------------------------------------
    */
    'promotion' => [
        'auto_dev_to_qa' => env('PROMOTION_AUTO_DEV_TO_QA', true),
        'qa_to_uat_approvals' => env('PROMOTION_QA_TO_UAT_APPROVALS', 1),
        'uat_to_prod_approvals' => env('PROMOTION_UAT_TO_PROD_APPROVALS', 2),
        'approval_timeout_hours' => env('PROMOTION_APPROVAL_TIMEOUT_HOURS', 24),
        'qa_stability_hours' => env('PROMOTION_QA_STABILITY_HOURS', 24),
        'uat_stability_hours' => env('PROMOTION_UAT_STABILITY_HOURS', 72),
    ],

    /*
    |--------------------------------------------------------------------------
    | Rollback Configuration
    |--------------------------------------------------------------------------
    |
    | rollback_on_failure: Automatically roll back when a QA/UAT deployment fails.
    | rollback_enabled:    Master switch. Set to false to disable all automatic rollbacks.
    | max_rollback_span:   Log a warning (but still proceed) when rolling back across
    |                      more than this many deployments.
    |
    | NOTE: Rollback DOES NOT revert database migrations. If a deployment included
    | schema changes, the rolled-back image will run against the new schema.
    | Ensure migrations are backwards-compatible before deploying.
    |
    */
    'rollback_on_failure' => env('DEPLOYMENT_ROLLBACK_ON_FAILURE', true),
    'rollback_enabled' => env('DOKPLOY_ROLLBACK_ENABLED', true),
    'max_rollback_span' => env('DOKPLOY_MAX_ROLLBACK_SPAN', 5),

    /*
    |--------------------------------------------------------------------------
    | Notification Configuration
    |--------------------------------------------------------------------------
    */
    'notifications' => [
        'channels' => env('NOTIFICATION_CHANNELS', 'email,slack'),
        'slack_webhook' => env('SLACK_PROMOTIONS_WEBHOOK'),
        'email_from' => env('PROMOTION_EMAIL_FROM', 'deployments@agl.com'),
        'alert_email' => env('PROMOTION_ALERT_EMAIL', 'ops@agl.com'),
    ],
];
