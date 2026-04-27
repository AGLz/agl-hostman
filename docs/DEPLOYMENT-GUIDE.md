# AGL-HOSTMAN Deployment Guide

> **Comprehensive Deployment Procedures** - This guide covers deployment workflows, environment management, rollback procedures, and troubleshooting for the AGL-HOSTMAN infrastructure management platform.

## Table of Contents

1. [Overview](#overview)
2. [Environment Architecture](#environment-architecture)
3. [Deployment Workflows](#deployment-workflows)
4. [GitHub Actions CI/CD](#github-actions-cicd)
5. [Dokploy Integration](#dokploy-integration)
6. [Health Checks & Validation](#health-checks--validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Monitoring & Observability](#monitoring--observability)
9. [Troubleshooting](#troubleshooting)
10. [Security Considerations](#security-considerations)

---

## Overview

### Deployment Philosophy

AGL-HOSTMAN follows these deployment principles:

- ✅ **Automated Testing**: All deployments must pass 219+ tests (87%+ coverage)
- ✅ **Progressive Delivery**: Gradual rollout through environments
- ✅ **Health Validation**: Automated health checks before production acceptance
- ✅ **Zero Downtime**: Blue-green deployments with automatic rollback
- ✅ **DORA Metrics**: Elite tier DevOps performance tracking
- ✅ **Observability**: Comprehensive monitoring and alerting

### Environment Strategy

| Environment | Auto-Deploy | Branch | Health Checks | Approval | Purpose |
|-------------|-------------|--------|---------------|----------|---------|
| **Development** | ✅ Yes | `develop` | Basic | Not required | Active development, feature integration |
| **QA** | ✅ Yes | `qa` | Basic | Not required | Functional testing, integration testing |
| **UAT** | ❌ No | `uat` | Medium | Required | User acceptance testing, performance testing |
| **Production** | ❌ No | `main` | High + External | Required + Review | Production traffic, customer-facing |

### Technology Stack

**CI/CD Platform**: GitHub Actions with matrix builds
**Deployment Target**: Dokploy + Harbor Registry
**Container Runtime**: Docker 26+
**Database**: PostgreSQL 17 (migrations with rollback support)
**Queue**: Redis 7 (job processing)
**Monitoring**: Prometheus + Grafana + AlertManager
**Load Balancer**: Traefik with Let's Encrypt SSL

---

## Environment Architecture

### Development Environment

**Endpoints:**
- **Web App**: https://dev.aglz.io
- **API**: https://api.dev.aglz.io
- **Monitoring**: https://grafana.dev.aglz.io

**Configuration:**
```yaml
Environment: development
Debug: enabled
Caching: file/database
Mail Driver: log
Queue Driver: sync
Database: agl_hostman_dev
```

**Deployment Trigger:**
```yaml
on:
  push:
    branches: [develop]
```

**Health Checks:**
- ✅ Application responds (HTTP 200)
- ✅ Database connection
- ✅ Redis connection
- ✅ Basic authentication

### QA Environment

**Endpoints:**
- **Web App**: https://qa.aglz.io
- **API**: https://api.qa.aglz.io
- **Health Dashboard**: https://health.qa.aglz.io

**Configuration:**
```yaml
Environment: qa
Debug: disabled
Caching: redis
Mail Driver: smtp
Queue Driver: redis
Database: agl_hostman_qa
```

**Deployment Trigger:**
```yaml
on:
  push:
    branches: [qa]
  pull_request:
    branches: [qa]
```

**Health Checks:**
- All dev checks +
- ✅ WebSocket server
- ✅ Queue worker processes
- ✅ All migrations applied
- ✅ Cache clearing works

### UAT Environment

**Endpoints:**
- **Web App**: https://uat.aglz.io
- **API**: https://api.uat.aglz.io
- **Load Testing**: https://k6.uat.aglz.io

**Configuration:**
```yaml
Environment: uat
Debug: disabled
Caching: redis cluster
Mail Driver: smtp
Queue Driver: redis
Database: agl_hostman_uat
Replicas: 3 pods
```

**Deployment Trigger:**
```yaml
on:
  push:
    branches: [uat]
  workflow_dispatch: # Manual approval
```

**Health Checks:**
- All qa checks +
- ✅ Load balancing
- ✅ Horizontal pod autoscaling
- ✅ Disaster recovery procedures
- ✅ Performance benchmarks (P95 latency < 500ms)

### Production Environment

**Endpoints:**
- **Web App**: https://app.aglz.io
- **API**: https://api.aglz.io
- **Status Page**: https://status.aglz.io

**Configuration:**
```yaml
Environment: production
Debug: disabled
Caching: redis sentinel
Mail Driver: smtp + failover
Queue Driver: redis sentinel
Database: agl_hostman_prod (High Availability)
Replicas: 5 minimum (auto-scale up to 50)
Resources:
  CPU: 2000m per pod
  Memory: 2Gi per pod
  Storage: 50Gi per pod
```

**Deployment Trigger:**
```yaml
on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch: # Approval required
```

**Health Checks:**
- All uat checks +
- ✅ External monitoring (Pingdom, Datadog)
- ✅ Synthetic user monitoring
- ✅ Real user monitoring (RUM)
- ✅ Load testing pre-deployment
- ✅ Security scan (Snyk, Trivy)
- ✅ Database replication lag < 1s

---

## Deployment Workflows

### Development Workflow

**Automated on push to `develop` branch:**

```bash
# 1. Developer commits and pushes
git checkout develop
git add .
git commit -m "feat: add new deployment feature"
git push origin develop

# 2. GitHub Actions triggers automatically:
# - Run all tests (219 tests)
# - Build Docker image
# - Push to Harbor Registry
# - Deploy to dev.aglz.io
# - Run health checks
# - Send notification on success/failure

# 3. Monitor deployment
# Check GitHub Actions logs
# View health dashboard: https://health.dev.aglz.io
# Monitor Slack #deployments channel
```

**Manual Health Check:**
```bash
# SSH to development container
ssh dev@dev.aglz.io

# Check application status
./scripts/health-check.sh

# View recent logs
tail -f /var/log/agl-hostman/app.log
```

### QA Workflow

**Automated on push to `qa` branch:**

```bash
# 1. Merge develop to qa
git checkout qa
git merge develop --no-ff
git push origin qa

# 2. GitHub Actions triggers:
# - Re-run all tests
# - Performance benchmarks
# - Security scan
# - Build optimized image
# - Deploy to qa.aglz.io
# - Extended health checks
# - DORA metrics collection

# 3. QA Team receives notification
# Test new features
# File bugs in GitHub Issues
```

**Validation Checklist:**
```bash
# Run integration tests
php artisan test --testsuite=Feature

# Check database migrations
php artisan migrate:status

# Verify cache clearing
php artisan cache:clear
php artisan config:clear
php artisan view:clear

# Test job queue
php artisan queue:work --tries=1
```

### UAT Workflow

**Manual deployment with approval required:**

```bash
# 1. Prepare UAT release
git checkout uat
git merge qa --no-ff
git tag -a v1.2.3-uat -m "UAT release for v1.2.3"
git push origin uat --tags

# 2. Navigate to GitHub Actions
# - Go to Actions tab
# - Select "Deploy to UAT" workflow
# - Click "Run workflow"
# - Select branch: uat
# - Wait for approval

# 3. Approval workflow
# - Team lead reviews changes
# - Security team reviews
# - Performance tests auto-run
# - If all checks pass → Approve
# - Deployment proceeds to uat.aglz.io

# 4. UAT Testing
# - End-to-end user tests
# - Performance benchmarks
# - Load testing (k6)
# - Security penetration testing
# - Accessibility compliance
```

**Performance Benchmarks:**
```bash
# Run load test
./scripts/load-test.sh --env=uat --duration=5m --users=100

# Check metrics
./scripts/check-metrics.sh --env=uat

# Scale test
./scripts/scale-test.sh --env=uat --replicas=10
```

### Production Workflow

**Manual deployment with multi-stage approval:**

```bash
# 1. Prepare production release
git checkout main
git merge uat --no-ff
git tag -a v1.2.3 -m "Production release v1.2.3"
git push origin main --tags

# 2. Create release on GitHub
# - Draft new release
# - Tag: v1.2.3
# - Title: Release v1.2.3
# - Description: Changelog
# - Attach binaries
# - Mark as pre-release if needed

# 3. Deploy to production
# - Navigate to GitHub Actions
# - Select "Deploy to Production" workflow
# - Click "Run workflow"
# - Select tag: v1.2.3
# - Stage 1 approval: Engineering Manager
# - Stage 2 approval: Security Team
# - Stage 3 approval: Product Manager

# 4. Automated deployment steps:
# - Pre-deployment health check
# - Security scan (Trivy, Snyk)
# - Backup databases
# - Blue-green deployment
# - Post-deployment health check
# - External monitoring validation
# - DORA metrics update
# - Notifications sent
```

**Production Validation:**
```bash
# Wait for deployment completion
# Check status page: https://status.aglz.io

# Validate deployment
./scripts/validate-deployment.sh --env=prod --version=v1.2.3

# Monitor for 30 minutes
# Check error rates, response times, user feedback

# If issues detected:
# - Trigger automatic rollback
# - Or manual rollback: ./scripts/rollback.sh --to=v1.2.2
```

---

## GitHub Actions CI/CD

### Workflow Overview

**Primary Workflow: `.github/workflows/deploy.yml`**

```yaml
name: Deploy AGL-HOSTMAN

on:
  push:
    branches: [main, uat, qa, develop]
    tags: ['v*.*.*']
  pull_request:
    branches: [main, uat, qa]

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    strategy:
      matrix:
        php: [8.4]
        postgres: [17]
        node: [20]
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql, redis, pcov
          coverage: pcov

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}

      - name: Install Dependencies
        run: |
          composer install --prefer-dist --no-progress --no-interaction
          npm ci

      - name: Prepare Environment
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Setup PostgreSQL
        uses: Harmon758/postgresql-action@v1.0.0
        with:
          postgresql version: ${{ matrix.postgres }}
          postgresql db: agl_hostman_test
          postgresql user: test_user
          postgresql password: test_password

      - name: Run Database Migrations
        run: php artisan migrate

      - name: Execute Tests
        run: vendor/bin/phpunit --coverage-text --log-junit junit.xml

      - name: Code Coverage Report
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.xml
          flags: unittests

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref != 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Harbor Registry
        uses: docker/login-action@v3
        with:
          registry: harbor.aglz.io:5000
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: harbor.aglz.io:5000/agl/agl-hostman
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./src
          file: ./src/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=harbor.aglz.io:5000/agl/agl-hostman:buildcache
          cache-to: type=registry,ref=harbor.aglz.io:5000/agl/agl-hostman:buildcache,mode=max

  deploy-development:
    name: Deploy to Development
    runs-on: ubuntu-latest
    needs: [test, build]
    if: github.ref == 'refs/heads/develop'
    environment: development
    steps:
      - name: Deploy to Dokploy (Dev)
        uses: dokploy/deploy-action@v1
        with:
          dokploy-url: https://dok.dev.aglz.io
          dokploy-token: ${{ secrets.DOKPLOY_TOKEN_DEV }}
          application-id: agl-hostman-dev
          image: harbor.aglz.io:5000/agl/agl-hostman:${{ github.sha }}

      - name: Health Check
        run: |
          sleep 30
          curl -f https://dev.aglz.io/health || exit 1

      - name: Notify Success
        if: success()
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: '✅ Development deployment successful: ${{ github.sha }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

      - name: Notify Failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: '❌ Development deployment failed: ${{ github.sha }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [test, build]
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production
      url: https://app.aglz.io
    steps:
      - name: Pre-deployment Health Check
        run: |
          response=$(curl -s https://app.aglz.io/health)
          if echo "$response" | grep -q '"status":"healthy"'; then
            echo "✅ Pre-deployment health check passed"
          else
            echo "❌ Pre-deployment health check failed"
            exit 1
          fi

      - name: Deploy to Dokploy (Prod)
        uses: dokploy/deploy-action@v1
        with:
          dokploy-url: https://dok.aglz.io
          dokploy-token: ${{ secrets.DOKPLOY_TOKEN_PROD }}
          application-id: agl-hostman-prod
          image: harbor.aglz.io:5000/agl/agl-hostman:${{ github.sha }}
          strategy: rolling
          max_unavailable: 0
          max_surge: 1

      - name: Post-deployment Health Check
        run: |
          echo "Waiting for pods to become ready..."
          sleep 60

          for i in {1..10}; do
            if curl -f https://app.aglz.io/health; then
              echo "✅ Post-deployment health check passed"
              exit 0
            fi
            echo "Attempt $i/10 - retrying..."
            sleep 10
          done

          echo "❌ Post-deployment health check failed"
          exit 1

      - name: Validate DORA Metrics
        run: |
          # Update DORA metrics after deployment
          curl -X POST https://api.aglz.io/internal/dora/update \
            -H "Authorization: Bearer ${{ secrets.INTERNAL_API_TOKEN }}"

      - name: Update Status Page
        run: |
          curl -X PATCH https://api.statuspage.io/v1/incidents \
            -H "Authorization: OAuth ${{ secrets.STATUSPAGE_API_KEY }}" \
            -d "incident[component_ids]=deployment&incident[status]=operational"

      - name: Notify Success
        if: success()
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: '✅ Production deployment successful: ${{ github.sha }} Visit: https://app.aglz.io'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

      - name: Auto Rollback on Failure
        if: failure()
        run: |
          # Trigger rollback workflow
          gh workflow run rollback.yml --ref main -f version=previous

      - name: Notify Failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: '❌ Production deployment failed: ${{ github.sha }} Rolling back...'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Dokploy Integration

### Application Configuration

**Dokploy Application: `agl-hostman-prod`**

```json
{
  "name": "agl-hostman",
  "environment": "production",
  "build_method": "dockerfile",
  "repository": "https://github.com/your-org/agl-hostman",
  "branch": "main",
  "auto_deploy": false,
  "dockerfile_path": "./src/Dockerfile",
  "environment_variables": {
    "APP_ENV": "production",
    "APP_DEBUG": "false",
    "APP_URL": "https://app.aglz.io",
    "DB_CONNECTION": "pgsql",
    "DB_HOST": "postgres-prod",
    "REDIS_HOST": "redis-prod"
  },
  "resources": {
    "cpu": "2000m",
    "memory": "2Gi",
    "replicas": 5
  },
  "health_check": {
    "path": "/health",
    "interval": 30,
    "timeout": 10,
    "retries": 3
  }
}
```

### Harbor Registry Integration

**Repository: `harbor.aglz.io:5000/agl/agl-hostman`**

```bash
# Build and tag image
docker build -t harbor.aglz.io:5000/agl/agl-hostman:v1.2.3 ./src

# Push to harbor
docker push harbor.aglz.io:5000/agl/agl-hostman:v1.2.3

# Verify image
docker pull harbor.aglz.io:5000/agl/agl-hostman:v1.2.3

# Scan for vulnerabilities
trivy image harbor.aglz.io:5000/agl/agl-hostman:v1.2.3
```

**CI/CD Webhook:**
```yaml
# Auto-deploy on successful build
webhooks:
  - url: https://dok.aglz.io/api/webhooks/build-complete
    events:
      - push
      - tag
```

---

## Health Checks & Validation

### Application Health Endpoint

**Endpoint: `GET /health`**

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-29T10:30:00Z",
  "version": "v1.2.3",
  "checks": {
    "database": {
      "status": "healthy",
      "latency_ms": 12
    },
    "redis": {
      "status": "healthy",
      "latency_ms": 5
    },
    "storage": {
      "status": "healthy",
      "available_gb": 245.3
    },
    "queue_worker": {
      "status": "healthy",
      "active_jobs": 3
    },
    "websocket": {
      "status": "healthy",
      "connected_clients": 14
    }
  },
  "metrics": {
    "uptime": "5d 3h 12m",
    "memory_usage": "45%",
    "cpu_usage": "23%",
    "response_time_p95": "127ms"
  }
}
```

### Pre-Deployment Validation

```bash
#!/bin/bash
# scripts/pre-deploy-check.sh

set -e

echo "🔍 Running pre-deployment validation..."

# Check database connectivity
echo "Checking database..."
php artisan db:check || exit 1

# Verify Redis connection
echo "Checking Redis..."
php artisan redis:ping || exit 1

# Check storage permissions
echo "Checking storage permissions..."
test -w storage/logs || exit 1
test -w storage/framework || exit 1

# Run diagnostics command
echo "Running diagnostics..."
php artisan diagnose || exit 1

# Check disk space
echo "Checking disk space..."
available=$(df / | awk 'NR==2 {print $4}')
if [ "$available" -lt 5242880 ]; then
    echo "❌ Insufficient disk space"
    exit 1
fi

# Check pending migrations
echo "Checking for pending migrations..."
pending=$(php artisan migrate:status --format=json | jq '.migrations[] | select(.status=="pending")')
if [ ! -z "$pending" ]; then
    echo "❌ Pending migrations detected"
    exit 1
fi

echo "✅ Pre-deployment validation passed"
exit 0
```

### Post-Deployment Validation

```bash
#!/bin/bash
# scripts/post-deploy-check.sh

set -e

APP_URL="${APP_URL:-https://app.aglz.io}"
TIMEOUT=300
INTERVAL=10

echo "🔍 Running post-deployment validation..."

# Wait for application to become ready
echo "Waiting for application to start..."
elapsed=0
while [ $elapsed -lt $TIMEOUT ]; do
    if curl -sf "$APP_URL/health" > /dev/null 2>&1; then
        echo "✅ Application is responding"
        break
    fi

    echo "Still waiting... ($elapsed/$TIMEOUT s)"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

if [ $elapsed -ge $TIMEOUT ]; then
    echo "❌ Application failed to start within $TIMEOUT seconds"
    exit 1
fi

# Extended health check
echo "Running extended health checks..."
health_response=$(curl -sf "$APP_URL/health")
if echo "$health_response" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
    echo "✅ Extended health checks passed"
else
    echo "❌ Health check failed"
    echo "$health_response"
    exit 1
fi

# Critical endpoint check
echo "Testing critical endpoints..."
curl -sf "$APP_URL/api/v1/status" > /dev/null || exit 1
curl -sf "$APP_URL/api/v1/projects" > /dev/null || exit 1

# Performance check
echo "Checking response times..."
response_time=$(curl -o /dev/null -s -w '%{time_total}' "$APP_URL")
if (( $(echo "$response_time > 5.0" | bc -l) )); then
    echo "⚠️ Warning: Response time is high ($response_time s)"
fi

# External monitoring
echo "Notifying external monitoring..."
curl -X POST https://api.pingdom.com/checks \
  -H "Authorization: Bearer $PINGDOM_TOKEN" \
  -d "action=verify"

echo "✅ Post-deployment validation completed successfully"
exit 0
```

---

## Rollback Procedures

### Automatic Rollback

**Trigger Conditions:**
- Post-deployment health check fails
- Error rate > 5% for 2 consecutive minutes
- Response time P95 > 1 second
- Critical endpoints return 5xx errors

**Rollback Workflow:**
```yaml
name: Emergency Rollback

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Target version to rollback to'
        required: true
  repository_dispatch:
    types: [rollback]

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Rollback Alert
        run: |
          curl -X POST ${{ secrets.PAGERDUTY_WEBHOOK }} \
            -d '{"event_type":"rollback","version":"${{ github.event.inputs.version }}"}'

      - name: Deploy Previous Version
        uses: dokploy/deploy-action@v1
        with:
          dokploy-url: https://dok.aglz.io
          dokploy-token: ${{ secrets.DOKPLOY_TOKEN_PROD }}
          application-id: agl-hostman-prod
          image: harbor.aglz.io:5000/agl/agl-hostman:${{ github.event.inputs.version }}

      - name: Verify Rollback
        run: |
          sleep 30
          curl -f https://app.aglz.io/health || exit 1

      - name: Notify Team
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: '🔄 Rollback completed to version ${{ github.event.inputs.version }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Manual Rollback

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

VERSION=${1:-previous}

echo "🔄 Initiating rollback to version: $VERSION"

# Get current version
current_version=$(curl -s https://app.aglz.io/health | jq -r '.version')
echo "Current version: $current_version"

# Confirm rollback
read -p "Are you sure you want to rollback from $current_version to $VERSION? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled"
    exit 1
fi

# Trigger rollback via GitHub Actions
gh workflow run rollback.yml --ref main -f version=$VERSION

# Monitor rollback
echo "Monitoring rollback progress..."
gh run watch

# Verify rollback
echo "Verifying rollback..."
sleep 30
new_version=$(curl -s https://app.aglz.io/health | jq -r '.version')
echo "New version: $new_version"

if [ "$new_version" == "$VERSION" ]; then
    echo "✅ Rollback successful"
    exit 0
else
    echo "❌ Rollback failed"
    exit 1
fi
```

### Database Rollback

```bash
#!/bin/bash
# scripts/rollback-database.sh

set -e

# Rollback to specific migration
php artisan migrate:rollback --step=1

# Or rollback specific migration
php artisan migrate:rollback --path=database/migrations/2025_11_27_000001_create_scaling_events_table.php

# Verify rollback
php artisan migrate:status
```

---

## Monitoring & Observability

### Metrics Collection

**Prometheus Metrics Endpoint: `GET /metrics`**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'agl-hostman-prod'
    scrape_interval: 15s
    metrics_path: /metrics
    static_configs:
      - targets: ['app.aglz.io:9090']
```

**Key Metrics:**
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration histogram
- `app_queue_jobs_total` - Queue job metrics
- `app_deployments_total` - Deployment counter
- `app_health_status` - Health status gauge
- `dora_deployment_frequency` - DORA metrics

### Grafana Dashboards

**Dashboard: AGL-HOSTMAN Production**

Panels:
- Request rate (req/s)
- Response time percentiles (P50, P95, P99)
- Error rate (%)
- Queue length
- CPU/Memory usage
- Database connections
- Active deployments
- DORA metrics trends

### AlertManager Configuration

```yaml
# alertmanager.yml
route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: <pagerduty_key>

  - name: 'slack'
    slack_configs:
      - api_url: <slack_webhook>
        channel: '#alerts-prod'
```

**Alerts:**
- High error rate (> 5%)
- High response time (P95 > 1s)
- Low disk space (< 10GB)
- Queue saturation (> 1000 jobs)
- Database down
- Health check failures

---

## Troubleshooting

### Deployment Failures

**Issue: Health check timeout**
```bash
# Check pod logs
kubectl logs deployment/agl-hostman-prod -f

# Check resource limits
kubectl describe pod agl-hostman-prod-xxx

# Check database connectivity
php artisan db:check

# Restart pods
kubectl rollout restart deployment/agl-hostman-prod
```

**Issue: Database migration failure**
```bash
# Check migration status
php artisan migrate:status

# Run migrations manually
php artisan migrate --force

# If failed, rollback specific migration
php artisan migrate:rollback --path=database/migrations/xxx
```

**Issue: Out of memory**
```bash
# Check memory usage
kubectl top pods

# Increase memory limit in Dokploy
# Resources → Memory → 4Gi

# Or add more replicas for load distribution
```

**Issue: Image pull failure**
```bash
# Check Harbor registry
docker pull harbor.aglz.io:5000/agl/agl-hostman:v1.2.3

# Verify credentials
docker login harbor.aglz.io:5000

# Check image exists
curl -u username:password https://harbor.aglz.io/api/v2.0/projects/agl/repositories/agl-hostman/artifacts
```

### Performance Issues

**Issue: High response times**
```bash
# Enable debug mode temporarily
php artisan config:set APP_DEBUG=true

# Profile requests
php artisan telescope

# Check database queries
php artisan debug:queries

# Check cache hits
redis-cli INFO stats | grep keyspace_hits
```

**Issue: Queue backup**
```bash
# Check queue status
php artisan queue:monitor

# Restart queue workers
php artisan queue:restart

# Clear failed jobs
php artisan queue:flush

# Process queue manually
php artisan queue:work --tries=1
```

---

## Security Considerations

### Secrets Management

**Environment Variables (`.env`):**
```bash
# Never commit these to Git
APP_KEY=base64:...
DB_PASSWORD=...
REDIS_PASSWORD=...
MAIL_PASSWORD=...
JWT_SECRET=...
```

**GitHub Secrets:**
- `HARBOR_USERNAME` - Harbor registry username
- `HARBOR_PASSWORD` - Harbor registry password
- `DOKPLOY_TOKEN_PROD` - Production deployment token
- `SLACK_WEBHOOK` - Slack notifications webhook
- `PAGERDUTY_WEBHOOK` - PagerDuty incident webhook
- `INTERNAL_API_TOKEN` - Internal API authentication

### Security Scanning

**Pre-deployment scans:**
```bash
# Docker image scan
trivy image harbor.aglz.io:5000/agl/agl-hostman:v1.2.3

# Dependency scan
composer audit

# Code security scan
php artisan security:scan

# OWASP ZAP scan (optional)
zaproxy --quickurl https://app.aglz.io --quickprogress
```

---

**End of Deployment Guide**

For additional support, contact the DevOps team at devops@aglz.io or reach out in #devops Slack channel.
