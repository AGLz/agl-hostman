# Blue-Green Deployment Strategy

**Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.3 - Production Deployment

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Deployment Workflow](#deployment-workflow)
4. [Approval Process](#approval-process)
5. [Traffic Switching](#traffic-switching)
6. [Rollback Procedures](#rollback-procedures)
7. [Monitoring During Deployment](#monitoring-during-deployment)
8. [Automated vs Manual Deployment](#automated-vs-manual-deployment)

---

## Overview

### What is Blue-Green Deployment?

Blue-green deployment is a release strategy that reduces downtime and risk by running two identical production environments:

- **Blue Environment**: Currently active, serving all production traffic
- **Green Environment**: Inactive, ready for new deployment

**Key Benefits**:
- ✅ **Zero-Downtime**: Instant traffic switch between environments
- ✅ **Fast Rollback**: < 2 minutes to revert to previous version
- ✅ **Testing in Production**: Validate new version before switching traffic
- ✅ **Reduced Risk**: Easy rollback if issues detected
- ✅ **Gradual Rollout**: Progressive traffic shifting (10% → 50% → 100%)

### When to Use Blue-Green

- ✅ Production deployments requiring zero downtime
- ✅ Major version upgrades with database migrations
- ✅ High-traffic applications where downtime is costly
- ✅ Deployments requiring production validation before full rollout

### When NOT to Use Blue-Green

- ❌ Development/QA environments (use direct deployment)
- ❌ Backward-incompatible database changes (requires migration strategy)
- ❌ Resource-constrained environments (requires 2x infrastructure)

---

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Load Balancer (Nginx)                   │
│              least_conn + health checks + SSL               │
└───────────────┬─────────────────────┬───────────────────────┘
                │                     │
        ┌───────▼──────┐      ┌──────▼───────┐
        │ Blue Cluster │      │ Green Cluster │
        ├──────────────┤      ├──────────────┤
        │ app-blue-1   │      │ app-green-1  │
        │ app-blue-2   │      │ app-green-2  │
        └───────┬──────┘      └──────┬───────┘
                │                    │
        ┌───────┴────────────────────┴───────┐
        │      Shared Infrastructure         │
        ├────────────────────────────────────┤
        │ PostgreSQL Primary + Replica       │
        │ Redis Master + Sentinel            │
        │ Prometheus + Grafana               │
        └────────────────────────────────────┘
```

### Shared vs Isolated Resources

**Shared Resources** (Single Instance):
- PostgreSQL database (primary + replica)
- Redis cache/queue (master + sentinel)
- Persistent storage (volumes)
- Monitoring stack (Prometheus, Grafana)
- Backup service

**Isolated Resources** (Per Environment):
- Application containers (2 replicas each)
- Application-level cache (in-memory)
- Temporary file storage

### Resource Requirements

**Blue Environment (Active)**:
- 2 application replicas
- 4 CPU cores, 8GB RAM (total)
- Active connections to database/Redis

**Green Environment (Inactive)**:
- 2 application replicas (initially 0, scaled up during deployment)
- 4 CPU cores, 8GB RAM (total)
- Standby connections to database/Redis

**Total**:
- 8-16 CPU cores (4 active + 4 standby during deployment)
- 16-32GB RAM (8 active + 8 standby during deployment)

---

## Deployment Workflow

### Step-by-Step Process

#### Phase 1: Pre-Deployment Validation

```bash
# 1. Verify current state
curl https://prod-agl.aglz.io/api/deployment/production/status

# Expected response:
{
  "success": true,
  "data": {
    "deployment_type": "blue_green",
    "active_slot": "blue",
    "active_version": "v1.0.0",
    "inactive_slot": "green",
    "inactive_version": null,
    "health_status": "healthy",
    "replicas": {
      "active": 2,
      "desired": 2
    }
  }
}
```

**Validation Checklist**:
- [ ] Current environment healthy (all replicas running)
- [ ] No active deployments in progress
- [ ] All smoke tests passing
- [ ] Database migrations compatible (backward-compatible if shared DB)
- [ ] Harbor image built and pushed
- [ ] 2-level approval obtained (lead-developer + admin)

#### Phase 2: Request Deployment

```bash
# API: Request production deployment
POST /api/deployment/production/request
{
  "version": "v1.1.0",
  "harbor_image": "harbor.aglz.io:5000/agl-hostman-prod:v1.1.0",
  "migration_required": false,
  "requester_notes": "Feature: Add new dashboard widgets"
}

# Response:
{
  "success": true,
  "data": {
    "approval_id": "uuid-1234",
    "status": "pending_approvals",
    "required_approvals": 2,
    "current_approvals": 0,
    "expires_at": "2025-01-21T10:00:00Z"
  }
}
```

#### Phase 3: Approval Workflow

**First Approval (Lead Developer)**:
```bash
POST /api/deployment/production/approve/{approval_id}
{
  "notes": "Code review passed, all tests green"
}
```

**Second Approval (Admin)**:
```bash
POST /api/deployment/production/approve/{approval_id}
{
  "notes": "Infrastructure ready, monitoring configured"
}
```

**Approval Status Check**:
```bash
GET /api/deployment/production/approval-status/{environment_id}

# Response when ready:
{
  "success": true,
  "data": {
    "status": "approved",
    "approvals": [
      {
        "level": "first",
        "role": "lead-developer",
        "approved_by": "john.doe",
        "approved_at": "2025-01-20T09:30:00Z"
      },
      {
        "level": "second",
        "role": "admin",
        "approved_by": "jane.smith",
        "approved_at": "2025-01-20T10:00:00Z"
      }
    ],
    "ready_for_deployment": true
  }
}
```

#### Phase 4: Deploy to Inactive Environment

**Automated (GitHub Actions)**:
```yaml
# Triggered by workflow_dispatch
# .github/workflows/deploy-production.yml handles:
# 1. Validate approvals
# 2. Build and push image
# 3. Deploy to green (inactive)
# 4. Run smoke tests
# 5. Switch traffic gradually
```

**Manual**:
```bash
# 1. Scale up green environment
docker compose -f docker-compose.green.yml up -d --scale app-green-1=1 --scale app-green-2=1

# 2. Update image version
docker compose -f docker-compose.green.yml pull
docker compose -f docker-compose.green.yml up -d

# 3. Wait for health checks
sleep 30

# 4. Verify green is healthy
curl http://app-green-1:3000/health
curl http://app-green-2:3000/health

# 5. Run smoke tests on green
docker exec agl-hostman-app-green-1 php artisan test --testsuite=Production --stop-on-failure
```

**Expected Output**:
```
✓ All smoke tests passing (16/16)
✓ Both replicas healthy
✓ Database connectivity verified
✓ Redis connectivity verified
✓ External integrations working
```

#### Phase 5: Gradual Traffic Switch

**10% Traffic to Green**:
```bash
# API call to switch traffic
POST /api/deployment/production/switch-traffic
{
  "target_slot": "green",
  "percentage": 10
}

# Monitoring window: 5 minutes
# Watch for errors, latency spikes
```

**50% Traffic to Green**:
```bash
POST /api/deployment/production/switch-traffic
{
  "target_slot": "green",
  "percentage": 50
}

# Monitoring window: 5 minutes
```

**100% Traffic to Green**:
```bash
POST /api/deployment/production/switch-traffic
{
  "target_slot": "green",
  "percentage": 100
}

# Monitoring window: 10 minutes
# Green is now active, blue is inactive
```

**Nginx Configuration Update**:
```nginx
# During traffic switch, nginx.conf is dynamically updated:

# 10% to green
upstream backend {
    least_conn;
    server app-blue-1:3000 weight=9;
    server app-blue-2:3000 weight=9;
    server app-green-1:3000 weight=1;
    server app-green-2:3000 weight=1;
}

# 50% to green
upstream backend {
    least_conn;
    server app-blue-1:3000 weight=5;
    server app-blue-2:3000 weight=5;
    server app-green-1:3000 weight=5;
    server app-green-2:3000 weight=5;
}

# 100% to green (blue becomes inactive)
upstream backend {
    least_conn;
    server app-green-1:3000;
    server app-green-2:3000;
}
```

#### Phase 6: Finalize Deployment

```bash
# API: Finalize deployment
POST /api/deployment/production/deploy
{
  "finalize": true
}

# Response:
{
  "success": true,
  "data": {
    "active_slot": "green",
    "active_version": "v1.1.0",
    "inactive_slot": "blue",
    "inactive_version": "v1.0.0",
    "rollback_available": true,
    "rollback_window_expires_at": "2025-01-20T11:00:00Z"
  }
}

# Blue environment is kept running for 1 hour (rollback window)
# After 1 hour, blue replicas are scaled down to save resources
```

---

## Approval Process

### 2-Level Approval Workflow

**Level 1: Lead Developer Approval**
- **Required Role**: `lead-developer`
- **Purpose**: Code review and technical validation
- **Checklist**:
  - [ ] All tests passing (unit, integration, smoke)
  - [ ] Code review completed
  - [ ] No critical security vulnerabilities
  - [ ] Database migrations backward-compatible
  - [ ] Performance benchmarks met

**Level 2: Admin Approval**
- **Required Role**: `admin`
- **Purpose**: Infrastructure and business validation
- **Checklist**:
  - [ ] Infrastructure capacity sufficient
  - [ ] Monitoring dashboards configured
  - [ ] Backup systems operational
  - [ ] Deployment window approved by business
  - [ ] Rollback plan reviewed

### Approval Rules

1. **Two Different Users**: Cannot be approved by same person twice
2. **Time Window**: 24 hours to obtain both approvals
3. **Expiration**: Approvals expire after 24 hours if not deployed
4. **Revocation**: Admins can reject/revoke approvals before deployment
5. **Audit Trail**: All approvals logged with user, timestamp, notes

### API Endpoints

```bash
# Request deployment
POST /api/deployment/production/request

# Approve (first or second level)
POST /api/deployment/production/approve/{id}
{
  "notes": "Approval reason"
}

# Reject
POST /api/deployment/production/reject/{id}
{
  "reason": "Rejection reason"
}

# Check approval status
GET /api/deployment/production/approval-status/{environmentId}

# List pending approvals (admin only)
GET /api/deployment/production/approvals/pending
```

---

## Traffic Switching

### Gradual Rollout Strategy

**Why Gradual?**
- Detect issues with minimal user impact
- Monitor performance under real traffic
- Validate new version incrementally
- Easy rollback if issues detected

**Traffic Intervals**:
- **10%**: Canary testing, detect critical errors
- **50%**: Performance validation, load testing
- **100%**: Full rollout, complete migration

### Monitoring Between Intervals

**Key Metrics** (must be within thresholds):
- Error Rate: < 1%
- P95 Response Time: < 500ms
- Database Pool Utilization: < 80%
- Memory Usage: < 85%
- CPU Usage: < 80%

**Auto-Rollback Triggers**:
- Error rate > 5% for 1 minute
- P95 response time > 1000ms for 2 minutes
- Critical service unavailable

### Manual Traffic Control

```bash
# Check current traffic distribution
GET /api/deployment/production/status

# Manually adjust traffic
POST /api/deployment/production/switch-traffic
{
  "target_slot": "green",
  "percentage": 25  # Custom percentage
}

# Immediate switch (emergency)
POST /api/deployment/production/switch-traffic
{
  "target_slot": "blue",
  "percentage": 100,
  "immediate": true  # Skip gradual rollout
}
```

### Session Persistence

**Problem**: Users might be switched mid-session during traffic shift

**Solution**: Shared Redis session store
```php
// Both blue and green share same Redis
'SESSION_DRIVER' => 'redis'
'SESSION_CONNECTION' => 'session'  // Shared Redis master

// Session persists across slot switch
// User logged in on blue → remains logged in on green
```

**Database Transactions**: Use shared PostgreSQL primary
- Write operations go to primary (shared)
- Read operations can use replica (shared)
- Transactions complete regardless of which slot served request

---

## Rollback Procedures

### When to Rollback

**Automatic Rollback Triggers**:
- Error rate > 5% for 1 minute
- P95 response time > 1000ms for 2 minutes
- Critical service (database, Redis, queue) unavailable
- Health check failures on both replicas

**Manual Rollback Criteria**:
- Business-critical functionality broken
- Data integrity issues detected
- Security vulnerability discovered
- Customer-reported critical bugs

### Rollback Time Window

**Within 1 Hour**: Fast rollback available
- Previous version still running in inactive slot
- Instant traffic switch (< 30 seconds)
- Zero downtime rollback

**After 1 Hour**: Slower rollback (requires redeployment)
- Previous version containers scaled down to save resources
- Requires pulling image from Harbor and redeploying
- Rollback time: 5-10 minutes

### Fast Rollback (< 2 Minutes)

```bash
# API: Immediate rollback
POST /api/deployment/production/rollback
{
  "immediate": true,
  "reason": "Critical error in new version"
}

# Process:
# 1. Verify previous slot is healthy (< 10 seconds)
# 2. Switch 100% traffic to previous slot (< 30 seconds)
# 3. Update active_slot in database (< 5 seconds)
# 4. Send notifications (async)
# Total: < 60 seconds
```

**Manual Rollback**:
```bash
# 1. Verify blue (previous) is healthy
docker compose -f docker-compose.blue.yml ps
curl http://app-blue-1:3000/health
curl http://app-blue-2:3000/health

# 2. Update nginx to point to blue
docker exec agl-hostman-load-balancer sed -i 's/app-green/app-blue/g' /etc/nginx/nginx.conf
docker exec agl-hostman-load-balancer nginx -s reload

# 3. Verify traffic switched
curl https://prod-agl.aglz.io/health
# Should now be served by blue

# Total time: < 2 minutes
```

### Post-Rollback Actions

1. **Investigate Root Cause**:
   - Review error logs
   - Check monitoring dashboards
   - Analyze database queries
   - Review recent code changes

2. **Fix Issues**:
   - Create hotfix branch
   - Fix bugs
   - Re-run tests
   - Request new approvals

3. **Redeploy**:
   - Build new image with fixes
   - Follow normal deployment process
   - Extra scrutiny during traffic switch

4. **Document**:
   - Update runbook with lessons learned
   - Add new monitoring alerts if needed
   - Update rollback procedures if gaps found

---

## Monitoring During Deployment

### Pre-Deployment Checks

```bash
# Verify monitoring is working
curl http://localhost:9090/api/v1/targets  # Prometheus
curl http://localhost:3001/api/health      # Grafana

# Check all exporters are up
docker ps | grep exporter
```

### Real-Time Monitoring

**Grafana Dashboard**: "Production Deployment Status"
- Active slot traffic rate
- Inactive slot traffic rate (during switch)
- Error rates per slot
- Response times per slot
- Database query performance
- Redis hit/miss rates

**Prometheus Queries**:
```promql
# Error rate per slot
rate(http_requests_total{status=~"5..",slot="green"}[5m])

# Response time (P95) per slot
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{slot="green"}[5m]))

# Traffic distribution
sum(rate(http_requests_total{slot="blue"}[1m])) / sum(rate(http_requests_total[1m]))
```

### Alerts During Deployment

**Temporarily Suppressed**:
- Latency spikes (expected during switch)
- Connection pool fluctuations

**Never Suppressed**:
- Error rate alerts
- Database connectivity
- Redis connectivity
- Disk space warnings
- Security alerts

### Post-Deployment Monitoring

**1-Hour Window**: Intensive monitoring
- Watch error rates every 5 minutes
- Monitor response times
- Check database slow query log
- Review application logs for warnings

**24-Hour Window**: Normal monitoring
- Hourly metrics review
- Daily summary email
- Weekly performance report

---

## Automated vs Manual Deployment

### Automated Deployment (GitHub Actions)

**Trigger**:
```bash
# From GitHub UI or CLI
gh workflow run deploy-production.yml \
  --ref main \
  --field version=v1.1.0 \
  --field harbor_image=harbor.aglz.io:5000/agl-hostman-prod:v1.1.0
```

**Process**:
1. ✅ Validate 2-level approval exists
2. ✅ Build and scan image (Trivy)
3. ✅ Push to Harbor registry
4. ✅ Deploy to inactive slot (green)
5. ✅ Run smoke tests
6. ✅ Gradual traffic switch (10% → 50% → 100%)
7. ✅ Monitor for issues
8. ✅ Auto-rollback if errors
9. ✅ Send notifications

**Advantages**:
- Consistent deployment process
- Audit trail in GitHub
- Automated testing and validation
- Built-in rollback logic

### Manual Deployment

**When to Use**:
- Emergency hotfixes
- Troubleshooting deployment issues
- Testing deployment process
- Automation is broken

**Process**:
```bash
# 1. Verify approvals (manual check)
# 2. Build and push image manually
docker build -t harbor.aglz.io:5000/agl-hostman-prod:v1.1.0 .
docker push harbor.aglz.io:5000/agl-hostman-prod:v1.1.0

# 3. Deploy to green
docker compose -f docker-compose.green.yml up -d

# 4. Run tests
docker exec agl-hostman-app-green-1 php artisan test --testsuite=Production

# 5. Switch traffic (manual API calls)
curl -X POST https://prod-agl.aglz.io/api/deployment/production/switch-traffic \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"target_slot":"green","percentage":10}'

# Wait 5 minutes, monitor metrics

curl -X POST https://prod-agl.aglz.io/api/deployment/production/switch-traffic \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"target_slot":"green","percentage":50}'

# Wait 5 minutes, monitor metrics

curl -X POST https://prod-agl.aglz.io/api/deployment/production/switch-traffic \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"target_slot":"green","percentage":100}'

# 6. Finalize
curl -X POST https://prod-agl.aglz.io/api/deployment/production/deploy \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"finalize":true}'
```

**Disadvantages**:
- Manual steps prone to errors
- Requires deep knowledge of process
- No automated rollback
- Less audit trail

---

## Best Practices

### Database Migrations

**Backward-Compatible Migrations**:
```php
// ✅ GOOD: Add nullable column
Schema::table('users', function (Blueprint $table) {
    $table->string('phone')->nullable();
});

// ✅ GOOD: Add column with default
Schema::table('users', function (Blueprint $table) {
    $table->boolean('active')->default(true);
});

// ❌ BAD: Drop column (breaks old code)
Schema::table('users', function (Blueprint $table) {
    $table->dropColumn('legacy_field');
});

// ❌ BAD: Rename column (breaks old code)
Schema::table('users', function (Blueprint $table) {
    $table->renameColumn('old_name', 'new_name');
});
```

**Multi-Phase Migration Strategy**:
```
Phase 1: Add new column (nullable)
- Deploy v1.1 (reads from old OR new column)

Phase 2: Backfill data
- Migrate data from old to new column

Phase 3: Make non-nullable
- Deploy v1.2 (reads only from new column)

Phase 4: Drop old column
- Deploy v1.3 (old column no longer referenced)
```

### Health Checks

**Comprehensive Health Check**:
```php
// routes/web.php
Route::get('/health', function () {
    $checks = [];

    // Database
    try {
        DB::connection()->getPdo();
        $checks['database'] = 'ok';
    } catch (\Exception $e) {
        $checks['database'] = 'error';
    }

    // Redis
    try {
        Cache::store('redis')->get('health-check');
        $checks['redis'] = 'ok';
    } catch (\Exception $e) {
        $checks['redis'] = 'error';
    }

    // Queue
    try {
        Queue::connection()->size();
        $checks['queue'] = 'ok';
    } catch (\Exception $e) {
        $checks['queue'] = 'error';
    }

    $status = in_array('error', $checks) ? 503 : 200;

    return response()->json([
        'status' => $status === 200 ? 'healthy' : 'unhealthy',
        'checks' => $checks,
        'timestamp' => now()->toIso8601String(),
    ], $status);
});
```

### Deployment Windows

**Recommended Times**:
- **Weekdays**: Tuesday-Thursday, 10:00-14:00 (low traffic)
- **Avoid**: Monday morning, Friday afternoon, weekends
- **Never**: During peak hours, major holidays, business-critical events

**Deployment Freeze Periods**:
- Black Friday / Cyber Monday
- End of quarter / fiscal year
- Major product launches
- Marketing campaigns

---

## Troubleshooting

### Deployment Stuck in Progress

**Symptom**: Deployment shows "in_progress" for > 30 minutes

**Diagnosis**:
```bash
# Check inactive slot health
curl http://app-green-1:3000/health
curl http://app-green-2:3000/health

# Check deployment logs
docker compose -f docker-compose.green.yml logs -f

# Check database migrations
docker exec agl-hostman-app-green-1 php artisan migrate:status
```

**Resolution**:
```bash
# If migrations stuck, rollback deployment
POST /api/deployment/production/rollback

# Fix migrations locally
php artisan migrate:rollback
php artisan migrate

# Redeploy
```

### Traffic Switch Failed

**Symptom**: Nginx returns 502 after traffic switch

**Diagnosis**:
```bash
# Check nginx config syntax
docker exec agl-hostman-load-balancer nginx -t

# Check upstream health
curl http://app-green-1:3000/health
curl http://app-green-2:3000/health

# Check nginx error log
docker logs agl-hostman-load-balancer --tail 100
```

**Resolution**:
```bash
# Immediate rollback to previous slot
docker exec agl-hostman-load-balancer sed -i 's/app-green/app-blue/g' /etc/nginx/nginx.conf
docker exec agl-hostman-load-balancer nginx -s reload

# Investigate green environment issues
docker compose -f docker-compose.green.yml restart
```

### Rollback Not Available

**Symptom**: API returns "rollback window expired"

**Diagnosis**:
```bash
# Check deployment timestamp
GET /api/deployment/production/status

# Check if previous slot still running
docker compose -f docker-compose.blue.yml ps
```

**Resolution**:
```bash
# Manual redeployment of previous version
docker compose -f docker-compose.blue.yml pull
docker compose -f docker-compose.blue.yml up -d

# Wait for health checks
sleep 30

# Switch traffic
POST /api/deployment/production/switch-traffic
{
  "target_slot": "blue",
  "percentage": 100,
  "immediate": true
}
```

---

## References

- [PRODUCTION-ENVIRONMENT-SETUP.md](PRODUCTION-ENVIRONMENT-SETUP.md) - Infrastructure setup
- [PRODUCTION-RUNBOOK.md](PRODUCTION-RUNBOOK.md) - Operations procedures
- [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) - DR procedures

---

**Document Version**: 1.0.0
**Last Review**: 2025-01-20
**Next Review**: 2025-02-20
