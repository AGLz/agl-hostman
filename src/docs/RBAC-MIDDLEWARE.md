# RBAC Middleware Documentation
**AGL Infrastructure Admin Platform - Phase 5**

## Overview

Phase 5 introduces comprehensive Role-Based Access Control (RBAC) middleware for securing routes and protecting resources. Three middleware classes provide flexible permission and role-based authorization.

---

## Available Middleware

### 1. `permission` - Check Permission Middleware
**File**: `app/Http/Middleware/CheckPermission.php`

Validates user has required permission(s) before allowing access.

**Features**:
- Single or multiple permission checks
- "Any" or "All" logic modes
- Automatic audit logging of unauthorized attempts
- JSON and web response support
- Active user validation

**Usage**:
```php
// Single permission
Route::middleware('permission:view-dashboard')->get('/monitoring', ...);

// Multiple permissions (requires ALL)
Route::middleware('permission:create-users,assign-roles')->post('/users', ...);

// Multiple permissions (requires ANY)
Route::middleware('permission:start-containers,stop-containers|any')->post('/containers/action', ...);

// Route groups
Route::middleware(['auth', 'permission:manage-infrastructure'])->group(function () {
    Route::get('/containers', ...);
    Route::post('/containers/start', ...);
    Route::post('/containers/stop', ...);
});
```

**Permission Logic Modes**:
- `|all` (default) - User must have ALL specified permissions
- `|any` - User must have AT LEAST ONE of the specified permissions

**Example Route Definitions**:
```php
// Dashboard access
Route::middleware('permission:view-dashboard')->group(function () {
    Route::get('/monitoring', [DashboardController::class, 'index'])->name('monitoring.index');
    Route::get('/api/cluster-health', [DashboardController::class, 'clusterHealth'])->name('monitoring.api.cluster-health');
});

// Infrastructure management
Route::middleware('permission:manage-infrastructure')->group(function () {
    Route::post('/containers/{id}/start', [ContainerController::class, 'start']);
    Route::post('/containers/{id}/stop', [ContainerController::class, 'stop']);
    Route::post('/containers/{id}/restart', [ContainerController::class, 'restart']);
});

// User management (requires multiple permissions)
Route::middleware('permission:manage-users,assign-roles|all')->group(function () {
    Route::post('/users/{id}/assign-role', [UserController::class, 'assignRole']);
});
```

---

### 2. `role` - Check Role Middleware
**File**: `app/Http/Middleware/CheckRole.php`

Validates user has required role(s) before allowing access.

**Features**:
- Single or multiple role checks
- "Any" or "All" logic modes
- Automatic audit logging of unauthorized attempts
- JSON and web response support
- Active user validation

**Usage**:
```php
// Single role
Route::middleware('role:admin')->get('/admin', ...);

// Multiple roles (requires ALL)
Route::middleware('role:admin,super-admin')->delete('/system/critical', ...);

// Multiple roles (requires ANY)
Route::middleware('role:admin,operator|any')->get('/infrastructure', ...);

// Combined with auth
Route::middleware(['auth', 'role:super-admin'])->group(function () {
    Route::get('/system/config', ...);
    Route::post('/system/settings', ...);
});
```

**Role Logic Modes**:
- `|all` (default) - User must have ALL specified roles
- `|any` - User must have AT LEAST ONE of the specified roles

**Example Route Definitions**:
```php
// Admin-only routes
Route::middleware('role:admin')->group(function () {
    Route::resource('users', UserController::class);
    Route::post('/users/{id}/activate', [UserController::class, 'activate']);
    Route::post('/users/{id}/deactivate', [UserController::class, 'deactivate']);
});

// Super admin-only routes
Route::middleware('role:super-admin')->group(function () {
    Route::delete('/audit-logs/{id}', [AuditLogController::class, 'destroy']);
    Route::post('/system/settings', [SystemController::class, 'updateSettings']);
});

// Operator or Admin routes (any)
Route::middleware('role:operator,admin|any')->group(function () {
    Route::get('/containers', [ContainerController::class, 'index']);
    Route::post('/containers/{id}/restart', [ContainerController::class, 'restart']);
});
```

---

### 3. `active` - Ensure User Is Active Middleware
**File**: `app/Http/Middleware/EnsureUserIsActive.php`

Validates authenticated user has active status (`is_active = true`).

**Features**:
- Checks user active status
- Automatic logout of inactive users
- Audit logging of inactive access attempts
- JSON and web response support
- Redirect to login with error message

