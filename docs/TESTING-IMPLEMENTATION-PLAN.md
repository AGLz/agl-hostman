# Pest PHP v3 Testing Implementation Plan
## AGL-HOSTMAN Laravel 12 Infrastructure Platform

**Created**: 2025-11-19
**Current Coverage**: 8.5%
**Phase 1 Target**: 30%
**Final Goal**: 70%+

---

## Executive Summary

Based on analysis of the current test suite:
- **31 test files** exist
- **219 total tests** (150 failing, 69 risky)
- **Main Issue**: Database migrations not running in test environment
- **Secondary Issues**: Missing code coverage attributes, test dependencies

**Root Cause**: Tests using `RefreshDatabase` trait but TestCase doesn't properly initialize it.

---

## Phase 1: Fix Foundation (Priority: CRITICAL)

### 1.1 Fix TestCase Base Class
**File**: `/mnt/overpower/apps/dev/agl/agl-hostman/src/tests/TestCase.php`

**Changes Needed**:
```php
<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication;

    protected function setUp(): void
    {
        parent::setUp();

        // Ensure we're using in-memory SQLite for speed
        config(['database.default' => 'sqlite']);
        config(['database.connections.sqlite.database' => ':memory:']);
    }
}
```

### 1.2 Add Coverage Attributes to Tests
**Impact**: Fixes 69 risky tests

Current tests use doc-comments (deprecated in PHPUnit 12). Need to convert to PHP 8 attributes:

```php
// OLD (deprecated)
/** @covers \App\Services\ProxmoxService */

// NEW (required)
use PHPUnit\Framework\Attributes\CoversClass;

#[CoversClass(ProxmoxService::class)]
test('can connect to proxmox', function () {
    // ...
});
```

### 1.3 Fix Import Statement Warning
**File**: `tests/Feature/ContainerLifecycleTest.php`

Remove unused import on line 11:
```php
use Mockery; // Remove this - already imported via Pest
```

---

## Phase 2: Parallel Execution Setup

### 2.1 Built-in Parallel Support
Pest v3 + paratest v7.8.4 provides native parallel execution:

```bash
# Run with all CPU cores
./vendor/bin/pest --parallel

# Run with specific process count
./vendor/bin/pest --processes=4

# Parallel with coverage
XDEBUG_MODE=coverage ./vendor/bin/pest --parallel --coverage
```

### 2.2 Optimize for Parallel
**Update `phpunit.xml`**:

```xml
<php>
    <!-- Add parallel-specific configs -->
    <env name="APP_ENV" value="testing"/>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>

    <!-- Each worker gets its own DB -->
    <env name="PARATEST" value="true"/>
</php>
```

### 2.3 Expected Performance Improvement
- **Sequential**: ~37s (current)
- **Parallel (4 cores)**: ~12s (expected)
- **Parallel (8 cores)**: ~8s (expected)

---

## Phase 3: Achieve 30% Coverage

### 3.1 Current Coverage Analysis

Based on `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/` structure:

**High-Value Targets** (Core Infrastructure):
1. `Services/ProxmoxService.php` - Proxmox API integration
2. `Services/WireGuardService.php` - Mesh network management
3. `Services/ContainerService.php` - LXC lifecycle
4. `Http/Controllers/DashboardController.php` - Main UI
5. `Models/ProxmoxServer.php` - Database models

**Coverage Calculation**:
```
Total Lines: ~8,500 (estimated)
30% Target: 2,550 lines
Current: ~720 lines (8.5%)
Needed: ~1,830 additional lines
```

### 3.2 Test Priority Matrix

| Service | Lines | Tests Exist | Coverage | Priority |
|---------|-------|-------------|----------|----------|
| ProxmoxService | 450 | Yes (failing) | 5% | HIGH |
| WireGuardService | 380 | No | 0% | HIGH |
| ContainerService | 290 | Yes (failing) | 8% | HIGH |
| DashboardController | 520 | Yes (working) | 60% | LOW |
| Models (all) | 850 | Partial | 12% | MEDIUM |
| Helpers | 240 | No | 0% | MEDIUM |

### 3.3 Test Creation Strategy

**Week 1: Infrastructure Services (60% of target)**
- ProxmoxService: 15 comprehensive tests → +400 lines coverage
- WireGuardService: 12 tests → +350 lines coverage
- ContainerService: 10 tests → +280 lines coverage
**Subtotal**: ~1,030 lines (12.1% → 20.2%)

