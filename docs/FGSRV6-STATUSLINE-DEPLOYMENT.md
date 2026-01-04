# FGSRV6 Statusline Deployment - Execution Plan

**Created**: 2026-01-04
**Agent**: Coder Agent (Hive Mind Coordination)
**Mission**: Deploy statusline-command.sh to FGSRV6 with backup and validation

---

## 📋 Deployment Summary

**Source File**: `/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh` (177 lines)
**Target Host**: `root@186.202.57.120` (or `10.6.0.5` via Tailscale)
**Target Directory**: `/root/.claude/`
**Deployment Script**: `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/copy-statusline-to-fgsrv6.sh`

---

## 🚀 Quick Start

### Standard Deployment (External IP)
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/copy-statusline-to-fgsrv6.sh
```

### Deployment via Tailscale (Internal Network)
```bash
./scripts/copy-statusline-to-fgsrv6.sh --tailscale
```

### Dry Run (Test Without Changes)
```bash
./scripts/copy-statusline-to-fgsrv6.sh --dry-run
```

---

## 📝 Execution Plan

### Phase 1: Pre-Deployment Validation ✅
1. **Validate source file exists and is readable**
   - Check: `/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh`
   - Verify: File size and permissions

2. **Test SSH connection to FGSRV6**
   - Primary: `root@186.202.57.120`
   - Fallback: `root@10.6.0.5` (Tailscale)
   - Timeout: 10 seconds

### Phase 2: Backup ✅
1. **Create timestamped backup on FGSRV6**
   - Format: `statusline-command.sh.backup.YYYYMMDD_HHMMSS`
   - Location: `/root/.claude/`
   - List existing backups for reference

### Phase 3: Transfer ✅
1. **Copy file via SCP**
   - Command: `scp -q <source> root@<host>:/root/.claude/statusline-command.sh`
   - Quiet mode for clean output
   - Error handling if transfer fails

### Phase 4: Configuration ✅
1. **Set executable permissions**
   - Command: `chmod +x /root/.claude/statusline-command.sh`
   - Verify: Check with `-x` test

### Phase 5: Validation ✅
1. **Verify file deployment**
   - File exists at target location
   - File is executable
   - File size matches source (177 lines)

2. **Test execution**
   - Run with sample JSON input:
     ```json
     {"model": {"display_name": "Claude Sonnet 4.5"}, "workspace": {"current_dir": "/root"}}
     ```
   - Verify statusline output displays correctly

3. **Check dependencies**
   - Confirm `jq` is installed (required by statusline)
   - Confirm `bc` is installed (for time calculations)
   - Confirm `git` is installed (for branch detection)

### Phase 6: Rollback Capability ✅
1. **If deployment fails**
   - Automatically restore from latest backup
   - Command: `cp <latest-backup> /root/.claude/statusline-command.sh`
   - Exit with error code

---

## 🔧 Script Features

### Command-Line Options
- `--help` - Show usage information
- `--tailscale` - Use Tailscale IP (10.6.0.5)
- `--dry-run` - Test without making changes
- `--no-backup` - Skip backup step (not recommended)

### Environment Variables
- `FGSRV6_HOST` - Override target host (default: 186.202.57.120)
- `FGSRV6_USER` - Override target user (default: root)

### Logging
- All operations logged to: `/tmp/statusline-copy-YYYYMMDD_HHMMSS.log`
- Color-coded output for easy reading
- Timestamp for each operation

### Error Handling
- Connection timeout: 10 seconds
- Automatic rollback on validation failure
- Exit codes for scripting integration

---

## ✅ Validation Checks

The script performs these automatic validations:

1. **Source Validation**
   - ✓ File exists
   - ✓ File is readable
   - ✓ File size is non-zero

2. **Connection Validation**
   - ✓ SSH connection succeeds
   - ✓ Target directory accessible

3. **Deployment Validation**
   - ✓ File transferred successfully
   - ✓ File exists at target location
   - ✓ File is executable (chmod +x)
   - ✓ File size matches source

4. **Execution Validation**
   - ✓ Script runs without errors
   - ✓ Output displays statusline correctly

---

## 🔄 Post-Deployment Steps

### 1. Restart Claude Code on FGSRV6
```bash
# SSH into FGSRV6
ssh root@186.202.57.120

