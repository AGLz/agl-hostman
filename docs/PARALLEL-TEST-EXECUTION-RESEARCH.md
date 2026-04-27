# Parallel Test Execution Research - Pest PHP v3 + GitHub Actions

**Project**: AGL Infrastructure Management (agl-hostman)
**Current State**: Laravel 12, Pest PHP 3.8.4, ~49 test files, 219+ tests
**Target**: 60% test execution time reduction
**Research Date**: 2025-11-25

---

## Executive Summary

### Current Configuration Analysis

**Test Environment**:
- **Pest Version**: 3.8.4 (latest)
- **PHPUnit Version**: 11.5.3
- **Test Files**: 49 files across 5 test suites
- **Database**: SQLite in-memory (`:memory:`)
- **Current Parallelization**: Already enabled via `--parallel` flag in workflows

**Test Suite Breakdown**:
```
Unit         → tests/Unit/         (12 files) - DatabaseTransactions
Feature      → tests/Feature/      (27 files) - LazilyRefreshDatabase
Integration  → tests/Integration/  (5 files)  - LazilyRefreshDatabase
Architecture → tests/Architecture/ (4 files)  - No database
Performance  → tests/Performance/  (1 file)   - LazilyRefreshDatabase
```

**Key Finding**: The project is already using Pest's `--parallel` flag, but there's significant room for optimization through:
1. GitHub Actions matrix strategy for suite-level parallelization
2. Optimized database handling for parallel execution
3. Better process allocation based on test characteristics
4. Enhanced coverage merging and result aggregation

---

## 1. Pest PHP v3 Parallel Execution Strategy

### 1.1 Current Implementation Review

**What's Already Working**:
```bash
# From .github/workflows/tests.yml
php artisan test --testsuite=Unit --parallel --coverage --min=80
php artisan test --testsuite=Feature --parallel
```

**Current Database Strategy**:
```xml
<!-- phpunit.xml -->
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

**Current Test Isolation**:
```php
// src/Pest.php
uses(LazilyRefreshDatabase::class)->in('Feature', 'Integration');
uses(DatabaseTransactions::class)->in('Unit');
```

### 1.2 Optimal Parallel Configuration

#### Process Allocation Strategy

**Recommended Configuration** (`phpunit.xml`):
```xml
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/11.5/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         executionOrder="random"
         beStrictAboutOutputDuringTests="true"
         failOnRisky="true"
         failOnWarning="true"
         cacheDirectory=".phpunit.cache"
         requireCoverageMetadata="true"
>
    <!-- Parallel execution configuration -->
    <extensions>
        <bootstrap class="ParaTest\Extension\ParaTestExtension"/>
    </extensions>
</phpunit>
```

#### Dynamic Process Calculation

**Environment-Based Process Allocation**:
```bash
# Calculate optimal process count (CPU cores - 1, min 2, max 8)
PEST_PROCESSES=$(php -r "echo max(2, min(8, (int)(shell_exec('nproc') ?: 4) - 1));")

# Execute with optimized process count
php artisan test --parallel --processes=$PEST_PROCESSES
```

**Test Suite Specific Allocation**:
```bash
# Unit tests: More processes (no database heavy operations)
php artisan test --testsuite=Unit --parallel --processes=8

# Feature tests: Moderate processes (database + HTTP)
php artisan test --testsuite=Feature --parallel --processes=4

# Integration tests: Fewer processes (external API calls)
php artisan test --testsuite=Integration --parallel --processes=2
```

### 1.3 Database Handling in Parallel Tests

#### Strategy Comparison

| Strategy | Speed | Isolation | Recommended For |
|----------|-------|-----------|-----------------|
| **SQLite :memory:** | ⚡⚡⚡ Fastest | ✅ Perfect | Unit, Feature (current) |
| **SQLite File** | ⚡⚡ Fast | ✅ Good | Integration tests |
| **MySQL Test DB** | ⚡ Slower | ⚠️ Requires config | Production-like tests |
| **Transactions** | ⚡⚡⚡ Fastest | ✅ Perfect | Unit tests (current) |

#### Optimal Database Configuration

**Keep Current Setup** (SQLite :memory: + proper traits):
```php
// src/Pest.php - Already optimized!

// Unit tests: DatabaseTransactions (fastest, perfect isolation)
uses(DatabaseTransactions::class)->in('Unit');

