# Container Registry and Deployment Infrastructure Analysis

**Project:** AGL Hostman Infrastructure Management Platform
**Analysis Date:** 2026-02-07
**Infrastructure Components:** Harbor Registry, Dokploy Platform, CI/CD Pipelines

---

## Executive Summary

AGL Hostman implements a sophisticated containerized infrastructure with enterprise-grade Harbor registry integration, Dokploy deployment automation, and comprehensive CI/CD workflows. The platform supports blue-green deployments, multi-environment configurations, and advanced caching strategies achieving 75%+ build time optimization.

---

## 1. Harbor Container Registry Integration

### 1.1 Architecture Overview

```
GitHub Actions → Build & Push → Harbor Registry (CT182)
                                         ↓
                              Vulnerability Scanning (Trivy)
                                         ↓
                              Webhook → Dokploy Deployment
                                         ↓
                              Production (Blue/Green Slots)
```

### 1.2 Harbor API Client (`HarborApiClient.php`)

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/HarborApiClient.php`

**Key Features:**
- **Circuit Breaker Pattern:** Prevents cascading failures (threshold: 5, timeout: 60s)
- **Retry Logic:** Exponential backoff with 3 retry attempts
- **Basic Authentication:** Secure HTTP auth via username/password
- **Connection Testing:** Built-in health check endpoint

**Code Pattern:**
```php
// Circuit Breaker State
protected array $circuitBreaker = [
    'failures' => 0,
    'last_failure' => null,
    'threshold' => 5,
    'timeout' => 60,
];

// Retry with Exponential Backoff
while ($attempt < $this->maxRetries) {
    // ... execute request
    if ($attempt < $this->maxRetries) {
        usleep(500000 * $attempt); // 0.5s, 1s, 1.5s
    }
}
```

### 1.3 Harbor Service Layer (`HarborService.php`)

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/HarborService.php`

**Capabilities:**

| Feature | Method | Description |
|---------|--------|-------------|
| **Projects** | `getProjects()`, `createProject()` | Manage Harbor projects with metadata |
| **Repositories** | `getRepositories()`, `deleteRepository()` | Image repository management |
| **Artifacts** | `getArtifacts()`, `copyArtifact()` | Tag and image operations |
| **Vulnerability Scanning** | `getVulnerabilities()`, `triggerScan()` | Trivy integration |
| **Retention Policies** | `getRetentionPolicies()`, `createRetentionPolicy()` | Tag lifecycle management |
| **Webhooks** | `getWebhooks()`, `createWebhook()` | Event-driven deployments |
| **System Health** | `getHealthStatus()`, `getSystemInfo()` | Registry monitoring |

**DTOs Implemented:**
- `HarborProjectDTO` - Project metadata
- `HarborRepositoryDTO` - Repository details
- `HarborArtifactDTO` - Image manifests
- `HarborVulnerabilityDTO` - Scan results

### 1.4 Harbor Configuration (`config/harbor.php`)

```php
'base_url' => env('HARBOR_BASE_URL', 'https://harbor.aglz.io'),
'username' => env('HARBOR_USERNAME'),
'password' => env('HARBOR_PASSWORD'),
'timeout' => env('HARBOR_TIMEOUT', 30),
'retry_times' => env('HARBOR_RETRY_TIMES', 3),
'retry_delay' => env('HARBOR_RETRY_DELAY', 1000),

// Cache Configuration
'cache' => [
    'enabled' => env('HARBOR_CACHE_ENABLED', true),
    'ttl' => env('HARBOR_CACHE_TTL', 300), // 5 minutes
],

// Circuit Breaker
'circuit_breaker' => [
    'threshold' => env('HARBOR_CIRCUIT_THRESHOLD', 5),
    'timeout' => env('HARBOR_CIRCUIT_TIMEOUT', 60),
],
```

### 1.5 REST API Controller (`HarborController.php`)

