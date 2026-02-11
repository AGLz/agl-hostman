# Security Testing Guide

## Overview

This guide provides comprehensive documentation for the AGL Infrastructure security testing suite, which implements AGL-24 Testing Coverage Improvement with focus on security validation.

## Table of Contents

- [Test Categories](#test-categories)
- [Running Security Tests](#running-security-tests)
- [Test Coverage](#test-coverage)
- [CI/CD Integration](#cicd-integration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Test Categories

### 1. Authentication Security Tests

**Location**: `src/tests/Unit/Security/AuthenticationSecurityTest.php`

Tests authentication security including:
- Password hashing (bcrypt)
- Session security
- Token management
- Failed login tracking
- Rate limiting
- Email verification

**Key Tests**:
- `test_passwords_are_hashed_with_bcrypt`
- `test_inactive_user_cannot_authenticate`
- `test_token_invalidated_after_logout`

### 2. Input Validation Tests

**Location**: `src/tests/Unit/Security/InputValidationTest.php`

Tests input sanitization and validation:
- SQL injection prevention
- XSS prevention
- Email validation
- URL validation
- File upload validation
- Array validation

**Key Tests**:
- `test_sql_injection_blocked_in_string_input`
- `test_xss_prevention_in_html_input`
- `test_file_upload_blocks_malicious_files`

### 3. RBAC Enforcement Tests

**Location**: `src/tests/Unit/Security/RbacEnforcementTest.php`

Tests role-based access control:
- Permission checks
- Role assignments
- Permission inheritance
- Wildcard permissions
- Inactive user handling

**Key Tests**:
- `test_super_admin_has_all_permissions`
- `test_permission_revocation`
- `test_inactive_user_no_permissions`

### 4. CSRF Protection Tests

**Location**: `src/tests/Feature/Security/CsrfProtectionTest.php`

Tests cross-site request forgery protection:
- Token validation
- Exempt routes
- AJAX request handling
- Session management

**Key Tests**:
- `test_post_without_csrf_token_rejected`
- `test_ajax_uses_x_csrf_token_header`
- `test_api_routes_exempt_from_csrf`

### 5. Secure Headers Tests

**Location**: `src/tests/Feature/Security/SecureHeadersTest.php`

Tests security headers:
- Content-Security-Policy (CSP)
- Strict-Transport-Security (HSTS)
- X-Frame-Options
- X-Content-Type-Options
- Cross-Origin policies

**Key Tests**:
- `test_content_security_policy_header`
- `test_x_frame_options_header`
- `test_csp_script_src_directive`

### 6. SQL Injection Prevention Tests

**Location**: `src/tests/Feature/Security/SqlInjectionTest.php`

Tests SQL injection prevention:
- Parameterized queries
- Eloquent ORM safety
- Raw query protection
- Mass assignment protection
- UNION injection prevention

**Key Tests**:
- `test_sql_injection_in_login_email`
- `test_parameterized_binding_prevents_injection`
- `test_stacked_query_prevention`

### 7. XSS Prevention Tests

**Location**: `src/tests/Feature/Security/XssPreventionTest.php`

Tests cross-site scripting prevention:
- Output escaping
- CSP enforcement
- Input sanitization
- Protocol blocking

**Key Tests**:
- `test_script_tags_escaped_in_output`
- `test_javascript_protocol_blocked`
- `test_stored_xss_prevented`

### 8. Secrets Management Tests

**Location**: `src/tests/Feature/Security/SecretsManagementTest.php`

Tests secrets management:
- No hardcoded credentials
- Environment variable usage
- App key security
- Configuration security
- Log sanitization

**Key Tests**:
- `test_no_hardcoded_passwords_in_source`
- `test_app_key_is_set`
- `test_env_files_not_in_version_control`

### 9. Rate Limiting Tests

**Location**: `src/tests/Feature/Security/RateLimitingTest.php`

Tests rate limiting enforcement:
- Login rate limits
- API rate limits
- Per-user limits
- Per-IP limits
- Decay time

**Key Tests**:
- `test_login_rate_limiting`
- `test_rate_limiting_by_user`
- `test_api_rate_limit_stricter_than_web`

### 10. Middleware Security Tests

**Location**: `src/tests/Unit/Security/MiddlewareSecurityTest.php`

Tests middleware security:
- CheckRole middleware
- CheckPermission middleware
- McpSecurity middleware
- API key authentication
- IP whitelist enforcement

**Key Tests**:
- `test_check_role_denies_unauthorized_role`
- `test_mcp_security_authenticates_api_key`
- `test_check_permission_denies_inactive_user`

## Running Security Tests

### Run All Security Tests

```bash
# From project root
cd src
vendor/bin/phpunit --testsuite=Unit,Feature --filter=Security
```

### Run Specific Test Suite

```bash
# Authentication tests
vendor/bin/phpunit --filter=AuthenticationSecurityTest

# Input validation tests
vendor/bin/phpunit --filter=InputValidationTest

# RBAC tests
vendor/bin/phpunit --filter=RbacEnforcementTest
```

### Run with Coverage

```bash
vendor/bin/phpunit --filter=Security \
  --coverage-html=coverage-security \
  --coverage-clover=coverage-security.xml
```

### Run Specific Test

```bash
vendor/bin/phpunit --filter test_passwords_are_hashed_with_bcrypt
```

## Test Coverage

### Current Coverage Targets

| Category | Target | Current |
|----------|--------|---------|
| Authentication | 90% | TBD |
| Authorization | 95% | TBD |
| Input Validation | 85% | TBD |
| CSRF Protection | 90% | TBD |
| SQL Injection | 95% | TBD |
| XSS Prevention | 90% | TBD |
| Secure Headers | 85% | TBD |
| Secrets Management | 90% | TBD |
| Rate Limiting | 85% | TBD |
| Middleware | 90% | TBD |

### Coverage Report

Generate a coverage report:

```bash
vendor/bin/phpunit --filter=Security --coverage-html=coverage-security
```

View the report:
```bash
open coverage-security/index.html
```

## CI/CD Integration

### GitHub Actions Workflow

The security tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Weekly schedule (Mondays at 6 AM UTC)
- Manual workflow dispatch

**Workflow File**: `.github/workflows/security-tests.yml`

### Workflow Jobs

1. **Security Tests** - Runs PHPUnit security tests
2. **Dependency Scan** - Snyk vulnerability scanning
3. **CodeQL Analysis** - GitHub's static analysis
4. **Secrets Scan** - TruffleHog and Gitleaks scanning

### Local Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running security tests..."
cd src
vendor/bin/phpunit --filter=Security --testsuite=Unit

if [ $? -ne 0 ]; then
  echo "Security tests failed. Commit aborted."
  exit 1
fi

echo "Security tests passed."
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Best Practices

### Writing Security Tests

1. **Test Behavior, Not Implementation**
   ```php
   // Good
   $this->assertTrue($user->hasPermissionTo('manage users'));

   // Bad
   $this->assertEquals('admin', $user->role->name);
   ```

2. **Use Deterministic Tests**
   ```php
   // Good
   $maliciousInput = "' OR '1'='1";
   $this->assertFalse($validator->validate($maliciousInput));

   // Bad (non-deterministic)
   $this->assertTrue(RateLimiter::availableIn($key) < 60);
   ```

3. **Test Happy and Edge Cases**
   ```php
   // Happy case
   $this->assertTrue($user->can('view dashboard'));

   // Edge case - inactive user
   $inactiveUser = User::factory()->inactive()->create();
   $this->assertFalse($inactiveUser->can('view dashboard'));
   ```

4. **Follow Arrange-Act-Assert Pattern**
   ```php
   // Arrange
   $user = User::factory()->create();
   $user->assignRole('admin');

   // Act
   $hasAccess = $user->can('manage users');

   // Assert
   $this->assertTrue($hasAccess);
   ```

### Security Testing Checklist

- [ ] All authentication paths tested
- [ ] All authorization checks tested
- [ ] All user inputs validated
- [ ] All SQL queries parameterized
- [ ] All outputs escaped
- [ ] All sensitive actions logged
- [ ] All rate limits enforced
- [ ] All secrets externalized
- [ ] All headers secure
- [ ] All CSRF protected

## Troubleshooting

### Common Issues

#### 1. Tests Fail with "401 Unauthorized"

**Cause**: Missing authentication in test setup

**Solution**:
```php
$response = $this->actingAs($user)->get('/protected-route');
```

#### 2. CSRF Token Validation Fails

**Cause**: Tests not starting session

**Solution**:
```php
protected function setUp(): void
{
    parent::setUp();
    Session::start();
}
```

#### 3. Rate Limiting Interferes with Tests

**Cause**: Rate limiter state persists

**Solution**:
```php
protected function tearDown(): void
{
    Cache::flush();
    parent::tearDown();
}
```

#### 4. Tests Pass in Local, Fail in CI

**Cause**: Environment differences

**Solution**: Ensure `.env.example` has all required variables

### Debug Mode

Enable debug output for tests:

```bash
vendor/bin/phpunit --filter=Security --debug
```

## Continuous Improvement

### Adding New Security Tests

1. Create test file in appropriate directory
2. Follow naming convention: `*SecurityTest.php`
3. Extend `Tests\TestCase`
4. Use `RefreshDatabase` trait for feature tests
5. Add comprehensive test cases

### Security Test Metrics

Track metrics to improve security posture:

```php
// In your test reporting
$securityMetrics = [
    'tests_run' => $testsRun,
    'coverage' => $coverage,
    'vulnerabilities_found' => $vulnerabilities,
    'false_positives' => $falsePositives,
];
```

## Additional Resources

- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Laravel Security Best Practices](https://laravel.com/docs/security)
- [Spatie Laravel Permission](https://spatie.be/docs/laravel-permission)
- [PHP Security Best Practices](https://www.php.net/manual/en/security.php)

## Support

For questions or issues with security tests:
1. Check this guide
2. Review test files for examples
3. Check existing issues in GitHub
4. Create new issue with detailed description

---

**Last Updated**: 2026-02-10
**Version**: 1.0.0
**Maintainer**: AGL Infrastructure Team
