# Statusline Deployment Test Plan - FGSRV6

## 🎯 Test Objectives

Validate the complete deployment and functionality of Claude Code statusline script on FGSRV6 (192.168.1.131).

## 📋 Test Execution Order

### Phase 1: Pre-Deployment Verification

**Script:** `pre-deployment-checks.sh`

**Tests:**
1. ✓ Network connectivity (ping test)
2. ✓ SSH accessibility
3. ✓ Target hostname verification
4. ✓ Local source file validation
5. ✓ Dependency checks (jq, git)
6. ✓ Target directory status
7. ✓ Existing statusline detection

**Pass Criteria:**
- All network and SSH tests must pass
- Local statusline must exist and be readable
- Dependencies verified (warnings acceptable for optional items)

**Estimated Duration:** 30 seconds

---

### Phase 2: Deployment

**Script:** `deploy-and-test.sh`

**Steps:**
1. Create backup directory structure
2. Backup existing statusline (if present)
3. Create target directory
4. Copy statusline script via SCP
5. Set executable permissions
6. Verify file integrity (size + MD5)

**Pass Criteria:**
- File successfully copied
- MD5 checksum matches source
- Execute permissions set correctly

**Rollback Trigger:**
- MD5 mismatch
- Permission setting failure
- File not found after copy

**Estimated Duration:** 10 seconds

---

### Phase 3: Post-Deployment Validation

**Script:** `post-deployment-validation.sh`

**Test Suite:**

#### 1. File Integrity Tests
- File existence
- Execute permissions
- Bash syntax validation

#### 2. Functional Tests
- Basic execution with minimal input
- Git repository context handling
- Branch detection accuracy

#### 3. Integration Tests
- jq dependency validation
- Claude-flow directory structure parsing
- System metrics display
- Agent topology detection

#### 4. Performance Tests
- 10-iteration execution test
- Average execution time < 1000ms

#### 5. Real-World Context Test
- Full Claude Code context simulation
- Output formatting validation

**Pass Criteria:**
- All functional tests pass
- Performance within acceptable range
- No syntax or runtime errors

**Estimated Duration:** 60 seconds

---

### Phase 4: Rollback Testing (If Needed)

**Script:** `rollback-procedure.sh`

**Procedure:**
1. List available backups
2. Select most recent backup
3. Verify backup integrity
4. Restore previous version
5. Test restored functionality

**Pass Criteria:**
- Backup successfully restored
- Restored version executes without errors

**Estimated Duration:** 20 seconds

---

## 🚀 Quick Start Commands

### Execute Full Test Suite

```bash
# Navigate to test directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/statusline-fgsrv6

# Make all scripts executable
chmod +x *.sh

# Run complete workflow
./pre-deployment-checks.sh && \
./deploy-and-test.sh && \
./post-deployment-validation.sh
```

### Individual Test Execution

```bash
# Pre-deployment only
./pre-deployment-checks.sh

# Deploy only (after pre-checks pass)
./deploy-and-test.sh

# Validate only (after deployment)
./post-deployment-validation.sh

# Rollback (if issues detected)
./rollback-procedure.sh
```

---

## 📊 Test Results Template

### Execution Log

```
Date: _______________
Executor: _______________
Target: FGSRV6 (192.168.1.131)

Phase 1: Pre-Deployment
[ ] Network connectivity       PASS / FAIL
[ ] SSH access                 PASS / FAIL
[ ] Dependencies               PASS / FAIL / WARN
[ ] Source validation          PASS / FAIL

Phase 2: Deployment
[ ] Backup created             PASS / FAIL / N/A
[ ] File copied                PASS / FAIL
[ ] MD5 verified               PASS / FAIL
[ ] Permissions set            PASS / FAIL

Phase 3: Validation
[ ] Syntax check               PASS / FAIL
[ ] Basic execution            PASS / FAIL
[ ] Git integration            PASS / FAIL
[ ] Claude-flow parsing        PASS / FAIL
[ ] Performance (<1000ms)      PASS / FAIL

Phase 4: Rollback (if needed)
[ ] Backup restored            PASS / FAIL / N/A
[ ] Functionality verified     PASS / FAIL / N/A

Overall Result: PASS / FAIL / PARTIAL
```

---

## 🔧 Troubleshooting Guide

### Issue: jq not found on target

**Solution:**
```bash
ssh root@192.168.1.131 "apt-get update && apt-get install -y jq"
```

### Issue: Permission denied during deployment

**Solution:**
```bash
# Check SSH key authentication
ssh-copy-id root@192.168.1.131

# Or verify password authentication is enabled
```

### Issue: MD5 checksum mismatch

**Solution:**
```bash
# Re-run deployment
./deploy-and-test.sh

# If persists, check network stability
# Manual verification:
md5sum /mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh
ssh root@192.168.1.131 "md5sum /root/.claude/statusline-command.sh"
```

### Issue: Performance degradation

**Investigation:**
```bash
# Check target system load
ssh root@192.168.1.131 "uptime; free -h"

# Profile statusline execution
time ssh root@192.168.1.131 'echo "{\"model\":{\"display_name\":\"Claude\"},\"cwd\":\"/root\"}" | /root/.claude/statusline-command.sh'
```

---

## 📝 Test Environment Details

**Local System:**
- OS: Linux 6.11.0-2-pve
- Node: v18.20.8
- pnpm: 10.19.0
- Source: /mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh

**Target System (FGSRV6):**
- Hostname: mysql
- OS: Linux 6.11.0-2-pve
- Primary IP: 192.168.1.131
- Tailscale IP: 100.108.104.131
- Target Path: /root/.claude/statusline-command.sh

**Network:**
- Latency: ~0.1ms (LAN)
- SSH: Key-based authentication
- Protocol: SSH v2

---

## ✅ Success Criteria Summary

**Deployment is successful if:**
1. All pre-deployment checks pass
2. File integrity verified (MD5 + size)
3. Script executes without errors
4. Git integration functional
5. Performance within acceptable range (<1000ms avg)
6. No syntax errors detected

**Rollback required if:**
1. MD5 mismatch persists
2. Syntax errors detected
3. Runtime failures in validation
4. Performance severely degraded (>3000ms)

---

## 🔄 Continuous Validation

**Periodic Health Checks:**
```bash
# Weekly validation
0 0 * * 0 /mnt/overpower/apps/dev/agl/agl-hostman/tests/statusline-fgsrv6/post-deployment-validation.sh

# Quick health check
ssh root@192.168.1.131 'echo "{\"model\":{\"display_name\":\"Claude\"},\"cwd\":\"/root\"}" | /root/.claude/statusline-command.sh'
```

**Version Tracking:**
```bash
# Record deployment version
ssh root@192.168.1.131 "md5sum /root/.claude/statusline-command.sh" >> deployment-history.log
```

---

## 📞 Escalation Path

**If all tests fail:**
1. Verify network connectivity: `ping 192.168.1.131`
2. Check SSH service: `ssh root@192.168.1.131 "systemctl status sshd"`
3. Review system logs: `ssh root@192.168.1.131 "journalctl -xe"`
4. Contact system administrator

**If performance issues persist:**
1. Check system resources on FGSRV6
2. Profile bash script execution
3. Consider optimization or caching strategies

---

*Test plan generated by Tester Agent - Hive Mind Coordination*
*Version: 1.0*
*Last Updated: 2026-01-04*