**Endpoints:**
```
GET    /api/harbor/projects
POST   /api/harbor/projects
GET    /api/harbor/projects/{project}/repositories
GET    /api/harbor/projects/{project}/repositories/{repository}/artifacts
POST   /api/harbor/projects/{project}/repositories/{repository}/artifacts/{reference}/scan
GET    /api/harbor/vulnerabilities/{project}/{repository}/{reference}
GET    /api/harbor/system/health
```

---

## 2. Dokploy Deployment Platform Integration

### 2.1 Architecture Overview

```
Dokploy (CT180) → Docker Engine → Container Orchestration
       ↓
   Traefik Proxy → SSL/Routing
       ↓
   Git Integration → CI/CD Triggers
```

### 2.2 Dokploy API Client (`DokployApiClient.php`)

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/DokployApiClient.php`

**Key Features:**
- **JWT Authentication:** Bearer token via `x-api-key` header
- **Circuit Breaker Pattern:** Same resilience pattern as Harbor client
- **Retry Logic:** Exponential backoff (0.5s, 1s, 1.5s intervals)
- **Connection Testing:** Health check endpoint

**Authentication:**
```php
$headers = [
    'x-api-key' => $this->apiKey,
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
];
```

### 2.3 Dokploy Service Layer (`DokployService.php`)

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/src/app/Services/DokployService.php`

**Capabilities:**

| Feature | Method | Description |
|---------|--------|-------------|
| **Projects** | `getProjects()`, `createProject()` | Project management |
| **Applications** | `createApplication()`, `getApplication()` | Application lifecycle |
| **Deployment** | `deployApplication()`, `redeployApplication()` | Deploy operations |
| **Domain Management** | `getDomains()`, `addDomain()` | Custom domain routing |
| **Environment Variables** | `getEnvironmentVariables()`, `setEnvironmentVariables()` | Configuration |
| **Deployment Control** | `startApplication()`, `stopApplication()`, `restartApplication()` | Service control |
| **Logs** | `getDeploymentLogs()` | Deployment debugging |

### 2.4 Dokploy Configuration (`config/dokploy.php`)

```php
'base_url' => env('DOKPLOY_BASE_URL', 'https://dok.aglz.io'),
'api_key' => env('DOKPLOY_API_KEY'),

// Harbor Registry Integration
'harbor' => [
    'url' => env('HARBOR_URL', 'harbor.aglz.io:5000'),
    'username' => env('HARBOR_USERNAME', 'admin'),
    'password' => env('HARBOR_PASSWORD'),
    'project' => env('HARBOR_PROJECT', 'agl'),
],

// Circuit Breaker
'circuit_breaker' => [
    'threshold' => env('DOKPLOY_CIRCUIT_BREAKER_THRESHOLD', 5),
    'timeout' => env('DOKPLOY_CIRCUIT_BREAKER_TIMEOUT', 60),
],

// Auto-Deployment
'auto_deploy' => [
    'enabled' => env('DOKPLOY_AUTO_DEPLOY', true),
    'environments' => [
        'production' => env('DOKPLOY_AUTO_DEPLOY_PRODUCTION', false),
        'staging' => env('DOKPLOY_AUTO_DEPLOY_STAGING', true),
        'development' => env('DOKPLOY_AUTO_DEPLOY_DEVELOPMENT', true),
    ],
],
```

### 2.5 REST API Controller (`DokployController.php`)

**Endpoints:**
```
GET    /api/dokploy/applications
POST   /api/dokploy/deploy
POST   /api/dokploy/redeploy
POST   /api/dokploy/services/{id}/start
POST   /api/dokploy/services/{id}/stop
POST   /api/dokploy/services/{id}/restart
GET    /api/dokploy/deployments/{applicationId}/status
GET    /api/dokploy/domains
POST   /api/dokploy/domains
GET    /api/dokploy/environment
POST   /api/dokploy/environment
GET    /api/dokploy/logs
GET    /api/dokploy/test
```

