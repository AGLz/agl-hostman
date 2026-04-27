# TASK-008: RBAC Implementation (Role-Based Access Control)

> **Status**: 📋 PLANNING
> **Assignee**: Claude
> **Priority**: HIGH
> **Created**: 2025-12-29
> **Dependencies**: TASK-007 (WorkOS Auth) ✅ COMPLETED

---

## 📋 Objective

Implement a comprehensive Role-Based Access Control (RBAC) system for AGL HostMan platform with flexible permissions and admin management interface.

---

## 🎯 Requirements

### 1. Database Schema

#### **roles table**
```sql
- id (bigint, primary key)
- name (string, unique) - admin, advanced, common, restricted
- slug (string, unique)
- description (text, nullable)
- is_system (boolean, default: false) - Prevent deletion of system roles
- created_at (timestamp)
- updated_at (timestamp)
```

#### **permissions table**
```sql
- id (bigint, primary key)
- name (string, unique) - e.g., "containers.create", "users.manage"
- slug (string, unique)
- description (text, nullable)
- module (string) - containers, servers, users, monitoring, deployments
- created_at (timestamp)
- updated_at (timestamp)
```

#### **permission_role pivot table**
```sql
- permission_id (bigint, foreign key)
- role_id (bigint, foreign key)
- created_at (timestamp)
```

#### **user_roles table** (Support multiple roles per user)
```sql
- id (bigint, primary key)
- user_id (bigint, foreign key)
- role_id (bigint, foreign key)
- created_at (timestamp)
```

#### **user_permissions table** (Direct user permissions override)
```sql
- id (bigint, primary key)
- user_id (bigint, foreign key)
- permission_id (bigint, foreign key)
- granted (boolean, default: true) - true = grant, false = revoke
- created_at (timestamp)
```

### 2. Default Roles

**System Roles (is_system = true):**
1. **admin** - Full access to everything
2. **advanced** - Can manage containers, deployments, view monitoring
3. **common** - Read-only access to monitoring and deployments
4. **restricted** - Limited access, only specific resources

### 3. Permission Modules

**Containers:**
- `containers.view` - View container list
- `containers.create` - Create new containers
- `containers.edit` - Edit container configuration
- `containers.delete` - Delete containers
- `containers.start` - Start containers
- `containers.stop` - Stop containers
- `containers.restart` - Restart containers
- `containers.clone` - Clone containers
- `containers.backup` - Backup containers
- `containers.restore` - Restore containers

**Servers:**
- `servers.view` - View server list
- `servers.manage` - Manage server configuration
- `servers.monitor` - View server metrics
- `servers.maintenance` - Put servers in maintenance mode

**Users:**
- `users.view` - View user list
- `users.create` - Create users
- `users.edit` - Edit user information
- `users.delete` - Delete users
- `users.assign_roles` - Assign roles to users
- `users.manage_permissions` - Manage user permissions

**Monitoring:**
- `monitoring.view` - View monitoring dashboard
- `monitoring.alerts` - View and manage alerts
- `monitoring.logs` - View system logs
- `monitoring.reports` - Generate reports

**Deployments:**
- `deployments.view` - View deployments
- `deployments.create` - Create deployments
- `deployments.manage` - Manage deployment pipelines
- `deployments.rollback` - Rollback deployments
- `deployments.logs` - View deployment logs

**Infrastructure:**
- `infrastructure.network` - Manage network configuration
- `infrastructure.storage` - Manage storage
- `infrastructure.backup` - Manage backup policies
- `infrastructure.security` - Manage security settings

---

## 🔧 Implementation Plan

### Phase 1: Database & Models (1-2 hours)

**Tasks:**
1. Create migration for roles table
2. Create migration for permissions table
3. Create migration for permission_role pivot table
4. Create migration for user_roles table
5. Create migration for user_permissions table
6. Create Role model with relationships
7. Create Permission model with relationships
8. Update User model with relationships
9. Create database seeder for default roles and permissions

