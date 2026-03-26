<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\ApiKey;
use App\Models\PhysicalLocation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * User Model Test
 *
 * Tests for the User model.
 */
class UserModelTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test creating a user
     */
    public function test_create_user(): void
    {
        $user = User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@example.com',
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Test User',
            'email' => 'test@example.com',
        ]);
    }

    /**
     * Test user has many API keys
     */
    public function test_user_has_many_api_keys(): void
    {
        $user = User::factory()->create();
        ApiKey::factory()->count(3)->create([
            'user_id' => $user->id,
        ]);

        $this->assertCount(3, $user->apiKeys);
        $this->assertInstanceOf(ApiKey::class, $user->apiKeys->first());
    }

    /**
     * Test user belongs to many locations
     */
    public function test_user_belongs_to_many_locations(): void
    {
        $user = User::factory()->create();
        $location1 = PhysicalLocation::factory()->create();
        $location2 = PhysicalLocation::factory()->create();

        $user->physicalLocations()->attach($location1->id, ['access_level' => 'admin']);
        $user->physicalLocations()->attach($location2->id, ['access_level' => 'viewer']);

        $this->assertCount(2, $user->physicalLocations);
        $this->assertInstanceOf(PhysicalLocation::class, $user->physicalLocations->first());
    }

    /**
     * Test user has roles via Spatie permission
     */
    public function test_user_has_roles(): void
    {
        $user = User::factory()->create();

        $role = \Spatie\Permission\Models\Role::create(['name' => 'admin']);
        $user->assignRole($role);

        $this->assertTrue($user->hasRole('admin'));
    }

    /**
     * Test user has permissions via Spatie permission
     */
    public function test_user_has_permissions(): void
    {
        $user = User::factory()->create();

        $permission = \Spatie\Permission\Models\Permission::create(['name' => 'edit containers']);
        $user->givePermissionTo($permission);

        $this->assertTrue($user->hasPermissionTo('edit containers'));
    }

    /**
     * Test is active scope
     */
    public function test_is_active_scope(): void
    {
        User::factory()->create(['is_active' => true]);
        User::factory()->create(['is_active' => false]);

        $activeUsers = User::active()->get();

        $this->assertCount(1, $activeUsers);
        $this->assertTrue($activeUsers->first()->is_active);
    }

    /**
     * Test is inactive scope
     */
    public function test_is_inactive_scope(): void
    {
        User::factory()->create(['is_active' => true]);
        User::factory()->create(['is_active' => false]);

        $inactiveUsers = User::inactive()->get();

        $this->assertCount(1, $inactiveUsers);
        $this->assertFalse($inactiveUsers->first()->is_active);
    }

    /**
     * Test search by name or email
     */
    public function test_search_by_name_or_email(): void
    {
        User::factory()->create([
            'name' => 'John Doe',
            'email' => 'john@example.com',
        ]);

        User::factory()->create([
            'name' => 'Jane Smith',
            'email' => 'jane@example.com',
        ]);

        $results = User::search('John')->get();

        $this->assertCount(1, $results);
        $this->assertEquals('John Doe', $results->first()->name);
    }

    /**
     * Test fillable attributes
     */
    public function test_fillable_attributes(): void
    {
        $user = new User;

        $expectedFillable = [
            'name',
            'email',
            'password',
            'avatar_url',
            'is_active',
            'last_login_at',
            'email_verified_at',
            'terms_accepted_at',
        ];

        foreach ($expectedFillable as $attribute) {
            $this->assertContains($attribute, $user->getFillable());
        }
    }

    /**
     * Test hidden attributes
     */
    public function test_hidden_attributes(): void
    {
        $user = new User;

        $this->assertContains('password', $user->getHidden());
        $this->assertContains('remember_token', $user->getHidden());
    }

    /**
     * Test casts configuration
     */
    public function test_casts_configuration(): void
    {
        $user = new User;

        $this->assertArrayHasKey('email_verified_at', $user->getCasts());
        $this->assertArrayHasKey('last_login_at', $user->getCasts());
        $this->assertArrayHasKey('terms_accepted_at', $user->getCasts());
        $this->assertArrayHasKey('is_active', $user->getCasts());
    }

    /**
     * Test password hashing
     */
    public function test_password_hashing(): void
    {
        $plainPassword = 'secret-password';
        $user = User::factory()->create([
            'password' => $plainPassword,
        ]);

        $this->assertNotEquals($plainPassword, $user->password);
        $this->assertTrue(\Hash::check($plainPassword, $user->password));
    }

    /**
     * Test has verified email
     */
    public function test_has_verified_email(): void
    {
        $user = User::factory()->create([
            'email_verified_at' => now(),
        ]);

        $this->assertNotNull($user->email_verified_at);
    }

    /**
     * Test unverified email
     */
    public function test_unverified_email(): void
    {
        $user = User::factory()->create([
            'email_verified_at' => null,
        ]);

        $this->assertNull($user->email_verified_at);
    }

    /**
     * Test accepted terms
     */
    public function test_accepted_terms(): void
    {
        $user = User::factory()->create([
            'terms_accepted_at' => now(),
        ]);

        $this->assertNotNull($user->terms_accepted_at);
    }

    /**
     * Test user activation
     */
    public function test_user_activation(): void
    {
        $user = User::factory()->create(['is_active' => false]);

        $user->activate();

        $this->assertTrue($user->is_active);
        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'is_active' => true,
        ]);
    }

    /**
     * Test user deactivation
     */
    public function test_user_deactivation(): void
    {
        $user = User::factory()->create(['is_active' => true]);

        $user->deactivate();

        $this->assertFalse($user->is_active);
        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'is_active' => false,
        ]);
    }

    /**
     * Test last login update
     */
    public function test_update_last_login(): void
    {
        $user = User::factory()->create();

        $user->updateLastLogin();

        $this->assertNotNull($user->last_login_at);
        $this->assertLessThanOrEqual(5, now()->diffInSeconds($user->last_login_at));
    }

    /**
     * Test scope by role
     */
    public function test_scope_by_role(): void
    {
        $adminRole = \Spatie\Permission\Models\Role::create(['name' => 'admin']);
        $userRole = \Spatie\Permission\Models\Role::create(['name' => 'user']);

        $admin = User::factory()->create();
        $regularUser = User::factory()->create();

        $admin->assignRole($adminRole);
        $regularUser->assignRole($userRole);

        $adminUsers = User::byRole('admin')->get();

        $this->assertCount(1, $adminUsers);
        $this->assertEquals($admin->id, $adminUsers->first()->id);
    }

    /**
     * Test scope with permission
     */
    public function test_scope_with_permission(): void
    {
        $permission = \Spatie\Permission\Models\Permission::create(['name' => 'edit containers']);

        $userWithPermission = User::factory()->create();
        $userWithoutPermission = User::factory()->create();

        $userWithPermission->givePermissionTo($permission);

        $users = User::withPermission('edit containers')->get();

        $this->assertCount(1, $users);
        $this->assertEquals($userWithPermission->id, $users->first()->id);
    }
}
