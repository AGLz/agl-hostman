# CI/CD Integration Guide

Complete guide for integrating integration tests into your CI/CD pipeline.

## 🎯 Overview

This guide covers integration test automation for:
- GitHub Actions
- GitLab CI
- Jenkins
- Docker-based CI
- Dokploy deployment pipeline

## 🚀 GitHub Actions

### Basic Workflow

Create `.github/workflows/integration-tests.yml`:

```yaml
name: Integration Tests

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

jobs:
  integration-tests:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x]

    services:
      docker:
        image: docker:dind
        options: --privileged

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run integration tests
        run: npm run test:integration
        env:
          NODE_ENV: test
          CI: true

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/integration/lcov.info
          flags: integration
          name: integration-coverage

      - name: Archive test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: |
            coverage/
            tests/integration/artifacts/
```

### Advanced Workflow with Caching

```yaml
name: Integration Tests (Cached)

on: [pull_request, push]

jobs:
  integration-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Cache node modules
        uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      - name: Cache Docker images
        uses: actions/cache@v3
        with:
          path: /tmp/docker-cache
          key: ${{ runner.os }}-docker-${{ hashFiles('**/Dockerfile') }}

      - run: npm ci
      - run: npm run test:integration

      - name: Generate coverage badge
        if: github.ref == 'refs/heads/main'
        run: |
          npm install -g coverage-badge-creator
          coverage-badge-creator \
            --file coverage/integration/coverage-summary.json \
            --output badges/integration-coverage.svg
```

### Matrix Testing (Multi-Environment)

```yaml
name: Integration Tests Matrix

on: [pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}

    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, ubuntu-20.04]
        node: [18, 20]
        include:
          - os: ubuntu-latest
            node: 18
            experimental: false
          - os: ubuntu-latest
            node: 20
            experimental: true

    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node }}

      - run: npm ci
      - run: npm run test:integration
        continue-on-error: ${{ matrix.experimental }}
```

## 🦊 GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - test
  - report

variables:
  NODE_ENV: test
  DOCKER_DRIVER: overlay2

integration-tests:
  stage: test
  image: node:18
  services:
    - docker:dind

  before_script:
    - npm ci

  script:
    - npm run lint
    - npm run test:integration

  coverage: '/Statements\s*:\s*(\d+\.?\d*)%/'

  artifacts:
    when: always
    paths:
      - coverage/integration/
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/integration/cobertura-coverage.xml
      junit:
        - coverage/integration/junit.xml

  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/
      - .npm/

coverage-report:
  stage: report
  image: node:18
  dependencies:
    - integration-tests

  script:
    - npm install -g lcov-result-merger
    - lcov-result-merger 'coverage/**/lcov.info' coverage/merged-lcov.info

  coverage: '/Statements\s*:\s*(\d+\.?\d*)%/'

  only:
    - main
    - develop
