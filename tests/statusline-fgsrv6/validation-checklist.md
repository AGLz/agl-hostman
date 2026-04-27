# Statusline Deployment Validation Checklist - FGSRV6

## 🎯 Pre-Deployment Validation

### 1. File Permissions Verification

- [ ] **Script has execute permissions**
  ```bash
  ls -l .claude/statusline-command.sh
  # Expected: -rwxr-xr-x (755 or 775)
  ```

- [ ] **Parent directory has correct permissions**
  ```bash
  ls -ld .claude/
  # Expected: drwxr-xr-x (755)
  ```

- [ ] **Settings.json is readable**
  ```bash
  cat .claude/settings.json | jq .
  # Should parse without errors
  ```

### 2. Configuration Syntax Validation

- [ ] **Settings.json is valid JSON**
  ```bash
  jq . .claude/settings.json > /dev/null && echo "Valid JSON"
  ```

- [ ] **statusLine section exists and is valid**
  ```bash
  jq '.statusLine' .claude/settings.json
  # Should show: {"type": "command", "command": ".claude/statusline-command.sh"}
  ```

- [ ] **Command path is correct**
  ```bash
  [ -f ".claude/statusline-command.sh" ] && echo "Script exists"
  ```

### 3. Dependencies Installation Verification

- [ ] **jq is installed and accessible**
  ```bash
  which jq && jq --version
  ```

- [ ] **bash is available**
  ```bash
  which bash && bash --version
  ```

- [ ] **git is available (for branch detection)**
  ```bash
  which git && git --version
  ```

- [ ] **bc is available (for calculations)**
  ```bash
  which bc && bc --version
  ```

- [ ] **awk is available (for formatting)**
  ```bash
  which awk && awk --version
  ```

### 4. Statusline Command Execution Test

- [ ] **Script executes without errors**
  ```bash
  echo '{}' | .claude/statusline-command.sh
  # Should output statusline without errors
  ```

- [ ] **Script handles minimal input**
  ```bash
  echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | .claude/statusline-command.sh
  # Should display: Test in /test
  ```

- [ ] **Script handles full Claude Code JSON input**
  ```bash
  cat > /tmp/test-input.json << 'EOF'
  {
    "session_id": "test-123",
    "model": {
      "id": "claude-sonnet-4-5-20250929",
      "display_name": "Sonnet 4.5"
    },
    "workspace": {
      "current_dir": "/mnt/test",
      "project_dir": "/mnt/test"
    },
    "cwd": "/mnt/test"
  }
  EOF
  cat /tmp/test-input.json | .claude/statusline-command.sh
  ```

### 5. Claude-Flow Integration Validation

- [ ] **.claude-flow directory structure exists**
  ```bash
  ls -la .claude-flow/ 2>/dev/null || echo "Not initialized yet"
  ```

- [ ] **swarm-config.json format is valid (if exists)**
  ```bash
  [ -f .claude-flow/swarm-config.json ] && jq . .claude-flow/swarm-config.json
  ```

- [ ] **metrics directory structure is valid (if exists)**
  ```bash
  [ -d .claude-flow/metrics ] && ls -la .claude-flow/metrics/
  ```

### 6. Error Handling Validation

- [ ] **Script handles invalid JSON gracefully**
  ```bash
  echo 'invalid json' | .claude/statusline-command.sh 2>&1
  # Should not crash, should handle error
  ```

- [ ] **Script handles missing jq command gracefully**
  ```bash
  # Temporarily hide jq and test
  (PATH=/nonexistent echo '{}' | .claude/statusline-command.sh) 2>&1
  # Should show fallback behavior
  ```

- [ ] **Script handles missing git gracefully**
  ```bash
  # In non-git directory
  cd /tmp && echo '{"model":{"display_name":"Test"},"cwd":"/tmp"}' | /path/to/statusline-command.sh
  # Should not show git branch
  ```

### 7. Performance Validation

- [ ] **Script executes in acceptable time (<100ms)**
  ```bash
  time echo '{}' | .claude/statusline-command.sh
  # Should complete in < 100ms
  ```

- [ ] **Memory usage is reasonable**
  ```bash
  /usr/bin/time -v bash -c 'echo "{}" | .claude/statusline-command.sh' 2>&1 | grep Maximum
  ```

### 8. Visual Output Validation

- [ ] **Output contains expected components**
  ```bash
  OUTPUT=$(echo '{}' | .claude/statusline-command.sh)
  echo "$OUTPUT" | grep -q "Claude" && echo "✓ Model shown"
  ```

- [ ] **ANSI color codes are present**
  ```bash
  OUTPUT=$(echo '{}' | .claude/statusline-command.sh)
  echo "$OUTPUT" | grep -q $'\033\[' && echo "✓ Colors present"
  ```

- [ ] **No literal ANSI codes in output**
  ```bash
  OUTPUT=$(echo '{}' | .claude/statusline-command.sh)
  echo "$OUTPUT" | grep -q '\\033' && echo "✗ Literal codes found" || echo "✓ Escaped properly"
  ```

## 🚀 Deployment Steps

### Step 1: Backup Current Configuration
```bash
cp .claude/settings.json .claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)
[ -f .claude/statusline-command.sh ] && cp .claude/statusline-command.sh .claude/statusline-command.sh.backup.$(date +%Y%m%d_%H%M%S)
```

### Step 2: Deploy New Statusline
```bash
# Copy the statusline script
cp /path/to/new/statusline-command.sh .claude/statusline-command.sh

# Set execute permissions
chmod +x .claude/statusline-command.sh

# Update settings.json if needed
jq '.statusLine = {"type": "command", "command": ".claude/statusline-command.sh"}' .claude/settings.json > .claude/settings.json.tmp
mv .claude/settings.json.tmp .claude/settings.json
```

### Step 3: Validate Deployment
Run all validation checks from the checklist above.

## ✅ Success Criteria

All of the following must pass:
- [ ] File permissions are correct (755 on script, 755 on directory)
- [ ] Settings.json is valid JSON with correct statusLine configuration
- [ ] All dependencies (jq, bash, git, bc, awk) are installed
- [ ] Script executes without errors on minimal input
- [ ] Script handles full Claude Code JSON input
- [ ] Error handling works for invalid JSON and missing commands
- [ ] Execution time is < 100ms
- [ ] Visual output contains expected components with ANSI colors

## ❌ Failure Criteria

Deployment fails if ANY of the following occur:
- [ ] Script is not executable
- [ ] Settings.json is invalid JSON
- [ ] Dependencies are missing
- [ ] Script crashes on valid input
- [ ] Script execution time exceeds 300ms consistently
- [ ] ANSI color codes are not properly formatted

## 📝 Notes

- Record the date/time of deployment: _______________
- Tested by: _______________
- FGSRV6 hostname: _______________
- Initial validation status: _______________
