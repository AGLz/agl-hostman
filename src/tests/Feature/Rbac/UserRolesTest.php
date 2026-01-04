<?php

use App\Models\User;
use App\Models\Role;
use App\Models\Permission;

beforeEach(function () {
    $admin = User::factory()->create([
        'email' => 'admin@test.com',
        'is_active' => true,
    ]);
    $admin->assignRole('admin');
    $this->admin = $admin;

    $user = User::factory()->create([
        'email' => 'user@test.com',
        'is_active' => true,
    ]);
    $this->user = $user;

    $this->testRole = Role::create([
        'name' => 'test-role',
        'guard_name' => 'web',
        'description' => 'Test role',
        'is_system' => false,
    ]);
});

test('admin can assign roles to user', function () {
    $response = $this->actingAs($this->admin)
        ->put(route('admin.users.roles.update', $this->user), [
            'roles' => [$this->testRole->id],
        ]);

    $response->assertRedirect();
    $this->assertTrue($this->user->hasRole('test-role'));
});

test('admin can remove role from user', function () {
    $this->user->assignRole('test-role');

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.users.roles.remove', [$this->user, $this->testRole]));

    $response->assertRedirect();
    $this->assertFalse($this->user->fresh()->hasRole('test-role'));
});

test('user can have multiple roles', function () {
    $role1 = Role::create([
        'name' => 'role-1',
        'guard_name' => 'web',
        'description' => 'First role',
        'is_system' => false,
    ]);

    $role2 = Role::create([
        'name' => 'role-2',
        'guard_name' => 'web',
        'description' => 'Second role',
        'is_system' => false,
    ]);

    $this->actingAs($this->admin)
        ->put(route('admin.users.roles.update', $this->user), [
            'roles' => [$role1->id, $role2->id],
        ]);

    $this->assertTrue($this->user->fresh()->hasRole('role-1'));
    $this->assertTrue($this->user->fresh()->hasRole('role-2'));
});

test('admin can grant direct permission to user', function () {
    $permission = Permission::where('name', 'containers.create')->first();

    $response = $this->actingAs($this->admin)
        ->put(route('admin.users.permissions.update', $this->user), [
            'permissions' => [$permission->id],
        ]);

    $response->assertRedirect();
    $this->assertTrue($this->user->fresh()->hasPermissionTo('containers.create'));
});

test('direct permission is independent of role permissions', function () {
    // Give user 'common' role (read-only)
    $this->user->assignRole('common');

    // Grant direct permission to create containers
    $permission = Permission::where('name', 'containers.create')->first();

    $this->actingAs($this->admin)
        ->put(route('admin.users.permissions.update', $this->user), [
            'permissions' => [$permission->id],
        ]);

    // User should have the direct permission even though common role doesn't
    $this->assertTrue($this->user->fresh()->hasPermissionTo('containers.create'));
});

test('admin can remove direct permission from user', function () {
    $permission = Permission::where('name', 'containers.delete')->first();
    $this->user->givePermissionTo($permission);

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.users.permissions.remove', [$this->user, $permission]));

    $response->assertRedirect();
    $this->assertFalse($this->user->fresh()->hasPermissionTo('containers.delete'));
});

test('user access summary shows all permissions from roles', function () {
    $this->user->assignRole('advanced');

    $response = $this->actingAs($this->admin)
        ->get(route('admin.users.access', $this->user));

    $response->assertStatus(200);
    $response->assertViewHas('allPermissions');
});

test('user access summary includes direct permissions', function () {
    $permission = Permission::where('name', 'servers.manage')->first();
    $this->user->givePermissionTo($permission);

    $response = $this->actingAs($this->admin)
        ->get(route('admin.users.access', $this->user));

    $response->assertStatus(200);
    $allPermissions = $response->viewData('allPermissions');
    $this->assertTrue($allPermissions->contains('name', 'servers.manage'));
});

test('inactive user permissions return false', function () {
    $this->user->assignRole('admin');
    $this->user->update(['is_active' => false]);

    $this->assertFalse($this->user->hasPermissionTo('containers.create'));
});

test('user with admin role has all permissions', function () {
    $this->user->assignRole('admin');
    $this->user->refresh();

    $this->assertTrue($this->user->hasPermissionTo('containers.create'));
    $this->assertTrue($this->user->hasPermissionTo('users.delete'));
    $this->assertTrue($this->user->hasPermissionTo('infrastructure.network'));
});