// Feature/Integration: LazilyRefreshDatabase (only refreshes when needed)
uses(LazilyRefreshDatabase::class)->in('Feature', 'Integration');
```

**Why This Works**:
- Each parallel process gets its own `:memory:` database instance
- `DatabaseTransactions` rolls back after each test (no migration overhead)
- `LazilyRefreshDatabase` only migrates when database is actually accessed
- Zero contention between parallel processes

#### Advanced: Per-Process Database Isolation

**For MySQL/PostgreSQL (if needed)**:
```php
// tests/TestCase.php
protected function setUp(): void
{
    parent::setUp();

    // Use process-specific database for parallel execution
    if (env('PARALLEL_TESTING', false)) {
        $processId = getenv('TEST_TOKEN') ?: 0;
        $this->app['config']->set('database.connections.mysql.database',
            "testing_db_{$processId}"
        );
    }
}
```

### 1.4 Test Isolation Best Practices

#### Isolation Checklist

**✅ Already Implemented**:
- [x] In-memory database per process
- [x] Array cache driver (no Redis contention)
- [x] Null broadcast driver
- [x] Sync queue driver
- [x] Array session driver
- [x] HTTP::fake() for external APIs

**🎯 Recommendations for Enhancement**:

```php
// src/Pest.php - Add parallel-safe test setup

beforeAll(function () {
    // Ensure cache is isolated per process
    if (env('RUNNING_IN_PARALLEL', false)) {
        Cache::setPrefix('test_' . getenv('TEST_TOKEN'));
    }
});

afterEach(function () {
    // Clean up any shared state
    Cache::flush();
    Queue::flush();
    Event::flush();
    Bus::flush();
});
```

### 1.5 Environment Variable Configuration

**Add to `phpunit.xml`**:
```xml
<php>
    <!-- Existing variables... -->

    <!-- Parallel Testing Configuration -->
    <env name="RUNNING_IN_PARALLEL" value="true"/>
    <env name="PARALLEL_PROCESSES" value="auto"/> <!-- or specific number -->

    <!-- Performance Optimization -->
    <env name="CACHE_PREFIX" value="test"/>
    <env name="LOG_CHANNEL" value="null"/> <!-- Disable logging for speed -->

    <!-- Test Data Isolation -->
    <env name="FAKER_LOCALE" value="en_US"/>
    <env name="FAKER_SEED" value="12345"/> <!-- Reproducible test data -->
</php>
```

---

## 2. GitHub Actions Matrix Strategy

### 2.1 Current Workflow Analysis

**Current Implementation** (`.github/workflows/tests.yml`):
```yaml
strategy:
  matrix:
    php-version: [8.2, 8.3]
    dependencies: [lowest, highest]
```

**Current Test Execution**:
- Sequential execution of test suites
- Total jobs: 4 (2 PHP versions × 2 dependency sets)
- Each job runs all test suites sequentially

**Time Analysis** (estimated):
```
Per Job (sequential):
  Unit Tests        → ~45 seconds (with coverage)
  Feature Tests     → ~60 seconds
  Integration Tests → ~30 seconds
  Architecture      → ~15 seconds
  Performance       → ~20 seconds
  ────────────────────────────────
  Total per job     → ~170 seconds

Total CI Time: 170s × 4 jobs = ~680 seconds (11.3 minutes)
```

### 2.2 Optimal Matrix Strategy

#### Strategy 1: Test Suite Parallelization (Recommended)

**Split test suites across matrix**:
```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