**Files to Create:**
- `database/migrations/2025_12_29_000001_create_roles_table.php`
- `database/migrations/2025_12_29_000002_create_permissions_table.php`
- `database/migrations/2025_12_29_000003_create_permission_role_table.php`
- `database/migrations/2025_12_29_000004_create_user_roles_table.php`
- `database/migrations/2025_12_29_000005_create_user_permissions_table.php`
- `app/Models/Role.php`
- `app/Models/Permission.php`
- `database/seeders/RbacSeeder.php`

### Phase 2: Authorization Middleware (2-3 hours)

**Tasks:**
1. Create `HasRoles` trait for User model
2. Create `HasPermissions` trait for Role model
3. Implement `RoleService` for role management
4. Implement `PermissionService` for permission checking
5. Create `RoleMiddleware` for route protection
6. Create `PermissionMiddleware` for granular control
7. Create Blade directives for UI permissions

**Files to Create:**
- `app/Traits/HasRoles.php`
- `app/Traits/HasPermissions.php`
- `app/Services/RoleService.php`
- `app/Services/PermissionService.php`
- `app/Http/Middleware/CheckRole.php`
- `app/Http/Middleware/CheckPermission.php`
- `app/Providers/BladeServiceProvider.php`

**Usage Examples:**
```php
// In routes
Route::middleware(['role:admin'])->group(function () {
    // Admin only routes
});

Route::middleware(['permission:containers.create'])->group(function () {
    // Requires container creation permission
});

// In controllers
$this->authorize('containers.create', Container::class);

// In Blade views
@role('admin')
    // Admin only content
@endrole

@permission('containers.delete')
    <button>Delete Container</button>
@endpermission

// In User model
$user->hasRole('admin'); // true/false
$user->hasPermission('containers.create'); // true/false
$user->getAllPermissions(); // Collection of permissions
```

### Phase 3: Admin Panel (3-4 hours)

**Tasks:**
1. Create RolesController with CRUD operations
2. Create PermissionsController with CRUD operations
3. Create UserRoleController for assigning roles to users
4. Create UserPermissionController for direct permission assignment
5. Create admin views for role management
6. Create admin views for permission management
7. Create user role assignment interface

**Files to Create:**
- `app/Http/Controllers/Admin/RolesController.php`
- `app/Http/Controllers/Admin/PermissionsController.php`
- `app/Http/Controllers/Admin/UserRoleController.php`
- `app/Http/Controllers/Admin/UserPermissionController.php`
- `resources/views/admin/roles/index.blade.php`
- `resources/views/admin/roles/create.blade.php`
- `resources/views/admin/roles/edit.blade.php`
- `resources/views/admin/permissions/index.blade.php`
- `resources/views/admin/users/roles.blade.php`
- `resources/views/admin/users/permissions.blade.php`

**Admin Panel Features:**
- List all roles with permissions count
- Create/edit/delete roles (except system roles)
- Assign permissions to roles
- List all permissions grouped by module
- Assign roles to users
- Grant/revoke individual permissions to users
- View user's current roles and permissions

### Phase 4: Integration & Testing (1-2 hours)

**Tasks:**
1. Protect existing routes with role/permission middleware
2. Update navigation to show/hide items based on permissions
3. Create tests for RBAC functionality
4. Test role assignments
5. Test permission checks
6. Test admin panel operations
7. Verify WorkOS authentication integration

**Test Coverage:**
```php
// tests/Feature/Rbac/RolesTest.php
- test_admin_can_create_roles()
- test_admin_can_delete_non_system_roles()
- test_cannot_delete_system_roles()

// tests/Feature/Rbac/PermissionsTest.php
- test_user_with_role_has_permissions()
- test_user_with_direct_permission_override()
- test_permission_middleware_works()
- test_role_middleware_works()

// tests/Feature/Rbac/AdminPanelTest.php
- test_admin_can_assign_roles_to_users()
- test_admin_can_grant_direct_permissions()
- test_unauthorized_cannot_access_admin_panel()
```

---

## 📝 Database Migration Scripts