# Restart Claude Code
# The statusline will now appear in your terminal prompt
```

### 2. Verify Settings Configuration
```bash
# Check settings.json has statusline configuration
cat /root/.claude/settings.json
```

Expected configuration:
```json
{
  "statusLine": {
    "type": "command",
    "command": ".claude/statusline-command.sh"
  }
}
```

### 3. Test Manually
```bash
# Run statusline script with sample input
echo '{"model": {"display_name": "Claude Sonnet 4.5"}, "workspace": {"current_dir": "/root"}}' | /root/.claude/statusline-command.sh
```

Expected output:
```
Claude Sonnet 4.5 in root [+ optional git branch, metrics, etc.]
```

---

## 🛡️ Rollback Procedure

### Automatic Rollback
The script automatically rolls back if validation fails.

### Manual Rollback
```bash
# SSH into FGSRV6
ssh root@186.202.57.120

# List available backups
ls -lht /root/.claude/statusline-command.sh.backup.*

# Restore from specific backup
cp /root/.claude/statusline-command.sh.backup.20260104_143022 /root/.claude/statusline-command.sh

# Verify restoration
/root/.claude/statusline-command.sh <<< '{"model": {"display_name": "Test"}, "workspace": {"current_dir": "/root"}}'
```

---

## 🔍 Troubleshooting

### Issue: SSH Connection Failed
**Symptoms**: `Cannot connect to root@186.202.57.120`

**Solutions**:
1. Try Tailscale option: `./scripts/copy-statusline-to-fgsrv6.sh --tailscale`
2. Check SSH key: `ssh-add -l`
3. Test connection manually: `ssh root@186.202.57.120 echo OK`
4. Verify host is reachable: `ping 186.202.57.120`

### Issue: File Transfer Failed
**Symptoms**: `File transfer failed` error

**Solutions**:
1. Check disk space on FGSRV6: `ssh root@186.202.57.120 df -h`
2. Verify source file exists: `ls -lh .claude/statusline-command.sh`
3. Check network connectivity: `ping 186.202.57.120`
4. Try manual copy: `scp .claude/statusline-command.sh root@186.202.57.120:/root/.claude/`

### Issue: Validation Failed
**Symptoms**: `Validation failed` after deployment

**Solutions**:
1. Check file exists: `ssh root@186.202.57.120 ls -lh /root/.claude/statusline-command.sh`
2. Verify executable bit: `ssh root@186.202.57.120 test -x /root/.claude/statusline-command.sh && echo OK`
3. Test execution manually: `ssh root@186.202.57.120 'echo "{}" | /root/.claude/statusline-command.sh'`
4. Check dependencies: `ssh root@186.202.57.120 which jq bc git`

### Issue: Statusline Not Displaying
**Symptoms**: Statusline doesn't appear after deployment

**Solutions**:
1. Verify settings.json: `ssh root@186.202.57.120 cat /root/.claude/settings.json`
2. Check configuration:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": ".claude/statusline-command.sh"
     }
   }
   ```
3. Run installation script: `ssh root@186.202.57.120 /root/deployment-package/fgsrv6/install.sh`
4. Restart Claude Code on FGSRV6

---

## 📊 Dependencies

### Required on FGSRV6
- **jq** - JSON parsing (for model/directory info)
- **bc** - Calculator (for time formatting)
- **git** - Version control (for branch detection)
- **curl** - HTTP client (for potential updates)

### Installation
```bash
# These are automatically installed by install.sh
# Manual installation if needed:
ssh root@186.202.57.120 'apt-get update && apt-get install -y jq bc git curl'
```

---

## 🔗 Related Documentation

- **Statusline Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/deployment-package/fgsrv6/STATUSLINE_DOCUMENTATION.md`
- **Full Orchestration Script**: `/mnt/overpower/apps/dev/agl/agl-hostman/tests/statusline-fgsrv6/deploy-statusline.sh`
- **Installation Script**: `/mnt/overpower/apps/dev/agl/agl-hostman/deployment-package/fgsrv6/install.sh`
- **FGSRV6 Connection Details**: See CT131-MYSQL-CREDENTIALS.md for infrastructure context

---

## 📈 Success Criteria

✅ Deployment considered successful when:
1. Source file validated and readable
2. SSH connection to FGSRV6 successful
3. Backup created with timestamp
4. File transferred to `/root/.claude/statusline-command.sh`
5. Execute permissions set (`chmod +x`)
6. File exists at target location
7. Validation test passes (sample execution)
8. No errors in deployment log

---

## 🎯 Implementation Details

**Script Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/copy-statusline-to-fgsrv6.sh`
**Lines of Code**: 351 lines
**Functions**: 11 (validate, test, backup, transfer, permissions, validate, rollback, etc.)
**Error Handling**: Comprehensive with automatic rollback
**Logging**: Complete operation log with timestamps
**Security**: Uses SSH key authentication, no passwords in code

---

**Document Version**: 1.0
**Last Updated**: 2026-01-04
**Maintainer**: Coder Agent (agl-hostman project)
**Mission Status**: ✅ COMPLETE - Ready for Deployment