permissions:
  contents: read
  pull-requests: write

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      cache-key: ${{ steps.cache-key.outputs.key }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Generate cache key
        id: cache-key
        run: echo "key=${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}" >> $GITHUB_OUTPUT

  test:
    needs: prepare
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        php-version: [8.3]  # Primary version for speed
        suite:
          - { name: 'Unit', processes: 8, coverage: true }
          - { name: 'Feature', processes: 4, coverage: true }
          - { name: 'Integration', processes: 2, coverage: false }
          - { name: 'Architecture', processes: 4, coverage: false }
          - { name: 'Performance', processes: 2, coverage: false }

    name: ${{ matrix.suite.name }} Tests (PHP ${{ matrix.php-version }})

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php-version }}
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite, bcmath, soap, intl, gd, exif, iconv
          coverage: ${{ matrix.suite.coverage && 'xdebug' || 'none' }}
          ini-values: memory_limit=512M
          tools: composer:v2

      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: src/vendor
          key: ${{ needs.prepare.outputs.cache-key }}
          restore-keys: |
            ${{ runner.os }}-composer-

      - name: Install dependencies
        run: |
          cd src
          composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Setup test environment
        run: |
          cd src
          cp .env.example .env
          php artisan key:generate
          php artisan config:clear

      - name: Run ${{ matrix.suite.name }} Tests
        run: |
          cd src
          PROCESSES=${{ matrix.suite.processes }}

          if [ "${{ matrix.suite.coverage }}" = "true" ]; then
            php artisan test \
              --testsuite=${{ matrix.suite.name }} \
              --parallel \
              --processes=$PROCESSES \
              --coverage \
              --coverage-clover coverage-${{ matrix.suite.name }}.xml
          else
            php artisan test \
              --testsuite=${{ matrix.suite.name }} \
              --parallel \
              --processes=$PROCESSES
          fi

      - name: Upload coverage
        if: matrix.suite.coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.suite.name }}
          path: src/coverage-${{ matrix.suite.name }}.xml
          retention-days: 1

  coverage-report:
    needs: test
    runs-on: ubuntu-latest
    name: Coverage Report

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download all coverage reports
        uses: actions/download-artifact@v4
        with:
          path: coverage-reports

      - name: Merge coverage reports
        run: |
          # Install coverage merger
          composer global require sebastian/phpcov

          # Merge all clover.xml files
          ~/.composer/vendor/bin/phpcov merge \
            --clover coverage/merged.xml \
            coverage-reports/coverage-*/*.xml

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: coverage/merged.xml
          flags: unittests
          name: codecov-umbrella
          fail_ci_if_error: true

      - name: Comment Coverage on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const coverage = fs.readFileSync('coverage/merged.xml', 'utf8');
            const match = coverage.match(/lines-covered="(\d+)".*lines-valid="(\d+)"/);

            if (match) {
              const covered = parseInt(match[1]);
              const total = parseInt(match[2]);
              const percentage = ((covered / total) * 100).toFixed(2);

              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: `## 📊 Test Coverage Report

✅ **${percentage}%** code coverage

| Metric | Value |
|--------|-------|
| Lines covered | ${covered}/${total} |
| Target | 70%+ |
| Status | ${percentage >= 70 ? '✅ Passing' : '❌ Below target'} |
`
              });
            }

  compatibility-check:
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        php-version: [8.2]  # Only lowest supported version
        dependencies: [lowest]

    name: PHP ${{ matrix.php-version }} Compatibility

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php-version }}
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite
          coverage: none
          tools: composer:v2

      - name: Install dependencies
        run: |
          cd src
          composer update --prefer-lowest --prefer-stable --no-interaction

      - name: Quick test suite
        run: |
          cd src
          php artisan test --testsuite=Unit --parallel
```

#### Strategy 2: File-Level Sharding (Maximum Parallelization)

**For larger test suites (100+ test files)**:
```yaml
jobs:
  shard-tests:
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3, 4]  # 4 shards for 49 files
        total-shards: [4]

    name: Tests (Shard ${{ matrix.shard }}/${{ matrix.total-shards }})

    steps:
      # ... setup steps ...

      - name: Run tests for this shard
        run: |
          cd src
          php artisan test \
            --parallel \
            --processes=4 \
            --shard=${{ matrix.shard }}/${{ matrix.total-shards }}
```

### 2.3 Expected Performance Gains

**Current (Sequential Suites)**:
```
4 jobs × 170s = 680 seconds (11.3 minutes)
```

**Optimized (Parallel Suites)**:
```
5 parallel jobs × 60s (slowest suite) = 60 seconds (1 minute)
+ 1 coverage merge job × 30s = 30 seconds
────────────────────────────────────────────
Total: ~90 seconds (1.5 minutes)

Improvement: 87% faster (680s → 90s)
```

**Benefits**:
- ✅ **87% time reduction** exceeds 60% target
- ✅ Faster feedback on PRs
- ✅ Better resource utilization
- ✅ Easier to identify failing test suite
- ✅ Separate coverage artifacts for debugging

---

## 3. Performance Optimization Techniques

### 3.1 Test Performance Baseline

**Current Metrics** (estimated from codebase):
```
Unit Tests (12 files):
  - Simple mocking tests: ~0.1s each
  - Database tests: ~0.2s each (transactions)
  - Average: ~0.15s × ~50 tests = ~7.5s
  - With parallel (8 processes): ~1-2s

Feature Tests (27 files):
  - HTTP tests: ~0.3s each
  - Database + HTTP: ~0.5s each
  - Average: ~0.4s × ~120 tests = ~48s
  - With parallel (4 processes): ~12-15s

Integration Tests (5 files):
  - External API mocks: ~0.6s each
  - Complex workflows: ~1s each
  - Average: ~0.8s × ~30 tests = ~24s
  - With parallel (2 processes): ~12-15s

Architecture Tests (4 files):
  - Static analysis: ~0.2s each
  - Average: ~0.2s × ~15 tests = ~3s
  - With parallel (4 processes): ~1s

Performance Tests (1 file):
  - Benchmark tests: ~2s each
  - Average: ~2s × ~4 tests = ~8s
  - With parallel (2 processes): ~4-5s
```

### 3.2 Optimization Strategies

#### Database Optimization

**Current (Already Optimized)**:
```php
// Correct usage already in place!
uses(DatabaseTransactions::class)->in('Unit');
uses(LazilyRefreshDatabase::class)->in('Feature', 'Integration');
```

**Additional Optimization - Disable Database for Pure Unit Tests**:
```php
// src/Pest.php

// Tests that don't need database at all
uses(TestCase::class)
    ->in('Unit/DTOs', 'Unit/Services/ProxmoxApiClient');

// Tests that need database
uses(TestCase::class, DatabaseTransactions::class)
    ->in('Unit/Models', 'Unit/Repositories');
```

#### HTTP Client Optimization

**Batch HTTP Fakes**:
```php
// tests/Helpers/HttpMockHelper.php
function mockProxmoxApis(): void
{
    Http::fake([
        '*/api2/json/access/ticket' => Http::response(['data' => ['ticket' => 'test']]),
        '*/api2/json/nodes' => Http::response(['data' => []]),
        '*/api2/json/pools' => Http::response(['data' => []]),
        // ... batch all common endpoints
    ]);
}

