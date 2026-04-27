# Phase 3 Deployment Guide - Advanced Monitoring & AI Integration

> **Status**: Ready for Production
> **Est. Deployment Time**: 30-45 minutes
> **Downtime Required**: ~5 minutes (database migrations + job restart)
> **Rollback Time**: ~10 minutes
> **Dependencies**: Phase 2 (Repository Pattern & DTOs)

---

## 📋 Pre-Deployment Checklist

### 1. **Prerequisites**
- [ ] Phase 2 deployed successfully and verified
- [ ] ProxmoxContainerRepository working correctly
- [ ] Redis accessible for caching and queues
- [ ] Laravel Horizon running for background jobs
- [ ] Alert channels configured (Slack/Discord/Email)
- [ ] Broadcasting driver configured (Pusher/Redis)

### 2. **Backup Strategy**
- [ ] Database backup created (includes Phase 2 tables)
- [ ] .env file backed up
- [ ] Horizon configuration backed up
- [ ] Backup location verified: `./storage/backups/phase3-YYYYMMDD-HHMMSS/`

### 3. **Alert Configuration**
- [ ] Slack webhook URL obtained (if using Slack)
- [ ] Discord webhook URL obtained (if using Discord)
- [ ] Email recipients list confirmed
- [ ] Test alert endpoints accessible

---

## 🚀 Deployment Steps

### Step 1: Pre-Deployment Verification

```bash
# Navigate to application directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Verify Phase 2 is deployed
php artisan migrate:status | grep "2025_01_11_000004_create_lxc_containers"
# Expected: Ran

# Verify ProxmoxContainerRepository exists
ls -la app/Repositories/ProxmoxContainerRepository.php
# Expected: File exists

# Test container repository
php artisan tinker --execute="
  \$repo = app(\App\Repositories\ProxmoxContainerRepository::class);
  echo \$repo->getAllContainers('pve1')->count() . ' containers found';
"
# Expected: Number of containers displayed

# Verify Horizon is running
php artisan horizon:status
# Expected: "running"
```

### Step 2: Configure Alert Channels

**Add to `.env`**:
```env
# Alert Configuration
ALERTS_SLACK_ENABLED=true
ALERTS_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

ALERTS_DISCORD_ENABLED=true
ALERTS_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK/ID/TOKEN

ALERTS_EMAIL_ENABLED=true
ALERTS_EMAIL_RECIPIENTS=admin@example.com,ops@example.com

# Monitoring Configuration
MONITORING_INTERVAL_REALTIME=30
MONITORING_INTERVAL_ANALYSIS=300
MONITORING_INTERVAL_PREDICTION=1800

# Health Check Thresholds
HEALTH_CPU_WARNING=70
HEALTH_CPU_CRITICAL=90
HEALTH_MEMORY_WARNING=70
HEALTH_MEMORY_CRITICAL=85
HEALTH_DISK_WARNING=60
HEALTH_DISK_CRITICAL=80
```

**Create `config/alerts.php`**:
```php
<?php

return [
    'slack' => [
        'enabled' => env('ALERTS_SLACK_ENABLED', false),
        'webhook_url' => env('ALERTS_SLACK_WEBHOOK_URL'),
    ],

    'discord' => [
        'enabled' => env('ALERTS_DISCORD_ENABLED', false),
        'webhook_url' => env('ALERTS_DISCORD_WEBHOOK_URL'),
    ],

    'email' => [
        'enabled' => env('ALERTS_EMAIL_ENABLED', false),
        'recipients' => explode(',', env('ALERTS_EMAIL_RECIPIENTS', '')),
    ],
];
```

### Step 3: Create Backup

```bash
# Create timestamped backup directory
BACKUP_DIR="./storage/backups/phase3-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
php artisan db:backup --path=$BACKUP_DIR

# Backup configuration files
cp .env $BACKUP_DIR/.env.backup
cp config/database.php $BACKUP_DIR/database.php.backup
cp config/horizon.php $BACKUP_DIR/horizon.php.backup 2>/dev/null || true

echo "Backup created at: $BACKUP_DIR"
```

### Step 4: Run Database Migrations

```bash
# Review migrations first
php artisan migrate:status

# Run Phase 3 migrations
php artisan migrate --step

# Expected migrations:
# - 2025_01_11_000005_create_container_health_logs_table
# - 2025_01_11_000006_create_performance_trends_table

# Verify tables created
php artisan tinker --execute="
  echo 'container_health_logs: ' . \Schema::hasTable('container_health_logs') . PHP_EOL;
  echo 'performance_trends: ' . \Schema::hasTable('performance_trends') . PHP_EOL;
"
# Expected: Both return 1 (true)
```

### Step 5: Register Event Listeners

**Update `app/Providers/EventServiceProvider.php`**:
```php
protected $listen = [
    \App\Events\ContainerCritical::class => [
        \App\Listeners\SendCriticalAlert::class,
    ],
    \App\Events\ResourceExhaustionPredicted::class => [
        \App\Listeners\SendCriticalAlert::class,
    ],
];
```

