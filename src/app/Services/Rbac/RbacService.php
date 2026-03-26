<?php

namespace App\Services\Rbac;

use App\Models\User;
use Illuminate\Support\Collection;

class RbacService
{
    public function __construct(
        protected RoleService $roleService,
        protected PermissionService $permissionService
    ) {}

    /**
     * Get complete RBAC overview
     */
    public function getOverview(): array
    {
        return [
            'statistics' => [
                'roles' => $this->roleService->getStatistics(),
                'permissions' => $this->permissionService->getStatistics(),
            ],
            'system_roles' => $this->roleService->getSystemRoles(),
            'modules' => $this->permissionService->getAvailableModules(),
        ];
    }

    /**
     * Get user's RBAC summary
     */
    public function getUserRbacSummary(User $user): array
    {
        return [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_active' => $user->isActive(),
            ],
            'roles' => $user->roles->map(fn ($role) => [
                'name' => $role->name,
                'description' => $role->description,
                'is_system' => $role->is_system,
            ]),
            'permissions' => [
                'direct' => $user->getDirectPermissions()->pluck('name'),
                'via_roles' => $user->getAllPermissions()->pluck('name'),
                'all' => $user->getAllPermissions()->pluck('name')->unique()->values(),
            ],
            'abilities' => [
                'is_super_admin' => $user->isSuperAdmin(),
                'can_manage_users' => $user->canManageUsers(),
                'can_manage_roles' => $user->canManageRoles(),
                'can_access_dashboard' => $user->canAccessDashboard(),
            ],
        ];
    }

    /**
     * Grant role to user
     */
    public function grantRoleToUser(string $roleName, User $user): User
    {
        $role = \Spatie\Permission\Models\Role::findByName($roleName);

        return $this->roleService->assignRoleToUser($role, $user);
    }

    /**
     * Revoke role from user
     */
    public function revokeRoleFromUser(string $roleName, User $user): User
    {
        $role = \Spatie\Permission\Models\Role::findByName($roleName);

        return $this->roleService->revokeRoleFromUser($role, $user);
    }

    /**
     * Grant permission to user
     */
    public function grantPermissionToUser(string $permissionName, User $user): User
    {
        $permission = \Spatie\Permission\Models\Permission::findByName($permissionName);

        return $this->permissionService->assignPermissionToUser($permission, $user);
    }

    /**
     * Revoke permission from user
     */
    public function revokePermissionFromUser(string $permissionName, User $user): User
    {
        $permission = \Spatie\Permission\Models\Permission::findByName($permissionName);

        return $this->permissionService->revokePermissionFromUser($permission, $user);
    }

    /**
     * Check if user has any of the specified permissions
     */
    public function userHasAnyPermission(User $user, array $permissions): bool
    {
        return $user->hasAnyPermission($permissions);
    }

    /**
     * Check if user has all specified permissions
     */
    public function userHasAllPermissions(User $user, array $permissions): bool
    {
        return $user->hasAllPermissions($permissions);
    }

    /**
     * Check if user has any of the specified roles
     */
    public function userHasAnyRole(User $user, array $roles): bool
    {
        return $user->hasAnyRole($roles);
    }

    /**
     * Get all users with a specific role
     */
    public function getUsersWithRole(string $roleName): Collection
    {
        return User::role($roleName)->active()->get();
    }

    /**
     * Get all users with a specific permission
     */
    public function getUsersWithPermission(string $permissionName): Collection
    {
        return User::permission($permissionName)->active()->get();
    }

    /**
     * Initialize default RBAC structure
     */
    public function initializeDefaults(): void
    {
        // This would typically be called from a seeder or migration
        \Database\Seeders\RbacSeeder::class;
    }
}