**Usage**:
```php
// Single route
Route::middleware('active')->get('/profile', ...);

// Global application (recommended)
// In bootstrap/app.php:
$middleware->append(\App\Http\Middleware\EnsureUserIsActive::class);

// Specific route group
Route::middleware(['auth', 'active'])->group(function () {
    Route::get('/dashboard', ...);
    Route::get('/profile', ...);
});
```

**Recommended Setup**:
Apply globally to all authenticated routes by adding to `web` middleware group:

```php
// bootstrap/app.php
->withMiddleware(function (Middleware $middleware): void {
    $middleware->alias([
        'permission' => \App\Http\Middleware\CheckPermission::class,
        'role' => \App\Http\Middleware\CheckRole::class,
        'active' => \App\Http\Middleware\EnsureUserIsActive::class,
    ]);

    // Apply active check globally to web routes
    $middleware->web(append: [
        \App\Http\Middleware\EnsureUserIsActive::class,
    ]);
})
```

---

## Middleware Registration

All middleware are registered in `bootstrap/app.php`:

```php
<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withMiddleware(function (Middleware $middleware): void {
        // Phase 5: RBAC Middleware Aliases
        $middleware->alias([
            'permission' => \App\Http\Middleware\CheckPermission::class,
            'role' => \App\Http\Middleware\CheckRole::class,
            'active' => \App\Http\Middleware\EnsureUserIsActive::class,
        ]);
    })
    ->create();
```

---

## Available Permissions

**Dashboard & Monitoring** (4):
- `view-dashboard` - Access monitoring dashboard
- `view-realtime-updates` - View real-time metrics
- `view-health-metrics` - View health statistics
- `view-alerts` - View alert history

**Predictive Maintenance** (3):
- `view-predictions` - View predictive maintenance forecasts
- `export-predictions` - Export prediction data
- `configure-predictions` - Configure prediction algorithms

**Infrastructure Management** (7):
- `view-infrastructure` - View infrastructure status
- `manage-infrastructure` - Full infrastructure management
- `start-containers` - Start containers/VMs
- `stop-containers` - Stop containers/VMs
- `restart-containers` - Restart containers/VMs
- `delete-containers` - Delete containers/VMs
- `configure-containers` - Configure container settings

**User Management** (6):
- `view-users` - View user list
- `create-users` - Create new users
- `edit-users` - Edit user details
- `delete-users` - Delete users
- `manage-users` - Full user management
- `activate-deactivate-users` - Activate/deactivate user accounts

**Role & Permission Management** (7):
- `view-roles` - View role list
- `create-roles` - Create new roles
- `edit-roles` - Edit role details
- `delete-roles` - Delete roles
- `manage-roles` - Full role management
- `assign-roles` - Assign roles to users
- `assign-permissions` - Assign permissions to roles

**Audit Logs** (3):
- `view-audit-logs` - View audit log entries
- `export-audit-logs` - Export audit log data
- `delete-audit-logs` - Delete audit log entries

**System Administration** (4):
- `admin-access` - Administrative access (super admin)
- `system-configuration` - Configure system settings
- `view-system-logs` - View system logs
- `manage-system-settings` - Manage system settings

---

## Available Roles

### Super Admin
**Permissions**: All 35 permissions
**Use Case**: System administrators with full access

### Admin
**Permissions**: 26/35 permissions
**Use Case**: Administrative users managing infrastructure and users
**Excluded**: Super admin-specific permissions (delete-users, delete-roles, delete-audit-logs, admin-access)

### Operator
**Permissions**: 12/35 permissions
**Use Case**: Infrastructure operators managing containers
**Capabilities**:
- Full dashboard access
- View predictions and export data
- Start/stop/restart containers (no delete)
- View audit logs

### Analyst
**Permissions**: 11/35 permissions
**Use Case**: Data analysts with read-only access plus prediction configuration
**Capabilities**:
- Full dashboard access
- Full predictive maintenance access
- View infrastructure (read-only)
- View and export audit logs

### Viewer
**Permissions**: 3/35 permissions
**Use Case**: Basic monitoring with minimal access
**Capabilities**:
- View dashboard
- View health metrics
- View infrastructure status

---

## Common Usage Patterns

### Pattern 1: Permission-Based Routes (Recommended)
```php
// Protect specific actions with granular permissions
Route::middleware('permission:start-containers')->post('/containers/{id}/start', ...);
Route::middleware('permission:stop-containers')->post('/containers/{id}/stop', ...);
Route::middleware('permission:delete-containers')->delete('/containers/{id}', ...);
```

**Advantages**:
- Granular control
- Easy to audit
- Flexible role changes

### Pattern 2: Role-Based Routes
```php
// Protect sections by role
Route::middleware('role:admin')->prefix('admin')->group(function () {
    Route::resource('users', UserController::class);
});
```