### Step 6: Configure Horizon Job Schedule

**Update `app/Console/Kernel.php`**:
```php
protected function schedule(Schedule $schedule)
{
    // Real-time container health monitoring (every 30 seconds)
    $schedule->job(new \App\Jobs\MonitorContainerHealth)
        ->everyThirtySeconds()
        ->withoutOverlapping(5)
        ->name('container-health-monitor');
}
```

### Step 7: Restart Services

```bash
# Clear all caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Restart Horizon workers
php artisan horizon:terminate
sleep 3
php artisan horizon

# Verify Horizon is running
php artisan horizon:status
# Expected: "running"

# Check jobs are scheduled
php artisan schedule:list
# Expected: "container-health-monitor" listed
```

### Step 8: Test Alert Channels

```bash
# Test Slack alert
php artisan tinker --execute="
  \$dispatcher = app(\App\Services\AlertDispatcher::class);
  \$result = \$dispatcher->testChannel('slack');
  print_r(\$result);
"
# Expected: success => true

# Test Discord alert
php artisan tinker --execute="
  \$dispatcher = app(\App\Services\AlertDispatcher::class);
  \$result = \$dispatcher->testChannel('discord');
  print_r(\$result);
"
# Expected: success => true

# Test Email alert
php artisan tinker --execute="
  \$dispatcher = app(\App\Services\AlertDispatcher::class);
  \$result = \$dispatcher->testChannel('email');
  print_r(\$result);
"
# Expected: success => true
```

### Step 9: Verify Monitoring System

```bash
# Test ContainerHealthMonitor
php artisan tinker --execute="
  \$monitor = app(\App\Services\ContainerHealthMonitor::class);
  \$results = \$monitor->monitorNode('pve1');
  echo 'Total containers: ' . \$results['total_containers'] . PHP_EOL;
  echo 'Healthy: ' . \$results['healthy'] . PHP_EOL;
  echo 'Warning: ' . \$results['warning'] . PHP_EOL;
  echo 'Critical: ' . \$results['critical'] . PHP_EOL;
"
# Expected: Container counts displayed

# Check health logs created
php artisan tinker --execute="
  echo 'Health logs: ' . \App\Models\ContainerHealthLog::count() . PHP_EOL;
"
# Expected: Count > 0

# Test PredictiveMaintenanceService
php artisan tinker --execute="
  \$service = app(\App\Services\PredictiveMaintenanceService::class);
  \$prediction = \$service->predictResourceExhaustion('pve1', 179, 'memory', 'medium_term');
  print_r(\$prediction);
"
# Expected: Prediction results displayed
```

### Step 10: Monitor Job Execution

```bash
# Watch Horizon dashboard
php artisan horizon:list

# Check job metrics
php artisan horizon:failed
# Expected: No failed jobs initially

# Monitor logs
tail -f storage/logs/laravel.log | grep -i "monitoring\|health\|alert"
```

---

## 📊 Performance Validation

### Monitoring Performance Targets

| Metric | Target | Validation Command |
|--------|--------|-------------------|
| Monitoring Interval | 30s | Check `MonitorContainerHealth` job frequency |
| Health Log Creation | <500ms | Time `ContainerHealthMonitor::monitorNode()` |
| Alert Dispatch | <1000ms | Time `AlertDispatcher::dispatch()` |
| Database Query Time | <100ms | Check slow query log |
| Cache Hit Ratio | >90% | Monitor Redis stats |

### Validation Script

```bash
# Run performance validation
php artisan tinker --execute="
  \$start = microtime(true);
  \$monitor = app(\App\Services\ContainerHealthMonitor::class);
  \$results = \$monitor->monitorNode('pve1');
  \$elapsed = (microtime(true) - \$start) * 1000;
  echo 'Monitoring time: ' . round(\$elapsed, 2) . 'ms' . PHP_EOL;
  echo 'Target: <500ms' . PHP_EOL;
  echo 'Status: ' . (\$elapsed < 500 ? 'PASS' : 'FAIL') . PHP_EOL;
"
```

---

## 🧪 Integration Tests

```bash
# Run Phase 3 integration tests
php artisan test --filter=ContainerHealthMonitorTest

# Expected output:
#   PASS  Tests\Feature\Services\ContainerHealthMonitorTest
#   ✓ monitor node returns proper structure
#   ✓ critical container triggers alert
#   ✓ monitor nodes aggregates correctly
#   ✓ health logs are created
#   ✓ monitoring snapshot is stored
#   ✓ rate limiting prevents alert spam
#   ✓ get container history
#   ✓ get cluster health statistics
#   ✓ error handling for unavailable node
#
#   Tests:  9 passed
```

---

## 🔧 Troubleshooting Guide

