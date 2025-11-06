# Comprehensive Testing Strategy - AGL Infrastructure Management

> **Document Version**: 1.0.0
> **Last Updated**: 2025-10-28
> **Author**: Tester Agent - Hive Mind Collective
> **Project**: agl-hostman Infrastructure Management

---

## 📑 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Testing Philosophy](#testing-philosophy)
3. [Environment Strategy](#environment-strategy)
4. [Test Pyramid](#test-pyramid)
5. [Test Types & Coverage](#test-types--coverage)
6. [CI/CD Integration](#cicd-integration)
7. [Quality Gates](#quality-gates)
8. [Docker Testing](#docker-testing)
9. [Infrastructure Testing](#infrastructure-testing)
10. [Performance & Load Testing](#performance--load-testing)
11. [Security Testing](#security-testing)
12. [Test Automation](#test-automation)

---

## Executive Summary

### Purpose
This document defines the comprehensive testing strategy for the AGL infrastructure management platform (agl-hostman), covering multi-environment deployment pipelines, Docker container testing, infrastructure validation, and continuous quality assurance.

### Scope
- **Infrastructure**: Proxmox LXC containers, Docker services, network configurations
- **Environments**: Dev → QA → UAT → Production
- **Technologies**: Shell scripts, Docker, Python, Node.js, Bash automation
- **Platforms**: WireGuard mesh, NFS storage, Archon MCP, Harbor registry

### Key Objectives
1. ✅ **Fast Feedback**: Catch issues early with comprehensive unit and integration tests
2. ✅ **Environment Parity**: Ensure consistent behavior across all deployment stages
3. ✅ **Automated Validation**: Minimize manual testing through automation
4. ✅ **Risk Mitigation**: Comprehensive security, performance, and reliability testing
5. ✅ **Quality Gates**: Enforce quality standards at each promotion stage

### Success Metrics
- **Code Coverage**: ≥80% for critical infrastructure scripts
- **Test Pass Rate**: ≥95% before production deployment
- **CI/CD Pipeline Success**: ≥98% green builds
- **Mean Time to Detection (MTTD)**: <15 minutes for critical issues
- **Mean Time to Recovery (MTTR)**: <30 minutes for production incidents

---

## Testing Philosophy

### Principles

#### 1. Shift-Left Testing
**Philosophy**: Test early and often to catch defects before they reach production.

**Implementation**:
- Unit tests run on every file save (watch mode)
- Pre-commit hooks validate code quality
- Integration tests in PR validation
- E2E tests before environment promotion

#### 2. Test Pyramid Approach
```
         /\
        /  \      ← Few E2E tests (slow, expensive)
       /----\
      /  IT  \    ← Moderate integration tests (medium speed)
     /--------\
    /   UNIT   \  ← Many unit tests (fast, cheap)
   /____________\
```

**Rationale**: Fast feedback loop with most coverage at unit level, decreasing as tests become more expensive.

#### 3. Environment-Specific Testing
- **Dev**: Fast feedback, debug-friendly, extensive logging
- **QA**: Full test suite, performance baselines
- **UAT**: User acceptance, production-like conditions
- **Production**: Smoke tests, monitoring, rollback validation

#### 4. Infrastructure as Code Testing
All infrastructure changes treated as code:
- Version controlled
- Peer reviewed
- Automated testing
- Gradual rollout

#### 5. Fail-Fast Philosophy
**From ARCHON.md guidelines**:
- Validate early (pre-deployment checks)
- Clear error messages
- Automated rollback on critical failures
- No silent failures

---

## Environment Strategy

### Environment Progression Model

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌────────────┐
│   DEV   │ -> │   QA    │ -> │   UAT   │ -> │ PRODUCTION │
│ (CT179) │    │ (CT180) │    │ (CT181) │    │  (CT182)   │
└─────────┘    └─────────┘    └─────────┘    └────────────┘
   Fast           Full         User-            Smoke
   Feedback       Suite        Facing           Tests
```

---

### 1. Development Environment (CT179)

**Purpose**: Rapid iteration and developer testing

**Infrastructure**:
- Container: CT179 (agldv03)
- Network: Triple-stack (LAN + WireGuard + Tailscale)
- Resources: 48GB RAM, Docker enabled
- Storage: Local NFS mounts

**Test Strategy**:
```yaml
focus: Fast feedback, extensive debugging
tests:
  unit:
    coverage: 100% of changed files
    run_on: file save (watch mode)
    timeout: 5 seconds per test

  integration:
    coverage: Critical paths only
    run_on: manual trigger or PR draft
    timeout: 30 seconds per suite

  smoke:
    coverage: Basic functionality
    run_on: local docker-compose up

environment:
  logging: DEBUG level
  monitoring: Optional
  alerts: Developer notifications only
  data: Synthetic test data

validation:
  - Script syntax validation
  - Docker image builds
  - Container health checks
  - Network connectivity
```

**Quality Gates**:
- ✅ All unit tests pass
- ✅ Code linting passes (shellcheck, eslint)
- ✅ No critical security vulnerabilities (trivy scan)
- ✅ Docker containers start successfully

**Promotion Criteria**:
- All dev tests pass
- Code review approved
- Feature branch merged to main

---

### 2. QA Environment (CT180)

**Purpose**: Comprehensive testing and quality validation

**Infrastructure**:
- Container: CT180 (dedicated QA)
- Network: Isolated VLAN with controlled access
- Resources: Production-like (8GB RAM)
- Storage: QA NFS shares

**Test Strategy**:
```yaml
focus: Full test coverage, performance validation
tests:
  unit:
    coverage: All modules (80%+ target)
    run_on: Automated on deployment

  integration:
    coverage: All integration points
    run_on: Automated on deployment
    scenarios:
      - Docker container interactions
      - NFS mount operations
      - WireGuard mesh connectivity
      - Archon MCP operations

  e2e:
    coverage: Critical user workflows
    run_on: Automated nightly
    scenarios:
      - Container deployment pipeline
      - Configuration updates
      - Service restarts
      - Backup/restore operations

  performance:
    coverage: Load and stress testing
    run_on: Automated weekly
    baselines:
      - Container startup time
      - Script execution time
      - Network throughput
      - Storage I/O performance

  security:
    coverage: Security scanning
    run_on: Automated on deployment
    checks:
      - Vulnerability scanning
      - Configuration audit
      - Certificate validation
      - Access control verification

environment:
  logging: INFO level
  monitoring: Full metrics collection
  alerts: QA team notifications
  data: Realistic test data (anonymized)

validation:
  - Full test suite execution
  - Performance benchmarks met
  - Security scans passed
  - Documentation updated
```

**Quality Gates**:
- ✅ 100% of automated tests pass
- ✅ Code coverage ≥80%
- ✅ No high/critical vulnerabilities
- ✅ Performance within ±10% of baseline
- ✅ All integration points validated
- ✅ Documentation complete and accurate

**Promotion Criteria**:
- All QA tests pass (100% success rate)
- Performance regression tests pass
- Security validation complete
- QA sign-off obtained

---

### 3. UAT Environment (CT181)

**Purpose**: User acceptance and production readiness validation

**Infrastructure**:
- Container: CT181 (staging)
- Network: Production-identical VLAN
- Resources: Production-identical (16GB RAM)
- Storage: Production-identical NFS

**Test Strategy**:
```yaml
focus: User acceptance, production readiness
tests:
  user_acceptance:
    coverage: Business-critical workflows
    run_on: Manual execution by stakeholders
    scenarios:
      - Infrastructure administrator workflows
      - Container deployment procedures
      - Monitoring dashboard validation
      - Incident response procedures

  smoke:
    coverage: Critical functionality only
    run_on: Pre-deployment validation
    timeout: 5 minutes total

  production_readiness:
    coverage: Deployment validation
    run_on: Before promotion to production
    checks:
      - Configuration parity
      - Certificate validity
      - Backup systems operational
      - Monitoring integrated
      - Rollback plan validated

environment:
  logging: WARN level (production-like)
  monitoring: Production monitoring system
  alerts: Operations team
  data: Production-like data (sanitized)

validation:
  - User acceptance criteria met
  - No blocking issues
  - Performance acceptable
  - Documentation validated by users
  - Rollback tested successfully
```

**Quality Gates**:
- ✅ All critical smoke tests pass
- ✅ User acceptance criteria met (100%)
- ✅ Zero high-priority defects
- ✅ Operations team sign-off
- ✅ Rollback plan validated
- ✅ Runbook complete and tested

**Promotion Criteria**:
- UAT sign-off from stakeholders
- All smoke tests pass
- Production deployment plan approved
- Rollback plan validated
- Change control approval obtained

---

### 4. Production Environment (CT182+)

**Purpose**: Live infrastructure serving real workloads

**Infrastructure**:
- Containers: Multiple production instances
- Network: Production VLANs (isolated)
- Resources: Full production allocation
- Storage: Production NFS with replication

**Test Strategy**:
```yaml
focus: Smoke tests, monitoring, quick rollback
tests:
  smoke:
    coverage: Critical paths only
    run_on: Post-deployment (within 5 minutes)
    timeout: 2 minutes total
    scenarios:
      - Service health checks
      - API endpoint validation
      - Database connectivity
      - External integration checks

  synthetic_monitoring:
    coverage: Continuous production validation
    run_on: Every 5 minutes
    checks:
      - Service availability
      - Response time thresholds
      - Error rate monitoring
      - Resource utilization

  canary:
    coverage: Gradual rollout validation
    run_on: During deployment
    strategy:
      - Deploy to 10% of containers
      - Monitor for 15 minutes
      - Promote to 50% if healthy
      - Full rollout if all green

environment:
  logging: ERROR level only
  monitoring: Real-time alerting
  alerts: On-call rotation
  data: Production data

validation:
  - All smoke tests pass immediately
  - No increase in error rates
  - Response times within SLA
  - Zero customer-impacting issues
```

**Quality Gates**:
- ✅ All smoke tests pass (100%)
- ✅ Service health checks green
- ✅ No alerts triggered
- ✅ Response times within SLA (<500ms)
- ✅ Error rate <0.1%

**Rollback Criteria**:
- ❌ Any smoke test fails
- ❌ Error rate >1%
- ❌ Response time >2x baseline
- ❌ Critical alert triggered
- ❌ Customer-impacting issue detected

---

## Test Pyramid

### Layer 1: Unit Tests (70% of total tests)

**Focus**: Individual functions, scripts, and modules in isolation

**Characteristics**:
- Fast (<100ms per test)
- Isolated (no external dependencies)
- Deterministic (same input = same output)
- High coverage (80%+ target)

**Tools**:
- **Shell Scripts**: bats-core, shunit2
- **Python**: pytest, unittest
- **Node.js**: jest, mocha
- **Docker**: container-structure-test

**Example Test**:
```bash
# tests/unit/wireguard-config-test.bats
#!/usr/bin/env bats

load '../test_helper'

@test "wg_generate_keypair creates valid keys" {
  source scripts/wireguard/keygen.sh

  run wg_generate_keypair
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Private key:" ]]
  [[ "$output" =~ "Public key:" ]]
}

@test "wg_validate_config detects missing parameters" {
  source scripts/wireguard/config.sh

  run wg_validate_config ""
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Missing required parameter" ]]
}
```

**Coverage Requirements**:
| Component | Target Coverage | Critical Functions |
|-----------|----------------|-------------------|
| Core scripts | 85% | Configuration, validation |
| Helper utilities | 75% | Parsing, formatting |
| Error handlers | 90% | All error paths |

---

### Layer 2: Integration Tests (20% of total tests)

**Focus**: Interactions between components and external systems

**Characteristics**:
- Medium speed (1-30 seconds per test)
- External dependencies (databases, APIs, file systems)
- Test realistic scenarios
- Moderate coverage (critical paths)

**Test Scenarios**:

#### Docker Integration
```bash
# tests/integration/docker-deployment-test.sh
test_docker_compose_up() {
  # Given: docker-compose.yml exists
  cd "${TEST_PROJECT_DIR}"

  # When: docker-compose up
  docker-compose up -d

  # Then: All containers healthy
  for service in $(docker-compose config --services); do
    wait_for_healthy "$service" 60
    assert_container_running "$service"
  done
}
```

#### NFS Mount Integration
```bash
# tests/integration/nfs-mount-test.sh
test_nfs_mount_operations() {
  # Given: NFS server accessible
  assert_ping_success "10.6.0.5"

  # When: Mount NFS share
  mount -t nfs 10.6.0.5:/storage /mnt/test

  # Then: Write and read succeed
  echo "test" > /mnt/test/testfile
  assert_file_exists /mnt/test/testfile
  assert_file_content /mnt/test/testfile "test"

  # Cleanup
  umount /mnt/test
}
```

#### Archon MCP Integration
```bash
# tests/integration/archon-mcp-test.sh
test_archon_project_lifecycle() {
  # Given: Archon MCP endpoint available
  assert_http_success "http://10.6.0.21:8051/mcp"

  # When: Create project via MCP
  project_id=$(create_archon_project "Test Project" "Integration test")

  # Then: Project retrievable
  project=$(get_archon_project "$project_id")
  assert_equals "$(echo $project | jq -r '.title')" "Test Project"

  # Cleanup
  delete_archon_project "$project_id"
}
```

**Tools**:
- **Docker**: docker-compose, testcontainers
- **API Testing**: curl, httpie, jq
- **Database**: PostgreSQL test containers
- **File System**: tmpfs test directories

---

### Layer 3: End-to-End Tests (10% of total tests)

**Focus**: Complete user workflows and scenarios

**Characteristics**:
- Slow (1-10 minutes per test)
- Full system integration
- Test production-like scenarios
- Low coverage (critical workflows only)

**Test Scenarios**:

#### Container Deployment Workflow
```python
# tests/e2e/test_container_deployment.py
import pytest
from infrastructure.proxmox import ProxmoxClient
from infrastructure.docker import DockerManager

@pytest.mark.e2e
def test_complete_container_deployment():
    """Test complete container deployment lifecycle"""
    # Given: Proxmox host available
    proxmox = ProxmoxClient("192.168.0.245")
    assert proxmox.is_available()

    # When: Create new LXC container
    container = proxmox.create_container(
        vmid=999,
        template="debian-12",
        memory=4096,
        storage="local-lvm"
    )

    # Then: Container created and started
    assert container.wait_for_status("running", timeout=120)

    # When: Deploy Docker Compose stack
    docker = DockerManager(container)
    docker.deploy_stack("./test-stack.yml")

    # Then: All services healthy
    assert docker.all_services_healthy(timeout=180)

    # When: Validate application endpoints
    response = container.exec("curl -f http://localhost:8080/health")
    assert response.exit_code == 0

    # Cleanup
    container.stop()
    container.destroy()
```

#### Infrastructure Update Workflow
```yaml
# tests/e2e/infrastructure-update.feature
Feature: Infrastructure Configuration Update
  As an infrastructure administrator
  I want to update container configurations
  So that infrastructure stays current and secure

Scenario: Update WireGuard configuration
  Given WireGuard mesh is operational
  And all peers are connected
  When I add a new peer configuration
  And I restart WireGuard service
  Then new peer connects successfully
  And existing peers remain connected
  And mesh latency stays within acceptable range

Scenario: Update Docker Compose services
  Given Docker Compose stack is running
  When I update service image versions
  And I perform rolling update
  Then services update without downtime
  And health checks pass throughout update
  And no data loss occurs
```

**Tools**:
- **Python**: pytest + pytest-bdd
- **Shell**: bats with scenario support
- **Browser**: Playwright/Selenium (for web dashboards)
- **Infrastructure**: Terraform/Ansible test modes

---

## Test Types & Coverage

### 1. Functional Tests

**Purpose**: Verify functionality meets requirements

**Categories**:

#### Script Execution Tests
```bash
# tests/functional/script-execution.bats
@test "discover-vps-hosts.sh finds all VPS hosts" {
  run bash scripts/discover-vps-hosts.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "CT179" ]]
  [[ "$output" =~ "CT180" ]]
  [[ "$output" =~ "CT182" ]]
}

@test "backup-ollama-models.sh creates backup archive" {
  run bash scripts/backup-ollama-models.sh --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Would create backup:" ]]
}
```

#### Docker Operations Tests
```python
# tests/functional/test_docker_operations.py
def test_docker_container_lifecycle():
    """Test container creation, start, stop, removal"""
    client = docker.from_env()

    # Create
    container = client.containers.create("alpine:latest", name="test-container")
    assert container.status == "created"

    # Start
    container.start()
    assert container.status == "running"

    # Stop
    container.stop()
    assert container.status == "exited"

    # Remove
    container.remove()
```

#### Network Configuration Tests
```bash
# tests/functional/network-config.bats
@test "WireGuard interface configured correctly" {
  run wg show wg0
  [ "$status" -eq 0 ]
  [[ "$output" =~ "listening port: 51820" ]]
}

@test "NFS mounts accessible" {
  run mount | grep "type nfs"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/mnt/pve/fgsrv6-wg" ]]
}
```

**Coverage**: 90% of functional requirements

---

### 2. Regression Tests

**Purpose**: Prevent reintroduction of fixed bugs

**Strategy**:
- Create test for every bug fix
- Tag with bug tracking ID
- Run on every deployment

**Example**:
```bash
# tests/regression/issue-123-nfs-timeout.bats
# Regression test for: NFS mount hangs on network timeout
# Issue: #123
# Fixed: 2025-10-15

@test "NFS mount fails gracefully on timeout (Issue #123)" {
  # Simulate network timeout
  iptables -A OUTPUT -p tcp --dport 2049 -j DROP

  # Attempt mount with timeout
  timeout 10 mount -t nfs 10.6.0.5:/storage /mnt/test
  status=$?

  # Cleanup
  iptables -D OUTPUT -p tcp --dport 2049 -j DROP

  # Should timeout, not hang
  [ "$status" -eq 124 ]  # timeout exit code
}
```

**Coverage**: 100% of resolved bugs have regression tests

---

### 3. Performance Tests

**Purpose**: Ensure system meets performance requirements

**Test Types**:

#### Load Testing
```python
# tests/performance/load_test.py
import locust
from locust import HttpUser, task, between

class ArchonMCPUser(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def search_knowledge_base(self):
        self.client.post("/mcp/rag_search_knowledge_base", json={
            "query": "wireguard configuration",
            "match_count": 5
        })

    @task(1)
    def list_projects(self):
        self.client.post("/mcp/find_projects")
```

**Run**: `locust -f tests/performance/load_test.py --users 100 --spawn-rate 10`

#### Stress Testing
```bash
# tests/performance/stress-test.sh
#!/bin/bash
# Stress test Docker container capacity

for i in {1..50}; do
  docker run -d --name "stress-$i" \
    --memory="512m" \
    --cpus="0.5" \
    alpine:latest sleep 3600
done

# Monitor system resources
while true; do
  docker stats --no-stream
  sleep 5
done
```

#### Benchmark Tests
```python
# tests/performance/benchmark_test.py
import pytest
from infrastructure.metrics import measure_time

@pytest.mark.benchmark
def test_container_startup_time(benchmark):
    """Container should start in <10 seconds"""
    result = benchmark(start_and_wait_for_container, "test-app")
    assert result < 10.0  # seconds
```

**Performance Baselines**:
| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Container startup | <10s | >15s | >30s |
| Script execution | <5s | >10s | >30s |
| API response time | <500ms | >1s | >3s |
| NFS throughput | >100MB/s | <50MB/s | <10MB/s |
| WireGuard latency | <10ms | >50ms | >100ms |

---

### 4. Security Tests

**Purpose**: Validate security controls and detect vulnerabilities

**Test Categories**:

#### Vulnerability Scanning
```bash
# tests/security/vulnerability-scan.sh
#!/bin/bash
# Scan Docker images for vulnerabilities

for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
  echo "Scanning $image..."
  trivy image --severity HIGH,CRITICAL "$image"
done
```

#### Configuration Audit
```bash
# tests/security/config-audit.sh
#!/bin/bash
# Audit container security configurations

check_user_namespace() {
  # Containers should not run as root
  docker inspect --format='{{.Config.User}}' "$1" | grep -v "^$" || return 1
}

check_readonly_root() {
  # Root filesystem should be read-only
  docker inspect --format='{{.HostConfig.ReadonlyRootfs}}' "$1" | grep true
}
```

#### Secret Management
```python
# tests/security/test_secret_management.py
def test_no_hardcoded_secrets():
    """Ensure no secrets in code or configs"""
    patterns = [
        r'password\s*=\s*["\'][^"\']+["\']',
        r'api[_-]?key\s*=\s*["\'][^"\']+["\']',
        r'secret\s*=\s*["\'][^"\']+["\']'
    ]

    for file in glob.glob("**/*.py", recursive=True):
        with open(file) as f:
            content = f.read()
            for pattern in patterns:
                assert not re.search(pattern, content, re.I), \
                    f"Potential hardcoded secret in {file}"
```

#### Access Control Tests
```bash
# tests/security/access-control.bats
@test "Non-admin user cannot access admin endpoints" {
  # Attempt to access admin API as regular user
  run curl -f -u testuser:testpass http://localhost:8080/admin/users
  [ "$status" -ne 0 ]  # Should fail
}

@test "SSL/TLS certificates valid" {
  run openssl s_client -connect localhost:443 </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Verify return code: 0 (ok)" ]]
}
```

**Security Testing Tools**:
- **Container Scanning**: Trivy, Clair
- **Secret Detection**: git-secrets, trufflehog
- **Configuration Audit**: docker-bench-security
- **Penetration Testing**: OWASP ZAP, nmap

---

## CI/CD Integration

### Pipeline Architecture

```yaml
# .github/workflows/ci-cd-pipeline.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Shellcheck
        run: |
          find scripts -name "*.sh" -exec shellcheck {} \;
      - name: Hadolint (Dockerfile)
        run: |
          find . -name "Dockerfile*" -exec hadolint {} \;

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: npm install -g bats
      - name: Run unit tests
        run: |
          bats tests/unit/*.bats --formatter junit > test-results.xml
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results.xml

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3
      - name: Start test containers
        run: docker-compose -f docker-compose.test.yml up -d
      - name: Run integration tests
        run: bash tests/integration/run-all.sh
      - name: Stop containers
        run: docker-compose -f docker-compose.test.yml down

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'

  deploy-dev:
    runs-on: ubuntu-latest
    needs: [lint, unit-tests, integration-tests, security-scan]
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Deploy to Dev (CT179)
        run: |
          ssh root@100.94.221.87 'cd /root/agl-hostman && git pull && ./deploy.sh dev'
      - name: Run smoke tests
        run: bash tests/smoke/dev-smoke-tests.sh

  deploy-qa:
    runs-on: ubuntu-latest
    needs: deploy-dev
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to QA (CT180)
        run: |
          ssh root@qa-host 'cd /root/agl-hostman && ./deploy.sh qa'
      - name: Run full test suite
        run: bash tests/e2e/qa-full-suite.sh
      - name: Performance benchmarks
        run: bash tests/performance/run-benchmarks.sh

  deploy-uat:
    runs-on: ubuntu-latest
    needs: deploy-qa
    environment: uat
    steps:
      - name: Deploy to UAT (CT181)
        run: |
          ssh root@uat-host 'cd /root/agl-hostman && ./deploy.sh uat'
      - name: UAT smoke tests
        run: bash tests/smoke/uat-smoke-tests.sh

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-uat
    environment: production
    steps:
      - name: Production deployment (canary)
        run: |
          ssh root@prod-host 'cd /root/agl-hostman && ./deploy.sh production --canary'
      - name: Canary validation
        run: bash tests/smoke/production-canary-tests.sh
      - name: Full rollout
        run: |
          ssh root@prod-host 'cd /root/agl-hostman && ./deploy.sh production --full'
      - name: Post-deployment validation
        run: bash tests/smoke/production-smoke-tests.sh
```

### Test Automation Scripts

All automated test suites are available in:
- **Unit Tests**: `/tests/unit/`
- **Integration Tests**: `/tests/integration/`
- **E2E Tests**: `/tests/e2e/`
- **Smoke Tests**: `/tests/smoke/`
- **Performance Tests**: `/tests/performance/`
- **Security Tests**: `/tests/security/`

---

## Quality Gates

### Definition
Quality gates are automated checkpoints that enforce quality standards before code promotion.

### Gate Levels

#### Level 1: Pre-Commit (Local Developer)
```bash
# .git/hooks/pre-commit
#!/bin/bash
echo "Running pre-commit checks..."

# Shellcheck
find scripts -name "*.sh" -exec shellcheck {} \; || exit 1

# Unit tests
bats tests/unit/*.bats || exit 1

# Secret detection
git secrets --scan || exit 1

echo "✅ Pre-commit checks passed"
```

**Requirements**:
- ✅ Code linting passes
- ✅ Unit tests for changed files pass
- ✅ No secrets detected

---

#### Level 2: Pull Request
**Trigger**: PR opened or updated

**Requirements**:
- ✅ All unit tests pass (100%)
- ✅ Code coverage ≥80%
- ✅ Integration tests pass
- ✅ No security vulnerabilities (high/critical)
- ✅ Code review approved (≥1 reviewer)
- ✅ No merge conflicts

**Automation**:
```yaml
pr-validation:
  checks:
    - linting
    - unit-tests
    - integration-tests
    - security-scan
    - coverage-check
  blocking: true  # PR cannot merge if checks fail
```

---

#### Level 3: Merge to Main
**Trigger**: PR merged to main branch

**Requirements**:
- ✅ All PR checks passed
- ✅ Branch up-to-date with main
- ✅ Build succeeds
- ✅ Docker images build successfully
- ✅ Documentation updated

---

#### Level 4: Deploy to QA
**Trigger**: Deployment to QA environment

**Requirements**:
- ✅ All smoke tests pass (100%)
- ✅ Full test suite passes (≥95%)
- ✅ Performance benchmarks within ±10% baseline
- ✅ Security scan passed
- ✅ No open critical bugs

**Validation**:
```bash
# tests/gates/qa-gate.sh
#!/bin/bash
set -e

echo "🚪 QA Quality Gate"

# 1. Smoke tests
echo "Running smoke tests..."
bash tests/smoke/qa-smoke-tests.sh

# 2. Full test suite
echo "Running full test suite..."
bash tests/e2e/qa-full-suite.sh

# 3. Performance check
echo "Running performance benchmarks..."
bash tests/performance/run-benchmarks.sh

# 4. Security validation
echo "Running security scans..."
bash tests/security/full-scan.sh

echo "✅ QA gate passed - ready for UAT"
```

---

#### Level 5: Deploy to UAT
**Trigger**: Deployment to UAT environment

**Requirements**:
- ✅ QA gate passed
- ✅ UAT smoke tests pass (100%)
- ✅ No high-priority defects
- ✅ User acceptance criteria defined
- ✅ Rollback plan validated

---

#### Level 6: Deploy to Production
**Trigger**: Deployment to production environment

**Requirements**:
- ✅ UAT sign-off obtained
- ✅ Production smoke tests pass (100%)
- ✅ Change control approval
- ✅ Deployment plan reviewed
- ✅ Rollback validated in UAT
- ✅ Monitoring configured
- ✅ On-call team notified

**Validation**:
```bash
# tests/gates/production-gate.sh
#!/bin/bash
set -e

echo "🚪 Production Quality Gate"

# 1. Pre-deployment checks
echo "Pre-deployment validation..."
bash tests/smoke/pre-production-checks.sh

# 2. Canary deployment
echo "Deploying canary..."
./deploy.sh production --canary

# 3. Canary validation (15 minutes)
echo "Validating canary..."
bash tests/smoke/canary-validation.sh --duration 900

# 4. Full rollout
echo "Full production rollout..."
./deploy.sh production --full

# 5. Post-deployment validation
echo "Post-deployment validation..."
bash tests/smoke/production-smoke-tests.sh

echo "✅ Production deployment successful"
```

---

### Quality Metrics Dashboard

```yaml
metrics:
  test_coverage:
    target: 80%
    warning: 75%
    critical: 70%

  test_pass_rate:
    target: 95%
    warning: 90%
    critical: 85%

  build_success_rate:
    target: 98%
    warning: 95%
    critical: 90%

  deployment_success:
    target: 95%
    warning: 90%
    critical: 85%

  mean_time_to_detect:
    target: 15min
    warning: 30min
    critical: 60min

  mean_time_to_recover:
    target: 30min
    warning: 60min
    critical: 120min
```

---

## Docker Testing

### Container Testing Strategy

#### 1. Dockerfile Validation
```bash
# tests/docker/dockerfile-validation.sh
#!/bin/bash

# Lint Dockerfiles
for dockerfile in $(find . -name "Dockerfile*"); do
  echo "Linting $dockerfile..."
  hadolint "$dockerfile" || exit 1
done

# Check for best practices
docker run --rm -v $(pwd):/workspace \
  securego/gosec:latest \
  /workspace/Dockerfile
```

#### 2. Image Build Tests
```python
# tests/docker/test_image_build.py
import docker
import pytest

@pytest.fixture
def docker_client():
    return docker.from_env()

def test_archon_image_builds(docker_client):
    """Test Archon MCP image builds successfully"""
    image, logs = docker_client.images.build(
        path="./docker/archon",
        tag="archon-mcp:test"
    )

    assert image is not None
    assert "archon-mcp:test" in image.tags

def test_harbor_image_builds(docker_client):
    """Test Harbor registry image builds"""
    image, logs = docker_client.images.build(
        path="./docker/harbor",
        tag="harbor:test"
    )

    assert image is not None
```

#### 3. Container Security Tests
```bash
# tests/docker/security-scan.sh
#!/bin/bash

# Scan for vulnerabilities
for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
  echo "Scanning $image for vulnerabilities..."

  # Trivy scan
  trivy image --severity HIGH,CRITICAL "$image"

  # Check for rootless
  user=$(docker inspect --format='{{.Config.User}}' "$image")
  if [ -z "$user" ] || [ "$user" = "root" ]; then
    echo "❌ Warning: $image runs as root"
  fi
done
```

#### 4. Container Structure Tests
```yaml
# tests/docker/container-structure-test.yaml
schemaVersion: '2.0.0'

fileExistenceTests:
  - name: 'Health check script exists'
    path: '/usr/local/bin/healthcheck.sh'
    shouldExist: true
    permissions: '-rwxr-xr-x'

commandTests:
  - name: 'Application starts successfully'
    command: '/usr/local/bin/start.sh'
    expectedOutput: ['Server started']
    exitCode: 0

metadataTest:
  exposedPorts: ['8080', '443']
  volumes: ['/data']
  workdir: '/app'
  user: 'appuser'
```

**Run**: `container-structure-test test --image archon-mcp:test --config tests/docker/container-structure-test.yaml`

#### 5. Docker Compose Tests
```python
# tests/docker/test_docker_compose.py
import subprocess
import time
import pytest

@pytest.fixture
def compose_project():
    """Start docker-compose stack for testing"""
    subprocess.run(['docker-compose', '-f', 'docker-compose.test.yml', 'up', '-d'])
    time.sleep(10)  # Wait for services to start
    yield
    subprocess.run(['docker-compose', '-f', 'docker-compose.test.yml', 'down'])

def test_all_services_healthy(compose_project):
    """All services should be healthy"""
    result = subprocess.run(
        ['docker-compose', 'ps', '--format', 'json'],
        capture_output=True,
        text=True
    )

    services = json.loads(result.stdout)
    for service in services:
        assert service['Health'] == 'healthy'
```

#### 6. Resource Limit Tests
```bash
# tests/docker/resource-limits.sh
#!/bin/bash

test_memory_limits() {
  # Container should respect memory limits
  container_id=$(docker run -d --memory="512m" alpine:latest sleep 3600)

  # Check actual memory limit
  mem_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$container_id")

  if [ "$mem_limit" -ne 536870912 ]; then  # 512MB in bytes
    echo "❌ Memory limit not enforced"
    docker rm -f "$container_id"
    return 1
  fi

  docker rm -f "$container_id"
  echo "✅ Memory limits working"
}

test_cpu_limits() {
  # Container should respect CPU limits
  container_id=$(docker run -d --cpus="0.5" alpine:latest sleep 3600)

  # Check actual CPU quota
  cpu_quota=$(docker inspect --format='{{.HostConfig.CpuQuota}}' "$container_id")

  if [ "$cpu_quota" -ne 50000 ]; then  # 0.5 CPUs
    echo "❌ CPU limit not enforced"
    docker rm -f "$container_id"
    return 1
  fi

  docker rm -f "$container_id"
  echo "✅ CPU limits working"
}
```

#### 7. Health Check Validation
```python
# tests/docker/test_health_checks.py
import docker
import time

def test_container_health_checks():
    """Containers should have working health checks"""
    client = docker.from_env()

    # Start container with health check
    container = client.containers.run(
        "archon-mcp:test",
        detach=True,
        healthcheck={
            "test": ["CMD", "curl", "-f", "http://localhost:8051/health"],
            "interval": 10_000_000_000,  # 10 seconds in nanoseconds
            "timeout": 5_000_000_000,
            "retries": 3
        }
    )

    # Wait for health check
    max_wait = 60
    elapsed = 0
    while elapsed < max_wait:
        container.reload()
        if container.health == "healthy":
            break
        time.sleep(5)
        elapsed += 5

    assert container.health == "healthy"
    container.stop()
    container.remove()
```

---

## Infrastructure Testing

### Network Testing

#### WireGuard Mesh Validation
```bash
# tests/infrastructure/wireguard-mesh-test.sh
#!/bin/bash

test_wireguard_connectivity() {
  echo "Testing WireGuard mesh connectivity..."

  # Test each peer
  peers=(
    "10.6.0.5"   # FGSRV6
    "10.6.0.12"  # AGLSRV6
    "10.6.0.21"  # CT183 (Archon)
  )

  for peer in "${peers[@]}"; do
    echo "Testing $peer..."

    # Ping test
    if ! ping -c 3 -W 5 "$peer" &>/dev/null; then
      echo "❌ Cannot ping $peer"
      return 1
    fi

    # Latency test
    latency=$(ping -c 10 "$peer" | tail -1 | awk -F'/' '{print $5}')
    if (( $(echo "$latency > 50" | bc -l) )); then
      echo "⚠️  High latency to $peer: ${latency}ms"
    fi

    echo "✅ $peer reachable (${latency}ms)"
  done
}

test_wireguard_handshake() {
  echo "Testing WireGuard handshakes..."

  wg show wg0 | grep -A 5 "peer:" | while read -r line; do
    if [[ $line =~ "latest handshake" ]]; then
      handshake_time=$(echo "$line" | awk '{print $3}')
      if [ "$handshake_time" -gt 180 ]; then
        echo "⚠️  Stale handshake: ${handshake_time}s ago"
      fi
    fi
  done
}
```

#### NFS Mount Testing
```bash
# tests/infrastructure/nfs-mount-test.sh
#!/bin/bash

test_nfs_mounts() {
  echo "Testing NFS mounts..."

  mounts=(
    "/mnt/pve/fgsrv6-wg"
    "/mnt/pve/aglsrv6-storage"
  )

  for mount in "${mounts[@]}"; do
    echo "Testing $mount..."

    # Check mount exists
    if ! mountpoint -q "$mount"; then
      echo "❌ $mount not mounted"
      return 1
    fi

    # Test write access
    test_file="$mount/.mount-test-$$"
    if echo "test" > "$test_file" 2>/dev/null; then
      rm -f "$test_file"
      echo "✅ $mount writable"
    else
      echo "⚠️  $mount read-only"
    fi

    # Test read performance
    dd if="$mount/testfile" of=/dev/null bs=1M count=100 2>&1 | \
      grep -o '[0-9.]* MB/s' || echo "Performance test skipped"
  done
}
```

### Container Health Testing

```python
# tests/infrastructure/test_proxmox_containers.py
import subprocess
import json
import pytest

def get_container_status(vmid):
    """Get Proxmox container status"""
    result = subprocess.run(
        ['ssh', 'root@192.168.0.245', f'pct status {vmid}'],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

@pytest.mark.parametrize("vmid,name", [
    (179, "CT179-agldv03"),
    (182, "CT182-harbor"),
    (183, "CT183-archon"),
])
def test_critical_containers_running(vmid, name):
    """Critical containers should be running"""
    status = get_container_status(vmid)
    assert status == "running", f"{name} is {status}"

def test_container_resource_usage():
    """Containers should not exceed resource limits"""
    result = subprocess.run(
        ['ssh', 'root@192.168.0.245', 'pct list'],
        capture_output=True,
        text=True
    )

    for line in result.stdout.split('\n')[1:]:  # Skip header
        if not line.strip():
            continue

        parts = line.split()
        vmid = parts[0]
        mem_usage = float(parts[3])  # Memory usage %

        assert mem_usage < 90, f"Container {vmid} memory usage {mem_usage}% too high"
```

---

## Performance & Load Testing

### Performance Test Scenarios

#### 1. Baseline Performance Tests
```bash
# tests/performance/baseline-performance.sh
#!/bin/bash

# Script execution time baseline
test_script_performance() {
  script="$1"
  max_time="${2:-5}"  # Default 5 seconds

  echo "Testing $script performance..."

  start=$(date +%s%N)
  bash "$script" &>/dev/null
  end=$(date +%s%N)

  duration=$(( (end - start) / 1000000 ))  # Convert to milliseconds

  if [ "$duration" -gt "$((max_time * 1000))" ]; then
    echo "❌ $script took ${duration}ms (max: ${max_time}s)"
    return 1
  fi

  echo "✅ $script completed in ${duration}ms"
}

# Test critical scripts
test_script_performance "scripts/discover-vps-hosts.sh" 5
test_script_performance "scripts/backup-ollama-models.sh --dry-run" 3
```

#### 2. Load Testing (Archon MCP)
```python
# tests/performance/load_test_archon.py
from locust import HttpUser, task, between
import json

class ArchonMCPUser(HttpUser):
    wait_time = between(1, 3)
    host = "http://10.6.0.21:8051"

    def on_start(self):
        """Setup - called once per user"""
        pass

    @task(5)
    def search_knowledge_base(self):
        """Most common operation - search"""
        self.client.post("/mcp", json={
            "method": "rag_search_knowledge_base",
            "params": {
                "query": "docker configuration",
                "match_count": 5
            }
        })

    @task(3)
    def list_projects(self):
        """List projects"""
        self.client.post("/mcp", json={
            "method": "find_projects",
            "params": {}
        })

    @task(2)
    def find_tasks(self):
        """Find tasks"""
        self.client.post("/mcp", json={
            "method": "find_tasks",
            "params": {
                "filter_by": "status",
                "filter_value": "todo"
            }
        })

    @task(1)
    def health_check(self):
        """Health check endpoint"""
        self.client.post("/mcp", json={
            "method": "health_check",
            "params": {}
        })
```

**Run**:
```bash
# Light load (10 users)
locust -f tests/performance/load_test_archon.py --users 10 --spawn-rate 2 --run-time 5m --headless

# Medium load (50 users)
locust -f tests/performance/load_test_archon.py --users 50 --spawn-rate 5 --run-time 10m --headless

# Heavy load (100 users)
locust -f tests/performance/load_test_archon.py --users 100 --spawn-rate 10 --run-time 15m --headless
```

#### 3. Stress Testing
```bash
# tests/performance/stress-test.sh
#!/bin/bash

stress_test_docker() {
  echo "Docker container stress test..."

  # Spawn many containers
  for i in {1..100}; do
    docker run -d --name "stress-test-$i" \
      --memory="256m" \
      --cpus="0.25" \
      alpine:latest sleep 600 &
  done

  wait

  # Monitor resources
  docker stats --no-stream

  # Cleanup
  docker ps -a --filter "name=stress-test-" -q | xargs docker rm -f
}

stress_test_nfs() {
  echo "NFS storage stress test..."

  # Multiple concurrent writes
  for i in {1..20}; do
    dd if=/dev/zero of="/mnt/pve/fgsrv6-wg/stress-$i" bs=1M count=100 &
  done

  wait

  # Cleanup
  rm -f /mnt/pve/fgsrv6-wg/stress-*
}
```

---

## Security Testing

### Security Test Framework

#### 1. Container Security Scanning
```bash
# tests/security/container-security-scan.sh
#!/bin/bash

echo "🔒 Container Security Scanning"

# Scan all images
for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
  echo "Scanning $image..."

  # Vulnerability scan with Trivy
  trivy image --severity HIGH,CRITICAL --exit-code 1 "$image"

  # Configuration scan
  docker-bench-security -c container_images -i "$image"
done

# Check running containers
docker ps -q | while read -r container_id; do
  echo "Auditing running container $container_id..."

  # Check if running as root
  user=$(docker inspect --format='{{.Config.User}}' "$container_id")
  if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
    echo "⚠️  Container $container_id running as root"
  fi

  # Check for privileged mode
  privileged=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container_id")
  if [ "$privileged" = "true" ]; then
    echo "⚠️  Container $container_id running in privileged mode"
  fi
done
```

#### 2. Secret Detection
```bash
# tests/security/secret-detection.sh
#!/bin/bash

echo "🔒 Secret Detection Scan"

# Scan for secrets in code
trufflehog filesystem . --json > secrets-report.json

# Check for hardcoded secrets
patterns=(
  "password\s*=\s*['\"][^'\"]+['\"]"
  "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
  "secret\s*=\s*['\"][^'\"]+['\"]"
  "token\s*=\s*['\"][^'\"]+['\"]"
)

for pattern in "${patterns[@]}"; do
  echo "Checking pattern: $pattern"
  if grep -r -E -i "$pattern" scripts/ src/ config/ 2>/dev/null; then
    echo "❌ Potential hardcoded secret found"
    exit 1
  fi
done

echo "✅ No secrets detected"
```

#### 3. SSL/TLS Validation
```bash
# tests/security/tls-validation.sh
#!/bin/bash

test_tls_configuration() {
  host="$1"
  port="${2:-443}"

  echo "Testing TLS configuration for $host:$port..."

  # Check certificate validity
  echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | \
    openssl x509 -noout -dates

  # Check TLS version support
  for version in tls1 tls1_1 tls1_2 tls1_3; do
    if echo | openssl s_client -"$version" -connect "$host:$port" 2>/dev/null | \
       grep -q "Protocol"; then
      echo "✅ $version supported"
    else
      echo "❌ $version not supported"
    fi
  done

  # Check cipher suites
  echo "Testing cipher suites..."
  nmap --script ssl-enum-ciphers -p "$port" "$host"
}
```

#### 4. Access Control Tests
```python
# tests/security/test_access_control.py
import requests
import pytest

@pytest.fixture
def archon_endpoint():
    return "http://10.6.0.21:8051"

def test_unauthenticated_access_blocked(archon_endpoint):
    """Unauthenticated requests should be rejected"""
    response = requests.post(f"{archon_endpoint}/mcp", json={
        "method": "find_projects"
    })
    assert response.status_code in [401, 403]

def test_admin_endpoints_require_admin_role(archon_endpoint, admin_token, user_token):
    """Admin endpoints should require admin role"""
    # Admin should succeed
    response = requests.post(
        f"{archon_endpoint}/admin/users",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert response.status_code == 200

    # Regular user should fail
    response = requests.post(
        f"{archon_endpoint}/admin/users",
        headers={"Authorization": f"Bearer {user_token}"}
    )
    assert response.status_code == 403
```

---

## Test Automation

### Test Framework Architecture

```
tests/
├── unit/                    # Fast, isolated unit tests
│   ├── scripts/             # Shell script unit tests
│   ├── python/              # Python unit tests
│   └── helpers/             # Test helper functions
├── integration/             # Integration tests
│   ├── docker/              # Docker integration
│   ├── network/             # Network tests
│   └── storage/             # Storage tests
├── e2e/                     # End-to-end tests
│   ├── deployment/          # Deployment workflows
│   └── infrastructure/      # Infrastructure scenarios
├── smoke/                   # Quick smoke tests
│   ├── dev-smoke.sh
│   ├── qa-smoke.sh
│   ├── uat-smoke.sh
│   └── prod-smoke.sh
├── performance/             # Performance & load tests
│   ├── baseline/
│   ├── load/
│   └── stress/
├── security/                # Security tests
│   ├── vulnerability-scan.sh
│   ├── secret-detection.sh
│   └── access-control/
├── docs/                    # Test documentation
│   ├── COMPREHENSIVE-TEST-STRATEGY.md (this file)
│   ├── ENVIRONMENT-TEST-PLANS.md
│   ├── CI-CD-INTEGRATION.md
│   ├── DOCKER-TESTING-GUIDE.md
│   └── QUALITY-GATES.md
└── test_helper.sh           # Shared test utilities
```

### Test Helper Library

```bash
# tests/test_helper.sh
#!/bin/bash

# Assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [ "$expected" != "$actual" ]; then
    echo "❌ $message"
    echo "   Expected: $expected"
    echo "   Actual: $actual"
    return 1
  fi
  echo "✅ $message"
}

assert_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "❌ File does not exist: $file"
    return 1
  fi
  echo "✅ File exists: $file"
}

assert_container_running() {
  local container="$1"
  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    echo "❌ Container not running: $container"
    return 1
  fi
  echo "✅ Container running: $container"
}

wait_for_healthy() {
  local container="$1"
  local timeout="${2:-60}"
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    if [ "$status" = "healthy" ]; then
      echo "✅ $container is healthy"
      return 0
    fi
    sleep 1
    ((elapsed++))
  done

  echo "❌ $container not healthy after ${timeout}s"
  return 1
}

# Cleanup functions
cleanup_test_containers() {
  docker ps -a --filter "name=test-" -q | xargs -r docker rm -f
}

cleanup_test_files() {
  rm -rf /tmp/test-*
}
```

---

## Test Execution Guide

### Running Tests Locally

```bash
# Run all unit tests
bats tests/unit/**/*.bats

# Run specific test suite
bats tests/unit/scripts/wireguard-test.bats

# Run with verbose output
bats -v tests/unit/**/*.bats

# Run integration tests
bash tests/integration/run-all.sh

# Run smoke tests
bash tests/smoke/dev-smoke-tests.sh

# Run performance tests
bash tests/performance/run-benchmarks.sh

# Run security scans
bash tests/security/full-scan.sh
```

### Running Tests in CI/CD

Tests are automatically executed in CI/CD pipeline (see [CI/CD Integration](#cicd-integration)).

### Test Reporting

Test results are exported in multiple formats:

```bash
# JUnit XML (for CI/CD)
bats tests/unit/*.bats --formatter junit > test-results.xml

# JSON format
bats tests/unit/*.bats --formatter json > test-results.json

# TAP format
bats tests/unit/*.bats --formatter tap > test-results.tap

# Human-readable HTML report
bats tests/unit/*.bats --formatter junit | \
  junit2html test-results.xml test-report.html
```

---

## Continuous Improvement

### Test Metrics to Track

1. **Test Coverage**: Track coverage trends over time
2. **Test Duration**: Monitor test execution time
3. **Flaky Tests**: Identify and fix unreliable tests
4. **Bug Detection Rate**: Measure test effectiveness
5. **Test Maintenance Cost**: Time spent maintaining tests

### Test Maintenance

```bash
# Weekly test maintenance checklist
- Remove obsolete tests
- Update test data
- Refactor slow tests
- Fix flaky tests
- Update documentation
```

---

## Related Documentation

- **[ENVIRONMENT-TEST-PLANS.md](./ENVIRONMENT-TEST-PLANS.md)** - Detailed test plans per environment
- **[CI-CD-INTEGRATION.md](./CI-CD-INTEGRATION.md)** - CI/CD pipeline integration guide
- **[DOCKER-TESTING-GUIDE.md](./DOCKER-TESTING-GUIDE.md)** - Comprehensive Docker testing
- **[QUALITY-GATES.md](./QUALITY-GATES.md)** - Quality gate specifications
- **[ARCHON.md](../../docs/ARCHON.md)** - Archon MCP testing integration

---

**Next Steps**:
1. ✅ Review and approve this strategy
2. ⏭️ Implement test automation scripts
3. ⏭️ Configure CI/CD pipeline
4. ⏭️ Train team on testing practices
5. ⏭️ Establish quality metrics dashboard

---

**Document Status**: ✅ Complete
**Review Status**: ⏳ Pending approval
**Implementation Status**: 🏗️ Ready for implementation

**Maintained by**: Tester Agent - Hive Mind Collective
**Last Updated**: 2025-10-28
**Version**: 1.0.0
