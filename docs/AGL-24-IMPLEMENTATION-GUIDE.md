# Testing Coverage Improvement - Quick Reference Guide

**Task**: AGL-24 Testing Coverage Improvement
**Status**: Baseline Analysis Complete | Implementation In Progress

## Quick Actions

### Fix Jest Tests (Immediate)
```bash
# Reinstall dependencies with pnpm override
cd /mnt/overpower/apps/dev/agl/agl-hostman
pnpm install

# Run tests
npm run test

# Run with coverage
npm run test:coverage
```

### Install PHP Coverage Driver
```bash
# Install Xdebug (recommended)
sudo apt-get install php8.4-xdebug

# Or install PCOV (faster)
sudo apt-get install php8.4-dev
pecl install pcov
echo "extension=pcov.so" | sudo tee -a /etc/php/8.4/cli/php.ini

# Run PHP tests with coverage
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
./vendor/bin/pest --coverage
```

## Test Commands

### Node.js Tests
```bash
# Run all tests
npm run test

# Run specific test file
npm run test:greeting

# Run with coverage
npm run test:coverage

# Watch mode
npm run test:watch
```

### PHP Tests
```bash
# Run all tests
cd src && ./vendor/bin/pest

# Run specific test suite
./vendor/bin/pest --testsuite=Unit
./vendor/bin/pest --testsuite=Feature

# Run with coverage
./vendor/bin/pest --coverage --min=80

# Run parallel
./vendor/bin/pest --parallel
```

## Coverage Targets

| Component | Current | Target | Priority |
|-----------|---------|--------|----------|
| Node.js Unit Tests | 0% | 80% | HIGH |
| PHP Unit Tests | Unknown | 80% | HIGH |
| Integration Tests | Partial | 60% | HIGH |
| E2E Tests | 0% | Critical Paths | MEDIUM |

## Critical Files

- `/docs/AGL-24-TESTING-COVERAGE-ANALYSIS.md` - Full analysis report
- `/tests/coverage-baseline.json` - Baseline metrics
- `/jest.config.js` - Jest configuration
- `/src/phpunit.xml` - PHPUnit/Pest configuration
- `/package.json` - Test scripts and dependencies

## Next Steps

1. **Immediate**: Fix Jest and run baseline metrics
2. **Week 1**: Install PHP coverage driver, add unit tests
3. **Week 2**: Implement integration tests
4. **Week 3**: Set up E2E testing with Playwright
5. **Week 4**: CI/CD automation and reporting

## Progress Tracking

- Phase 1 (Foundation): 0% complete
- Phase 2 (Coverage): 0% complete
- Phase 3 (Advanced): 0% complete
- Phase 4 (Maintenance): 0% complete

**Estimated Completion**: 160 hours (4 weeks with 1 dedicated resource)
