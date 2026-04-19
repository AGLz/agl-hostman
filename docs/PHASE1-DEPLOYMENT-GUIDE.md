# Phase 1 Deployment Guide - Critical Fixes

> **Status**: Ready for Production
> **Est. Deployment Time**: 30-45 minutes
> **Downtime Required**: ~5 minutes (database migrations)
> **Rollback Time**: ~10 minutes

---

## 📋 Pre-Deployment Checklist

### 1. **Environment Requirements**
- [ ] PHP 8.2+ installed
- [ ] Laravel 12 running
- [ ] MySQL 8.0+ accessible
- [ ] Redis accessible (for queue driver)
- [ ] Sufficient disk space for backups (minimum 2GB)
- [ ] Supervisor configured for Horizon

### 2. **Backup Strategy**
- [ ] Database backup created
- [ ] .env file backed up
- [ ] Critical service files backed up
- [ ] Backup location verified: `./storage/backups/phase1-YYYYMMDD-HHMMSS/`

### 3. **Access Requirements**
- [ ] SSH access to server
- [ ] Database credentials
- [ ] Admin access to application
- [ ] Access to Harbor registry (if using Docker deployment)

---

## 🚀 Deployment Steps

### Step 1: Pre-Deployment Verification
```bash
# Navigate to application directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Check current environment
php artisan env
# Expected: production (or local/staging for testing)

# Test database connection
php artisan db:show
# Expected: Database connection successful

# Test Redis connection
php artisan tinker --execute="Redis::ping()"
# Expected: PONG

# Check Horizon status
php artisan horizon:status
# Expected: running
```

### Step 2: Create Backup
```bash
# Execute deployment script in dry-run mode first
./deploy/phase1-deployment-script.sh --dry-run

# Review what will be executed, then create backup
./deploy/phase1-deployment-script.sh

# Manual backup (alternative)
mkdir -p storage/backups/manual-$(date +%Y%m%d)
php artisan db:backup --path=storage/backups/manual-$(date +%Y%m%d)/database.sql
cp .env storage/backups/manual-$(date +%Y%m%d)/.env.backup
```

### Step 3: Run Database Migrations
```bash
# Review pending migrations
php artisan migrate:status

# Expected output:
# Migration name ............................................. Batch / Status
# 2025_01_11_000001_add_performance_indexes .................. Pending
# 2025_01_11_000002_switch_queue_driver_to_redis ............. Pending

# Execute migrations
php artisan migrate --force

# Verify indexes created
php artisan tinker
>>> DB::select('SHOW INDEXES FROM users WHERE Key_name = "users_email_index"')
```

**Expected Downtime**: ~2-5 minutes (depending on table sizes)

### Step 4: Configure Queue Driver
```bash
# Update .env file
sed -i.bak 's/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/' .env

# Or manually edit .env:
# QUEUE_CONNECTION=redis

# Clear config cache
php artisan config:clear

# Verify Redis queue configuration
php artisan tinker --execute="config('queue.default')"
# Expected: redis
```

### Step 5: Deploy New Service Files

**Option A: Manual Deployment**
```bash
# Files are already created in src/ directory
# Verify files exist:
ls -la app/Services/FlexibleCacheService.php
ls -la app/Services/AIModelServiceFixed.php
ls -la app/Services/EncryptedConfigService.php
ls -la app/Jobs/ProcessAIRequest.php
ls -la app/Http/Middleware/VerifyN8NWebhook.php
ls -la app/Http/Middleware/ThrottleApiRequests.php
ls -la app/Console/Commands/EncryptApiKeys.php

# No action needed - files already in place
```

**Option B: Docker Deployment** (if using Harbor + Dokploy)
```bash
# Build and push to Harbor
./deploy.sh

# Wait for Dokploy webhook to trigger deployment
# Monitor at: https://dok.aglz.io
```

### Step 6: Encrypt API Keys
```bash
# Verify encryption command is registered
php artisan list | grep encrypt

# Run encryption (dry-run verification first)
php artisan config:encrypt-api-keys --verify

# Encrypt all API keys
php artisan config:encrypt-api-keys

# Expected output:
# 🔐 API Key Encryption Tool
#
# Scanning .env for API keys...
#
# ✓ CLAUDE_API_KEY: Encrypted successfully
# ✓ GEMINI_API_KEY: Encrypted successfully
# ✓ OPENAI_API_KEY: Encrypted successfully
# ✓ N8N_API_KEY: Encrypted successfully
# ✓ N8N_WEBHOOK_SECRET: Encrypted successfully
#
# 📊 Summary:
#   Encrypted: 5
#   Skipped: 2
#   Errors: 0

# Verify encrypted keys
php artisan config:encrypt-api-keys --verify
```

