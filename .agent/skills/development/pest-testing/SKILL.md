---
name: pest-testing
description: Pest PHP testing framework patterns including unit vs integration tests, mocking, factories, and test organization
category: development
tags: [php, testing, pest, tdd, quality]
when_to_use: |
  Use this skill when:
  - Writing unit tests for services, models, or utilities
  - Creating integration tests for API endpoints
  - Setting up test fixtures and factories
  - Mocking external dependencies
  - Organizing test suites
---

# Pest PHP Testing

This skill covers Pest testing patterns used in the agl-hostman project.

## Test Configuration

### Pest.php Setup

Located in `tests/Pest.php`:

```php
<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(Tests\TestCase::class)->in('Feature', 'Integration', 'Performance', 'Unit');
uses(Tests\TestCase::class, RefreshDatabase::class)->in('Feature/Database');

// Custom expectations
expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

// Helper functions
function mockProxmoxResponse(array $data = [], int $status = 200): array
{
    return [
        'data' => $data,
        'status' => $status,
    ];
}

function assertPerformance(float $actualMs, float $thresholdMs = 200): void
{
    expect($actualMs)
        ->toBeLessThan($thresholdMs)
        ->and($actualMs)
        ->toBeGreaterThan(0);
}
```

## Unit Tests

Unit tests isolate individual components. Located in `tests/Unit/`.

### Service Unit Test

```php
<?php

declare(strict_types=1);

use App\Services\ProxmoxApiClient;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

beforeEach(function () {
    $this->client = new ProxmoxApiClient();
    $this->baseUrl = 'https://test.proxmox.local:8006/api2/json';

    Http::fake([
        '*/access/ticket' => Http::response([
            'data' => [
                'ticket' => 'test-ticket',
                'CSRFPreventionToken' => 'test-csrf-token',
            ],
        ], 200),
    ]);
});

it('authenticates successfully with valid credentials', function () {
    Http::fake([
        '*/access/ticket' => Http::response([
            'data' => [
                'ticket' => 'valid-ticket',
                'CSRFPreventionToken' => 'valid-csrf',
            ],
        ], 200),
    ]);

    $result = $this->client->authenticate('test@pam', 'password');

    expect($result)->toBeTrue()
        ->and($this->client->isAuthenticated())->toBeTrue();
});

it('fails authentication with invalid credentials', function () {
    Http::fake([
        '*/access/ticket' => Http::response(['errors' => 'Invalid credentials'], 401),
    ]);

    $result = $this->client->authenticate('wrong@pam', 'wrong-pass');

    expect($result)->toBeFalse();
});

it('retrieves list of containers successfully', function () {
    $mockContainers = [
        ['vmid' => 100, 'name' => 'test-ct', 'status' => 'running'],
        ['vmid' => 101, 'name' => 'dev-ct', 'status' => 'stopped'],
    ];

    Http::fake([
        '*/nodes/*/lxc' => Http::response(['data' => $mockContainers], 200),
    ]);

    $containers = $this->client->getContainers('node1');

    expect($containers)
        ->toBeArray()
        ->toHaveCount(2)
        ->and($containers[0])
        ->toHaveKey('vmid', 100);
});

it('handles API errors gracefully', function () {
    Http::fake([
        '*/nodes/*/lxc' => Http::response(['errors' => 'Server error'], 500),
    ]);

    $containers = $this->client->getContainers('node1');

    expect($containers)->toBeArray()->toBeEmpty();
});
```

### Model Unit Test

```php
<?php

declare(strict_types=1);

use App\Models\LxcContainer;

it('has fillable attributes', function () {
    $container = new LxcContainer();

    expect($container->getFillable())->toBeArray()->toContain(
        'name',
        'hostname',
        'status',
        'cores'
    );
});

it('calculates uptime correctly', function () {
    $container = LxcContainer::factory()->make([
        'status' => 'running',
        'started_at' => now()->subHours(2),
    ]);

    $uptime = $container->getUptimeSeconds();

    expect($uptime)->toBeGreaterThan(0)
        ->and($uptime)->toBeLessThan(7201);
});

it('returns null uptime for stopped container', function () {
    $container = LxcContainer::factory()->make([
        'status' => 'stopped',
        'started_at' => null,
    ]);

    expect($container->getUptimeSeconds())->toBeNull();
});
```

## Integration Tests

Integration tests test multiple components together. Located in `tests/Feature/`.

### API Endpoint Test

```php
<?php

declare(strict_types=1);

use App\Models\LxcContainer;
use App\Models\User;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

it('returns list of containers', function () {
    LxcContainer::factory()->count(3)->create();

    $response = $this->getJson('/api/containers');

    $response->assertStatus(200)
        ->assertJsonCount(3, 'data');
});

it('creates a new container', function () {
    $data = [
        'name' => 'test-container',
        'vmid' => 200,
        'cores' => 2,
        'memory_mb' => 2048,
        'disk_gb' => 20,
    ];

    $response = $this->postJson('/api/containers', $data);

    $response->assertStatus(201)
        ->assertJsonPath('data.name', 'test-container');

    $this->assertDatabaseHas('lxc_containers', [
        'name' => 'test-container',
        'vmid' => 200,
    ]);
});

it('validates required fields', function () {
    $response = $this->postJson('/api/containers', []);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['name', 'cores', 'memory_mb']);
});
```

