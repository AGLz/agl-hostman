<?php

namespace App\Services\Rbac;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class PermissionService
{
    /**
     * Get all permissions grouped by module
     */
    public function getPermissionsGroupedByModule(): Collection
    {
        return Permission::all()->groupBy('module');
    }

    /**
     * Get all available modules
     */
    public function getAvailableModules(): array
    {
        return Permission::getModules();
    }

    /**
     * Create a new permission
     */
    public function createPermission(array $data): Permission
    {
        return DB::transaction(function () use ($data) {
            $permission = Permission::create([
                'name' => $data['name'],
                'guard_name' => $data['guard_name'] ?? 'web',
                'module' => $data['module'] ?? 'general',
                'description' => $data['description'] ?? null,
            ]);

            // Clear permission cache
            $this->clearPermissionCache();

            return $permission;
        });
    }

    /**
     * Update a permission
     */
    public function updatePermission(Permission $permission, array $data): Permission
    {
        return DB::transaction(function () use ($permission, $data) {
            $permission->update([
                'name' => $data['name'] ?? $permission->name,
                'guard_name' => $data['guard_name'] ?? $permission->guard_name,
                'module' => $data['module'] ?? $permission->module,
                'description' => $data['description'] ?? $permission->description,
            ]);

            $this->clearPermissionCache();

            return $permission->fresh();
        });
    }

    /**
     * Delete a permission
     */
    public function deletePermission(Permission $permission): bool
    {
        return DB::transaction(function () use ($permission) {
            $permission->delete();
            $this->clearPermissionCache();

            return true;
        });
    }

    /**
     * Assign permission to role
     */
    public function assignPermissionToRole(Permission $permission, Role $role): Role
    {
        return DB::transaction(function () use ($permission, $role) {
            if (! $role->hasPermissionTo($permission->name)) {
                $role->givePermissionTo($permission);
                $this->clearPermissionCache();
            }

            return $role->fresh();
        });
    }

    /**
     * Revoke permission from role
     */
    public function revokePermissionFromRole(Permission $permission, Role $role): Role
    {
        return DB::transaction(function () use ($permission, $role) {
            $role->revokePermissionTo($permission);
            $this->clearPermissionCache();

            return $role->fresh();
        });
    }

    /**
     * Assign permission directly to user
     */
    public function assignPermissionToUser(Permission $permission, User $user): User
    {
        return DB::transaction(function () use ($permission, $user) {
            if (! $user->hasDirectPermission($permission->name)) {
                $user->givePermissionTo($permission);
                $this->clearPermissionCache();
            }

            return $user->fresh();
        });
    }

    /**
     * Revoke permission from user
     */
    public function revokePermissionFromUser(Permission $permission, User $user): User
    {
        return DB::transaction(function () use ($permission, $user) {
            $user->revokePermissionTo($permission);
            $this->clearPermissionCache();

            return $user->fresh();
        });
    }

    /**
     * Sync permissions to role
     */
    public function syncPermissionsToRole(Role $role, array $permissionIds): Role
    {
        return DB::transaction(function () use ($role, $permissionIds) {
            $permissions = Permission::whereIn('id', $permissionIds)->get();
            $role->syncPermissions($permissions);
            $this->clearPermissionCache();

            return $role->fresh();
        });
    }

    /**
     * Get permissions for a specific module
     */
    public function getModulePermissions(string $module): Collection
    {
        return Permission::byModule($module)->get();
    }

    /**
     * Search permissions
     */
    public function searchPermissions(string $term): Collection
    {
        return Permission::search($term)->get();
    }

    /**
     * Get permission statistics
     */
    public function getStatistics(): array
    {
        return [
            'total_permissions' => Permission::count(),
            'total_modules' => count($this->getAvailableModules()),
            'permissions_by_module' => Permission::select('module')
                ->selectRaw('COUNT(*) as count')
                ->groupBy('module')
                ->pluck('count', 'module')
                ->toArray(),
        ];
    }

    /**
     * Clear permission cache
     */
    protected function clearPermissionCache(): void
    {
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
    }
}