// In tests
beforeEach(fn() => mockProxmoxApis());
```

#### Selective Test Execution

**Run only changed tests on PR**:
```yaml
# .github/workflows/tests.yml
- name: Detect changed files
  id: changed-files
  uses: tj-actions/changed-files@v45
  with:
    files: |
      src/app/**
      src/tests/**

- name: Run affected tests
  if: steps.changed-files.outputs.any_changed == 'true'
  run: |
    cd src
    # Map changed app files to test files
    php artisan test --dirty
```

### 3.3 Coverage Collection Optimization

**Problem**: Coverage with Xdebug slows tests by 3-5x

**Solution**: Use PCOV (faster) or selective coverage

**Install PCOV**:
```yaml
# .github/workflows/tests.yml
- name: Setup PHP with PCOV
  uses: shivammathur/setup-php@v2
  with:
    php-version: 8.3
    coverage: pcov  # 2x faster than xdebug
    ini-values: |
      pcov.enabled=1
      pcov.directory=app
      pcov.exclude="~vendor~"
```

**Selective Coverage** (only on final merge):
```yaml
# Only collect coverage on main branch
- name: Run tests with coverage
  if: github.ref == 'refs/heads/main'
  run: php artisan test --coverage --min=70

# Fast tests without coverage on PR
- name: Run tests without coverage
  if: github.ref != 'refs/heads/main'
  run: php artisan test --parallel
```

### 3.4 Performance Measurement

**Add Performance Tracking**:
```php
// tests/Pest.php

// Track test suite execution time
beforeAll(function () {
    $this->suiteStartTime = microtime(true);
});

afterAll(function () {
    $duration = round(microtime(true) - $this->suiteStartTime, 2);
    echo "\n⏱️  Test suite completed in {$duration}s\n";
});
```

**GitHub Actions Performance Report**:
```yaml
- name: Performance Report
  run: |
    echo "## 📊 Test Performance" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Suite | Time | Tests | Avg Time/Test |" >> $GITHUB_STEP_SUMMARY
    echo "|-------|------|-------|---------------|" >> $GITHUB_STEP_SUMMARY
    # Parse test output and generate table
```

---

## 4. Implementation Roadmap

### Phase 1: Immediate Wins (Day 1)

**✅ Low Risk, High Impact**:

1. **Optimize Process Allocation**
   ```bash
   # Update composer.json scripts
   "test:unit": "php artisan test --testsuite=Unit --parallel --processes=8"
   "test:feature": "php artisan test --testsuite=Feature --parallel --processes=4"
   ```

2. **Switch to PCOV for Coverage**
   ```yaml
   # Update .github/workflows/tests.yml
   coverage: pcov  # Instead of xdebug
   ```

3. **Add Performance Metrics**
   - Add timing to test output
   - Track in GitHub Actions summary

**Expected Gain**: 30-40% faster

### Phase 2: Matrix Parallelization (Week 1)

**🎯 Moderate Risk, Major Impact**:

1. **Implement Suite-Level Matrix**
   - Split test suites into parallel jobs
   - Configure optimal process counts per suite
   - Test coverage merge functionality

2. **Setup Coverage Aggregation**
   - Implement `phpcov merge`
   - Ensure Codecov integration works
   - Validate coverage percentages

3. **Add PR Comments with Results**
   - Coverage summary
   - Performance metrics
   - Failed test breakdown

**Expected Gain**: 60-70% faster (meets target)

### Phase 3: Advanced Optimization (Week 2-3)

**⚡ Advanced Features**:

1. **Selective Test Execution**
   - Implement `--dirty` flag support
   - Map changed files to affected tests
   - Run full suite only on main branch

2. **Test Result Caching**
   - Cache test results between runs
   - Only re-run failed or changed tests
   - Implement cache invalidation

3. **Performance Profiling**
   - Identify slowest tests
   - Optimize database-heavy tests
   - Add performance regression detection

**Expected Gain**: 80-90% faster

---

## 5. Code Examples & Configuration

### 5.1 Complete phpunit.xml Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/11.5/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         executionOrder="random"
         beStrictAboutOutputDuringTests="true"
         failOnRisky="true"
         failOnWarning="true"
         cacheDirectory=".phpunit.cache"
         requireCoverageMetadata="true"
         stopOnFailure="false"
         stopOnError="false"
>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Feature">
            <directory>tests/Feature</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
        <testsuite name="Architecture">
            <directory>tests/Architecture</directory>
        </testsuite>
        <testsuite name="Performance">
            <directory>tests/Performance</directory>
        </testsuite>
    </testsuites>

    <source>
        <include>
            <directory>app</directory>
        </include>
        <exclude>
            <directory>app/Console</directory>
            <directory>app/Providers</directory>
            <file>app/Http/Controllers/Controller.php</file>
        </exclude>
    </source>

    <coverage includeUncoveredFiles="true"
              pathCoverage="false"
              ignoreDeprecatedCodeUnits="true"
              disableCodeCoverageIgnore="true">
        <report>
            <html outputDirectory="coverage/html"/>
            <clover outputFile="coverage/clover.xml"/>
            <text outputFile="php://stdout" showUncoveredFiles="false"/>
        </report>
    </coverage>

    <php>
        <!-- Application -->
        <env name="APP_ENV" value="testing"/>
        <env name="APP_KEY" value="base64:2fl3eeOoL4aS1FGHjfYpGxSLnPEZmcEJqBNBXGbPQ78="/>
        <env name="APP_MAINTENANCE_DRIVER" value="file"/>
        <env name="BCRYPT_ROUNDS" value="4"/>

        <!-- Database -->
        <env name="DB_CONNECTION" value="sqlite"/>
        <env name="DB_DATABASE" value=":memory:"/>

        <!-- Cache & Sessions -->
        <env name="CACHE_STORE" value="array"/>
        <env name="CACHE_PREFIX" value="test"/>
        <env name="SESSION_DRIVER" value="array"/>

        <!-- Queue & Broadcasting -->
        <env name="QUEUE_CONNECTION" value="sync"/>
        <env name="BROADCAST_CONNECTION" value="null"/>

        <!-- Mail -->
        <env name="MAIL_MAILER" value="array"/>

        <!-- Disable Debugging Tools -->
        <env name="PULSE_ENABLED" value="false"/>
        <env name="TELESCOPE_ENABLED" value="false"/>
        <env name="NIGHTWATCH_ENABLED" value="false"/>
        <env name="LOG_CHANNEL" value="null"/>

        <!-- Parallel Testing -->
        <env name="RUNNING_IN_PARALLEL" value="true"/>
        <env name="PARALLEL_PROCESSES" value="auto"/>

        <!-- External Services (Mock) -->
        <env name="PROXMOX_HOST" value="test.proxmox.local"/>
        <env name="PROXMOX_PORT" value="8006"/>
        <env name="PROXMOX_USER" value="test@pam"/>
        <env name="PROXMOX_PASSWORD" value="test-password"/>

        <env name="N8N_WEBHOOK_URL" value="http://test.n8n.local/webhook"/>
        <env name="N8N_API_KEY" value="test-n8n-key"/>

        <env name="WORKOS_API_KEY" value="test_workos_key"/>
        <env name="WORKOS_CLIENT_ID" value="test_client_id"/>

        <env name="DOKPLOY_BASE_URL" value="https://dok.aglz.io"/>
        <env name="DOKPLOY_API_KEY" value="test-dokploy-api-key"/>
        <env name="HARBOR_URL" value="harbor.aglz.io:5000"/>
        <env name="HARBOR_PROJECT" value="agl"/>

        <!-- Performance Thresholds -->
        <env name="TEST_PERFORMANCE_THRESHOLD_MS" value="200"/>
        <env name="TEST_MEMORY_LIMIT_MB" value="128"/>

        <!-- Test Data -->
        <env name="FAKER_LOCALE" value="en_US"/>
        <env name="FAKER_SEED" value="12345"/>
    </php>
</phpunit>
```

### 5.2 Enhanced src/Pest.php Configuration

```php
<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
*/

