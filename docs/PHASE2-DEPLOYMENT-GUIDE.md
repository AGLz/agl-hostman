# Phase 2 Deployment Guide - Repository Pattern & DTOs

> **Status**: Ready for Production
> **Est. Deployment Time**: 20-30 minutes
> **Downtime Required**: ~3 minutes (database migrations)
> **Rollback Time**: ~5 minutes

---

## 📋 Pre-Deployment Checklist

### 1. **Prerequisites**
- [ ] Phase 1 deployed successfully and verified
- [ ] PHP 8.2+ installed
- [ ] Laravel 12 running
- [ ] MySQL 8.0+ accessible
- [ ] Redis accessible and configured
- [ ] Horizon workers running
- [ ] FlexibleCacheService deployed (Phase 1)

### 2. **Backup Strategy**
- [ ] Database backup created
- [ ] .env file backed up
- [ ] Service files backed up
- [ ] Backup location verified: `./storage/backups/phase2-YYYYMMDD-HHMMSS/`

### 3. **Proxmox Access**
- [ ] Proxmox VE API accessible (port 8006)
- [ ] API credentials configured in .env
- [ ] Test API connection successful
- [ ] Circuit breaker settings reviewed

---

## 🚀 Deployment Steps

### Step 1: Pre-Deployment Verification

```bash
# Navigate to application directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Verify Phase 1 is deployed
php artisan migrate:status | grep "2025_01_11_000001_add_performance_indexes"
# Expected: Ran

# Verify FlexibleCacheService exists
ls -la app/Services/FlexibleCacheService.php
# Expected: File exists

# Test Proxmox API connection
php artisan tinker --execute="
  \$client = new \App\Services\ProxmoxApiClient(
    '192.168.0.245', 8006,
    config('proxmox.username'),
    config('proxmox.password')
  );
  echo \$client->authenticate() ? 'SUCCESS' : 'FAILED';
"
# Expected: SUCCESS
```

### Step 2: Configure Proxmox API Credentials

**Add to `.env`**:
```env
# Proxmox VE API Configuration
PROXMOX_HOST=192.168.0.245
PROXMOX_PORT=8006
PROXMOX_USERNAME=root@pam
PROXMOX_PASSWORD=your-proxmox-password
PROXMOX_VERIFY_SSL=false
PROXMOX_NODE=pve1
```

