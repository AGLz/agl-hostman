<?php

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;

beforeEach(function () {
    // Create admin user
    $admin = User::factory()->create([
        'email' => 'admin@test.com',
        'is_active' => true,
    ]);
    $admin->assignRole('admin');
    $this->admin = $admin;

    // Create regular user
    $user = User::factory()->create([
        'email' => 'user@test.com',
        'is_active' => true,
    ]);
    $user->assignRole('common');
    $this->user = $user;
});

test('admin can view roles list', function () {
    $response = $this->actingAs($this->admin)
        ->get(route('admin.roles.index'));

    $response->assertStatus(200);
});

test('user without permission cannot view roles list', function () {
    $response = $this->actingAs($this->user)
        ->get(route('admin.roles.index'));

    $response->assertStatus(403);
});

test('admin can create a custom role', function () {
    $response = $this->actingAs($this->admin)
        ->post(route('admin.roles.store'), [
            'name' => 'manager',
            'description' => 'Manager role with specific permissions',
            'permissions' => [],
        ]);

    $response->assertRedirect(route('admin.roles.index'));
    $this->assertDatabaseHas('roles', [
        'name' => 'manager',
        'is_system' => false,
    ]);
});

test('system role cannot be deleted', function () {
    $adminRole = Role::where('name', 'admin')->first();

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.roles.destroy', $adminRole));

    $response->assertRedirect();
    $response->assertSessionHas('error');
    $this->assertDatabaseHas('roles', [
        'name' => 'admin',
    ]);
});

test('system role cannot be modified', function () {
    $adminRole = Role::where('name', 'admin')->first();

    $response = $this->actingAs($this->admin)
        ->put(route('admin.roles.update', $adminRole), [
            'name' => 'super-admin',
            'description' => 'Modified description',
        ]);

    $response->assertRedirect();
    $response->assertSessionHas('error');
});

test('custom role can be deleted when no users assigned', function () {
    // Create custom role
    $role = Role::create([
        'name' => 'temporary',
        'guard_name' => 'web',
        'description' => 'Temporary role',
        'is_system' => false,
    ]);

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.roles.destroy', $role));

    $response->assertRedirect(route('admin.roles.index'));
    $this->assertDatabaseMissing('roles', [
        'name' => 'temporary',
    ]);
});

test('role with assigned users cannot be deleted', function () {
    // Create custom role
    $role = Role::create([
        'name' => 'with-users',
        'guard_name' => 'web',
        'description' => 'Role with users',
        'is_system' => false,
    ]);

    // Assign role to user
    $this->user->assignRole('with-users');

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.roles.destroy', $role));

    $response->assertRedirect();
    $response->assertSessionHas('error');
    $this->assertDatabaseHas('roles', [
        'name' => 'with-users',
    ]);
});

test('admin can assign permissions to role', function () {
    $role = Role::create([
        'name' => 'editor',
        'guard_name' => 'web',
        'description' => 'Editor role',
        'is_system' => false,
    ]);

    $permission = Permission::where('name', 'containers.view')->first();

    $response = $this->actingAs($this->admin)
        ->put(route('admin.roles.update', $role), [
            'name' => 'editor',
            'description' => 'Editor role',
            'permissions' => [$permission->id],
        ]);

    $response->assertRedirect(route('admin.roles.index'));
    $this->assertTrue($role->permissions()->where('id', $permission->id)->exists());
});

test('inactive user cannot access admin panel', function () {
    $this->user->update(['is_active' => false]);

    $response = $this->actingAs($this->user)
        ->get(route('admin.roles.index'));

    $response->assertStatus(403);
});