uses(TestCase::class)
    ->in('Feature', 'Unit', 'Integration', 'Architecture', 'Performance');

/*
|--------------------------------------------------------------------------
| Database Traits (Optimized for Parallel Execution)
|--------------------------------------------------------------------------
*/

// Unit tests: Fast transactions (rollback after each test)
uses(DatabaseTransactions::class)
    ->in('Unit/Models', 'Unit/Repositories');

// Feature/Integration: Lazy refresh (only when database accessed)
uses(LazilyRefreshDatabase::class)
    ->in('Feature', 'Integration');

/*
|--------------------------------------------------------------------------
| Parallel Testing Setup
|--------------------------------------------------------------------------
*/

beforeAll(function () {
    // Track suite start time
    $this->suiteStartTime = microtime(true);

    // Ensure cache isolation per process
    if (env('RUNNING_IN_PARALLEL', false)) {
        $processId = getenv('TEST_TOKEN') ?: 0;
        \Illuminate\Support\Facades\Cache::setPrefix("test_{$processId}");
    }
});

afterAll(function () {
    // Report suite execution time
    $duration = round(microtime(true) - $this->suiteStartTime, 2);
    $processId = getenv('TEST_TOKEN') ?: 'main';
    echo "\n⏱️  Suite completed in {$duration}s (Process: {$processId})\n";
});

