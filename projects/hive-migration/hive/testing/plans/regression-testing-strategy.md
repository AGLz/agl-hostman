# Regression Testing Strategy
## API1 to API8 Migration

**Purpose**: Prevent functionality degradation during migration and ensure no existing features break
**Scope**: Continuous validation of previously working functionality
**Approach**: Automated regression suite with smart test selection

---

## Regression Testing Philosophy

> "Regression testing is insurance against the future. Every bug fixed today is a test case for tomorrow."

### Core Principles
1. **Test What Worked**: Verify previously functional features remain functional
2. **Test What Was Fixed**: Ensure bugs don't resurface
3. **Test What's Critical**: Prioritize high-value functionality
4. **Automate Everything**: Manual regression is unsustainable
5. **Run Often**: Regression tests should run on every change

---

## Regression Test Categories

### 1. Defect-Based Regression Tests
**Purpose**: Ensure fixed bugs don't reappear

**Process**:
```
Bug Found → Bug Fixed → Test Created → Added to Regression Suite
```

**Test Template**:
```markdown
### REG-BUG-{ID}: {Bug Title}
**Original Issue**: {Defect ID}
**Fixed In**: {Version/Commit}
**Severity**: Critical/High/Medium/Low

**Reproduction Steps**:
1. [Step 1]
2. [Step 2]
3. [Expected failure condition]

**Verification Steps**:
1. [Step 1]
2. [Step 2]
3. [Expected success condition]

**Pass Criteria**: Bug does not recur
```

**Example**:
```markdown
### REG-BUG-042: Authentication Token Not Refreshed
**Original Issue**: JIRA-1234
**Fixed In**: v2.3.1
**Severity**: High

**Reproduction Steps** (Original):
1. Login and obtain token
2. Wait for token expiration (30 min)
3. Make authenticated request
4. Expected: 401 error (Original behavior)

**Verification Steps**:
1. Login and obtain token
2. Wait for token expiration
3. Make authenticated request
4. Expected: Token auto-refreshed OR proper 401 with refresh instructions

**Pass Criteria**: No silent auth failures
```

---

### 2. Feature-Based Regression Tests
**Purpose**: Verify core features continue working

**Test Organization**:
```
Feature: User Authentication
  ├─ REG-FEAT-001: Login with valid credentials
  ├─ REG-FEAT-002: Login failure with invalid credentials
  ├─ REG-FEAT-003: Logout functionality
  ├─ REG-FEAT-004: Password reset flow
  └─ REG-FEAT-005: Session timeout handling

Feature: Resource Management
  ├─ REG-FEAT-010: Create resource
  ├─ REG-FEAT-011: Read resource
  ├─ REG-FEAT-012: Update resource
  ├─ REG-FEAT-013: Delete resource
  └─ REG-FEAT-014: List resources with pagination
```

**Coverage Goal**: 100% of P1 features, 80% of P2 features

---

### 3. Critical Path Regression Tests
**Purpose**: Validate essential business workflows

**Critical Paths** (Examples - TBD based on actual endpoints):
```
1. User Onboarding Flow
   └─ Register → Verify Email → Complete Profile → First Login

2. Core Transaction Flow
   └─ Create Order → Process Payment → Update Inventory → Send Confirmation

3. Data Management Flow
   └─ Upload Data → Validate → Process → Store → Retrieve → Display

4. Reporting Flow
   └─ Request Report → Generate → Cache → Download
```

**Test Frequency**: Every build, every deployment

---

### 4. API Contract Regression Tests
**Purpose**: Ensure API contracts remain stable

**What to Test**:
- Request/response schemas unchanged
- Status codes consistent
- Error formats consistent
- Authentication mechanisms stable
- Rate limiting behavior unchanged

**Contract Test Example**:
```json
{
  "endpoint": "/api/users/{id}",
  "method": "GET",
  "expectedStatus": 200,
  "responseSchema": {
    "type": "object",
    "required": ["id", "name", "email"],
    "properties": {
      "id": {"type": "integer"},
      "name": {"type": "string"},
      "email": {"type": "string", "format": "email"},
      "created_at": {"type": "string", "format": "date-time"}
    }
  }
}
```

