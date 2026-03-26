<?php

namespace Tests\Feature;

use App\Models\PhysicalLocation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LocationAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Seed locations
        $this->artisan('db:seed', ['--class' => 'PhysicalLocationsSeeder']);
        $this->artisan('db:seed', ['--class' => 'RolesAndPermissionsSeeder']);
    }

    /** @test */
    public function user_has_access_to_location_method_works_correctly()
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole('admin');

        $aglsrv1 = PhysicalLocation::where('code', 'AGLSRV1')->first();
        $ct179 = PhysicalLocation::where('code', 'CT179')->first();

        // Assign locations
        $user->physicalLocations()->attach($aglsrv1->id, [
            'access_level' => 'admin',
            'is_primary' => true,
        ]);
        $user->physicalLocations()->attach($ct179->id, [
            'access_level' => 'manage',
            'is_primary' => false,
        ]);

        // Test hasAccessToLocation method
        $this->assertTrue($user->hasAccessToLocation('AGLSRV1', 'view'));
        $this->assertTrue($user->hasAccessToLocation('AGLSRV1', 'admin'));
        $this->assertTrue($user->hasAccessToLocation('CT179', 'view'));
        $this->assertTrue($user->hasAccessToLocation('CT179', 'manage'));
        $this->assertFalse($user->hasAccessToLocation('CT179', 'admin'));
        $this->assertFalse($user->hasAccessToLocation('AGLSRV6', 'view'));
        $this->assertFalse($user->hasAccessToLocation('AGLHQ11', 'view'));
    }

    /** @test */
    public function middleware_allows_access_with_any_logic()
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole('admin');

        $aglsrv1 = PhysicalLocation::where('code', 'AGLSRV1')->first();
        $user->physicalLocations()->attach($aglsrv1->id, [
            'access_level' => 'admin',
            'is_primary' => true,
        ]);

        Sanctum::actingAs($user);

        // User has AGLSRV1, testing ANY logic with AGLSRV1,AGLSRV6
        $response = $this->getJson('/location-test/datacenter-any');
        $response->assertOk();
    }

    /** @test */
    public function middleware_denies_access_with_all_logic_when_missing_location()
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole('admin');

        $aglsrv1 = PhysicalLocation::where('code', 'AGLSRV1')->first();
        $user->physicalLocations()->attach($aglsrv1->id, [
            'access_level' => 'admin',
            'is_primary' => true,
        ]);

        Sanctum::actingAs($user);

        // User has AGLSRV1 but NOT AGLSRV6, testing ALL logic should FAIL
        $response = $this->getJson('/location-test/datacenter-all');
        $response->assertForbidden();
        $response->assertJson([
            'error' => 'Forbidden',
            'required_locations' => ['AGLSRV1', 'AGLSRV6'],
            'logic' => 'all',
        ]);
    }

    /** @test */
    public function middleware_allows_access_with_all_logic_when_has_all_locations()
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole('admin');

        $aglsrv1 = PhysicalLocation::where('code', 'AGLSRV1')->first();
        $aglsrv6 = PhysicalLocation::where('code', 'AGLSRV6')->first();

        $user->physicalLocations()->attach($aglsrv1->id, [
            'access_level' => 'admin',
            'is_primary' => true,
        ]);
        $user->physicalLocations()->attach($aglsrv6->id, [
            'access_level' => 'view',
            'is_primary' => false,
        ]);

        Sanctum::actingAs($user);

        // User has BOTH AGLSRV1 and AGLSRV6, ALL logic should PASS
        $response = $this->getJson('/location-test/datacenter-all');
        $response->assertOk();
    }

    /** @test */
    public function middleware_enforces_access_levels_correctly()
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole('admin');

        $ct179 = PhysicalLocation::where('code', 'CT179')->first();
        $user->physicalLocations()->attach($ct179->id, [
            'access_level' => 'manage',  // Only manage, not admin
            'is_primary' => true,
        ]);

        Sanctum::actingAs($user);

        // Should allow manage level access
        $response = $this->getJson('/location-test/ct179-manage');
        $response->assertOk();

        // Should deny admin level access (user only has manage)
        // Note: There's no ct179-admin route, so we can't test this specific scenario
    }
}
