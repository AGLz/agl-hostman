<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class PermissionsController extends Controller
{
    /**
     * Display all permissions grouped by module
     */
    public function index(Request $request): View
    {
        $search = $request->get('search');
        $module = $request->get('module');

        $query = Permission::withCount('roles');

        if ($search) {
            $query->search($search);
        }

        if ($module) {
            $query->byModule($module);
        }

        $permissions = $query->orderBy('module')->orderBy('name')->paginate(50);
        $modules = Permission::getModules();

        return view('admin.permissions.index', compact('permissions', 'modules', 'search', 'module'));
    }

    /**
     * Show form to create a new permission
     */
    public function create(): View
    {
        $modules = Permission::getModules();

        return view('admin.permissions.create', compact('modules'));
    }

    /**
     * Store a new permission
     */
    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'module' => 'required|string|max:50',
            'description' => 'nullable|string|max:500',
        ]);

        $permissionName = $request->module.'.'.$request->name;

        $existing = Permission::where('name', $permissionName)->first();
        if ($existing) {
            return back()
                ->withInput()
                ->with('error', "Permission '{$permissionName}' already exists.");
        }

        Permission::create([
            'name' => $permissionName,
            'guard_name' => 'web',
            'module' => $request->module,
            'description' => $request->description,
        ]);

        return redirect()
            ->route('admin.permissions.index')
            ->with('success', "Permission '{$permissionName}' created successfully.");
    }

    /**
     * Show form to edit a permission
     */
    public function edit(Permission $permission): View
    {
        $modules = Permission::getModules();

        return view('admin.permissions.edit', compact('permission', 'modules'));
    }

    /**
     * Update a permission
     */
    public function update(Request $request, Permission $permission): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'module' => 'required|string|max:50',
            'description' => 'nullable|string|max:500',
        ]);

        $newPermissionName = $request->module.'.'.$request->name;

        $existing = Permission::where('name', $newPermissionName)
            ->where('id', '!=', $permission->id)
            ->first();

        if ($existing) {
            return back()
                ->withInput()
                ->with('error', "Permission '{$newPermissionName}' already exists.");
        }

        $permission->update([
            'name' => $newPermissionName,
            'module' => $request->module,
            'description' => $request->description,
        ]);

        return redirect()
            ->route('admin.permissions.index')
            ->with('success', "Permission '{$newPermissionName}' updated successfully.");
    }

    /**
     * Delete a permission
     */
    public function destroy(Permission $permission): RedirectResponse
    {
        $rolesCount = $permission->roles()->count();

        if ($rolesCount > 0) {
            return back()
                ->with('error', "Cannot delete permission assigned to {$rolesCount} role(s).");
        }

        $permissionName = $permission->name;
        $permission->delete();

        return redirect()
            ->route('admin.permissions.index')
            ->with('success', "Permission '{$permissionName}' deleted successfully.");
    }
}
