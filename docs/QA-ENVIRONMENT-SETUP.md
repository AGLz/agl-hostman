# QA Environment Setup Guide

> **Last Updated**: 2025-11-20 | **Version**: 1.0.0
> **Status**: Production Ready

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Prerequisites](#-prerequisites)
3. [Quick Start](#-quick-start)
4. [Detailed Setup](#-detailed-setup)
5. [GitHub Integration](#-github-integration)
6. [Harbor Configuration](#-harbor-configuration)
7. [Testing](#-testing)
8. [Monitoring](#-monitoring)
9. [Troubleshooting](#-troubleshooting)
10. [Rollback Procedures](#-rollback-procedures)

---

## 🌐 Overview

The QA (Quality Assurance) environment provides automated deployment from the `develop` branch with integrated testing, monitoring, and rollback capabilities.

### Key Features

- ✅ **Automated Deployment**: Triggers on push to `develop` branch
- ✅ **Docker Integration**: Builds and pushes to Harbor registry
- ✅ **Dokploy Orchestration**: Manages deployment lifecycle
- ✅ **Integrated Testing**: Runs integration tests automatically
- ✅ **Auto Rollback**: Reverts on test failure
- ✅ **Slack Notifications**: Real-time deployment status
- ✅ **Health Monitoring**: Continuous health checks

### Architecture

```
GitHub (develop) → GitHub Actions → Harbor (QA project) → Dokploy → CT180
                      ↓                                                ↓
                 Run Tests                                   Health Checks
                      ↓                                                ↓
              Slack Notification                           Deployment Success
```

---

## 🔧 Prerequisites

### Required Services

| Service | Version | Purpose | Access |
|---------|---------|---------|--------|
| **Dokploy** | Latest | Deployment platform | https://dok.aglz.io |
| **Harbor** | 2.x | Container registry | https://harbor.aglz.io |
| **GitHub** | N/A | Code repository | github.com/your-org/agl-hostman |
| **PostgreSQL** | 16 | Database | Via Docker Compose |
| **Redis** | 7 | Cache/Queue | Via Docker Compose |

### Required Credentials

```env
# .env file
DOKPLOY_API_URL=http://192.168.0.180:3000
DOKPLOY_API_TOKEN=your_dokploy_token
DOKPLOY_WEBHOOK_TOKEN=your_webhook_token

HARBOR_REGISTRY=harbor.aglz.io:5000
HARBOR_USERNAME=admin
HARBOR_PASSWORD=your_harbor_password

GITHUB_WEBHOOK_SECRET=your_github_secret

DB_PASSWORD=your_database_password
REDIS_PASSWORD=your_redis_password
```

### GitHub Secrets

Configure in GitHub repository settings → Secrets and variables → Actions:

```
HARBOR_USERNAME=admin
HARBOR_PASSWORD=SecurePass2025!
DOKPLOY_WEBHOOK_TOKEN=your_webhook_token
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

---

## 🚀 Quick Start

### Step 1: Run Database Migration

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src

# Run migration
php artisan migrate

# Seed QA environment
php artisan db:seed --class=QAEnvironmentSeeder
```

**Expected Output:**
```
✅ Created QA Environment (ID: 1)
   Name: QA Environment
   Type: qa
   Branch: develop
   Auto-deploy: Yes
   Auto-test: Yes
   Domains: qa.agl-hostman.local, qa-agl.aglz.io
```

### Step 2: Setup QA Environment in Dokploy

```bash
# Automated setup
php artisan deployment:setup-qa

# Manual setup (if Dokploy unavailable)
php artisan deployment:setup-qa --skip-dokploy
```

**What This Does:**
1. ✅ Creates environment record in database
2. ✅ Creates Dokploy project "AGL-HOSTMAN QA"
3. ✅ Creates application "agl-hostman-qa"
4. ✅ Configures domains (qa-agl.aglz.io)
5. ✅ Sets environment variables
6. ✅ Configures resource limits (2 CPU, 4GB RAM)

### Step 3: Configure Harbor Project

```bash
# Login to Harbor
docker login harbor.aglz.io:5000
# Username: admin
# Password: SecurePass2025!

# Create project (via Harbor UI)
# Project Name: agl-hostman-qa
# Access Level: Private
# Storage Quota: 10GB
```

### Step 4: Setup GitHub Webhook

1. Go to GitHub repository → Settings → Webhooks → Add webhook
2. Configure:
   ```
   Payload URL: https://your-app-url/api/webhooks/github
   Content type: application/json
   Secret: (value from GITHUB_WEBHOOK_SECRET)
   Events: Just the push event
   Active: ✓
   ```

### Step 5: Test Deployment

```bash
# Push to develop branch
git checkout develop
git add .
git commit -m "test: trigger QA deployment"
git push origin develop

# Monitor GitHub Actions
# Check: https://github.com/your-org/agl-hostman/actions

# Monitor Dokploy
# Check: https://dok.aglz.io

# Check deployment status
curl https://qa-agl.aglz.io/api/health
```

---

## 📚 Detailed Setup

### Database Schema

The `environments` table structure:

```sql
CREATE TABLE environments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    type ENUM('dev', 'qa', 'uat', 'production') NOT NULL UNIQUE,
    dokploy_project_id VARCHAR(255) NULL,
    harbor_project VARCHAR(255) NOT NULL,
    git_branch VARCHAR(255) NOT NULL,
    auto_deploy BOOLEAN DEFAULT FALSE,
    auto_test BOOLEAN DEFAULT TRUE,
    status ENUM('active', 'inactive', 'maintenance') DEFAULT 'active',
    domains JSON NOT NULL,
    env_vars JSON NOT NULL,
    resources JSON NOT NULL,
    last_deployed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Environment Configuration

Default QA configuration (from `EnvironmentConfigService`):

```php
[
    'harbor_project' => 'agl-hostman-qa',
    'git_branch' => 'develop',
    'auto_deploy' => true,
    'auto_test' => true,
    'domains' => ['qa.agl-hostman.local', 'qa-agl.aglz.io'],
    'env_vars' => [
        'APP_ENV' => 'qa',
        'APP_DEBUG' => 'true',
        'DB_DATABASE' => 'agl_hostman_qa',
        'CACHE_DRIVER' => 'redis',
        'QUEUE_CONNECTION' => 'redis',
        'LOG_LEVEL' => 'info',
    ],
    'resources' => [
        'cpu_limit' => '2',
        'cpu_reservation' => '1',
        'memory_limit' => '4096M',
        'memory_reservation' => '2048M',
    ],
]
```

### Deployment Workflow

Detailed steps executed by `DeploymentWorkflowService`:

```
1. Pull latest code from 'develop' branch
   ↓
2. Build Docker image (harbor.aglz.io:5000/agl-hostman-qa:qa-{commit})
   ↓
3. Push to Harbor /qa project
   ↓
4. Trigger Dokploy deployment (via API)
   ↓
5. Wait for deployment (max 5 minutes, poll every 5 seconds)
   ↓
6. Run health checks (6 attempts, 10s interval)
   ↓
7. Run integration tests (if auto_test enabled)
   ↓
8. Update deployment status (success/failed)
   ↓
9. Send Slack notification
```

---

## 🔗 GitHub Integration

### GitHub Actions Workflow

File: `.github/workflows/deploy-qa.yml`

#### Trigger Events

- **Automatic**: Push to `develop` branch
- **Manual**: workflow_dispatch (with force_deploy option)

#### Workflow Jobs

**1. build-and-deploy**
- Checkout code
- Login to Harbor
- Build Docker image
- Push to Harbor registry
- Trigger Dokploy deployment
- Wait for deployment (120s + health checks)
- Run integration tests
- Send Slack notification

**2. rollback** (on failure)
- Triggers Dokploy rollback API
- Reverts to previous successful deployment

#### Environment Variables

```yaml
env:
  HARBOR_REGISTRY: harbor.aglz.io:5000
  HARBOR_PROJECT: agl-hostman-qa
  IMAGE_NAME: agl-hostman
  DOKPLOY_URL: https://dok.aglz.io
```

### Webhook Payload Example

GitHub sends this payload on push:

```json
{
  "ref": "refs/heads/develop",
  "repository": {
    "full_name": "your-org/agl-hostman",
    "clone_url": "https://github.com/your-org/agl-hostman.git"
  },
  "head_commit": {
    "id": "abc123def456...",
    "message": "feat: add new feature",
    "author": {
      "name": "John Doe",
      "email": "john@example.com"
    }
  }
}
```

### Webhook Validation

Signature validation using HMAC-SHA256:

```php
$signature = $request->header('X-Hub-Signature-256');
$payload = $request->getContent();
$secret = config('services.github.webhook_secret');

$expectedSignature = 'sha256=' . hash_hmac('sha256', $payload, $secret);

if (!hash_equals($expectedSignature, $signature)) {
    return response()->json(['error' => 'Invalid signature'], 403);
}
```

---

## 🐳 Harbor Configuration

### Project Setup

1. **Login to Harbor**: https://harbor.aglz.io
2. **Create Project**:
   - Name: `agl-hostman-qa`
   - Access Level: Private
   - Storage Quota: 10GB
   - Project Members: Add CI/CD service account

### Tag Retention Policy

Configure in Harbor UI → Projects → agl-hostman-qa → Policy:

```yaml
Retention Rules:
  - Always retain: 10 (latest 10 tags)
  - Retain tags matching: qa-*
  - Retain tags matching: qa-latest
  - Dry run: No
  - Schedule: Daily at 00:00 UTC
```

### Vulnerability Scanning

Enable automatic scanning:

```yaml
Scan Settings:
  - Scan on Push: Enabled
  - Prevent vulnerable images: Warning only
  - Severity: High, Critical
```

### Harbor Webhook (Optional)

Configure webhook to Dokploy:

```
Endpoint URL: https://dok.aglz.io/api/webhooks/harbor
Events:
  - Artifact pushed ✓
  - Artifact deleted
  - Scanning completed
```

---

## 🧪 Testing

### Manual Testing

```bash
# Run all tests
php artisan test

# Run integration tests only
php artisan test --group=integration

# Run QA environment tests
php artisan test tests/Feature/Integration/QAEnvironmentTest.php
```

### Integration Test Suite

Located in: `tests/Feature/Integration/QAEnvironmentTest.php`

**Tests Include:**
- ✅ QA environment configured
- ✅ Correct environment variables
- ✅ Resource limits set
- ✅ Domains configured
- ✅ Dokploy API connection
- ✅ Health endpoint reachable
- ✅ Database connection
- ✅ Redis connection
- ✅ Deployment workflow validation

### Health Check Endpoint

```bash
# Check application health
curl https://qa-agl.aglz.io/api/health

# Expected response
{
  "status": "ok",
  "timestamp": "2025-11-20T12:00:00Z",
  "environment": "qa",
  "version": "qa-abc1234"
}
```

---

## 📊 Monitoring

### Deployment Status API

```bash
# Get QA environment status
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://your-app-url/api/deployment/qa/status

# Response
{
  "success": true,
  "environment": {
    "id": 1,
    "name": "QA Environment",
    "type": "qa",
    "status": "active",
    "last_deployed_at": "2025-11-20T10:30:00Z",
    "deployment_status": "running",
    "domains": ["qa.agl-hostman.local", "qa-agl.aglz.io"]
  }
}
```

### Deployment Logs

```bash
# Get deployment logs
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://your-app-url/api/deployment/qa/logs

# Stream logs (real-time)
# Via Dokploy UI: https://dok.aglz.io
```

### Dokploy Monitoring

Access Dokploy dashboard: https://dok.aglz.io

**Metrics Available:**
- Container status (running/stopped)
- CPU usage
- Memory usage
- Network I/O
- Deployment history
- Real-time logs

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Deployment Timeout

**Symptoms**: Deployment hangs for 5+ minutes

**Causes**:
- Dokploy service down
- Network connectivity issues
- Resource limits too low

**Solutions**:
```bash
# Check Dokploy status
curl http://192.168.0.180:3000/api/health

# Check container status
ssh root@192.168.0.180 'docker ps | grep agl-hostman-qa'

# Increase timeout
# Edit .env: DEPLOYMENT_TIMEOUT=600
```

#### Issue 2: GitHub Webhook Not Triggering

**Symptoms**: Push to develop doesn't trigger deployment

**Causes**:
- Webhook secret mismatch
- Webhook disabled
- Network/firewall blocking GitHub

**Solutions**:
```bash
# Test webhook manually
curl -X POST https://your-app-url/api/webhooks/github \
     -H "X-GitHub-Event: push" \
     -H "X-Hub-Signature-256: sha256=..." \
     -d @github-payload.json

# Check webhook logs
tail -f storage/logs/laravel.log | grep webhook

# Verify secret
# Check .env: GITHUB_WEBHOOK_SECRET matches GitHub settings
```

#### Issue 3: Harbor Push Fails

**Symptoms**: `docker push` fails with 401/403

**Causes**:
- Not logged in to Harbor
- Invalid credentials
- Project doesn't exist

**Solutions**:
```bash
# Login to Harbor
docker login harbor.aglz.io:5000
# Username: admin
# Password: SecurePass2025!

# Verify project exists
curl -u admin:SecurePass2025! \
     https://harbor.aglz.io/api/v2.0/projects/agl-hostman-qa

# Check image tag format
# Should be: harbor.aglz.io:5000/agl-hostman-qa/agl-hostman:qa-abc1234
```

#### Issue 4: Integration Tests Fail

**Symptoms**: Deployment succeeds but tests fail

**Causes**:
- Environment not fully initialized
- Database migration not run
- Redis not running

**Solutions**:
```bash
# Check application logs
curl https://qa-agl.aglz.io/api/health

# Run migrations manually
docker exec agl-hostman-qa php artisan migrate --force

# Check database connection
docker exec agl-hostman-qa php artisan db:show

# Check Redis
docker exec agl-hostman-qa-redis redis-cli ping
```

#### Issue 5: Resource Limit Errors

**Symptoms**: Container OOM (Out of Memory) or CPU throttling

**Causes**:
- Memory limit too low
- Application memory leak
- Too many concurrent processes

**Solutions**:
```bash
# Check resource usage
docker stats agl-hostman-qa

# Increase limits (via Dokploy UI or API)
# Edit Environment model:
# resources.memory_limit = '8192M'
# resources.cpu_limit = '4'

# Restart application
curl -X POST https://dok.aglz.io/api/application/restart \
     -H "Authorization: Bearer TOKEN"
```

### Diagnostic Commands

```bash
# Check environment status
php artisan deployment:qa:status

# Check Dokploy connectivity
php artisan dokploy:test-connection

# View deployment history
php artisan deployment:history --environment=qa

# Clear deployment cache
php artisan cache:clear --tags=deployments
```

### Log Locations

```
Application Logs:  storage/logs/laravel.log
Deployment Logs:   storage/logs/deployments.log
Dokploy Logs:      Via Dokploy UI
GitHub Actions:    GitHub repository → Actions tab
Docker Logs:       docker logs agl-hostman-qa
```

---

## 🔄 Rollback Procedures

### Automatic Rollback

Configured in `.env`:
```env
DEPLOYMENT_ROLLBACK_ON_FAILURE=true
```

Automatic rollback triggers when:
- Integration tests fail
- Health check fails after deployment
- Deployment timeout exceeded

### Manual Rollback via API

```bash
# Trigger rollback
curl -X POST https://your-app-url/api/deployment/qa/rollback \
     -H "Authorization: Bearer YOUR_TOKEN"

# Response
{
  "success": true,
  "message": "Rollback initiated"
}
```

### Manual Rollback via Dokploy UI

1. Login to Dokploy: https://dok.aglz.io
2. Navigate to: Projects → AGL-HOSTMAN QA → Applications → agl-hostman-qa
3. Go to: Deployments tab
4. Find last successful deployment
5. Click: "Rollback" button

### Manual Rollback via Docker

```bash
# SSH to Dokploy server
ssh root@192.168.0.180

# Pull previous image
docker pull harbor.aglz.io:5000/agl-hostman-qa/agl-hostman:qa-previous

# Stop current container
docker stop agl-hostman-qa

# Start with previous image
docker run -d \
  --name agl-hostman-qa \
  --env-file /opt/dokploy/envs/qa.env \
  -p 8081:80 \
  harbor.aglz.io:5000/agl-hostman-qa/agl-hostman:qa-previous
```

### Rollback Verification

```bash
# Check application version
curl https://qa-agl.aglz.io/api/version

# Run health check
curl https://qa-agl.aglz.io/api/health

# Run smoke tests
php artisan test --group=smoke
```

---

## 📚 Additional Resources

### Documentation

- **Dokploy Docs**: [docs/DOKPLOY.md](DOKPLOY.md)
- **Infrastructure**: [docs/INFRA.md](INFRA.md)
- **Testing Architecture**: [docs/TESTING-ARCHITECTURE.md](TESTING-ARCHITECTURE.md)

### API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/deployment/qa/deploy` | POST | ✓ | Trigger QA deployment |
| `/api/deployment/qa/rollback` | POST | ✓ | Rollback QA deployment |
| `/api/deployment/qa/status` | GET | ✓ | Get QA environment status |
| `/api/deployment/qa/logs` | GET | ✓ | Get deployment logs |
| `/api/webhooks/github` | POST | - | GitHub webhook handler |
| `/api/webhooks/harbor` | POST | - | Harbor webhook handler |

### Environment Variables Reference

Complete list in `.env.example`:

```env
# QA Environment
QA_ENABLED=true
QA_DOKPLOY_PROJECT_ID=
QA_HARBOR_PROJECT=agl-hostman-qa
QA_DOMAIN=qa-agl.aglz.io

# Dokploy
DOKPLOY_API_URL=http://192.168.0.180:3000
DOKPLOY_API_TOKEN=
DOKPLOY_WEBHOOK_TOKEN=

# Harbor Registry
HARBOR_REGISTRY=harbor.aglz.io:5000
HARBOR_USERNAME=admin
HARBOR_PASSWORD=

# GitHub Webhook
GITHUB_WEBHOOK_SECRET=
GITHUB_WEBHOOK_ENABLED=true

# Deployment
DEPLOYMENT_TIMEOUT=300
DEPLOYMENT_ROLLBACK_ON_FAILURE=true
DEPLOYMENT_RUN_TESTS=true
```

---

## 🎯 Next Steps

### Phase 3.2: UAT Environment

- Copy QA setup for UAT environment
- Branch: `release`
- Manual approval required
- Production-like configuration

### Phase 3.3: Production Environment

- Copy UAT setup for Production
- Branch: `main`
- Blue-green deployment
- Zero-downtime updates
- Comprehensive monitoring

### Phase 3.4: Multi-Region Deployment

- Deploy to multiple Dokploy instances
- Geographic load balancing
- Disaster recovery procedures

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Maintainer**: AGL Infrastructure Team
**Status**: ✅ Production Ready
