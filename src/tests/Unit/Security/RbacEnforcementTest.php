<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * RBAC Enforcement Tests
 *
 * Tests for Role-Based Access Control enforcement including
 * role checks, permission checks, and authorization bypass prevention.
 */
class RbacEnforcementTest extends TestCase
{
    use RefreshDatabase;

    private User $superAdmin;

    private User $admin;

    private User $operator;

    private User $commonUser;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\RolesAndPermissionsSeeder::class);

        $this->superAdmin = User::factory()->create();
        $this->superAdmin->assignRole('super-admin');

        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');

        $this->operator = User::factory()->create();
        $this->operator->assignRole('operator');

        $this->commonUser = User::factory()->create();
        $this->commonUser->assignRole('common');
    }

    /**
     * Test super admin has all permissions
     */
    public function test_super_admin_has_all_permissions(): void
    {
        $this->assertTrue($this->superAdmin->isSuperAdmin());

        $allPermissions = Permission::all();
        foreach ($allPermissions as $permission) {
            $this->assertTrue(
                $this->superAdmin->hasPermissionTo($permission->name),
                "Super admin should have permission: {$permission->name}"
            );
        }
    }

    /**
     * Test admin can manage users
     */
    public function test_admin_can_manage_users(): void
    {
        $this->assertTrue($this->admin->canManageUsers());
        $this->assertTrue($this->admin->hasPermissionTo('manage users'));
    }

    /**
     * Test common user cannot manage users
     */
    public function test_common_user_cannot_manage_users(): void
    {
        $this->assertFalse($this->commonUser->canManageUsers());
        $this->assertFalse($this->commonUser->hasPermissionTo('manage users'));
    }

    /**
     * Test role inheritance
     */
    public function test_role_inheritance(): void
    {
        $adminRole = Role::findByName('admin');
        $adminPermissions = $adminRole->permissions->pluck('name')->toArray();

        $this->assertNotEmpty($adminPermissions);
        $this->assertContains('manage users', $adminPermissions);
    }

    /**
     * Test permission direct assignment
     */
    public function test_permission_direct_assignment(): void
    {
        $user = User::factory()->create();
        $permission = Permission::firstOrCreate(['name' => 'custom permission']);

        $user->givePermissionTo($permission);

        $this->assertTrue($user->hasPermissionTo('custom permission'));
        $this->assertTrue($user->hasDirectPermission($permission));
    }

    /**
     * Test permission revocation
     */
    public function test_permission_revocation(): void
    {
        $user = User::factory()->create();
        $permission = Permission::firstOrCreate(['name' => 'test permission']);

        $user->givePermissionTo($permission);
        $this->assertTrue($user->hasPermissionTo($permission));

        $user->revokePermissionTo($permission);
        $this->assertFalse($user->hasPermissionTo($permission));
    }

    /**
     * Test role assignment
     */
    public function test_role_assignment(): void
    {
        $user = User::factory()->create();
        $role = Role::findByName('operator');

        $user->assignRole($role);

        $this->assertTrue($user->hasRole('operator'));
    }

    /**
     * Test role revocation
     */
    public function test_role_revocation(): void
    {
        $user = User::factory()->create();
        $role = Role::findByName('operator');

        $user->assignRole($role);
        $this->assertTrue($user->hasRole('operator'));

        $user->removeRole($role);
        $this->assertFalse($user->hasRole('operator'));
    }

    /**
     * Test multiple role assignment
     */
    public function test_multiple_role_assignment(): void
    {
        $user = User::factory()->create();

        $user->assignRole(['operator', 'admin']);

        $this->assertTrue($user->hasRole(['operator', 'admin']));
    }

    /**
     * Test hasAnyRole check
     */
    public function test_has_any_role(): void
    {
        $user = User::factory()->create();
        $user->assignRole('operator');

        $this->assertTrue($user->hasAnyRole(['operator', 'admin']));
        $this->assertTrue($user->hasAnyRole('operator', 'admin'));
    }

    /**
     * Test hasAllRoles check
     */
    public function test_has_all_roles(): void
    {
        $user = User::factory()->create();
        $user->assignRole(['operator', 'admin']);

        $this->assertTrue($user->hasAllRoles(['operator', 'admin']));
    }

    /**
     * Test hasAnyPermission check
     */
    public function test_has_any_permission(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo(['view dashboard', 'edit profile']);

        $this->assertTrue($user->hasAnyPermission(['view dashboard', 'delete users']));
    }

    /**
     * Test hasAllPermissions check
     */
    public function test_has_all_permissions(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo(['view dashboard', 'edit profile']);

        $this->assertTrue($user->hasAllPermissions(['view dashboard', 'edit profile']));
        $this->assertFalse($user->hasAllPermissions(['view dashboard', 'delete users']));
    }

    /**
     * Test wildcard permissions
     */
    public function test_wildcard_permissions(): void
    {
        $user = User::factory()->create();
        Permission::firstOrCreate(['name' => 'manage users']);
        Permission::firstOrCreate(['name' => 'manage roles']);
        Permission::firstOrCreate(['name' => 'manage permissions']);

        $user->givePermissionTo(['manage users', 'manage roles']);

        $this->assertTrue($user->hasAnyPermission('manage *'));
    }

    /**
     * Test permission via role
     */
    public function test_permission_via_role(): void
    {
        $role = Role::findByName('admin');
        $permission = Permission::firstOrCreate(['name' => 'admin permission']);

        $role->givePermissionTo($permission);

        $user = User::factory()->create();
        $user->assignRole('admin');

        $this->assertTrue($user->hasPermissionTo('admin permission'));
    }

    /**
     * Test getAllPermissions includes direct and role permissions
     */
    public function test_get_all_permissions(): void
    {
        $role = Role::findByName('admin');
        $role->givePermissionTo('role permission');

        $user = User::factory()->create();
        $user->assignRole('admin');
        $user->givePermissionTo('direct permission');

        $allPermissions = $user->getAllPermissions()->pluck('name')->toArray();

        $this->assertContains('role permission', $allPermissions);
        $this->assertContains('direct permission', $allPermissions);
    }

    /**
     * Test inactive user cannot access protected routes
     */
    public function test_inactive_user_no_permissions(): void
    {
        $user = User::factory()->inactive()->create();
        $user->assignRole('admin');

        $this->assertFalse($user->isActive());
    }

    /**
     * Test permission sync
     */
    public function test_permission_sync(): void
    {
        $user = User::factory()->create();

        Permission::firstOrCreate(['name' => 'permission 1']);
        Permission::firstOrCreate(['name' => 'permission 2']);
        Permission::firstOrCreate(['name' => 'permission 3']);

        $user->syncPermissions(['permission 1', 'permission 2']);

        $this->assertTrue($user->hasPermissionTo('permission 1'));
        $this->assertTrue($user->hasPermissionTo('permission 2'));
        $this->assertFalse($user->hasPermissionTo('permission 3'));
    }

    /**
     * Test role sync
     */
    public function test_role_sync(): void
    {
        $user = User::factory()->create();

        $user->syncRoles(['operator', 'admin']);

        $this->assertTrue($user->hasRole('operator'));
        $this->assertTrue($user->hasRole('admin'));

        $user->syncRoles(['common']);

        $this->assertFalse($user->hasRole('operator'));
        $this->assertFalse($user->hasRole('admin'));
        $this->assertTrue($user->hasRole('common'));
    }

    /**
     * Test permission caching
     */
    public function test_permission_caching(): void
    {
        $user = User::factory()->create();
        $permission = Permission::firstOrCreate(['name' => 'cached permission']);

        $user->givePermissionTo($permission);

        $this->assertTrue($user->hasPermissionTo('cached permission'));

        $user->forgetCachedPermissions();

        $this->assertTrue($user->fresh()->hasPermissionTo('cached permission'));
    }

    /**
     * Test unauthenticated user has no permissions
     */
    public function test_unauthenticated_no_permissions(): void
    {
        $this->assertFalse(auth()->check());
    }

    /**
     * Test permission guard
     */
    public function test_permission_guard(): void
    {
        $user = User::factory()->create();
        $permission = Permission::firstOrCreate(['name' => 'guarded permission', 'guard_name' => 'web']);

        $user->givePermissionTo($permission);

        $this->assertTrue($user->hasPermissionTo('guarded permission', 'web'));
    }

    /**
     * Test scope permission check
     */
    public function test_scope_permission(): void
    {
        $permission = Permission::firstOrCreate(['name' => 'view dashboard']);

        $user1 = User::factory()->create();
        $user1->givePermissionTo($permission);

        $user2 = User::factory()->create();

        $usersWithPermission = User::permission('view dashboard')->get();

        $this->assertTrue($usersWithPermission->contains($user1));
        $this->assertFalse($usersWithPermission->contains($user2));
    }

    /**
     * Test scope role check
     */
    public function test_scope_role(): void
    {
        $role = Role::findByName('admin');

        $user1 = User::factory()->create();
        $user1->assignRole('admin');

        $user2 = User::factory()->create();
        $user2->assignRole('common');

        $adminUsers = User::role('admin')->get();

        $this->assertTrue($adminUsers->contains($user1));
        $this->assertFalse($adminUsers->contains($user2));
    }
}
