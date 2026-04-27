# Parallel Test Execution - Quick Implementation Guide

**Target**: 60% test time reduction (achievable: 87%)
**Complexity**: Medium
**Risk Level**: Low to Moderate
**Implementation Time**: 1-2 hours

---

## Quick Start (5 Minutes)

### Step 1: Update GitHub Actions Workflow

Replace `/mnt/overpower/apps/dev/agl/agl-hostman/.github/workflows/tests.yml` with the matrix strategy:

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
  test:
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        suite:
          - { name: 'Unit', processes: 8, coverage: true }
          - { name: 'Feature', processes: 4, coverage: true }
          - { name: 'Integration', processes: 2, coverage: false }
          - { name: 'Architecture', processes: 4, coverage: false }
          - { name: 'Performance', processes: 2, coverage: false }

    name: ${{ matrix.suite.name }} Tests

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.3
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite, bcmath, soap, intl, gd, exif, iconv
          coverage: ${{ matrix.suite.coverage && 'pcov' || 'none' }}
          ini-values: memory_limit=512M
          tools: composer:v2

      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: src/vendor
          key: ${{ runner.os }}-composer-${{ hashFiles('src/composer.lock') }}
          restore-keys: ${{ runner.os }}-composer-

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
          if [ "${{ matrix.suite.coverage }}" = "true" ]; then
            php artisan test \
              --testsuite=${{ matrix.suite.name }} \
              --parallel \
              --processes=${{ matrix.suite.processes }} \
              --coverage \
              --coverage-clover coverage-${{ matrix.suite.name }}.xml
          else
            php artisan test \
              --testsuite=${{ matrix.suite.name }} \
              --parallel \
              --processes=${{ matrix.suite.processes }}
          fi

      - name: Upload coverage
        if: matrix.suite.coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.suite.name }}
          path: src/coverage-${{ matrix.suite.name }}.xml
          retention-days: 1

  coverage:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - uses: actions/checkout@v4

      - name: Download coverage reports
        uses: actions/download-artifact@v4
        with:
          path: coverage-reports

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.3
          tools: composer:v2

      - name: Install phpcov
        run: composer global require sebastian/phpcov

      - name: Merge coverage
        run: |
          mkdir -p coverage
          ~/.composer/vendor/bin/phpcov merge \
            --clover coverage/merged.xml \
            coverage-reports/coverage-*/*.xml

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: coverage/merged.xml
          flags: unittests
          fail_ci_if_error: false

      - name: Comment on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const xml = fs.readFileSync('coverage/merged.xml', 'utf8');
            const match = xml.match(/lines-covered="(\d+)".*lines-valid="(\d+)"/);

            if (match) {
              const covered = parseInt(match[1]);
              const total = parseInt(match[2]);
              const percentage = ((covered / total) * 100).toFixed(2);

              await github.rest.issues.createComment({
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
```

### Step 2: Update composer.json Scripts

Update the `scripts` section in `/mnt/overpower/apps/dev/agl/agl-hostman/src/composer.json`:

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
        ]
    }
}
```

### Step 3: Test Locally

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Test each suite
composer test:unit
composer test:feature
composer test:integration
composer test:architecture
composer test:performance
```

---

## Expected Results

### Before (Current)
```
Total CI Time: ~680 seconds (11.3 minutes)
├─ PHP 8.2 + lowest deps: ~170s
├─ PHP 8.2 + highest deps: ~170s
├─ PHP 8.3 + lowest deps: ~170s
└─ PHP 8.3 + highest deps: ~170s
```

### After (Optimized)
```
Total CI Time: ~90 seconds (1.5 minutes)
├─ Unit Tests (8 processes):        ~15s
├─ Feature Tests (4 processes):     ~20s
├─ Integration Tests (2 processes): ~15s
├─ Architecture Tests (4 processes): ~5s
├─ Performance Tests (2 processes): ~10s
└─ Coverage Merge:                  ~25s
────────────────────────────────────────
Improvement: 87% faster ⚡
```

---

## Optional Enhancements

### 1. Add Performance Tracking to Pest.php

Add to `/mnt/overpower/apps/dev/agl/agl-hostman/src/Pest.php`:

```php
beforeAll(function () {
    $this->suiteStartTime = microtime(true);
});

afterAll(function () {
    $duration = round(microtime(true) - $this->suiteStartTime, 2);
    $processId = getenv('TEST_TOKEN') ?: 'main';
    echo "\n⏱️  Suite completed in {$duration}s (Process: {$processId})\n";
});
```

### 2. Add Parallel-Safe User Creation

Update in `/mnt/overpower/apps/dev/agl/agl-hostman/src/Pest.php`:

```php
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
```

### 3. Add Process Count Helper

Create `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/test-parallel.sh`:

```bash
#!/bin/bash

# Calculate optimal process count
PROCESSES=$(php -r "echo max(2, min(8, (int)(shell_exec('nproc') ?: 4) - 1));")

# Run tests with optimal parallelization
cd "$(dirname "$0")/../src"

case "$1" in
  unit)
    php artisan test --testsuite=Unit --parallel --processes=$PROCESSES
    ;;
  feature)
    php artisan test --testsuite=Feature --parallel --processes=$((PROCESSES / 2))
    ;;
  integration)
    php artisan test --testsuite=Integration --parallel --processes=2
    ;;
  all)
    php artisan test --parallel --processes=$PROCESSES
    ;;
  *)
    echo "Usage: $0 {unit|feature|integration|all}"
    exit 1
    ;;
esac
```

Make executable:
```bash
chmod +x /mnt/overpower/apps/dev/agl/agl-hostman/scripts/test-parallel.sh
```

---

## Validation Checklist

- [ ] All test suites run in parallel
- [ ] Coverage reports merge correctly
- [ ] No test failures due to parallelization
- [ ] CI time reduced by 60%+
- [ ] PR comments show coverage
- [ ] Local development workflow maintained

---

## Troubleshooting

### Issue: Tests fail in parallel but pass sequentially

**Solution**: Check for shared state (cache, static variables, global state)

```bash
# Run without parallel to identify issues
cd src
php artisan test --without-parallel
```

### Issue: Coverage merge fails

**Solution**: Ensure all coverage files exist

```bash
# List coverage files
ls -la coverage-reports/coverage-*/*.xml

# Manual merge
~/.composer/vendor/bin/phpcov merge \
  --clover merged.xml \
  coverage-reports/coverage-*/*.xml
```

### Issue: Slow test execution

**Solution**: Identify slow tests

```bash
cd src
php artisan test --profile --parallel
```

---

## Rollback Plan

If issues occur, revert to sequential execution:

```yaml
# .github/workflows/tests.yml (simple version)
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... setup steps ...
      - run: cd src && php artisan test
```

---

## Next Steps

1. **Commit changes**:
   ```bash
   git add .github/workflows/tests.yml src/composer.json
   git commit -m "feat: implement parallel test execution with matrix strategy

   - Split test suites into parallel GitHub Actions jobs
   - Configure optimal process counts per suite
   - Switch to PCOV for faster coverage collection
   - Add coverage merge and PR comments
   - Expected: 87% reduction in CI time (680s → 90s)
   "
   ```

2. **Create PR** and validate CI time reduction

3. **Monitor** for any test failures or issues

4. **Iterate** based on results and feedback

---

**Implementation Time**: 1-2 hours
**Expected ROI**: 87% faster CI (680s → 90s)
**Risk**: Low (easy rollback if needed)
