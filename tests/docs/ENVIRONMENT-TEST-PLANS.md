# Environment-Specific Test Plans

> **Document Version**: 1.0.0
> **Last Updated**: 2025-10-28
> **Author**: Tester Agent - Hive Mind Collective

---

## Table of Contents

1. [Development Environment (DEV)](#development-environment-dev)
2. [QA Environment (QA)](#qa-environment-qa)
3. [UAT Environment (UAT)](#uat-environment-uat)
4. [Production Environment (PROD)](#production-environment-prod)
5. [Test Data Management](#test-data-management)
6. [Environment Promotion](#environment-promotion)

---

## Development Environment (DEV)

### Environment Details

**Container**: CT179 (agldv03)
**Purpose**: Rapid development and initial testing
**Network**: Triple-stack (LAN + WireGuard + Tailscale)
**Resources**: 48GB RAM, full Docker support

### Test Strategy

#### Fast Feedback Focus
- Unit tests run on file save (watch mode)
- Immediate feedback for developers
- Extensive debugging capabilities
- Quick iteration cycles

### Test Plan

#### 1. Unit Testing

**Frequency**: On every file save / commit
**Coverage Target**: 100% of changed files
**Timeout**: 5 seconds per test
**Tools**: bats-core, pytest, jest

**Test Suite**:
```bash
# tests/environments/dev/unit-tests.sh
#!/bin/bash

echo "🧪 DEV Environment - Unit Test Suite"

# Run all unit tests
bats tests/unit/**/*.bats --tap

# Python unit tests
pytest tests/unit/python/ -v --cov

# Node.js unit tests (if applicable)
npm test -- --coverage
```

#### 2. Local Docker Tests

**Frequency**: After code changes affecting containers
**Scope**: Local docker-compose stack
**Timeout**: 30 seconds

**Test Script**:
```bash
# tests/environments/dev/local-docker-test.sh
#!/bin/bash

echo "🐳 DEV - Local Docker Testing"

# Start local stack
docker-compose -f docker-compose.dev.yml up -d

# Wait for health
for service in $(docker-compose config --services); do
  echo "Waiting for $service..."
  timeout 30 bash -c "until docker-compose ps $service | grep -q healthy; do sleep 1; done"
done

# Run basic smoke tests
curl -f http://localhost:8080/health || exit 1

echo "✅ Local Docker stack healthy"
```

#### 3. Script Validation

**Frequency**: Pre-commit hook
**Scope**: All shell scripts
**Tools**: shellcheck, shfmt

```bash
# tests/environments/dev/script-validation.sh
#!/bin/bash

echo "📝 DEV - Script Validation"

# Shellcheck all scripts
find scripts -name "*.sh" -exec shellcheck {} \;

# Format check
find scripts -name "*.sh" -exec shfmt -d {} \;

echo "✅ All scripts valid"
```

### DEV Quality Gates

| Gate | Requirement | Blocker |
|------|------------|---------|
| Unit Tests | All pass | Yes |
| Linting | No errors | Yes |
| Build | Succeeds | Yes |
| Local Docker | Containers start | No |

### DEV Test Execution

```bash
# Quick test (pre-commit)
./tests/environments/dev/quick-test.sh

# Full dev test suite
./tests/environments/dev/full-test-suite.sh

# Watch mode (continuous testing)
./tests/environments/dev/watch-mode.sh
```

---

## QA Environment (QA)

### Environment Details

**Container**: CT180 (dedicated QA)
**Purpose**: Comprehensive testing and validation
**Network**: Isolated QA VLAN
**Resources**: 8GB RAM, production-like configuration

### Test Strategy

#### Comprehensive Coverage
- Full test suite execution
- Performance benchmarking
- Security scanning
- Integration testing

### Test Plan

#### 1. Full Test Suite

**Frequency**: On deployment to QA
**Coverage Target**: 80%+ code coverage
**Timeout**: 30 minutes
**Tools**: Full test framework

```bash
# tests/environments/qa/full-test-suite.sh
#!/bin/bash
set -e

echo "🔬 QA Environment - Full Test Suite"

# 1. Unit Tests
echo "Running unit tests..."
bats tests/unit/**/*.bats
pytest tests/unit/python/ --cov --cov-report=html

# 2. Integration Tests
echo "Running integration tests..."
bash tests/integration/run-all.sh

# 3. E2E Tests
echo "Running E2E tests..."
bash tests/e2e/qa-scenarios.sh

# 4. Security Scans
echo "Running security scans..."
bash tests/security/full-scan.sh

# 5. Performance Tests
echo "Running performance benchmarks..."
bash tests/performance/run-benchmarks.sh

echo "✅ QA Full Test Suite Complete"
```

#### 2. Integration Testing

**Scope**: All system integrations
**Duration**: 10-15 minutes

```bash
# tests/environments/qa/integration-tests.sh
#!/bin/bash

echo "🔗 QA - Integration Tests"

# Docker container integration
bash tests/integration/docker/container-interactions.sh

# NFS storage integration
bash tests/integration/storage/nfs-operations.sh

# WireGuard network integration
bash tests/integration/network/wireguard-connectivity.sh

# Archon MCP integration
bash tests/integration/archon/mcp-operations.sh

# Database integration
bash tests/integration/database/postgres-operations.sh

echo "✅ All integration tests passed"
```

#### 3. Performance Benchmarks

**Frequency**: Weekly + on deployment
**Baseline Comparison**: ±10% tolerance

```bash
# tests/environments/qa/performance-benchmarks.sh
#!/bin/bash

echo "⚡ QA - Performance Benchmarks"

# Container startup time
measure_startup_time() {
  start=$(date +%s)
  docker-compose up -d
  end=$(date +%s)
  echo "Startup time: $((end - start))s"
}

# Script execution time
measure_script_time() {
  script="$1"
  time bash "$script" &>/dev/null
}

# API response time
measure_api_response() {
  endpoint="$1"
  time curl -s "$endpoint" &>/dev/null
}

# Run all benchmarks
measure_startup_time
measure_script_time "scripts/discover-vps-hosts.sh"
measure_api_response "http://10.6.0.21:8051/mcp"

echo "✅ Performance benchmarks complete"
```

#### 4. Security Validation

**Frequency**: On every deployment
**Scope**: Complete security audit

```bash
# tests/environments/qa/security-validation.sh
#!/bin/bash

echo "🔒 QA - Security Validation"

# 1. Container vulnerability scanning
trivy image --severity HIGH,CRITICAL archon-mcp:latest

# 2. Secret detection
trufflehog filesystem . --json

# 3. Configuration audit
docker-bench-security

# 4. SSL/TLS validation
bash tests/security/tls-validation.sh 10.6.0.21 8051

# 5. Access control tests
pytest tests/security/test_access_control.py -v

echo "✅ Security validation complete"
```

### QA Quality Gates

| Gate | Requirement | Blocker |
|------|------------|---------|
| Unit Tests | 100% pass | Yes |
| Integration Tests | 100% pass | Yes |
| Code Coverage | ≥80% | Yes |
| Performance | Within ±10% baseline | Yes |
| Security | No high/critical vulns | Yes |
| E2E Tests | ≥95% pass | Yes |

### QA Test Execution

```bash
# Standard QA deployment test
./tests/environments/qa/deployment-test.sh

# Full QA validation
./tests/environments/qa/full-validation.sh

# QA regression suite
./tests/environments/qa/regression-suite.sh
```

---

## UAT Environment (UAT)

### Environment Details

**Container**: CT181 (staging)
**Purpose**: User acceptance and production readiness
**Network**: Production-identical VLAN
**Resources**: 16GB RAM, production parity

### Test Strategy

#### User Acceptance Focus
- Business-critical workflows
- Stakeholder validation
- Production readiness
- Rollback testing

### Test Plan

#### 1. User Acceptance Tests

**Frequency**: Before production promotion
**Duration**: 1-2 days
**Stakeholders**: Infrastructure admins, operations team

```yaml
# tests/environments/uat/user-acceptance-tests.yaml
test_scenarios:
  - name: "Container Deployment Workflow"
    description: "Complete container deployment from start to finish"
    steps:
      - Create container configuration
      - Deploy via automation
      - Verify services start
      - Validate monitoring
      - Test rollback procedure
    acceptance_criteria:
      - Deployment completes in <10 minutes
      - All services healthy
      - Monitoring shows correct metrics
      - Rollback restores previous state

  - name: "Configuration Update Workflow"
    description: "Update running container configuration"
    steps:
      - Modify configuration file
      - Apply changes via automation
      - Verify service restart
      - Validate new configuration
      - Test service continuity
    acceptance_criteria:
      - Update completes without downtime
      - Configuration applied correctly
      - Services remain healthy
      - No data loss occurs

  - name: "Incident Response Workflow"
    description: "Respond to simulated production incident"
    steps:
      - Simulate service failure
      - Receive monitoring alert
      - Execute incident response
      - Validate recovery procedures
      - Document resolution steps
    acceptance_criteria:
      - Alert received within 1 minute
      - Service restored within 15 minutes
      - Root cause identified
      - Documentation complete
```

#### 2. Production Readiness Tests

**Scope**: Production deployment validation
**Duration**: 2-3 hours

```bash
# tests/environments/uat/production-readiness.sh
#!/bin/bash

echo "🚀 UAT - Production Readiness Tests"

# 1. Configuration parity check
echo "Checking configuration parity..."
diff -r /etc/config/uat /etc/config/prod || {
  echo "⚠️  Configuration differences detected"
  exit 1
}

# 2. Certificate validation
echo "Validating certificates..."
openssl s_client -connect uat-host:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -dates

# 3. Backup system check
echo "Validating backup systems..."
bash scripts/verify_backup_system.sh

# 4. Monitoring integration
echo "Validating monitoring integration..."
curl -f http://monitoring-host/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="uat")'

# 5. Rollback plan validation
echo "Testing rollback plan..."
bash tests/environments/uat/rollback-test.sh

echo "✅ Production readiness validated"
```

#### 3. Smoke Tests

**Frequency**: Before and after deployment
**Duration**: 5 minutes
**Scope**: Critical paths only

```bash
# tests/environments/uat/smoke-tests.sh
#!/bin/bash

echo "💨 UAT - Smoke Tests"

# Test critical endpoints
critical_endpoints=(
  "http://uat-host:8080/health"
  "http://uat-host:8080/api/v1/status"
  "http://10.6.0.21:8051/mcp"
)

for endpoint in "${critical_endpoints[@]}"; do
  echo "Testing $endpoint..."
  curl -f -s -o /dev/null "$endpoint" || {
    echo "❌ $endpoint failed"
    exit 1
  }
done

# Test database connectivity
psql -h uat-db -U app -c "SELECT 1" >/dev/null || {
  echo "❌ Database connection failed"
  exit 1
}

# Test NFS mounts
mountpoint -q /mnt/pve/fgsrv6-wg || {
  echo "❌ NFS mount failed"
  exit 1
}

echo "✅ UAT smoke tests passed"
```

### UAT Quality Gates

| Gate | Requirement | Blocker |
|------|------------|---------|
| Smoke Tests | 100% pass | Yes |
| User Acceptance | All criteria met | Yes |
| Production Readiness | All checks pass | Yes |
| Rollback Test | Successful | Yes |
| Stakeholder Sign-off | Approved | Yes |

### UAT Test Execution

```bash
# UAT smoke tests
./tests/environments/uat/smoke-tests.sh

# User acceptance test suite
./tests/environments/uat/user-acceptance-suite.sh

# Production readiness check
./tests/environments/uat/production-readiness.sh

# Rollback validation
./tests/environments/uat/rollback-test.sh
```

---

## Production Environment (PROD)

### Environment Details

**Containers**: Multiple production instances
**Purpose**: Live production workloads
**Network**: Production VLANs (isolated)
**Resources**: Full production allocation

### Test Strategy

#### Minimal Impact Testing
- Quick smoke tests only
- Continuous monitoring
- Canary deployments
- Immediate rollback capability

### Test Plan

#### 1. Production Smoke Tests

**Frequency**: Immediately after deployment
**Duration**: 2 minutes maximum
**Scope**: Critical functionality only

```bash
# tests/environments/prod/smoke-tests.sh
#!/bin/bash
set -e

echo "💨 PRODUCTION - Smoke Tests"

START_TIME=$(date +%s)

# Test 1: Service health checks
for service in api database cache; do
  curl -f -s http://prod-host:8080/health/$service >/dev/null || {
    echo "❌ $service health check failed"
    exit 1
  }
done

# Test 2: Database connectivity
psql -h prod-db -U app -c "SELECT 1" >/dev/null 2>&1 || {
  echo "❌ Database connectivity failed"
  exit 1
}

# Test 3: API endpoint validation
curl -f -s http://prod-host:8080/api/v1/ping >/dev/null || {
  echo "❌ API endpoint failed"
  exit 1
}

# Test 4: External integrations
curl -f -s http://prod-host:8080/api/v1/integrations/status >/dev/null || {
  echo "❌ External integrations failed"
  exit 1
}

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $DURATION -gt 120 ]; then
  echo "⚠️  Smoke tests took ${DURATION}s (max: 120s)"
fi

echo "✅ Production smoke tests passed in ${DURATION}s"
```

#### 2. Canary Deployment Tests

**Strategy**: Gradual rollout with validation at each stage
**Rollout**: 10% → 50% → 100%

```bash
# tests/environments/prod/canary-deployment.sh
#!/bin/bash

echo "🐤 PRODUCTION - Canary Deployment"

# Stage 1: Deploy to 10% of instances
echo "Deploying to 10% canary..."
kubectl set image deployment/app app=app:new --replicas=1
sleep 60

# Validate canary (15 minutes)
echo "Validating canary for 15 minutes..."
for i in {1..90}; do
  # Check error rate
  error_rate=$(curl -s http://monitoring/api/v1/query?query=error_rate | jq '.data.result[0].value[1]')
  if (( $(echo "$error_rate > 0.01" | bc -l) )); then
    echo "❌ Canary error rate too high: $error_rate"
    kubectl rollout undo deployment/app
    exit 1
  fi

  # Check response time
  response_time=$(curl -s http://monitoring/api/v1/query?query=response_time_p95 | jq '.data.result[0].value[1]')
  if (( $(echo "$response_time > 500" | bc -l) )); then
    echo "❌ Canary response time too high: ${response_time}ms"
    kubectl rollout undo deployment/app
    exit 1
  fi

  sleep 10
done

echo "✅ Canary validated - proceeding to 50%"

# Stage 2: Deploy to 50%
kubectl scale deployment/app --replicas=5
sleep 300  # 5 minute validation

# Stage 3: Full deployment
kubectl scale deployment/app --replicas=10

echo "✅ Canary deployment complete"
```

#### 3. Synthetic Monitoring

**Frequency**: Every 5 minutes
**Purpose**: Continuous production validation

```python
# tests/environments/prod/synthetic-monitoring.py
import requests
import time
from prometheus_client import Gauge, push_to_gateway

# Metrics
response_time_gauge = Gauge('synthetic_response_time', 'Response time in ms')
availability_gauge = Gauge('synthetic_availability', 'Service availability')

def synthetic_check():
    """Run synthetic production check"""
    endpoints = [
        'http://prod-host:8080/health',
        'http://prod-host:8080/api/v1/ping',
        'http://10.6.0.21:8051/mcp'
    ]

    for endpoint in endpoints:
        start = time.time()
        try:
            response = requests.get(endpoint, timeout=5)
            duration = (time.time() - start) * 1000  # Convert to ms

            if response.status_code == 200:
                response_time_gauge.set(duration)
                availability_gauge.set(1)
            else:
                availability_gauge.set(0)

        except Exception as e:
            availability_gauge.set(0)
            print(f"Synthetic check failed: {e}")

        # Push to Prometheus
        push_to_gateway('monitoring-host:9091', job='synthetic-monitoring')

if __name__ == '__main__':
    while True:
        synthetic_check()
        time.sleep(300)  # Every 5 minutes
```

### Production Quality Gates

| Gate | Requirement | Action on Failure |
|------|------------|-------------------|
| Smoke Tests | 100% pass | Immediate rollback |
| Error Rate | <0.1% | Rollback |
| Response Time | <500ms P95 | Rollback |
| Availability | >99.9% | Alert on-call |
| Resource Usage | <80% CPU/Memory | Alert ops team |

### Production Rollback Criteria

**Immediate Rollback If**:
- ❌ Any smoke test fails
- ❌ Error rate >1%
- ❌ Response time >2x baseline
- ❌ Critical alert triggered
- ❌ Data loss detected
- ❌ Security incident

### Production Test Execution

```bash
# Pre-deployment checks
./tests/environments/prod/pre-deployment-checks.sh

# Canary deployment with validation
./tests/environments/prod/canary-deployment.sh

# Post-deployment smoke tests
./tests/environments/prod/smoke-tests.sh

# Continuous synthetic monitoring (background)
python3 tests/environments/prod/synthetic-monitoring.py &
```

---

## Test Data Management

### Test Data Strategy

#### Development Environment
```yaml
data_strategy: synthetic
characteristics:
  - Randomly generated
  - Minimal data set
  - Fast reset capability
  - No PII/sensitive data

management:
  reset: "On demand"
  refresh: "Daily (optional)"
  source: "Test data generators"
```

#### QA Environment
```yaml
data_strategy: realistic_anonymized
characteristics:
  - Production-like data structure
  - Anonymized PII
  - Larger data volumes
  - Realistic relationships

management:
  reset: "Weekly"
  refresh: "From production (sanitized)"
  source: "Production data + anonymization"
```

#### UAT Environment
```yaml
data_strategy: production_like
characteristics:
  - Near-production data
  - Sanitized sensitive data
  - Production volumes
  - Production relationships

management:
  reset: "Per UAT cycle"
  refresh: "Before UAT testing"
  source: "Latest production snapshot (sanitized)"
```

#### Production Environment
```yaml
data_strategy: live_production
characteristics:
  - Real production data
  - Full volumes
  - No test data

management:
  reset: "N/A"
  refresh: "N/A"
  source: "Live production"
```

### Test Data Scripts

```bash
# tests/data/generate-dev-data.sh
#!/bin/bash
# Generate synthetic test data for development

# Generate 100 test containers
for i in {1..100}; do
  cat <<EOF > "test-data/containers/ct-${i}.json"
{
  "vmid": $((200 + i)),
  "name": "test-ct-${i}",
  "memory": $((1024 * (i % 8 + 1))),
  "cores": $((i % 4 + 1))
}
EOF
done

# Generate test projects
for i in {1..20}; do
  cat <<EOF > "test-data/projects/project-${i}.json"
{
  "id": "proj-${i}",
  "title": "Test Project ${i}",
  "status": "active"
}
EOF
done
```

---

## Environment Promotion

### Promotion Process

```
DEV → QA → UAT → PRODUCTION
 ↓      ↓     ↓        ↓
Tests  Tests Tests   Tests
Pass   Pass  Pass    Pass
```

### Promotion Criteria

#### DEV → QA
```yaml
criteria:
  - All unit tests pass
  - Code review approved
  - Feature branch merged
  - Build successful
  - Local Docker tests pass

automated: true
approval_required: false
```

#### QA → UAT
```yaml
criteria:
  - Full QA test suite passes (100%)
  - Code coverage ≥80%
  - Performance within baseline
  - Security scans clean
  - Integration tests pass
  - QA sign-off

automated: false
approval_required: true
approvers: [qa-lead, tech-lead]
```

#### UAT → Production
```yaml
criteria:
  - UAT smoke tests pass (100%)
  - User acceptance criteria met
  - Production readiness validated
  - Rollback plan tested
  - Change control approved
  - Stakeholder sign-off

automated: false
approval_required: true
approvers: [operations-lead, product-owner, engineering-lead]
```

### Promotion Script

```bash
# tests/promote.sh
#!/bin/bash

SOURCE_ENV="$1"
TARGET_ENV="$2"

case "$SOURCE_ENV-$TARGET_ENV" in
  "dev-qa")
    echo "Promoting from DEV to QA..."
    bash tests/environments/qa/deployment-test.sh || exit 1
    ;;

  "qa-uat")
    echo "Promoting from QA to UAT..."
    read -p "QA sign-off obtained? (yes/no): " qa_signoff
    [ "$qa_signoff" = "yes" ] || exit 1
    bash tests/environments/uat/deployment-test.sh || exit 1
    ;;

  "uat-prod")
    echo "Promoting from UAT to PRODUCTION..."
    read -p "UAT sign-off obtained? (yes/no): " uat_signoff
    [ "$uat_signoff" = "yes" ] || exit 1
    read -p "Change control approved? (yes/no): " cc_approved
    [ "$cc_approved" = "yes" ] || exit 1
    bash tests/environments/prod/canary-deployment.sh || exit 1
    ;;

  *)
    echo "Invalid promotion path: $SOURCE_ENV → $TARGET_ENV"
    exit 1
    ;;
esac

echo "✅ Promotion complete: $SOURCE_ENV → $TARGET_ENV"
```

---

## Related Documentation

- **[COMPREHENSIVE-TEST-STRATEGY.md](./COMPREHENSIVE-TEST-STRATEGY.md)** - Overall testing strategy
- **[CI-CD-INTEGRATION.md](./CI-CD-INTEGRATION.md)** - CI/CD pipeline integration
- **[DOCKER-TESTING-GUIDE.md](./DOCKER-TESTING-GUIDE.md)** - Docker testing specifics
- **[QUALITY-GATES.md](./QUALITY-GATES.md)** - Quality gate definitions

---

**Document Status**: ✅ Complete
**Maintained by**: Tester Agent - Hive Mind Collective
**Version**: 1.0.0