**Week 2: Models & Controllers (30% of target)**
- ProxmoxServer model: 8 tests → +180 lines
- LxcContainer model: 8 tests → +220 lines
- Additional controllers: 6 tests → +400 lines
**Subtotal**: ~800 lines (20.2% → 29.6%)

**Week 3: Helpers & Utilities (10% of target)**
- Helper functions: 5 tests → +200 lines
- Utility classes: 3 tests → +120 lines
**Subtotal**: ~320 lines (29.6% → 33.4%)

---

## Phase 4: Implementation Commands

### 4.1 Fix Foundation
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Update TestCase
# (manual edit required)

# Run migrations test
./vendor/bin/pest tests/Unit/ExampleTest.php --no-coverage

# Verify DB working
./vendor/bin/pest tests/Feature/DatabaseTest.php --no-coverage
```

### 4.2 Run Full Suite
```bash
# Sequential with coverage
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage --min=30

# Parallel without coverage (faster CI)
./vendor/bin/pest --parallel --processes=4

# Generate coverage report
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage-html coverage/html
```

### 4.3 Monitor Progress
```bash
# Coverage only (no test run)
XDEBUG_MODE=coverage ./vendor/bin/pest --coverage-text --min=30 | grep "Lines:"

# Failed tests summary
./vendor/bin/pest --no-coverage 2>&1 | grep -E "FAILED|RISKY"

# Test count
./vendor/bin/pest --list-tests | wc -l
```

---

## Phase 5: Documentation Deliverables

### 5.1 tests/README.md
**Contents**:
- Quick start guide
- Running tests (sequential, parallel, with coverage)
- Writing new tests (Pest v3 syntax)
- Troubleshooting common issues
- CI/CD integration

### 5.2 Code Coverage Badge
**Location**: `README.md`

```markdown
![Coverage](https://img.shields.io/badge/coverage-30%25-yellow)
```

### 5.3 GitHub Actions Workflow
**File**: `.github/workflows/tests.yml`

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          coverage: xdebug

      - run: composer install
      - run: XDEBUG_MODE=coverage ./vendor/bin/pest --parallel --coverage --min=30
```

---

## Risk Assessment

### High Risk
- **Database Migration Issues**: Some tests may fail until TestCase is fixed
- **External Dependencies**: Proxmox/WireGuard tests need mocking
- **Time Constraints**: 3-week timeline is aggressive

### Medium Risk
- **Parallel Execution**: May uncover race conditions
- **Coverage Measurement**: Some code may be untestable (views, middleware)

### Low Risk
- **Pest v3 Compatibility**: Already installed and working
- **PHP 8.4 Support**: Confirmed working

---

## Success Criteria

### Phase 1 (Foundation) ✅
- [ ] All 219 tests run without database errors
- [ ] Zero "risky" tests warnings
- [ ] Syntax errors fixed

### Phase 2 (Performance) ✅
- [ ] Parallel execution working (4-8 processes)
- [ ] Test suite runs in <15s (parallel)
- [ ] CI/CD integration complete

### Phase 3 (Coverage) ✅
- [ ] 30%+ code coverage achieved
- [ ] All infrastructure services tested
- [ ] Coverage report generated

### Phase 4 (Documentation) ✅
- [ ] tests/README.md complete
- [ ] Coverage badge in main README
- [ ] Team training completed

---

## Next Immediate Actions

1. **Fix TestCase.php** (10 minutes)
2. **Run test suite to verify** (5 minutes)
3. **Add coverage attributes to top 10 test files** (30 minutes)
4. **Run coverage analysis** (10 minutes)
5. **Identify gaps and create new tests** (ongoing)

**Estimated Time to 30%**: 3-4 weeks with dedicated effort
**Estimated Time to 70%**: 8-10 weeks

---

## Conclusion

The foundation exists but needs critical fixes. Once TestCase properly handles database setup, the existing 219 tests should provide ~20-25% coverage. An additional 15-20 focused tests on infrastructure services will push us to 30%+.

Parallel execution will reduce CI/CD time from 37s to ~10s, making TDD more practical.

**Recommendation**: Fix foundation first (Phase 1), then add strategic tests (Phase 3) while setting up parallel execution (Phase 2). Documentation (Phase 4) can proceed in parallel.