---

## 3. Docker Container Management

### 3.1 Multi-Stage Dockerfile (`src/Dockerfile`)

**Build Stages:**

| Stage | Purpose | Cache Strategy |
|-------|---------|----------------|
| **php-base** | PHP 8.4 + Extensions | System layer (rarely changes) |
| **composer-deps** | PHP Dependencies | BuildKit cache mount |
| **node-deps** | NPM Dependencies | BuildKit cache mount |
| **asset-builder** | Vite Frontend Build | Vite cache mount |
| **production** | Minimal Runtime | Only artifacts |
| **development** | Debugging (Xdebug) | Development tools |
| **test** | CI Testing | Test dependencies |

**Key Optimizations:**
```dockerfile
# Composer with cache mount
RUN --mount=type=cache,target=/root/.composer,id=composer-cache \
    composer install --no-dev --prefer-dist

# NPM with cache mount
RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    npm ci --prefer-offline

# Vite build with cache
RUN --mount=type=cache,target=/app/node_modules/.vite,id=vite-cache \
    npm run build -- --mode production
```

**Performance Metrics:**
- First build: 8-12 minutes
- Cached build: 30-60 seconds
- Partial changes: 2-3 minutes
- **Optimization: 75%+ reduction** in subsequent builds

### 3.2 BuildKit Configuration (`buildkit.toml`)

**Location:** `/mnt/overpower/apps/dev/agl/agl-hostman/buildkit.toml`

```toml
[worker.oci]
  max-parallelism = 4
  gc = true
  gckeepstorage = 10737418240  # 10 GB

[registry."harbor.aglz.io:5000"]
  http = false
  insecure = false

[cache]
  mode = "max"
  keep-bytes = 10737418240  # 10 GB
  keep-duration = 604800     # 7 days
```

### 3.3 Docker Compose Configurations

#### Development (`docker-compose.yml`)
**Services:** app, nginx, db (PostgreSQL), redis, horizon, reverb, mailhog, adminer

**Key Features:**
- Volume mounts for hot-reload
- Development target with Xdebug
- Vite dev server integration
- Health checks on all services

#### Production Blue-Green (`docker/production/docker-compose.blue.yml`)

**Architecture:**
```yaml
app-blue-1:  # Primary instance
  image: harbor.aglz.io:5000/agl-hostman-prod:${BLUE_VERSION}
  resources:
    limits: 4 CPUs, 8GB RAM
    reservations: 2 CPUs, 4GB RAM

postgres-primary:  # Shared database
  image: postgres:16-alpine

redis-master:  # Shared cache
  image: redis:7-alpine
```

**Deployment Slots:**
- **Blue Slot:** Active production instances
- **Green Slot:** Staging for new releases
- Gradual traffic switching (10% → 50% → 100%)

---

## 4. CI/CD Pipeline Patterns

### 4.1 GitHub Actions Workflows

#### CI Pipeline (`.github/workflows/ci.yml`)

**Jobs:**
1. **Code Quality & Linting** (Laravel Pint, ESLint)
2. **PHP Tests** (Pest: Unit, Feature, Integration, Architecture)
3. **JavaScript Tests** (Vite)
4. **Security Scanning** (Composer audit, npm audit, Trivy, TruffleHog)
5. **Static Analysis** (PHPStan)
6. **Docker Build Test** (Test target)
7. **Production Image Build** (Push to Harbor)

**Caching Strategy:**
```yaml
- name: Cache Composer dependencies
  uses: actions/cache@v4
  with:
    path: vendor
    key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}

- name: Build and push production image
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

#### CD Pipeline (`.github/workflows/cd.yml`)

**Deployment Flow:**
```
Pre-deploy Validation → Staging Deployment → Health Checks
                                              ↓
                                         Post-deploy Tests
                                              ↓
                              Production Deployment (Approval)
                                              ↓
                              Blue-Green Deployment
                                              ↓
                              Gradual Traffic Switch
                                              ↓
                              Monitoring (5 min)
                                              ↓
                              Auto-Rollback on Failure
