# RBAC Implementation Guide

## Overview

AGL Hostman implements a comprehensive Role-Based Access Control (RBAC) system using [Spatie Laravel Permission](https://spatie.be/docs/laravel-permission/v6/introduction). This system provides fine-grained access control for users, roles, and permissions.

## Features

- **Flexible Permission System**: Granular permissions for all application features
- **Role-Based Access**: Predefined system roles and custom roles
- **Direct User Permissions**: Assign permissions directly to users when needed
- **Middleware Protection**: Route-level permission and role checking
- **API Controllers**: Full REST API for RBAC management
- **Service Layer**: Business logic separation for RBAC operations
- **Audit Logging**: Track all permission-related security events

## Installation

The Spatie Laravel Permission package is already installed. Run the migrations:

```bash
cd src
php artisan migrate
```

Run the RBAC seeder to populate default roles and permissions:

```bash
php artisan db:seed --class=RbacSeeder
```

## Default Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| `admin` | Full system access with all permissions | All permissions |
| `advanced` | Can manage containers, deployments, and view monitoring | Containers, Deployments, Monitoring, Servers (view/monitor) |
| `common` | Read-only access to monitoring and deployments | All `.view` permissions |
| `restricted` | Limited access to specific resources | No default permissions (assigned manually) |

## Permission Modules

Permissions are organized by modules:

| Module | Permissions |
|--------|-------------|
| `containers` | view, create, edit, delete, start, stop, restart, clone, backup, restore |
| `servers` | view, manage, monitor, maintenance |
| `users` | view, create, edit, delete, assign_roles, manage_permissions |
| `monitoring` | view, alerts, logs, reports |
| `deployments` | view, create, manage, rollback, logs |
| `infrastructure` | network, storage, backup, security |
| `roles` | view, create, edit, delete |
| `permissions` | view, manage |

## Usage

### Checking Permissions

#### In Blade Templates

```blade
@can('containers.view')
    <!-- User can view containers -->
@endcan

@role('admin')
    <!-- User is admin -->
@endrole

@hasanyrole('admin|advanced')
    <!-- User is admin or advanced -->
@endhasanyrole
```

#### In Controllers

```php
// Check permission
if ($user->can('containers.create')) {
    // User can create containers
}

// Check role
if ($user->hasRole('admin')) {
    // User is admin
}

// Check multiple permissions (any)
if ($user->hasAnyPermission(['containers.view', 'containers.create'])) {
    // User has at least one permission
}

// Check multiple permissions (all)
if ($user->hasAllPermissions(['containers.view', 'containers.edit'])) {
    // User has all permissions
}
```

#### Using Helper Methods

```php
// User model helper methods
$user->canAccessDashboard();
$user->canManageUsers();
$user->canManageRoles();
$user->isSuperAdmin();
$user->canManageInfrastructure();
```

### Middleware Protection

#### Protect Routes by Permission

```php
// Single permission
Route::get('/containers', [ContainerController::class, 'index'])
    ->middleware('permission:containers.view');

// Multiple permissions (user must have ALL)
Route::post('/containers', [ContainerController::class, 'store'])
    ->middleware('permission:containers.view,containers.create');

// Multiple permissions (user must have ANY)
Route::delete('/containers/{id}', [ContainerController::class, 'destroy'])
    ->middleware('permission:containers.delete,admin-access|any');
```

#### Protect Routes by Role

```php
// Single role
Route::get('/admin', [AdminController::class, 'index'])
    ->middleware('role:admin');

// Multiple roles (user must have ALL)
Route::get('/settings', [SettingsController::class, 'index'])
    ->middleware('role:admin,manager|all');

// Multiple roles (user must have ANY)
Route::get('/reports', [ReportController::class, 'index'])
    ->middleware('role:admin,manager,analyst|any');
```

#### Other Middleware

```php
// Ensure user is active
Route::middleware('active')

// Check location access
Route::middleware('location:DATA_CENTER_01,view')
```

### Service Layer Usage

#### PermissionService

```php
use App\Services\Rbac\PermissionService;

class ContainerController extends Controller
{
    public function __construct(
        private PermissionService $permissionService
    ) {}

    public function assignPermission(Request $request)
    {
        $permission = Permission::findByName('containers.manage');
        $user = User::find($request->user_id);

        $this->permissionService->assignPermissionToUser($permission, $user);
    }

    public function getStatistics()
    {
        return $this->permissionService->getStatistics();
    }
}
```

#### RoleService

```php
use App\Services\Rbac\RoleService;

class UserController extends Controller
{
    public function __construct(
        private RoleService $roleService
    ) {}

    public function assignRole(Request $request)
    {
        $role = Role::findByName('admin');
        $user = User::find($request->user_id);

        $this->roleService->assignRoleToUser($role, $user);
    }

    public function cloneRole(Request $request)
    {
        $sourceRole = Role::findByName('admin');
        $newRole = $this->roleService->cloneRole($sourceRole, 'super-admin');
    }
}
```

#### RbacService

```php
use App\Services\Rbac\RbacService;

class DashboardController extends Controller
{
    public function __construct(
        private RbacService $rbacService
    ) {}

    public function userSummary(Request $request)
    {
        $summary = $this->rbacService->getUserRbacSummary($request->user());

        return response()->json($summary);
        /*
        Returns:
        {
            user: { id, name, email, is_active },
            roles: [...],
            permissions: { direct: [...], via_roles: [...], all: [...] },
            abilities: { is_super_admin, can_manage_users, ... }
        }
        */
    }
}
```

## API Endpoints

### Roles API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/roles` | List all roles |
| GET | `/api/roles/{id}` | Get role details |
| POST | `/api/roles` | Create new role |
| PUT | `/api/roles/{id}` | Update role |
| DELETE | `/api/roles/{id}` | Delete role |
| POST | `/api/roles/{id}/assign` | Assign role to user |
| DELETE | `/api/roles/{id}/revoke` | Revoke role from user |
| GET | `/api/roles/statistics` | Get role statistics |
| POST | `/api/roles/{id}/clone` | Clone a role |

### Permissions API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/permissions` | List all permissions |
| GET | `/api/permissions/grouped` | Get permissions grouped by module |
| GET | `/api/permissions/modules` | Get available modules |
| GET | `/api/permissions/{id}` | Get permission details |
| POST | `/api/permissions` | Create new permission |
| PUT | `/api/permissions/{id}` | Update permission |
| DELETE | `/api/permissions/{id}` | Delete permission |
| POST | `/api/permissions/{id}/assign-role` | Assign permission to role |
| DELETE | `/api/permissions/{id}/revoke-role` | Revoke permission from role |
| POST | `/api/permissions/{id}/assign-user` | Assign permission to user |
| GET | `/api/permissions/statistics` | Get permission statistics |

### RBAC API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/rbac/overview` | Get complete RBAC overview |
| GET | `/api/rbac/me` | Get current user's RBAC summary |
| GET | `/api/rbac/users/{id}` | Get user's RBAC summary |
| POST | `/api/rbac/grant-role` | Grant role to user |
| POST | `/api/rbac/revoke-role` | Revoke role from user |
| POST | `/api/rbac/grant-permission` | Grant permission to user |
| POST | `/api/rbac/revoke-permission` | Revoke permission from user |
| GET | `/api/rbac/users/role/{role}` | Get users with role |
| GET | `/api/rbac/users/permission/{permission}` | Get users with permission |

## Database Schema

### Tables

- `roles` - Custom role model with `description` and `is_system` fields
- `permissions` - Custom permission model with `module` and `description` fields
- `model_has_roles` - Pivot table for user-role relationships
- `model_has_permissions` - Pivot table for user-permission relationships
- `role_has_permissions` - Pivot table for role-permission relationships

### Custom Fields

#### Roles Table
- `id` - Primary key
- `name` - Role name (unique)
- `guard_name` - Guard name (default: web)
- `description` - Role description
- `is_system` - Boolean flag for system roles (protected)
- `created_at`, `updated_at` - Timestamps

#### Permissions Table
- `id` - Primary key
- `name` - Permission name (unique)
- `guard_name` - Guard name (default: web)
- `module` - Permission module (e.g., containers, users)
- `description` - Permission description
- `created_at`, `updated_at` - Timestamps

## Custom Models

### Role Model

```php
use App\Models\Role;

// Get system roles
$systemRoles = Role::system()->get();

// Get custom roles
$customRoles = Role::custom()->get();

// Check if role can be deleted
if ($role->canBeDeleted()) {
    $role->delete();
}

// Get permissions grouped by module
$groupedPermissions = $role->permissions_grouped_by_module;

// Get user count with this role
$userCount = $role->users_count;
```

### Permission Model

```php
use App\Models\Permission;

// Get permissions by module
$containerPermissions = Permission::byModule('containers')->get();

// Get all modules
$modules = Permission::getModules();

// Search permissions
$results = Permission::search('container')->get();

// Get role count
$roleCount = $permission->roles_count;

// Get user count
$userCount = $permission->users_count;
```

### User Model (RBAC Methods)

```php
use App\Models\User;

$user = User::find(1);

// Check methods
$user->hasPermissionTo('containers.view');
$user->hasAnyPermission(['containers.view', 'containers.create']);
$user->hasAllPermissions(['containers.view', 'containers.edit']);
$user->hasRole('admin');
$user->hasAnyRole(['admin', 'advanced']);
$user->hasAllRoles(['admin', 'operator']);

// Helper methods
$user->isSuperAdmin();
$user->canAccessDashboard();
$user->canManageUsers();
$user->canManageRoles();
$user->canViewPredictiveMaintenance();
$user->canManageInfrastructure();

// Get permissions
$user->getAllPermissions(); // All permissions (direct + via roles)
$user->getDirectPermissions(); // Only direct permissions
$user->getPrimaryRoleAttribute(); // Primary role

// Scopes
User::active()->get();
User::inactive()->get();
User::withRole('admin')->get();
User::withPermission('containers.view')->get();
```

## Caching

Permissions are cached for 24 hours by default. The cache is automatically cleared when:

- A role is created/updated/deleted
- A permission is created/updated/deleted
- A permission is assigned/revoked from a role
- A permission is assigned/revoked from a user
- A role is assigned/revoked from a user

To manually clear the cache:

```bash
php artisan cache:forget spatie.permission.cache
```

Or programmatically:

```php
app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
```

## Security Considerations

1. **System Roles Protection**: System roles (`is_system = true`) cannot be modified or deleted
2. **Audit Logging**: All unauthorized access attempts are logged to `audit_logs` table
3. **Active User Check**: Inactive users automatically fail permission checks
4. **Permission in Exception**: Disabled for security (set to `false` in config)
5. **Role in Exception**: Disabled for security (set to `false` in config)

## Troubleshooting

### Permissions not working

1. Clear the permission cache:
   ```bash
   php artisan cache:forget spatie.permission.cache
   ```

2. Ensure user is active:
   ```php
   $user->isActive(); // Should return true
   ```

3. Check user's roles and permissions:
   ```php
   $user->roles->pluck('name');
   $user->getAllPermissions()->pluck('name');
   ```

### "This action is unauthorized" error

1. Check if the permission exists:
   ```php
   Permission::findByName('containers.view');
   ```

2. Verify the user has the permission:
   ```php
   $user->hasPermissionTo('containers.view');
   ```

3. Check middleware configuration in `bootstrap/app.php`

### Database migration errors

1. Ensure `app/Models/Role.php` and `app/Models/Permission.php` exist
2. Check `config/permission.php` for correct model references
3. Run migrations fresh (WARNING: This deletes data):
   ```bash
   php artisan migrate:fresh
   php artisan db:seed --class=RbacSeeder
   ```

## Best Practices

1. **Use Permissions, Not Roles**: Check permissions in code, not roles
   ```php
   // Good
   if ($user->can('containers.create')) { }

   // Less flexible
   if ($user->hasRole('admin')) { }
   ```

2. **Use Wildcards Sparingly**: Only use wildcard permissions for super admins

3. **Create Custom Roles**: Don't modify system roles; create custom ones

4. **Use Service Layer**: Use `RoleService`, `PermissionService`, `RbacService` for RBAC operations

5. **Log Security Events**: The middleware automatically logs unauthorized access attempts

6. **Test Permissions**: Use Pest/PHPUnit to test permission logic

## Testing

```php
use App\Models\User;
use Spatie\Permission\Models\Role;

test('admin can create containers', function () {
    $admin = User::factory()->create();
    $admin->assignRole('admin');

    $this->actingAs($admin)
        ->post('/containers', [...])
        ->assertStatus(201);
});

test('user without permission cannot create containers', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->post('/containers', [...])
        ->assertStatus(403);
});
```

## References

- [Spatie Laravel Permission Documentation](https://spatie.be/docs/laravel-permission/v6/introduction)
- [Laravel Authorization](https://laravel.com/docs/11.x/authorization)
- [Laravel Middleware](https://laravel.com/docs/11.x/middleware)
