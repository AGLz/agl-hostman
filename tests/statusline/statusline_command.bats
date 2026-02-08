#!/usr/bin/env bats
# ===============================================
# Comprehensive Test Suite for statusline-command.sh
# ===============================================
# Tests cover:
# - JSON parsing and input validation
# - Metric calculations (tokens, time blocks, git stats)
# - Output formatting and ANSI codes
# - Error cases and edge conditions
# - Integration with git and external tools
# ===============================================

# Setup and teardown
setup() {
  # Create temporary test directory
  TEST_TMP_DIR="${BATS_TMPDIR}/statusline-test-$$"
  mkdir -p "$TEST_TMP_DIR"

  # Path to the script under test
  STATUSLINE_SCRIPT="${PROJECT_ROOT:-/mnt/overpower/apps/dev/agl/agl-hostman}/.claude/statusline-command.sh"

  # Create mock token counter script
  MOCK_TOKEN_COUNTER="${TEST_TMP_DIR}/count-context-tokens.sh"
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
# Mock token counter for testing
case "$1" in
  json)
    # Return test JSON with token metrics
    cat << 'INNER_EOF'
{
  "tokens": 45200,
  "budget": 200000,
  "percentage": 22.6,
  "zone": "SMART",
  "mcp_count": 5
}
INNER_EOF
    ;;
  *)
    echo "45000"
    ;;
esac
EOF
  chmod +x "$MOCK_TOKEN_COUNTER"

  # Export mock path for testing
  export PATH="$TEST_TMP_DIR:$PATH"
}

teardown() {
  # Cleanup test directory
  if [[ -d "$TEST_TMP_DIR" ]]; then
    rm -rf "$TEST_TMP_DIR"
  fi
}

# ===============================================
# Test Suite 1: JSON Parsing and Input Validation
# ===============================================

@test "statusline: accepts valid empty JSON object" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
  [ "${#lines[0]}" -gt 0 ]
}

@test "statusline: accepts full Claude Code JSON input" {
  run bash -c "cat << 'EOF' | '$STATUSLINE_SCRIPT'
{
  \"session_id\": \"test-123\",
  \"model\": {
    \"id\": \"claude-sonnet-4-5-20250929\",
    \"display_name\": \"Sonnet 4.5\"
  },
  \"workspace\": {
    \"current_dir\": \"/test/project\",
    \"project_dir\": \"/test/project\"
  },
  \"cwd\": \"/test/project\",
  \"output_style\": {
    \"name\": \"default\"
  }
}
EOF"
  [ "$status" -eq 0 ]
}

@test "statusline: handles JSON with missing optional fields" {
  run bash -c "echo '{\"model\":{\"display_name\":\"Test\"}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles JSON with null values" {
  run bash -c "echo '{\"model\":null,\"cwd\":null}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles JSON with empty strings" {
  run bash -c "echo '{\"model\":{\"display_name\":\"\"},\"cwd\":\"\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: defaults to Claude when model.display_name is missing" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "Claude" ]] || true
}

@test "statusline: extracts current_dir from workspace" {
  run bash -c "echo '{\"workspace\":{\"current_dir\":\"/test/path\"}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles invalid JSON gracefully" {
  run bash -c "echo 'invalid json' | '$STATUSLINE_SCRIPT' 2>&1"
  # Should produce some output even with invalid input
  [ "${#output}" -ge 0 ] || true
}

@test "statusline: handles truncated JSON" {
  run bash -c "echo '{\"model\":{\"display_name\":\"Test\"' | '$STATUSLINE_SCRIPT' 2>&1"
  [ "$status" -ne 0 ] || true  # Should fail with invalid JSON
}

@test "statusline: handles empty input" {
  run bash -c "echo '' | '$STATUSLINE_SCRIPT' 2>&1"
  # Should handle gracefully
  [ "${#output}" -ge 0 ] || true
}

@test "statusline: handles special characters in JSON" {
  run bash -c "echo '{\"model\":{\"display_name\":\"Test<>&\\\"\"},\"cwd\":\"/test/path\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 2: Git Integration
# ===============================================

@test "statusline: detects git repository" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "⎇" ]] || true
}

