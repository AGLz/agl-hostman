<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class UserRoleController extends Controller
{
    public function __construct()
    {
        $this->middleware(['permission:users.view']);
        $this->middleware(['permission:users.assign_roles'])->only(['editRoles', 'updateRoles']);
        $this->middleware(['permission:users.manage_permissions'])->only(['editPermissions', 'updatePermissions']);
    }

    /**
     * Show form to manage user roles
     */
    public function editRoles(User $user): View
    {
        $user->load('roles');
        $roles = Role::orderBy('is_system', 'desc')->orderBy('name')->get();
        $userRoleIds = $user->roles->pluck('id')->toArray();

        return view('admin.users.roles', compact('user', 'roles', 'userRoleIds'));
    }

    /**
     * Update user roles
     */
    public function updateRoles(Request $request, User $user): RedirectResponse
    {
        $request->validate([
            'roles' => 'array',
            'roles.*' => 'exists:roles,id',
        ]);

        $roles = $request->roles ?? [];
        $user->syncRoles($roles);

        return back()->with('success', 'User roles updated successfully.');
    }

    /**
     * Show form to manage direct user permissions
     */
    public function editPermissions(User $user): View
    {
        $user->load('permissions');
        $permissions = Permission::orderBy('module')->orderBy('name')->get();
        $modules = Permission::getModules();
        $userPermissionIds = $user->permissions->pluck('id')->toArray();

        return view('admin.users.permissions', compact(
            'user',
            'permissions',
            'modules',
            'userPermissionIds'
        ));
    }

    /**
     * Update user direct permissions
     */
    public function updatePermissions(Request $request, User $user): RedirectResponse
    {
        $request->validate([
            'permissions' => 'array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        $permissions = $request->permissions ?? [];

        // Sync direct permissions (not through roles)
        $user->syncPermissions($permissions);

        return back()->with('success', 'User permissions updated successfully.');
    }

    /**
     * Show user access summary
     */
    public function showAccess(User $user): View
    {
        $user->load(['roles', 'permissions', 'roles.permissions']);

        // Get all permissions (from roles + direct)
        $allPermissions = $user->getAllPermissions();

        // Group by module
        $permissionsByModule = $allPermissions->groupBy('module');

        return view('admin.users.access', compact(
            'user',
            'permissionsByModule',
            'allPermissions'
        ));
    }

    /**
     * Remove a specific role from user
     */
    public function removeRole(User $user, Role $role): RedirectResponse
    {
        $user->removeRole($role);

        return back()
            ->with('success', "Role '{$role->name}' removed from user.");
    }

    /**
     * Remove a specific direct permission from user
     */
    public function removePermission(User $user, Permission $permission): RedirectResponse
    {
        $user->revokePermissionTo($permission);

        return back()
            ->with('success', "Direct permission '{$permission->name}' removed from user.");
    }
}
