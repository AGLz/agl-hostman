<?php

declare(strict_types=1);

use App\Http\Controllers\Auth\WorkOSController;
use App\Models\PhysicalLocation;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use WorkOS\Resource\AuthenticationResponse;
use WorkOS\UserManagement;

uses(RefreshDatabase::class);

covers(WorkOSController::class);

describe('Authentication', function () {
    beforeEach(function () {
        $this->seed(RolesAndPermissionsSeeder::class);
    });

    it('redirects to WorkOS login page', function () {
        $response = $this->get('/auth/workos/redirect');

        $response->assertRedirect();
        $location = (string) $response->headers->get('Location');
        expect($location)->toContain('workos.com');
        expect($location)->toContain('authorize');
    });

    it('handles WorkOS callback successfully', function () {
        $auth = AuthenticationResponse::constructFromResponse([
            'user' => [
                'object' => 'user',
                'id' => 'user_01workostest',
                'email' => 'test@agl.com',
                'first_name' => 'Test',
                'last_name' => 'User',
                'email_verified' => true,
                'profile_picture_url' => null,
                'last_sign_in_at' => null,
                'created_at' => '2025-01-01T00:00:00Z',
                'updated_at' => '2025-01-01T00:00:00Z',
                'external_id' => null,
                'metadata' => null,
            ],
            'access_token' => 'test-access-token',
            'refresh_token' => 'test-refresh-token',
        ]);

        $mock = Mockery::mock(UserManagement::class);
        $mock->shouldReceive('authenticateWithCode')
            ->once()
            ->with('test_client_id', 'test-code')
            ->andReturn($auth);

        $this->app->instance(UserManagement::class, $mock);

        $response = $this->get('/auth/workos/callback?code=test-code');

        $response->assertRedirect('/dashboard');
        $this->assertAuthenticatedAs(User::where('email', 'test@agl.com')->first());
    });

    it('enforces RBAC permissions for admin routes', function () {
        $commonUser = User::factory()->create();
        $commonUser->assignRole('common');

        $adminUser = User::factory()->create();
        $adminUser->assignRole('admin');

        $this->actingAs($commonUser)
            ->get('/admin/users')
            ->assertForbidden();

        $this->actingAs($adminUser)
            ->get('/admin/users')
            ->assertRedirect(route('dashboard'));
    });

    it('exige autenticação Sanctum para API de infraestrutura', function () {
        PhysicalLocation::create([
            'code' => 'AGLSRV1',
            'name' => 'AGL Server 1',
            'type' => 'datacenter',
        ]);

        $this->getJson('/api/infrastructure/servers/AGLSRV1')
            ->assertUnauthorized();

        $user = User::factory()->create();
        $user->assignRole('common');

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/infrastructure/servers/AGLSRV1')
            ->assertOk();
    });

    it('logs out user correctly', function () {
        $user = User::factory()->create();
        $this->actingAs($user);

        $response = $this->post('/logout');

        $response->assertRedirect('/');
        $this->assertGuest();
    });

    it('expõe password.request e redireciona para o login', function () {
        $this->get('/auth/forgot-password')
            ->assertRedirect(route('login'));
    });
});