```

**Production Deployment Script:** `scripts/deployment/deploy-production.sh`

**Key Features:**
- Required approval workflow
- Blue-green slot management
- Health check verification
- Smoke test execution
- Gradual traffic switching (10%, 50%, 100%)
- Automatic rollback on error rate > 5%

#### Docker Build Workflow (`.github/workflows/docker-build.yml`)

**Triggered on:** Push to main branch

**Steps:**
1. Checkout code
2. Set up Docker Buildx
3. Login to Harbor registry
4. Extract metadata tags
5. Build and push with cache
6. Trivy vulnerability scan
7. Upload results to GitHub Security

---

## 5. Container Management Workflows

### 5.1 Image Build & Push

```bash
# Manual deployment script
./src/deploy.sh [version]

# Steps:
# 1. Build Docker image
# 2. Run tests
# 3. Login to Harbor
# 4. Push to Harbor
# 5. Trigger Dokploy webhook
```

### 5.2 Blue-Green Deployment

**Location:** `scripts/deployment/deploy-production.sh`

**Process:**
```bash
# 1. Determine active slot (blue/green)
# 2. Deploy to inactive slot
# 3. Health check inactive slot
# 4. Smoke test inactive slot
# 5. Gradual traffic switch (10% → 50% → 100%)
# 6. Monitor for 5 minutes
# 7. Switch active slot
# 8. Keep old slot for 1h rollback window
```

**Rollback Triggers:**
- Health check failure
- Smoke test failure
- Error rate > 5%
- Response time > 500ms

### 5.3 Environment Configurations

| Environment | Docker Compose | Registry | Deployment |
|-------------|----------------|----------|------------|
| **Local** | `docker-compose.yml` | N/A | Volume mounts |
| **QA** | `src/docker/qa/docker-compose.yml` | Harbor `agl/agl-hostman:qa` | Manual |
| **UAT** | `src/docker/uat/docker-compose.yml` | Harbor `agl/agl-hostman:uat` | Dokploy |
| **Staging** | `src/docker/staging/docker-compose.yml` | Harbor `agl/agl-hostman:staging` | Dokploy auto |
| **Production** | `src/docker/production/docker-compose.{blue,green}.yml` | Harbor `agl-hostman-prod` | Blue-green |

### 5.4 Harbor Webhook Integration

**Webhook Configuration:**
```php
$webhook = $this->harbor->createWebhook($projectId, [
    'name' => 'Dokploy Integration',
    'url' => 'https://dok.aglz.io/api/webhooks/deploy',
    'secret' => env('HARBOR_WEBHOOK_SECRET'),
    'events' => [
        'PUSH_ARTIFACT',      // Image pushed
        'SCANNING_COMPLETED', // Scan finished
    ],
]);
```

**Webhook Handler:**
```php
// Route: /api/webhooks/harbor
public function handleWebhook(Request $request)
{
    $payload = $request->all();

    switch ($payload['type']) {
        case 'push_image':
            $this->handleImagePushed($payload);
            break;
        case 'scan_image':
            $this->handleImageScanned($payload);
            break;
    }
}
```

---

## 6. Deployment Scripts

### 6.1 Production Deployment

**Script:** `scripts/deployment/deploy-production.sh`

**Usage:**
```bash
./scripts/deployment/deploy-production.sh [--version VERSION] [--skip-approval]
```

**Features:**
- Pre-flight prerequisite checks
- Required approval workflow
- Slot determination (blue/green)
- Deployment to inactive slot
- Health and smoke test verification
- Gradual traffic switching
- Monitoring window (5 min)
- Automatic rollback on failure

### 6.2 Staging Deployment

**Script:** `scripts/deployment/deploy-staging.sh`

**Features:**
- Automated deployment (no approval required)
- Health check verification
- Direct deployment (no blue-green)
- Smoke test execution

### 6.3 Rollback Script

**Script:** `scripts/deployment/rollback.sh`

**Features:**
- Immediate traffic switch back
- Previous slot health verification
- Rollback notification
- Deployment state restoration

---

## 7. Recommended Skills for Container Operations

### 7.1 Harbor Registry Management

**Required Skills:**
1. **Harbor API Operations**
   - Project creation and configuration
   - Robot account management
   - Retention policy configuration
   - Webhook setup and troubleshooting

2. **Vulnerability Scanning**
   - Trivy scanner configuration
   - Severity threshold management
   - Scan result analysis
   - Remediation workflows

3. **Image Lifecycle**
   - Tag management strategies
   - Garbage collection policies
   - Replication configuration
   - Storage quota management

### 7.2 Dokploy Deployment

**Required Skills:**
1. **Application Deployment**
   - Docker/Docker Compose deployments
   - Git-based deployments
   - Environment variable management
   - Domain and SSL configuration

2. **Deployment Strategies**
   - Blue-green deployments
   - Rolling updates
   - Canary deployments
   - Rollback procedures

3. **Monitoring & Debugging**
   - Deployment log analysis
   - Container health checks
   - Performance monitoring
   - Failure troubleshooting

### 7.3 Docker & BuildKit

**Required Skills:**
1. **Dockerfile Optimization**
   - Multi-stage builds
   - Layer caching strategies
   - BuildKit cache mounts
   - Image size optimization

2. **Build Configuration**
   - BuildKit daemon configuration
   - Registry mirror setup
   - Cache retention policies
   - Parallel build optimization

3. **Docker Compose**
   - Multi-environment configurations
   - Service orchestration
   - Volume management
   - Network configuration

### 7.4 CI/CD Automation

**Required Skills:**
1. **GitHub Actions**
   - Workflow authoring
   - Composite actions
   - Caching strategies
   - Secret management

2. **Pipeline Design**
   - Trunk-based development
   - Feature flag strategies
   - Automated testing gates
   - Deployment approval workflows

3. **Monitoring & Alerting**
   - Deployment metrics
   - Error rate tracking
   - Performance monitoring
   - Alert configuration

---

## 8. Integration Patterns

### 8.1 Harbor + Dokploy Workflow

```
Developer pushes code → GitHub Actions CI
                         ↓
                   Docker build & test
                         ↓
                   Push to Harbor (trigger scan)
                         ↓
                   Trivy vulnerability scan
                         ↓
                   Harbor webhook (scan complete)
                         ↓
                   Dokploy deploy application
                         ↓
                   Blue-green traffic switch
                         ↓
                   Health check verification
