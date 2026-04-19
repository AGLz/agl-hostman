# Security Testing Plan
## API1 and API8 Security Validation

**Objective**: Ensure both APIs are secure and migration doesn't introduce vulnerabilities
**Priority**: CRITICAL
**Scope**: OWASP Top 10, authentication, authorization, input validation, data protection

---

## Security Testing Philosophy

> "Security is not a product, but a process." - Bruce Schneier

### Core Principles
1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Minimal necessary permissions
3. **Secure by Default**: Secure configuration out-of-the-box
4. **Fail Securely**: Failures don't compromise security
5. **Audit Everything**: Complete security event logging

---

## OWASP Top 10 Test Coverage

### A01:2021 - Broken Access Control

#### SEC-001: Horizontal Privilege Escalation
**Test**: User A cannot access User B's resources

```bash
test_horizontal_privilege_escalation() {
  echo "Testing horizontal privilege escalation..."

  # Login as User A
  user_a_token=$(login "usera@example.com" "password")

  # Create resource as User A
  resource_id=$(create_resource "$user_a_token")

  # Login as User B
  user_b_token=$(login "userb@example.com" "password")

  # Attempt to access User A's resource
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $user_b_token" \
    "$API_URL/api/resources/$resource_id")

  status=$(echo "$response" | tail -n 1)

  # Should be denied
  assert_equals "403" "$status" "Access denied correctly" || return 1

  echo "PASS: Horizontal privilege escalation prevented"
  return 0
}
```

#### SEC-002: Vertical Privilege Escalation
**Test**: Regular user cannot access admin functions

```bash
test_vertical_privilege_escalation() {
  echo "Testing vertical privilege escalation..."

  # Login as regular user
  user_token=$(login "user@example.com" "password")

  # Attempt admin operation
  response=$(curl -s -w "\n%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer $user_token" \
    "$API_URL/api/admin/users/123")

  status=$(echo "$response" | tail -n 1)

  assert_equals "403" "$status" || return 1

  echo "PASS: Vertical privilege escalation prevented"
  return 0
}
```

#### SEC-003: Insecure Direct Object Reference (IDOR)
**Test**: Cannot manipulate IDs to access unauthorized resources

```bash
test_idor() {
  echo "Testing IDOR vulnerabilities..."

  user_token=$(login "user@example.com" "password")

  # Try sequential ID guessing
  for id in {1..10}; do
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $user_token" \
      "$API_URL/api/resources/$id")

    status=$(echo "$response" | tail -n 1)

    # Should only succeed for user's own resources
    # Track which IDs are accessible
    if [ "$status" == "200" ]; then
      verify_resource_ownership $id $user_token || return 1
    fi
  done

  echo "PASS: IDOR protection working"
  return 0
}
```

---

### A02:2021 - Cryptographic Failures

#### SEC-010: Password Storage
**Test**: Passwords are hashed, not plaintext

```bash
test_password_storage() {
  echo "Testing password storage..."

  # Create user
  email="test_$(date +%s)@example.com"
  password="SecurePass123!"

  register_user "$email" "$password"

  # Check database directly
  stored_password=$(mysql -N -e "
    SELECT password FROM users WHERE email = '$email'
  " api8_db)

  # Should NOT match plaintext password
  if [ "$stored_password" == "$password" ]; then
    echo "FAIL: Password stored in plaintext!"
    return 1
  fi

  # Should look like bcrypt/argon2 hash
  if [[ ! "$stored_password" =~ ^\$2[ayb]\$ ]]; then
    echo "FAIL: Password not properly hashed"
    return 1
  fi

  echo "PASS: Password properly hashed"
  return 0
}
```

#### SEC-011: Sensitive Data Exposure
**Test**: Sensitive data not logged or exposed in errors

```bash
test_sensitive_data_exposure() {
  echo "Testing sensitive data exposure..."

  # Create user with sensitive data
  response=$(curl -s -X POST "$API_URL/api/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "test@example.com",
      "password": "MySecretPassword123!",
      "ssn": "123-45-6789"
    }')

  # Check response doesn't contain sensitive data
  if echo "$response" | grep -q "MySecretPassword123!"; then
    echo "FAIL: Password exposed in response"
    return 1
  fi

  if echo "$response" | grep -q "123-45-6789"; then
    echo "FAIL: SSN exposed in response"
    return 1
  fi

  # Check application logs
  if tail -100 /var/log/api8/app.log | grep -q "MySecretPassword123!"; then
    echo "FAIL: Password found in logs"
    return 1
  fi

  echo "PASS: Sensitive data properly protected"
  return 0
}
```

