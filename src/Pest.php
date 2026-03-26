<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
|
| The closure you provide to your test functions is always bound to a specific PHPUnit test
| case class. By default, that class is "PHPUnit\Framework\TestCase". Of course, you may
| need to change it using the "uses()" function to bind a different classes or traits.
|
*/

uses(TestCase::class)
    ->in('Feature', 'Unit', 'Integration', 'Architecture', 'Performance');

/*
|--------------------------------------------------------------------------
| Traits
|--------------------------------------------------------------------------
|
| Configure traits that should be used globally across all tests.
| RefreshDatabase: Refreshes database after each test (slower but safer)
| LazilyRefreshDatabase: Only refreshes when database is accessed (faster)
| DatabaseTransactions: Wraps each test in a transaction and rolls back
|
*/

// Use LazilyRefreshDatabase for better performance
uses(LazilyRefreshDatabase::class)
    ->in('Feature', 'Integration');

// Use DatabaseTransactions for faster execution when possible
uses(DatabaseTransactions::class)
    ->in('Unit');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
|
| When you're writing tests, you often need to check that values meet certain conditions. The
| "expect()" function gives you access to a set of "expectations" methods that you can use
| to assert different things. Of course, you may extend the Expectation API at any time.
|
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

expect()->extend('toBeValidUuid', function () {
    return $this->toMatch('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i');
});

expect()->extend('toBeValidApiResponse', function () {
    return $this->toHaveKeys(['success', 'data']);
});

expect()->extend('toBeWithinResponseTime', function (int $milliseconds = 200) {
    return $this->toBeLessThan($milliseconds);
});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
|
| While Pest is very powerful out-of-the-box, you may have some testing code specific to your
| project that you don't want to repeat in every file. Here you can also expose helpers as
| global functions to help you to reduce the number of lines of code in your test files.
|
*/

/**
 * Create a mock Proxmox API response
 */
function mockProxmoxResponse(array $data = [], bool $success = true): array
{
    return [
        'success' => $success,
        'data' => $data,
        'timestamp' => now()->timestamp,
    ];
}

/**
 * Create a test user with specific roles
 */
function createTestUser(array $attributes = [], array $roles = []): \App\Models\User
{
    $user = \App\Models\User::factory()->create($attributes);

    if (! empty($roles)) {
        foreach ($roles as $role) {
            $user->assignRole($role);
        }
    }

    return $user;
}

/**
 * Create authenticated user and return bearer token
 */
function authenticateUser(?\App\Models\User $user = null): string
{
    $user = $user ?? \App\Models\User::factory()->create();

    return $user->createToken('test-token')->plainTextToken;
}

/**
 * Mock external API call
 */
function mockExternalApi(string $service, string $endpoint, array $response): void
{
    \Illuminate\Support\Facades\Http::fake([
        $endpoint => \Illuminate\Support\Facades\Http::response($response, 200),
    ]);
}

/**
 * Create a test container metrics data
 */
function containerMetrics(array $overrides = []): array
{
    return array_merge([
        'cpu_usage' => 45.5,
        'memory_usage' => 1024,
        'memory_total' => 2048,
        'disk_usage' => 5120,
        'disk_total' => 10240,
        'network_in' => 1024,
        'network_out' => 2048,
        'uptime' => 86400,
        'status' => 'running',
    ], $overrides);
}

/**
 * Create test N8N webhook payload
 */
function n8nWebhookPayload(array $data = []): array
{
    return [
        'event' => 'container.health.check',
        'timestamp' => now()->toIso8601String(),
        'data' => $data,
        'source' => 'n8n-webhook',
    ];
}

/**
 * Assert that a job was dispatched with specific data
 */
function assertJobDispatched(string $jobClass, ?callable $callback = null): void
{
    \Illuminate\Support\Facades\Queue::assertPushed($jobClass, $callback);
}

/**
 * Create VCR cassette for recording HTTP interactions
 */
function recordHttpInteraction(string $name, callable $callback): mixed
{
    // For now, use Http::fake for mocking
    // Can be replaced with proper VCR implementation
    return $callback();
}

/**
 * Benchmark a closure and return execution time in milliseconds
 */
function benchmark(callable $callback): float
{
    $start = microtime(true);
    $callback();
    $end = microtime(true);

    return ($end - $start) * 1000; // Convert to milliseconds
}

/**
 * Create test database with seed data
 */
function seedTestDatabase(): void
{
    \Illuminate\Support\Facades\Artisan::call('db:seed', [
        '--class' => 'Tests\\Database\\Seeders\\TestDatabaseSeeder',
    ]);
}
