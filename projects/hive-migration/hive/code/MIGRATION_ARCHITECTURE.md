# Migration Architecture: API1 → API8 (fg_API8_d)

## Executive Summary

Strategic migration from legacy API1 (`/var/www/fg_OLD2_NEW`) to modern API8 (`/var/www/fg_API8_d`) with database synchronization from production (`falgimoveis11`) to staging (`fgdev`).

### Migration Strategy
**Approach**: Critical paths first + shim layer for edge cases
**Timeline**: Incremental deployment with rollback capability
**Risk Level**: Medium (mitigated by 4x daily backups and shim layer)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     MIGRATION FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  API1 (Legacy)              API8 (Target)                  │
│  /var/www/fg_OLD2_NEW  →    /var/www/fg_API8_d            │
│  ├─ PHP 5.6/7.x             ├─ PHP 8.x                     │
│  ├─ Legacy patterns         ├─ Modern patterns             │
│  └─ falgimoveis11           └─ fgdev (synced 4x daily)     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │         SHIM LAYER (Compatibility Bridge)        │      │
│  ├──────────────────────────────────────────────────┤      │
│  │  • PHP 8 compatibility wrappers                  │      │
│  │  • Route mapping (API1 → API8)                   │      │
│  │  • Gradual feature flag rollout                  │      │
│  │  • Fallback to legacy for unmigrated routes      │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Critical Path Analysis

**Status**: Pending Analyst report

### Identification Criteria
1. **High Traffic Routes** (>1000 req/day)
2. **Business Critical** (payments, bookings, core API)
3. **Data Integrity** (user management, transactions)
4. **External Dependencies** (third-party integrations)

### Expected Critical Paths
- Authentication/Authorization endpoints
- Property listing/search APIs
- User profile management
- Payment processing
- Booking/reservation system
- Image upload/storage
- Email/notification services

---

## Phase 2: Route Mapping Strategy

### Mapping Template

```yaml
# Example route mapping configuration
routes:
  legacy:
    path: "/api/v1/properties/search"
    method: "POST"
    handler: "PropertyController@search"
    php_version: "7.4"

  target:
    path: "/api/v8/properties/search"
    method: "POST"
    handler: "App\\Http\\Controllers\\PropertyController@search"
    php_version: "8.2"

  migration:
    status: "planned"  # planned, in_progress, testing, deployed
    strategy: "direct"  # direct, shim, rewrite
    complexity: "medium"
    dependencies: ["auth", "database"]

  compatibility:
    breaking_changes:
      - "Response format changed from XML to JSON"
      - "Removed deprecated 'location' field"
    shim_required: true
    fallback_enabled: true
```

### Route Categories

#### Category A: Direct Migration (Low Complexity)
- Static content serving
- Simple CRUD operations
- Read-only endpoints
- **Strategy**: 1:1 mapping, minimal changes

#### Category B: Shim Layer Required (Medium Complexity)
- Complex business logic
- Multiple dependencies
- PHP version-specific code
- **Strategy**: Compatibility wrapper + gradual rollout

#### Category C: Full Rewrite (High Complexity)
- Legacy patterns (mysql_* functions)
- Security vulnerabilities
- Performance bottlenecks
- **Strategy**: Complete rewrite + parallel testing

---

## Phase 3: PHP Compatibility Shims

### 3.1 PHP 8 Migration Checklist

```php
<?php
/**
 * Common PHP 5.x/7.x → 8.x compatibility issues
 */

// Issue: mysql_* functions removed in PHP 7.0+
// Solution: PDO or mysqli wrapper
class LegacyDatabaseShim {
    private $pdo;

    public function mysql_query($query) {
        // Convert legacy mysql_query to PDO
        return $this->pdo->query($query);
    }

    public function mysql_fetch_assoc($result) {
        return $result->fetch(PDO::FETCH_ASSOC);
    }
}

// Issue: Deprecated array_key_exists() with objects
// Solution: Property check wrapper
function safe_array_key_exists($key, $array) {
    if (is_object($array)) {
        return property_exists($array, $key);
    }
    return array_key_exists($key, $array);
}

// Issue: Stricter type checking
// Solution: Type-safe wrappers
function safe_count($var) {
    return is_countable($var) ? count($var) : 0;
}

// Issue: Deprecated string interpolation
// Solution: Explicit concatenation or string functions
function safe_string_interpolation($template, $vars) {
    foreach ($vars as $key => $value) {
        $template = str_replace("{" . $key . "}", $value, $template);
    }
    return $template;
}
```

### 3.2 Autoloader Configuration

