# Security Implementation Guide

**Project:** AGL-20 Security Hardening and Audit
**Version:** 1.0.0
**Last Updated:** 2026-02-10

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Security Middleware](#security-middleware)
4. [RBAC Implementation](#rbac-implementation)
5. [Audit Logging](#audit-logging)
6. [API Security](#api-security)
7. [Secrets Management](#secrets-management)
8. [Compliance Monitoring](#compliance-monitoring)
9. [Testing Security](#testing-security)
10. [Deployment Checklist](#deployment-checklist)
11. [Incident Response](#incident-response)
12. [Maintenance Procedures](#maintenance-procedures)

---

## Overview

This guide provides comprehensive documentation for implementing and maintaining security features in the AGL application. It covers the security architecture, implementation details, and operational procedures.

### Security Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimum required access for all users and services
3. **Fail Securely**: Default to secure behavior on errors
4. **Audit Everything**: Comprehensive logging of security-relevant events
5. **Continuous Monitoring**: Ongoing security assessment and improvement

### Security Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Authentication | Laravel Sanctum, WorkOS | User identity verification |
| Authorization | Spatie Laravel Permission | Role-based access control |
| Audit Logging | Custom SecurityAuditLog | Event tracking and compliance |
| API Security | Custom Middleware | API key authentication and rate limiting |
| Security Scanning | Composer/NPM Audit | Dependency vulnerability detection |
| Compliance Checking | Custom Services | OWASP/GDPR compliance monitoring |

---

## Architecture

### Security Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Application                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Routes    │──│ Middleware  │──│  Controllers         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                 │                      │           │
│         ▼                 ▼                      ▼           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  RBAC       │  │   Audit     │  │  Services            │ │
│  │  Middleware │  │   Logging   │  │  - SecurityAudit     │ │
│  └─────────────┘  └─────────────┘  │  - Compliance        │ │
│                                   └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  Data Layer                             ││
│  │  - SecurityAuditLog Table                               ││
│  │  - API Keys Table                                       ││
│  │  - Roles/Permissions Tables                             ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Request Flow

1. **Incoming Request** → McpSecurity Middleware (API auth, rate limit)
2. **Authentication** → Sanctum/WorkOS (User auth)
3. **Authorization** → Spatie Permission (RBAC check)
4. **Audit Logging** → AuditLog Middleware (Event capture)
5. **Controller** → Business Logic
6. **Response** → Security Headers Added

---

## Security Middleware

### MCP Security Middleware

**Location:** `/src/app/Http/Middleware/McpSecurity.php`

The MCP Security Middleware provides comprehensive security controls for Model Context Protocol servers.

#### Configuration

```php
// config/mcp-security.php
return [
    'api_keys' => [
        'service_name' => env('SERVICE_API_KEY'),
    ],
    'rate_limiting' => [
        'enabled' => true,
        'max_attempts' => 60,
        'decay_minutes' => 1,
    ],
    'ip_whitelist' => [
        'enabled' => env('MCP_IP_WHITELIST_ENABLED', false),
        'allowed_ips' => explode(',', env('MCP_ALLOWED_IPS', '')),
    ],
];
```

#### Environment Variables

```bash
# Required
MCP_LARAVEL_BOOST_KEY=your-secure-key-here
MCP_SHADCN_KEY=your-secure-key-here
MCP_RUV_SWARM_KEY=your-secure-key-here

# Optional
MCP_RATE_LIMITING_ENABLED=true
MCP_RATE_LIMIT_MAX_ATTEMPTS=60
MCP_RATE_LIMIT_DECAY_MINUTES=1
MCP_IP_WHITELIST_ENABLED=false
MCP_ALLOWED_IPS=10.0.0.0/8,192.168.1.0/24
MCP_AUDIT_LOGGING_ENABLED=true
```

#### Implementation Guide

**Step 1: Generate Secure API Keys**

```bash
# Generate a cryptographically secure API key
php artisan tinker
>>> Str::random(64);
=> "your-64-character-random-string"
```

**Step 2: Configure Environment**

Add to `.env`:
```bash
MCP_LARAVEL_BOOST_KEY=ak_[64-char-random-string]
```

**Step 3: Apply Middleware to Routes**

```php
// routes/api.php
Route::middleware(['mcp.security'])->group(function () {
    Route::post('/mcp/tools/call', [McpController::class, 'executeTool']);
    Route::post('/mcp/resources/list', [McpController::class, 'listResources']);
});
```

**Step 4: Customize Rate Limiting**

```php
// Per-service rate limits
Route::middleware(['mcp.security', 'throttle:laravel_boost'])->group(function () {
    // Stricter limits for specific services
});
```

#### Security Features

| Feature | Implementation | Configuration |
|---------|---------------|---------------|
| API Key Auth | Header/Bearer/Query | api_keys array |
| Rate Limiting | Per-IP | max_attempts, decay_minutes |
| IP Whitelist | CIDR Support | allowed_ips array |
| Request Size | Max 10MB | max_request_size |
| Content Type | JSON only | allowed_content_types |
| Audit Logging | All requests | audit_logging.enabled |

---

## RBAC Implementation

### Overview

The application uses Spatie Laravel Permission for role-based access control (RBAC).

### Default Roles

| Role | Description | Permissions |
|------|-------------|--------------|
| super-admin | Full system access | All permissions |
| admin | Administrative access | manage-* |
| operator | Operational access | view-*, manage-containers |
| analyst | Read-only access | view-* |
| user | Basic user access | view-dashboard |

### Default Permissions

```php
// Infrastructure
view-infrastructure
manage-infrastructure
manage-containers
manage-networks
manage-deployments

// Users & Roles
view-users
manage-users
manage-roles

// Security
view-security-logs
manage-security-settings
run-security-audits

// System
view-system-info
manage-system-config
```

### Implementation Guide

**Step 1: Create a Role**

```php
use Spatie\Permission\Models\Role;

$role = Role::create([
    'name' => 'developer',
    'guard_name' => 'web'
]);
```

**Step 2: Create Permissions**

```php
use Spatie\Permission\Models\Permission;

$permission = Permission::create([
    'name' => 'deploy-code',
    'guard_name' => 'web'
]);
```

**Step 3: Assign Permissions to Role**

```php
$role->givePermissionTo($permission);
// Or multiple
$role->syncPermissions(['deploy-code', 'view-logs']);
```

**Step 4: Assign Role to User**

```php
$user->assignRole('developer');
// Or multiple
$user->syncRoles(['developer', 'analyst']);
```

**Step 5: Check Permissions**

```php
// In controllers
$this->authorize('deploy-code');

// In blade
@can('deploy-code')
    <!-- Show deployment button -->
@endcan

// In code
if ($user->can('deploy-code')) {
    // Allow deployment
}
```

### Middleware Protection

```php
// Single role
Route::get('/admin', [AdminController::class, 'index'])
    ->middleware('role:admin');

// Multiple roles (any)
Route::get('/settings', [SettingsController::class, 'index'])
    ->middleware('role:admin,operator|any');

// Multiple roles (all)
Route::get('/super', [SuperController::class, 'index'])
    ->middleware('role:admin,super-admin|all');

// Permission
Route::post('/deploy', [DeployController::class, 'deploy'])
    ->middleware('permission:deploy-code');

// Combined
Route::post('/critical', [CriticalController::class, 'execute'])
    ->middleware('role:admin')
    ->middleware('permission:execute-critical');
```

### Direct Permission Assignment

```php
// Assign directly to user (bypasses roles)
$user->givePermissionTo('view-sensitive-data');

// Check direct permissions
if ($user->hasDirectPermission('view-sensitive-data')) {
    // User has this permission directly, not through role
}
```

### Role Hierarchy

```php
// Define role hierarchy (optional)
$superAdmin = Role::findByName('super-admin');
$admin = Role::findByName('admin');

// Super admin inherits all admin permissions
// (Requires custom implementation or package extension)
```

---

## Audit Logging

### Security Audit Log Model

**Location:** `/src/app/Models/SecurityAuditLog.php`

The audit log tracks all security-relevant events for compliance and forensic analysis.

### Event Types

| Category | Events | Severity |
|----------|--------|----------|
| Authentication | auth.login, auth.logout, auth.failed | info-high |
| User Management | user.created, user.deleted, user.role_changed | low-high |
| Authorization | permission.granted, permission.revoked | medium |
| Container | container.created, container.deployed | info-medium |
| Deployment | deployment.started, deployment.failed | info-high |
| Security | security.scan, security.alert, vulnerability_found | medium-critical |
| Configuration | config.changed, api_key.created | medium-high |

### Implementation Guide

**Step 1: Log Security Events**

```php
use App\Models\SecurityAuditLog;

// Log authentication event
SecurityAuditLog::logAuth('auth.login', [
    'user_id' => $user->id,
    'ip_address' => request()->ip(),
    'user_agent' => request()->userAgent(),
]);

// Log user event
SecurityAuditLog::logUser('user.role_changed', $user, [
    'old_role' => $oldRole,
    'new_role' => $newRole,
    'severity' => 'medium',
]);

// Log security alert
SecurityAuditLog::alert('Potential brute force attack detected', [
    'ip_address' => $attackerIp,
    'attempts' => $attemptCount,
    'tags' => ['brute-force', 'auto-detected'],
]);
```

**Step 2: Query Audit Logs**

```php
// Get critical events
$criticalEvents = SecurityAuditLog::critical()->get();

// Get recent events (last 7 days)
$recentEvents = SecurityAuditLog::recent()->get();

// Filter by event type
$loginEvents = SecurityAuditLog::eventType('auth.login')->get();

// Filter by tags
$alerts = SecurityAuditLog::withTag(['security-alert'])->get();

// Get high or above severity
$importantEvents = SecurityAuditLog::highOrAbove()->get();
```

**Step 3: Audit Log Middleware**

Automatic logging is handled by the `AuditLog` middleware for all write operations:

```php
// routes/api.php
Route::middleware(['auth:sanctum', 'audit.log'])->group(function () {
    Route::post('/users', [UserController::class, 'store']);
    Route::put('/users/{user}', [UserController::class, 'update']);
    Route::delete('/users/{user}', [UserController::class, 'destroy']);
});
```

### Audit Log Retention

**Recommended Retention Policy:**

| Severity | Retention Period | Archive Location |
|----------|------------------|------------------|
| Critical | 7 years | Secure archive |
| High | 3 years | Secure archive |
| Medium | 1 year | Database |
| Low | 6 months | Database |
| Info | 3 months | Database |

**Implementation:**

```php
// Console/Commands/PruneAuditLogs.php
public function handle()
{
    // Archive old logs
    SecurityAuditLog::where('created_at', '<', now()->subYear())
        ->where('severity', '>=', 'medium')
        ->each(function ($log) {
            $this->archiveLog($log);
        });

    // Delete old info logs
    SecurityAuditLog::where('created_at', '<', now()->subMonths(3))
        ->where('severity', 'info')
        ->delete();
}
```

---

## API Security

### API Authentication Middleware

**Location:** `/src/app/Http/Middleware/ApiAuthentication.php`

Comprehensive API key authentication with rate limiting and usage tracking.

### API Key Model

**Location:** `/src/app/Models/ApiKey.php`

```php
// Create API key
$apiKey = ApiKey::create([
    'name' => 'Production API Key',
    'user_id' => $user->id,
    'permissions' => ['containers:read', 'containers:write'],
    'rate_limit' => 1000, // requests per hour
    'expires_at' => now()->addYear(),
    'is_active' => true,
]);

// Returns API key: ak_...
echo $apiKey->key;
```

### API Key Usage

**Step 1: Include API Key in Request**

```bash
# Header (recommended)
curl -H "X-API-Key: ak_your_key_here" https://api.example.com/endpoint

# Bearer token
curl -H "Authorization: Bearer ak_your_key_here" https://api.example.com/endpoint

# Query parameter (NOT RECOMMENDED)
curl https://api.example.com/endpoint?api_key=ak_your_key_here
```

**Step 2: Apply Middleware**

```php
Route::middleware(['api.auth'])->group(function () {
    Route::get('/containers', [ContainerController::class, 'index']);
    Route::post('/containers', [ContainerController::class, 'store']);
});

// With permission check
Route::middleware(['api.auth:containers:write'])->group(function () {
    Route::post('/containers', [ContainerController::class, 'store']);
    Route::put('/containers/{id}', [ContainerController::class, 'update']);
});
```

**Step 3: Check API Key in Controller**

```php
public function index(Request $request)
{
    $apiKey = $request->attributes->get('api_key');

    // Access API key properties
    $name = $apiKey->name;
    $permissions = $apiKey->permissions;
    $usageCount = $apiKey->usage_count;
}
```

### Rate Limiting Strategy

**Current:** Per-IP rate limiting
**Recommended:** Per-API-key rate limiting

```php
// In ApiAuthentication middleware
$rateLimitKey = 'api_rate:' . $apiKey->id;
$limit = $apiKey->rate_limit ?: 60;

if (!RateLimiter::attempt($rateLimitKey, $limit, function() {}, 3600)) {
    return response()->json([
        'error' => 'Rate limit exceeded',
        'retry_after' => RateLimiter::availableIn($rateLimitKey),
    ], 429);
}
```

### API Key Security Best Practices

1. **Never expose API keys in client-side code**
2. **Use short expiration times for temporary keys**
3. **Implement key rotation policies**
4. **Monitor usage for anomalies**
5. **Revoke compromised keys immediately**

---

## Secrets Management

### Environment Variables

**Required Security Variables:**

```bash
# Application
APP_KEY=base64:32-char-or-more-random-string
APP_ENV=production
APP_DEBUG=false

# Database
DB_PASSWORD=strong-unique-password

# MCP Services
MCP_LARAVEL_BOOST_KEY=ak_64-char-random-string
MCP_SHADCN_KEY=ak_64-char-random-string
MCP_RUV_SWARM_KEY=ak_64-char-random-string

# Encryption
MCP_ENCRYPTION_KEY=32-char-encryption-key
```

### Secrets Rotation

**Rotation Schedule:**

| Secret Type | Rotation Frequency | Method |
|-------------|-------------------|--------|
| API Keys | Quarterly | Issue new, revoke old |
| Database Password | Annually | Change in maintenance window |
| APP_KEY | Never (generate once) | N/A |
| Encryption Keys | Annually | Re-encrypt data |

**Rotation Procedure:**

1. Generate new secret
2. Add new secret to configuration (keep old)
3. Deploy with both secrets active
4. Test with new secret
5. Remove old secret
6. Document rotation

### Encrypted Configuration

For sensitive configuration values, use Laravel's encrypted configuration:

```php
// Encrypt value
php artisan encrypt:value

// Add to config
'api_secret' => env('API_SECRET_ENCRYPTED'),

// Decrypt at runtime
$secret = decrypt(config('services.api.api_secret'));
```

---

## Compliance Monitoring

### Security Audit Service

**Location:** `/src/app/Services/SecurityAuditService.php`

Automated security auditing with vulnerability scanning and compliance checking.

### Running Security Audits

**Via Console:**

```bash
# Full security audit
php artisan security:audit

# Dependency check only
php artisan security:check-dependencies

# Code security scan
php artisan security:scan-code
```

**Via API:**

```bash
curl -X POST https://api.example.com/api/security/audit \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json"
```

### Audit Report

```json
{
  "timestamp": "2026-02-10T10:00:00Z",
  "checks": {
    "dependency_vulnerabilities": {
      "status": "pass",
      "findings": []
    },
    "code_security": {
      "status": "fail",
      "findings": [
        {
          "severity": "high",
          "file": "/app/Services/ExternalApi.php",
          "message": "Potential SQL injection"
        }
      ]
    }
  },
  "summary": {
    "total_findings": 5,
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 2,
    "grade": "B"
  }
}
```

### Compliance Checking

**OWASP Top 10 Compliance:**

```php
use App\Services\SecurityComplianceService;

$service = new SecurityComplianceService();
$result = $service->checkOWASPTop10();

// Result
[
    'compliance_percentage' => 80,
    'passed' => 8,
    'total' => 10,
    'checks' => [
        'A01_2021_Broken_Access_Control' => [...],
        'A02_2021_Cryptographic_Failures' => [...],
        // ...
    ]
]
```

**GDPR Compliance:**

```php
$result = $service->checkGDPRCompliance();

// Result
[
    'compliance_percentage' => 60,
    'passed' => 4,
    'total' => 7,
    'checks' => [
        'data_minimization' => [...],
        'right_to_access' => [...],
        'right_to_erasure' => [...],
        // ...
    ]
]
```

### Scheduled Audits

```php
// app/Console/Kernel.php
protected function schedule(Schedule $schedule)
{
    // Daily security scan
    $schedule->command('security:audit')
        ->dailyAt('02:00')
        ->onSuccess(function () {
            Log::info('Security audit completed successfully');
        })
        ->onFailure(function () {
            Log::error('Security audit failed');
            // Send alert to security team
        });
}
```

---

## Testing Security

### Security Test Suite

**Location:** `/src/tests/Feature/Api/SecurityEndpointsComprehensiveTest.php`

### Running Security Tests

```bash
# All security tests
php artisan test --testsuite=Security

# Unit tests
php artisan test tests/Unit/Services/SecurityAuditServiceTest.php
php artisan test tests/Unit/Services/SecurityComplianceServiceTest.php

# Feature tests
php artisan test tests/Feature/Api/SecurityEndpointsComprehensiveTest.php
```

### Test Coverage

| Component | Coverage | Target |
|-----------|----------|--------|
| Security Middleware | 85% | 90% |
| RBAC Implementation | 80% | 90% |
| Audit Logging | 90% | 95% |
| API Authentication | 85% | 90% |
| Compliance Checking | 75% | 85% |

### Writing Security Tests

**Test Authentication/Authorization:**

```php
public function test_unauthorized_user_cannot_access_admin()
{
    $user = User::factory()->create();
    $this->actingAs($user);

    $response = $this->getJson('/api/admin/users');

    $response->assertStatus(403);
}

public function test_admin_can_access_admin()
{
    $admin = User::factory()->create();
    $admin->assignRole('admin');
    $this->actingAs($admin);

    $response = $this->getJson('/api/admin/users');

    $response->assertStatus(200);
}
```

**Test Rate Limiting:**

```php
public function test_rate_limiting_enforced()
{
    $apiKey = ApiKey::factory()->create(['rate_limit' => 2]);

    for ($i = 0; $i < 2; $i++) {
        $response = $this->withHeader('X-API-Key', $apiKey->key)
            ->getJson('/api/endpoint');
        $response->assertStatus(200);
    }

    // Third request should be rate limited
    $response = $this->withHeader('X-API-Key', $apiKey->key)
        ->getJson('/api/endpoint');
    $response->assertStatus(429);
}
```

**Test Input Validation:**

```php
public function test_sql_injection_prevented()
{
    $admin = User::factory()->create();
    $admin->assignRole('admin');
    $this->actingAs($admin);

    $maliciousInput = "1' OR '1'='1";
    $response = $this->postJson('/api/users/search', [
        'id' => $maliciousInput
    ]);

    // Should either validate and reject, or safely escape
    $response->assertStatus(422); // Validation error
}
```

### Security Testing Checklist

- [ ] Authentication bypass tests
- [ ] Authorization elevation tests
- [ ] SQL injection tests
- [ ] XSS payload tests
- [ ] CSRF token validation
- [ ] Rate limiting enforcement
- [ ] Input boundary testing
- [ ] Error message information leakage
- [ ] Session fixation tests
- [ ] File upload security tests

---

## Deployment Checklist

### Pre-Deployment

- [ ] Review security audit report
- [ ] Resolve critical and high-severity findings
- [ ] Update all dependencies
- [ ] Run `composer audit` and `npm audit`
- [ ] Verify no hardcoded secrets in code
- [ ] Review and update `.env` settings
- [ ] Generate secure `APP_KEY` if not set
- [ ] Configure production database user with minimal privileges

### Configuration

- [ ] Set `APP_ENV=production`
- [ ] Set `APP_DEBUG=false`
- [ ] Set `APP_URL` to HTTPS
- [ ] Configure trusted proxies
- [ ] Set up SSL/TLS certificates
- [ ] Configure session security (secure, http_only, same_site)
- [ ] Set up CORS restrictions
- [ ] Configure rate limiting
- [ ] Set up log aggregation

### Security Controls

- [ ] Enable all security middleware
- [ ] Configure IP whitelisting (if applicable)
- [ ] Set up API keys for services
- [ ] Configure role permissions
- [ ] Enable audit logging
- [ ] Set up log retention
- [ ] Configure security headers
- [ ] Enable CSP headers

### Verification

- [ ] Run security audit suite
- [ ] Verify OWASP compliance >70%
- [ ] Test authentication flows
- [ ] Test authorization boundaries
- [ ] Verify rate limiting works
- [ ] Test audit log capture
- [ ] Verify API key authentication
- [ ] Test session management
- [ ] Verify HTTPS enforcement

### Post-Deployment

- [ ] Monitor security logs for 24 hours
- [ ] Run compliance checks
- [ ] Document any security exceptions
- [ ] Schedule first security review
- [ ] Set up alerting for security events

---

## Incident Response

### Security Incident Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| P0 - Critical | Active breach, data exfiltration | Immediate (15 min) |
| P1 - High | Attempted breach, vulnerability exploited | 1 hour |
| P2 - Medium | Potential issue, needs investigation | 4 hours |
| P3 - Low | Policy violation, documentation needed | 24 hours |

### Incident Response Procedure

**1. Detection**

```php
// Automated alert for critical security events
SecurityAuditLog::alert('Critical security event detected', [
    'event_type' => 'brute_force_detected',
    'ip_address' => $attackerIp,
    'attempts' => $attempts,
]);

// Send notification
Notification::route('mail', 'security@example.com')
    ->notify(new SecurityIncidentAlert($event));
```

**2. Containment**

```php
// Block malicious IP
$blockedIp = BlockedIp::create([
    'ip_address' => $attackerIp,
    'reason' => 'Brute force attack',
    'blocked_at' => now(),
]);

// Reolve compromised API key
$apiKey->update(['is_active' => false]);
```

**3. Eradication**

```php
// Identify and patch vulnerability
// Update affected systems
// Scan for backdoors
```

**4. Recovery**

```php
// Restore from clean backups
// Verify system integrity
// Monitor for recurrence
```

**5. Lessons Learned**

- Document incident timeline
- Identify root cause
- Implement preventive measures
- Update security policies

### Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Security Lead | | security@example.com |
| DevOps Lead | | devops@example.com |
| Legal Counsel | | legal@example.com |
| Incident Commander | | incidents@example.com |

---

## Maintenance Procedures

### Daily Tasks

- Review security logs for critical events
- Monitor failed authentication attempts
- Check for new dependency vulnerabilities
- Verify backup completion

### Weekly Tasks

- Review audit log summary
- Check compliance scores
- Review rate limit violations
- Update security documentation

### Monthly Tasks

- Run full security audit
- Review and update role permissions
- Audit API key usage
- Review and rotate secrets (as needed)
- Update security test suite

### Quarterly Tasks

- Comprehensive security review
- Penetration testing
- Compliance audit
- Security training update
- Incident response drill

### Annual Tasks

- Third-party security assessment
- Full infrastructure security review
- Policy and procedure updates
- Security architecture review

---

## Appendix

### A. Security Headers

```php
// Recommended security headers
return [
    'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';",
    'X-Content-Type-Options' => 'nosniff',
    'X-Frame-Options' => 'DENY',
    'X-XSS-Protection' => '1; mode=block',
    'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',
    'Referrer-Policy' => 'strict-origin-when-cross-origin',
];
```

### B. Password Policy

```php
// StrongPassword rule
public function passes($attribute, $value)
{
    // At least 12 characters
    if (strlen($value) < 12) return false;

    // Contains uppercase
    if (!preg_match('/[A-Z]/', $value)) return false;

    // Contains lowercase
    if (!preg_match('/[a-z]/', $value)) return false;

    // Contains number
    if (!preg_match('/[0-9]/', $value)) return false;

    // Contains special character
    if (!preg_match('/[^A-Za-z0-9]/', $value)) return false;

    return true;
}
```

### C. Session Security

```php
// config/session.php
return [
    'driver' => env('SESSION_DRIVER', 'redis'),
    'lifetime' => env('SESSION_LIFETIME', 120),
    'expire_on_close' => env('SESSION_EXPIRE_ON_CLOSE', false),
    'encrypt' => true,
    'files' => storage_path('framework/sessions'),
    'connection' => env('SESSION_CONNECTION'),
    'table' => 'sessions',
    'store' => env('SESSION_STORE'),
    'lottery' => [2, 100],
    'cookie' => env('SESSION_COOKIE_NAME', 'laravel_session'),
    'path' => '/',
    'domain' => env('SESSION_DOMAIN'),
    'secure' => env('SESSION_SECURE', true),
    'http_only' => env('SESSION_HTTP_ONLY', true),
    'same_site' => env('SESSION_SAME_SITE', 'lax'),
];
```

### D. Encryption Configuration

```php
// Generate encryption key
php artisan key:generate

// For custom encryption
use Illuminate\Support\Facades\Crypt;

$encrypted = Crypt::encryptString('sensitive data');
$decrypted = Crypt::decryptString($encrypted);

// For database encryption
use Illuminate\Support\Facades\Crypt;

$model->sensitive_field = Crypt::encrypt($value);
```

### E. Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Laravel Security](https://laravel.com/docs/security)
- [Spatie Laravel Permission](https://spatie.be/docs/laravel-permission)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [PCI DSS](https://www.pcisecuritystandards.org/)

---

**Document Version:** 1.0.0
**Last Updated:** 2026-02-10
**Next Review:** 2026-03-10
