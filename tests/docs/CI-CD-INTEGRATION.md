# CI/CD Test Integration Guide

> **Document Version**: 1.0.0
> **Last Updated**: 2025-10-28
> **Author**: Tester Agent - Hive Mind Collective

---

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Architecture](#pipeline-architecture)
3. [Test Gates](#test-gates)
4. [GitHub Actions Integration](#github-actions-integration)
5. [GitLab CI Integration](#gitlab-ci-integration)
6. [Test Execution](#test-execution)
7. [Reporting & Metrics](#reporting--metrics)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### Purpose
This document provides comprehensive guidance for integrating the AGL infrastructure testing framework into CI/CD pipelines.

### Supported CI/CD Platforms
- ✅ GitHub Actions (primary)
- ✅ GitLab CI/CD
- ✅ Jenkins (legacy support)
- ⏳ CircleCI (planned)

### Integration Goals
1. **Automated Testing**: Run tests on every commit/PR
2. **Fast Feedback**: Provide results in <10 minutes
3. **Quality Gates**: Enforce quality standards automatically
4. **Deployment Automation**: Automated environment promotion
5. **Metrics Collection**: Track test trends over time

---

## Pipeline Architecture

### Multi-Stage Pipeline

```
┌──────────────┐
│   Trigger    │  ← Push / PR / Manual
└──────┬───────┘
       │
┌──────▼───────┐
│  Lint & Validate  │  ← 2 min
└──────┬───────┘
       │
┌──────▼───────┐
│  Unit Tests  │  ← 3 min
└──────┬───────┘
       │
┌──────▼───────┐
│ Integration  │  ← 5 min
└──────┬───────┘
       │
┌──────▼───────┐
│  Security    │  ← 3 min
└──────┬───────┘
       │
┌──────▼───────┐
│  Deploy DEV  │  ← Auto if main/develop
└──────┬───────┘
       │
┌──────▼───────┐
│  Deploy QA   │  ← Auto if main
└──────┬───────┘
       │
┌──────▼───────┐
│  Deploy UAT  │  ← Manual approval
└──────┬───────┘
       │
┌──────▼───────┐
│Deploy PROD   │  ← Manual approval + canary
└──────────────┘
```

### Pipeline Stages

| Stage | Duration | Trigger | Blocker | Artifacts |
|-------|----------|---------|---------|-----------|
| Lint | 2 min | All commits | Yes | Lint reports |
| Unit Tests | 3 min | All commits | Yes | Coverage report |
| Integration | 5 min | All commits | Yes | Test results |
| Security | 3 min | All commits | Yes | Vulnerability report |
| Deploy DEV | 2 min | develop branch | No | Deployment log |
| Deploy QA | 3 min | main branch | Yes | Test report |
| Deploy UAT | 3 min | Manual | Yes | UAT report |
| Deploy PROD | 5 min | Manual | Yes | Deployment report |

---

## Test Gates

### Gate 1: Lint & Validate (Pre-Test)

**Purpose**: Catch syntax errors before testing
**Duration**: ~2 minutes
**Blocker**: Yes

```yaml
lint_and_validate:
  steps:
    - name: Shellcheck
      run: |
        find scripts -name "*.sh" -exec shellcheck {} \;

    - name: Hadolint (Dockerfile)
      run: |
        find . -name "Dockerfile*" -exec hadolint {} \;

    - name: YAML Lint
      run: |
        find . -name "*.yml" -o -name "*.yaml" | xargs yamllint

    - name: JSON Lint
      run: |
        find . -name "*.json" | xargs jsonlint

  failure_action: block_pipeline
```

### Gate 2: Unit Tests

**Purpose**: Validate individual components
**Duration**: ~3 minutes
**Coverage**: ≥80%

```yaml
unit_tests:
  steps:
    - name: Shell Unit Tests (bats)
      run: |
        bats tests/unit/**/*.bats --formatter junit > unit-tests.xml

    - name: Python Unit Tests
      run: |
        pytest tests/unit/python/ --cov --cov-report=xml --junitxml=pytest-results.xml

    - name: Coverage Check
      run: |
        coverage report --fail-under=80

  artifacts:
    - unit-tests.xml
    - pytest-results.xml
    - coverage.xml

  failure_action: block_pipeline
```

### Gate 3: Integration Tests

**Purpose**: Validate component interactions
**Duration**: ~5 minutes

```yaml
integration_tests:
  steps:
    - name: Start Test Environment
      run: |
        docker-compose -f docker-compose.test.yml up -d

    - name: Wait for Services
      run: |
        timeout 60 bash -c 'until docker-compose ps | grep -q healthy; do sleep 1; done'

    - name: Run Integration Tests
      run: |
        bash tests/integration/run-all.sh

    - name: Cleanup
      run: |
        docker-compose -f docker-compose.test.yml down

  failure_action: block_pipeline
```

### Gate 4: Security Scan

**Purpose**: Detect vulnerabilities
**Duration**: ~3 minutes

```yaml
security_scan:
  steps:
    - name: Container Vulnerability Scan
      run: |
        trivy image --severity HIGH,CRITICAL --exit-code 1 archon-mcp:latest

    - name: Secret Detection
      run: |
        trufflehog filesystem . --json > secrets-report.json

    - name: Dependency Audit
      run: |
        npm audit --audit-level=high

  failure_action: block_pipeline
  allow_warnings: true
```

---

## GitHub Actions Integration

### Complete Workflow File

```yaml
# .github/workflows/ci-cd-pipeline.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main, develop]
  workflow_dispatch:  # Manual trigger

env:
  DOCKER_REGISTRY: harbor.agl.local
  REGISTRY_USER: ${{ secrets.HARBOR_USER }}
  REGISTRY_PASSWORD: ${{ secrets.HARBOR_PASSWORD }}

jobs:
  # ═══════════════════════════════════════
  # Stage 1: Lint & Validate
  # ═══════════════════════════════════════
  lint:
    name: Lint & Validate
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Shellcheck
        run: |
          sudo apt-get install -y shellcheck
          find scripts -name "*.sh" -exec shellcheck {} \;

      - name: Hadolint (Dockerfile linting)
        uses: hadolint/hadolint-action@v3.1.0
        with:
          recursive: true

      - name: YAML Lint
        run: |
          pip install yamllint
          find . -name "*.yml" -o -name "*.yaml" | xargs yamllint

      - name: JSON Lint
        run: |
          npm install -g jsonlint
          find . -name "*.json" -exec jsonlint -q {} \;

  # ═══════════════════════════════════════
  # Stage 2: Unit Tests
  # ═══════════════════════════════════════
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: lint
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install bats
        run: |
          npm install -g bats

      - name: Run Shell Unit Tests
        run: |
          bats tests/unit/**/*.bats --formatter junit > unit-tests.xml

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install Python dependencies
        run: |
          pip install pytest pytest-cov

      - name: Run Python Unit Tests
        run: |
          pytest tests/unit/python/ \
            --cov \
            --cov-report=xml \
            --cov-report=html \
            --junitxml=pytest-results.xml

      - name: Check Code Coverage
        run: |
          coverage report --fail-under=80

      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
          flags: unittests

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: |
            unit-tests.xml
            pytest-results.xml
            htmlcov/

  # ═══════════════════════════════════════
  # Stage 3: Integration Tests
  # ═══════════════════════════════════════
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: unit-tests
    timeout-minutes: 15

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Start Test Environment
        run: |
          docker-compose -f docker-compose.test.yml up -d

      - name: Wait for Services
        run: |
          timeout 120 bash -c 'until docker-compose ps | grep -q healthy; do sleep 2; done'

      - name: Run Integration Tests
        run: |
          bash tests/integration/run-all.sh

      - name: Collect Logs (on failure)
        if: failure()
        run: |
          docker-compose -f docker-compose.test.yml logs > integration-logs.txt

      - name: Upload Logs
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: integration-logs
          path: integration-logs.txt

      - name: Cleanup
        if: always()
        run: |
          docker-compose -f docker-compose.test.yml down -v

  # ═══════════════════════════════════════
  # Stage 4: Security Scan
  # ═══════════════════════════════════════
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: unit-tests
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run Trivy Vulnerability Scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Secret Detection with Trufflehog
        run: |
          docker run --rm -v $(pwd):/repo \
            trufflesecurity/trufflehog:latest \
            filesystem /repo --json > secrets-report.json

      - name: Check for Secrets
        run: |
          if [ -s secrets-report.json ]; then
            echo "❌ Secrets detected!"
            cat secrets-report.json
            exit 1
          fi

      - name: npm Audit
        run: |
          if [ -f package.json ]; then
            npm audit --audit-level=high
          fi

  # ═══════════════════════════════════════
  # Stage 5: Build Docker Images
  # ═══════════════════════════════════════
  build:
    name: Build Docker Images
    runs-on: ubuntu-latest
    needs: [integration-tests, security-scan]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Harbor Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.DOCKER_REGISTRY }}
          username: ${{ env.REGISTRY_USER }}
          password: ${{ env.REGISTRY_PASSWORD }}

      - name: Build and Push Images
        run: |
          docker build -t ${DOCKER_REGISTRY}/agl/archon-mcp:${GITHUB_SHA} .
          docker push ${DOCKER_REGISTRY}/agl/archon-mcp:${GITHUB_SHA}

          # Tag as latest for main branch
          if [ "$GITHUB_REF" = "refs/heads/main" ]; then
            docker tag ${DOCKER_REGISTRY}/agl/archon-mcp:${GITHUB_SHA} \
              ${DOCKER_REGISTRY}/agl/archon-mcp:latest
            docker push ${DOCKER_REGISTRY}/agl/archon-mcp:latest
          fi

  # ═══════════════════════════════════════
  # Stage 6: Deploy to DEV
  # ═══════════════════════════════════════
  deploy-dev:
    name: Deploy to DEV (CT179)
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: development
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to DEV
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: 100.94.221.87  # CT179 Tailscale
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/agl-hostman
            git pull origin develop
            ./deploy.sh dev

      - name: Run DEV Smoke Tests
        run: |
          bash tests/smoke/dev-smoke-tests.sh

  # ═══════════════════════════════════════
  # Stage 7: Deploy to QA
  # ═══════════════════════════════════════
  deploy-qa:
    name: Deploy to QA (CT180)
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: qa
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to QA
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.QA_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/agl-hostman
            git pull origin main
            ./deploy.sh qa

      - name: Run QA Full Test Suite
        run: |
          bash tests/environments/qa/full-test-suite.sh

      - name: Performance Benchmarks
        run: |
          bash tests/performance/run-benchmarks.sh

  # ═══════════════════════════════════════
  # Stage 8: Deploy to UAT
  # ═══════════════════════════════════════
  deploy-uat:
    name: Deploy to UAT (CT181)
    runs-on: ubuntu-latest
    needs: deploy-qa
    environment: uat
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to UAT
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.UAT_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/agl-hostman
            git pull origin main
            ./deploy.sh uat

      - name: UAT Smoke Tests
        run: |
          bash tests/smoke/uat-smoke-tests.sh

      - name: Production Readiness Check
        run: |
          bash tests/environments/uat/production-readiness.sh

  # ═══════════════════════════════════════
  # Stage 9: Deploy to PRODUCTION
  # ═══════════════════════════════════════
  deploy-production:
    name: Deploy to PRODUCTION (CT182+)
    runs-on: ubuntu-latest
    needs: deploy-uat
    environment: production
    timeout-minutes: 20

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Canary Deployment (10%)
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/agl-hostman
            ./deploy.sh production --canary

      - name: Canary Validation (15 minutes)
        run: |
          bash tests/environments/prod/canary-validation.sh --duration 900

      - name: Full Production Rollout
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/agl-hostman
            ./deploy.sh production --full

      - name: Production Smoke Tests
        run: |
          bash tests/smoke/production-smoke-tests.sh

      - name: Notify Operations Team
        if: always()
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "Production deployment ${{ job.status }}: ${{ github.event.head_commit.message }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## GitLab CI Integration

### Complete .gitlab-ci.yml

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - security
  - build
  - deploy-dev
  - deploy-qa
  - deploy-uat
  - deploy-prod

variables:
  DOCKER_REGISTRY: harbor.agl.local
  DOCKER_TLS_CERTDIR: "/certs"

# ═══════════════════════════════════════
# Lint Stage
# ═══════════════════════════════════════
lint:shellcheck:
  stage: lint
  image: koalaman/shellcheck-alpine:latest
  script:
    - find scripts -name "*.sh" -exec shellcheck {} \;

lint:hadolint:
  stage: lint
  image: hadolint/hadolint:latest
  script:
    - find . -name "Dockerfile*" -exec hadolint {} \;

# ═══════════════════════════════════════
# Test Stage
# ═══════════════════════════════════════
test:unit:
  stage: test
  image: ubuntu:22.04
  before_script:
    - apt-get update && apt-get install -y bats python3-pip
    - pip3 install pytest pytest-cov
  script:
    - bats tests/unit/**/*.bats --formatter junit > unit-tests.xml
    - pytest tests/unit/python/ --cov --junitxml=pytest-results.xml
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      junit:
        - unit-tests.xml
        - pytest-results.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

test:integration:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker-compose -f docker-compose.test.yml up -d
    - timeout 120 bash -c 'until docker-compose ps | grep -q healthy; do sleep 2; done'
    - bash tests/integration/run-all.sh
  after_script:
    - docker-compose -f docker-compose.test.yml down -v

# ═══════════════════════════════════════
# Security Stage
# ═══════════════════════════════════════
security:trivy:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs --severity HIGH,CRITICAL --exit-code 1 .

security:secrets:
  stage: security
  image: trufflesecurity/trufflehog:latest
  script:
    - trufflehog filesystem . --json > secrets-report.json
    - test ! -s secrets-report.json

# ═══════════════════════════════════════
# Build Stage
# ═══════════════════════════════════════
build:docker:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $DOCKER_REGISTRY
  script:
    - docker build -t ${DOCKER_REGISTRY}/agl/archon-mcp:${CI_COMMIT_SHA} .
    - docker push ${DOCKER_REGISTRY}/agl/archon-mcp:${CI_COMMIT_SHA}
  only:
    - main
    - develop

# ═══════════════════════════════════════
# Deploy Stages
# ═══════════════════════════════════════
deploy:dev:
  stage: deploy-dev
  environment:
    name: development
  script:
    - ssh root@100.94.221.87 'cd /root/agl-hostman && git pull && ./deploy.sh dev'
    - bash tests/smoke/dev-smoke-tests.sh
  only:
    - develop

deploy:qa:
  stage: deploy-qa
  environment:
    name: qa
  script:
    - ssh root@$QA_HOST 'cd /root/agl-hostman && git pull && ./deploy.sh qa'
    - bash tests/environments/qa/full-test-suite.sh
  only:
    - main

deploy:uat:
  stage: deploy-uat
  environment:
    name: uat
  when: manual
  script:
    - ssh root@$UAT_HOST 'cd /root/agl-hostman && git pull && ./deploy.sh uat'
    - bash tests/smoke/uat-smoke-tests.sh
  only:
    - main

deploy:production:
  stage: deploy-prod
  environment:
    name: production
  when: manual
  script:
    - ssh root@$PROD_HOST 'cd /root/agl-hostman && ./deploy.sh production --canary'
    - bash tests/environments/prod/canary-validation.sh --duration 900
    - ssh root@$PROD_HOST 'cd /root/agl-hostman && ./deploy.sh production --full'
    - bash tests/smoke/production-smoke-tests.sh
  only:
    - main
```

---

## Test Execution

### Parallel Test Execution

```yaml
# Run tests in parallel for faster feedback
test:parallel:
  strategy:
    matrix:
      test_suite:
        - unit/scripts
        - unit/python
        - integration/docker
        - integration/network
        - integration/storage
  script:
    - bash tests/${test_suite}/run-tests.sh
```

### Caching Strategy

```yaml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - .pip-cache/
    - .bats-cache/
```

---

## Reporting & Metrics

### Test Result Publishing

```yaml
- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: |
      **/test-results/**/*.xml
```

### Code Coverage Reporting

```yaml
- name: Code Coverage Report
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    flags: unittests
    name: codecov-umbrella
```

### Slack Notifications

```yaml
- name: Slack Notification
  uses: slackapi/slack-github-action@v1.24.0
  with:
    payload: |
      {
        "text": "Pipeline ${{ job.status }}: ${{ github.event.head_commit.message }}",
        "attachments": [{
          "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
          "fields": [
            {"title": "Branch", "value": "${{ github.ref_name }}", "short": true},
            {"title": "Commit", "value": "${{ github.sha }}", "short": true}
          ]
        }]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Troubleshooting

### Common Issues

#### Issue: Tests Timeout in CI

**Solution**:
```yaml
# Increase timeout
timeout-minutes: 20

# Or optimize tests
script:
  - bash tests/run-tests.sh --fail-fast --parallel
```

#### Issue: Flaky Integration Tests

**Solution**:
```bash
# Add retries for flaky tests
pytest tests/integration/ --reruns 3 --reruns-delay 5
```

#### Issue: CI Environment Differences

**Solution**:
```yaml
# Use Docker for consistent environment
services:
  docker:
    image: docker:dind

script:
  - docker run --rm -v $(pwd):/workspace test-runner:latest
```

---

## Related Documentation

- **[COMPREHENSIVE-TEST-STRATEGY.md](./COMPREHENSIVE-TEST-STRATEGY.md)** - Overall testing strategy
- **[ENVIRONMENT-TEST-PLANS.md](./ENVIRONMENT-TEST-PLANS.md)** - Environment-specific plans
- **[DOCKER-TESTING-GUIDE.md](./DOCKER-TESTING-GUIDE.md)** - Docker testing guide

---

**Document Status**: ✅ Complete
**Maintained by**: Tester Agent - Hive Mind Collective
**Version**: 1.0.0
