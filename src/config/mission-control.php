<?php

declare(strict_types=1);

/**
 * Mission Control — Service Registry (Fase 1: AGLSRV1).
 *
 * Fonte canónica de hosts/serviços monitorizados. Guests ≥20; health HTTP ≥10.
 * Runbooks: llm-wiki + docs/ — não duplicar runbooks longos aqui.
 */
return [
    'cache_ttl' => (int) env('MISSION_CONTROL_CACHE_TTL', 45),
    'health_timeout' => (int) env('MISSION_CONTROL_HEALTH_TIMEOUT', 3),
    'poll_interval_ms' => (int) env('MISSION_CONTROL_POLL_MS', 45000),
    'probe_health' => (bool) env('MISSION_CONTROL_PROBE_HEALTH', true),
    'probe_proxmox' => (bool) env('MISSION_CONTROL_PROBE_PROXMOX', true),

    'hosts' => [
        'aglsrv1' => [
            'code' => 'aglsrv1',
            'name' => 'AGLSRV1',
            'node' => env('MISSION_CONTROL_AGLSRV1_NODE', 'aglsrv1'),
            'lan_ip' => '192.168.0.245',
            'tailscale_ip' => '100.107.113.33',
            'inventory_doc' => 'docs/CT_INVENTORY_AGLSRV1.md',
            'wiki' => 'AGLSRV1 — Troubleshooting aglwk45',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Guests (grid semáforo) — inventário estático; Proxmox enriquece status
    |--------------------------------------------------------------------------
    */
    'guests' => [
        ['host' => 'aglsrv1', 'vmid' => 104, 'type' => 'qemu', 'name' => 'aglwk45', 'category' => 'workstation'],
        ['host' => 'aglsrv1', 'vmid' => 110, 'type' => 'qemu', 'name' => 'ollama-vm', 'category' => 'ai-gateway'],
        ['host' => 'aglsrv1', 'vmid' => 113, 'type' => 'lxc', 'name' => 'plex', 'category' => 'media'],
        ['host' => 'aglsrv1', 'vmid' => 117, 'type' => 'lxc', 'name' => 'cloudflared', 'category' => 'tunnel'],
        ['host' => 'aglsrv1', 'vmid' => 123, 'type' => 'lxc', 'name' => 'radarr', 'category' => 'media'],
        ['host' => 'aglsrv1', 'vmid' => 124, 'type' => 'lxc', 'name' => 'sonarr', 'category' => 'media'],
        ['host' => 'aglsrv1', 'vmid' => 131, 'type' => 'lxc', 'name' => 'mysql', 'category' => 'data'],
        ['host' => 'aglsrv1', 'vmid' => 134, 'type' => 'lxc', 'name' => 'agl-hostman-prod', 'category' => 'deploy'],
        ['host' => 'aglsrv1', 'vmid' => 137, 'type' => 'lxc', 'name' => 'redis', 'category' => 'data'],
        ['host' => 'aglsrv1', 'vmid' => 149, 'type' => 'lxc', 'name' => 'postgresql', 'category' => 'data'],
        ['host' => 'aglsrv1', 'vmid' => 165, 'type' => 'lxc', 'name' => 'aria2', 'category' => 'media'],
        ['host' => 'aglsrv1', 'vmid' => 172, 'type' => 'lxc', 'name' => 'prowlarr', 'category' => 'media'],
        ['host' => 'aglsrv1', 'vmid' => 179, 'type' => 'lxc', 'name' => 'agl-hostman-legacy', 'category' => 'deploy'],
        ['host' => 'aglsrv1', 'vmid' => 180, 'type' => 'lxc', 'name' => 'dokploy', 'category' => 'deploy'],
        ['host' => 'aglsrv1', 'vmid' => 182, 'type' => 'lxc', 'name' => 'harbor', 'category' => 'deploy'],
        ['host' => 'aglsrv1', 'vmid' => 183, 'type' => 'lxc', 'name' => 'archon', 'category' => 'agent'],
        ['host' => 'aglsrv1', 'vmid' => 184, 'type' => 'lxc', 'name' => 'supabase', 'category' => 'data'],
        ['host' => 'aglsrv1', 'vmid' => 186, 'type' => 'lxc', 'name' => 'litellm', 'category' => 'ai-gateway'],
        ['host' => 'aglsrv1', 'vmid' => 187, 'type' => 'lxc', 'name' => 'openclaw', 'category' => 'agent'],
        ['host' => 'aglsrv1', 'vmid' => 188, 'type' => 'lxc', 'name' => 'hermes', 'category' => 'agent'],
        ['host' => 'aglsrv1', 'vmid' => 192, 'type' => 'lxc', 'name' => 'honcho', 'category' => 'agent'],
        ['host' => 'aglsrv1', 'vmid' => 193, 'type' => 'lxc', 'name' => 'obsidian', 'category' => 'storage'],
        ['host' => 'aglsrv1', 'vmid' => 200, 'type' => 'lxc', 'name' => 'ollama', 'category' => 'ai-gateway'],
        ['host' => 'aglsrv1', 'vmid' => 202, 'type' => 'lxc', 'name' => 'n8n', 'category' => 'deploy'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Serviços com health probe
    |--------------------------------------------------------------------------
    */
    'services' => [
        'litellm' => [
            'host' => 'aglsrv1',
            'vmid' => 186,
            'name' => 'LiteLLM',
            'category' => 'ai-gateway',
            'health_url' => env('MISSION_CONTROL_LITELLM_HEALTH', 'http://100.125.249.8:4000/health/readiness'),
            'accept_statuses' => [200],
            'runbook' => 'docs/LITELLM-TROUBLESHOOTING.md',
            'priority' => true,
        ],
        'openclaw' => [
            'host' => 'aglsrv1',
            'vmid' => 187,
            'name' => 'OpenClaw',
            'category' => 'agent',
            'health_url' => env('MISSION_CONTROL_OPENCLAW_HEALTH', 'http://192.168.0.187:18789/healthz'),
            'accept_statuses' => [200],
            'runbook' => 'docs/OPENCLAW.md',
            'priority' => true,
        ],
        'hermes_api' => [
            'host' => 'aglsrv1',
            'vmid' => 188,
            'name' => 'Hermes API',
            'category' => 'agent',
            'health_url' => env('MISSION_CONTROL_HERMES_HEALTH', 'http://100.81.225.22:8642/health'),
            'accept_statuses' => [200],
            'runbook' => 'docs/HERMES-MISSION-CONTROL.md',
            'priority' => true,
        ],
        'hermes_minions' => [
            'host' => 'aglsrv1',
            'vmid' => 188,
            'name' => 'Hermes Minions',
            'category' => 'agent',
            'health_url' => env('MISSION_CONTROL_MINIONS_HEALTH', 'http://100.81.225.22:6969/api/health'),
            'accept_statuses' => [200],
            'runbook' => 'docs/HERMES-MISSION-CONTROL.md',
            'priority' => true,
        ],
        'honcho' => [
            'host' => 'aglsrv1',
            'vmid' => 192,
            'name' => 'Honcho',
            'category' => 'agent',
            'health_url' => env('MISSION_CONTROL_HONCHO_HEALTH', 'http://192.168.0.192:8000/health'),
            'accept_statuses' => [200, 404],
            'runbook' => 'docs/HERMES-AGENCY-AGENTS.md',
            'priority' => true,
        ],
        'harbor' => [
            'host' => 'aglsrv1',
            'vmid' => 182,
            'name' => 'Harbor',
            'category' => 'deploy',
            'health_url' => env('MISSION_CONTROL_HARBOR_HEALTH', 'https://harbor.aglz.io/v2/'),
            'accept_statuses' => [200, 401],
            'runbook' => 'docs/CT134-AGL-HOSTMAN-PRODUCTION.md',
            'priority' => true,
        ],
        'dokploy' => [
            'host' => 'aglsrv1',
            'vmid' => 180,
            'name' => 'Dokploy',
            'category' => 'deploy',
            'health_url' => env('MISSION_CONTROL_DOKPLOY_HEALTH', 'http://192.168.0.180:3000/api/health'),
            'accept_statuses' => [200],
            'runbook' => 'docs/CT134-AGL-HOSTMAN-PRODUCTION.md',
            'priority' => true,
        ],
        'hostman_prod' => [
            'host' => 'aglsrv1',
            'vmid' => 134,
            'name' => 'agl-hostman prod',
            'category' => 'deploy',
            'health_url' => env('MISSION_CONTROL_HOSTMAN_HEALTH', 'https://ah.aglz.io/health/'),
            'accept_statuses' => [200],
            'runbook' => 'docs/CT134-AGL-HOSTMAN-PRODUCTION.md',
            'priority' => true,
        ],
        'archon' => [
            'host' => 'aglsrv1',
            'vmid' => 183,
            'name' => 'Archon',
            'category' => 'agent',
            'health_url' => env('MISSION_CONTROL_ARCHON_HEALTH', 'http://192.168.0.183:8051/health'),
            'accept_statuses' => [200],
            'runbook' => 'docs/CT_INVENTORY_AGLSRV1.md',
            'priority' => false,
        ],
        'supabase' => [
            'host' => 'aglsrv1',
            'vmid' => 184,
            'name' => 'Supabase',
            'category' => 'data',
            'health_url' => env('MISSION_CONTROL_SUPABASE_HEALTH', 'http://192.168.0.184:8000/health'),
            'accept_statuses' => [200],
            'runbook' => 'docs/CT_INVENTORY_AGLSRV1.md',
            'priority' => false,
        ],
        'ollama' => [
            'host' => 'aglsrv1',
            'vmid' => 200,
            'name' => 'Ollama',
            'category' => 'ai-gateway',
            'health_url' => env('MISSION_CONTROL_OLLAMA_HEALTH', 'http://192.168.0.200:11434/api/tags'),
            'accept_statuses' => [200],
            'runbook' => 'docs/AGL-OLLAMA-VM110.md',
            'priority' => true,
        ],
        'n8n' => [
            'host' => 'aglsrv1',
            'vmid' => 202,
            'name' => 'N8N',
            'category' => 'deploy',
            'health_url' => env('MISSION_CONTROL_N8N_HEALTH', 'http://192.168.0.202:5678/healthz'),
            'accept_statuses' => [200],
            'runbook' => 'docs/CT_INVENTORY_AGLSRV1.md',
            'priority' => false,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Runbook rules (engine v1 — condições simples)
    |--------------------------------------------------------------------------
    */
    'runbook_rules' => [
        [
            'id' => 'litellm_down',
            'severity' => 'critical',
            'title' => 'LiteLLM indisponível',
            'runbook' => 'docs/LITELLM-TROUBLESHOOTING.md',
            'when' => ['service' => 'litellm', 'health' => 'down'],
        ],
        [
            'id' => 'hermes_down',
            'severity' => 'critical',
            'title' => 'Hermes API / Minions down',
            'runbook' => 'docs/HERMES-MISSION-CONTROL.md',
            'when' => ['any_service' => ['hermes_api', 'hermes_minions'], 'health' => 'down'],
        ],
        [
            'id' => 'meshagent_vm104',
            'severity' => 'warning',
            'title' => 'VM104 aglwk45 — verificar meshagent RSS (>1GB)',
            'runbook' => 'docs/AGLWK45-SETUP.md',
            'when' => ['vmid' => 104, 'guest_status' => ['running', 'unknown']],
        ],
        [
            'id' => 'priority_guest_stopped',
            'severity' => 'critical',
            'title' => 'Guest prioritário parado',
            'runbook' => 'docs/AGLSRV1-TROUBLESHOOTING.md',
            'when' => ['priority_guest_stopped' => true],
        ],
        [
            'id' => 'harbor_down',
            'severity' => 'critical',
            'title' => 'Harbor registry down',
            'runbook' => 'docs/CT134-AGL-HOSTMAN-PRODUCTION.md',
            'when' => ['service' => 'harbor', 'health' => 'down'],
        ],
    ],
];
