<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

/**
 * Role Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles role management operations (CRUD, permission assignment).
 * Requires 'manage-roles' or specific role permissions.
 */
class RoleController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
        $this->middleware('active');
        $this->middleware('permission:view-roles')->only(['index', 'show']);
        $this->middleware('permission:create-roles')->only(['create', 'store']);
        $this->middleware('permission:edit-roles')->only(['edit', 'update']);
        $this->middleware('permission:delete-roles')->only(['destroy']);
        $this->middleware('permission:assign-permissions')->only(['assignPermissions', 'revokePermissions']);
    }

    /**
     * Display a listing of roles
     *
     * @return View
     */
    public function index(): View
    {
        $roles = Role::withCount(['users', 'permissions'])
            ->orderBy('name')
            ->get();

        return view('roles.index', [
            'roles' => $roles,
        ]);
    }

    /**
     * Show the form for creating a new role
     *
     * @return View
     */
    public function create(): View
    {
        $permissions = Permission::orderBy('name')->get()->groupBy(function ($permission) {
            // Group by prefix (e.g., 'view-', 'create-', 'manage-')
            return explode('-', $permission->name)[0] ?? 'other';
        });

        return view('roles.create', [
            'permissions' => $permissions,
        ]);
    }

    /**
     * Store a newly created role
     *
     * @param Request $request
     * @return RedirectResponse
     */
    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:roles,name'],
            'permissions' => ['sometimes', 'array'],
            'permissions.*' => ['exists:permissions,name'],
        ]);

        DB::beginTransaction();

        try {
            // Create role
            $role = Role::create(['name' => $validated['name']]);

            // Assign permissions
            if (isset($validated['permissions'])) {
                $role->givePermissionTo($validated['permissions']);
            }

            // Log role creation
            AuditLog::record([
                'user_id' => Auth::id(),
                'event_type' => AuditLog::EVENT_ROLE_MANAGEMENT,
                'event_category' => 'role_created',
                'action' => 'create',
                'description' => "Role '{$role->name}' was created",
                'metadata' => [
                    'role_name' => $role->name,
                    'permissions_count' => count($validated['permissions'] ?? []),
                    'permissions' => $validated['permissions'] ?? [],
                ],
            ]);

            DB::commit();

            return redirect()->route('roles.show', $role)
                ->with('success', __('Role created successfully.'));

        } catch (\Exception $e) {
            DB::rollBack();

            return back()
                ->withInput()
                ->withErrors(['error' => __('Failed to create role: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Display the specified role
     *
     * @param Role $role
     * @return View
     */
    public function show(Role $role): View
    {
        $role->loadCount('users');
        $role->load('permissions');

        // Get users with this role
        $users = $role->users()->with('physicalLocations')->paginate(15);

        return view('roles.show', [
            'role' => $role,
            'users' => $users,
        ]);
    }

    /**
     * Show the form for editing the specified role
     *
     * @param Role $role
     * @return View
     */
    public function edit(Role $role): View
    {
        // Prevent editing system roles
        if (in_array($role->name, ['super-admin', 'admin'])) {
            abort(403, 'Cannot edit system roles');
        }

        $permissions = Permission::orderBy('name')->get()->groupBy(function ($permission) {
            return explode('-', $permission->name)[0] ?? 'other';
        });

        $role->load('permissions');

        return view('roles.edit', [
            'role' => $role,
            'permissions' => $permissions,
        ]);
    }

    /**
     * Update the specified role
     *
     * @param Request $request
     * @param Role $role
     * @return RedirectResponse
     */
    public function update(Request $request, Role $role): RedirectResponse
    {
        // Prevent editing system roles
        if (in_array($role->name, ['super-admin', 'admin'])) {
            return back()->withErrors(['error' => __('Cannot edit system roles')]);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255', 'unique:roles,name,' . $role->id],
            'permissions' => ['sometimes', 'array'],
            'permissions.*' => ['exists:permissions,name'],
        ]);

        DB::beginTransaction();

        try {
            $oldValues = [
                'name' => $role->name,
                'permissions' => $role->permissions->pluck('name')->toArray(),
            ];

            // Update role name if provided
            if (isset($validated['name'])) {
                $role->update(['name' => $validated['name']]);
            }

            // Sync permissions if provided
            if (isset($validated['permissions'])) {
                $role->syncPermissions($validated['permissions']);
            }

            // Log role update
            AuditLog::record([
                'user_id' => Auth::id(),
                'event_type' => AuditLog::EVENT_ROLE_MANAGEMENT,
                'event_category' => 'role_updated',
                'action' => 'update',
                'description' => "Role '{$role->name}' was updated",
                'metadata' => [
                    'role_name' => $role->name,
                    'old_values' => $oldValues,
                    'new_permissions' => $validated['permissions'] ?? [],
                ],
            ]);

            DB::commit();

            return redirect()->route('roles.show', $role)
                ->with('success', __('Role updated successfully.'));

        } catch (\Exception $e) {
            DB::rollBack();

            return back()
                ->withInput()
                ->withErrors(['error' => __('Failed to update role: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Remove the specified role
     *
     * @param Role $role
     * @return RedirectResponse
     */
    public function destroy(Role $role): RedirectResponse
    {
        // Prevent deletion of system roles
        if (in_array($role->name, ['super-admin', 'admin', 'operator', 'analyst', 'viewer'])) {
            return back()->withErrors(['error' => __('Cannot delete system roles')]);
        }

        // Check if role has users
        if ($role->users()->count() > 0) {
            return back()->withErrors(['error' => __('Cannot delete role with assigned users. Please reassign users first.')]);
        }

        DB::beginTransaction();

        try {
            $roleData = [
                'name' => $role->name,
                'permissions' => $role->permissions->pluck('name')->toArray(),
            ];

            // Log role deletion
            AuditLog::record([
                'user_id' => Auth::id(),
                'event_type' => AuditLog::EVENT_ROLE_MANAGEMENT,
                'event_category' => 'role_deleted',
                'action' => 'delete',
                'description' => "Role '{$role->name}' was deleted",
                'metadata' => $roleData,
            ]);

            $role->delete();

            DB::commit();

            return redirect()->route('roles.index')
                ->with('success', __('Role deleted successfully.'));

        } catch (\Exception $e) {
            DB::rollBack();

            return back()
                ->withErrors(['error' => __('Failed to delete role: :message', ['message' => $e->getMessage()])]);
        }
    }
}
