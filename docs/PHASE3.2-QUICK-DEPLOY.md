# Phase 3.2: UAT Deployment - Quick Start Guide

> **Fast-track deployment guide for UAT environment on CT181**
> **Estimated time**: 15-20 minutes

---

## Prerequisites Check

```bash
# 1. Verify you're in the correct directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
pwd

# 2. Check CT181 is accessible
ping -c 3 192.168.0.181

# 3. Verify Harbor registry
curl -I https://harbor.aglz.io

# 4. Check Dokploy on CT181
curl http://192.168.0.181:3000/api/health
```

**Required**:
- ✅ CT181 running and accessible
- ✅ Harbor registry at harbor.aglz.io:5000
- ✅ Dokploy API token for CT181
- ✅ Admin access to agl-hostman application

---

## Step 1: Configure Environment (2 minutes)

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Copy example if .env doesn't exist
cp .env.example .env

# Add UAT configuration
nano .env
```

**Add these lines to .env:**

```env
# ========== UAT Environment (CT181) ==========
UAT_DOKPLOY_URL=http://192.168.0.181:3000
UAT_DOKPLOY_TOKEN=dp-xxxxxxxxxxxxx
UAT_HARBOR_PROJECT=agl-hostman-uat
UAT_DOMAIN=uat-agl.aglz.io
UAT_DB_DATABASE=agl_hostman_uat
UAT_APPROVAL_REQUIRED=true
UAT_APPROVER_ROLES=admin,lead-developer
UAT_AUTO_DEPLOY=false
UAT_AUTO_TEST=true
UAT_TEST_TYPE=smoke
UAT_ROLLBACK_ON_FAILURE=true

# Promotion Settings
PROMOTION_APPROVAL_TIMEOUT=86400
SMOKE_TEST_TIMEOUT=120
SMOKE_TEST_PARALLEL=true
```

**Get Dokploy token:**
```bash
# Login to Dokploy on CT181
# http://192.168.0.181:3000
# Settings → API Tokens → Create Token
```

---

## Step 2: Run Database Migration (1 minute)

```bash
# Run promotions table migration
php artisan migrate --path=database/migrations/2025_01_20_000005_create_promotions_table.php

# Expected output:
# Migrating: 2025_01_20_000005_create_promotions_table
# Migrated:  2025_01_20_000005_create_promotions_table (XX.XXms)

# Verify table created
php artisan tinker
>>> \Illuminate\Support\Facades\Schema::hasTable('promotions')
=> true
>>> exit
```

---

## Step 3: Seed UAT Environment (1 minute)

```bash
# Create UAT environment record
php artisan db:seed --class=UATEnvironmentSeeder

# Expected output:
# ✅ Created UAT Environment (ID: xxx)
#    Name: UAT Environment
#    Type: uat
#    Branch: release
#    Auto-deploy: No (Manual Only)
```

---

## Step 4: Setup Dokploy Project on CT181 (5 minutes)

```bash
# Create Dokploy project and application
php artisan deployment:setup-uat

# This will:
# 1. Connect to CT181 Dokploy
# 2. Create "AGL-HOSTMAN UAT" project
# 3. Create application with UAT config
# 4. Configure domains (uat-agl.aglz.io)
# 5. Set environment variables
# 6. Configure resource limits (2 CPU, 4GB RAM)
```

**If command succeeds, you'll see:**
```
✅ UAT environment created successfully!
   Dokploy Project ID: xxx
   Application ID: xxx
   Domains: uat-agl.aglz.io
```

---

## Step 5: Configure Harbor (3 minutes)

```bash
# 1. Login to Harbor
open https://harbor.aglz.io
# OR: firefox https://harbor.aglz.io

# 2. Create UAT project
#    - Projects → New Project
#    - Name: agl-hostman-uat
#    - Access Level: Private
#    - Click "OK"

# 3. Verify project created
curl -u admin:your-password \
  https://harbor.aglz.io/api/v2.0/projects/agl-hostman-uat

