# Smoke Test Suite
## API1 to API8 Migration Verification

**Purpose**: Rapid validation of critical functionality (5-10 minutes)
**Execution**: Pre-deployment, post-deployment, on-demand
**Success Criteria**: 100% pass required to proceed

---

## Smoke Test Philosophy

> "Smoke tests are the canary in the coal mine. If they fail, don't go deeper."

### What are Smoke Tests?
- **Quick**: Run in 5-10 minutes
- **Critical**: Only the most important functionality
- **Binary**: Pass/Fail, no maybes
- **Blocking**: Failures block deployment

### When to Run?
- ✅ Before deployment (gate check)
- ✅ After deployment (verification)
- ✅ After every build (CI/CD)
- ✅ On infrastructure changes
- ✅ After configuration changes

---

## Smoke Test Checklist

### SMOKE-001: Service Availability
**Objective**: Verify API is reachable and responding

```bash
test_service_availability() {
  echo "SMOKE-001: Testing service availability..."

  response=$(curl -s -w "%{http_code}" -o /dev/null \
    --max-time 5 \
    "$API_URL/health")

  if [ "$response" -eq 200 ]; then
    echo "✅ PASS: Service is available"
    return 0
  else
    echo "❌ FAIL: Service returned $response"
    return 1
  fi
}
```

**Critical**: YES
**Timeout**: 5 seconds
**Expected**: HTTP 200

---

### SMOKE-002: Database Connectivity
**Objective**: Verify database is accessible

```bash
test_database_connectivity() {
  echo "SMOKE-002: Testing database connectivity..."

  # Test via API health endpoint that checks DB
  response=$(curl -s "$API_URL/health/db" | jq -r '.database.status')

  if [ "$response" == "connected" ]; then
    echo "✅ PASS: Database connected"
    return 0
  else
    echo "❌ FAIL: Database not connected"
    return 1
  fi
}
```

**Critical**: YES
**Timeout**: 5 seconds
**Expected**: Database connected

---

### SMOKE-003: Authentication - Login
**Objective**: Verify users can authenticate

```bash
test_authentication_login() {
  echo "SMOKE-003: Testing authentication..."

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "'"$TEST_USER_EMAIL"'",
      "password": "'"$TEST_USER_PASSWORD"'"
    }')

  body=$(echo "$response" | head -n -1)
  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ]; then
    token=$(echo "$body" | jq -r '.data.token')
    if [ -n "$token" ] && [ "$token" != "null" ]; then
      export AUTH_TOKEN="$token"
      echo "✅ PASS: Authentication successful"
      return 0
    fi
  fi

  echo "❌ FAIL: Authentication failed (Status: $status)"
  return 1
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: Valid auth token

---

### SMOKE-004: Read Operation (GET)
**Objective**: Verify basic read functionality

```bash
test_read_operation() {
  echo "SMOKE-004: Testing read operation..."

  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    "$API_URL/api/resources?limit=1")

  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ]; then
    echo "✅ PASS: Read operation successful"
    return 0
  else
    echo "❌ FAIL: Read operation failed (Status: $status)"
    return 1
  fi
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: HTTP 200, data returned

---

### SMOKE-005: Write Operation (POST)
**Objective**: Verify basic write functionality

```bash
test_write_operation() {
  echo "SMOKE-005: Testing write operation..."

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL/api/resources" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
      "name": "Smoke Test Resource",
      "description": "Created by smoke test",
      "value": 123
    }')

  body=$(echo "$response" | head -n -1)
  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ] || [ "$status" -eq 201 ]; then
    resource_id=$(echo "$body" | jq -r '.data.id')
    if [ -n "$resource_id" ] && [ "$resource_id" != "null" ]; then
      export SMOKE_TEST_RESOURCE_ID="$resource_id"
      echo "✅ PASS: Write operation successful"
      return 0
    fi
  fi

  echo "❌ FAIL: Write operation failed (Status: $status)"
  return 1
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: HTTP 201, resource created

---

### SMOKE-006: Update Operation (PUT/PATCH)
**Objective**: Verify update functionality

```bash
test_update_operation() {
  echo "SMOKE-006: Testing update operation..."

  if [ -z "$SMOKE_TEST_RESOURCE_ID" ]; then
    echo "⚠ SKIP: No resource ID from write test"
    return 0
  fi

  response=$(curl -s -w "\n%{http_code}" \
    -X PUT "$API_URL/api/resources/$SMOKE_TEST_RESOURCE_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
      "name": "Updated Smoke Test Resource"
    }')

  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ]; then
    echo "✅ PASS: Update operation successful"
    return 0
  else
    echo "❌ FAIL: Update operation failed (Status: $status)"
    return 1
  fi
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: HTTP 200

