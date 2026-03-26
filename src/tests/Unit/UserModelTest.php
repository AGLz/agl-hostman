<?php

declare(strict_types=1);

use App\Models\PhysicalLocation;
use App\Models\User;
use Illuminate\Support\Facades\DB;

describe('User Model', function () {
    beforeEach(function () {
        // Enable query log for N+1 detection
        DB::enableQueryLog();
    });

    afterEach(function () {
        DB::disableQueryLog();
    });

    it('prevents N+1 query when accessing primary location', function () {
        // Arrange: Create users with locations
        $users = User::factory()
            ->count(10)
            ->has(PhysicalLocation::factory()->state(['is_primary' => true]))
            ->create();

        DB::flushQueryLog();

        // Act: Load users with eager loading
        $loadedUsers = User::withPrimaryLocation()->get();

        $queryCount = count(DB::getQueryLog());

        // Act: Access primary locations (should not trigger additional queries)
        foreach ($loadedUsers as $user) {
            $location = $user->primaryLocation;
        }

        // Assert: Should have 2 queries total (1 for users + 1 for pivot join)
        expect($queryCount)->toBeLessThanOrEqual(2)
            ->and(DB::getQueryLog())->toHaveCount($queryCount);
    });

    it('returns null when no primary location exists', function () {
        // Arrange
        $user = User::factory()->create();

        // Act & Assert
        expect($user->primaryLocation)->toBeNull();
    });

    it('caches primary location when relation is loaded', function () {
        // Arrange
        $user = User::factory()
            ->has(PhysicalLocation::factory()->state(['is_primary' => true]))
            ->create();

        // Act: Load user with eager loading
        $loadedUser = User::withPrimaryLocation()->find($user->id);

        DB::flushQueryLog();

        // Access primary location multiple times
        $location1 = $loadedUser->primaryLocation;
        $location2 = $loadedUser->primaryLocation;
        $location3 = $loadedUser->primaryLocation;

        // Assert: No additional queries should be executed
        expect(DB::getQueryLog())->toBeEmpty()
            ->and($location1)->toBe($location2)
            ->and($location2)->toBe($location3);
    });

    it('has many physical locations relationship', function () {
        // Arrange
        $user = User::factory()
            ->has(PhysicalLocation::factory()->count(3))
            ->create();

        // Act & Assert
        expect($user->physicalLocations)->toHaveCount(3)
            ->and($user->physicalLocations->first())->toBeInstanceOf(PhysicalLocation::class);
    });

    it('validates required fields', function () {
        $this->expectException(\Illuminate\Database\QueryException::class);

        User::create([
            'name' => null, // Invalid
            'email' => 'test@example.com',
        ]);
    });
});
