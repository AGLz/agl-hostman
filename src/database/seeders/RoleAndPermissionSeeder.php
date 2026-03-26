<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RoleAndPermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Create permissions
        $permissions = [
            // User management
            'view users',
            'create users',
            'edit users',
            'delete users',

            // Location management
            'view locations',
            'manage locations',
            'assign locations',

            // Infrastructure monitoring
            'view infrastructure',
            'manage infrastructure',
            'execute commands',

            // N8N workflows
            'view workflows',
            'create workflows',
            'execute workflows',
            'manage workflows',

            // AI Models
            'view ai models',
            'use ai models',
            'configure ai models',

            // System
            'view logs',
            'view telescope',
            'view horizon',
            'manage system',

            // Scrum board
            'view board',
            'create tasks',
            'edit tasks',
            'delete tasks',
        ];

        foreach ($permissions as $permission) {
            Permission::create(['name' => $permission]);
        }

        // Create roles and assign permissions

        // Admin - acesso total
        $adminRole = Role::create(['name' => 'admin']);
        $adminRole->givePermissionTo(Permission::all());

        // Advanced - gerenciamento avançado
        $advancedRole = Role::create(['name' => 'advanced']);
        $advancedRole->givePermissionTo([
            'view users',
            'edit users',
            'view locations',
            'manage locations',
            'view infrastructure',
            'manage infrastructure',
            'view workflows',
            'create workflows',
            'execute workflows',
            'view ai models',
            'use ai models',
            'view logs',
            'view telescope',
            'view board',
            'create tasks',
            'edit tasks',
        ]);

        // Common - operações básicas
        $commonRole = Role::create(['name' => 'common']);
        $commonRole->givePermissionTo([
            'view users',
            'view locations',
            'view infrastructure',
            'view workflows',
            'execute workflows',
            'view ai models',
            'use ai models',
            'view board',
            'create tasks',
            'edit tasks',
        ]);

        // Restricted - apenas leitura
        $restrictedRole = Role::create(['name' => 'restricted']);
        $restrictedRole->givePermissionTo([
            'view locations',
            'view infrastructure',
            'view workflows',
            'view board',
        ]);
    }
}