### Integration Test with External Services

```php
<?php

it('integrates with Proxmox API', function () {
    Http::fake([
        '*/nodes/*/lxc' => Http::response([
            'data' => [
                ['vmid' => 100, 'name' => 'test-ct', 'status' => 'running'],
            ],
        ], 200),
    ]);

    $response = $this->getJson('/api/proxmox/containers?node=pve1');

    $response->assertStatus(200)
        ->assertJsonPath('data.0.name', 'test-ct');
});
```

## Mocking

### HTTP Facade Mocking

```php
// Single response
Http::fake([
    '*/api/*' => Http::response(['data' => 'success'], 200),
]);

// Sequence of responses
Http::fake([
    '*/api/*' => Http::sequence()
        ->push(['data' => 'first'], 200)
        ->push(['data' => 'second'], 200),
]);

// Conditional fake
Http::fake(function ($request) {
    if ($request->url() === 'https://api.example.com/endpoint') {
        return Http::response(['success' => true], 200);
    }
    return Http::response('Not Found', 404);
});

// Assertions
Http::assertSent(function ($request) {
    return $request->url() === 'https://api.example.com/endpoint'
        && $request->method() === 'POST';
});
```

### Mocking Facades

```php
// Cache mock
Cache::shouldReceive('remember')
    ->once()
    ->with('key', 60, \Closure::class)
    ->andReturn('cached-value');

// Log mock
Log::spy();
Log::shouldReceive('error')
    ->once()
    ->with('Error message', \Mockery::on(function ($context) {
        return isset($context['error']);
    }));

// Event fake
Event::fake([ContainerCreated::class]);
// ... perform action
Event::assertDispatched(ContainerCreated::class);
```

### Partial Mocks

```php
$mock = Mockery::mock(ProxmoxApiClient::class)->makePartial();
$mock->shouldReceive('authenticate')->once()->andReturn(true);
```

## Factories

### Model Factory

```php
<?php

namespace Database\Factories;

use App\Models\LxcContainer;
use Illuminate\Database\Eloquent\Factories\Factory;

class LxcContainerFactory extends Factory
{
    protected $model = LxcContainer::class;

    public function definition(): array
    {
        return [
            'proxmox_server_id' => 1,
            'vmid' => $this->faker->unique()->numberBetween(100, 9999),
            'name' => 'agldv' . $this->faker->unique()->numberBetween(1, 99),
            'hostname' => $this->faker->domainName(),
            'status' => 'running',
            'os_template' => 'ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
            'cores' => $this->faker->numberBetween(1, 8),
            'memory_mb' => $this->faker->randomElement([1024, 2048, 4096, 8192]),
            'disk_gb' => $this->faker->randomElement([20, 40, 80, 160]),
            'network_config' => [
                'net0' => 'name=eth0,bridge=vmbr0,ip=dhcp',
            ],
            'is_template' => false,
            'auto_start' => $this->faker->boolean(),
        ];
    }

    public function running(): Factory
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'running',
            'started_at' => now()->subHours(rand(1, 720)),
        ]);
    }

    public function stopped(): Factory
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'stopped',
            'stopped_at' => now(),
        ]);
    }
}
```

### Using Factories in Tests

```php
// Single model
$container = LxcContainer::factory()->create();

// With overrides
$container = LxcContainer::factory()->create([
    'name' => 'specific-name',
    'cores' => 4,
]);

// Multiple models
$containers = LxcContainer::factory()->count(5)->create();

// Using states
$runningContainer = LxcContainer::factory()->running()->create();
$stoppedContainers = LxcContainer::factory()->stopped()->count(3)->create();

// Raw data (no persist)
$data = LxcContainer::factory()->raw();
```

## Test Organization

### Directory Structure

```
tests/
├── Unit/
│   ├── Services/
│   ├── Models/
│   ├── DTOs/
│   └── Rules/
├── Feature/
│   ├── Api/
│   ├── Controllers/
│   └── Integration/
├── Integration/
│   ├── Proxmox/
│   └── QAEnvironmentTest.php
├── Performance/
└── Pest.php
```

### Parallel Testing

Configure parallel test groups in `tests/parallel-groups.php`:

```php
return [
    'default' => [
        'unit' => ['tests/Unit'],
        'feature' => ['tests/Feature'],
        'integration' => ['tests/Integration'],
    ],
];
```

Run with:
```bash
pest --parallel
```

## Reference Files

- Test Setup: `src/tests/Pest.php`
- Unit Tests: `src/tests/Unit/`
- Feature Tests: `src/tests/Feature/`
- Integration Tests: `src/tests/Integration/`
- Test Case: `src/tests/TestCase.php`