**Advantages**:
- Simpler route definitions
- Clear organizational structure
- Good for role-specific sections

### Pattern 3: Combined Middleware
```php
// Combine multiple middleware
Route::middleware(['auth', 'active', 'permission:manage-users'])->group(function () {
    Route::post('/users', [UserController::class, 'store']);
    Route::put('/users/{id}', [UserController::class, 'update']);
});
```

**Advantages**:
- Maximum security
- Explicit requirements
- Comprehensive validation

### Pattern 4: API Routes with JSON Responses
```php
// API routes automatically return JSON
Route::prefix('api')->middleware(['auth:sanctum', 'permission:view-dashboard'])->group(function () {
    Route::get('/cluster-health', [DashboardController::class, 'clusterHealth']);
    Route::get('/node-health/{node}', [DashboardController::class, 'nodeHealth']);
});
```

**Response Format** (unauthorized):
```json
{
    "error": "Forbidden",
    "message": "You do not have permission to perform this action.",
    "required_permissions": ["view-dashboard"]
}
```

---

## Security Features

### 1. Active User Validation
All middleware automatically check `is_active` status:
```php
if (!$user->isActive()) {
    // Log security event
    // Return 403 Forbidden
}
```

### 2. Comprehensive Audit Logging
Unauthorized access attempts are automatically logged:
```php
AuditLog::logSecurityEvent($user, 'unauthorized_access', $description, [
    'required_permissions' => $permissionList,
    'user_permissions' => $userPermissions,
    'ip' => $request->ip(),
    'url' => $request->fullUrl(),
]);
```

### 3. Automatic Logout
Inactive users are logged out automatically by `active` middleware.

### 4. JSON API Support
All middleware detect JSON requests and return appropriate responses:
```json
{
    "error": "Forbidden",
    "message": "You do not have permission to perform this action.",
    "required_permissions": ["manage-users", "assign-roles"]
}
```

---

## Testing Middleware

### Unit Tests
```php
/** @test */
public function it_blocks_users_without_permission()
{
    $user = User::factory()->create();

    $response = $this->actingAs($user)
        ->get('/admin/users');

    $response->assertStatus(403);
}

/** @test */
public function it_allows_users_with_permission()
{
    $user = User::factory()->create();
    $user->givePermissionTo('view-users');

    $response = $this->actingAs($user)
        ->get('/admin/users');

    $response->assertStatus(200);
}
```

### Integration Tests
```php
/** @test */
public function admin_can_manage_users()
{
    $admin = User::factory()->create();
    $admin->assignRole('admin');

    $response = $this->actingAs($admin)
        ->post('/admin/users', [
            'name' => 'New User',
            'email' => 'new@example.com',
        ]);

    $response->assertStatus(201);
    $this->assertDatabaseHas('users', ['email' => 'new@example.com']);
}
```

---

## Troubleshooting

### Issue: Middleware not working
**Solution**: Clear cached routes and config
```bash
php artisan route:clear
php artisan config:clear
php artisan cache:clear
```

### Issue: Permission denied for admin users
**Solution**: Verify permissions are assigned
```bash
php artisan tinker
$user = User::find(1);
$user->getAllPermissions(); // Check assigned permissions
$user->roles; // Check assigned roles
```

### Issue: Inactive user still has access
**Solution**: Apply `active` middleware globally
```php
// bootstrap/app.php
$middleware->web(append: [
    \App\Http\Middleware\EnsureUserIsActive::class,
]);
```

---

## Best Practices

1. **Use permission middleware over role middleware** for better granularity
2. **Apply `active` middleware globally** to all authenticated routes
3. **Use `|any` logic sparingly** - prefer specific permission checks
4. **Test authorization logic** with unit and integration tests
5. **Review audit logs regularly** to identify unauthorized access patterns
6. **Document route protection** in route files with comments
7. **Keep permissions granular** - one permission per action type
8. **Use route groups** to reduce middleware repetition

---

## Migration Checklist

Before deploying RBAC middleware:

- [ ] Install Spatie Laravel Permission: `composer require spatie/laravel-permission`
- [ ] Publish Spatie config: `php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"`
- [ ] Run Spatie migrations: `php artisan migrate`
- [ ] Run audit logs RBAC migration: `php artisan migrate`
- [ ] Seed roles and permissions: `php artisan db:seed --class=RolesAndPermissionsSeeder`
- [ ] Assign roles to existing users
- [ ] Update routes with middleware
- [ ] Test authorization logic
- [ ] Clear caches: `php artisan optimize:clear`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-11
**Phase**: 5 - User Management & Permissions
**Status**: Complete
