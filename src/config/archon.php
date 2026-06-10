<?php

declare(strict_types=1);

return [

    /*
    |--------------------------------------------------------------------------
    | Archon MCP Integration Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for Archon MCP server integration (CT183).
    | Provides task management, project tracking, and RAG knowledge base.
    |
    | Archon Instance: CT183 (archon) @ AGLSRV1 — hostname aglsrv1-archon
    | agldv07 = CT547 @ FGSRV7 (host dev separado; TS 100.64.139.79)
    | - LAN: 192.168.0.183:8052 (development only)
    | - WireGuard: 10.6.0.21:8051 (fastest, production)
    | - Tailscale: 100.80.30.59:8051 (backup)
    | - Public: https://archon.aglz.io (admin/ArchonPass2025)
    |
    | @see docs/ARCHON.md for complete documentation
    |
    */

    /*
    | Enable/disable Archon integration
    */
    'enabled' => env('ARCHON_ENABLED', true),

    /*
    | MCP Server URL
    | Priority: WireGuard (fastest) > LAN (local) > Tailscale (fallback)
    */
    'mcp_url' => env('ARCHON_MCP_URL', 'http://10.6.0.21:8051/mcp'),

    /*
    | Archon Web UI URL
    */
    'web_url' => env('ARCHON_WEB_URL', 'https://archon.aglz.io'),

    /*
    | HTTP Request Timeout (seconds)
    */
    'timeout' => env('ARCHON_TIMEOUT', 30),

    /*
    | Retry Configuration
    */
    'retry_times' => env('ARCHON_RETRY_TIMES', 3),
    'retry_delay' => env('ARCHON_RETRY_DELAY', 1000), // milliseconds

    /*
    | Sync Configuration
    */
    'sync_interval' => env('ARCHON_SYNC_INTERVAL', 300), // 5 minutes
    'sync_enabled' => env('ARCHON_SYNC_ENABLED', true),

    /*
    | Cache Configuration
    */
    'cache_ttl' => env('ARCHON_CACHE_TTL', 3600), // 1 hour
    'cache_enabled' => env('ARCHON_CACHE_ENABLED', true),

    /*
    | Available MCP Tools (28 total)
    */
    'tools' => [
        // Knowledge Base (6 tools)
        'knowledge' => [
            'rag_get_available_sources',
            'rag_search_knowledge_base',
            'rag_search_code_examples',
            'rag_list_pages_for_source',
            'rag_read_full_page',
            'archon_search_knowledge',
        ],

        // Project Management (3 tools)
        'projects' => [
            'find_projects',
            'manage_project',
            'get_project_features',
        ],

        // Task Management (2 tools)
        'tasks' => [
            'find_tasks',
            'manage_task',
        ],

        // Document Management (2 tools)
        'documents' => [
            'find_documents',
            'manage_document',
        ],

        // Version Management (2 tools)
        'versions' => [
            'find_versions',
            'manage_version',
        ],

        // System (3 tools)
        'system' => [
            'health_check',
            'session_info',
            'archon_get_status',
        ],
    ],

    /*
    | Conflict Resolution Strategy
    | Options: 'last-write-wins', 'manual', 'archon-wins', 'laravel-wins'
    */
    'conflict_resolution' => env('ARCHON_CONFLICT_RESOLUTION', 'last-write-wins'),

    /*
    | Logging Configuration
    */
    'logging' => [
        'enabled' => env('ARCHON_LOGGING_ENABLED', true),
        'channel' => env('ARCHON_LOG_CHANNEL', 'stack'),
        'level' => env('ARCHON_LOG_LEVEL', 'info'),
    ],

];