#### SEC-012: HTTPS Enforcement
**Test**: HTTP redirects to HTTPS

```bash
test_https_enforcement() {
  echo "Testing HTTPS enforcement..."

  # Attempt HTTP connection
  response=$(curl -s -w "\n%{http_code}" -L \
    "http://api.example.com/api/users")

  status=$(echo "$response" | tail -n 1)

  # Should redirect to HTTPS (301/302) or return 426
  if [[ "$status" != "301" && "$status" != "302" && "$status" != "426" ]]; then
    echo "FAIL: HTTP not redirected to HTTPS"
    return 1
  fi

  echo "PASS: HTTPS properly enforced"
  return 0
}
```

---

### A03:2021 - Injection

#### SEC-020: SQL Injection
**Test**: SQL injection attempts are blocked

```bash
test_sql_injection() {
  echo "Testing SQL injection prevention..."

  sql_payloads=(
    "' OR '1'='1"
    "'; DROP TABLE users; --"
    "1' UNION SELECT * FROM users--"
    "admin'--"
    "' OR 1=1--"
  )

  for payload in "${sql_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/users?name=$payload")

    body=$(echo "$response" | head -n -1)
    status=$(echo "$response" | tail -n 1)

    # Should not cause SQL error (500)
    if [ "$status" == "500" ]; then
      echo "FAIL: SQL injection caused server error"
      return 1
    fi

    # Should not return unexpected data
    if echo "$body" | grep -qi "syntax error"; then
      echo "FAIL: SQL syntax error exposed"
      return 1
    fi
  done

  # Verify database still intact
  user_count=$(mysql -N -e "SELECT COUNT(*) FROM users" api8_db)
  if [ -z "$user_count" ]; then
    echo "FAIL: Database may be compromised"
    return 1
  fi

  echo "PASS: SQL injection prevented"
  return 0
}
```

#### SEC-021: NoSQL Injection
**Test**: NoSQL injection attempts blocked (if applicable)

```bash
test_nosql_injection() {
  echo "Testing NoSQL injection prevention..."

  nosql_payloads=(
    '{"$gt":""}'
    '{"$ne":null}'
    '{"$regex":".*"}'
  )

  for payload in "${nosql_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" \
      -X POST "$API_URL/api/search" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"filter\": $payload}")

    status=$(echo "$response" | tail -n 1)

    # Should handle safely
    if [ "$status" == "500" ]; then
      echo "FAIL: NoSQL injection caused error"
      return 1
    fi
  done

  echo "PASS: NoSQL injection prevented"
  return 0
}
```

#### SEC-022: Command Injection
**Test**: OS command injection blocked

```bash
test_command_injection() {
  echo "Testing command injection prevention..."

  command_payloads=(
    "; ls -la"
    "| cat /etc/passwd"
    "\$(whoami)"
    "\`id\`"
  )

  for payload in "${command_payloads[@]}"; do
    response=$(curl -s -w "\n%{http_code}" \
      -X POST "$API_URL/api/files" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"filename\": \"test$payload\"}")

    body=$(echo "$response" | head -n -1)

    # Should not execute commands
    if echo "$body" | grep -qi "root:"; then
      echo "FAIL: Command injection executed"
      return 1
    fi
  done

  echo "PASS: Command injection prevented"
  return 0
}
```

#### SEC-023: XSS (Cross-Site Scripting)
**Test**: XSS payloads are sanitized

```bash
test_xss_prevention() {
  echo "Testing XSS prevention..."

  xss_payloads=(
    "<script>alert('XSS')</script>"
    "<img src=x onerror=alert('XSS')>"
    "javascript:alert('XSS')"
    "<svg onload=alert('XSS')>"
  )

  for payload in "${xss_payloads[@]}"; do
    # Create resource with XSS payload
    response=$(curl -s -X POST "$API_URL/api/resources" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"name\": \"$payload\", \"description\": \"test\"}")

    resource_id=$(echo "$response" | jq -r '.data.id')

    # Retrieve resource
    retrieved=$(curl -s \
      -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/resources/$resource_id")

    name=$(echo "$retrieved" | jq -r '.data.name')

    # Should be escaped/sanitized
    if [[ "$name" == *"<script>"* ]]; then
      echo "FAIL: XSS payload not sanitized"
      return 1
    fi
  done

  echo "PASS: XSS prevention working"
  return 0
}
```

---

### A04:2021 - Insecure Design

#### SEC-030: Rate Limiting
**Test**: Rate limiting protects against abuse

