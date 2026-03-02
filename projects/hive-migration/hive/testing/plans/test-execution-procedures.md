# Test Execution Procedures
## API1 to API8 Migration Testing

**Purpose**: Step-by-step guide for executing all testing activities
**Audience**: QA Engineers, DevOps, Developers
**Prerequisites**: Test environment access, test data prepared

---

## Overview

This document provides detailed procedures for executing the complete test suite for the API1 to API8 migration project.

### Test Suite Components
1. **Smoke Tests**: 5-10 minutes, critical functionality
2. **Functional Tests**: 30-60 minutes, all endpoints
3. **Integration Tests**: 1-2 hours, multi-component workflows
4. **Performance Tests**: 2-4 hours, load and stress testing
5. **Security Tests**: 2-3 hours, vulnerability assessment
6. **Regression Tests**: 30-45 minutes, prevent breakage
7. **Data Integrity Tests**: Ongoing, validate data consistency

---

## Pre-Execution Checklist

### Environment Preparation
- [ ] Test environment accessible
- [ ] API1 endpoint confirmed: `https://api.falg.com.br`
- [ ] API8 endpoint confirmed: `[TBD]`
- [ ] Test database initialized
- [ ] Test user accounts created
- [ ] Authentication tokens ready
- [ ] Monitoring tools configured
- [ ] Log access verified

### Test Data Preparation
- [ ] Test data loaded
- [ ] Database seeded
- [ ] Test files prepared
- [ ] Mock services configured
- [ ] Baseline metrics captured

### Tools and Access
- [ ] curl installed and working
- [ ] jq installed for JSON parsing
- [ ] MySQL client installed
- [ ] Test scripts downloaded
- [ ] Results directory created
- [ ] SSH access to servers (if needed)

---

## Procedure 1: Execute Smoke Tests

**When**: Before any deployment, after every build
**Duration**: 5-10 minutes
**Required Pass Rate**: 100%

### Step-by-Step

1. **Navigate to test directory**:
```bash
cd /mnt/overpower/apps/dev/agl/hostman/hive/testing/scripts
```

2. **Set environment variables**:
```bash
export API_URL="https://api.falg.com.br"
export TEST_USER_EMAIL="test@example.com"
export TEST_USER_PASSWORD="YourSecurePassword"
```

3. **Run smoke tests**:
```bash
chmod +x smoke-test-suite.sh
./smoke-test-suite.sh
```

4. **Review results**:
```bash
cat ../results/smoke-test-$(date +%Y%m%d).txt
```

5. **Decision point**:
   - ✅ All passed → Proceed to next phase
   - ❌ Any failed → STOP, investigate, fix, retest

### Expected Output
```
=========================================
Smoke Test Summary
=========================================
Total Tests:   10
Passed:        10
Failed:        0
Skipped:       0
=========================================
Pass Rate:     100%

✅ SMOKE TESTS PASSED - SAFE TO PROCEED
```

---

## Procedure 2: Execute Functional Tests

**When**: After smoke tests pass, per build
**Duration**: 30-60 minutes
**Required Pass Rate**: 95%+

### Step-by-Step

1. **Review endpoint list**:
```bash
cat ../plans/endpoints-to-test.txt
```

2. **Execute functional test suite**:
```bash
./functional-test-suite.sh --api1 --api8 --compare
```

3. **Monitor execution**:
```bash
# In another terminal
tail -f ../results/functional-tests.log
```

4. **Wait for completion**:
   - Tests run sequentially
   - Progress shown in real-time
   - Failures logged immediately

5. **Review results**:
```bash
cat ../results/functional-test-report-$(date +%Y%m%d).md
```

6. **Compare API1 vs API8**:
```bash
./compare-api-results.sh \
  ../results/api1-functional.json \
  ../results/api8-functional.json
```

### Expected Output
```
Functional Test Results:
  Total Endpoints: 42
  API1 Passed: 42 (100%)
  API8 Passed: 41 (97.6%)
  Parity Issues: 1

Failed Tests:
  - API8: /api/users/export (500 error)

Pass Rate: 97.6% (Above 95% threshold ✅)
```

