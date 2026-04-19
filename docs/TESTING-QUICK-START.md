# Testing Infrastructure - Quick Start Guide

Get from 8.5% to 70%+ coverage in 5 steps.

## Step 1: Install Pest PHP (5 minutes)

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Install Pest PHP and plugins
composer require pestphp/pest --dev --with-all-dependencies
composer require pestphp/pest-plugin-laravel --dev --with-all-dependencies
composer require pestphp/pest-plugin-arch --dev --with-all-dependencies

# Verify installation
./vendor/bin/pest --version
```

**Expected Output:**
```
Pest v3.x.x
```

---

## Step 2: Setup Test Environment (2 minutes)

```bash
# Create test database
touch database/testing.sqlite

# Setup test environment file (optional)
cp .env .env.testing

# Update .env.testing
# DB_CONNECTION=sqlite
# DB_DATABASE=:memory:
```

**Verify:**
```bash
php artisan config:clear
php artisan test --help
```

---

## Step 3: Run Initial Tests (1 minute)

```bash
# Run all tests
php artisan test

# Run with coverage
php artisan test --coverage
```

**Expected Output:**
```
PASS  Tests\Unit\Services\ProxmoxApiClientTest
✓ authenticates successfully with valid credentials
✓ fails authentication with invalid credentials
...

Tests:    85 passed (XXX assertions)
Duration: X.XXs
```

---

## Step 4: Generate Coverage Report (2 minutes)

```bash
# Generate HTML coverage report
php artisan test --coverage-html coverage/html

# Open in browser (if GUI available)
open coverage/html/index.html
# OR
xdg-open coverage/html/index.html
```

**What to Look For:**
- Overall coverage percentage (target: 70%+)
- Red files (low coverage) - prioritize these
- Green files (high coverage) - good!

---

## Step 5: Run by Category (1 minute each)

```bash
# Unit tests (fastest)
composer test:unit

# Feature tests
composer test:feature

# Integration tests
composer test:integration

# Architecture tests (code quality)
composer test:architecture

# Performance tests
composer test:performance
```

---

## Quick Commands Reference

```bash
# All tests, parallel, with coverage
composer test

# Coverage with minimum threshold
composer test:coverage

# Fast iteration (no coverage)
php artisan test --parallel

# Filter by name
php artisan test --filter=ProxmoxApiClient

# Only failed tests
php artisan test --failed

# Profile slow tests
php artisan test --profile

# Exclude slow tests
php artisan test --exclude-group=slow
```

---

## Common Issues & Solutions

### Issue: "Pest not found"
```bash
composer require pestphp/pest --dev --with-all-dependencies
```

### Issue: "SQLite not found"
```bash
touch database/testing.sqlite
```

### Issue: "Coverage not generating"
```bash
# Check if Xdebug is installed
php -v | grep Xdebug

# Install Xdebug if missing
pecl install xdebug
```

### Issue: "Tests fail with database errors"
```bash
php artisan config:clear
php artisan migrate:fresh --env=testing
```

### Issue: "Parallel tests failing"
```bash
# Run without parallel
php artisan test --without-parallel
```

---

## Coverage Goals by Week

**Week 1:** 30% (Unit tests - Services, DTOs, Models)
**Week 2:** 50% (Feature tests - API, Controllers)
**Week 3:** 60% (Integration tests - External services)
**Week 4:** 70%+ (Livewire, Jobs, edge cases)

---

## What's Already Done

✅ **Configuration:**
- Pest.php with helpers and expectations
- phpunit.xml with test suites
- composer.json with test scripts

✅ **Test Examples:**
- 5 Unit test files (Services, DTOs, Models)
- 1 Feature test file (API)
- 1 Integration test file (Proxmox)
- 4 Architecture test files
- 1 Performance test file

✅ **Test Factories:**
- LxcContainerFactory
- ProxmoxServerFactory
- TestDatabaseSeeder

✅ **CI/CD:**
- GitHub Actions workflow
- Coverage reporting
- Matrix testing (PHP 8.2, 8.3)

✅ **Documentation:**
- Complete testing guide (tests/README.md)
- Implementation summary
- This quick start guide

---

## Next Steps

1. **Run tests to establish baseline:**
   ```bash
   php artisan test --coverage
   ```

2. **Identify low-coverage files:**
   - Open `coverage/html/index.html`
   - Sort by coverage (ascending)
   - Prioritize high-impact files (Services, Controllers)

3. **Add tests for priority files:**
   - Copy existing test patterns
   - Use factories for test data
   - Mock external dependencies

4. **Monitor progress:**
   ```bash
   php artisan test --coverage --min=70
   ```

5. **Enable CI/CD:**
   - Push to GitHub
   - Verify workflow runs
   - Review coverage reports on PRs

---

## File Locations

**Configuration:**
- `/src/Pest.php` - Main config
- `/src/phpunit.xml` - PHPUnit config
- `/src/composer.json` - Dependencies

**Tests:**
- `/src/tests/Unit/` - Unit tests
- `/src/tests/Feature/` - Feature tests
- `/src/tests/Integration/` - Integration tests
- `/src/tests/Architecture/` - Code quality
- `/src/tests/Performance/` - Benchmarks

**Factories:**
- `/src/database/factories/` - Test data factories

**Documentation:**
- `/src/tests/README.md` - Complete guide
- `/docs/TESTING-IMPLEMENTATION-SUMMARY.md` - Implementation details
- `/docs/TESTING-QUICK-START.md` - This file

**CI/CD:**
- `/.github/workflows/tests.yml` - GitHub Actions

---

## Need Help?

**Check documentation:**
```bash
# Read testing guide
cat src/tests/README.md

# View implementation summary
cat docs/TESTING-IMPLEMENTATION-SUMMARY.md
```

**Run help commands:**
```bash
php artisan test --help
./vendor/bin/pest --help
```

**Online resources:**
- Pest PHP: https://pestphp.com
- Laravel Testing: https://laravel.com/docs/testing

---

**Ready to achieve 70%+ coverage! 🚀**

Start with: `composer test`