**Validation**:
- Schema validation on every response
- No breaking changes to existing contracts
- Deprecation warnings for planned changes

---

### 5. Performance Regression Tests
**Purpose**: Detect performance degradation

**Baseline Metrics** (Per Endpoint):
- Average response time
- 95th percentile response time
- Throughput (requests/second)
- Error rate

**Regression Threshold**:
- Response time degradation > 10%: Warning
- Response time degradation > 25%: Failure
- Error rate increase > 1%: Warning
- Error rate increase > 5%: Failure

**Monitoring**:
```bash
# Compare current performance to baseline
compare_performance() {
  current_avg=$(measure_current_response_time)
  baseline_avg=$(load_baseline_response_time)

  degradation=$(calculate_percentage_change $baseline_avg $current_avg)

  if [ $degradation -gt 25 ]; then
    echo "FAIL: Performance degraded by ${degradation}%"
    exit 1
  elif [ $degradation -gt 10 ]; then
    echo "WARN: Performance degraded by ${degradation}%"
  else
    echo "PASS: Performance within acceptable range"
  fi
}
```

---

### 6. Security Regression Tests
**Purpose**: Ensure security measures aren't compromised

**Test Areas**:
- Authentication bypass attempts
- Authorization checks
- Input validation
- SQL injection prevention
- XSS prevention
- CSRF protection
- Sensitive data exposure

**Test Example**:
```bash
# SQL Injection Regression Test
test_sql_injection_prevention() {
  malicious_inputs=(
    "' OR '1'='1"
    "'; DROP TABLE users; --"
    "1' UNION SELECT * FROM users--"
  )

  for payload in "${malicious_inputs[@]}"; do
    response=$(curl -s -w "%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/users?name=$payload")

    if [[ $response == *"500"* ]] || [[ $response == *"error"* ]]; then
      echo "FAIL: SQL injection vulnerability detected"
      return 1
    fi
  done

  echo "PASS: SQL injection tests passed"
  return 0
}
```

---

## Regression Test Selection Strategy

### Smart Test Selection (STS)
Not all regression tests need to run for every change. Use impact analysis to select relevant tests.

**Selection Criteria**:
1. **Code Coverage**: Tests covering changed files
2. **Dependency Analysis**: Tests for dependent components
3. **Historical Failures**: Tests that failed recently
4. **Risk Assessment**: High-risk area tests
5. **Time Budget**: Critical path tests first

**Example Algorithm**:
```python
def select_regression_tests(changed_files, time_budget):
    """Smart test selection based on changes and time available"""

    # Always run these
    critical_tests = get_critical_path_tests()

    # Select based on code coverage
    coverage_tests = get_tests_covering_files(changed_files)

    # Select based on dependencies
    dependency_tests = get_dependent_tests(changed_files)

    # Combine and deduplicate
    selected = set(critical_tests + coverage_tests + dependency_tests)

    # Sort by priority and estimated duration
    sorted_tests = sort_by_priority_and_duration(selected)

    # Fit within time budget
    final_selection = fit_to_time_budget(sorted_tests, time_budget)

    return final_selection
```

---

## Regression Test Suite Structure

### Test Suite Levels

**Level 1: Smoke Regression** (5-10 minutes)
- Top 20 critical endpoints
- Authentication flows
- Core CRUD operations
- Run: On every commit

**Level 2: Core Regression** (30-45 minutes)
- All P1 functionality
- Recent defect tests
- Critical business flows
- Run: On merge to main branch

**Level 3: Full Regression** (2-4 hours)
- All automated tests
- All features
- All known defects
- Edge cases
- Run: Nightly, pre-deployment

**Level 4: Extended Regression** (8+ hours)
- Full regression + manual tests
- Exploratory testing
- Visual regression
- Cross-browser/platform testing
- Run: Weekly, pre-release

---

## Test Data Management for Regression

### Data Strategies

**1. Static Test Data**:
- Fixed dataset for consistent results
- Version controlled test data
- Reset before each run

**2. Dynamic Test Data**:
- Generated per test run
- Randomized within constraints
- Cleaned up after run

**3. Production-Like Data**:
- Anonymized production snapshots
- Realistic data patterns
- Updated periodically

