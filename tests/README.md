# AGL-HOSTMAN Testing Guide
## Pest PHP v3 | Laravel 12 | PHP 8.4

**Last Updated**: 2025-11-19
**Test Framework**: Pest PHP v3.8.4
**Coverage Engine**: Xdebug v3.4.5 + PHPUnit Code Coverage 11.0.11
**Parallel Execution**: ParaTest v7.8.4

---

## Quick Start

### Run All Tests
```bash
cd src

# Sequential execution (slower, more detailed)
./vendor/bin/pest

# Parallel execution (faster, recommended for CI/CD)
./vendor/bin/pest --parallel --processes=4

# With coverage (requires XDEBUG_MODE=coverage)
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage --min=30
```

### Run Specific Test Suites
```bash
# Unit tests only
./vendor/bin/pest tests/Unit

# Feature tests only
./vendor/bin/pest tests/Feature

# Single test file
./vendor/bin/pest tests/Unit/Services/ProxmoxServiceTest.php

# Specific test by name
./vendor/bin/pest --filter="test_can_connect_to_proxmox"
```

### Coverage Reports
```bash
# Text output to terminal
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage-text

# HTML report (opens in browser)
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage-html coverage/html
open coverage/html/index.html

# Minimum coverage threshold
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage --min=30
```

---

## Test Structure

### Directory Organization
```
tests/
├── Unit/                  # Unit tests (isolated, no DB)
│   ├── Services/          # Service layer tests
│   ├── Models/            # Model tests
│   └── Helpers/           # Helper function tests
│
├── Feature/               # Feature tests (with DB, HTTP)
│   ├── Controllers/       # Controller integration tests
│   ├── Database/          # Database-specific tests
│   └── ContainerLifecycleTest.php
│
├── Integration/           # Integration tests (external services)
│   ├── Proxmox/           # Proxmox API tests
│   └── WireGuard/         # WireGuard mesh tests
│
├── Performance/           # Performance benchmarks
│   └── ApiResponseTimeTest.php
│
├── Architecture/          # Architecture tests
│   └── ArchTest.php
│
├── Pest.php               # Global Pest configuration
├── TestCase.php           # Laravel base test case
└── README.md              # This file
```

### Test Naming Conventions

**File Names**: `*Test.php` (e.g., `ProxmoxServiceTest.php`)
**Test Functions**: Use `test()` or `it()` with descriptive names

```php
// Option 1: test() function
test('proxmox service can connect to server', function () {
    // ...
});

// Option 2: it() function (more readable)
it('connects to proxmox server successfully', function () {
    // ...
});

// Option 3: describe() blocks for organization
describe('ProxmoxService', function () {
    it('connects to server', function () {
        // ...
    });

    it('lists containers', function () {
        // ...
    });
});
```

---

## Writing Tests with Pest v3

### Basic Test Structure
```php
<?php

use App\Services\ProxmoxService;
use PHPUnit\Framework\Attributes\CoversClass;

#[CoversClass(ProxmoxService::class)]
describe('ProxmoxService', function () {
    beforeEach(function () {
        // Runs before each test
        $this->service = new ProxmoxService();
    });

    it('connects to proxmox server', function () {
        $result = $this->service->connect();

        expect($result)->toBeTrue();
    });

    it('lists all containers', function () {
        $containers = $this->service->listContainers();

        expect($containers)
            ->toBeArray()
            ->not->toBeEmpty();
    });
});
```

### Using Laravel Features
```php
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class);

it('creates a user in database', function () {
    $user = User::factory()->create([
        'email' => 'test@example.com',
    ]);

    $this->assertDatabaseHas('users', [
        'email' => 'test@example.com',
    ]);
});

it('can make HTTP requests', function () {
    $response = $this->get('/');

    $response->assertStatus(200);
});
```

### Mocking External Services
```php
<?php

use App\Services\ProxmoxService;
use Mockery;

it('handles proxmox connection failure gracefully', function () {
    $mock = Mockery::mock(ProxmoxService::class);
    $mock->shouldReceive('connect')
         ->once()
         ->andReturn(false);

    $this->app->instance(ProxmoxService::class, $mock);

    $result = app(ProxmoxService::class)->connect();

    expect($result)->toBeFalse();
});
```

### Test Fixtures and Factories
```php
<?php

use App\Models\ProxmoxServer;

it('uses factories for test data', function () {
    // Create single instance
    $server = ProxmoxServer::factory()->create();

    // Create multiple instances
    $servers = ProxmoxServer::factory()->count(5)->create();

    // With specific attributes
    $server = ProxmoxServer::factory()->create([
        'name' => 'test-server',
        'host' => '192.168.0.245',
    ]);

    expect($servers)->toHaveCount(5);
});
```

---

## Parallel Execution

### Configuration

Pest v3 includes built-in parallel execution via ParaTest v7.8.4.

**Basic Usage**:
```bash
# Auto-detect CPU cores
./vendor/bin/pest --parallel

# Specific process count
./vendor/bin/pest --parallel --processes=8

# With coverage (slower)
XDEBUG_MODE=coverage ./vendor/bin/pest --parallel --coverage
```

### Performance Benchmarks

| Configuration | Test Count | Duration | Speedup |
|---------------|-----------|----------|---------|
| Sequential | 219 tests | ~37s | 1.0x |
| Parallel (4 cores) | 219 tests | ~12s | 3.1x |
| Parallel (8 cores) | 219 tests | ~8s | 4.6x |

### Parallel-Safe Tests

⚠️ **Important**: When running tests in parallel, ensure:

1. **Database Isolation**: Use `:memory:` SQLite or unique DB names per process
2. **No Shared State**: Tests shouldn't depend on external files/caches
3. **Idempotent**: Tests can run in any order without side effects