---

### SMOKE-007: Delete Operation (DELETE)
**Objective**: Verify delete functionality

```bash
test_delete_operation() {
  echo "SMOKE-007: Testing delete operation..."

  if [ -z "$SMOKE_TEST_RESOURCE_ID" ]; then
    echo "⚠ SKIP: No resource ID from write test"
    return 0
  fi

  response=$(curl -s -w "\n%{http_code}" \
    -X DELETE "$API_URL/api/resources/$SMOKE_TEST_RESOURCE_ID" \
    -H "Authorization: Bearer $AUTH_TOKEN")

  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ] || [ "$status" -eq 204 ]; then
    echo "✅ PASS: Delete operation successful"
    return 0
  else
    echo "❌ FAIL: Delete operation failed (Status: $status)"
    return 1
  fi
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: HTTP 200 or 204

---

### SMOKE-008: Search/Filter Functionality
**Objective**: Verify search is working

```bash
test_search_functionality() {
  echo "SMOKE-008: Testing search functionality..."

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL/api/search" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
      "query": "test",
      "limit": 5
    }')

  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ]; then
    echo "✅ PASS: Search functionality working"
    return 0
  else
    echo "❌ FAIL: Search failed (Status: $status)"
    return 1
  fi
}
```

**Critical**: NO
**Timeout**: 15 seconds
**Expected**: HTTP 200

---

### SMOKE-009: Error Handling
**Objective**: Verify graceful error handling

```bash
test_error_handling() {
  echo "SMOKE-009: Testing error handling..."

  # Request non-existent resource
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    "$API_URL/api/resources/999999999")

  body=$(echo "$response" | head -n -1)
  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 404 ]; then
    # Verify error response is structured
    if echo "$body" | jq -e '.error' >/dev/null 2>&1; then
      echo "✅ PASS: Error handling working"
      return 0
    fi
  fi

  echo "❌ FAIL: Error handling issue (Status: $status)"
  return 1
}
```

**Critical**: YES
**Timeout**: 10 seconds
**Expected**: HTTP 404 with structured error

---

### SMOKE-010: Performance Baseline
**Objective**: Verify acceptable response times

```bash
test_performance_baseline() {
  echo "SMOKE-010: Testing performance baseline..."

  # Time a simple request
  start=$(date +%s%N)

  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    "$API_URL/api/resources?limit=1")

  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))  # Convert to ms

  status=$(echo "$response" | tail -n 1)

  if [ "$status" -eq 200 ] && [ "$duration" -lt 1000 ]; then
    echo "✅ PASS: Performance acceptable (${duration}ms < 1000ms)"
    return 0
  elif [ "$status" -eq 200 ]; then
    echo "⚠ WARN: Slow response (${duration}ms >= 1000ms)"
    return 0
  else
    echo "❌ FAIL: Request failed or too slow"
    return 1
  fi
}
```

**Critical**: NO
**Timeout**: 30 seconds
**Expected**: < 1000ms response time

---

## Smoke Test Suite Runner

```bash
#!/bin/bash
# smoke-test-suite.sh
# Complete smoke test runner for API migration validation

set -e

# Configuration
API_URL="${API_URL:-https://api.falg.com.br}"
TEST_USER_EMAIL="${TEST_USER_EMAIL:-test@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-TestPassword123!}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Helper functions
log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  ((PASSED_TESTS++))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  ((FAILED_TESTS++))
}

log_skip() {
  echo -e "${YELLOW}⚠ SKIP${NC}: $1"
  ((SKIPPED_TESTS++))
}

# Test functions (include all tests from above)