# Expected: {"project_id": xxx, "name": "agl-hostman-uat", ...}
```

---

## Step 6: Configure GitHub Secrets (2 minutes)

```bash
# Go to GitHub repository
# Settings → Secrets and variables → Actions → New repository secret

# Add these secrets:
# 1. DOKPLOY_WEBHOOK_URL_UAT
#    Value: http://192.168.0.181:3000/api/deploy?token=xxx

# 2. UAT_DOKPLOY_TOKEN
#    Value: dp-xxxxxxxxxxxxx (from Step 1)

# Secrets should already exist from QA setup:
# - HARBOR_USERNAME
# - HARBOR_PASSWORD
# - APP_URL
# - API_TOKEN
```

---

## Step 7: Test Smoke Tests (2 minutes)

```bash
# Run smoke test suite locally
php artisan test --group=smoke

# Expected output (12 tests):
# ✓ health endpoint returns 200
# ✓ database connection works
# ✓ redis connection works
# ✓ auth endpoints respond
# ✓ environment list endpoint works
# ✓ dokploy service is configured
# ✓ harbor is configured
# ✓ deployment endpoints accessible
# ✓ promotion endpoints exist
# ✓ queue connection works
# ✓ cache works
# ✓ comprehensive smoke check

# Tests:    12 passed (12 assertions)
# Duration: < 2 minutes
```

---

## Step 8: Test Manual Promotion Workflow (5 minutes)

### 8.1 Create Test Promotion

```bash
# Create a test promotion request
curl -X POST http://localhost:8000/api/promotion/qa-to-uat \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_version": "qa-test-v1",
    "notes": "Test promotion workflow"
  }'

# Save the promotion_id from response
PROMOTION_ID="xxx-xxx-xxx"
```

### 8.2 Check Promotion Status

```bash
curl http://localhost:8000/api/promotion/${PROMOTION_ID}/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Expected: {"data": {"status": "pending", ...}}
```

### 8.3 Approve Promotion (Admin User)

```bash
curl -X POST http://localhost:8000/api/promotion/${PROMOTION_ID}/approve \
  -H "Authorization: Bearer ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approval_notes": "Test approval - automated testing",
    "auto_deploy": false
  }'

# Expected: {"success": true, "data": {"status": "approved", ...}}
```

### 8.4 Verify Promotion Approved

```bash
curl http://localhost:8000/api/promotion/${PROMOTION_ID}/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Expected: {"data": {"status": "approved", "approved_at": "...", ...}}
```

---

## Step 9: First UAT Deployment (GitHub Actions)

```bash
# 1. Commit and push to release branch
git checkout release
git pull origin release
git merge develop  # Merge latest changes
git push origin release

# 2. Go to GitHub Actions
# https://github.com/your-org/agl-hostman/actions

# 3. Select "Deploy to UAT" workflow

# 4. Click "Run workflow"
#    - Branch: release
#    - promotion_id: [paste from Step 8]
#    - source_version: qa-test-v1
#    - skip_approval: false

# 5. Monitor workflow execution (7-12 minutes):
#    ✓ Check approval status
#    ✓ Build Docker image
#    ✓ Push to Harbor
#    ✓ Deploy to CT181
#    ✓ Run smoke tests
#    ✓ Update promotion status
```

---

## Verification Checklist

After deployment completes:

### 1. Health Check

```bash
curl https://uat-agl.aglz.io/api/health

# Expected:
# {
#   "status": "healthy",
#   "services": {
#     "database": "ok",
#     "redis": "ok",
#     "dokploy": "ok"
#   }
# }
```

### 2. UAT Status

```bash
curl https://uat-agl.aglz.io/api/deployment/uat/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Expected:
# {
#   "success": true,
#   "environment": {
#     "type": "uat",
#     "status": "active",
#     "last_deployed_at": "..."
#   }
# }
```

### 3. Smoke Tests Passed

```bash
curl https://uat-agl.aglz.io/api/promotion/${PROMOTION_ID}/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Expected:
# {
#   "data": {
#     "status": "completed",
#     "smoke_test_results": {
#       "total": 12,
#       "passed": 12,
#       "failed": 0
#     }
#   }
# }
```

### 4. Promotion Complete

```bash
curl http://localhost:8000/api/promotion/history \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Should show completed promotion
```

---

## Common Issues & Quick Fixes

### Issue: Migration fails

```bash
# Check if table already exists
php artisan tinker
>>> \Illuminate\Support\Facades\Schema::hasTable('promotions')

