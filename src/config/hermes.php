<?php

declare(strict_types=1);

$defaultApi = 'http://100.81.225.22:8642';

return [
    'api_base_url' => rtrim((string) env('HERMES_API_BASE_URL', $defaultApi), '/'),
    'api_key' => filled(env('HERMES_API_KEY')) ? (string) env('HERMES_API_KEY') : null,
    'minions_base_url' => rtrim((string) env('HERMES_MINIONS_BASE_URL', 'http://100.81.225.22:6969'), '/'),
    'studio_base_url' => rtrim((string) env('HERMES_STUDIO_BASE_URL', 'http://100.81.225.22:3003'), '/'),
    'claw3d_ws_url' => (string) env('HERMES_CLAW3D_WS_URL', 'ws://100.81.225.22:18789'),
    'dashboard_base_url' => rtrim((string) env('HERMES_DASHBOARD_BASE_URL', 'http://100.81.225.22:9119'), '/'),
    'studio_access_token' => filled(env('HERMES_STUDIO_ACCESS_TOKEN')) ? (string) env('HERMES_STUDIO_ACCESS_TOKEN') : null,
    'health_timeout' => (int) env('HERMES_HEALTH_TIMEOUT', 5),
    'chat_timeout' => (int) env('HERMES_CHAT_TIMEOUT', 90),
    'chat_model' => (string) env('HERMES_CHAT_MODEL', 'hermes-agent'),
];