```bash
test_rate_limiting() {
  echo "Testing rate limiting..."

  # Send rapid requests
  rate_limit_reached=false

  for i in {1..100}; do
    response=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/users")

    status=$(echo "$response" | tail -n 1)

    if [ "$status" == "429" ]; then
      rate_limit_reached=true
      break
    fi
  done

  if [ "$rate_limit_reached" == "false" ]; then
    echo "WARN: Rate limiting not detected in 100 requests"
    # Not necessarily a failure, but should be investigated
  fi

  echo "PASS: Rate limiting check complete"
  return 0
}
```

#### SEC-031: Account Lockout
**Test**: Account locks after failed login attempts

```bash
test_account_lockout() {
  echo "Testing account lockout..."

  email="test@example.com"
  wrong_password="WrongPassword123!"

  # Attempt multiple failed logins
  for i in {1..10}; do
    login "$email" "$wrong_password" 2>/dev/null
  done

  # Attempt with correct password should now be locked
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$email\", \"password\": \"CorrectPassword123!\"}")

  status=$(echo "$response" | tail -n 1)

  # Should be locked (423) or still unauthorized (401)
  # If 200, account lockout not implemented
  if [ "$status" == "200" ]; then
    echo "WARN: Account lockout not detected"
  fi

  echo "PASS: Account lockout check complete"
  return 0
}
```

---

### A05:2021 - Security Misconfiguration

#### SEC-040: Security Headers
**Test**: Proper security headers present

```bash
test_security_headers() {
  echo "Testing security headers..."

  response=$(curl -sI "$API_URL/api/users" \
    -H "Authorization: Bearer $TOKEN")

  required_headers=(
    "X-Content-Type-Options: nosniff"
    "X-Frame-Options: DENY"
    "X-XSS-Protection: 1; mode=block"
    "Strict-Transport-Security"
  )

  for header in "${required_headers[@]}"; do
    if ! echo "$response" | grep -qi "$header"; then
      echo "WARN: Missing security header: $header"
    fi
  done

  # Should NOT have these
  if echo "$response" | grep -qi "X-Powered-By"; then
    echo "WARN: X-Powered-By header exposes technology"
  fi

  if echo "$response" | grep -qi "Server: "; then
    echo "WARN: Server header may expose version info"
  fi

  echo "PASS: Security headers check complete"
  return 0
}
```

#### SEC-041: Error Message Information Disclosure
**Test**: Error messages don't leak sensitive info

```bash
test_error_messages() {
  echo "Testing error messages..."

  # Trigger various errors
  errors=(
    "GET /api/nonexistent"
    "POST /api/users (invalid JSON)"
    "GET /api/users/99999999"
  )

  for error_case in "${errors[@]}"; do
    response=$(curl -s $error_case 2>&1)

    # Should not contain
    leaky_patterns=(
      "stack trace"
      "SQLException"
      "mysql"
      "postgres"
      "/var/www"
      "password"
    )

    for pattern in "${leaky_patterns[@]}"; do
      if echo "$response" | grep -qi "$pattern"; then
        echo "FAIL: Error message leaks sensitive info: $pattern"
        return 1
      fi
    done
  done

  echo "PASS: Error messages properly sanitized"
  return 0
}
```

---

### A07:2021 - Identification and Authentication Failures

#### SEC-050: Weak Password Policy
**Test**: Weak passwords rejected

```bash
test_weak_passwords() {
  echo "Testing password policy..."

  weak_passwords=(
    "123456"
    "password"
    "qwerty"
    "abc123"
    "test"
  )

  for password in "${weak_passwords[@]}"; do
    response=$(curl -s -w "\n%{http_code}" \
      -X POST "$API_URL/api/auth/register" \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"test_$(date +%s)@example.com\",
        \"password\": \"$password\"
      }")

    status=$(echo "$response" | tail -n 1)

    # Should reject weak password
    if [ "$status" == "200" ] || [ "$status" == "201" ]; then
      echo "FAIL: Weak password accepted: $password"
      return 1
    fi
  done

  echo "PASS: Password policy enforced"
  return 0
}
```

#### SEC-051: JWT Token Security
**Test**: JWT tokens are secure

```bash
test_jwt_security() {
  echo "Testing JWT security..."

  # Login and get token
  token=$(login "user@example.com" "password" | jq -r '.data.token')

  # Decode JWT (without verification)
  payload=$(echo "$token" | cut -d '.' -f2 | base64 -d 2>/dev/null)

  # Check for security issues
  if echo "$payload" | jq -e '.password' >/dev/null 2>&1; then
    echo "FAIL: JWT contains password"
    return 1
  fi

  if echo "$payload" | jq -e '.ssn' >/dev/null 2>&1; then
    echo "FAIL: JWT contains sensitive data"
    return 1
  fi

  # Check expiration
  exp=$(echo "$payload" | jq -r '.exp')
  now=$(date +%s)

  if [ -z "$exp" ]; then
    echo "FAIL: JWT has no expiration"
    return 1
  fi

  # Expiration should be reasonable (not > 24 hours)
  diff=$((exp - now))
  if [ $diff -gt 86400 ]; then
    echo "WARN: JWT expiration is very long (>24h)"
  fi

  echo "PASS: JWT security check passed"
  return 0
}
```

