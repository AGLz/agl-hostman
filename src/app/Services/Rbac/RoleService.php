<?php

namespace App\Services\Rbac;

use App\Models\Role;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Collection;

class RoleService
{
    public function __construct(
        protected PermissionService $permissionService
    ) {}

    /**
     * Get all roles with user counts
     */
    public function getAllRoles(): Collection
    {
        return Role::with('permissions')
            ->withCount('users')
            ->orderBy('is_system', 'desc')
            ->orderBy('name')
            ->get();
    }

    /**
     * Get system roles
     */
    public function getSystemRoles(): Collection
    {
        return Role::system()->with('permissions')->get();
    }

    /**
     * Get custom roles
     */
    public function getCustomRoles(): Collection
    {
        return Role::custom()->with('permissions')->get();
    }

    /**
     * Create a new role
     */
    public function createRole(array $data): Role
    {
        return DB::transaction(function () use ($data) {
            $role = Role::create([
                'name' => $data['name'],
                'guard_name' => $data['guard_name'] ?? 'web',
                'description' => $data['description'] ?? null,
                'is_system' => $data['is_system'] ?? false,
            ]);

            // Sync permissions if provided
            if (!empty($data['permissions'])) {
                $this->permissionService->syncPermissionsToRole($role, $data['permissions']);
            }

            return $role;
        });
    }

    /**
     * Update a role
     */
    public function updateRole(Role $role, array $data): Role
    {
        return DB::transaction(function () use ($role, $data) {
            // Prevent modifying system roles' critical fields
            if ($role->is_system) {
                unset($data['name'], $data['is_system']);
            }

            $role->update([
                'name' => $data['name'] ?? $role->name,
                'guard_name' => $data['guard_name'] ?? $role->guard_name,
                'description' => $data['description'] ?? $role->description,
            ]);

            // Sync permissions if provided
            if (isset($data['permissions'])) {
                $this->permissionService->syncPermissionsToRole($role, $data['permissions']);
            }

            return $role->fresh();
        });
    }

    /**
     * Delete a role
     */
    public function deleteRole(Role $role): bool
    {
        // Prevent deleting system roles
        if ($role->is_system) {
            throw new \Exception('Cannot delete system roles');
        }

        return DB::transaction(function () use ($role) {
            // Remove role from all users
            DB::table('model_has_roles')
                ->where('role_id', $role->id)
                ->delete();

            $role->delete();
            return true;
        });
    }

    /**
     * Assign role to user
     */
    public function assignRoleToUser(Role $role, User $user): User
    {
        return DB::transaction(function () use ($role, $user) {
            if (!$user->hasRole($role->name)) {
                $user->assignRole($role);
            }

            return $user->fresh();
        });
    }

    /**
     * Revoke role from user
     */
    public function revokeRoleFromUser(Role $role, User $user): User
    {
        return DB::transaction(function () use ($role, $user) {
            $user->removeRole($role);
            return $user->fresh();
        });
    }

    /**
     * Sync roles to user
     */
    public function syncRolesToUser(User $user, array $roleIds): User
    {
        return DB::transaction(function () use ($user, $roleIds) {
            $roles = Role::whereIn('id', $roleIds)->get();
            $user->syncRoles($roles);
            return $user->fresh();
        });
    }

    /**
     * Get role with permissions
     */
    public function getRoleWithPermissions(Role $role): Role
    {
        return $role->load('permissions');
    }

    /**
     * Get users with role
     */
    public function getUsersWithRole(Role $role): Collection
    {
        return User::role($role->name)->active()->get();
    }

    /**
     * Search roles
     */
    public function searchRoles(string $term): Collection
    {
        return Role::where('name', 'like', "%{$term}%")
            ->orWhere('description', 'like', "%{$term}%")
            ->get();
    }

    /**
     * Get role statistics
     */
    public function getStatistics(): array
    {
        return [
            'total_roles' => Role::count(),
            'system_roles' => Role::system()->count(),
            'custom_roles' => Role::custom()->count(),
            'roles_with_user_count' => Role::withCount('users')
                ->pluck('users_count', 'name')
                ->toArray(),
        ];
    }

    /**
     * Clone a role
     */
    public function cloneRole(Role $role, string $newName): Role
    {
        return DB::transaction(function () use ($role, $newName) {
            $newRole = Role::create([
                'name' => $newName,
                'guard_name' => $role->guard_name,
                'description' => "Clone of {$role->name}",
                'is_system' => false,
            ]);

            // Copy all permissions
            $permissions = $role->permissions()->pluck('id')->toArray();
            $this->permissionService->syncPermissionsToRole($newRole, $permissions);

            return $newRole;
        });
    }

    /**
     * Check if role can be modified
     */
    public function canModifyRole(Role $role): bool
    {
        return !$role->is_system;
    }

    /**
     * Check if role can be deleted
     */
    public function canDeleteRole(Role $role): bool
    {
        return $this->canModifyRole($role);
    }
}
