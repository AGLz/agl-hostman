<?php

use Illuminate\Support\Facades\Route;
use App\Models\PhysicalLocation;

/*
|--------------------------------------------------------------------------
| Location Access Test Routes
|--------------------------------------------------------------------------
|
| These routes test the CheckLocationAccess middleware and location-based
| access control system.
|
| Usage:
|   1. Seed locations: php artisan db:seed --class=PhysicalLocationsSeeder
|   2. Create test user and assign location access
|   3. Test routes below with various location requirements
*/

Route::prefix('location-test')->middleware(['web'])->group(function () {

    // Test: Public route (no auth or location required)
    Route::get('/public', function () {
        return response()->json([
            'message' => 'Public route - No authentication or location required',
            'authenticated' => auth()->check(),
            'all_locations' => PhysicalLocation::active()->get(['code', 'name', 'type']),
        ]);
    });

    // Test: List all physical locations
    Route::get('/locations', function () {
        $locations = PhysicalLocation::active()->get();

        return response()->json([
            'message' => 'All active physical locations',
            'count' => $locations->count(),
            'locations' => $locations->map(function ($location) {
                return [
                    'code' => $location->code,
                    'name' => $location->name,
                    'type' => $location->type,
                    'type_label' => $location->getTypeLabel(),
                    'ip_range' => $location->ip_range,
                    'networks' => $location->metadata['networks'] ?? [],
                    'is_active' => $location->is_active,
                ];
            }),
        ]);
    });

    // Test: Authenticated user's location access
    Route::get('/my-locations', function () {
        $user = auth()->user();

        return response()->json([
            'message' => 'Your accessible locations',
            'user' => $user->only(['id', 'name', 'email']),
            'locations' => $user->physicalLocations->map(function ($location) {
                return [
                    'code' => $location->code,
                    'name' => $location->name,
                    'access_level' => $location->pivot->access_level,
                    'is_primary' => $location->pivot->is_primary,
                ];
            }),
            'primary_location' => $user->primary_location?->only(['code', 'name']),
            'has_admin_access' => $user->hasAdminAccess(),
        ]);
    })->middleware('auth:sanctum');

    // Test: Single location access - AGLSRV1
    Route::get('/aglsrv1-only', function () {
        return response()->json([
            'message' => 'AGLSRV1 datacenter access',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'location' => PhysicalLocation::byCode('AGLSRV1')->first()?->only(['code', 'name', 'type']),
        ]);
    })->middleware(['auth:sanctum', 'location:AGLSRV1']);

    // Test: Multiple locations with ANY logic
    Route::get('/datacenter-any', function () {
        return response()->json([
            'message' => 'Access to ANY datacenter (AGLSRV1 OR AGLSRV6)',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'user_locations' => auth()->user()->physicalLocations->pluck('code'),
        ]);
    })->middleware(['auth:sanctum', 'location:AGLSRV1,AGLSRV6|any']);

    // Test: Multiple locations with ALL logic
    Route::get('/datacenter-all', function () {
        return response()->json([
            'message' => 'Access to ALL datacenters (AGLSRV1 AND AGLSRV6)',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'user_locations' => auth()->user()->physicalLocations->pluck('code'),
        ]);
    })->middleware(['auth:sanctum', 'location:AGLSRV1,AGLSRV6|all']);

    // Test: Container access - CT179
    Route::get('/ct179-dev', function () {
        return response()->json([
            'message' => 'CT179 development container access',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'location' => PhysicalLocation::byCode('CT179')->first()?->only(['code', 'name', 'metadata']),
        ]);
    })->middleware(['auth:sanctum', 'location:CT179']);

    // Test: Container access - CT183 Archon
    Route::get('/ct183-archon', function () {
        return response()->json([
            'message' => 'CT183 Archon AI Command Center access',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'location' => PhysicalLocation::byCode('CT183')->first()?->only(['code', 'name', 'metadata']),
        ]);
    })->middleware(['auth:sanctum', 'location:CT183']);

    // Test: Headquarters access - AGLHQ11
    Route::get('/headquarters', function () {
        return response()->json([
            'message' => 'AGLHQ11 headquarters access',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'location' => PhysicalLocation::byCode('AGLHQ11')->first()?->only(['code', 'name', 'metadata']),
        ]);
    })->middleware(['auth:sanctum', 'location:AGLHQ11']);

    // Test: Admin level access required
    Route::get('/aglsrv1-admin', function () {
        return response()->json([
            'message' => 'AGLSRV1 admin access required',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'access_level' => auth()->user()->physicalLocations()
                ->where('code', 'AGLSRV1')
                ->first()?->pivot->access_level,
        ]);
    })->middleware(['auth:sanctum', 'location:AGLSRV1|admin']);

    // Test: Manage level access required
    Route::get('/ct179-manage', function () {
        return response()->json([
            'message' => 'CT179 manage access required',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'access_level' => auth()->user()->physicalLocations()
                ->where('code', 'CT179')
                ->first()?->pivot->access_level,
        ]);
    })->middleware(['auth:sanctum', 'location:CT179|manage']);

    // Test: Combined - Role + Location
    Route::get('/admin-with-datacenter', function () {
        return response()->json([
            'message' => 'Admin role WITH datacenter access',
            'user' => auth()->user()->only(['id', 'name', 'email']),
            'roles' => auth()->user()->roles->pluck('name'),
            'locations' => auth()->user()->physicalLocations->pluck('code'),
        ]);
    })->middleware(['auth:sanctum', 'role:admin', 'location:AGLSRV1,AGLSRV6|any']);

    // Helper: Assign location access to user
    Route::post('/assign-location', function (Illuminate\Http\Request $request) {
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'location_code' => 'required|exists:physical_locations,code',
            'access_level' => 'required|in:view,manage,admin',
            'is_primary' => 'boolean',
        ]);

        $user = \App\Models\User::findOrFail($request->user_id);
        $location = PhysicalLocation::where('code', $request->location_code)->firstOrFail();

        $user->physicalLocations()->syncWithoutDetaching([
            $location->id => [
                'access_level' => $request->access_level,
                'is_primary' => $request->is_primary ?? false,
            ]
        ]);

        return response()->json([
            'message' => 'Location access assigned',
            'user' => $user->only(['id', 'name', 'email']),
            'location' => $location->only(['code', 'name']),
            'access_level' => $request->access_level,
            'is_primary' => $request->is_primary ?? false,
        ]);
    });

    // Helper: Remove location access from user
    Route::post('/remove-location', function (Illuminate\Http\Request $request) {
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'location_code' => 'required|exists:physical_locations,code',
        ]);

        $user = \App\Models\User::findOrFail($request->user_id);
        $location = PhysicalLocation::where('code', $request->location_code)->firstOrFail();

        $user->physicalLocations()->detach($location->id);

        return response()->json([
            'message' => 'Location access removed',
            'user' => $user->only(['id', 'name', 'email']),
            'location' => $location->only(['code', 'name']),
        ]);
    });

    // Helper: Check IP range matching
    Route::post('/check-ip-range', function (Illuminate\Http\Request $request) {
        $request->validate([
            'location_code' => 'required|exists:physical_locations,code',
            'ip_address' => 'required|ip',
        ]);

        $location = PhysicalLocation::where('code', $request->location_code)->firstOrFail();
        $inRange = $location->isIpInRange($request->ip_address);

        return response()->json([
            'message' => 'IP range check',
            'location' => $location->only(['code', 'name', 'ip_range']),
            'ip_address' => $request->ip_address,
            'in_range' => $inRange,
        ]);
    });

    // Helper: Get location access levels
    Route::get('/access-levels', function () {
        return response()->json([
            'message' => 'Available access levels',
            'levels' => \App\Http\Middleware\CheckLocationAccess::getAccessLevels(),
        ]);
    });
});
