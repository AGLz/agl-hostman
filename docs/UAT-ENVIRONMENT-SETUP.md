# UAT Environment Setup Guide

> **Phase 3.2: UAT Environment Deployment (CT181)**
> **Target**: Manual promotion workflow with approval gates
> **Last Updated**: 2025-01-20

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Installation Steps](#installation-steps)
5. [Manual Promotion Workflow](#manual-promotion-workflow)
6. [Approval Process](#approval-process)
7. [Smoke Test Execution](#smoke-test-execution)
8. [Rollback Procedures](#rollback-procedures)
9. [API Reference](#api-reference)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### What is UAT?

User Acceptance Testing (UAT) environment on **CT181** serves as the final pre-production validation environment where:

- Stakeholders perform acceptance testing
- Release candidates are validated before production
- Manual promotions from QA are approved by designated personnel
- Smoke tests ensure critical functionality works

### Key Differences from QA

| Feature | QA (CT180) | UAT (CT181) |
|---------|------------|-------------|
| **Auto-Deploy** | Yes (on push to `develop`) | No (Manual only) |
| **Git Branch** | `develop` | `release` |
| **Approval Required** | No | Yes |
| **Test Type** | Full integration tests | Smoke tests |
| **Harbor Project** | agl-hostman-qa | agl-hostman-uat |
| **Promotion** | Automatic | Manual with approval |
| **Dokploy Instance** | CT180:3000 | CT181:3000 |

---

## Architecture

### Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    CT181 (AGLSRV1)                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Dokploy (Port 3000)                        │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  AGL-HOSTMAN UAT Project                       │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │  │   │
│  │  │  │   App    │  │PostgreSQL│  │  Redis   │    │  │   │
│  │  │  │  (2 CPU) │  │    16    │  │    7     │    │  │   │
│  │  │  │  (4GB)   │  │  (2GB)   │  │  (512MB) │    │  │   │
│  │  │  └──────────┘  └──────────┘  └──────────┘    │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ Manual Promotion
                           │ (Requires Approval)
                           │
┌─────────────────────────────────────────────────────────────┐
│                    CT180 (AGLSRV1)                          │
│                  QA Environment                              │
└─────────────────────────────────────────────────────────────┘
```

### Promotion Workflow

```
QA (develop) → [Promotion Request] → [Approval Gate] → UAT (release) → [Smoke Tests] → Production
```

---

## Prerequisites

### Required Infrastructure

- ✅ **CT181** running Dokploy
- ✅ **Harbor** registry at `harbor.aglz.io:5000`
- ✅ **Database**: PostgreSQL 16 or higher
- ✅ **Cache**: Redis 7 or higher
- ✅ **Network**: Access to CT181 on port 3000

### Required Accounts

- Admin user account (for approvals)
- Lead developer account (for approvals)
- Harbor registry credentials
- Dokploy API token for CT181

### Environment Variables

Copy and configure `.env`:

```bash
# UAT-specific configuration
UAT_DOKPLOY_URL=http://192.168.0.181:3000
UAT_DOKPLOY_TOKEN=your-dokploy-token
UAT_HARBOR_PROJECT=agl-hostman-uat
UAT_DOMAIN=uat-agl.aglz.io
UAT_DB_DATABASE=agl_hostman_uat
UAT_APPROVAL_REQUIRED=true
UAT_APPROVER_ROLES=admin,lead-developer
```

---

## Installation Steps

### Step 1: Run Database Migrations

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Run promotions table migration
php artisan migrate --path=database/migrations/2025_01_20_000005_create_promotions_table.php
```

### Step 2: Seed UAT Environment

```bash
# Create UAT environment record
php artisan db:seed --class=UATEnvironmentSeeder
```

Expected output:
```
✅ Created UAT Environment (ID: xxx)
   Name: UAT Environment
   Type: uat
   Branch: release
   Auto-deploy: No (Manual Only)
   Auto-test: Yes (Smoke Tests)
   Approval Required: Yes
   Domains: uat.agl-hostman.local, uat-agl.aglz.io
```

### Step 3: Setup Dokploy Project on CT181

```bash
# Create Dokploy project and application
php artisan deployment:setup-uat
```

This command will:
1. ✅ Verify Dokploy connectivity (CT181)
2. ✅ Create UAT environment record
3. ✅ Create Dokploy project
4. ✅ Create application
5. ✅ Configure domains
6. ✅ Set environment variables
7. ✅ Configure resource limits

### Step 4: Configure Harbor Project

1. Login to Harbor: `https://harbor.aglz.io`
2. Create project: `agl-hostman-uat`
3. Configure project as **private**
4. Add webhook (optional):
   - URL: `https://uat-agl.aglz.io/api/webhooks/harbor`
   - Events: `PUSH_ARTIFACT`

### Step 5: Configure Approval Roles

Update `.env` with approver roles:

```env
UAT_APPROVER_ROLES=admin,lead-developer,release-manager
```

Users with these roles can approve UAT promotions.

### Step 6: Test Smoke Tests

```bash
# Run smoke test suite
php artisan test --group=smoke

# Expected: ~12 tests passing in < 2 minutes
```

---

## Manual Promotion Workflow

### Workflow Steps

```
1. Developer creates promotion request from QA
   ↓
2. System creates pending promotion record
   ↓
3. Admin/Lead reviews and approves
   ↓
4. GitHub Actions triggers UAT deployment
   ↓
5. Smoke tests execute automatically
   ↓
6. On success: Promotion marked complete
   On failure: Automatic rollback triggered
```

### 1. Create Promotion Request

**API Endpoint**: `POST /api/promotion/qa-to-uat`

```bash
curl -X POST https://qa-agl.aglz.io/api/promotion/qa-to-uat \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_version": "qa-1a2b3c4",
    "notes": "Production release candidate - Sprint 15"
  }'
```

Response:
```json
{
  "success": true,
  "message": "Promotion request created successfully",
  "data": {
    "promotion_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "status": "pending",
    "source_environment": "qa",
    "target_environment": "uat",
    "source_version": "qa-1a2b3c4",
    "requested_at": "2025-01-20T10:30:00Z"
  }
}
```

### 2. Check Promotion Status

**API Endpoint**: `GET /api/promotion/{promotionId}/status`

```bash
curl https://qa-agl.aglz.io/api/promotion/9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### 3. List Pending Promotions

**API Endpoint**: `GET /api/promotion/pending`

```bash
curl https://qa-agl.aglz.io/api/promotion/pending \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

---

## Approval Process

### Who Can Approve?

Users with the following roles (configured in `.env`):
- `admin`
- `lead-developer`
- `release-manager` (if configured)

### Approve Promotion

**API Endpoint**: `POST /api/promotion/{promotionId}/approve`

```bash
curl -X POST https://qa-agl.aglz.io/api/promotion/9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d/approve \
  -H "Authorization: Bearer ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approval_notes": "Release approved for UAT deployment. All tests passed in QA.",
    "auto_deploy": true
  }'
```

Response:
```json
{
  "success": true,
  "message": "Promotion approved and deployment started",
  "data": {
    "promotion_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "deployment_id": "5f3deb4d-1a2b-3c4d-5e6f-7g8h9i0j1k2l",
    "status": "approved"
  }
}
```

### Approve Without Auto-Deploy

```bash
curl -X POST https://qa-agl.aglz.io/api/promotion/9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d/approve \
  -H "Authorization: Bearer ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approval_notes": "Approved. Will deploy manually later.",
    "auto_deploy": false
  }'
```

### Manual Deployment After Approval

**API Endpoint**: `POST /api/deployment/uat/deploy`

```bash
curl -X POST https://qa-agl.aglz.io/api/deployment/uat/deploy \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "promotion_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "source_version": "qa-1a2b3c4"
  }'
```

---

## Smoke Test Execution

### What Are Smoke Tests?

Lightweight critical path tests that:
- Complete in **< 2 minutes**
- Test only **essential functionality**
- Run automatically after UAT deployment
- Trigger rollback on failure

### Test Coverage

✅ **Health endpoint** (`/api/health`)
✅ **Database connectivity** (PostgreSQL)
✅ **Cache connectivity** (Redis)
✅ **Authentication endpoints**
✅ **Critical API endpoints** (5-10 key routes)
✅ **Configuration validation** (Dokploy, Harbor)

### Run Smoke Tests Manually

```bash
# Run all smoke tests
php artisan test --group=smoke

# Run with parallel execution
php artisan test --group=smoke --parallel

# Stop on first failure
php artisan test --group=smoke --stop-on-failure
```

### Smoke Test Results

After deployment, smoke test results are stored in the promotion record:

```json
{
  "smoke_test_results": {
    "total": 12,
    "passed": 12,
    "failed": 0,
    "duration": 87.5,
    "success_rate": 100.0,
    "tests": [
      {"name": "health_check", "status": "passed"},
      {"name": "database_connection", "status": "passed"},
      {"name": "redis_connection", "status": "passed"}
    ]
  }
}
```

---

## Rollback Procedures

### Automatic Rollback

Automatic rollback triggers when:
- Smoke tests fail
- Deployment fails
- Health checks fail

Configuration:
```env
UAT_ROLLBACK_ON_FAILURE=true
```

### Manual Rollback

**API Endpoint**: `POST /api/deployment/uat/rollback`

```bash
curl -X POST https://uat-agl.aglz.io/api/deployment/uat/rollback \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

Response:
```json
{
  "success": true,
  "rolled_back_to_deployment": "previous-deployment-id",
  "rolled_back_to_commit": "abc123def"
}
```

### Rollback via Promotion

**API Endpoint**: `POST /api/promotion/{promotionId}/rollback`

```bash
curl -X POST https://uat-agl.aglz.io/api/promotion/9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d/rollback \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

---

## API Reference

### Promotion Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/promotion/qa-to-uat` | Create promotion request | Required |
| POST | `/api/promotion/{id}/approve` | Approve promotion | Admin |
| GET | `/api/promotion/{id}/status` | Get promotion status | Required |
| POST | `/api/promotion/{id}/rollback` | Rollback promotion | Admin |
| GET | `/api/promotion/pending` | List pending promotions | Required |
| GET | `/api/promotion/history` | Promotion history | Required |

### Deployment Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/deployment/uat/deploy` | Deploy to UAT | Required |
| POST | `/api/deployment/uat/rollback` | Rollback UAT | Admin |
| GET | `/api/deployment/uat/status` | UAT deployment status | Required |
| GET | `/api/deployment/uat/logs` | UAT deployment logs | Required |

---

## Troubleshooting

### Common Issues

#### 1. Approval Fails - "Insufficient permissions"

**Problem**: User doesn't have approval rights

**Solution**:
```bash
# Check user role
php artisan tinker
>>> User::find($userId)->role

# Update .env with correct roles
UAT_APPROVER_ROLES=admin,lead-developer
```

#### 2. Smoke Tests Timeout

**Problem**: Tests taking too long

**Solution**:
```bash
# Increase timeout
SMOKE_TEST_TIMEOUT=180  # 3 minutes

# Check test performance
php artisan test --group=smoke --profile
```

#### 3. Dokploy Connection Failed

**Problem**: Cannot connect to CT181

**Solution**:
```bash
# Test connection
curl http://192.168.0.181:3000/api/health

# Verify token
UAT_DOKPLOY_TOKEN=check-your-token

# Check firewall
sudo ufw status
```

#### 4. Harbor Push Failed

**Problem**: Cannot push to UAT project

**Solution**:
```bash
# Login to Harbor
docker login harbor.aglz.io:5000

# Verify project exists
curl -u admin:password https://harbor.aglz.io/api/v2.0/projects

# Check credentials
HARBOR_USERNAME=your-username
HARBOR_PASSWORD=your-password
```

#### 5. Promotion Stuck in Pending

**Problem**: Promotion not approved

**Solution**:
```bash
# Check promotion status
curl /api/promotion/{id}/status

# Approve manually
curl -X POST /api/promotion/{id}/approve \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{"approval_notes": "Approved", "auto_deploy": true}'
```

### Debug Commands

```bash
# Check UAT environment status
php artisan tinker
>>> Environment::where('type', 'uat')->first()

# List all promotions
>>> Promotion::with(['sourceEnvironment', 'targetEnvironment'])->get()

# Check latest deployment
>>> DokployDeployment::where('environment_id', $uatEnvId)->latest()->first()

# View promotion history
>>> Promotion::where('status', 'completed')->latest()->take(5)->get()
```

### Logs

```bash
# Application logs
tail -f storage/logs/laravel.log

# Deployment logs
php artisan deployment:logs --env=uat --lines=100

# Smoke test logs
tail -f storage/logs/testing.log
```

---

## Next Steps

After UAT environment is working:

1. ✅ **Phase 3.3**: Production environment setup
2. ✅ **Phase 3.4**: Multi-environment orchestration
3. ✅ **Phase 4**: Monitoring and alerts

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-20
**Phase**: 3.2 - UAT Environment Deployment