---

## Procedure 3: Execute Integration Tests

**When**: Daily, pre-deployment
**Duration**: 1-2 hours
**Required Pass Rate**: 95%+

### Step-by-Step

1. **Prepare test environment**:
```bash
./setup-integration-test-data.sh
```

2. **Execute integration suite**:
```bash
./integration-test-suite.sh --verbose
```

3. **Monitor multi-step workflows**:
```bash
tail -f ../results/integration-tests.log | grep "Workflow"
```

4. **Review results**:
```bash
cat ../results/integration-test-report-$(date +%Y%m%d).md
```

5. **Cleanup test data**:
```bash
./cleanup-integration-test-data.sh
```

### Expected Output
```
Integration Test Results:
  Total Scenarios: 10
  Passed: 10 (100%)
  Failed: 0

All critical workflows validated ✅
```

---

## Procedure 4: Execute Performance Tests

**When**: Weekly, pre-production
**Duration**: 2-4 hours
**Required**: API8 ≤ 110% API1 metrics

### Step-by-Step

1. **Capture API1 baseline** (if not already done):
```bash
./capture-performance-baseline.sh \
  --api https://api.falg.com.br \
  --output ../results/api1-baseline.json
```

2. **Execute API8 performance tests**:
```bash
./performance-test-suite.sh \
  --api $API8_URL \
  --baseline ../results/api1-baseline.json \
  --duration 3600  # 1 hour
```

3. **Monitor system resources**:
```bash
# In separate terminals
htop
watch -n 1 'mysqladmin processlist'
```

4. **Run comparative analysis**:
```bash
./compare-performance.sh \
  ../results/api1-baseline.json \
  ../results/api8-performance.json \
  > ../reports/performance-comparison.md
```

5. **Review results**:
```bash
cat ../reports/performance-comparison.md
```

### Expected Output
```
Performance Comparison:
  Metric              API1      API8      Diff    Status
  --------------------------------------------------
  Avg Response Time   156ms     142ms     -9%     ✅
  95th Percentile     423ms     398ms     -6%     ✅
  Throughput          245 rps   257 rps   +5%     ✅
  Error Rate          0.02%     0.01%     -50%    ✅

Overall: API8 MEETS PERFORMANCE REQUIREMENTS ✅
```

---

## Procedure 5: Execute Security Tests

**When**: Weekly, pre-production, after security changes
**Duration**: 2-3 hours
**Required**: Zero critical vulnerabilities

### Step-by-Step

1. **Review security checklist**:
```bash
cat ../plans/security-testing.md
```

2. **Execute security test suite**:
```bash
./security-test-suite.sh --target $API8_URL
```

3. **Run OWASP ZAP scan** (if available):
```bash
zap-cli quick-scan --self-contained \
  --spider \
  -r security-scan-report.html \
  $API8_URL
```

4. **Test authentication and authorization**:
```bash
./test-auth-security.sh
```

5. **Test for common vulnerabilities**:
```bash
./test-sql-injection.sh
./test-xss-prevention.sh
./test-csrf-protection.sh
```

6. **Review results**:
```bash
cat ../results/security-test-report-$(date +%Y%m%d).md
```

### Expected Output
```
Security Test Results:
  Total Tests: 18
  Passed: 18 (100%)
  Warnings: 2 (non-critical)
  Critical Issues: 0 ✅

Warnings:
  - X-Powered-By header present (info disclosure)
  - Rate limiting threshold could be lower

Overall: SECURITY VALIDATION PASSED ✅
```

---

## Procedure 6: Execute Regression Tests

**When**: Every build, every merge
**Duration**: 30-45 minutes
**Required Pass Rate**: 98%+

### Step-by-Step

1. **Execute regression suite**:
```bash
./regression-test-suite.sh --level full
```

2. **For quick regression** (5-10 mins):
```bash
./regression-test-suite.sh --level core
```

3. **Review results**:
```bash
cat ../results/regression-test-report-$(date +%Y%m%d).md
```

4. **Check for new failures**:
```bash
./compare-regression-results.sh \
  ../results/previous-regression.json \
  ../results/current-regression.json
```