```php
<?php
// Composer autoload shim for legacy code
// File: /var/www/fg_API8_d/bootstrap/legacy-shim.php

spl_autoload_register(function ($class) {
    // Map legacy class names to new namespaced classes
    $legacy_map = [
        'PropertyController' => 'App\\Http\\Controllers\\PropertyController',
        'UserModel' => 'App\\Models\\User',
        'DatabaseHelper' => 'App\\Services\\LegacyDatabaseShim',
    ];

    if (isset($legacy_map[$class])) {
        class_alias($legacy_map[$class], $class);
    }
});
```

---

## Phase 4: Incremental Deployment Plan

### Stage 1: Preparation (Days 1-3)
- [ ] Complete PHP compatibility audit (Analyst)
- [ ] Setup 4x daily database sync (COMPLETED)
- [ ] Configure staging environment (API8)
- [ ] Install shim layer
- [ ] Setup feature flags

### Stage 2: Low-Risk Routes (Days 4-7)
- [ ] Migrate read-only endpoints
- [ ] Deploy with 5% traffic split
- [ ] Monitor error rates
- [ ] Rollback if error rate >1%

### Stage 3: Medium-Risk Routes (Days 8-14)
- [ ] Migrate CRUD operations
- [ ] Deploy with 25% traffic split
- [ ] A/B testing with user cohorts
- [ ] Performance benchmarking

### Stage 4: High-Risk Routes (Days 15-21)
- [ ] Migrate critical business logic
- [ ] Deploy with 50% traffic split
- [ ] Real-time monitoring dashboard
- [ ] 24/7 on-call coverage

### Stage 5: Full Cutover (Days 22-28)
- [ ] 100% traffic to API8
- [ ] Disable API1 (read-only mode)
- [ ] Archive legacy codebase
- [ ] Remove shim layer (gradual)

---

## Phase 5: Rollback Procedures

### Immediate Rollback (< 5 minutes)

```bash
#!/bin/bash
# Rollback script: /mnt/overpower/apps/dev/agl/hostman/hive/code/rollback-api.sh

# 1. Switch traffic back to API1
echo "Reverting to API1..."
ln -sf /var/www/fg_OLD2_NEW /var/www/current_api

# 2. Restore database from latest backup
echo "Restoring database..."
LATEST_BACKUP=$(ls -t /var/backups/mysql/fgdev/*.sql.gz | head -1)
zcat "$LATEST_BACKUP" | mysql -u root fgdev

# 3. Clear cache
echo "Clearing cache..."
php artisan cache:clear
php artisan config:clear

# 4. Notify team
logger -t "api-rollback" "Emergency rollback executed"

echo "Rollback completed. API1 is now active."
```

### Gradual Rollback (Feature Flags)

```php
<?php
// Feature flag configuration
// File: config/features.php

return [
    'api8_migration' => [
        'enabled' => env('API8_ENABLED', false),
        'routes' => [
            'properties.search' => env('API8_PROPERTY_SEARCH', false),
            'users.profile' => env('API8_USER_PROFILE', false),
            'bookings.create' => env('API8_BOOKING_CREATE', false),
        ],
    ],
];

// Usage in controller
if (config('features.api8_migration.routes.properties.search')) {
    // Use API8 logic
    return $this->api8PropertySearch($request);
} else {
    // Fallback to API1
    return $this->legacyPropertySearch($request);
}
```

---

## Phase 6: Monitoring & Validation

### Key Metrics

```yaml
monitoring:
  performance:
    - metric: "Response time (p95)"
      baseline: "< 200ms"
      alert_threshold: "> 500ms"

    - metric: "Error rate"
      baseline: "< 0.1%"
      alert_threshold: "> 1%"

    - metric: "Database query time"
      baseline: "< 50ms"
      alert_threshold: "> 200ms"

  business:
    - metric: "Successful bookings"
      baseline: "Compare to 7-day average"
      alert_threshold: "< 90% of baseline"

    - metric: "User registrations"
      baseline: "Compare to 7-day average"
      alert_threshold: "< 80% of baseline"

  infrastructure:
    - metric: "CPU usage"
      baseline: "< 60%"
      alert_threshold: "> 80%"

    - metric: "Memory usage"
      baseline: "< 70%"
      alert_threshold: "> 85%"
```

### Validation Tests

