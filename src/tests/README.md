# Testing Infrastructure - AGL Hostman

Comprehensive Pest PHP testing suite for achieving 70%+ code coverage.

## Table of Contents

- [Quick Start](#quick-start)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Test Categories](#test-categories)
- [Coverage Reports](#coverage-reports)
- [Writing Tests](#writing-tests)
- [CI/CD Integration](#cicd-integration)
- [Performance](#performance)

## Quick Start

### Installation

```bash
# Install dependencies
cd src
composer install

# Install Pest PHP
composer require pestphp/pest --dev --with-all-dependencies
composer require pestphp/pest-plugin-laravel --dev --with-all-dependencies
composer require pestphp/pest-plugin-arch --dev --with-all-dependencies

# Setup test database
cp .env.example .env.testing
php artisan key:generate --env=testing
touch database/testing.sqlite
```

### Run All Tests

```bash
php artisan test
```

## Test Structure

```
tests/
├── Unit/                    # Unit tests (80% coverage target)
│   ├── Services/           # Service layer tests
│   ├── DTOs/              # Data Transfer Object tests
│   ├── Models/            # Eloquent model tests
│   ├── Jobs/              # Queue job tests
│   └── Repositories/      # Repository pattern tests
├── Feature/                # Feature tests (90% coverage target)
│   ├── Api/               # API endpoint tests
│   ├── Controllers/       # Controller tests
│   ├── Livewire/          # Livewire component tests
│   └── Auth/              # Authentication flow tests
├── Integration/           # Integration tests
│   ├── Proxmox/          # Proxmox API integration
│   ├── N8N/              # N8N webhook integration
│   ├── Queue/            # Queue processing tests
│   └── AI/               # AI model integration
├── Architecture/          # Architecture tests (Pest exclusive)
│   ├── ModelsTest.php
│   ├── ControllersTest.php
│   ├── ServicesTest.php
│   └── GeneralTest.php
├── Performance/           # Performance benchmarks
│   └── ApiResponseTimeTest.php
├── Helpers/              # Test helper functions
└── Database/             # Test-specific database files
    ├── Factories/        # Model factories
    └── Seeders/          # Test data seeders
```

## Running Tests

### By Test Suite

```bash
# Unit tests only
php artisan test --testsuite=Unit

# Feature tests only
php artisan test --testsuite=Feature

# Integration tests
php artisan test --testsuite=Integration

# Architecture tests
php artisan test --testsuite=Architecture

# Performance tests
php artisan test --testsuite=Performance
```

### With Parallel Execution

```bash
# Run tests in parallel (10-20x faster)
php artisan test --parallel

# Limit parallel processes
php artisan test --parallel --processes=4
```

### With Coverage

```bash
# Generate coverage report
php artisan test --coverage

# Require minimum coverage
php artisan test --coverage --min=70

# HTML coverage report
php artisan test --coverage-html coverage/html

# Open coverage report
open coverage/html/index.html
```

### Filter by Group

```bash
# Run only performance tests
php artisan test --group=performance

# Run integration tests
php artisan test --group=integration

# Skip slow tests
php artisan test --exclude-group=slow
```

### Filter by Name

```bash
# Run specific test file
php artisan test tests/Unit/Services/ProxmoxApiClientTest.php

# Filter by test name
php artisan test --filter=ProxmoxApiClient
```

## Test Categories

### 1. Unit Tests (Target: 80% coverage)

**Services:**
- ProxmoxApiClient
- N8NService
- AIModelService
- BackupService
- CacheService
- All 15 service classes

**DTOs:**
- ProxmoxApiResponse
- ContainerMetrics

**Models:**
- LxcContainer
- ProxmoxServer
- User
- All Eloquent models

**Example:**
```php
it('authenticates successfully with valid credentials', function () {
    $client = new ProxmoxApiClient();
    Http::fake([
        '*/access/ticket' => Http::response(['data' => ['ticket' => 'valid']], 200),
    ]);

    $result = $client->authenticate('test@pam', 'password');

    expect($result)->toBeTrue();
});
```

### 2. Feature Tests (Target: 90% coverage)

**API Endpoints:**
- Infrastructure API
- Backup API
- AI Model API
- Authentication API

**Controllers:**
- DashboardController
- UserController
- RoleController
- All 18 controllers

**Livewire Components:**
- MonitoringDashboard
- ContainerHealthCard
- All 12 Livewire components

**Example:**
```php
it('returns list of all containers', function () {
    LxcContainer::factory()->count(3)->create();

    $response = $this->withToken($token)
        ->getJson('/api/v1/infrastructure/containers');

    $response->assertOk()
        ->assertJsonCount(3, 'data');
});
```

### 3. Integration Tests

**Proxmox Integration:**
- Full container lifecycle
- Cluster operations
- Network partition handling

**N8N Integration:**
- Webhook delivery
- Batch operations
- Error handling

**Queue Integration:**
- Job processing
- Failed job handling
- Queue priority

**Example:**
```php
it('performs full container lifecycle', function () {
    // Create -> Start -> Check Status -> Stop -> Delete
    // With VCR-like HTTP recording
})->group('integration', 'slow');
```

### 4. Architecture Tests (Pest Exclusive)

**Enforces:**
- Strict typing
- Proper namespacing
- Design patterns
- No circular dependencies
- No debugging functions in production

**Example:**
```php
arch('models')
    ->expect('App\Models')
    ->toExtend('Illuminate\Database\Eloquent\Model')
    ->toUseStrictTypes();
```

### 5. Performance Tests

**Metrics:**
- API response time < 200ms
- Database query optimization
- Memory usage limits
- N+1 query detection

**Example:**
```php
it('lists containers within performance threshold', function () {
    $executionTime = benchmark(function () {
        $this->getJson('/api/v1/infrastructure/containers');
    });

    expect($executionTime)->toBeWithinResponseTime(200);
});
```

## Coverage Reports

### Generate Coverage

```bash
# Terminal output
php artisan test --coverage

# HTML report
php artisan test --coverage-html coverage/html

# Clover XML (for CI/CD)
php artisan test --coverage-clover coverage/clover.xml

# All formats
php artisan test --coverage --coverage-html coverage/html --coverage-clover coverage/clover.xml
```

### Coverage Targets

| Category | Target | Current |
|----------|--------|---------|
| Services | 80%    | TBD     |
| Controllers | 85%  | TBD     |
| Models   | 90%    | TBD     |
| DTOs     | 95%    | TBD     |
| Overall  | 70%+   | TBD     |

## Writing Tests

### Test Helpers

```php
// Create mock Proxmox response
mockProxmoxResponse(['vmid' => 100], true);

// Create authenticated user
$user = createTestUser(['name' => 'Test'], ['admin']);
$token = authenticateUser($user);

// Mock external API
mockExternalApi('proxmox', 'https://api.proxmox.local/status', ['status' => 'ok']);

// Container metrics
$metrics = containerMetrics(['cpu_usage' => 45.5, 'memory_usage' => 1024]);

// N8N webhook payload
$payload = n8nWebhookPayload(['event' => 'container.created']);

// Benchmark performance
$time = benchmark(fn () => $this->getJson('/api/endpoint'));
expect($time)->toBeWithinResponseTime(200);
```

### Custom Expectations

```php
// Valid UUID
expect($id)->toBeValidUuid();

// Valid API response structure
expect($response)->toBeValidApiResponse();

// Within response time threshold
expect($time)->toBeWithinResponseTime(200);
```

### Factories

```php
// Basic container
$container = LxcContainer::factory()->create();

// Running container
$container = LxcContainer::factory()->running()->create();

// High resource container
$container = LxcContainer::factory()->highResource()->create();

// Protected template
$template = LxcContainer::factory()->protected()->template()->create();

// With specific VMID
$container = LxcContainer::factory()->withVmid(100)->create();
```

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- Push to `main` or `develop`
- Pull requests

**Matrix Testing:**
- PHP 8.2, 8.3
- Lowest and highest dependencies

**Pipeline Steps:**
1. Code style (Pint)
2. Unit tests (parallel, coverage)
3. Feature tests (parallel)
4. Integration tests
5. Architecture tests
6. Performance tests (PR only)
7. Static analysis (PHPStan, Psalm)
8. Security check

**Coverage Reports:**
- Posted as PR comments
- Uploaded to Codecov
- HTML artifacts available

## Performance

### Parallel Execution

```bash
# 10-20x faster than sequential
php artisan test --parallel

# Monitor performance
php artisan test --parallel --profile
```

### Database Optimization

- SQLite in-memory database
- Database transactions for isolation
- Lazy database refresh
- Factory seeding

### Caching

- HTTP request mocking (no external calls)
- VCR-like recording for integration tests
- Cached test data

## Troubleshooting

### Common Issues

**SQLite not found:**
```bash
touch database/testing.sqlite
```

**Parallel tests failing:**
```bash
# Disable parallel execution
php artisan test --without-parallel
```

**Coverage not generating:**
```bash
# Ensure Xdebug is installed
php -v | grep Xdebug

# Install Xdebug
pecl install xdebug
```

**Memory limit exceeded:**
```bash
php -d memory_limit=512M artisan test
```

## Best Practices

1. **AAA Pattern**: Arrange, Act, Assert
2. **One assertion per test**: Keep tests focused
3. **Use factories**: Avoid hardcoded test data
4. **Mock external services**: No real API calls in tests
5. **Test behavior, not implementation**: Focus on outcomes
6. **Descriptive test names**: Use natural language
7. **Group related tests**: Use `describe()` blocks
8. **Tag slow tests**: Use `->group('slow')`
9. **Clean up after tests**: Use database transactions
10. **Keep tests fast**: Parallel execution + mocking

## Resources

- [Pest PHP Documentation](https://pestphp.com)
- [Laravel Testing Guide](https://laravel.com/docs/testing)
- [Pest Plugins](https://pestphp.com/docs/plugins)
- [Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)

---

**Maintained by:** AGL Infrastructure Team
**Last Updated:** 2025-11-11
**Coverage Goal:** 70%+ overall, 80%+ services/controllers