### Step 7: Configure Middleware Routes
```bash
# Review middleware configuration
cat routes/api-middleware-config.php

# Add routes to routes/api.php (manual step)
# Copy contents from api-middleware-config.php to routes/api.php
# Or create symbolic link:
ln -s api-middleware-config.php routes/api-middleware.php

# Then include in routes/api.php:
# require __DIR__.'/api-middleware.php';
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

# Verify queue workers
php artisan queue:work --once
# Should execute successfully
```

### Step 9: Post-Deployment Verification
```bash
# 1. Check database indexes
php artisan tinker --execute="DB::select('SHOW INDEXES FROM users')" | grep users_email_index
# Expected: users_email_index found

# 2. Verify queue driver
php artisan tinker --execute="config('queue.default')"
# Expected: redis

# 3. Test flexible caching
php artisan tinker
>>> $service = app(\App\Services\FlexibleCacheService::class);
>>> $result = $service->cacheServerStatus('AGLSRV1', fn() => ['status' => 'ok']);
>>> echo json_encode($result);

# 4. Test rate limiting
curl -I http://localhost/api/infrastructure/locations
# Expected: X-RateLimit-Limit: 100

# 5. Test N8N webhook verification
curl -X POST http://localhost/webhooks/n8n \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
# Expected: 401 Unauthorized (missing signature)

# 6. Check Horizon dashboard
# Navigate to: http://your-domain/horizon
# Verify queue workers are running

# 7. Monitor application logs
tail -f storage/logs/laravel.log
# Check for any errors
```

---

## 📊 Performance Validation

### Expected Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Infrastructure Analysis Response | 500-800ms | 200-300ms | 60-70% faster |
| Multi-AI Query Execution | 6-10s | 2-3s | 60-70% faster |
| Database Query Time (with indexes) | 50-200ms | 5-20ms | 90% faster |
| API Rate Limit Protection | ❌ None | ✅ 100 req/min | Security ✓ |
| N8N Webhook Security | ❌ Unauthenticated | ✅ HMAC verified | Security ✓ |
| API Key Storage | ❌ Plain text | ✅ Encrypted | Security ✓ |

### Performance Testing
```bash
# 1. Test flexible cache performance
time php artisan tinker --execute="
  \$service = app(\App\Services\FlexibleCacheService::class);
  for (\$i = 0; \$i < 10; \$i++) {
    \$service->cacheServerStatus('AGLSRV1', fn() => ['data' => str_repeat('x', 1000)]);
  }
"
# Expected: <100ms total for 10 cache hits

# 2. Test database query performance
php artisan tinker --execute="
  \$start = microtime(true);
  \$users = \App\Models\User::withPrimaryLocation()->get();
  echo 'Query time: ' . round((microtime(true) - \$start) * 1000, 2) . 'ms';
"
# Expected: <50ms for 100 users

# 3. Monitor Horizon throughput
# Navigate to /horizon
# Check Jobs Per Minute metric
# Expected: 30-50 jobs/min (depending on load)
```

---

## 🔄 Rollback Procedure

### When to Rollback
- Database migration failures
- Service crashes after deployment
- Performance degradation
- Critical errors in logs
- Failed verification tests

### Rollback Steps
```bash
# Execute rollback script
./deploy/phase1-deployment-script.sh --rollback

# Expected output:
# ⚠️  ROLLBACK MODE
# Are you sure you want to rollback? (yes/no): yes
#
# [ERROR] Rolling back deployment...
# [INFO] Rolling back migrations...
# [INFO] Restoring .env file...
# [INFO] Restoring modified files...
# [INFO] Rollback completed ✓

# Verify rollback success
php artisan migrate:status
# Expected: Last 2 migrations marked as not run

# Restart services
php artisan horizon:terminate
php artisan optimize:clear

# Verify application functionality
php artisan tinker --execute="DB::connection()->getPdo()"
```

### Manual Rollback (if script fails)
```bash
# 1. Restore database
BACKUP_DIR=./storage/backups/phase1-YYYYMMDD-HHMMSS
php artisan db:restore --path="$BACKUP_DIR/database-backup.sql"

# 2. Restore .env
cp "$BACKUP_DIR/.env.backup" .env

# 3. Restore service files
cp "$BACKUP_DIR/User.php.backup" app/Models/User.php
cp "$BACKUP_DIR/AIModelService.php.backup" app/Services/AIModelService.php
cp "$BACKUP_DIR/InfrastructureAnalyticsService.php.backup" app/Services/InfrastructureAnalyticsService.php

# 4. Clear caches
php artisan optimize:clear

# 5. Restart Horizon
php artisan horizon:terminate
```

