<?php

namespace App\Repositories;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

/**
 * User Repository
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles all user-related database operations with permission checks,
 * audit logging, and business rule validation.
 */
class UserRepository
{
    /**
     * Get all users with optional filters
     */
    public function getAllUsers(array $filters = [], int $perPage = 15): LengthAwarePaginator
    {
        $query = User::query()->with(['roles', 'physicalLocations']);

        // Filter by active status
        if (isset($filters['is_active'])) {
            $query->where('is_active', $filters['is_active']);
        }

        // Filter by role
        if (isset($filters['role'])) {
            $query->role($filters['role']);
        }

        // Search by name or email
        if (isset($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        // Filter by location
        if (isset($filters['location_code'])) {
            $query->whereHas('physicalLocations', function ($q) use ($filters) {
                $q->where('code', $filters['location_code']);
            });
        }

        // Sort by
        $sortBy = $filters['sort_by'] ?? 'created_at';
        $sortOrder = $filters['sort_order'] ?? 'desc';
        $query->orderBy($sortBy, $sortOrder);

        return $query->paginate($perPage);
    }

    /**
     * Get active users only
     */
    public function getActiveUsers(): Collection
    {
        return User::active()->with('roles')->get();
    }

    /**
     * Find user by ID with relationships
     */
    public function findById(int $userId): ?User
    {
        return User::with(['roles', 'permissions', 'physicalLocations'])->find($userId);
    }

    /**
     * Find user by email
     */
    public function findByEmail(string $email): ?User
    {
        return User::where('email', $email)->first();
    }

    /**
     * Create new user with role assignment
     *
     * @throws \Exception
     */
    public function createUser(array $data, User $creator): User
    {
        DB::beginTransaction();

        try {
            // Create user
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
                'is_active' => $data['is_active'] ?? true,
                'avatar_url' => $data['avatar_url'] ?? null,
            ]);

            // Assign role if provided
            if (isset($data['role'])) {
                $user->assignRole($data['role']);
            }

            // Assign locations if provided
            if (isset($data['locations'])) {
                foreach ($data['locations'] as $locationData) {
                    $user->physicalLocations()->attach($locationData['id'], [
                        'access_level' => $locationData['access_level'] ?? 'view',
                        'is_primary' => $locationData['is_primary'] ?? false,
                    ]);
                }
            }

            // Log user creation
            AuditLog::logUserManagement($creator, $user, 'user_created', [
                'role' => $data['role'] ?? null,
                'is_active' => $user->is_active,
                'locations_count' => $user->physicalLocations()->count(),
            ]);

            DB::commit();

            return $user->load(['roles', 'physicalLocations']);

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Update user information
     *
     * @throws \Exception
     */
    public function updateUser(User $user, array $data, User $updater): User
    {
        DB::beginTransaction();

        try {
            $oldValues = $user->toArray();

            // Update basic fields
            $updateData = [];

            if (isset($data['name'])) {
                $updateData['name'] = $data['name'];
            }

            if (isset($data['email'])) {
                $updateData['email'] = $data['email'];
            }

            if (isset($data['password'])) {
                $updateData['password'] = Hash::make($data['password']);
            }

            if (isset($data['avatar_url'])) {
                $updateData['avatar_url'] = $data['avatar_url'];
            }

            $user->update($updateData);

            // Update locations if provided
            if (isset($data['locations'])) {
                $user->physicalLocations()->detach();
                foreach ($data['locations'] as $locationData) {
                    $user->physicalLocations()->attach($locationData['id'], [
                        'access_level' => $locationData['access_level'] ?? 'view',
                        'is_primary' => $locationData['is_primary'] ?? false,
                    ]);
                }
            }

            // Log user update
            AuditLog::logUserManagement($updater, $user, 'user_updated', [
                'old_values' => $oldValues,
                'new_values' => $user->fresh()->toArray(),
                'fields_changed' => array_keys($updateData),
            ]);

            DB::commit();

            return $user->fresh(['roles', 'physicalLocations']);

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Delete user
     *
     * @throws \Exception
     */
    public function deleteUser(User $user, User $deleter): bool
    {
        // Prevent self-deletion
        if ($user->id === $deleter->id) {
            throw new \Exception('You cannot delete your own account');
        }

        // Prevent deletion of last super admin
        if ($user->isSuperAdmin()) {
            $superAdminCount = User::role('super-admin')->active()->count();
            if ($superAdminCount <= 1) {
                throw new \Exception('Cannot delete the last super admin');
            }
        }

        DB::beginTransaction();

        try {
            $userData = $user->toArray();

            // Log deletion before removing
            AuditLog::logUserManagement($deleter, $user, 'user_deleted', [
                'user_data' => $userData,
                'roles' => $user->roles->pluck('name')->toArray(),
                'permissions' => $user->getAllPermissions()->pluck('name')->toArray(),
            ]);

            // Delete user
            $user->delete();

            DB::commit();

            return true;

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Activate user account
     */
    public function activateUser(User $user, User $activator): User
    {
        if ($user->is_active) {
            throw new \Exception('User is already active');
        }

        $user->activate();

        AuditLog::logUserManagement($activator, $user, 'user_activated', [
            'activated_at' => now()->toDateTimeString(),
        ]);

        return $user;
    }

    /**
     * Deactivate user account
     *
     * @throws \Exception
     */
    public function deactivateUser(User $user, User $deactivator): User
    {
        // Prevent self-deactivation
        if ($user->id === $deactivator->id) {
            throw new \Exception('You cannot deactivate your own account');
        }

        // Prevent deactivation of last super admin
        if ($user->isSuperAdmin()) {
            $superAdminCount = User::role('super-admin')->active()->count();
            if ($superAdminCount <= 1) {
                throw new \Exception('Cannot deactivate the last super admin');
            }
        }

        if (! $user->is_active) {
            throw new \Exception('User is already inactive');
        }

        $user->deactivate();

        AuditLog::logUserManagement($deactivator, $user, 'user_deactivated', [
            'deactivated_at' => now()->toDateTimeString(),
            'reason' => 'Manual deactivation',
        ]);

        return $user;
    }

    /**
     * Assign role to user
     *
     * @throws \Exception
     */
    public function assignRole(User $user, string|Role $role, User $assigner): User
    {
        DB::beginTransaction();

        try {
            $roleName = is_string($role) ? $role : $role->name;
            $oldRoles = $user->roles->pluck('name')->toArray();

            // Remove existing roles and assign new one
            $user->syncRoles([$roleName]);

            // Log role assignment
            AuditLog::logPermissionChange($assigner, $user, 'role_assigned', [
                'old_roles' => $oldRoles,
                'new_role' => $roleName,
            ]);

            DB::commit();

            return $user->fresh('roles');

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Remove role from user
     *
     * @throws \Exception
     */
    public function removeRole(User $user, string|Role $role, User $remover): User
    {
        // Prevent removing super-admin from last super admin
        $roleName = is_string($role) ? $role : $role->name;

        if ($roleName === 'super-admin') {
            $superAdminCount = User::role('super-admin')->active()->count();
            if ($superAdminCount <= 1 && $user->isSuperAdmin()) {
                throw new \Exception('Cannot remove super-admin role from the last super admin');
            }
        }

        DB::beginTransaction();

        try {
            $user->removeRole($role);

            // Log role removal
            AuditLog::logPermissionChange($remover, $user, 'role_removed', [
                'removed_role' => $roleName,
                'remaining_roles' => $user->fresh('roles')->roles->pluck('name')->toArray(),
            ]);

            DB::commit();

            return $user->fresh('roles');

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Give permission directly to user
     */
    public function givePermission(User $user, string|Permission $permission, User $granter): User
    {
        DB::beginTransaction();

        try {
            $permissionName = is_string($permission) ? $permission : $permission->name;

            $user->givePermissionTo($permission);

            // Log permission grant
            AuditLog::logPermissionChange($granter, $user, 'permission_granted', [
                'permission' => $permissionName,
            ]);

            DB::commit();

            return $user->fresh('permissions');

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Revoke permission from user
     */
    public function revokePermission(User $user, string|Permission $permission, User $revoker): User
    {
        DB::beginTransaction();

        try {
            $permissionName = is_string($permission) ? $permission : $permission->name;

            $user->revokePermissionTo($permission);

            // Log permission revocation
            AuditLog::logPermissionChange($revoker, $user, 'permission_revoked', [
                'permission' => $permissionName,
            ]);

            DB::commit();

            return $user->fresh('permissions');

        } catch (\Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Get users by role
     */
    public function getUsersByRole(string $role): Collection
    {
        return User::role($role)->with('roles')->get();
    }

    /**
     * Get users by permission
     */
    public function getUsersByPermission(string $permission): Collection
    {
        return User::permission($permission)->with(['roles', 'permissions'])->get();
    }

    /**
     * Get user's activity statistics
     */
    public function getUserActivityStats(User $user, int $days = 30): array
    {
        $startDate = now()->subDays($days);

        return [
            'total_actions' => $user->auditLogs()->where('created_at', '>=', $startDate)->count(),
            'last_login' => $user->last_login_at?->diffForHumans(),
            'failed_logins' => $user->auditLogs()
                ->where('event_type', AuditLog::EVENT_AUTH)
                ->where('status', AuditLog::STATUS_FAILED)
                ->where('created_at', '>=', $startDate)
                ->count(),
            'infrastructure_actions' => $user->auditLogs()
                ->where('event_type', AuditLog::EVENT_INFRASTRUCTURE)
                ->where('created_at', '>=', $startDate)
                ->count(),
            'security_events' => $user->auditLogs()
                ->where('event_type', AuditLog::EVENT_SECURITY)
                ->where('created_at', '>=', $startDate)
                ->count(),
        ];
    }

    /**
     * Check if user can perform action on target user
     */
    public function canPerformAction(User $actor, User $target, string $action): bool
    {
        // Super admin can do anything
        if ($actor->isSuperAdmin()) {
            return true;
        }

        // Cannot perform actions on self for destructive operations
        if ($actor->id === $target->id && in_array($action, ['delete', 'deactivate'])) {
            return false;
        }

        // Cannot perform actions on super admins unless you are one
        if ($target->isSuperAdmin() && ! $actor->isSuperAdmin()) {
            return false;
        }

        // Check specific permissions
        return match ($action) {
            'view' => $actor->hasPermissionTo('view-users'),
            'create' => $actor->hasPermissionTo('create-users'),
            'edit' => $actor->hasPermissionTo('edit-users'),
            'delete' => $actor->hasPermissionTo('delete-users'),
            'activate', 'deactivate' => $actor->hasPermissionTo('activate-deactivate-users'),
            'assign_role' => $actor->hasPermissionTo('assign-roles'),
            'manage' => $actor->hasPermissionTo('manage-users'),
            default => false,
        };
    }

    /**
     * Validate business rules for user operations
     *
     * @return array ['valid' => bool, 'errors' => array]
     */
    public function validateBusinessRules(string $operation, ?User $user = null, array $data = []): array
    {
        $errors = [];

        switch ($operation) {
            case 'create':
                // Check email uniqueness
                if (User::where('email', $data['email'] ?? null)->exists()) {
                    $errors[] = 'Email already exists';
                }
                break;

            case 'update':
                // Check email uniqueness (excluding current user)
                if (isset($data['email']) && $user) {
                    $exists = User::where('email', $data['email'])
                        ->where('id', '!=', $user->id)
                        ->exists();
                    if ($exists) {
                        $errors[] = 'Email already exists';
                    }
                }
                break;

            case 'delete':
                // Prevent deletion of last super admin
                if ($user && $user->isSuperAdmin()) {
                    $count = User::role('super-admin')->active()->count();
                    if ($count <= 1) {
                        $errors[] = 'Cannot delete the last super admin';
                    }
                }
                break;

            case 'deactivate':
                // Prevent deactivation of last super admin
                if ($user && $user->isSuperAdmin()) {
                    $count = User::role('super-admin')->active()->count();
                    if ($count <= 1) {
                        $errors[] = 'Cannot deactivate the last super admin';
                    }
                }
                break;
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
        ];
    }
}
