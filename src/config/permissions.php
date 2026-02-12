<?php

declare(strict_types=1);

return [
    /*
    |--------------------------------------------------------------------------
    | Default Roles
    |--------------------------------------------------------------------------
    |
    | Default system roles that are created during setup/seed.
    | These roles form the foundation of the RBAC system.
    |
    */

    'default_roles' => [
        [
            'name' => 'super-admin',
            'display_name' => 'Super Administrator',
            'description' => 'Full system access with all permissions',
            'is_system' => true,
            'is_default' => false,
        ],
        [
            'name' => 'admin',
            'display_name' => 'Administrator',
            'description' => 'Administrative access to manage system resources',
            'is_system' => true,
            'is_default' => false,
        ],
        [
            'name' => 'operator',
            'display_name' => 'Operator',
            'description' => 'Operational access to manage containers and deployments',
            'is_system' => true,
            'is_default' => false,
        ],
        [
            'name' => 'auditor',
            'display_name' => 'Security Auditor',
            'description' => 'Read-only access for security auditing and compliance',
            'is_system' => true,
            'is_default' => false,
        ],
        [
            'name' => 'developer',
            'display_name' => 'Developer',
            'description' => 'Development access for coding and testing',
            'is_system' => false,
            'is_default' => false,
        ],
        [
            'name' => 'analyst',
            'display_name' => 'Analyst',
            'description' => 'Read-only access to view metrics and analytics',
            'is_system' => false,
            'is_default' => false,
        ],
        [
            'name' => 'viewer',
            'display_name' => 'Viewer',
            'description' => 'Basic read-only access to dashboards',
            'is_system' => true,
            'is_default' => true,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Permission Modules
    |--------------------------------------------------------------------------
    |
    | Group permissions by functional module for better organization.
    |
    */

    'modules' => [
        'infrastructure' => 'Infrastructure Management',
        'users' => 'User Management',
        'security' => 'Security Management',
        'containers' => 'Container Management',
        'deployments' => 'Deployment Management',
        'monitoring' => 'Monitoring & Alerts',
        'backups' => 'Backup Management',
        'api' => 'API Access',
        'system' => 'System Configuration',
    ],

    /*
    |--------------------------------------------------------------------------
    | Default Permissions
    |--------------------------------------------------------------------------
    |
    | Core permissions that map to specific actions within each module.
    |
    */

    'default_permissions' => [
        // Infrastructure Module
        ['name' => 'view-infrastructure', 'display_name' => 'View Infrastructure', 'module' => 'infrastructure'],
        ['name' => 'manage-infrastructure', 'display_name' => 'Manage Infrastructure', 'module' => 'infrastructure'],
        ['name' => 'manage-containers', 'display_name' => 'Manage Containers', 'module' => 'infrastructure'],
        ['name' => 'manage-networks', 'display_name' => 'Manage Networks', 'module' => 'infrastructure'],
        ['name' => 'manage-deployments', 'display_name' => 'Manage Deployments', 'module' => 'infrastructure'],

        // User Management Module
        ['name' => 'view-users', 'display_name' => 'View Users', 'module' => 'users'],
        ['name' => 'manage-users', 'display_name' => 'Manage Users', 'module' => 'users'],
        ['name' => 'manage-roles', 'display_name' => 'Manage Roles', 'module' => 'users'],
        ['name' => 'impersonate-users', 'display_name' => 'Impersonate Users', 'module' => 'users'],

        // Security Module
        ['name' => 'view-security-logs', 'display_name' => 'View Security Logs', 'module' => 'security'],
        ['name' => 'manage-security-settings', 'display_name' => 'Manage Security Settings', 'module' => 'security'],
        ['name' => 'run-security-audits', 'display_name' => 'Run Security Audits', 'module' => 'security'],
        ['name' => 'view-audit-reports', 'display_name' => 'View Audit Reports', 'module' => 'security'],

        // Containers Module
        ['name' => 'view-containers', 'display_name' => 'View Containers', 'module' => 'containers'],
        ['name' => 'create-containers', 'display_name' => 'Create Containers', 'module' => 'containers'],
        ['name' => 'edit-containers', 'display_name' => 'Edit Containers', 'module' => 'containers'],
        ['name' => 'delete-containers', 'display_name' => 'Delete Containers', 'module' => 'containers'],
        ['name' => 'start-containers', 'display_name' => 'Start Containers', 'module' => 'containers'],
        ['name' => 'stop-containers', 'display_name' => 'Stop Containers', 'module' => 'containers'],
        ['name' => 'restart-containers', 'display_name' => 'Restart Containers', 'module' => 'containers'],

        // Deployments Module
        ['name' => 'view-deployments', 'display_name' => 'View Deployments', 'module' => 'deployments'],
        ['name' => 'create-deployments', 'display_name' => 'Create Deployments', 'module' => 'deployments'],
        ['name' => 'approve-deployments', 'display_name' => 'Approve Deployments', 'module' => 'deployments'],
        ['name' => 'rollback-deployments', 'display_name' => 'Rollback Deployments', 'module' => 'deployments'],

        // Monitoring Module
        ['name' => 'view-monitoring', 'display_name' => 'View Monitoring', 'module' => 'monitoring'],
        ['name' => 'configure-alerts', 'display_name' => 'Configure Alerts', 'module' => 'monitoring'],
        ['name' => 'manage-alert-rules', 'display_name' => 'Manage Alert Rules', 'module' => 'monitoring'],

        // Backups Module
        ['name' => 'view-backups', 'display_name' => 'View Backups', 'module' => 'backups'],
        ['name' => 'create-backups', 'display_name' => 'Create Backups', 'module' => 'backups'],
        ['name' => 'restore-backups', 'display_name' => 'Restore Backups', 'module' => 'backups'],
        ['name' => 'delete-backups', 'display_name' => 'Delete Backups', 'module' => 'backups'],

        // API Module
        ['name' => 'view-api-keys', 'display_name' => 'View API Keys', 'module' => 'api'],
        ['name' => 'create-api-keys', 'display_name' => 'Create API Keys', 'module' => 'api'],
        ['name' => 'revoke-api-keys', 'display_name' => 'Revoke API Keys', 'module' => 'api'],

        // System Module
        ['name' => 'view-system-info', 'display_name' => 'View System Info', 'module' => 'system'],
        ['name' => 'manage-system-config', 'display_name' => 'Manage System Configuration', 'module' => 'system'],
        ['name' => 'view-logs', 'display_name' => 'View Logs', 'module' => 'system'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Role-Permission Assignments
    |--------------------------------------------------------------------------
    |
    | Define which permissions are assigned to each default role.
    |
    */

    'role_permissions' => [
        'super-admin' => ['*'], // All permissions
        'admin' => [
            'view-infrastructure', 'manage-infrastructure', 'manage-containers', 'manage-networks', 'manage-deployments',
            'view-users', 'manage-users', 'manage-roles',
            'view-security-logs', 'manage-security-settings', 'run-security-audits', 'view-audit-reports',
            'view-containers', 'create-containers', 'edit-containers', 'delete-containers', 'start-containers', 'stop-containers', 'restart-containers',
            'view-deployments', 'create-deployments', 'approve-deployments', 'rollback-deployments',
            'view-monitoring', 'configure-alerts', 'manage-alert-rules',
            'view-backups', 'create-backups', 'restore-backups', 'delete-backups',
            'view-api-keys', 'create-api-keys', 'revoke-api-keys',
            'view-system-info', 'manage-system-config', 'view-logs',
        ],
        'operator' => [
            'view-infrastructure', 'manage-containers', 'manage-networks', 'manage-deployments',
            'view-security-logs',
            'view-containers', 'create-containers', 'edit-containers', 'delete-containers', 'start-containers', 'stop-containers', 'restart-containers',
            'view-deployments', 'create-deployments',
            'view-monitoring', 'configure-alerts',
            'view-backups', 'create-backups',
            'view-api-keys', 'create-api-keys',
            'view-system-info',
        ],
        'auditor' => [
            'view-infrastructure',
            'view-users',
            'view-security-logs', 'run-security-audits', 'view-audit-reports',
            'view-containers',
            'view-deployments',
            'view-monitoring',
            'view-backups',
            'view-api-keys',
            'view-system-info', 'view-logs',
        ],
        'developer' => [
            'view-infrastructure', 'manage-containers',
            'view-users',
            'view-security-logs',
            'view-containers', 'create-containers', 'edit-containers', 'delete-containers',
            'view-deployments', 'create-deployments',
            'view-monitoring',
            'view-backups',
            'view-api-keys', 'create-api-keys',
            'view-system-info', 'view-logs',
        ],
        'analyst' => [
            'view-infrastructure',
            'view-monitoring',
            'view-system-info',
        ],
        'viewer' => [
            'view-infrastructure',
            'view-containers',
            'view-deployments',
            'view-monitoring',
            'view-backups',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Protected Routes
    |--------------------------------------------------------------------------
    |
    | Routes that require special protection. These are automatically
    | protected in middleware.
    |
    */

    'protected_routes' => [
        'authentication' => [
            'login',
            'logout',
            'password/reset',
            'password/email',
            'register',
        ],
        'sensitive' => [
            'users/*',
            'roles/*',
            'permissions/*',
            'security/*',
            'api-keys/*',
            'system/*',
            'backups/*',
        ],
        'administrative' => [
            'settings/*',
            'audit/*',
            'logs/*',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Permission Cache Configuration
    |--------------------------------------------------------------------------
    |
    | Configure permission caching for performance optimization.
    |
    */

    'cache' => [
        'enabled' => env('PERMISSION_CACHE_ENABLED', true),
        'ttl_minutes' => env('PERMISSION_CACHE_TTL', 60),
    ],

    /*
    |--------------------------------------------------------------------------
    | Wildcard Permissions
    |--------------------------------------------------------------------------
    |
    | Enable wildcard permission matching (e.g., 'containers.*' matches all container permissions).
    | WARNING: Only enable if you understand the security implications.
    |
    */

    'wildcards_enabled' => env('PERMISSION_WILDCARDS_ENABLED', false),

    /*
    |--------------------------------------------------------------------------
    | Guest Access
    |--------------------------------------------------------------------------
    |
    | Configure what unauthenticated users can access.
    |
    */

    'guest_access' => [
        'enabled' => env('GUEST_ACCESS_ENABLED', false),
        'allowed_routes' => [
            'login',
            'password/reset',
            'password/email',
        ],
    ],
];
