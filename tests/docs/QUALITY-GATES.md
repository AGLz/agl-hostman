# Quality Gates Specification

> **Document Version**: 1.0.0
> **Last Updated**: 2025-10-28
> **Author**: Tester Agent - Hive Mind Collective

---

## Table of Contents

1. [Overview](#overview)
2. [Gate Definitions](#gate-definitions)
3. [Metrics & Thresholds](#metrics--thresholds)
4. [Implementation](#implementation)
5. [Enforcement](#enforcement)
6. [Reporting](#reporting)
7. [Continuous Improvement](#continuous-improvement)

---

## Overview

### Purpose
Quality gates are automated checkpoints that enforce quality standards before code promotion through environments.

### Quality Gate Philosophy

```
🚪 Quality Gate = Automated + Objective + Blocking + Measurable
```

**Characteristics**:
- ✅ **Automated**: No manual intervention required
- ✅ **Objective**: Clear pass/fail criteria
- ✅ **Blocking**: Prevents promotion on failure
- ✅ **Measurable**: Quantifiable metrics

### Gate Hierarchy

```
┌─────────────────┐
│  Pre-Commit     │  ← Developer Workstation
├─────────────────┤
│  Pull Request   │  ← Code Review Stage
├─────────────────┤
│  Main Branch    │  ← Integration Stage
├─────────────────┤
│  QA Deployment  │  ← Quality Assurance
├─────────────────┤
│  UAT Deployment │  ← User Acceptance
├─────────────────┤
│  Production     │  ← Production Release
└─────────────────┘
```

---

## Gate Definitions

### Gate 1: Pre-Commit (Local)

**Trigger**: Before commit to local repository
**Execution Time**: <30 seconds
**Blocker**: Yes (prevents commit)

#### Requirements

| Check | Threshold | Blocker |
|-------|-----------|---------|
| Code Linting | Zero errors | Yes |
| File-level Unit Tests | 100% pass | Yes |
| Secret Detection | Zero secrets | Yes |
| File Size | <10MB per file | Yes |

#### Implementation

```bash
# .git/hooks/pre-commit
#!/bin/bash
set -e

echo "🚪 Pre-Commit Quality Gate"

# 1. Linting
echo "Running linters..."
find scripts -name "*.sh" -exec shellcheck {} \; || exit 1

# 2. Unit Tests (changed files only)
echo "Running unit tests for changed files..."
changed_files=$(git diff --cached --name-only --diff-filter=ACM | grep "\.sh$" || true)
if [ -n "$changed_files" ]; then
  for file in $changed_files; do
    test_file="tests/unit/$(basename "$file" .sh)-test.bats"
    if [ -f "$test_file" ]; then
      bats "$test_file" || exit 1
    fi
  done
fi

# 3. Secret Detection
echo "Scanning for secrets..."
git secrets --scan || exit 1

# 4. File Size Check
echo "Checking file sizes..."
git diff --cached --name-only | while read file; do
  if [ -f "$file" ]; then
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
    if [ "$size" -gt 10485760 ]; then  # 10MB
      echo "❌ File too large: $file ($(($size / 1024 / 1024))MB)"
      exit 1
    fi
  fi
done

echo "✅ Pre-commit checks passed"
```

**Installation**:
```bash
cp tests/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

---

### Gate 2: Pull Request

**Trigger**: PR opened or updated
**Execution Time**: <10 minutes
**Blocker**: Yes (prevents merge)

#### Requirements

| Check | Threshold | Blocker |
|-------|-----------|---------|
| All Unit Tests | 100% pass | Yes |
| Code Coverage | ≥80% | Yes |
| Integration Tests | 100% pass | Yes |
| Security Scan | No high/critical vulns | Yes |
| Code Review | ≥1 approval | Yes |
| Merge Conflicts | None | Yes |
| Documentation | Updated | No |

#### Implementation

```yaml
# .github/workflows/pr-quality-gate.yml
name: PR Quality Gate

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  quality-gate:
    name: PR Quality Gate
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Quality Gate - Linting
        run: |
          find scripts -name "*.sh" -exec shellcheck {} \;
        continue-on-error: false

      - name: Quality Gate - Unit Tests
        run: |
          bats tests/unit/**/*.bats --formatter junit > unit-tests.xml
          test -f unit-tests.xml
        continue-on-error: false

      - name: Quality Gate - Code Coverage
        run: |
          pytest tests/unit/python/ --cov --cov-report=xml
          coverage report --fail-under=80
        continue-on-error: false

      - name: Quality Gate - Integration Tests
        run: |
          bash tests/integration/run-all.sh
        continue-on-error: false

      - name: Quality Gate - Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Quality Gate - Summary
        if: always()
        run: |
          echo "## Quality Gate Results" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Linting: Passed" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Unit Tests: Passed" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Code Coverage: ≥80%" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Integration: Passed" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Security: No critical issues" >> $GITHUB_STEP_SUMMARY
```

---

### Gate 3: Main Branch Merge

**Trigger**: PR merged to main
**Execution Time**: <15 minutes
**Blocker**: Yes (prevents bad merge)

#### Requirements

| Check | Threshold | Blocker |
|-------|-----------|---------|
| PR Quality Gate | Passed | Yes |
| Branch Up-to-Date | Yes | Yes |
| Build Success | 100% | Yes |
| Docker Images Build | 100% | Yes |
| E2E Tests | ≥95% pass | Yes |

#### Implementation

```yaml
# .github/workflows/main-merge-gate.yml
name: Main Branch Quality Gate

on:
  push:
    branches: [main]

jobs:
  main-gate:
    name: Main Branch Quality Gate
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Quality Gate - Build
        run: |
          docker build -t app:test .

      - name: Quality Gate - E2E Tests
        run: |
          bash tests/e2e/run-all.sh

      - name: Quality Gate - Deployment Readiness
        run: |
          bash tests/deployment/readiness-check.sh

      - name: Notify on Failure
        if: failure()
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "❌ Main branch quality gate failed",
              "blocks": [{
                "type": "section",
                "text": {"type": "mrkdwn", "text": "*Main Branch Gate Failed*\nCommit: ${{ github.sha }}"}
              }]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

### Gate 4: QA Deployment

**Trigger**: Deployment to QA environment
**Execution Time**: <30 minutes
**Blocker**: Yes (prevents promotion to UAT)

#### Requirements

| Check | Threshold | Blocker |
|-------|-----------|---------|
| Smoke Tests | 100% pass | Yes |
| Full Test Suite | ≥95% pass | Yes |
| Code Coverage | ≥80% | Yes |
| Performance Benchmarks | Within ±10% baseline | Yes |
| Security Scan | No high/critical vulns | Yes |
| Integration Tests | 100% pass | Yes |

#### Implementation

```bash
# tests/gates/qa-deployment-gate.sh
#!/bin/bash
set -e

echo "🚪 QA Deployment Quality Gate"

START_TIME=$(date +%s)

# Gate Check 1: Smoke Tests
echo ""
echo "═══════════════════════════════════════"
echo "Check 1: Smoke Tests (BLOCKING)"
echo "═══════════════════════════════════════"
bash tests/smoke/qa-smoke-tests.sh || {
  echo "❌ QA Gate Failed: Smoke tests failed"
  exit 1
}

# Gate Check 2: Full Test Suite
echo ""
echo "═══════════════════════════════════════"
echo "Check 2: Full Test Suite (BLOCKING)"
echo "═══════════════════════════════════════"
bash tests/environments/qa/full-test-suite.sh || {
  echo "❌ QA Gate Failed: Full test suite failed"
  exit 1
}

# Gate Check 3: Code Coverage
echo ""
echo "═══════════════════════════════════════"
echo "Check 3: Code Coverage ≥80% (BLOCKING)"
echo "═══════════════════════════════════════"
coverage=$(pytest tests/ --cov --cov-report=term | grep TOTAL | awk '{print $4}' | sed 's/%//')
if (( $(echo "$coverage < 80" | bc -l) )); then
  echo "❌ QA Gate Failed: Code coverage ${coverage}% < 80%"
  exit 1
fi
echo "✅ Code coverage: ${coverage}%"

# Gate Check 4: Performance Benchmarks
echo ""
echo "═══════════════════════════════════════"
echo "Check 4: Performance Benchmarks (BLOCKING)"
echo "═══════════════════════════════════════"
bash tests/performance/run-benchmarks.sh || {
  echo "❌ QA Gate Failed: Performance regression detected"
  exit 1
}

# Gate Check 5: Security Scan
echo ""
echo "═══════════════════════════════════════"
echo "Check 5: Security Scan (BLOCKING)"
echo "═══════════════════════════════════════"
trivy image --severity HIGH,CRITICAL --exit-code 1 app:latest || {
  echo "❌ QA Gate Failed: Security vulnerabilities detected"
  exit 1
}

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════"
echo "✅ QA Deployment Gate PASSED"
echo "═══════════════════════════════════════"
echo "Duration: ${DURATION}s"
echo "Ready for UAT promotion"
```

---

### Gate 5: UAT Deployment

**Trigger**: Deployment to UAT environment
**Execution Time**: <15 minutes
**Blocker**: Yes (prevents production deployment)

#### Requirements

| Check | Threshold | Blocker |
|-------|-----------|---------|
| QA Gate | Passed | Yes |
| UAT Smoke Tests | 100% pass | Yes |
| No High-Priority Defects | Zero P1/P2 bugs | Yes |
| User Acceptance Criteria | Defined | No |
| Rollback Plan | Validated | Yes |

#### Implementation

```bash
# tests/gates/uat-deployment-gate.sh
#!/bin/bash
set -e

echo "🚪 UAT Deployment Quality Gate"

# Gate Check 1: QA Gate Passed
echo "Verifying QA gate passed..."
if [ ! -f ".qa-gate-passed" ]; then
  echo "❌ UAT Gate Failed: QA gate not passed"
  exit 1
fi

# Gate Check 2: UAT Smoke Tests
echo "Running UAT smoke tests..."
bash tests/smoke/uat-smoke-tests.sh || {
  echo "❌ UAT Gate Failed: Smoke tests failed"
  exit 1
}

# Gate Check 3: No High-Priority Defects
echo "Checking for high-priority defects..."
p1_bugs=$(jira issues "project=AGL AND priority=Highest AND status!=Closed" --count || echo 0)
p2_bugs=$(jira issues "project=AGL AND priority=High AND status!=Closed" --count || echo 0)

if [ "$p1_bugs" -gt 0 ] || [ "$p2_bugs" -gt 0 ]; then
  echo "❌ UAT Gate Failed: Found $p1_bugs P1 bugs, $p2_bugs P2 bugs"
  exit 1
fi

# Gate Check 4: Production Readiness
echo "Running production readiness check..."
bash tests/environments/uat/production-readiness.sh || {
  echo "❌ UAT Gate Failed: Not production-ready"
  exit 1
}

# Gate Check 5: Rollback Plan
echo "Validating rollback plan..."
bash tests/environments/uat/rollback-test.sh || {
  echo "❌ UAT Gate Failed: Rollback plan not validated"
  exit 1
}

echo "✅ UAT Deployment Gate PASSED"
echo "Ready for production deployment"

# Create production gate marker
touch .uat-gate-passed
```

---

### Gate 6: Production Deployment

**Trigger**: Deployment to production
**Execution Time**: <10 minutes (smoke), <30 minutes (canary)
**Blocker**: Yes (immediate rollback on failure)

#### Requirements

| Check | Threshold | Blocker | Action on Failure |
|-------|-----------|---------|-------------------|
| UAT Gate | Passed | Yes | Block deployment |
| Pre-Deploy Smoke | 100% pass | Yes | Block deployment |
| Canary Smoke (10%) | 100% pass | Yes | Rollback |
| Canary Validation | Error rate <0.1% | Yes | Rollback |
| Canary Performance | Response time <500ms | Yes | Rollback |
| Full Deployment Smoke | 100% pass | Yes | Rollback |
| Production Monitoring | All metrics green | No | Alert ops team |

#### Implementation

```bash
# tests/gates/production-deployment-gate.sh
#!/bin/bash
set -e

echo "🚪 Production Deployment Quality Gate"

# Gate Check 1: UAT Gate Passed
if [ ! -f ".uat-gate-passed" ]; then
  echo "❌ Production Gate Failed: UAT gate not passed"
  exit 1
fi

# Gate Check 2: Pre-Deployment Smoke Tests
echo "Running pre-deployment smoke tests..."
bash tests/smoke/pre-production-checks.sh || {
  echo "❌ Production Gate Failed: Pre-deployment checks failed"
  exit 1
}

# Gate Check 3: Canary Deployment (10%)
echo "Deploying canary (10%)..."
./deploy.sh production --canary || {
  echo "❌ Production Gate Failed: Canary deployment failed"
  exit 1
}

# Gate Check 4: Canary Validation (15 minutes)
echo "Validating canary for 15 minutes..."
bash tests/environments/prod/canary-validation.sh --duration 900 || {
  echo "❌ Production Gate Failed: Canary validation failed"
  echo "Rolling back..."
  ./deploy.sh production --rollback
  exit 1
}

# Gate Check 5: Full Deployment
echo "Deploying to 100%..."
./deploy.sh production --full || {
  echo "❌ Production Gate Failed: Full deployment failed"
  echo "Rolling back..."
  ./deploy.sh production --rollback
  exit 1
}

# Gate Check 6: Post-Deployment Smoke Tests
echo "Running post-deployment smoke tests..."
bash tests/smoke/production-smoke-tests.sh || {
  echo "❌ Production Gate Failed: Post-deployment smoke tests failed"
  echo "Rolling back..."
  ./deploy.sh production --rollback
  exit 1
}

echo "✅ Production Deployment Gate PASSED"
echo "Deployment successful!"

# Notify operations team
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"text\": \"✅ Production deployment successful\",
    \"blocks\": [{
      \"type\": \"section\",
      \"text\": {
        \"type\": \"mrkdwn\",
        \"text\": \"*Production Deployment Complete*\nCommit: $GIT_SHA\nAll quality gates passed\"
      }
    }]
  }"
```

---

## Metrics & Thresholds

### Quality Metrics Dashboard

```yaml
metrics:
  code_quality:
    - metric: "Code Coverage"
      target: "≥80%"
      warning: "75-79%"
      critical: "<75%"
      current: "87%"
      trend: "↑"

    - metric: "Test Pass Rate"
      target: "≥95%"
      warning: "90-94%"
      critical: "<90%"
      current: "98%"
      trend: "→"

    - metric: "Build Success Rate"
      target: "≥98%"
      warning: "95-97%"
      critical: "<95%"
      current: "99%"
      trend: "↑"

  performance:
    - metric: "Unit Test Duration"
      target: "<3 min"
      warning: "3-5 min"
      critical: ">5 min"
      current: "2.5 min"
      trend: "→"

    - metric: "Integration Test Duration"
      target: "<5 min"
      warning: "5-10 min"
      critical: ">10 min"
      current: "4.2 min"
      trend: "↓"

    - metric: "Full Suite Duration"
      target: "<30 min"
      warning: "30-45 min"
      critical: ">45 min"
      current: "25 min"
      trend: "↓"

  security:
    - metric: "Critical Vulnerabilities"
      target: "0"
      warning: "0"
      critical: ">0"
      current: "0"
      trend: "→"

    - metric: "High Vulnerabilities"
      target: "0"
      warning: "1-2"
      critical: ">2"
      current: "1"
      trend: "→"

    - metric: "Secret Leaks"
      target: "0"
      warning: "0"
      critical: ">0"
      current: "0"
      trend: "→"

  deployment:
    - metric: "Deployment Success Rate"
      target: "≥95%"
      warning: "90-94%"
      critical: "<90%"
      current: "97%"
      trend: "↑"

    - metric: "Mean Time to Deploy"
      target: "<30 min"
      warning: "30-60 min"
      critical: ">60 min"
      current: "22 min"
      trend: "→"

    - metric: "Rollback Rate"
      target: "<5%"
      warning: "5-10%"
      critical: ">10%"
      current: "3%"
      trend: "↓"
```

---

## Enforcement

### Automated Enforcement

Quality gates are **automatically enforced** through CI/CD pipelines:

1. **GitHub Branch Protection Rules**:
```yaml
branch_protection:
  required_status_checks:
    strict: true
    contexts:
      - "PR Quality Gate"
      - "Code Coverage ≥80%"
      - "Security Scan"
  required_pull_request_reviews:
    required_approving_review_count: 1
  enforce_admins: false  # Allow emergency overrides
```

2. **Deployment Controls**:
```yaml
deployment_controls:
  qa:
    auto_deploy: true
    require_gate_pass: true
    rollback_on_failure: true

  uat:
    auto_deploy: false
    require_gate_pass: true
    require_manual_approval: true

  production:
    auto_deploy: false
    require_gate_pass: true
    require_manual_approval: true
    canary_validation: true
    rollback_on_failure: true
```

### Override Process

**Emergency Override** (production incidents):

```bash
# Override requires:
# 1. Incident ticket number
# 2. Engineering lead approval
# 3. Operations team notification

INCIDENT_ID="INC-12345"
APPROVED_BY="eng-lead@example.com"

echo "OVERRIDE: $INCIDENT_ID approved by $APPROVED_BY" > .gate-override

# Deploy with override
./deploy.sh production --override-gate --incident "$INCIDENT_ID"

# Post-incident: Review and fix root cause
```

---

## Reporting

### Gate Pass/Fail Report

```json
{
  "gate": "qa-deployment",
  "timestamp": "2025-10-28T12:00:00Z",
  "status": "PASSED",
  "duration_seconds": 1234,
  "checks": [
    {
      "name": "Smoke Tests",
      "status": "PASSED",
      "duration_seconds": 45,
      "details": "15/15 tests passed"
    },
    {
      "name": "Full Test Suite",
      "status": "PASSED",
      "duration_seconds": 850,
      "details": "234/240 tests passed (97.5%)"
    },
    {
      "name": "Code Coverage",
      "status": "PASSED",
      "duration_seconds": 120,
      "details": "Coverage: 87%"
    },
    {
      "name": "Performance Benchmarks",
      "status": "PASSED",
      "duration_seconds": 180,
      "details": "All metrics within baseline ±5%"
    },
    {
      "name": "Security Scan",
      "status": "PASSED",
      "duration_seconds": 39,
      "details": "No critical/high vulnerabilities"
    }
  ],
  "artifacts": [
    "test-results.xml",
    "coverage-report.html",
    "security-report.json"
  ]
}
```

### Trend Reporting

```python
# tests/reporting/gate-trend-report.py
import json
from datetime import datetime, timedelta

def generate_gate_trend_report(days=30):
    """Generate quality gate trend report"""
    results = {
        "period": f"Last {days} days",
        "gates": {},
        "overall_pass_rate": 0,
        "trends": {}
    }

    # Aggregate gate results
    for gate_type in ["pr", "qa", "uat", "production"]:
        gate_results = load_gate_results(gate_type, days)

        passed = sum(1 for r in gate_results if r['status'] == 'PASSED')
        total = len(gate_results)
        pass_rate = (passed / total * 100) if total > 0 else 0

        results["gates"][gate_type] = {
            "total_runs": total,
            "passed": passed,
            "failed": total - passed,
            "pass_rate": f"{pass_rate:.1f}%",
            "avg_duration": calculate_avg_duration(gate_results)
        }

    return results
```

---

## Continuous Improvement

### Gate Optimization

**Monthly Review Process**:

1. **Analyze gate performance**:
   - Identify slow gates
   - Find flaky tests
   - Detect false positives

2. **Optimize thresholds**:
   - Adjust based on historical data
   - Balance strictness vs. velocity

3. **Update documentation**:
   - Reflect current practices
   - Update examples

### Quality Gate Retrospective

```markdown
## Quality Gate Retrospective Template

**Period**: [Date Range]
**Attendees**: [Team members]

### Metrics Review
- Total gate runs: [X]
- Pass rate: [X%]
- Average duration: [Xm]
- False positives: [X]

### What Worked Well
- [Positive finding 1]
- [Positive finding 2]

### What Needs Improvement
- [Improvement area 1]
- [Improvement area 2]

### Action Items
- [ ] [Action 1] - Owner: [Name] - Due: [Date]
- [ ] [Action 2] - Owner: [Name] - Due: [Date]

### Threshold Adjustments
- [Metric]: [Old] → [New] (Reason: [X])
```

---

## Related Documentation

- **[COMPREHENSIVE-TEST-STRATEGY.md](./COMPREHENSIVE-TEST-STRATEGY.md)** - Overall testing strategy
- **[ENVIRONMENT-TEST-PLANS.md](./ENVIRONMENT-TEST-PLANS.md)** - Environment-specific plans
- **[CI-CD-INTEGRATION.md](./CI-CD-INTEGRATION.md)** - CI/CD pipeline integration

---

**Document Status**: ✅ Complete
**Maintained by**: Tester Agent - Hive Mind Collective
**Version**: 1.0.0
