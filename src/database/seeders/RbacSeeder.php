<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class RbacSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // ========================================
        // Create System Roles
        // ========================================
        $roles = [
            [
                'name' => 'admin',
                'description' => 'Full system access with all permissions',
                'is_system' => true,
            ],
            [
                'name' => 'advanced',
                'description' => 'Can manage containers, deployments, and view monitoring',
                'is_system' => true,
            ],
            [
                'name' => 'common',
                'description' => 'Read-only access to monitoring and deployments',
                'is_system' => true,
            ],
            [
                'name' => 'restricted',
                'description' => 'Limited access to specific resources',
                'is_system' => true,
            ],
        ];

        $createdRoles = [];
        foreach ($roles as $roleData) {
            $description = $roleData['description'];
            $isSystem = $roleData['is_system'];
            unset($roleData['description'], $roleData['is_system']);

            $role = Role::firstOrCreate(
                ['name' => $roleData['name'], 'guard_name' => 'web'],
                array_merge($roleData, [
                    'description' => $description,
                    'is_system' => $isSystem,
                ])
            );
            $createdRoles[$roleData['name']] = $role;
        }

        // ========================================
        // Create Permissions by Module
        // ========================================

        // Containers module
        $containers = [
            'containers.view',
            'containers.create',
            'containers.edit',
            'containers.delete',
            'containers.start',
            'containers.stop',
            'containers.restart',
            'containers.clone',
            'containers.backup',
            'containers.restore',
        ];

        // Servers module
        $servers = [
            'servers.view',
            'servers.manage',
            'servers.monitor',
            'servers.maintenance',
        ];

        // Users module
        $users = [
            'users.view',
            'users.create',
            'users.edit',
            'users.delete',
            'users.assign_roles',
            'users.manage_permissions',
        ];

        // Monitoring module
        $monitoring = [
            'monitoring.view',
            'monitoring.alerts',
            'monitoring.logs',
            'monitoring.reports',
        ];

        // Deployments module
        $deployments = [
            'deployments.view',
            'deployments.create',
            'deployments.manage',
            'deployments.rollback',
            'deployments.logs',
        ];

        // Infrastructure module
        $infrastructure = [
            'infrastructure.network',
            'infrastructure.storage',
            'infrastructure.backup',
            'infrastructure.security',
        ];

        // Admin module (for RBAC management)
        $admin = [
            'roles.view',
            'roles.create',
            'roles.edit',
            'roles.delete',
            'permissions.view',
            'permissions.manage',
        ];

        $allPermissions = array_merge(
            $containers,
            $servers,
            $users,
            $monitoring,
            $deployments,
            $infrastructure,
            $admin
        );

        $createdPermissions = [];
        foreach ($allPermissions as $permissionName) {
            [$module, $action] = explode('.', $permissionName);

            $permission = Permission::firstOrCreate(
                ['name' => $permissionName, 'guard_name' => 'web'],
                [
                    'module' => $module,
                    'description' => "Ability to {$action} {$module}",
                ]
            );
            $createdPermissions[$permissionName] = $permission;
        }

        // ========================================
        // Assign Permissions to Roles
        // ========================================

        // Admin: ALL permissions
        $createdRoles['admin']->syncPermissions($createdPermissions);

        // Advanced: Containers, Deployments, Monitoring (all actions)
        $advancedPermissions = array_filter(
            $createdPermissions,
            fn($key) => str_starts_with($key, 'containers.') ||
                          str_starts_with($key, 'deployments.') ||
                          str_starts_with($key, 'monitoring.') ||
                          $key === 'servers.view' ||
                          $key === 'servers.monitor',
            ARRAY_FILTER_USE_KEY
        );
        $createdRoles['advanced']->syncPermissions($advancedPermissions);

        // Common: Read-only (.view) permissions only
        $commonPermissions = array_filter(
            $createdPermissions,
            fn($key) => str_ends_with($key, '.view'),
            ARRAY_FILTER_USE_KEY
        );
        $createdRoles['common']->syncPermissions($commonPermissions);

        // Restricted: No default permissions (assigned manually)
        $createdRoles['restricted']->syncPermissions([]);

        $this->command->info('========================================');
        $this->command->info('RBAC Seeder Completed Successfully');
        $this->command->info('========================================');
        $this->command->info('Roles created: ' . count($createdRoles));
        foreach ($createdRoles as $name => $role) {
            $permCount = $role->permissions()->count();
            $this->command->info("  - {$name}: {$permCount} permissions");
        }
        $this->command->info('Total permissions created: ' . count($createdPermissions));
        $this->command->info('========================================');
    }
}