### Data Reset Strategy
```bash
#!/bin/bash
# Reset test database for regression tests

reset_regression_data() {
  echo "Resetting regression test data..."

  # Drop and recreate database
  mysql -u root -e "DROP DATABASE IF EXISTS test_regression"
  mysql -u root -e "CREATE DATABASE test_regression"

  # Load schema
  mysql -u root test_regression < schema.sql

  # Load seed data
  mysql -u root test_regression < regression_seed_data.sql

  echo "Test data ready"
}
```

---

## Regression Test Automation

### Framework Requirements
- **Language**: Bash/Python/PHP (based on project stack)
- **Test Runner**: PHPUnit, pytest, or custom
- **Assertions**: HTTP status, JSON validation, schema validation
- **Reporting**: JUnit XML, HTML reports, test trends
- **CI Integration**: Jenkins, GitLab CI, GitHub Actions

### Sample Test Structure
```bash
#!/bin/bash
# Regression test script template

# Configuration
API_BASE_URL="${API_URL:-https://api.falg.com.br}"
AUTH_TOKEN="${AUTH_TOKEN:-}"

# Test helper functions
assert_status() {
  expected=$1
  actual=$2
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL: Expected status $expected, got $actual"
    return 1
  fi
  return 0
}

assert_json_field() {
  json=$1
  field=$2
  expected=$3
  actual=$(echo "$json" | jq -r ".$field")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: Expected $field=$expected, got $actual"
    return 1
  fi
  return 0
}

# REG-FEAT-001: Login with valid credentials
test_login_valid_credentials() {
  echo "Running: REG-FEAT-001 - Login with valid credentials"

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"password123"}')

  body=$(echo "$response" | head -n -1)
  status=$(echo "$response" | tail -n 1)

  assert_status 200 "$status" || return 1
  assert_json_field "$body" "success" "true" || return 1

  token=$(echo "$body" | jq -r '.data.token')
  if [ -z "$token" ] || [ "$token" == "null" ]; then
    echo "FAIL: Token not returned"
    return 1
  fi

  echo "PASS: REG-FEAT-001"
  return 0
}

# REG-BUG-042: Token refresh handling
test_token_refresh() {
  echo "Running: REG-BUG-042 - Token refresh handling"

  # Login
  login_response=$(curl -s "$API_BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"password123"}')

  token=$(echo "$login_response" | jq -r '.data.token')

  # Make request with valid token
  response=$(curl -s -w "%{http_code}" \
    -H "Authorization: Bearer $token" \
    "$API_BASE_URL/api/user/profile")

  status="${response: -3}"

  if [ "$status" -ne 200 ]; then
    echo "FAIL: Could not access profile with valid token"
    return 1
  fi

  echo "PASS: REG-BUG-042"
  return 0
}

# Run all regression tests
run_regression_suite() {
  echo "Starting regression test suite..."
  echo "API URL: $API_BASE_URL"
  echo "================================"

  passed=0
  failed=0

  tests=(
    test_login_valid_credentials
    test_token_refresh
    # Add more tests here
  )

  for test in "${tests[@]}"; do
    if $test; then
      ((passed++))
    else
      ((failed++))
    fi
    echo ""
  done

  echo "================================"
  echo "Regression Test Results:"
  echo "  Passed: $passed"
  echo "  Failed: $failed"
  echo "================================"

  if [ $failed -gt 0 ]; then
    exit 1
  fi

  exit 0
}

# Execute
run_regression_suite
```

---

## Regression Test Maintenance

### When to Add Tests
1. ✅ Every bug fix → Add defect-based regression test
2. ✅ New feature complete → Add feature regression tests
3. ✅ Critical path changes → Update critical path tests
4. ✅ API contract changes → Update contract tests

### When to Remove Tests
1. ❌ Feature deprecated/removed
2. ❌ Test no longer valid
3. ❌ Test duplicates another test
4. ❌ Test consistently fails due to environment (fix environment instead!)

### When to Update Tests
1. 🔄 API contract legitimately changes
2. 🔄 Expected behavior intentionally changes
3. 🔄 Test data requirements change
4. 🔄 Test becomes flaky (fix flakiness!)

### Test Review Process
- **Monthly**: Review all regression tests
- **Quarterly**: Audit test coverage
- **Annually**: Comprehensive test suite refactor