### Create Roles Table
```php
// database/migrations/2025_12_29_000001_create_roles_table.php
Schema::create('roles', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('slug')->unique();
    $table->text('description')->nullable();
    $table->boolean('is_system')->default(false);
    $table->timestamps();
});
```

### Create Permissions Table
```php
// database/migrations/2025_12_29_000002_create_permissions_table.php
Schema::create('permissions', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('slug')->unique();
    $table->text('description')->nullable();
    $table->string('module'); // containers, servers, users, etc.
    $table->timestamps();
});
```

### Create Permission_Role Pivot Table
```php
// database/migrations/2025_12_29_000003_create_permission_role_table.php
Schema::create('permission_role', function (Blueprint $table) {
    $table->foreignId('permission_id')->constrained()->onDelete('cascade');
    $table->foreignId('role_id')->constrained()->onDelete('cascade');
    $table->timestamps();

    $table->unique(['permission_id', 'role_id']);
});
```

### Create User_Roles Table
```php
// database/migrations/2025_12_29_000004_create_user_roles_table.php
Schema::create('user_roles', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->foreignId('role_id')->constrained()->onDelete('cascade');
    $table->timestamps();

    $table->unique(['user_id', 'role_id']);
});
```

### Create User_Permissions Table
```php
// database/migrations/2025_12_29_000005_create_user_permissions_table.php
Schema::create('user_permissions', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->foreignId('permission_id')->constrained()->onDelete('cascade');
    $table->boolean('granted')->default(true);
    $table->timestamps();

    $table->unique(['user_id', 'permission_id']);
});
```

---

## 🌱 Seeder - Default Roles & Permissions

```php
// database/seeders/RbacSeeder.php

public function run()
{
    // Create system roles
    $admin = Role::create([
        'name' => 'Administrator',
        'slug' => 'admin',
        'description' => 'Full system access',
        'is_system' => true,
    ]);

    $advanced = Role::create([
        'name' => 'Advanced User',
        'slug' => 'advanced',
        'description' => 'Can manage containers and deployments',
        'is_system' => true,
    ]);

    $common = Role::create([
        'name' => 'Common User',
        'slug' => 'common',
        'description' => 'Read-only access to monitoring',
        'is_system' => true,
    ]);

    $restricted = Role::create([
        'name' => 'Restricted User',
        'slug' => 'restricted',
        'description' => 'Limited access to specific resources',
        'is_system' => true,
    ]);

    // Create permissions by module
    $containers = [
        'containers.view', 'containers.create', 'containers.edit',
        'containers.delete', 'containers.start', 'containers.stop',
        'containers.restart', 'containers.clone', 'containers.backup',
        'containers.restore',
    ];

    $servers = [
        'servers.view', 'servers.manage', 'servers.monitor',
        'servers.maintenance',
    ];

    $users = [
        'users.view', 'users.create', 'users.edit',
        'users.delete', 'users.assign_roles', 'users.manage_permissions',
    ];

    $monitoring = [
        'monitoring.view', 'monitoring.alerts',
        'monitoring.logs', 'monitoring.reports',
    ];

    $deployments = [
        'deployments.view', 'deployments.create',
        'deployments.manage', 'deployments.rollback', 'deployments.logs',
    ];

    $infrastructure = [
        'infrastructure.network', 'infrastructure.storage',
        'infrastructure.backup', 'infrastructure.security',
    ];

    $allPermissions = array_merge($containers, $servers, $users, $monitoring, $deployments, $infrastructure);

    foreach ($allPermissions as $permission) {
        [$module, $action] = explode('.', $permission);
        Permission::create([
            'name' => ucwords(str_replace('.', ' ', $permission)),
            'slug' => $permission,
            'module' => $module,
            'description' => "Ability to {$action} {$module}",
        ]);
    }

    // Assign all permissions to admin
    $admin->permissions()->attach(Permission::all());

    // Assign specific permissions to advanced user
    $advanced->permissions()->attach(
        Permission::whereIn('module', ['containers', 'deployments', 'monitoring'])->get()
    );

    // Assign read-only permissions to common user
    $common->permissions()->attach(
        Permission::where('slug', 'like', '%.view')->get()
    );

    // No permissions for restricted user (assigned manually)
}
```