```

### 8.2 Webhook Event Handling

**Push Artifact Event:**
```php
{
  "type": "push_image",
  "event_data": {
    "repository": "agl/hostman",
    "tag": "v1.2.3",
    "digest": "sha256:abc123..."
  }
}
```

**Scan Complete Event:**
```php
{
  "type": "scan_image",
  "event_data": {
    "repository": "agl/hostman",
    "tag": "v1.2.3",
    "scan": {
      "severity": "medium",
      "summary": {
        "total": 5,
        "fixable": 3,
        "critical": 0,
        "high": 1
      }
    }
  }
}
```

### 8.3 Circuit Breaker Pattern

**Implementation:**
```php
// Both Harbor and Dokploy clients implement this pattern

protected function isCircuitBreakerOpen(): bool
{
    if ($this->circuitBreaker['failures'] < $this->circuitBreaker['threshold']) {
        return false;
    }

    $elapsed = now()->diffInSeconds($this->circuitBreaker['last_failure']);
    return $elapsed < $this->circuitBreaker['timeout'];
}

protected function recordFailure(): void
{
    $this->circuitBreaker['failures']++;
    $this->circuitBreaker['last_failure'] = now();
}
```

---

## 9. Security Considerations

### 9.1 Authentication

| Component | Method | Credential Storage |
|-----------|--------|-------------------|
| **Harbor** | Basic Auth | Environment variables (`HARBOR_USERNAME`, `HARBOR_PASSWORD`) |
| **Dokploy** | JWT Bearer Token | Environment (`DOKPLOY_API_KEY`) |
| **Registry Pull** | Docker Config | `.docker/config.json` or secret mount |

### 9.2 Vulnerability Management

**Scanning Pipeline:**
1. Image pushed to Harbor
2. Automatic Trivy scan triggered
3. Results stored in artifact metadata
4. Webhook notification on completion
5. Deployment blocked if severity > threshold

**Severity Thresholds:**
```php
'severity' => 'medium',  // Block deployment on 'high' or 'critical'
'prevent_vul' => env('HARBOR_DEFAULT_PREVENT_VUL', false),
```

### 9.3 Robot Account Rotation

**Best Practices:**
- Rotate robot accounts every 90 days
- Use minimal required permissions
- Separate accounts for push/pull operations
- Monitor robot account usage

---

## 10. Performance Metrics

### 10.1 Build Performance

| Metric | Value |
|--------|-------|
| **First Build** | 8-12 minutes |
| **Cached Build** | 30-60 seconds |
| **Partial Changes** | 2-3 minutes |
| **Cache Hit Rate** | 95%+ (after first build) |
| **Image Size Reduction** | ~60% (multi-stage) |

### 10.2 Deployment Metrics

| Metric | Value |
|--------|-------|
| **Deployment Time** | ~3-5 minutes |
| **Health Check Timeout** | 5 minutes |
| **Traffic Switch Duration** | ~3 minutes (10%→50%→100%) |
| **Rollback Time** | ~30 seconds |
| **Monitoring Window** | 5 minutes |

---

## 11. Troubleshooting Guide

### 11.1 Common Issues

**Harbor Authentication Failed:**
```bash
# Verify credentials
curl -u 'username:password' https://harbor.aglz.io/api/v2.0/projects

