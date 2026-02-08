<?php

namespace App\Http\Controllers\Api\Rbac;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Services\Rbac\RoleService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;

class RoleController extends Controller
{
    public function __construct(
        private RoleService $roleService
    ) {}

    /**
     * List all roles
     */
    public function index(Request $request): JsonResponse
    {
        $query = Role::query();

        if ($request->has('search')) {
            $query->where('name', 'like', '%' . $request->search . '%')
                ->orWhere('description', 'like', '%' . $request->search . '%');
        }

        if ($request->has('type')) {
            if ($request->type === 'system') {
                $query->system();
            } elseif ($request->type === 'custom') {
                $query->custom();
            }
        }

        $roles = $query->with('permissions')
            ->withCount('users')
            ->orderBy('is_system', 'desc')
            ->orderBy('name')
            ->paginate($request->per_page ?? 20);

        return response()->json([
            'success' => true,
            'data' => $roles,
        ]);
    }

    /**
     * Get role details
     */
    public function show(Role $role): JsonResponse
    {
        $role->load('permissions', 'users');

        return response()->json([
            'success' => true,
            'data' => $role,
        ]);
    }

    /**
     * Create a new role
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|unique:roles,name',
            'guard_name' => 'string|max:255',
            'description' => 'nullable|string',
            'permissions' => 'array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $role = $this->roleService->createRole($request->all());

            return response()->json([
                'success' => true,
                'message' => 'Role created successfully',
                'data' => $role->load('permissions'),
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Update a role
     */
    public function update(Request $request, Role $role): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'string|max:255|unique:roles,name,' . $role->id,
            'guard_name' => 'string|max:255',
            'description' => 'nullable|string',
            'permissions' => 'array',
            'permissions.*' => 'exists:permissions,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        if (!$this->roleService->canModifyRole($role)) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot modify system roles',
            ], 403);
        }

        try {
            $role = $this->roleService->updateRole($role, $request->all());

            return response()->json([
                'success' => true,
                'message' => 'Role updated successfully',
                'data' => $role->load('permissions'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete a role
     */
    public function destroy(Role $role): JsonResponse
    {
        if (!$this->roleService->canDeleteRole($role)) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot delete system roles',
            ], 403);
        }

        try {
            $this->roleService->deleteRole($role);

            return response()->json([
                'success' => true,
                'message' => 'Role deleted successfully',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Assign role to user
     */
    public function assignToUser(Request $request, Role $role): JsonResponse
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
            $user = $this->roleService->assignRoleToUser($role, $user);

            return response()->json([
                'success' => true,
                'message' => 'Role assigned to user successfully',
                'data' => $user->load('roles'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to assign role to user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Revoke role from user
     */
    public function revokeFromUser(Request $request, Role $role): JsonResponse
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
            $user = $this->roleService->revokeRoleFromUser($role, $user);

            return response()->json([
                'success' => true,
                'message' => 'Role revoked from user successfully',
                'data' => $user->load('roles'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to revoke role from user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get role statistics
     */
    public function statistics(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->roleService->getStatistics(),
        ]);
    }

    /**
     * Clone a role
     */
    public function clone(Request $request, Role $role): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|unique:roles,name',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $newRole = $this->roleService->cloneRole($role, $request->name);

            return response()->json([
                'success' => true,
                'message' => 'Role cloned successfully',
                'data' => $newRole->load('permissions'),
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to clone role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}
