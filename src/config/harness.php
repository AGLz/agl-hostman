<?php

declare(strict_types=1);

return [
    'repo_root' => env('HARNESS_REPO_ROOT', base_path('..')),
    'governor_state_path' => env('HARNESS_GOVERNOR_STATE_PATH', storage_path('app/harness/quota-governor-state.json')),
    'governor_state_fallback' => env(
        'HARNESS_GOVERNOR_STATE_FALLBACK',
        base_path('../config/monitoring/quota-governor-state.example.json'),
    ),
    'virtual_keys_manifest' => env(
        'HARNESS_VIRTUAL_KEYS_MANIFEST',
        base_path('../config/litellm/virtual-keys-manifest.example.json'),
    ),
    'cache_ttl' => (int) env('HARNESS_SNAPSHOT_CACHE_TTL', 15),
    'litellm_gateway_url' => rtrim((string) env('LITELLM_GATEWAY_URL', 'http://100.125.249.8:4000'), '/'),
];