# Check robot account expiration
# Harbor UI: Administration → Robot Accounts
```

**Dokploy Deployment Timeout:**
```bash
# Increase timeout in config
DOKPLOY_TIMEOUT=300

# Check application logs
docker logs <container_id> --tail=100
```

**Build Cache Not Working:**
```bash
# Clear BuildKit cache
docker builder prune -f

# Verify cache mounts
docker buildx build --progress=plain --check .
```

### 11.2 Debug Commands

```bash
# Harbor health check
curl https://harbor.aglz.io/api/v2.0/systemhealth

# Dokploy health check
curl https://dok.aglz.io/api/health

# Container logs
docker-compose logs -f app

# Deployment status
./scripts/deployment/deploy-production.sh --version latest
```

---

## 12. Best Practices

### 12.1 Image Tagging
```bash
# Semantic versioning
harbor.aglz.io/agl/hostman:1.2.3
harbor.aglz.io/agl/hostman:1.2.4
harbor.aglz.io/agl/hostman:2.0.0

# Environment tags
harbor.aglz.io/agl/hostman:latest
harbor.aglz.io/agl/hostman:staging
harbor.aglz.io/agl/hostman:production
```

### 12.2 Dockerfile Optimization
```dockerfile
# Layer ordering: Least changing first
# System packages → PHP extensions → Composer → Application code

# Multi-stage builds for minimal final image
FROM composer:2.7 AS deps
FROM node:20-alpine AS assets
FROM php:8.4-fpm-alpine AS production

# BuildKit cache mounts for dependencies
RUN --mount=type=cache,target=/root/.composer \
    composer install --no-dev
```

### 12.3 Deployment Safety
```bash
# Always test in staging first
./scripts/deployment/deploy-staging.sh --version v1.2.3

# Run smoke tests before production
curl -f https://staging.agl.aglz.io/api/health