---

## 🐛 Troubleshooting

### Issue 1: Migration Failed - Index Already Exists
**Error**: `SQLSTATE[42000]: Syntax error or access violation: 1061 Duplicate key name 'users_email_index'`

**Solution**:
```bash
# Check existing indexes
php artisan tinker --execute="DB::select('SHOW INDEXES FROM users')"

# Drop conflicting index
php artisan tinker --execute="DB::statement('DROP INDEX users_email_index ON users')"

# Re-run migration
php artisan migrate --force
```

### Issue 2: Redis Connection Failed
**Error**: `Connection refused [tcp://127.0.0.1:6379]`

**Solution**:
```bash
# Check Redis status
systemctl status redis
# or
redis-cli ping

# Start Redis
systemctl start redis

# Update .env with correct Redis host
# REDIS_HOST=127.0.0.1 (or actual Redis server IP)
```

### Issue 3: Horizon Workers Not Starting
**Error**: `Horizon is inactive`

**Solution**:
```bash
# Check Supervisor status
supervisorctl status horizon
# or
systemctl status supervisor

# Restart Supervisor
supervisorctl reread
supervisorctl update
supervisorctl start horizon

# Verify Horizon
php artisan horizon:status
```

### Issue 4: N8N Webhook Returns 401
**Expected Behavior**: N8N webhooks require HMAC signature

**Solution**:
```bash
# Generate signature for testing
php artisan tinker
>>> $payload = json_encode(['test' => 'data']);
>>> $signature = hash_hmac('sha256', $payload, config('services.n8n.webhook_secret'));
>>> echo $signature;

# Test with signature
curl -X POST http://localhost/webhooks/n8n \
  -H "Content-Type: application/json" \
  -H "X-N8N-Signature: <signature_from_above>" \
  -d '{"test": "data"}'
```

### Issue 5: API Rate Limit Too Restrictive
**Issue**: Legitimate users hitting rate limit

**Solution**:
```bash
# Adjust rate limit in routes/api.php
# Change from:
# ThrottleApiRequests::class . ':100,1'
# To:
# ThrottleApiRequests::class . ':200,1'

# Or clear rate limit for specific user
php artisan tinker
>>> App\Http\Middleware\ThrottleApiRequests::clearRateLimit('api:user:1');

# Rebuild route cache
php artisan route:cache
```

---

## 📈 Monitoring After Deployment

### 1. Application Logs
```bash
# Real-time log monitoring
tail -f storage/logs/laravel.log

# Filter for errors
tail -f storage/logs/laravel.log | grep ERROR

# Filter for specific component
tail -f storage/logs/laravel.log | grep "AI request"
```

### 2. Horizon Dashboard
Navigate to: `http://your-domain/horizon`

**Key Metrics to Monitor**:
- Jobs Per Minute (should be stable 30-50)
- Failed Jobs (should be <5% of total)
- Wait Time (should be <10s)
- Runtime (should match expected AI query times 2-3s)

### 3. Database Performance
```bash
# Monitor slow queries
php artisan tinker --execute="
  DB::listen(function(\$query) {
    if (\$query->time > 100) {
      \Log::warning('Slow query: ' . \$query->sql . ' [' . \$query->time . 'ms]');
    }
  });
"

# Check query cache hit rate
php artisan tinker --execute="
  DB::select('SHOW STATUS LIKE \"Qcache_hits\"');
"
```

### 4. Redis Monitoring
```bash
# Redis metrics
redis-cli info stats

# Monitor commands in real-time
redis-cli monitor | grep -i cache
```

---

## 📞 Support & Escalation

### Support Contacts
- **Technical Lead**: admin@agl.com.br
- **DevOps**: devops@agl.com.br
- **Discord**: discord.gg/agl
- **Documentation**: https://docs.aglz.io

### Escalation Matrix

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| Critical (site down) | Immediate | Technical Lead + DevOps |
| High (degraded) | 15 minutes | Technical Lead |
| Medium (warnings) | 1 hour | Team Lead |
| Low (informational) | Next business day | Team |

---

## ✅ Sign-Off Checklist

After successful deployment, verify:

- [ ] All migrations executed successfully
- [ ] Database indexes created and verified
- [ ] Queue driver switched to Redis
- [ ] Horizon workers running
- [ ] API keys encrypted
- [ ] Middleware routes configured
- [ ] N8N webhook verification working
- [ ] API rate limiting active
- [ ] Performance improvements validated
- [ ] No errors in application logs
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

**Next Steps**: Proceed to [Phase 2 - Repository Pattern & DTOs](./PHASE2-DEPLOYMENT-GUIDE.md) (Week 3-4)
