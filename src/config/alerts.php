<?php

return [
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
        'recipients' => explode(',', env('ALERTS_EMAIL_RECIPIENTS', '')),
    ],
];