### Expected Output
```
Regression Test Results:
  Total Tests: 247
  Passed: 243 (98.4%)
  Failed: 3 (1.2%)
  New Failures: 1

Failed Tests:
  REG-FEAT-089: Search pagination
  REG-BUG-124: File upload timeout
  REG-PERF-015: Response time threshold

New Failure:
  REG-FEAT-089: Started failing today

Action Required: Investigate REG-FEAT-089
```

---

## Procedure 7: Validate Data Integrity

**When**: During migration, daily monitoring
**Duration**: 15-30 minutes
**Required**: 100% data integrity

### Step-by-Step

1. **Count records**:
```bash
./validate-record-counts.sh
```

2. **Verify primary keys**:
```bash
./validate-primary-keys.sh
```

3. **Check foreign key integrity**:
```bash
./validate-foreign-keys.sh
```

4. **Compare data samples**:
```bash
./compare-data-samples.sh --sample-size 1000
```

5. **Generate integrity report**:
```bash
./generate-data-integrity-report.sh \
  > ../reports/data-integrity-$(date +%Y%m%d).md
```

### Expected Output
```
Data Integrity Report:

Record Counts:
  users:        API1: 10,234 | API8: 10,234 ✅
  resources:    API1: 45,678 | API8: 45,678 ✅
  transactions: API1: 123,456 | API8: 123,456 ✅

Primary Keys: 100% match ✅
Foreign Keys: 100% valid ✅
Data Content: 1000/1000 samples match ✅

Overall: DATA INTEGRITY VERIFIED ✅
```

---

## Procedure 8: Full Test Suite Execution

**When**: Pre-production, weekly
**Duration**: 8-12 hours
**Required**: All tests pass

### Comprehensive Test Execution

```bash
#!/bin/bash
# run-all-tests.sh - Execute complete test suite

echo "Starting Full Test Suite Execution"
echo "Date: $(date)"
echo "===================================="

# 1. Smoke Tests (BLOCKING)
echo "Phase 1: Smoke Tests"
if ! ./smoke-test-suite.sh; then
  echo "❌ Smoke tests failed. Stopping."
  exit 1
fi

# 2. Functional Tests
echo "Phase 2: Functional Tests"
./functional-test-suite.sh --api1 --api8

# 3. Integration Tests
echo "Phase 3: Integration Tests"
./integration-test-suite.sh

# 4. Regression Tests
echo "Phase 4: Regression Tests"
./regression-test-suite.sh --level full

# 5. Performance Tests
echo "Phase 5: Performance Tests"
./performance-test-suite.sh

# 6. Security Tests
echo "Phase 6: Security Tests"
./security-test-suite.sh

# 7. Data Integrity
echo "Phase 7: Data Integrity Validation"
./validate-data-integrity.sh

# 8. Generate comprehensive report
echo "Generating Comprehensive Report"
./generate-comprehensive-report.sh \
  > ../reports/full-test-suite-$(date +%Y%m%d).md

echo "===================================="
echo "Full Test Suite Complete"
echo "Review: ../reports/full-test-suite-$(date +%Y%m%d).md"
```

---

## Test Result Interpretation

### Result Categories

**✅ PASS**: Test passed successfully
- Action: No action required
- Continue to next test

**❌ FAIL**: Test failed
- Action: Investigate immediately
- Log defect
- Fix and retest

**⚠ WARN**: Test passed with warnings
- Action: Review warning
- Decide if action needed
- Document decision

**⏭ SKIP**: Test skipped
- Action: Understand why
- Re-enable if possible

### Decision Matrix

| Smoke | Functional | Integration | Regression | Decision |
|-------|------------|-------------|------------|----------|
| ✅ | ✅ | ✅ | ✅ | ✅ DEPLOY |
| ✅ | ✅ | ✅ | ⚠ | ✅ DEPLOY with caution |
| ✅ | ✅ | ⚠ | ✅ | ✅ DEPLOY with monitoring |
| ✅ | ❌ | - | - | ❌ DO NOT DEPLOY |
| ❌ | - | - | - | ❌ DO NOT DEPLOY |