```

## 🔨 Jenkins

Create `Jenkinsfile`:

```groovy
pipeline {
    agent {
        docker {
            image 'node:18'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        NODE_ENV = 'test'
        CI = 'true'
    }

    stages {
        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Integration Tests') {
            steps {
                sh 'npm run test:integration'
            }
            post {
                always {
                    junit 'coverage/integration/junit.xml'

                    publishHTML([
                        reportDir: 'coverage/integration/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Integration Coverage Report'
                    ])
                }
            }
        }

        stage('Coverage Analysis') {
            steps {
                script {
                    def coverage = readJSON file: 'coverage/integration/coverage-summary.json'
                    def statements = coverage.total.statements.pct
                    def branches = coverage.total.branches.pct

                    echo "Statement Coverage: ${statements}%"
                    echo "Branch Coverage: ${branches}%"

                    if (statements < 80 || branches < 80) {
                        error("Coverage below threshold: Statements=${statements}%, Branches=${branches}%")
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'coverage/**/*', allowEmptyArchive: true
            cleanWs()
        }

        success {
            echo 'Integration tests passed!'
        }

        failure {
            echo 'Integration tests failed!'
            emailext(
                subject: "Integration Tests Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
    }
}
```

## 🐳 Docker-based CI

### Dockerfile for Testing

Create `docker/test/Dockerfile`:

```dockerfile
FROM node:18-alpine

# Install Docker CLI
RUN apk add --no-cache docker-cli

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Run tests
CMD ["npm", "run", "test:integration"]
```

### Docker Compose for CI

Create `docker-compose.test.yml`:

```yaml
version: '3.8'

services:
  integration-tests:
    build:
      context: .
      dockerfile: docker/test/Dockerfile
    environment:
      - NODE_ENV=test
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./coverage:/app/coverage
    networks:
      - test-network

  mock-proxmox:
    image: mockserver/mockserver:latest
    ports:
      - "8006:1080"
    environment:
      - MOCKSERVER_INITIALIZATION_JSON_PATH=/config/proxmox-mock.json
    volumes:
      - ./tests/integration/mocks/proxmox-config.json:/config/proxmox-mock.json
    networks:
      - test-network

networks:
  test-network:
    driver: bridge
```

### Run CI Tests

```bash
# Build and run tests
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit

# Cleanup
docker-compose -f docker-compose.test.yml down -v
```

## 📦 Dokploy Integration

### Pre-deployment Tests

Create `.dokploy/hooks/pre-deploy.sh`:

```bash
#!/bin/bash
set -e

echo "Running integration tests before deployment..."

# Install dependencies
npm ci

# Run tests
npm run test:integration

# Check coverage
COVERAGE=$(node -e "console.log(require('./coverage/integration/coverage-summary.json').total.statements.pct)")

if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "Coverage below 80% ($COVERAGE%). Deployment blocked."
    exit 1
fi

echo "Integration tests passed! Coverage: $COVERAGE%"
```

### Post-deployment Smoke Tests

Create `.dokploy/hooks/post-deploy.sh`:

```bash
#!/bin/bash
set -e

echo "Running smoke tests after deployment..."

# Wait for service to be ready
timeout 60 bash -c 'until curl -s http://localhost:3000/health > /dev/null; do sleep 2; done'

# Run smoke tests
npm run test:smoke

echo "Smoke tests passed!"
```

### Dokploy Configuration

Create `.dokploy/config.yml`:

```yaml
version: '1'

project:
  name: agl-hostman
  environment: production

build:
  dockerfile: docker/production/Dockerfile
  context: .
  args:
    NODE_ENV: production

deploy:
  strategy: rolling
  replicas: 2
  healthcheck:
    path: /health
    interval: 30s
    timeout: 10s
    retries: 3

hooks:
  pre-deploy:
    - .dokploy/hooks/pre-deploy.sh
  post-deploy:
    - .dokploy/hooks/post-deploy.sh

environments:
  dev:
    auto-deploy: true
    branch: develop
  qa:
    auto-deploy: false
    branch: release/*
  uat:
    auto-deploy: false
    branch: main
  prod:
    auto-deploy: false
    branch: production
```

## 🔄 Multi-Environment Testing

### Environment-Specific Tests

```bash
# Development
NODE_ENV=development npm run test:integration

# QA
NODE_ENV=qa npm run test:integration

# UAT
NODE_ENV=uat npm run test:integration

# Production (smoke tests only)
NODE_ENV=production npm run test:smoke
```

### Environment Configuration

Create `tests/integration/config/`:

```javascript
// tests/integration/config/environments.js
module.exports = {
  development: {
    timeout: 30000,
    proxmoxHost: 'dev-proxmox.test',
    skipDockerTests: false,
  },
  qa: {
    timeout: 20000,
    proxmoxHost: 'qa-proxmox.test',
    skipDockerTests: false,
  },
  uat: {
    timeout: 15000,
    proxmoxHost: 'uat-proxmox.test',
    skipDockerTests: true,
  },
  production: {
    timeout: 10000,
    proxmoxHost: 'proxmox.prod',
    skipDockerTests: true,
    smokeTestsOnly: true,
  },
};
```

## 📊 Coverage Integration

### Codecov

```yaml
# .codecov.yml
coverage:
  status:
    project:
      default:
        target: 80%
        threshold: 2%
    patch:
      default:
        target: 80%

  flags:
    integration:
      paths:
        - src/
      target: 80%

comment:
  require_changes: true
  behavior: default
  layout: "reach, diff, flags, files"
```

### Coveralls

```yaml
# .coveralls.yml
service_name: github-actions
repo_token: ${{ secrets.COVERALLS_TOKEN }}

coverage_clover: coverage/integration/clover.xml
json_path: coverage/integration/coveralls.json
```

### SonarQube

```properties
# sonar-project.properties
sonar.projectKey=agl-hostman
sonar.sources=src
sonar.tests=tests
sonar.javascript.lcov.reportPaths=coverage/integration/lcov.info
sonar.testExecutionReportPaths=coverage/integration/test-report.xml
```

## 🔔 Notifications

### Slack Integration

```yaml
# GitHub Actions
- name: Notify Slack on Failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Integration tests failed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Email Notifications

```yaml
# GitLab CI
after_script:
  - |
    if [ "$CI_JOB_STATUS" == "failed" ]; then
      echo "Integration tests failed" | mail -s "CI Failure" team@example.com
    fi
```

## 📈 Performance Monitoring

### Test Duration Tracking

```bash
# Add to CI script
START_TIME=$(date +%s)
npm run test:integration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Integration tests took ${DURATION} seconds"

# Alert if too slow
if [ $DURATION -gt 300 ]; then
  echo "Warning: Tests took longer than 5 minutes!"
fi
```

### Resource Monitoring

```bash
# Monitor memory usage during tests
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  > test-resources.log &

STATS_PID=$!
npm run test:integration
kill $STATS_PID
```

## 🐛 Troubleshooting

### Common CI Issues

#### 1. Docker Socket Permission Denied

```yaml
# Solution: Add docker group
services:
  docker:
    image: docker:dind
    options: --privileged

steps:
  - run: sudo usermod -aG docker $USER
```

#### 2. Timeout Issues

```yaml
# Increase timeouts
environment:
  JEST_TIMEOUT: 60000
```

#### 3. Flaky Tests

```bash
# Run tests multiple times
npm run test:integration -- --maxWorkers=1 --runInBand
```

## 📚 Best Practices

1. **Run tests on every PR** - Catch issues early
2. **Cache dependencies** - Speed up CI runs
3. **Parallel execution** - Faster test completion
4. **Fail fast** - Stop on first failure
5. **Retry flaky tests** - Reduce false negatives
6. **Monitor trends** - Track coverage and performance
7. **Clean up resources** - Prevent resource leaks

## 🔗 Related Documentation

- [Integration Tests README](README.md)
- [Mock Data Documentation](MOCK-DATA.md)
- [Testing Strategy](../TESTING-DELIVERABLES-SUMMARY.md)

---

**Last Updated:** 2025-10-28
**Maintainer:** AGL Infrastructure Team