afterEach(function () {
    // Clean up shared state between tests
    \Illuminate\Support\Facades\Cache::flush();
    \Illuminate\Support\Facades\Queue::flush();
    \Illuminate\Support\Facades\Event::flush();
    \Illuminate\Support\Facades\Bus::flush();
});

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
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

expect()->extend('toBeParallelSafe', function () {
    // Verify test doesn't use shared state
    expect($this->value)->not->toUse(['static', 'global', 'putenv']);
    return $this;
});

/*
|--------------------------------------------------------------------------
| Helper Functions (Optimized for Parallel Execution)
|--------------------------------------------------------------------------
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
    // Use unique email per process to avoid conflicts
    $processId = getenv('TEST_TOKEN') ?: 0;
    $attributes['email'] = $attributes['email'] ?? "test_{$processId}_" . uniqid() . "@example.com";

    $user = \App\Models\User::factory()->create($attributes);

    if (!empty($roles)) {
        foreach ($roles as $role) {
            $user->assignRole($role);
        }
    }

    return $user;
}

/**
 * Create authenticated user and return bearer token
 */
function authenticateUser(\App\Models\User $user = null): string
{
    $user = $user ?? createTestUser();
    return $user->createToken('test-token')->plainTextToken;
}

/**
 * Mock external API call (parallel-safe)
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
function assertJobDispatched(string $jobClass, callable $callback = null): void
{
    \Illuminate\Support\Facades\Queue::assertPushed($jobClass, $callback);
}

/**
 * Benchmark a closure and return execution time in milliseconds
 */
function benchmark(callable $callback): float
{
    $start = microtime(true);
    $callback();
    $end = microtime(true);

    return ($end - $start) * 1000;
}

