<?php

declare(strict_types=1);

$defaultBase = 'http://100.123.184.125:28789';

return [
    'base_url' => rtrim((string) env('OPENCLAW_BASE_URL', $defaultBase), '/'),
    'chat_base_url' => rtrim((string) env('OPENCLAW_CHAT_BASE_URL', env('OPENCLAW_BASE_URL', $defaultBase)), '/'),
    'remote_status_enabled' => filter_var(env('OPENCLAW_REMOTE_STATUS_ENABLED', 'true'), FILTER_VALIDATE_BOOLEAN),
    'ssh_host' => (string) env('OPENCLAW_SSH_HOST', 'root@100.123.184.125'),
    'docker_container' => (string) env('OPENCLAW_DOCKER_CONTAINER', 'agl-openclaw-openclaw-gateway-1'),
    'ssh_connect_timeout' => (string) env('OPENCLAW_SSH_CONNECT_TIMEOUT', '8'),
    'gateway_token' => filled(env('OPENCLAW_GATEWAY_TOKEN')) ? (string) env('OPENCLAW_GATEWAY_TOKEN') : null,
    'chat_timeout' => (int) env('OPENCLAW_CHAT_TIMEOUT', 90),
    'chat_transport' => strtolower((string) env('OPENCLAW_CHAT_TRANSPORT', 'ssh-docker')),
];