# If true, skip migration (already run)
```

### Issue: Dokploy connection timeout

```bash
# Test CT181 connectivity
ping 192.168.0.181

# Test Dokploy API
curl http://192.168.0.181:3000/api/health

# Check token in .env
grep UAT_DOKPLOY_TOKEN .env
```

### Issue: Harbor push fails

```bash
# Login to Harbor manually
docker login harbor.aglz.io:5000

# Test push
docker tag test-image harbor.aglz.io:5000/agl-hostman-uat/test:latest
docker push harbor.aglz.io:5000/agl-hostman-uat/test:latest
```

### Issue: Smoke tests timeout

```bash
# Increase timeout
echo "SMOKE_TEST_TIMEOUT=180" >> .env

# Run with verbose output
php artisan test --group=smoke --stop-on-failure
```

### Issue: Approval fails - "Insufficient permissions"

```bash
# Check user role
php artisan tinker
>>> $user = User::find($userId);
>>> $user->role;

# Update approver roles in .env
echo "UAT_APPROVER_ROLES=admin,lead-developer,your-role" >> .env
```

---

## Rollback Procedure

If deployment fails or issues found:

```bash
# Option 1: Manual rollback via API
curl -X POST https://uat-agl.aglz.io/api/deployment/uat/rollback \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Option 2: Rollback specific promotion
curl -X POST https://uat-agl.aglz.io/api/promotion/${PROMOTION_ID}/rollback \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Option 3: Redeploy previous version via GitHub Actions
# Run workflow with previous source_version
```

---

## Next Steps After Successful Deployment

1. ✅ **Notify team** - UAT environment is live
2. ✅ **Schedule user acceptance testing** - Coordinate with stakeholders
3. ✅ **Monitor for 24 hours** - Check logs, performance
4. ✅ **Document any issues** - Track UAT-specific problems
5. ✅ **Plan Phase 3.3** - Production environment setup

---

## Quick Reference Commands

```bash
# Check UAT status
curl https://uat-agl.aglz.io/api/health

# List pending promotions
curl http://localhost:8000/api/promotion/pending \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Get promotion history
curl http://localhost:8000/api/promotion/history \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Run smoke tests
php artisan test --group=smoke

# View deployment logs
php artisan deployment:logs --env=uat --lines=100

# Check application logs
tail -f storage/logs/laravel.log
```

---

## Support & Documentation

**Full Documentation**:
- `docs/UAT-ENVIRONMENT-SETUP.md` - Comprehensive guide
- `docs/PHASE3.2-IMPLEMENTATION-SUMMARY.md` - Technical details
- `docs/PHASE3.2-DEPLOYMENT-READINESS.md` - Deployment checklist

**Troubleshooting**:
- Check `docs/UAT-ENVIRONMENT-SETUP.md` Section 10 (Troubleshooting)
- Review application logs: `storage/logs/laravel.log`
- Check Dokploy logs: CT181 Dokploy UI → Application → Logs

**Need Help?**
- Technical issues: Check troubleshooting section
- Approval issues: Verify user roles and permissions
- Deployment issues: Review GitHub Actions logs

---

## Success Criteria

**Deployment is successful when**:

- [x] All migrations completed
- [x] UAT environment seeded
- [x] Dokploy project created on CT181
- [x] Harbor project configured (agl-hostman-uat)
- [x] GitHub workflow executed successfully
- [x] All smoke tests passed (12/12)
- [x] Health endpoint returns 200
- [x] Promotion marked as completed
- [x] UAT accessible at https://uat-agl.aglz.io

**Time to Complete**: 15-20 minutes (excluding GitHub Actions deployment)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.2 - UAT Environment Deployment