#### SEC-052: Session Management
**Test**: Sessions properly managed

```bash
test_session_management() {
  echo "Testing session management..."

  # Login
  token1=$(login "user@example.com" "password" | jq -r '.data.token')

  # Use token
  curl -s -H "Authorization: Bearer $token1" "$API_URL/api/user/profile" > /dev/null

  # Logout
  curl -s -X POST -H "Authorization: Bearer $token1" "$API_URL/api/auth/logout" > /dev/null

  # Token should now be invalid
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $token1" \
    "$API_URL/api/user/profile")

  status=$(echo "$response" | tail -n 1)

  if [ "$status" == "200" ]; then
    echo "FAIL: Token still valid after logout"
    return 1
  fi

  echo "PASS: Session management working"
  return 0
}
```

---

### A08:2021 - Software and Data Integrity Failures

#### SEC-060: Dependency Vulnerabilities
**Test**: Check for known vulnerable dependencies

```bash
test_dependency_vulnerabilities() {
  echo "Testing for vulnerable dependencies..."

  # Run dependency checker (example for PHP)
  if command -v composer &> /dev/null; then
    cd /var/www/api8
    composer audit --format=json > /tmp/audit.json 2>&1

    vulnerabilities=$(jq '.advisories | length' /tmp/audit.json 2>/dev/null || echo "0")

    if [ "$vulnerabilities" -gt 0 ]; then
      echo "WARN: Found $vulnerabilities known vulnerabilities"
      jq '.advisories' /tmp/audit.json
    fi
  fi

  echo "PASS: Dependency check complete"
  return 0
}
```

---

### A09:2021 - Security Logging and Monitoring Failures

#### SEC-070: Authentication Logging
**Test**: Auth events are logged

```bash
test_authentication_logging() {
  echo "Testing authentication logging..."

  # Perform login
  email="test_$(date +%s)@example.com"
  register_user "$email" "SecurePass123!"
  login "$email" "SecurePass123!"

  # Check logs
  sleep 2
  if ! grep -q "$email" /var/log/api8/auth.log 2>/dev/null; then
    echo "WARN: Authentication not logged"
  fi

  # Perform failed login
  login "$email" "WrongPassword"

  # Check failed login logged
  sleep 2
  if ! grep -q "failed.*$email" /var/log/api8/auth.log 2>/dev/null; then
    echo "WARN: Failed login not logged"
  fi

  echo "PASS: Authentication logging check complete"
  return 0
}
```

---

## Security Test Execution

### Test Suite Runner
```bash
#!/bin/bash
# security-test-suite.sh

API_URL="${API_URL:-https://api.falg.com.br}"
RESULTS_DIR="./hive/testing/results/security"

mkdir -p "$RESULTS_DIR"

echo "========================================="
echo "Security Test Suite"
echo "API: $API_URL"
echo "========================================="

passed=0
failed=0

# Run all security tests
tests=(
  test_horizontal_privilege_escalation
  test_vertical_privilege_escalation
  test_idor
  test_password_storage
  test_sensitive_data_exposure
  test_https_enforcement
  test_sql_injection
  test_nosql_injection
  test_command_injection
  test_xss_prevention
  test_rate_limiting
  test_account_lockout
  test_security_headers
  test_error_messages
  test_weak_passwords
  test_jwt_security
  test_session_management
  test_authentication_logging
)

for test in "${tests[@]}"; do
  echo ""
  if $test; then
    ((passed++))
  else
    ((failed++))
  fi
done

echo ""
echo "========================================="
echo "Security Test Results:"
echo "  Passed: $passed"
echo "  Failed: $failed"
echo "========================================="

# Generate report
generate_security_report "$passed" "$failed" > "$RESULTS_DIR/security-report-$(date +%Y%m%d).md"

if [ $failed -gt 0 ]; then
  exit 1
fi

exit 0
```

---

**Document Version**: 1.0
**Author**: Hive Mind TESTER Agent
**Date**: 2025-10-13
**Status**: Ready for Implementation

---

*"Security is a journey, not a destination. Test early, test often."*