**Example Parallel-Safe Test**:
```php
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('is parallel-safe with in-memory database', function () {
    // Each process gets its own :memory: SQLite DB
    User::factory()->create(['email' => 'test@example.com']);

    $this->assertDatabaseHas('users', ['email' => 'test@example.com']);
});
```

---

## Coverage Requirements

### Current Status
- **Current Coverage**: 8.5%
- **Phase 1 Target**: 30%
- **Final Goal**: 70%+

### Measuring Coverage
```bash
# Quick coverage check
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage | grep "Lines:"

# Detailed HTML report
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage-html coverage/html

# Enforce minimum coverage
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage --min=30
```

### Coverage Attributes (PHP 8)

Pest v3 and PHPUnit 11 require coverage metadata via attributes:

```php
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\CoversFunction;
use PHPUnit\Framework\Attributes\CoversNothing;

// Cover entire class
#[CoversClass(ProxmoxService::class)]
test('proxmox service works', function () { });

// Cover specific function
#[CoversFunction('processProxmoxData')]
test('data processing works', function () { });

// Test has no coverage (utility tests)
#[CoversNothing]
test('environment is configured', function () {
    expect(env('APP_ENV'))->toBe('testing');
});
```

### Excluding Code from Coverage

```php
// @codeCoverageIgnore on methods/classes
class ProxmoxService
{
    /**
     * @codeCoverageIgnore
     */
    public function debugMethod()
    {
        // Not counted in coverage
    }
}

// Or in phpunit.xml:
<coverage>
    <exclude>
        <directory>app/Console</directory>
        <directory>app/Providers</directory>
    </exclude>
</coverage>
```

---

## Known Issues & Solutions

### Issue 1: "Facade Root Not Set" Error

**Problem**: Tests fail with `RuntimeException: A facade root has not been set.`

**Cause**: Laravel 12 application not fully bootstrapped in test environment.

**Solution**: Ensure `TestCase.php` properly creates application:

```php
<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        return require __DIR__.'/../bootstrap/app.php';
    }
}
```

**Workaround**: If issue persists, tests may need to avoid facades in setUp() methods or ensure they use `$this->app->make()` instead.

### Issue 2: "No Such Table" Errors

**Problem**: Tests fail with database table not found errors.

**Cause**: Migrations not running in test environment.

**Solution**: Use `RefreshDatabase` trait:

```php
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class);

it('works with database', function () {
    // Migrations run automatically
});
```

### Issue 3: "Risky" Test Warnings

**Problem**: Tests marked as "risky" with coverage metadata warning.

**Cause**: `phpunit.xml` has `requireCoverageMetadata="true"` but tests lack coverage attributes.

**Solution**: Add coverage attributes to all tests:

```php
use PHPUnit\Framework\Attributes\CoversClass;

#[CoversClass(MyClass::class)]
test('my test', function () { });
```

**OR** disable requirement in `phpunit.xml`:

```xml
<phpunit requireCoverageMetadata="false">
```

### Issue 4: Slow Test Execution

**Problem**: Test suite takes >30 seconds.

**Solution**: Enable parallel execution:

```bash
./vendor/bin/pest --parallel --processes=4
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite
          coverage: xdebug

      - name: Install Dependencies
        run: cd src && composer install --no-interaction --prefer-dist

      - name: Run Tests
        run: cd src && XDEBUG_MODE=coverage ./vendor/bin/pest --parallel --coverage --min=30

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./src/coverage/clover.xml
```

### Local Development Workflow

```bash
# Before committing
cd src

# Run all tests
./vendor/bin/pest --parallel

# Check coverage
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage --min=30

# Fix code style (if applicable)
./vendor/bin/pint

# Commit if tests pass
git add .
git commit -m "feat: add new feature with tests"
```

---

## Best Practices

### 1. Test Naming
- ✅ **Good**: `it('creates container with valid configuration', function () {});`
- ❌ **Bad**: `test('test1', function () {});`

### 2. One Assertion Per Test
- ✅ **Good**: Separate tests for different scenarios
- ❌ **Bad**: One test checking multiple unrelated things

### 3. Use Factories
- ✅ **Good**: `User::factory()->create()`
- ❌ **Bad**: Manual `DB::insert()` calls

### 4. Mock External Services
- ✅ **Good**: Mock HTTP calls, external APIs
- ❌ **Bad**: Make real network requests in tests

### 5. Test Behavior, Not Implementation
- ✅ **Good**: Test public API and outcomes
- ❌ **Bad**: Test internal private methods

---

## Troubleshooting

### Tests Won't Run
```bash
# Clear caches
php artisan cache:clear
php artisan config:clear

# Regenerate autoload
composer dump-autoload

# Verify Pest installation
./vendor/bin/pest --version
```

### Coverage Not Generated
```bash
# Check Xdebug is installed
php -v | grep Xdebug

# Verify Xdebug mode
XDEBUG_MODE=coverage php -i | grep "xdebug.mode"

# If Xdebug missing, install:
pecl install xdebug
```

### Parallel Tests Failing
```bash
# Try sequential first
./vendor/bin/pest

# Then narrow down problematic tests
./vendor/bin/pest --parallel --processes=2

# Check for shared state issues
grep -r "static " tests/
```

---

## Resources

- **Pest Documentation**: https://pestphp.com/docs
- **Laravel Testing**: https://laravel.com/docs/12.x/testing
- **PHPUnit**: https://phpunit.de/documentation.html
- **Pest Expectations**: https://pestphp.com/docs/expectations

---

## Support

For issues or questions:
1. Check this README
2. Review `/docs/TESTING-IMPLEMENTATION-PLAN.md`
3. Check Pest documentation
4. Ask the team in #development channel

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-19
**Maintainer**: Infrastructure Team