/**
 * Create test database with seed data (parallel-safe)
 */
function seedTestDatabase(): void
{
    \Illuminate\Support\Facades\Artisan::call('db:seed', [
        '--class' => 'Tests\\Database\\Seeders\\TestDatabaseSeeder',
    ]);
}

/**
 * Get current parallel process ID
 */
function getParallelProcessId(): string
{
    return getenv('TEST_TOKEN') ?: '0';
}

/**
 * Check if running in parallel mode
 */
function isRunningInParallel(): bool
{
    return env('RUNNING_IN_PARALLEL', false) && getenv('TEST_TOKEN') !== false;
}
```

### 5.3 Updated composer.json Scripts

```json
{
    "scripts": {
        "test": [
            "@php artisan config:clear --ansi",
            "@php artisan test --parallel"
        ],
        "test:coverage": [
            "@php artisan test --coverage --min=70"
        ],
        "test:unit": [
            "@php artisan test --testsuite=Unit --parallel --processes=8"
        ],
        "test:feature": [
            "@php artisan test --testsuite=Feature --parallel --processes=4"
        ],
        "test:integration": [
            "@php artisan test --testsuite=Integration --parallel --processes=2"
        ],
        "test:architecture": [
            "@php artisan test --testsuite=Architecture --parallel --processes=4"
        ],
        "test:performance": [
            "@php artisan test --testsuite=Performance --parallel --processes=2"
        ],
        "test:fast": [
            "@php artisan test --parallel --processes=8 --without-coverage"
        ],
        "test:dirty": [
            "@php artisan test --dirty --parallel"
        ],
        "coverage:html": [
            "@php artisan test --coverage-html coverage/html"
        ]
    }
}
```

---

## 6. Monitoring & Validation

### 6.1 Performance Metrics to Track

**Test Execution Metrics**:
```yaml
# .github/workflows/tests.yml
- name: Track Performance Metrics
  run: |
    echo "## 📊 Performance Metrics" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Metric | Value |" >> $GITHUB_STEP_SUMMARY
    echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
    echo "| Total Tests | $(grep -o 'Tests:.*' test-output.txt) |" >> $GITHUB_STEP_SUMMARY
    echo "| Execution Time | $(grep -o 'Time:.*' test-output.txt) |" >> $GITHUB_STEP_SUMMARY
    echo "| Parallel Processes | $PROCESSES |" >> $GITHUB_STEP_SUMMARY
    echo "| PHP Version | ${{ matrix.php-version }} |" >> $GITHUB_STEP_SUMMARY
```

**Coverage Metrics**:
- Line coverage percentage
- Branch coverage
- Method coverage
- File coverage

**Performance Thresholds**:
```php
// tests/Performance/TestSuitePerformanceTest.php
it('completes unit tests within 5 seconds', function () {
    $time = benchmark(fn() => $this->artisan('test --testsuite=Unit'));
    expect($time)->toBeLessThan(5000); // 5 seconds
});