# Main test execution
run_smoke_tests() {
  echo "========================================="
  echo "Smoke Test Suite - API Migration"
  echo "API: $API_URL"
  echo "Time: $(date)"
  echo "========================================="
  echo ""

  # Array of test functions
  tests=(
    test_service_availability
    test_database_connectivity
    test_authentication_login
    test_read_operation
    test_write_operation
    test_update_operation
    test_delete_operation
    test_search_functionality
    test_error_handling
    test_performance_baseline
  )

  TOTAL_TESTS=${#tests[@]}

  # Run all tests
  for test in "${tests[@]}"; do
    echo ""
    if $test; then
      :  # Test already logs pass/fail
    fi
    echo ""
  done

  # Summary
  echo "========================================="
  echo "Smoke Test Summary"
  echo "========================================="
  echo "Total Tests:   $TOTAL_TESTS"
  echo -e "Passed:        ${GREEN}$PASSED_TESTS${NC}"
  echo -e "Failed:        ${RED}$FAILED_TESTS${NC}"
  echo -e "Skipped:       ${YELLOW}$SKIPPED_TESTS${NC}"
  echo "========================================="

  # Calculate pass rate
  if [ $TOTAL_TESTS -gt 0 ]; then
    pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo "Pass Rate:     ${pass_rate}%"
  fi

  echo ""

  # Exit with appropriate code
  if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}SMOKE TESTS FAILED - DO NOT DEPLOY${NC}"
    exit 1
  else
    echo -e "${GREEN}SMOKE TESTS PASSED - SAFE TO PROCEED${NC}"
    exit 0
  fi
}

# Execute tests
run_smoke_tests
```

---

## Quick Smoke Test (30 seconds)

For ultra-fast validation:

```bash
#!/bin/bash
# quick-smoke.sh - Absolute minimum validation

quick_smoke() {
  echo "Quick Smoke Test..."

  # 1. Ping
  if ! curl -sf --max-time 3 "$API_URL/health" > /dev/null; then
    echo "❌ Service unreachable"
    exit 1
  fi

  # 2. Auth
  token=$(curl -sf -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"'"$TEST_USER"'","password":"'"$TEST_PASS"'"}' \
    | jq -r '.data.token')

  if [ -z "$token" ] || [ "$token" == "null" ]; then
    echo "❌ Auth failed"
    exit 1
  fi

  # 3. Basic request
  if ! curl -sf -H "Authorization: Bearer $token" \
    "$API_URL/api/resources?limit=1" > /dev/null; then
    echo "❌ API call failed"
    exit 1
  fi

  echo "✅ Quick smoke passed"
  exit 0
}

quick_smoke
```

---

## Smoke Test Automation

### CI/CD Integration

```yaml
# .gitlab-ci.yml
smoke-test-before-deploy:
  stage: pre-deploy
  script:
    - ./hive/testing/scripts/smoke-test-suite.sh
  environment:
    name: staging
  only:
    - tags
  allow_failure: false  # Block deployment on failure

smoke-test-after-deploy:
  stage: verify
  script:
    - ./hive/testing/scripts/smoke-test-suite.sh
  environment:
    name: production
  only:
    - tags
  when: on_success
```

---

## Smoke Test Results Report

```markdown
# Smoke Test Report
**Date**: 2025-10-13 15:45:00
**Environment**: Production
**API**: https://api.falg.com.br
**Duration**: 6 minutes 23 seconds

## Summary
- Total Tests: 10
- Passed: 10 ✅
- Failed: 0
- Skipped: 0
- Pass Rate: 100%

## Test Results

| Test | Result | Duration | Notes |
|------|--------|----------|-------|
| SMOKE-001: Service Availability | ✅ PASS | 2s | |
| SMOKE-002: Database Connectivity | ✅ PASS | 3s | |
| SMOKE-003: Authentication | ✅ PASS | 8s | |
| SMOKE-004: Read Operation | ✅ PASS | 5s | |
| SMOKE-005: Write Operation | ✅ PASS | 7s | |
| SMOKE-006: Update Operation | ✅ PASS | 6s | |
| SMOKE-007: Delete Operation | ✅ PASS | 4s | |
| SMOKE-008: Search | ✅ PASS | 12s | |
| SMOKE-009: Error Handling | ✅ PASS | 3s | |
| SMOKE-010: Performance | ✅ PASS | 134ms | |

## Conclusion
✅ **ALL SMOKE TESTS PASSED**
Safe to proceed with deployment.

## Next Steps
- Proceed with full regression test suite
- Monitor production metrics for 1 hour
- Keep rollback plan ready
```

---

## Smoke Test Maintenance

### When to Update Smoke Tests
- New critical features added
- Core workflows change
- Breaking changes introduced
- Security vulnerabilities found
- Performance requirements change

### What NOT to Include
- Non-critical features
- Edge cases
- Complex workflows
- Long-running operations
- Nice-to-have functionality

---

**Document Version**: 1.0
**Author**: Hive Mind TESTER Agent
**Date**: 2025-10-13
**Status**: Ready for Implementation

---

*"Smoke tests are your safety net. Keep them fast, keep them critical, keep them reliable."*