# Monitor error rates during switch
curl https://prod-agl.aglz.io/api/metrics/error-rate
```

---

## 13. Documentation References

| Document | Location |
|----------|----------|
| **Harbor Integration** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/integrations/harbor.md` |
| **Dokploy Integration** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/integrations/dokploy.md` |
| **Deployment Overview** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/deployments/overview.md` |
| **Production Runbook** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/PRODUCTION-RUNBOOK.md` |
| **Build Optimization** | `/mnt/overpower/apps/dev/agl/agl-hostman/docs/BUILD-OPTIMIZATION-GUIDE.md` |

---

## Appendix A: Environment Variables

```env
# Harbor Registry
HARBOR_BASE_URL=https://harbor.aglz.io
HARBOR_USERNAME=agl-hostman-robot
HARBOR_PASSWORD=<robot-secret>
HARBOR_TIMEOUT=30
HARBOR_CACHE_TTL=300

# Dokploy Platform
DOKPLOY_BASE_URL=https://dok.aglz.io
DOKPLOY_API_KEY=<jwt-token>
DOKPLOY_TIMEOUT=120

# Deployment
PRODUCTION_DOKPLOY_URL=https://dok.aglz.io
PRODUCTION_DOKPLOY_TOKEN=<token>
PRODUCTION_DOMAIN=prod-agl.aglz.io
PRODUCTION_LB_API_URL=<lb-api>
PRODUCTION_LB_TOKEN=<lb-token>

# Docker Registry
DOCKER_REGISTRY=harbor.aglz.io:5000
DOCKER_REGISTRY_USERNAME=agl-hostman
DOCKER_REGISTRY_PASSWORD=<password>
```

---

## Appendix B: File Structure

```
/mnt/overpower/apps/dev/agl/agl-hostman/
├── src/
│   ├── app/
│   │   ├── Services/
│   │   │   ├── HarborApiClient.php          # Harbor HTTP client
│   │   │   ├── HarborService.php            # Harbor business logic
│   │   │   ├── DokployApiClient.php         # Dokploy HTTP client
│   │   │   └── DokployService.php           # Dokploy business logic
│   │   ├── Http/Controllers/Api/
│   │   │   ├── HarborController.php         # Harbor REST API
│   │   │   └── DokployController.php        # Dokploy REST API
│   │   └── DTOs/
│   │       ├── Harbor/                       # Harbor DTOs
│   │       └── Dokploy/                     # Dokploy DTOs
│   ├── Dockerfile                           # Multi-stage build
│   ├── docker-compose.yml                   # Dev environment
│   ├── docker-compose.override.yml          # Dev overrides
│   └── docker/
│       ├── production/
│       │   ├── docker-compose.blue.yml      # Blue slot
│       │   └── docker-compose.green.yml     # Green slot
│       ├── qa/
│       │   └── docker-compose.yml           # QA environment
│       └── uat/
│           └── docker-compose.yml           # UAT environment
├── .github/workflows/
│   ├── ci.yml                               # CI pipeline
│   ├── cd.yml                               # CD pipeline
│   ├── docker-build.yml                     # Docker build
│   ├── deploy-production.yml                # Production deployment
│   └── deploy-staging.yml                   # Staging deployment
├── scripts/deployment/
│   ├── deploy-production.sh                 # Production script
│   ├── deploy-staging.sh                    # Staging script
│   └── rollback.sh                          # Rollback script
├── config/
│   ├── harbor.php                           # Harbor config
│   └── dokploy.php                          # Dokploy config
├── buildkit.toml                            # BuildKit config
└── docs/
    ├── integrations/
    │   ├── harbor.md                        # Harbor guide
    │   └── dokploy.md                       # Dokploy guide
    └── deployments/
        └── overview.md                      # Deployment docs
```

---

**Document Version:** 1.0
**Last Updated:** 2026-02-07
**Maintained By:** AGL Infrastructure Team