---

## 🎨 UI Components (Blade)

### Role Management Interface

```blade
<!-- resources/views/admin/roles/index.blade.php -->
@extends('layouts.app')

@section('content')
<div class="container mx-auto px-4 py-8">
    <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Roles Management</h1>
        @permission('roles.create')
            <a href="{{ route('admin.roles.create') }}"
               class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
                Create Role
            </a>
        @endpermission
    </div>

    <div class="bg-white shadow-md rounded-lg overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
                <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Name
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Slug
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Permissions
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Actions
                    </th>
                </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
                @foreach($roles as $role)
                    <tr>
                        <td class="px-6 py-4 whitespace-nowrap">
                            {{ $role->name }}
                            @if($role->is_system)
                                <span class="ml-2 px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                                    System
                                </span>
                            @endif
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <code>{{ $role->slug }}</code>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            {{ $role->permissions->count() }} permissions
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                            <a href="{{ route('admin.roles.edit', $role) }}"
                               class="text-indigo-600 hover:text-indigo-900 mr-3">Edit</a>
                            @if(!$role->is_system)
                                @permission('roles.delete')
                                    <form action="{{ route('admin.roles.destroy', $role) }}"
                                          method="POST" class="inline">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit"
                                                class="text-red-600 hover:text-red-900"
                                                onclick="return confirm('Are you sure?')">
                                            Delete
                                        </button>
                                    </form>
                                @endpermission
                            @endif
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
@endsection
```

---

## ✅ Testing Checklist

- [ ] Migration files created
- [ ] Roles table created successfully
- [ ] Permissions table created successfully
- [ ] Pivot tables created successfully
- [ ] Models created with relationships
- [ ] HasRoles trait working
- [ ] HasPermissions trait working
- [ ] RoleService functional
- [ ] PermissionService functional
- [ ] Middleware protecting routes
- [ ] Blade directives working
- [ ] Seeder creates default roles
- [ ] Seeder creates all permissions
- [ ] Admin has all permissions
- [ ] Advanced user has correct permissions
- [ ] Common user has read-only permissions
- [ ] Admin panel accessible to admin only
- [ ] Role CRUD operations working
- [ ] Permission CRUD operations working
- [ ] User role assignment working
- [ ] Direct permission assignment working
- [ ] System roles protected from deletion
- [ ] WorkOS authentication integrated with roles
- [ ] Tests passing (≥70% coverage for RBAC)

---

## 🔗 Dependencies

**Required:**
- ✅ TASK-007: WorkOS Authentication (User model exists)

**Next Steps:**
- TASK-009: Dashboard UI (uses RBAC for menu visibility)

---

## 📊 Metrics

**Estimated Time**: 8-12 hours
**Files Created**: ~25 files
- 5 migrations
- 2 models
- 2 traits
- 2 services
- 2 middleware
- 4 controllers
- 6 views
- 1 seeder
- 3 test files

**Lines of Code**: ~1500 lines

---

## 🎯 Success Criteria

- ✅ Database schema implemented
- ✅ All models and relationships working
- ✅ Middleware protecting routes
- ✅ Admin panel functional
- ✅ Default roles and permissions seeded
- ✅ Integration with WorkOS authentication
- ✅ Tests passing with ≥70% coverage
- ✅ System roles protected from deletion
- ✅ Users can be assigned multiple roles
- ✅ Direct permission overrides working

---

## 📚 Documentation

- **Laravel Authorization**: https://laravel.com/docs/authorization
- **Laravel Policies**: https://laravel.com/docs/authorization#creating-policies
- **Spatie Laravel Permission** (Reference): https://spatie.be/docs/laravel-permission

**Last Updated**: 2025-12-29 22:50 UTC
**Status**: 📋 PLANNING - READY TO IMPLEMENT