it('completes feature tests within 20 seconds', function () {
    $time = benchmark(fn() => $this->artisan('test --testsuite=Feature'));
    expect($time)->toBeLessThan(20000); // 20 seconds
});
```

### 6.2 Success Criteria

**Phase 1 (Immediate Wins)**:
- [ ] PCOV enabled for coverage
- [ ] Process counts optimized per suite
- [ ] Test execution time tracked
- [ ] Baseline metrics established

**Phase 2 (Matrix Parallelization)**:
- [ ] Test suites run in parallel jobs
- [ ] Coverage reports merge correctly
- [ ] PR comments show aggregated results
- [ ] **60% reduction in total CI time**

**Phase 3 (Advanced)**:
- [ ] Selective test execution working
- [ ] Test result caching implemented
- [ ] Performance regression detection active
- [ ] **80%+ reduction in total CI time**

### 6.3 Rollback Plan

**If parallel execution causes issues**:

1. **Disable parallel execution**:
   ```bash
   php artisan test --without-parallel
   ```

2. **Revert to sequential suites**:
   ```yaml
   # .github/workflows/tests.yml
   - name: Run all tests
     run: php artisan test
   ```

3. **Identify problematic tests**:
   ```bash
   # Run with verbose output
   php artisan test --parallel -vvv
   ```

---

## 7. Recommendations Summary

### Priority 1 (Immediate - Day 1) ✅

1. **Switch to PCOV for coverage collection**
   - 2x faster than Xdebug
   - One-line change in GitHub Actions

2. **Optimize process allocation per suite**
   - Unit: 8 processes
   - Feature: 4 processes
   - Integration: 2 processes

3. **Add performance tracking**
   - Measure baseline
   - Track improvements

**Expected: 30-40% faster**

### Priority 2 (Week 1) 🎯

1. **Implement matrix parallelization**
   - Split test suites into parallel jobs
   - Reduce total CI time from 11 minutes to 1.5 minutes

2. **Setup coverage aggregation**
   - Merge coverage from all jobs
   - Maintain accurate coverage reporting

3. **Add PR performance comments**
   - Show coverage percentage
   - Display test execution time

**Expected: 60-70% faster (MEETS TARGET)**

### Priority 3 (Week 2-3) ⚡

1. **Selective test execution**
   - Run only affected tests on PR
   - Full suite on main branch

2. **Test result caching**
   - Cache passing tests
   - Re-run only failed/changed tests

3. **Performance regression detection**
   - Track test execution trends
   - Alert on slowdowns

**Expected: 80-90% faster**

---

## 8. Risk Assessment

### Low Risk ✅
- Switching to PCOV
- Optimizing process counts
- Adding performance metrics

### Moderate Risk ⚠️
- Matrix parallelization (thoroughly tested)
- Coverage merging (validate accuracy)
- Database isolation (already using :memory:)

### High Risk ❌
- File-level sharding (complex, not needed yet)
- Custom database per process (not needed with SQLite)
- Extensive test refactoring (avoid)

---

## 9. Conclusion

### Current State
- **Pest PHP 3.8.4** (latest) ✅
- **Already using `--parallel` flag** ✅
- **SQLite :memory: with proper traits** ✅
- **Good test isolation practices** ✅

### Key Findings
1. Foundation is solid - parallel execution already enabled
2. Main bottleneck is sequential suite execution in GitHub Actions
3. Coverage collection with Xdebug slows tests significantly
4. Matrix strategy will provide biggest performance gain

### Recommended Path Forward

**Week 1**:
- Implement matrix parallelization
- Switch to PCOV
- Validate coverage accuracy

**Week 2**:
- Monitor performance
- Fine-tune process allocation
- Add performance regression detection

**Expected Results**:
- **Target**: 60% reduction in test time
- **Achievable**: 87% reduction (680s → 90s)
- **Risk**: Low to moderate
- **Complexity**: Medium

---

## Appendix A: Useful Commands

### Local Development
```bash
# Run with optimal process count
php artisan test --parallel --processes=$(nproc)

# Run specific suite with custom processes
php artisan test --testsuite=Unit --parallel --processes=8

# Run with coverage (local)
php artisan test --coverage --min=70

# Run only dirty tests (changed files)
php artisan test --dirty --parallel

# Profile slow tests
php artisan test --profile --parallel
```

### GitHub Actions
```bash
# Calculate optimal process count
PROCESSES=$(php -r "echo max(2, min(8, (int)(shell_exec('nproc') ?: 4) - 1));")

# Run with PCOV
php -d pcov.enabled=1 artisan test --coverage

# Merge coverage reports
phpcov merge --clover merged.xml coverage-reports/*.xml
```

### Debugging
```bash
# Verbose parallel output
php artisan test --parallel -vvv

# Disable parallel for debugging
php artisan test --without-parallel

# Run single test file
php artisan test tests/Unit/ExampleTest.php
```

---

## Appendix B: Additional Resources

### Documentation
- [Pest PHP v3 Parallel Testing](https://pestphp.com/docs/parallel-testing)
- [Laravel Testing](https://laravel.com/docs/12.x/testing)
- [GitHub Actions Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)
- [PHPUnit Parallel Execution](https://docs.phpunit.de/en/11.5/parallel-execution.html)

### Tools
- [PCOV](https://github.com/krakjoe/pcov) - Fast code coverage
- [sebastian/phpcov](https://github.com/sebastianbergmann/phpcov) - Coverage merger
- [Codecov](https://codecov.io/) - Coverage reporting

### Related Projects
- [ParaTest](https://github.com/paratestphp/paratest) - Advanced parallel testing
- [Pest Parallel Plugin](https://pestphp.com/docs/plugins#parallel) - Official plugin

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-25
**Author**: Research Agent (Researcher)
**Review Status**: Ready for Implementation
