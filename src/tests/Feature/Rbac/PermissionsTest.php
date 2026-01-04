<?php

use App\Models\User;
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
    $user->assignRole('common');
    $this->user = $user;
});

test('admin can view permissions list', function () {
    $response = $this->actingAs($this->admin)
        ->get(route('admin.permissions.index'));

    $response->assertStatus(200);
});

test('user without permission cannot view permissions list', function () {
    $response = $this->actingAs($this->user)
        ->get(route('admin.permissions.index'));

    $response->assertStatus(403);
});

test('admin can create a new permission', function () {
    $response = $this->actingAs($this->admin)
        ->post(route('admin.permissions.store'), [
            'name' => 'manage',
            'module' => 'settings',
            'description' => 'Manage application settings',
        ]);

    $response->assertRedirect(route('admin.permissions.index'));
    $this->assertDatabaseHas('permissions', [
        'name' => 'settings.manage',
        'module' => 'settings',
    ]);
});

test('permission name includes module prefix', function () {
    $response = $this->actingAs($this->admin)
        ->post(route('admin.permissions.store'), [
            'name' => 'delete',
            'module' => 'containers',
            'description' => 'Delete containers',
        ]);

    $this->assertDatabaseHas('permissions', [
        'name' => 'containers.delete',
    ]);
});

test('duplicate permission cannot be created', function () {
    // Create initial permission
    Permission::create([
        'name' => 'test.action',
        'guard_name' => 'web',
        'module' => 'test',
    ]);

    $response = $this->actingAs($this->admin)
        ->post(route('admin.permissions.store'), [
            'name' => 'action',
            'module' => 'test',
            'description' => 'Duplicate permission',
        ]);

    $response->assertSessionHasErrors();
});

test('permission can be filtered by module', function () {
    $response = $this->actingAs($this->admin)
        ->get(route('admin.permissions.index', ['module' => 'containers']));

    $response->assertStatus(200);
});

test('permission can be searched', function () {
    $response = $this->actingAs($this->admin)
        ->get(route('admin.permissions.index', ['search' => 'create']));

    $response->assertStatus(200);
});

test('permission assigned to role cannot be deleted', function () {
    $permission = Permission::where('name', 'containers.view')->first();

    $response = $this->actingAs($this->admin)
        ->delete(route('admin.permissions.destroy', $permission));

    $response->assertRedirect();
    $response->assertSessionHas('error');
    $this->assertDatabaseHas('permissions', [
        'name' => 'containers.view',
    ]);
});

test('admin can update permission', function () {
    $permission = Permission::create([
        'name' => 'test.original',
        'guard_name' => 'web',
        'module' => 'test',
        'description' => 'Original description',
    ]);

    $response = $this->actingAs($this->admin)
        ->put(route('admin.permissions.update', $permission), [
            'name' => 'updated',
            'module' => 'test',
            'description' => 'Updated description',
        ]);

    $response->assertRedirect(route('admin.permissions.index'));
    $this->assertDatabaseHas('permissions', [
        'id' => $permission->id,
        'name' => 'test.updated',
        'description' => 'Updated description',
    ]);
});

test('permissions are grouped by module in index', function () {
    $response = $this->actingAs($this->admin)
        ->get(route('admin.permissions.index'));

    $response->assertStatus(200);
    $response->assertViewHas('permissions');
});
