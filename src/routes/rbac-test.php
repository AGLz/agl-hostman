<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| RBAC Test Routes
|--------------------------------------------------------------------------
|
| These routes test the CheckRole and CheckPermission middleware.
| Create a test user via Tinker and assign roles to test.
|
| Usage:
|   - Create test user: User::factory()->create(['email' => 'admin@test.com']);
|   - Assign role: User::first()->assignRole('admin');
|   - Login: Auth::login(User::first());
|   - Test routes below
*/

Route::prefix('rbac-test')->middleware(['web'])->group(function () {

    // Test: Public route (no auth required)
    Route::get('/public', function () {
        return response()->json([
            'message' => 'Public route - No authentication required',
            'authenticated' => auth()->check(),
            'user' => auth()->user()?->only(['id', 'name', 'email']),
        ]);
    });

    // Test: Authenticated route
    Route::get('/authenticated', function () {
        return response()->json([
            'message' => 'Authenticated route',
            'user' => auth()->user()->only(['id', 'name', 'email', 'is_active']),
            'roles' => auth()->user()->roles->pluck('name'),
            'permissions' => auth()->user()->getAllPermissions()->pluck('name'),
        ]);
    })->middleware('auth:sanctum');

    // Test: Role middleware - Admin only
    Route::get('/admin-only', function () {
        return response()->json([
            'message' => 'Admin only route',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'role:admin']);

    // Test: Role middleware - Multiple roles with "any" logic
    Route::get('/admin-or-operator', function () {
        return response()->json([
            'message' => 'Admin OR Operator route',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'role:admin,operator|any']);

    // Test: Role middleware - Multiple roles with "all" logic
    Route::get('/admin-and-analyst', function () {
        return response()->json([
            'message' => 'Admin AND Analyst route (must have both)',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'role:admin,analyst|all']);

    // Test: Permission middleware - View dashboard
    Route::get('/view-dashboard', function () {
        return response()->json([
            'message' => 'View dashboard permission required',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'permissions' => auth()->user()->getAllPermissions()->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'permission:view-dashboard']);

    // Test: Permission middleware - Multiple permissions with "any"
    Route::get('/view-or-manage-infrastructure', function () {
        return response()->json([
            'message' => 'View OR Manage infrastructure permission',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'permissions' => auth()->user()->getAllPermissions()->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'permission:view-infrastructure,manage-infrastructure|any']);

    // Test: Permission middleware - Multiple permissions with "all"
    Route::get('/manage-users-and-roles', function () {
        return response()->json([
            'message' => 'Manage users AND roles permission (must have both)',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'permissions' => auth()->user()->getAllPermissions()->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'permission:manage-users,manage-roles|all']);

    // Test: Active user middleware
    Route::get('/active-users-only', function () {
        return response()->json([
            'message' => 'Active users only',
            'user' => auth()->user()->only(['id', 'name', 'email', 'is_active']),
        ]);
    })->middleware(['auth:sanctum', 'active']);

    // Test: Combined - Role + Permission
    Route::get('/admin-with-manage-infrastructure', function () {
        return response()->json([
            'message' => 'Admin role WITH manage-infrastructure permission',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
            'permissions' => auth()->user()->getAllPermissions()->pluck('name'),
        ]);
    })->middleware(['auth:sanctum', 'role:admin', 'permission:manage-infrastructure']);

    // Test: Super Admin access
    Route::get('/super-admin-only', function () {
        return response()->json([
            'message' => 'Super Admin only route',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
            'all_permissions' => auth()->user()->getAllPermissions()->count() . ' permissions',
        ]);
    })->middleware(['auth:sanctum', 'role:super-admin']);

    // Helper: Create test user with role
    Route::post('/create-test-user', function (Illuminate\Http\Request $request) {
        $user = \App\Models\User::factory()->create([
            'email' => $request->input('email', 'test@example.com'),
            'name' => $request->input('name', 'Test User'),
            'is_active' => true,
        ]);

        if ($request->has('role')) {
            $user->assignRole($request->input('role'));
        }

        return response()->json([
            'message' => 'Test user created',
            'user' => $user->only(['id', 'name', 'email']),
            'roles' => $user->roles->pluck('name'),
            'api_token' => $user->createToken('test-token')->plainTextToken,
        ]);
    });

    // Helper: Login test user
    Route::post('/login-test-user', function (Illuminate\Http\Request $request) {
        $user = \App\Models\User::where('email', $request->input('email'))->firstOrFail();

        $token = $user->createToken('test-token')->plainTextToken;

        return response()->json([
            'message' => 'User logged in',
            'user' => $user->only(['id', 'name', 'email', 'is_active']),
            'roles' => $user->roles->pluck('name'),
            'permissions' => $user->getAllPermissions()->pluck('name'),
            'api_token' => $token,
            'usage' => 'Add header: Authorization: Bearer ' . $token,
        ]);
    });

    // Helper: List all roles and permissions
    Route::get('/list-roles-permissions', function () {
        return response()->json([
            'roles' => \Spatie\Permission\Models\Role::with('permissions')->get()->map(function ($role) {
                return [
                    'name' => $role->name,
                    'permissions' => $role->permissions->pluck('name'),
                    'permissions_count' => $role->permissions->count(),
                ];
            }),
            'all_permissions' => \Spatie\Permission\Models\Permission::pluck('name'),
        ]);
    });
});