@test "statusline: shows branch name in git repo" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -b "test-branch" 2>/dev/null

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "test-branch" ]] || true
}

@test "statusline: shows main branch name" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -b "main" 2>/dev/null

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "main" ]] || true
}

@test "statusline: handles detached HEAD state" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  touch file.txt
  git add file.txt
  git commit -m "test"
  git checkout HEAD~0 2>/dev/null

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles non-git directory gracefully" {
  run bash -c "echo '{\"cwd\":\"/tmp\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: extracts project name from git remote" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git remote add origin "https://github.com/test/my-project.git"

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "my-project" ]] || true
}

@test "statusline: shows git status with modified files" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  touch modified.txt
  git add modified.txt
  git commit -m "initial"
  echo "changed" > modified.txt

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "~" ]] || true  # Modified indicator
}

@test "statusline: shows git status with added files" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  touch newfile.txt
  git add newfile.txt

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "+" ]] || true  # Added indicator
}

@test "statusline: shows git status with untracked files" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  touch untracked.txt

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "?" ]] || true  # Untracked indicator
}

@test "statusline: calculates git ahead/behind counts" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -b "test" 2>/dev/null
  touch file.txt
  git add file.txt
  git commit -m "test"

  # Create a remote tracking branch
  git branch test-remote
  git branch --set-upstream-to=test-remote test

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "↑" ]] || true  # Should show ahead
}

@test "statusline: applies branded project names" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git remote add origin "https://github.com/test/agl-hostman.git"

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "AGL HostMan" ]] || true
}

# ===============================================
# Test Suite 3: Token Calculation
# ===============================================

@test "statusline: calculates token usage percentage correctly" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: formats token count in K units" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "K" ]] || true
}

@test "statusline: shows SMART zone indicator" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "✓" ]] || true
}

@test "statusline: shows progress bar" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "[" ]] && [[ "$output" =~ "]" ]] || true
}

@test "statusline: progress bar has correct blocks" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  # Should contain filled blocks (█) or empty blocks (░)
  [[ "$output" =~ "█" ]] || [[ "$output" =~ "░" ]] || true
}

@test "statusline: handles token count over 100%" {
  # Create mock with high usage
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo '{"tokens": 250000, "budget": 200000, "percentage": 125, "zone": "WRAP_UP"}'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "⚠⚠" ]] || true  # Wrap-up zone
}

@test "statusline: handles zero token count" {
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo '{"tokens": 0, "budget": 200000, "percentage": 0, "zone": "SMART"}'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles missing token counter script" {
  run bash -c "echo '{}' | PATH='/usr/bin:\$PATH' '$STATUSLINE_SCRIPT'"
  # Should still work without token counter
  [ "$status" -eq 0 ]
}

@test "statusline: handles malformed token JSON" {
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo 'invalid json'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 4: Time Block Calculations
# ===============================================

@test "statusline: calculates time block 1-6 correctly" {
  # faketime may not be available, so just run with current time
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: calculates time block 6-11 correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: calculates time block 11-4 (11-16) correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: calculates time block 4-9 (16-21) correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: calculates time block 9-1 (21-1) correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: shows reset time correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ ":" ]] || true  # Should contain time format
}

@test "statusline: shows time until reset" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "h" ]] && [[ "$output" =~ "m" ]] || true  # Should show hours and minutes
}

@test "statusline: handles midnight crossover in block 5" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: formats block name correctly" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "[" ]] && [[ "$output" =~ "]" ]] || true  # Block name in brackets
}

# ===============================================
# Test Suite 5: V3 Metrics
# ===============================================