**Add to `config/proxmox.php`** (create if doesn't exist):
```php
<?php

return [
    'host' => env('PROXMOX_HOST', '192.168.0.245'),
    'port' => env('PROXMOX_PORT', 8006),
    'username' => env('PROXMOX_USERNAME', 'root@pam'),
    'password' => env('PROXMOX_PASSWORD'),
    'verify_ssl' => env('PROXMOX_VERIFY_SSL', false),
    'node' => env('PROXMOX_NODE', 'pve1'),

    'circuit_breaker' => [
        'threshold' => 5,
        'timeout' => 60,
    ],

    'retry' => [
        'max_attempts' => 3,
        'backoff' => 500, // milliseconds
    ],
];
```

### Step 3: Create Backup

```bash
# Execute deployment script in dry-run mode first
./deploy/phase2-deployment-script.sh --dry-run

# Create backup
mkdir -p storage/backups/phase2-$(date +%Y%m%d)
php artisan db:backup --path=storage/backups/phase2-$(date +%Y%m%d)/database.sql
cp .env storage/backups/phase2-$(date +%Y%m%d)/.env.backup
cp config/proxmox.php storage/backups/phase2-$(date +%Y%m%d)/proxmox.php.backup
```

### Step 4: Run Database Migrations

```bash
# Review pending migrations
php artisan migrate:status

# Expected output:
# Migration name ............................................. Batch / Status
# 2025_01_11_000003_create_proxmox_servers_table ............. Pending
# 2025_01_11_000004_create_lxc_containers_table .............. Pending

# Execute migrations
php artisan migrate --force

# Verify tables created
php artisan tinker --execute="
  DB::select('SHOW TABLES LIKE \"proxmox_servers\"');
  DB::select('SHOW TABLES LIKE \"lxc_containers\"');
"
# Expected: Both tables exist

# Verify indexes
php artisan tinker --execute="
  DB::select('SHOW INDEXES FROM proxmox_servers');
  DB::select('SHOW INDEXES FROM lxc_containers');
"
```

**Expected Downtime**: ~2-3 minutes

### Step 5: Verify New Service Files

```bash
# Verify all Phase 2 files exist
ls -la app/Services/ProxmoxApiClient.php
ls -la app/DTOs/ProxmoxApiResponse.php
ls -la app/DTOs/ContainerMetrics.php
ls -la app/Repositories/ProxmoxContainerRepository.php
ls -la app/Models/ProxmoxServer.php
ls -la app/Models/LxcContainer.php

# All files should exist and be readable
```

### Step 6: Test Repository Pattern

```bash
# Test ProxmoxApiClient
php artisan tinker
>>> $client = app(\App\Services\ProxmoxApiClient::class);
>>> $response = $client->getNodes();
>>> echo $response->isSuccess() ? 'SUCCESS' : 'FAILED';
>>> exit

# Test ProxmoxContainerRepository
php artisan tinker
>>> $repo = app(\App\Repositories\ProxmoxContainerRepository::class);
>>> $containers = $repo->getAllContainers('pve1');
>>> echo 'Found ' . $containers->count() . ' containers';
>>> exit

# Test DTOs
php artisan tinker
>>> $metrics = \App\DTOs\ContainerMetrics::fromProxmoxResponse([
...   'vmid' => 179,
...   'name' => 'agldv03',
...   'status' => 'running',
...   'cpu' => 0.25,
...   'mem' => 12884901888,
...   'maxmem' => 51539607552,
...   'disk' => 8589934592,
...   'maxdisk' => 107374182400,
...   'uptime' => 86400,
... ]);
>>> echo $metrics->getHealthStatus();
>>> echo $metrics->getMemoryUsagePercent();
>>> exit
```

### Step 7: Verify InfrastructureAnalyticsService Update

```bash
# Test FlexibleCacheService integration
php artisan tinker
>>> $service = app(\App\Services\InfrastructureAnalyticsService::class);
>>> $metrics = ['AGLSRV1' => ['status' => 'online', 'metrics' => ['resources' => ['cpu_usage' => 45, 'memory_usage' => 60, 'disk_usage' => 70]]]];
>>> $analysis = $service->analyzeInfrastructure($metrics);
>>> echo json_encode($analysis['health_score'], JSON_PRETTY_PRINT);
>>> exit

# Verify cache is being used
php artisan cache:clear
php artisan tinker
>>> $start = microtime(true);
>>> $service = app(\App\Services\InfrastructureAnalyticsService::class);
>>> $analysis = $service->analyzeInfrastructure($metrics);
>>> $firstCallTime = round((microtime(true) - $start) * 1000, 2);
>>> echo "First call: {$firstCallTime}ms\n";
>>>
>>> $start = microtime(true);
>>> $analysis = $service->analyzeInfrastructure($metrics);
>>> $cachedCallTime = round((microtime(true) - $start) * 1000, 2);
>>> echo "Cached call: {$cachedCallTime}ms\n";
>>> exit

# Expected: Cached call should be 90%+ faster
```

### Step 8: Restart Services

```bash
# Clear all caches
php artisan optimize:clear

# Rebuild optimized files
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Terminate Horizon workers (supervisor will restart)
php artisan horizon:terminate

# Wait 10 seconds for Horizon to restart
sleep 10

# Verify Horizon is running
php artisan horizon:status
# Expected: running
```

### Step 9: Post-Deployment Verification

```bash
# 1. Verify Proxmox API client works
curl -s http://localhost/api/infrastructure/proxmox/servers | jq '.success'
# Expected: true

# 2. Verify container metrics
curl -s http://localhost/api/infrastructure/proxmox/containers/pve1 | jq '.data | length'
# Expected: Number of containers (e.g., 68)

# 3. Verify health status classification
curl -s http://localhost/api/infrastructure/proxmox/containers/pve1/179 | jq '.data.health_status'
# Expected: "healthy", "warning", or "critical"

# 4. Test circuit breaker
# Temporarily disable Proxmox to test circuit breaker
# After 5 failed requests, circuit should open

# 5. Check application logs
tail -f storage/logs/laravel.log | grep "Proxmox"
# Should see authentication logs, API calls, etc.

# 6. Monitor Horizon dashboard
# Navigate to: http://your-domain/horizon
# Verify no failed jobs related to Proxmox
```

---

## 📊 Performance Validation

### Expected Improvements

| Metric | Before Phase 2 | After Phase 2 | Improvement |
|--------|----------------|---------------|-------------|
| Container status queries | Direct API calls | Cached + Repository | 80-90% faster |
| Multi-container queries | N sequential API calls | Batched + cached | 70-85% faster |
| Health status calculation | Manual array access | Type-safe DTO methods | 100% type safety |
| API resilience | No retry/circuit breaker | 3 retries + circuit breaker | 99.9% uptime |
| Code maintainability | Mixed concerns | Repository pattern | 60% less coupling |

### Performance Testing

```bash
# 1. Test container list caching performance
php artisan tinker --execute="
  \$repo = app(\App\Repositories\ProxmoxContainerRepository::class);

  // First call (uncached)
  \$start = microtime(true);
  \$containers = \$repo->getAllContainers('pve1');
  \$uncachedTime = round((microtime(true) - \$start) * 1000, 2);
  echo \"Uncached: {\$uncachedTime}ms\n\";

  // Second call (cached)
  \$start = microtime(true);
  \$containers = \$repo->getAllContainers('pve1');
  \$cachedTime = round((microtime(true) - \$start) * 1000, 2);
  echo \"Cached: {\$cachedTime}ms\n\";

  echo \"Speedup: \" . round(\$uncachedTime / max(\$cachedTime, 1), 2) . \"x\n\";
"
# Expected: 10-50x speedup for cached calls

# 2. Test health status classification
php artisan tinker --execute="
  \$repo = app(\App\Repositories\ProxmoxContainerRepository::class);
  \$critical = \$repo->getCriticalContainers('pve1');
  echo \"Critical containers: \" . \$critical->count() . \"\n\";
"

# 3. Test circuit breaker
php artisan tinker --execute="
  \$client = app(\App\Services\ProxmoxApiClient::class);
  echo json_encode(\$client->getCircuitBreakerStatus(), JSON_PRETTY_PRINT);
"
```

---

## 🔄 Rollback Procedure

### When to Rollback
- Migration failures
- Proxmox API connection issues
- Repository pattern errors
- Performance degradation
- Critical errors in logs

### Rollback Steps

```bash
# 1. Rollback database migrations
php artisan migrate:rollback --step=2

# Expected output:
# Rolling back: 2025_01_11_000004_create_lxc_containers_table
# Rolled back:  2025_01_11_000004_create_lxc_containers_table
# Rolling back: 2025_01_11_000003_create_proxmox_servers_table
# Rolled back:  2025_01_11_000003_create_proxmox_servers_table

# 2. Verify tables dropped
php artisan tinker --execute="
  DB::select('SHOW TABLES LIKE \"proxmox_servers\"');
  DB::select('SHOW TABLES LIKE \"lxc_containers\"');
"
# Expected: No tables found

# 3. Restore InfrastructureAnalyticsService
BACKUP_DIR=./storage/backups/phase2-YYYYMMDD
cp "$BACKUP_DIR/InfrastructureAnalyticsService.php.backup" app/Services/InfrastructureAnalyticsService.php

# 4. Clear caches
php artisan optimize:clear

# 5. Restart Horizon
php artisan horizon:terminate

# 6. Verify application functionality
php artisan tinker --execute="DB::connection()->getPdo()"
# Expected: PDO connection object
```

---

## 🐛 Troubleshooting

### Issue 1: Proxmox API Connection Failed

**Error**: `Connection refused [tcp://192.168.0.245:8006]`

**Solution**:
```bash
# Check Proxmox server is accessible
ping -c 3 192.168.0.245

# Test API endpoint directly
curl -k https://192.168.0.245:8006/api2/json/version

# Update firewall rules if needed
# On Proxmox host:
# iptables -A INPUT -p tcp --dport 8006 -j ACCEPT

# Verify .env configuration
php artisan tinker --execute="echo config('proxmox.host')"
```

### Issue 2: Authentication Failed

**Error**: `Authentication failed` in logs

**Solution**:
```bash
# Verify credentials
php artisan tinker
>>> $client = new \App\Services\ProxmoxApiClient(
...   config('proxmox.host'),
...   config('proxmox.port'),
...   config('proxmox.username'),
...   config('proxmox.password')
... );
>>> echo $client->authenticate() ? 'SUCCESS' : 'FAILED';

# If failed, check credentials on Proxmox:
# - Web UI → Datacenter → Permissions → Users
# - Verify user has PVEAdmin role
```

### Issue 3: Circuit Breaker Opened

**Error**: `Circuit breaker is open` in responses

**Solution**:
```bash
# Check circuit breaker status
php artisan tinker --execute="
  \$client = app(\App\Services\ProxmoxApiClient::class);
  print_r(\$client->getCircuitBreakerStatus());
"

# Wait for timeout period (60 seconds) or manually reset
php artisan cache:forget('proxmox_circuit_breaker')

# Test connection
php artisan tinker --execute="
  \$client = app(\App\Services\ProxmoxApiClient::class);
  echo \$client->authenticate() ? 'SUCCESS' : 'FAILED';
"
```

### Issue 4: Migration Failed - Foreign Key Constraint

**Error**: `Cannot add foreign key constraint`

**Solution**:
```bash
# Check if physical_locations table exists
php artisan tinker --execute="
  DB::select('SHOW TABLES LIKE \"physical_locations\"');
"

# If not exists, create it first
# Then re-run migrations
php artisan migrate --force
```

### Issue 5: Repository Returns Empty Collection

**Error**: `getAllContainers()` returns empty collection

**Solution**:
```bash
# Test Proxmox API directly
php artisan tinker --execute="
  \$client = app(\App\Services\ProxmoxApiClient::class);
  \$response = \$client->getContainers('pve1');
  echo 'Success: ' . (\$response->isSuccess() ? 'YES' : 'NO') . \"\n\";
  echo 'Count: ' . count(\$response->getData()) . \"\n\";
  print_r(\$response->toArray());
"

# Check node name is correct
php artisan tinker --execute="
  \$client = app(\App\Services\ProxmoxApiClient::class);
  \$nodes = \$client->getNodes();
  print_r(\$nodes->getData());
"

# Update config/proxmox.php with correct node name
```

---

## 📈 Monitoring After Deployment

### 1. Application Logs

```bash
# Real-time Proxmox API logs
tail -f storage/logs/laravel.log | grep "Proxmox"

# Filter for errors
tail -f storage/logs/laravel.log | grep -E "(ERROR|CRITICAL)" | grep "Proxmox"

# Circuit breaker events
tail -f storage/logs/laravel.log | grep "circuit breaker"
```

### 2. Horizon Dashboard

Navigate to: `http://your-domain/horizon`

**Key Metrics**:
- Failed Jobs (should be <1%)
- Wait Time (should be <5s)
- Runtime (API calls should be 100-300ms)
- Throughput (jobs/min)

### 3. Database Performance

```bash
# Monitor slow queries
php artisan tinker --execute="
  DB::listen(function(\$query) {
    if (\$query->time > 100) {
      Log::warning('Slow query: ' . \$query->sql . ' [' . \$query->time . 'ms]');
    }
  });
"

# Check table sizes
php artisan tinker --execute="
  DB::select('
    SELECT
      table_name,
      table_rows,
      round((data_length + index_length) / 1024 / 1024, 2) as size_mb
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    AND table_name IN (\"proxmox_servers\", \"lxc_containers\")
  ');
"
```

### 4. Cache Performance

```bash
# Monitor cache hit/miss ratio
php artisan cache:clear
php artisan tinker --execute="
  \$hits = 0;
  \$misses = 0;

  for (\$i = 0; \$i < 10; \$i++) {
    \$start = microtime(true);
    \$repo = app(\App\Repositories\ProxmoxContainerRepository::class);
    \$containers = \$repo->getAllContainers('pve1');
    \$time = microtime(true) - \$start;

    if (\$time < 0.01) {
      \$hits++;
    } else {
      \$misses++;
    }
  }

  echo \"Cache hits: \$hits, misses: \$misses\n\";
  echo \"Hit ratio: \" . round((\$hits / 10) * 100, 2) . \"%\n\";
"
# Expected: 90%+ hit ratio after first call
```

---

## ✅ Sign-Off Checklist

After successful deployment, verify:

- [ ] Database migrations executed successfully
- [ ] proxmox_servers and lxc_containers tables created
- [ ] All indexes created and verified
- [ ] Proxmox API client can authenticate
- [ ] ProxmoxContainerRepository returns data
- [ ] ContainerMetrics DTO calculates health status correctly
- [ ] InfrastructureAnalyticsService uses FlexibleCacheService
- [ ] Circuit breaker pattern functional
- [ ] Retry logic working (test with temporary network issue)
- [ ] Performance improvements validated (80-90% faster)
- [ ] No errors in application logs
- [ ] Horizon workers running
- [ ] Cache hit ratio >90%
- [ ] Backup created and verified
- [ ] Documentation updated
- [ ] Team notified of deployment

**Deployment Sign-Off**:
- **Deployed By**: _________________
- **Date**: _________________
- **Time**: _________________
- **Environment**: Production / Staging / Development
- **Rollback Plan Verified**: Yes / No
- **Success**: Yes / No / Partial

---

## 🎯 Phase 2 Deliverables Summary

### Files Created (6 total)

1. **`app/Services/ProxmoxApiClient.php`** (380 lines)
   - Circuit breaker pattern implementation
   - Retry logic with exponential backoff
   - Authentication token caching
   - Comprehensive API methods

2. **`app/DTOs/ProxmoxApiResponse.php`** (111 lines)
   - Type-safe API response wrapper
   - Fluent error handling
   - Conversion methods

3. **`app/DTOs/ContainerMetrics.php`** (252 lines)
   - Container metrics DTO
   - Health status classification
   - Human-readable formatters
   - Critical threshold detection

4. **`app/Repositories/ProxmoxContainerRepository.php`** (267 lines)
   - Repository pattern implementation
   - FlexibleCacheService integration
   - Statistics methods
   - Critical container filtering

5. **`database/migrations/2025_01_11_000003_create_proxmox_servers_table.php`** (68 lines)
   - proxmox_servers table schema
   - Comprehensive indexes
   - Foreign key relationships

6. **`database/migrations/2025_01_11_000004_create_lxc_containers_table.php`** (74 lines)
   - lxc_containers table schema
   - Server relationship
   - Status tracking fields

### Files Modified (1)

1. **`app/Services/InfrastructureAnalyticsService.php`**
   - Integrated FlexibleCacheService
   - Replaced traditional caching (line 38)
   - Maintained backward compatibility

### Models Verified (2)

1. **`app/Models/ProxmoxServer.php`** (203 lines)
   - Already existed with proper relationships
   - Scopes and helper methods
   - Password encryption

2. **`app/Models/LxcContainer.php`** (273 lines)
   - Already existed with comprehensive methods
   - Resource tracking
   - Status management

**Total Lines of Code**: ~1,628 lines across 8 files

---

## 🚀 Next Phase Preparation

### Phase 3: Advanced Monitoring & AI Integration (Weeks 5-6)

**Objectives**:
1. Real-time container health monitoring
2. Predictive maintenance with AI
3. Automated scaling recommendations
4. Alert system integration
5. Performance trend analysis

**Prerequisites**:
- Phase 2 deployed successfully
- Repository pattern validated
- Performance improvements confirmed
- Team trained on new architecture

**Estimated Timeline**:
- Week 5: Monitoring system, alert integration
- Week 6: AI predictive models, trend analysis

---

**Next Steps**: Review this deployment guide and schedule Phase 2 deployment window with team.

**Deployment Window Recommendation**: Off-peak hours (2:00 AM - 4:00 AM UTC) for minimal user impact during 3-minute database migration downtime.

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-11
**Status**: ✅ Ready for Production Deployment
