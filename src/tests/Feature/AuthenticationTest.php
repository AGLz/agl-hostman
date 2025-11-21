<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Support\Facades\Session;

describe('Authentication', function () {
    it('redirects to WorkOS login page', function () {
        // Act
        $response = $this->get('/auth/workos/redirect');

        // Assert
        $response->assertRedirect();
        expect($response->headers->get('Location'))
            ->toContain('workos.com/sso/authorize');
    });

    it('handles WorkOS callback successfully', function () {
        // Arrange: Mock WorkOS response
        $this->mock(\WorkOS\WorkOS::class, function ($mock) {
            $mock->shouldReceive('sso->getProfileAndToken')
                ->andReturn([
                    'profile' => [
                        'email' => 'test@agl.com',
                        'first_name' => 'Test',
                        'last_name' => 'User',
                    ],
                ]);
        });

        // Act
        $response = $this->get('/auth/workos/callback?code=test-code');

        // Assert
        $response->assertRedirect('/dashboard');
        $this->assertAuthenticatedAs(User::where('email', 'test@agl.com')->first());
    });

    it('enforces RBAC permissions for admin routes', function () {
        // Arrange
        $commonUser = User::factory()->create(['role' => 'common']);
        $adminUser = User::factory()->create(['role' => 'admin']);

        // Act & Assert: Common user denied
        $this->actingAs($commonUser)
            ->get('/admin/users')
            ->assertForbidden();

        // Admin user allowed
        $this->actingAs($adminUser)
            ->get('/admin/users')
            ->assertOk();
    });

    it('restricts access based on physical location permissions', function () {
        // Arrange
        $location = PhysicalLocation::factory()->create(['code' => 'AGLSRV1']);
        $user = User::factory()->create(['role' => 'common']);

        // User has permission only for AGLSRV1
        $user->physicalLocations()->attach($location, ['can_manage' => false]);

        // Act & Assert: Can view AGLSRV1
        $this->actingAs($user)
            ->get("/api/infrastructure/servers/AGLSRV1")
            ->assertOk();

        // Cannot view AGLSRV2 (no permission)
        $this->actingAs($user)
            ->get("/api/infrastructure/servers/AGLSRV2")
            ->assertForbidden();
    });

    it('logs out user correctly', function () {
        // Arrange
        $user = User::factory()->create();
        $this->actingAs($user);

        // Act
        $response = $this->post('/logout');

        // Assert
        $response->assertRedirect('/');
        $this->assertGuest();
    });
});
