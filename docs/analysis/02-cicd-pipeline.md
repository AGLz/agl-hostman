# CI/CD Pipeline Design and Implementation

> **Document**: Deployment Workflow Analysis - Part 2
> **Version**: 1.0.0
> **Created**: 2025-10-28
> **Author**: Analyst Agent (Hive Mind)

---

## 📋 Executive Summary

This document defines the complete CI/CD pipeline architecture for the AGL infrastructure management project, leveraging Dokploy for multi-environment deployments with Harbor registry integration and automated quality gates.

---

## 🏗️ Pipeline Architecture

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **CI/CD Platform** | GitHub Actions | Automated workflows |
| **Container Registry** | Harbor (CT182) | Image storage & scanning |
| **Deployment Platform** | Dokploy (CT180/181/182) | Multi-environment orchestration |
| **Container Runtime** | Docker | Application packaging |
| **Orchestration** | Docker Compose | Service management |
| **Secret Management** | GitHub Secrets + Dokploy | Credential handling |
| **Monitoring** | Prometheus + Grafana | Pipeline metrics |

### Infrastructure Mapping

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│                   github.com/org/repo                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼ (webhook)
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Actions Runner                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Build Pipeline                                       │  │
│  │  - Compile/Build                                      │  │
│  │  - Unit Tests                                         │  │
│  │  - Security Scan                                      │  │
│  │  - Docker Build                                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼ (docker push)
┌─────────────────────────────────────────────────────────────┐
│             Harbor Registry (CT182)                          │
│             harbor.aglz.io                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Projects:                                            │  │
│  │  - dev/myapp:latest                                   │  │
│  │  - qa/myapp:v1.2.3-qa                                 │  │
│  │  - uat/myapp:v1.2.3-uat                               │  │
│  │  - prod/myapp:v1.2.3                                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼ (deploy trigger)
┌─────────────────────────────────────────────────────────────┐
│                 Dokploy Environments                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CT179: Development (Docker Compose)                  │  │
│  │  - Pulls: harbor.aglz.io/dev/*:latest                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CT182: QA (Dokploy)                                  │  │
│  │  - Pulls: harbor.aglz.io/qa/*:v*-qa                  │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CT181: UAT (Dokploy)                                 │  │
│  │  - Pulls: harbor.aglz.io/uat/*:v*-uat                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CT180: Production (Dokploy)                          │  │
│  │  - Pulls: harbor.aglz.io/prod/*:v*                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Pipeline Stages

### Stage 1: Build & Test (develop branch)

**Triggered by**: Push to develop, feature/* branches

```yaml
name: Build and Test
on:
  push:
    branches:
      - develop
      - 'feature/**'
      - 'bugfix/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # 1. Checkout code
      - uses: actions/checkout@v4

      # 2. Setup environment
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      # 3. Install dependencies
      - name: Install dependencies
        run: npm ci

      # 4. Lint code
      - name: Run linter
        run: npm run lint

      # 5. Run unit tests
        run: npm test

      # 6. Code coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3

      # 7. Build application
      - name: Build
        run: npm run build

      # 8. Security scan (dependencies)
      - name: Run security audit
        run: npm audit --audit-level=moderate

      # 9. Build Docker image
      - name: Build Docker image
        run: |
          docker build -t myapp:${GITHUB_SHA} .

      # 10. Scan Docker image
      - name: Scan image for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${GITHUB_SHA}
          severity: HIGH,CRITICAL

      # 11. Push to Harbor dev registry
      - name: Push to Harbor
        if: github.ref == 'refs/heads/develop'
        run: |
          echo "${{ secrets.HARBOR_PASSWORD }}" | docker login harbor.aglz.io -u ${{ secrets.HARBOR_USERNAME }} --password-stdin
          docker tag myapp:${GITHUB_SHA} harbor.aglz.io/dev/myapp:latest
          docker tag myapp:${GITHUB_SHA} harbor.aglz.io/dev/myapp:${GITHUB_SHA}
          docker push harbor.aglz.io/dev/myapp:latest
          docker push harbor.aglz.io/dev/myapp:${GITHUB_SHA}
```

**Quality Gates**:
- ✅ All tests pass (100% success rate)
- ✅ Code coverage >= 80%
- ✅ No high/critical security vulnerabilities
- ✅ Linting passes (0 errors)
- ✅ Docker build succeeds

---

### Stage 2: Integration Tests (staging branch)

**Triggered by**: Push to staging

```yaml
name: Integration Tests
on:
  push:
    branches:
      - staging

jobs:
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: testpass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        run: |
          cp .env.test .env
          npm ci
          npm run build

      - name: Run database migrations
        run: npm run migrate:test

      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:testpass@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379

      - name: Run API contract tests
        run: npm run test:contract

      - name: Performance benchmarks
        run: npm run test:performance

      - name: Build and push QA image
        run: |
          VERSION=$(node -p "require('./package.json').version")
          docker build -t myapp:${VERSION}-qa .
          echo "${{ secrets.HARBOR_PASSWORD }}" | docker login harbor.aglz.io -u ${{ secrets.HARBOR_USERNAME }} --password-stdin
          docker tag myapp:${VERSION}-qa harbor.aglz.io/qa/myapp:${VERSION}-qa
          docker push harbor.aglz.io/qa/myapp:${VERSION}-qa

      - name: Deploy to QA environment
        uses: appleboy/ssh-action@master
        with:
          host: 192.168.0.182
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/dokploy
            docker compose pull myapp
            docker compose up -d myapp
```

**Quality Gates**:
- ✅ Integration tests pass
- ✅ API contract tests pass
- ✅ Database migrations successful
- ✅ Performance benchmarks within limits
- ✅ No breaking changes detected

---

### Stage 3: UAT Deployment (release branch)

**Triggered by**: Push to release

```yaml
name: UAT Deployment
on:
  push:
    branches:
      - release

jobs:
  uat-deploy:
    runs-on: ubuntu-latest
    environment:
      name: uat
      url: https://uat.myapp.aglz.io

    steps:
      - uses: actions/checkout@v4

      - name: Extract version
        id: version
        run: |
          VERSION=$(node -p "require('./package.json').version")
          echo "version=${VERSION}" >> $GITHUB_OUTPUT

      - name: Run E2E tests
        run: |
          npm ci
          npm run test:e2e

      - name: Build production image
        run: |
          docker build \
            --build-arg NODE_ENV=production \
            --build-arg VERSION=${{ steps.version.outputs.version }} \
            -t myapp:${{ steps.version.outputs.version }}-uat .

      - name: Security scan (final)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ steps.version.outputs.version }}-uat
          severity: CRITICAL
          exit-code: '1'

      - name: Push to Harbor UAT
        run: |
          echo "${{ secrets.HARBOR_PASSWORD }}" | docker login harbor.aglz.io -u ${{ secrets.HARBOR_USERNAME }} --password-stdin
          docker tag myapp:${{ steps.version.outputs.version }}-uat harbor.aglz.io/uat/myapp:${{ steps.version.outputs.version }}-uat
          docker push harbor.aglz.io/uat/myapp:${{ steps.version.outputs.version }}-uat

      - name: Deploy to UAT (CT181)
        uses: appleboy/ssh-action@master
        with:
          host: 192.168.0.181
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/dokploy/projects/myapp
            export VERSION=${{ steps.version.outputs.version }}
            docker compose -f docker-compose.uat.yml pull
            docker compose -f docker-compose.uat.yml up -d

      - name: Health check
        run: |
          sleep 30
          curl -f https://uat.myapp.aglz.io/health || exit 1

      - name: Smoke tests
        run: npm run test:smoke -- --env=uat
```

**Quality Gates**:
- ✅ E2E tests pass
- ✅ No critical vulnerabilities
- ✅ Health check passes
- ✅ Smoke tests pass
- ✅ Performance meets SLA

---

### Stage 4: Production Deployment (main branch)

**Triggered by**: Push to main

```yaml
name: Production Deployment
on:
  push:
    branches:
      - main

jobs:
  production-deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.aglz.io

    steps:
      - uses: actions/checkout@v4

      - name: Extract version
        id: version
        run: |
          VERSION=$(node -p "require('./package.json').version")
          echo "version=${VERSION}" >> $GITHUB_OUTPUT

      - name: Pull UAT image
        run: |
          echo "${{ secrets.HARBOR_PASSWORD }}" | docker login harbor.aglz.io -u ${{ secrets.HARBOR_USERNAME }} --password-stdin
          docker pull harbor.aglz.io/uat/myapp:${{ steps.version.outputs.version }}-uat

      - name: Tag for production
        run: |
          docker tag \
            harbor.aglz.io/uat/myapp:${{ steps.version.outputs.version }}-uat \
            harbor.aglz.io/prod/myapp:${{ steps.version.outputs.version }}
          docker tag \
            harbor.aglz.io/uat/myapp:${{ steps.version.outputs.version }}-uat \
            harbor.aglz.io/prod/myapp:latest

      - name: Push to production registry
        run: |
          docker push harbor.aglz.io/prod/myapp:${{ steps.version.outputs.version }}
          docker push harbor.aglz.io/prod/myapp:latest

      - name: Create backup snapshot
        uses: appleboy/ssh-action@master
        with:
          host: 192.168.0.180
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/dokploy/projects/myapp
            docker compose exec -T db pg_dump -U appuser appdb > backup-pre-deploy-$(date +%Y%m%d-%H%M%S).sql

      - name: Deploy to production (CT180)
        uses: appleboy/ssh-action@master
        with:
          host: 192.168.0.180
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/dokploy/projects/myapp
            export VERSION=${{ steps.version.outputs.version }}

            # Blue-green deployment
            docker compose -f docker-compose.prod.yml pull myapp
            docker compose -f docker-compose.prod.yml up -d --no-deps --scale myapp=2 myapp
            sleep 30

            # Health check new instance
            curl -f http://localhost:8080/health || exit 1

            # Remove old instance
            docker compose -f docker-compose.prod.yml up -d --no-deps --scale myapp=1 myapp

      - name: Production health check
        run: |
          sleep 60
          curl -f https://myapp.aglz.io/health || exit 1

      - name: Run production smoke tests
        run: npm run test:smoke -- --env=production

      - name: Create GitHub release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: v${{ steps.version.outputs.version }}
          release_name: Release v${{ steps.version.outputs.version }}
          body_path: CHANGELOG.md

      - name: Notify team
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Production deployment v${{ steps.version.outputs.version }} completed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

**Quality Gates**:
- ✅ UAT sign-off documented
- ✅ Backup created successfully
- ✅ Blue-green deployment succeeds
- ✅ Health checks pass
- ✅ Smoke tests pass
- ✅ Rollback procedure validated

---

## 🏷️ Harbor Image Tagging Strategy

### Tagging Convention

```
harbor.aglz.io/<project>/<image>:<version>-<environment>

Examples:
- harbor.aglz.io/dev/myapp:latest
- harbor.aglz.io/dev/myapp:abc123def
- harbor.aglz.io/qa/myapp:1.2.3-qa
- harbor.aglz.io/uat/myapp:1.2.3-uat
- harbor.aglz.io/prod/myapp:1.2.3
- harbor.aglz.io/prod/myapp:latest
```

### Tag Lifecycle

| Tag | Purpose | Retention | Immutable |
|-----|---------|-----------|-----------|
| `latest` | Most recent build | Forever | No |
| `<commit-sha>` | Specific commit | 90 days | Yes |
| `<version>-dev` | Development build | 30 days | No |
| `<version>-qa` | QA tested build | 60 days | Yes |
| `<version>-uat` | UAT approved build | 90 days | Yes |
| `<version>` | Production release | Forever | Yes |

### Harbor Projects

```
harbor.aglz.io
├── dev/          (Public, auto-scan)
│   ├── myapp
│   ├── api
│   └── worker
├── qa/           (Private, auto-scan)
│   ├── myapp
│   ├── api
│   └── worker
├── uat/          (Private, auto-scan, immutable)
│   ├── myapp
│   ├── api
│   └── worker
└── prod/         (Private, auto-scan, immutable, signed)
    ├── myapp
    ├── api
    └── worker
```

---

## 🔄 Rollback Procedures

### Automated Rollback Triggers

**Trigger rollback when**:
- Health check fails for > 5 minutes
- Error rate > 5% for > 2 minutes
- Response time > 2x baseline for > 3 minutes
- Critical alerts fired

### Rollback Workflow

```yaml
name: Emergency Rollback
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - production
          - uat
          - qa
      target_version:
        description: 'Version to rollback to'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}

    steps:
      - name: Validate rollback target
        run: |
          echo "Rolling back ${{ github.event.inputs.environment }} to version ${{ github.event.inputs.target_version }}"

      - name: Execute rollback
        uses: appleboy/ssh-action@master
        with:
          host: ${{ env.DEPLOY_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/dokploy/projects/myapp
            export VERSION=${{ github.event.inputs.target_version }}
            docker compose -f docker-compose.${{ github.event.inputs.environment }}.yml pull
            docker compose -f docker-compose.${{ github.event.inputs.environment }}.yml up -d

      - name: Verify rollback
        run: |
          sleep 30
          curl -f https://${{ github.event.inputs.environment }}.myapp.aglz.io/health || exit 1

      - name: Create incident report
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[INCIDENT] Rollback executed: ${{ github.event.inputs.environment }} to v${{ github.event.inputs.target_version }}`,
              body: 'Automated rollback was triggered. Investigation required.',
              labels: ['incident', 'rollback', ${{ github.event.inputs.environment }}]
            })
```

---

## 📊 Pipeline Metrics

### Key Performance Indicators

| Metric | Target | Measurement |
|--------|--------|-------------|
| Build Time | < 10 minutes | From trigger to image pushed |
| Test Suite Time | < 15 minutes | All tests combined |
| Deploy Time (dev) | < 2 minutes | Image pull + container start |
| Deploy Time (prod) | < 5 minutes | Blue-green deployment |
| Pipeline Success Rate | > 95% | Successful builds / total builds |
| Mean Time to Deploy (MTTD) | < 30 minutes | Commit to production |
| Mean Time to Recovery (MTTR) | < 15 minutes | Incident to rollback complete |

### Monitoring Dashboards

**Grafana Dashboards**:
1. **Pipeline Overview**
   - Build success rate
   - Average build duration
   - Deploy frequency per environment
   - Failed builds by stage

2. **Quality Metrics**
   - Test coverage trends
   - Security vulnerabilities over time
   - Code quality scores
   - Technical debt

3. **Deployment Health**
   - Deployment success rate
   - Rollback frequency
   - Downtime incidents
   - SLA compliance

---

## 🔐 Security in Pipeline

### Secret Management

**GitHub Secrets** (stored):
- `HARBOR_USERNAME` - Harbor registry user
- `HARBOR_PASSWORD` - Harbor registry password
- `SSH_PRIVATE_KEY` - Deployment SSH key
- `SLACK_WEBHOOK` - Notification webhook
- `SENTRY_DSN` - Error tracking
- `NPM_TOKEN` - Private package registry

**Dokploy Secrets** (runtime):
- Database credentials
- API keys
- OAuth secrets
- Encryption keys

### Security Scanning Layers

1. **Dependency Scanning** (npm audit)
   - Runs on every commit
   - Fails on high/critical vulnerabilities

2. **SAST** (Static Application Security Testing)
   - Code analysis for security patterns
   - Runs on PR creation

3. **Container Scanning** (Trivy)
   - Scans Docker images
   - Fails on critical CVEs

4. **Harbor Scanning**
   - Automatic scan on image push
   - Quarantine policy for critical vulnerabilities

5. **DAST** (Dynamic Application Security Testing)
   - Runs against QA environment
   - Automated penetration testing

---

## 🚨 Alerting and Notifications

### Notification Channels

| Event | Channel | Recipients |
|-------|---------|------------|
| Build failed | Slack + Email | Developer |
| Deploy started | Slack | Team channel |
| Deploy completed | Slack | Team channel |
| Production deploy | Slack + Email | All team + Leads |
| Rollback triggered | Slack + PagerDuty | On-call team |
| Security vulnerability | Email + Jira | Security team |

### Alert Severities

**P1 (Critical)**:
- Production build failure
- Production deployment failure
- Automated rollback triggered
- Security breach detected

**P2 (High)**:
- QA/UAT build failure
- Test coverage drop > 10%
- High severity vulnerability found

**P3 (Medium)**:
- Dev build failure
- Deprecated dependencies
- Performance degradation

**P4 (Low)**:
- Documentation out of date
- Code quality score decline
- Minor linting issues

---

## 🔧 Pipeline Optimization

### Caching Strategy

**Docker Build Cache**:
```dockerfile
# Use BuildKit cache mounts
RUN --mount=type=cache,target=/root/.npm \
    npm ci --production

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**GitHub Actions Cache**:
```yaml
- uses: actions/cache@v3
  with:
    path: |
      ~/.npm
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

### Parallel Execution

```yaml
jobs:
  tests:
    strategy:
      matrix:
        test-type: [unit, integration, e2e]
    runs-on: ubuntu-latest
    steps:
      - name: Run ${{ matrix.test-type }} tests
        run: npm run test:${{ matrix.test-type }}
```

### Resource Optimization

- Use smaller base images (alpine)
- Multi-stage Docker builds
- Prune unused layers
- Optimize test data fixtures
- Parallel test execution

---

## 📋 Implementation Checklist

### Phase 1: Foundation (Week 1)
- [ ] Create GitHub Actions workflows
- [ ] Configure Harbor projects and policies
- [ ] Set up GitHub Secrets
- [ ] Configure Dokploy instances
- [ ] Implement basic build pipeline

### Phase 2: Quality Gates (Week 2)
- [ ] Add unit test automation
- [ ] Implement security scanning
- [ ] Configure code coverage
- [ ] Set up integration tests
- [ ] Add performance benchmarks

### Phase 3: Deployment (Week 3)
- [ ] Configure dev environment auto-deploy
- [ ] Implement QA deployment
- [ ] Set up UAT deployment
- [ ] Configure production deployment
- [ ] Test rollback procedures

### Phase 4: Monitoring (Week 4)
- [ ] Set up Grafana dashboards
- [ ] Configure alerting rules
- [ ] Implement notification channels
- [ ] Create runbooks
- [ ] Train team on workflows

---

## 🔗 Related Documents

- **[Branching Strategy](./01-branching-strategy.md)** - Git workflow
- **[Environment Configuration](./03-environment-config.md)** - Environment setup
- **[Workflow Optimization](./04-workflow-optimization.md)** - Process improvements

---

**Document Owner**: DevOps Team
**Last Review**: 2025-10-28
**Next Review**: 2025-11-28
**Status**: Draft - Pending Implementation