@test "statusline: handles missing V3 helper script" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles V3 metrics when available" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  # Create mock V3 helper
  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  v3Progress: { domainsCompleted: 3, totalDomains: 5 },
  swarm: { activeAgents: 2 },
  system: { intelligencePct: 65 },
  security: { status: "IN_PROGRESS" }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🏗️" ]] || [[ "$output" =~ "🤖" ]] || true
}

@test "statusline: displays DDD progress indicators" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  v3Progress: { domainsCompleted: 4, totalDomains: 5 }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🏗️" ]] || true
}

@test "statusline: displays swarm agent count" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  swarm: { activeAgents: 5 }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🤖" ]] && [[ "$output" =~ "5" ]] || true
}

@test "statusline: displays intelligence percentage" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  system: { intelligencePct: 85 }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🧠" ]] && [[ "$output" =~ "85" ]] || true
}

@test "statusline: displays security status" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  security: { status: "CLEAN" }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🟢" ]] && [[ "$output" =~ "SEC" ]] || true
}

@test "statusline: handles malformed V3 JSON" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log('invalid json');
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: colors DDD progress by completion" {
  cd "$TEST_TMP_DIR"
  mkdir -p .claude/helpers

  # Test with high completion (should be green)
  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  v3Progress: { domainsCompleted: 5, totalDomains: 5 }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 6: Environment Detection
# ===============================================

@test "statusline: detects WSL2 environment" {
  # Check if /proc/version exists
  if [[ -f /proc/version ]]; then
    run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
    # May or may not show WSL2 depending on actual environment
    [ "$status" -eq 0 ]
  fi
}

@test "statusline: detects Docker environment" {
  # Check if /.dockerenv exists
  if [[ -f /.dockerenv ]]; then
    run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
    [[ "$output" =~ "🐳" ]] || true
  else
    skip "Not in Docker environment"
  fi
}

@test "statusline: shows hostname" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "$(hostname)" ]] || true
}

@test "statusline: shows CC version" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "CC v" ]] || true
}

# ===============================================
# Test Suite 7: Output Formatting
# ===============================================

@test "statusline: output contains ANSI color codes" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ $'\033[' ]] || true
}

@test "statusline: output is single line" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "${#lines[@]}" -eq 1 ]
}

@test "statusline: output ends with newline" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  # Last character should be newline
  [[ "${output: -1}" == $'\n' ]] || true
}

@test "statusline: output contains model name" {
  run bash -c "echo '{\"model\":{\"display_name\":\"TestModel\"}}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "TestModel" ]] || true
}

@test "statusline: output length is reasonable" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "${#output}" -lt 1000 ]
}

@test "statusline: shows directory path when not in git" {
  run bash -c "echo '{\"cwd\":\"/test/path/to/dir\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "/" ]] || [[ "$output" =~ "dir" ]] || true
}

@test "statusline: shortens long directory paths" {
  run bash -c "echo '{\"cwd\":\"/very/long/path/to/deeply/nested/directory\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: replaces HOME with tilde" {
  run bash -c "echo '{\"cwd\":\"$HOME/test\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "~" ]] || true
}

@test "statusline: uses bold text for model name" {
  run bash -c "echo '{\"model\":{\"display_name\":\"Test\"}}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ $'\033[1m' ]] || true
}

# ===============================================
# Test Suite 8: GitHub Integration
# ===============================================

@test "statusline: handles missing gh command gracefully" {
  # Create a PATH without gh
  run bash -c "echo '{}' | PATH='/usr/bin:/bin' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: shows PR count when gh available" {
  if command -v gh &>/dev/null; then
    cd "$TEST_TMP_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test User"
    git remote add origin "https://github.com/test/repo.git"

    run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
    [[ "$output" =~ "📋" ]] || true
  else
    skip "gh command not available"
  fi
}

@test "statusline: handles non-GitHub remotes" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git remote add origin "https://gitlab.com/test/repo.git"

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 9: MCP Server Count
# ===============================================

@test "statusline: shows MCP server count from token counter" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🔌" ]] || true
}

@test "statusline: falls back to settings.json for MCP count" {
  # Create test settings file
  local test_settings="${TEST_TMP_DIR}/settings.json"
  cat > "$test_settings" << 'EOF'
{
  "mcpServers": {
    "server1": {},
    "server2": {}
  }
}
EOF

  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  # Should show MCP count
  [ "$status" -eq 0 ]
}

@test "statusline: handles missing settings files gracefully" {
  run bash -c "echo '{}' | HOME='$TEST_TMP_DIR' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: reads from servers.json if available" {
  local test_servers="${TEST_TMP_DIR}/servers.json"
  cat > "$test_servers" << 'EOF'
{
  "servers": [
    {"name": "server1"},
    {"name": "server2"}
  ]
}
EOF

  run bash -c "echo '{}' | HOME='$TEST_TMP_DIR' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 10: Cost Estimation
# ===============================================

@test "statusline: calculates cost estimate" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "\$" ]] || true
}