---

## Troubleshooting

### Common Issues

#### Issue: Tests timing out
**Solution**:
```bash
# Increase timeout
export TEST_TIMEOUT=30  # seconds

# Or test endpoint directly
curl --max-time 30 "$API_URL/api/endpoint"
```

#### Issue: Authentication failures
**Solution**:
```bash
# Verify credentials
echo "User: $TEST_USER_EMAIL"
echo "Pass: [hidden]"

# Test login manually
curl -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'"$TEST_USER_EMAIL"'","password":"'"$TEST_USER_PASSWORD"'"}'
```

#### Issue: Database connection errors
**Solution**:
```bash
# Test database connectivity
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SELECT 1"

# Check API health endpoint
curl "$API_URL/health/db"
```

#### Issue: Inconsistent test results
**Solution**:
```bash
# Reset test environment
./reset-test-environment.sh

# Clear caches
./clear-all-caches.sh

# Run tests again
./smoke-test-suite.sh
```

---

## Post-Execution Tasks

### After Test Completion

1. **Archive results**:
```bash
tar -czf test-results-$(date +%Y%m%d-%H%M).tar.gz results/
mv test-results-*.tar.gz archive/
```

2. **Update test metrics**:
```bash
./update-test-metrics.sh
```

3. **Generate trend report**:
```bash
./generate-trend-report.sh --last 7
```

4. **Notify stakeholders**:
```bash
./send-test-report-email.sh \
  --recipients "team@example.com" \
  --report ../reports/full-test-suite-$(date +%Y%m%d).md
```

5. **Log defects** (if any):
```bash
# Create defect tickets
./create-defect-tickets.sh --from-results ../results/
```

---

## Continuous Integration

### Automated Test Execution

Tests run automatically on:
- Every commit → Smoke tests
- Merge to main → Core regression
- Tagged release → Full test suite
- Nightly → Performance + full regression
- Weekly → Security scan

### CI/CD Pipeline

```yaml
test:
  script:
    - ./hive/testing/scripts/smoke-test-suite.sh
    - ./hive/testing/scripts/regression-test-suite.sh --level core
  artifacts:
    reports:
      junit: results/junit.xml
    paths:
      - results/
    expire_in: 30 days
```

---

## Contact and Escalation

### Test Execution Issues
- Primary: QA Team Lead
- Secondary: DevOps Team

### Test Failures
- Critical: Immediate escalation to Dev Team Lead
- High: Report within 2 hours
- Medium: Report within 1 day
- Low: Include in daily report

### Environment Issues
- DevOps Team (24/7 on-call)

---

## Appendix: Quick Reference

### Essential Commands

```bash
# Quick smoke test
./smoke-test-suite.sh

# Full test suite
./run-all-tests.sh

# Test specific endpoint
./test-endpoint.sh /api/users GET

# Compare API1 vs API8
./compare-apis.sh

# Generate report
./generate-comprehensive-report.sh

# Reset environment
./reset-test-environment.sh
```

### File Locations

- Test Plans: `/mnt/overpower/apps/dev/agl/hostman/hive/testing/plans/`
- Test Scripts: `/mnt/overpower/apps/dev/agl/hostman/hive/testing/scripts/`
- Test Results: `/mnt/overpower/apps/dev/agl/hostman/hive/testing/results/`
- Test Reports: `/mnt/overpower/apps/dev/agl/hostman/hive/testing/reports/`

### Environment Variables

```bash
# API endpoints
export API1_URL="https://api.falg.com.br"
export API8_URL="https://api8.example.com"

# Authentication
export TEST_USER_EMAIL="test@example.com"
export TEST_USER_PASSWORD="SecurePassword123!"

# Database
export DB_HOST="localhost"
export DB_NAME="api8_test"
export DB_USER="test_user"
export DB_PASS="test_password"

# Timeouts
export TEST_TIMEOUT=30
export HTTP_TIMEOUT=10
```

---

**Document Version**: 1.0
**Author**: Hive Mind TESTER Agent
**Date**: 2025-10-13
**Status**: Ready for Use

---

*"Good testing is not expensive. Bad testing is."*