### Common Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Jobs not running** | No health logs created | 1. Check Horizon status<br>2. Verify job schedule<br>3. Restart Horizon |
| **Alerts not sending** | No Slack/Discord/Email | 1. Verify webhook URLs<br>2. Check network connectivity<br>3. Test channels manually |
| **High memory usage** | Health logs table growing | 1. Run `ContainerHealthLog::cleanupOldTrends(90)`<br>2. Check retention policy<br>3. Optimize queries |
| **Prediction errors** | Insufficient data errors | 1. Wait for data accumulation (24h)<br>2. Check historical logs count |
| **Database locks** | Slow queries | 1. Add indexes if missing<br>2. Check migration completion<br>3. Optimize concurrent writes |

### Diagnostic Commands

```bash
# Check Horizon workers
php artisan horizon:list

# Monitor job queue
watch -n 1 'redis-cli -h localhost -p 6379 llen queues:default'

# Check database connections
php artisan tinker --execute="echo DB::connection()->getDatabaseName();"

# Verify event listeners
php artisan event:list | grep Container

# Check broadcasting
php artisan tinker --execute="event(new \App\Events\ContainerCritical('test', 999, 'test', 'critical', [], []));"

# Monitor cache performance
redis-cli INFO stats | grep hit_rate
```

---

## 🔄 Rollback Procedures

### Emergency Rollback (5-10 minutes)

```bash
# Stop Horizon
php artisan horizon:terminate

# Rollback migrations
php artisan migrate:rollback --step=2

# Restore configuration
LATEST_BACKUP=$(ls -td storage/backups/phase3-* | head -1)
cp $LATEST_BACKUP/.env.backup .env
cp $LATEST_BACKUP/horizon.php.backup config/horizon.php 2>/dev/null || true

# Clear caches
php artisan cache:clear
php artisan config:clear

# Restart Horizon
php artisan horizon

# Verify rollback
php artisan migrate:status
```

### Partial Rollback (Keep Data)

```bash
# Stop monitoring jobs only
php artisan horizon:pause

# Comment out job schedule in app/Console/Kernel.php
# Then restart Horizon
php artisan horizon:terminate && php artisan horizon
```

---

## 📈 Post-Deployment Monitoring

### First 24 Hours

```bash
# Monitor health log creation rate
watch -n 60 'php artisan tinker --execute="echo \App\Models\ContainerHealthLog::count();"'

# Check alert frequency
tail -f storage/logs/laravel.log | grep "alert triggered"

# Monitor job success rate
php artisan horizon:failed

# Check database growth
php artisan tinker --execute="
  echo 'Health logs: ' . \App\Models\ContainerHealthLog::count() . PHP_EOL;
  echo 'Performance trends: ' . \App\Models\PerformanceTrend::count() . PHP_EOL;
"
```

### Weekly Tasks

```bash
# Clean up old health logs (keep 90 days)
php artisan tinker --execute="
  \App\Models\ContainerHealthLog::where('created_at', '<', now()->subDays(90))->delete();
  \App\Models\PerformanceTrend::cleanupOldTrends(90);
"

# Review alert patterns
php artisan tinker --execute="
  \$criticalCount = \App\Models\ContainerHealthLog::critical()->recent(168)->count();
  echo 'Critical incidents (7d): ' . \$criticalCount . PHP_EOL;
"
```

---

## ✅ Deployment Sign-Off

### Validation Checklist

- [ ] All migrations executed successfully
- [ ] Health logs being created every 30 seconds
- [ ] Performance trends being recorded
- [ ] Alerts configured and tested
- [ ] Horizon jobs running without errors
- [ ] Integration tests passing (9/9)
- [ ] No errors in Laravel logs
- [ ] Cache hit ratio >90%
- [ ] Monitoring dashboard functional
- [ ] Team trained on new features

### Performance Metrics

| Metric | Baseline | Target | Actual | Status |
|--------|----------|--------|--------|--------|
| Monitoring Latency | N/A | <500ms | ___ms | ⬜ |
| Alert Dispatch | N/A | <1s | ___s | ⬜ |
| Database Query | N/A | <100ms | ___ms | ⬜ |
| Cache Hit Ratio | N/A | >90% | ___% | ⬜ |
| Job Success Rate | N/A | >99% | ___% | ⬜ |

---

**🎯 Phase 3: DEPLOYMENT READY ✅**

**Next Phase**: Phase 4 - Dashboard & Visualization (Weeks 7-8)
**Prerequisites**: Phase 3 deployed and accumulating monitoring data (24+ hours recommended)

**Post-Deployment**: Monitor for 24 hours, verify predictive maintenance accuracy, fine-tune alert thresholds based on real data.

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-11
**Status**: ✅ Ready for Production Deployment
**Phase 2 Dependency**: ✅ Verified
**Tests**: ✅ 9 integration tests passing
**Documentation**: ✅ Complete deployment guide with rollback procedures
