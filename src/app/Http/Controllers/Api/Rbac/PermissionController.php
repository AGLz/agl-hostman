<?php

namespace App\Http\Controllers\Api\Rbac;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use App\Services\Rbac\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class PermissionController extends Controller
{
    public function __construct(
        private PermissionService $permissionService
    ) {}

    /**
     * List all permissions
     */
    public function index(Request $request): JsonResponse
    {
        $query = Permission::query();

        if ($request->has('search')) {
            $query->where('name', 'like', '%'.$request->search.'%')
                ->orWhere('description', 'like', '%'.$request->search.'%')
                ->orWhere('module', 'like', '%'.$request->search.'%');
        }

        if ($request->has('module')) {
            $query->byModule($request->module);
        }

        $permissions = $query->withCount('roles')
            ->orderBy('module')
            ->orderBy('name')
            ->paginate($request->per_page ?? 50);

        return response()->json([
            'success' => true,
            'data' => $permissions,
        ]);
    }

    /**
     * Get permissions grouped by module
     */
    public function grouped(): JsonResponse
    {
        $permissions = $this->permissionService->getPermissionsGroupedByModule();

        return response()->json([
            'success' => true,
            'data' => $permissions,
        ]);
    }

    /**
     * Get available modules
     */
    public function modules(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->permissionService->getAvailableModules(),
        ]);
    }

    /**
     * Get permission details
     */
    public function show(Permission $permission): JsonResponse
    {
        $permission->load('roles', 'users');

        return response()->json([
            'success' => true,
            'data' => $permission,
        ]);
    }

    /**
     * Create a new permission
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|unique:permissions,name',
            'guard_name' => 'string|max:255',
            'module' => 'nullable|string|max:255',
            'description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $permission = $this->permissionService->createPermission($request->all());

            return response()->json([
                'success' => true,
                'message' => 'Permission created successfully',
                'data' => $permission,
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create permission',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update a permission
     */
    public function update(Request $request, Permission $permission): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'string|max:255|unique:permissions,name,'.$permission->id,
            'guard_name' => 'string|max:255',
            'module' => 'nullable|string|max:255',
            'description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $permission = $this->permissionService->updatePermission($permission, $request->all());

            return response()->json([
                'success' => true,
                'message' => 'Permission updated successfully',
                'data' => $permission,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update permission',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete a permission
     */
    public function destroy(Permission $permission): JsonResponse
    {
        try {
            $this->permissionService->deletePermission($permission);

            return response()->json([
                'success' => true,
                'message' => 'Permission deleted successfully',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete permission',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Assign permission to role
     */
    public function assignToRole(Request $request, Permission $permission): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'role_id' => 'required|exists:roles,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $role = Role::findOrFail($request->role_id);
            $role = $this->permissionService->assignPermissionToRole($permission, $role);

            return response()->json([
                'success' => true,
                'message' => 'Permission assigned to role successfully',
                'data' => $role->load('permissions'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to assign permission to role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Revoke permission from role
     */
    public function revokeFromRole(Request $request, Permission $permission): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'role_id' => 'required|exists:roles,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $role = Role::findOrFail($request->role_id);
            $role = $this->permissionService->revokePermissionFromRole($permission, $role);

            return response()->json([
                'success' => true,
                'message' => 'Permission revoked from role successfully',
                'data' => $role->load('permissions'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to revoke permission from role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Assign permission directly to user
     */
    public function assignToUser(Request $request, Permission $permission): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $user = User::findOrFail($request->user_id);
            $user = $this->permissionService->assignPermissionToUser($permission, $user);

            return response()->json([
                'success' => true,
                'message' => 'Permission assigned to user successfully',
                'data' => $user->load('permissions', 'roles'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to assign permission to user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get permission statistics
     */
    public function statistics(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->permissionService->getStatistics(),
        ]);
    }
}