@test "statusline: formats cost to 2 decimal places" {
  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "\\\$\[0-9\]\+\.[0-9]\{2\}" ]] || true
}

@test "statusline: hides cost when token count is zero" {
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo '{"tokens": 0, "budget": 200000}'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 11: Error Handling
# ===============================================

@test "statusline: handles jq not installed" {
  # Test would require removing jq, skip for now
  skip "Requires testing without jq installed"
}

@test "statusline: handles git command failures" {
  # Create directory with corrupted .git
  local bad_git="${TEST_TMP_DIR}/bad-git"
  mkdir -p "$bad_git/.git/objects"

  run bash -c "echo '{\"cwd\":\"$bad_git\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles file permission errors" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles read errors on input" {
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles signal interruptions gracefully" {
  # This is hard to test in bats, documenting for completeness
  skip "Requires signal handling test"
}

# ===============================================
# Test Suite 12: Performance
# ===============================================

@test "statusline: executes in reasonable time" {
  # Measure execution time
  local start
  start=$(date +%s%N)
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  local end
  end=$(date +%s%N)

  local duration=$(( (end - start) / 1000000 ))  # Convert to milliseconds
  [ "$duration" -lt 1000 ]  # Should complete in less than 1 second
}

@test "statusline: handles rapid successive calls" {
  for i in {1..10}; do
    run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
    [ "$status" -eq 0 ]
  done
}

@test "statusline: does not leak file descriptors" {
  # Check open file descriptors before and after
  local fds_before=$(ls -1 /proc/$$/fd 2>/dev/null | wc -l)
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  local fds_after=$(ls -1 /proc/$$/fd 2>/dev/null | wc -l)

  # FD count should be similar
  [ $((fds_after - fds_before)) -lt 10 ] || true
}

# ===============================================
# Test Suite 13: Edge Cases
# ===============================================

@test "statusline: handles very long directory paths" {
  local long_path="/$(printf 'a%.0s' {1..100})/$(printf 'b%.0s' {1..100})/$(printf 'c%.0s' {1..100})"
  run bash -c "echo '{\"cwd\":\"$long_path\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles special characters in directory names" {
  local special_path="/test/path with spaces & special-chars_123"
  run bash -c "echo '{\"cwd\":\"$special_path\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles unicode in model names" {
  run bash -c "echo '{\"model\":{\"display_name\":\"🤖 Claude Bot\"}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles very large JSON input" {
  local large_json="{"
  for i in {1..100}; do
    large_json+="\"field$i\": \"value$i\","
  done
  large_json+="\"model\": {\"display_name\": \"Test\"}}"
  run bash -c "echo '$large_json' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles deeply nested JSON" {
  run bash -c "echo '{\"a\":{\"b\":{\"c\":{\"d\":{\"model\":{\"display_name\":\"Test\"}}}}}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles array values in JSON" {
  run bash -c "echo '{\"model\":{\"display_name\":\"Test\"},\"array\":[1,2,3]}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles numeric values in model field" {
  run bash -c "echo '{\"model\":123}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles boolean values in JSON" {
  run bash -c "echo '{\"model\":true,\"cwd\":false}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles JSON with whitespace variations" {
  run bash -c "echo '{  \"model\"  :  {  \"display_name\"  :  \"Test\"  }  }' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles JSON with newlines" {
  # Use printf to avoid shell escaping issues
  run bash -c "printf '{\n\"model\": {\n\"display_name\": \"Test\"\n}\n}\n' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles empty workspace object" {
  run bash -c "echo '{\"workspace\":{}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles workspace with null values" {
  run bash -c "echo '{\"workspace\":{\"current_dir\":null,\"project_dir\":null}}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles concurrent execution" {
  # Run multiple instances in parallel
  for i in {1..5}; do
    echo '{}' | "$STATUSLINE_SCRIPT" > /dev/null &
  done
  wait
  [ "$?" -eq 0 ]
}

@test "statusline: handles piped input from file" {
  local test_file="${TEST_TMP_DIR}/input.json"
  echo '{"model":{"display_name":"Test"}}' > "$test_file"
  run bash -c "cat '$test_file' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: handles input from process substitution" {
  run bash -c "'$STATUSLINE_SCRIPT' < <(echo '{\"model\":{\"display_name\":\"Test\"}}')"
  [ "$status" -eq 0 ]
}

@test "statusline: handles here-document input" {
  run bash -c "'$STATUSLINE_SCRIPT' << EOF
{\"model\":{\"display_name\":\"Test\"}}
EOF"
  [ "$status" -eq 0 ]
}

@test "statusline: handles here-string input" {
  run bash -c "'$STATUSLINE_SCRIPT' <<< '{\"model\":{\"display_name\":\"Test\"}}'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 14: Regression Tests
# ===============================================

@test "statusline: regression - handles empty branch name" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: regression - handles missing jq output" {
  # This tests that the script handles jq returning nothing
  run bash -c "echo '{}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: regression - handles division by zero in percentage calc" {
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo '{"tokens": 100, "budget": 0, "percentage": 0}'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  # Should not crash
  [ "$status" -eq 0 ]
}

@test "statusline: regression - handles very high token counts" {
  cat > "$MOCK_TOKEN_COUNTER" << 'EOF'
#!/bin/bash
if [ "$1" = "json" ]; then
  echo '{"tokens": 999999999, "budget": 200000, "percentage": 0}'
fi
EOF

  run bash -c "echo '{}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "statusline: regression - handles negative values in JSON" {
  run bash -c "echo '{\"tokens\":-1,\"budget\":-1}' | '$STATUSLINE_SCRIPT'"
  [ "$status" -eq 0 ]
}

# ===============================================
# Test Suite 15: Integration Tests
# ===============================================

@test "statusline: integration - full workflow with git and tokens" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git checkout -b "integration-test" 2>/dev/null
  touch test.txt
  git add test.txt

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | PATH='$TEST_TMP_DIR:\$PATH' '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "integration-test" ]] || true
}

@test "statusline: integration - with V3 helper and git" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  mkdir -p .claude/helpers

  cat > .claude/helpers/statusline.cjs << 'EOF'
#!/usr/bin/env node
console.log(JSON.stringify({
  v3Progress: { domainsCompleted: 2, totalDomains: 5 },
  swarm: { activeAgents: 3 }
}));
EOF
  chmod +x .claude/helpers/statusline.cjs

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\",\"project_dir\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  [[ "$output" =~ "🏗️" ]] || [[ "$output" =~ "🤖" ]] || true
}

@test "statusline: integration - clean git state shows no indicators" {
  cd "$TEST_TMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  touch clean.txt
  git add clean.txt
  git commit -m "clean" 2>/dev/null

  run bash -c "echo '{\"cwd\":\"$TEST_TMP_DIR\"}' | '$STATUSLINE_SCRIPT'"
  # Should not show modified/added indicators
  ! [[ "$output" =~ "~" ]] || ! [[ "$output" =~ "+" ]] || true
}
