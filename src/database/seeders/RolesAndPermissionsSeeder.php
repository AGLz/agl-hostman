<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Spatie\Permission\PermissionRegistrar;

/**
 * Roles and Permissions Seeder
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Creates default roles and permissions for RBAC system:
 * - Super Admin: Full system access
 * - Admin: Administrative access (user management, infrastructure)
 * - Operator: Infrastructure operations (start/stop containers)
 * - Analyst: Read-only access with predictive maintenance
 * - Viewer: Basic read-only access
 */
class RolesAndPermissionsSeeder extends Seeder
{
    /**
     * Run the database seeder.
     */
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[PermissionRegistrar::class]->forgetCachedPermissions();

        // ========================================
        // Create Permissions
        // ========================================

        // Dashboard & Monitoring
        Permission::create(['name' => 'view-dashboard']);
        Permission::create(['name' => 'view-realtime-updates']);
        Permission::create(['name' => 'view-health-metrics']);
        Permission::create(['name' => 'view-alerts']);

        // Predictive Maintenance
        Permission::create(['name' => 'view-predictions']);
        Permission::create(['name' => 'export-predictions']);
        Permission::create(['name' => 'configure-predictions']);

        // Infrastructure Management
        Permission::create(['name' => 'view-infrastructure']);
        Permission::create(['name' => 'manage-infrastructure']);
        Permission::create(['name' => 'start-containers']);
        Permission::create(['name' => 'stop-containers']);
        Permission::create(['name' => 'restart-containers']);
        Permission::create(['name' => 'delete-containers']);
        Permission::create(['name' => 'configure-containers']);

        // User Management
        Permission::create(['name' => 'view-users']);
        Permission::create(['name' => 'create-users']);
        Permission::create(['name' => 'edit-users']);
        Permission::create(['name' => 'delete-users']);
        Permission::create(['name' => 'manage-users']);
        Permission::create(['name' => 'activate-deactivate-users']);

        // Role & Permission Management
        Permission::create(['name' => 'view-roles']);
        Permission::create(['name' => 'create-roles']);
        Permission::create(['name' => 'edit-roles']);
        Permission::create(['name' => 'delete-roles']);
        Permission::create(['name' => 'manage-roles']);
        Permission::create(['name' => 'assign-roles']);
        Permission::create(['name' => 'assign-permissions']);

        // Audit Logs
        Permission::create(['name' => 'view-audit-logs']);
        Permission::create(['name' => 'export-audit-logs']);
        Permission::create(['name' => 'delete-audit-logs']);

        // System Administration
        Permission::create(['name' => 'admin-access']);
        Permission::create(['name' => 'system-configuration']);
        Permission::create(['name' => 'view-system-logs']);
        Permission::create(['name' => 'manage-system-settings']);

        // ========================================
        // Create Roles
        // ========================================

        // Super Admin - Full System Access
        $superAdmin = Role::create([
            'name' => 'super-admin',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Full system access',
        ]);
        $superAdmin->givePermissionTo(Permission::all());

        // Admin - Administrative Access
        $admin = Role::create([
            'name' => 'admin',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Administrative access',
        ]);
        $admin->givePermissionTo([
            // Dashboard
            'view-dashboard',
            'view-realtime-updates',
            'view-health-metrics',
            'view-alerts',

            // Predictions
            'view-predictions',
            'export-predictions',
            'configure-predictions',

            // Infrastructure
            'view-infrastructure',
            'manage-infrastructure',
            'start-containers',
            'stop-containers',
            'restart-containers',
            'configure-containers',

            // User Management
            'view-users',
            'create-users',
            'edit-users',
            'manage-users',
            'activate-deactivate-users',

            // Role Management
            'view-roles',
            'assign-roles',

            // Audit Logs
            'view-audit-logs',
            'export-audit-logs',

            // System
            'view-system-logs',
        ]);

        // Operator - Infrastructure Operations
        $operator = Role::create([
            'name' => 'operator',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Infrastructure operations',
        ]);
        $operator->givePermissionTo([
            // Dashboard
            'view-dashboard',
            'view-realtime-updates',
            'view-health-metrics',
            'view-alerts',

            // Predictions
            'view-predictions',
            'export-predictions',

            // Infrastructure (operations only, no delete)
            'view-infrastructure',
            'start-containers',
            'stop-containers',
            'restart-containers',

            // Audit Logs (view only)
            'view-audit-logs',
        ]);

        // Analyst - Read-Only with Predictions
        $analyst = Role::create([
            'name' => 'analyst',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Analyst',
        ]);
        $analyst->givePermissionTo([
            // Dashboard
            'view-dashboard',
            'view-realtime-updates',
            'view-health-metrics',
            'view-alerts',

            // Predictions (full access)
            'view-predictions',
            'export-predictions',
            'configure-predictions',

            // Infrastructure (view only)
            'view-infrastructure',

            // Audit Logs (view only)
            'view-audit-logs',
            'export-audit-logs',
        ]);

        // Viewer - Basic Read-Only Access
        $viewer = Role::create([
            'name' => 'viewer',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Read-only viewer',
        ]);
        $viewer->givePermissionTo([
            // Dashboard (basic view)
            'view-dashboard',
            'view-health-metrics',

            // Infrastructure (view only)
            'view-infrastructure',
        ]);

        // Common — papel usado nos testes e legado (alinhado ao viewer)
        $common = Role::create([
            'name' => 'common',
            'guard_name' => 'web',
            'is_system' => true,
            'description' => 'Common / basic access',
        ]);
        $common->syncPermissions($viewer->permissions);

        $this->command->info('Roles and permissions created successfully!');
        $this->command->info('Created roles: super-admin, admin, operator, analyst, viewer');
        $this->command->info('Created '.Permission::count().' permissions');
    }
}