---

## Handling Test Failures

### Failure Analysis Workflow
```
Test Fails
    ↓
Is it a real bug? ───Yes───> Report defect, fix
    │
    No
    ↓
Is test incorrect? ───Yes───> Update test
    │
    No
    ↓
Is environment issue? ───Yes───> Fix environment
    │
    No
    ↓
Is test flaky? ───Yes───> Fix flakiness or mark as quarantine
```

### Quarantine Strategy
For flaky tests that can't be immediately fixed:
```yaml
# quarantine.yml
quarantined_tests:
  - test_id: REG-FEAT-042
    reason: "Intermittent timing issue"
    quarantined_date: "2025-10-01"
    owner: "john@example.com"
    status: "investigating"
```

**Quarantine Rules**:
- Maximum quarantine period: 2 weeks
- Must have assigned owner
- Must have investigation status
- Report quarantined tests daily
- Fix or remove after maximum period

---

## Regression Testing Metrics

### Key Metrics
1. **Test Pass Rate**: % of tests passing
2. **Test Execution Time**: Duration of suite
3. **Test Coverage**: % of code covered
4. **Defect Detection Rate**: Bugs found by regression tests
5. **False Positive Rate**: % of false failures
6. **Test Maintenance Time**: Time spent updating tests

### Target Metrics
- Pass Rate: > 95%
- Execution Time: < 2 hours (full suite)
- Code Coverage: > 80%
- False Positive Rate: < 2%

### Reporting Dashboard
```markdown
## Regression Test Health Dashboard
**Last Updated**: 2025-10-13 15:30

### Test Execution Summary
- Total Tests: 247
- Passed: 243 (98.4%)
- Failed: 3 (1.2%)
- Quarantined: 1 (0.4%)
- Execution Time: 1h 23m

### Trend (Last 7 Days)
- Pass Rate: 97.2% → 98.4% ✅
- Execution Time: 1h 31m → 1h 23m ✅
- Coverage: 82.1% → 83.7% ✅

### Failed Tests
1. REG-FEAT-089: Search pagination (investigating)
2. REG-BUG-124: File upload timeout (environment issue)
3. REG-PERF-015: Response time threshold (performance regression)

### Action Items
- [ ] Fix REG-FEAT-089 by EOD
- [ ] Increase file upload timeout
- [ ] Investigate performance regression in search endpoint
```

---

## CI/CD Integration

### Pipeline Configuration
```yaml
# .gitlab-ci.yml example
stages:
  - test
  - deploy

regression-smoke:
  stage: test
  script:
    - ./hive/testing/scripts/run-smoke-regression.sh
  only:
    - branches
  timeout: 10 minutes

regression-core:
  stage: test
  script:
    - ./hive/testing/scripts/run-core-regression.sh
  only:
    - main
  timeout: 45 minutes

regression-full:
  stage: test
  script:
    - ./hive/testing/scripts/run-full-regression.sh
  only:
    - tags
  timeout: 4 hours
  allow_failure: false  # Block deployment on failure

deploy:
  stage: deploy
  script:
    - ./deploy.sh
  only:
    - tags
  when: on_success  # Only deploy if tests pass
```

---

## Best Practices

1. **Keep Tests Fast**: Slow tests don't get run
2. **Keep Tests Isolated**: No dependencies between tests
3. **Keep Tests Deterministic**: Same input = same output
4. **Keep Tests Simple**: Easy to understand and maintain
5. **Keep Tests Updated**: Review and refactor regularly
6. **Keep Tests Relevant**: Remove obsolete tests
7. **Keep Tests Visible**: Make results easily accessible

---

## Next Steps

1. **Immediate**:
   - Create initial regression test suite based on critical paths
   - Set up CI pipeline integration
   - Establish baseline metrics

2. **Short-term**:
   - Add defect-based tests for all known bugs
   - Implement smart test selection
   - Create reporting dashboard

3. **Ongoing**:
   - Maintain test suite
   - Monitor metrics
   - Optimize execution time

---

**Document Version**: 1.0
**Author**: Hive Mind TESTER Agent
**Date**: 2025-10-13
**Status**: Ready for Implementation

---

*"The best regression test is the one that finds a bug before your users do."*
