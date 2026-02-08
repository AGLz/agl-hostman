<?php

namespace App\Http\Controllers\Api\Rbac;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Rbac\RbacService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class RbacController extends Controller
{
    public function __construct(
        private RbacService $rbacService
    ) {}

    /**
     * Get complete RBAC overview
     */
    public function overview(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->rbacService->getOverview(),
        ]);
    }

    /**
     * Get current user's RBAC summary
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated',
            ], 401);
        }

        return response()->json([
            'success' => true,
            'data' => $this->rbacService->getUserRbacSummary($user),
        ]);
    }

    /**
     * Get user's RBAC summary (for admins)
     */
    public function userSummary(Request $request, User $user): JsonResponse
    {
        if (!$request->user()->can('users.view')) {
            return response()->json([
                'success' => false,
                'message' => 'Forbidden',
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => $this->rbacService->getUserRbacSummary($user),
        ]);
    }

    /**
     * Grant role to user
     */
    public function grantRole(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'role' => 'required|string|exists:roles,name',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        if (!$request->user()->can('users.assign_roles')) {
            return response()->json([
                'success' => false,
                'message' => 'You do not have permission to assign roles',
            ], 403);
        }

        try {
            $user = User::findOrFail($request->user_id);
            $user = $this->rbacService->grantRoleToUser($request->role, $user);

            return response()->json([
                'success' => true,
                'message' => 'Role granted successfully',
                'data' => $user->load('roles'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to grant role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Revoke role from user
     */
    public function revokeRole(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'role' => 'required|string|exists:roles,name',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        if (!$request->user()->can('users.assign_roles')) {
            return response()->json([
                'success' => false,
                'message' => 'You do not have permission to revoke roles',
            ], 403);
        }

        try {
            $user = User::findOrFail($request->user_id);
            $user = $this->rbacService->revokeRoleFromUser($request->role, $user);

            return response()->json([
                'success' => true,
                'message' => 'Role revoked successfully',
                'data' => $user->load('roles'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to revoke role',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Grant permission to user
     */
    public function grantPermission(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'permission' => 'required|string|exists:permissions,name',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        if (!$request->user()->can('users.manage_permissions')) {
            return response()->json([
                'success' => false,
                'message' => 'You do not have permission to manage user permissions',
            ], 403);
        }

        try {
            $user = User::findOrFail($request->user_id);
            $user = $this->rbacService->grantPermissionToUser($request->permission, $user);

            return response()->json([
                'success' => true,
                'message' => 'Permission granted successfully',
                'data' => $user->load('permissions'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to grant permission',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Revoke permission from user
     */
    public function revokePermission(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'permission' => 'required|string|exists:permissions,name',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        if (!$request->user()->can('users.manage_permissions')) {
            return response()->json([
                'success' => false,
                'message' => 'You do not have permission to manage user permissions',
            ], 403);
        }

        try {
            $user = User::findOrFail($request->user_id);
            $user = $this->rbacService->revokePermissionFromUser($request->permission, $user);

            return response()->json([
                'success' => true,
                'message' => 'Permission revoked successfully',
                'data' => $user->load('permissions'),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to revoke permission',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get users with a specific role
     */
    public function usersWithRole(Request $request, string $role): JsonResponse
    {
        if (!$request->user()->can('users.view')) {
            return response()->json([
                'success' => false,
                'message' => 'Forbidden',
            ], 403);
        }

        $users = $this->rbacService->getUsersWithRole($role);

        return response()->json([
            'success' => true,
            'data' => $users,
        ]);
    }

    /**
     * Get users with a specific permission
     */
    public function usersWithPermission(Request $request, string $permission): JsonResponse
    {
        if (!$request->user()->can('users.view')) {
            return response()->json([
                'success' => false,
                'message' => 'Forbidden',
            ], 403);
        }

        $users = $this->rbacService->getUsersWithPermission($permission);

        return response()->json([
            'success' => true,
            'data' => $users,
        ]);
    }
}
