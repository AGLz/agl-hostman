<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\Permission;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;

class RolesController extends Controller
{
    public function __construct()
    {
        $this->middleware(['permission:roles.view']);
        $this->middleware(['permission:roles.create'])->only(['create', 'store']);
        $this->middleware(['permission:roles.edit'])->only(['edit', 'update']);
        $this->middleware(['permission:roles.delete'])->only(['destroy']);
    }

    /**
     * Display all roles
     */
    public function index(): View
    {
        $roles = Role::withCount('permissions', 'users')
            ->orderBy('is_system', 'desc')
            ->orderBy('name')
            ->paginate(20);

        return view('admin.roles.index', compact('roles'));
    }

    /**
     * Show form to create a new role
     */
    public function create(): View
    {
        $permissions = Permission::orderBy('module')->orderBy('name')->get();
        $modules = Permission::getModules();

        return view('admin.roles.create', compact('permissions', 'modules'));
    }

    /**
     * Store a new role
     */
    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string|max:255|unique:roles,name',
            'description' => 'nullable|string|max:500',
            'permissions' => 'array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        $role = Role::create([
            'name' => $request->name,
            'guard_name' => 'web',
            'description' => $request->description,
            'is_system' => false,
        ]);

        if ($request->has('permissions')) {
            $role->syncPermissions($request->permissions);
        }

        return redirect()
            ->route('admin.roles.index')
            ->with('success', "Role '{$role->name}' created successfully.");
    }

    /**
     * Show form to edit a role
     */
    public function edit(Role $role): View
    {
        $role->load('permissions');
        $permissions = Permission::orderBy('module')->orderBy('name')->get();
        $modules = Permission::getModules();
        $rolePermissionIds = $role->permissions->pluck('id')->toArray();

        return view('admin.roles.edit', compact(
            'role',
            'permissions',
            'modules',
            'rolePermissionIds'
        ));
    }

    /**
     * Update a role
     */
    public function update(Request $request, Role $role): RedirectResponse
    {
        if ($role->is_system) {
            return back()
                ->with('error', 'System roles cannot be modified.');
        }

        $request->validate([
            'name' => 'required|string|max:255|unique:roles,name,' . $role->id,
            'description' => 'nullable|string|max:500',
            'permissions' => 'array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        $role->update([
            'name' => $request->name,
            'description' => $request->description,
        ]);

        if ($request->has('permissions')) {
            $role->syncPermissions($request->permissions);
        } else {
            $role->syncPermissions([]);
        }

        return redirect()
            ->route('admin.roles.index')
            ->with('success', "Role '{$role->name}' updated successfully.");
    }

    /**
     * Delete a role
     */
    public function destroy(Role $role): RedirectResponse
    {
        if ($role->is_system) {
            return back()
                ->with('error', 'System roles cannot be deleted.');
        }

        $usersCount = $role->users()->count();
        if ($usersCount > 0) {
            return back()
                ->with('error', "Cannot delete role with {$usersCount} assigned users.");
        }

        $roleName = $role->name;
        $role->delete();

        return redirect()
            ->route('admin.roles.index')
            ->with('success', "Role '{$roleName}' deleted successfully.");
    }

    /**
     * Show role details
     */
    public function show(Role $role): View
    {
        $role->load(['permissions', 'users']);

        return view('admin.roles.show', compact('role'));
    }
}