```php
<?php
// Automated validation suite
// File: tests/Migration/Api8ValidationTest.php

namespace Tests\Migration;

use Tests\TestCase;

class Api8ValidationTest extends TestCase
{
    /** @test */
    public function api1_and_api8_return_identical_results()
    {
        $testCases = [
            ['endpoint' => '/properties/search', 'params' => ['city' => 'Rio']],
            ['endpoint' => '/users/profile', 'params' => ['id' => 123]],
        ];

        foreach ($testCases as $test) {
            $api1Response = $this->callApi1($test['endpoint'], $test['params']);
            $api8Response = $this->callApi8($test['endpoint'], $test['params']);

            $this->assertEquals(
                $api1Response->json(),
                $api8Response->json(),
                "API8 response differs from API1 for {$test['endpoint']}"
            );
        }
    }

    /** @test */
    public function database_sync_is_current()
    {
        $prodCount = DB::connection('production')->table('properties')->count();
        $stagingCount = DB::connection('staging')->table('properties')->count();

        $this->assertEqualsWithDelta(
            $prodCount,
            $stagingCount,
            100, // Allow 100 record difference (due to sync lag)
            "Staging database is not synchronized with production"
        );
    }
}
```

---

## Phase 7: Code Transformation Scripts

### 7.1 Namespace Updater

```bash
#!/bin/bash
# Script: transform-namespaces.sh
# Updates legacy class references to PSR-4 namespaced classes

find /var/www/fg_API8_d -name "*.php" -type f -exec sed -i \
  -e 's/\bnew PropertyController\b/new \\App\\Http\\Controllers\\PropertyController/g' \
  -e 's/\bnew UserModel\b/new \\App\\Models\\User/g' \
  -e 's/\bmysql_query(/DatabaseShim::query(/g' \
  {} \;

echo "Namespace transformation completed"
```

### 7.2 Configuration Migrator

```php
<?php
// Script: migrate-config.php
// Converts legacy config.php to Laravel .env format

$legacyConfig = include('/var/www/fg_OLD2_NEW/config/config.php');

$envContent = "";
foreach ($legacyConfig as $key => $value) {
    $envKey = strtoupper(str_replace('.', '_', $key));
    $envContent .= "$envKey=$value\n";
}

file_put_contents('/var/www/fg_API8_d/.env.legacy', $envContent);
echo "Configuration migration completed\n";
```

---

## Risk Mitigation Matrix

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Data loss during migration | CRITICAL | LOW | 4x daily backups + transaction logs |
| Performance degradation | HIGH | MEDIUM | Load testing + gradual rollout |
| PHP compatibility issues | HIGH | HIGH | Shim layer + pre-migration audit |
| Business logic errors | CRITICAL | MEDIUM | Parallel testing + feature flags |
| Downtime during cutover | HIGH | LOW | Blue-green deployment |
| User authentication failure | CRITICAL | LOW | Separate auth service (no migration) |

---

## Success Criteria

### Technical
- ✓ All routes migrated to API8
- ✓ PHP 8.x compatibility achieved
- ✓ Error rate < 0.1%
- ✓ Response time p95 < 200ms
- ✓ Database sync latency < 5 minutes

### Business
- ✓ Zero data loss
- ✓ Zero business impact during migration
- ✓ User satisfaction maintained (NPS score)
- ✓ Transaction success rate maintained

### Operational
- ✓ Automated deployment pipeline
- ✓ Comprehensive monitoring
- ✓ Documented rollback procedures
- ✓ Team trained on new architecture

---

## Next Steps

1. **IMMEDIATE**: Deploy backup system (Track 1 - COMPLETED)
2. **PENDING**: Receive PHP compatibility report from Analyst
3. **DAY 1-2**: Map critical routes based on Analyst findings
4. **DAY 3**: Design and implement shim layer
5. **DAY 4**: Begin Stage 1 deployment (low-risk routes)

---

## Appendix A: Directory Structure

```
/mnt/overpower/apps/dev/agl/hostman/hive/code/
├── backup-db-sync.sh              # 4x daily backup automation
├── backup-monitor.sh              # Health monitoring
├── crontab-backup.txt             # Cron configuration
├── MIGRATION_ARCHITECTURE.md      # This document
├── rollback-api.sh                # Emergency rollback (TBD)
├── transform-namespaces.sh        # Code transformation (TBD)
├── shim/                          # Compatibility layer (TBD)
│   ├── LegacyDatabaseShim.php
│   ├── RouteMapper.php
│   └── FeatureFlags.php
└── validation/                    # Testing suite (TBD)
    ├── Api8ValidationTest.php
    └── PerformanceBenchmark.php
```

---

**Document Status**: Draft v1.0
**Last Updated**: 2025-10-13
**Author**: CODER Agent (Hive Mind)
**Reviewers**: Pending (Queen, Analyst, Tester)
