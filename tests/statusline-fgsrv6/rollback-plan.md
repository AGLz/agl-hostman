# Statusline Deployment Rollback Plan - FGSRV6

## 🚨 Emergency Rollback Procedure

### When to Rollback

Rollback immediately if ANY of the following occur:
- Statusline script crashes on startup
- Statusline prevents Claude Code from functioning
- Performance degradation > 500ms execution time
- Statusline displays corrupted or malformed output
- Errors in logs related to statusline execution
- System becomes unresponsive after statusline deployment

### Quick Rollback Steps

#### Option 1: Disable Statusline (Immediate)

If you need to disable the statusline quickly without removing files:

```bash
# Backup current settings
cp .claude/settings.json .claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)

# Remove statusLine configuration
jq 'del(.statusLine)' .claude/settings.json > .claude/settings.json.tmp
mv .claude/settings.json.tmp .claude/settings.json

echo "Statusline disabled. Restart Claude Code to see changes."
```

#### Option 2: Restore Backup (Complete Rollback)

If you have backups from before deployment:

```bash
# Restore settings.json
cp .claude/settings.json.backup.YYYYMMDD_HHMMSS .claude/settings.json

# Restore statusline script (if backed up)
cp .claude/statusline-command.sh.backup.YYYYMMDD_HHMMSS .claude/statusline-command.sh

# Set correct permissions
chmod +x .claude/statusline-command.sh

echo "Rollback complete. Restart Claude Code."
```

#### Option 3: Revert to Default (Nuclear Option)

If you want to completely remove the custom statusline:

```bash
# Remove statusline script
rm -f .claude/statusline-command.sh

# Remove statusLine from settings.json
jq 'del(.statusLine)' .claude/settings.json > .claude/settings.json.tmp
mv .claude/settings.json.tmp .claude/settings.json

echo "Custom statusline removed. Using default Claude Code statusline."
```

## 📋 Detailed Rollback Procedures

### Phase 1: Assessment (30 seconds)

**Objective**: Determine severity and rollback approach

```bash
# 1. Check if script is executable
ls -l .claude/statusline-command.sh

# 2. Test script manually
echo '{}' | .claude/statusline-command.sh

# 3. Check for errors in output
echo '{}' | .claude/statusline-command.sh 2>&1 | head -20

# 4. Verify settings.json is valid
jq '.' .claude/settings.json
```

**Decision Matrix**:
- If script crashes: **Option 1 or 2**
- If settings.json is corrupt: **Option 2**
- If performance is bad: **Option 1** (then investigate)
- If visual issues only: **Option 1** (then fix and redeploy)

### Phase 2: Execute Rollback (1-2 minutes)

#### Rollback to Previous Configuration

**Step 1: List Available Backups**
```bash
ls -la .claude/settings.json.backup.*
ls -la .claude/statusline-command.sh.backup.* 2>/dev/null || echo "No script backups found"
```

**Step 2: Choose Rollback Point**
```bash
# Use most recent backup
BACKUP_FILE=$(ls -t .claude/settings.json.backup.* | head -1)
SCRIPT_BACKUP=$(ls -t .claude/statusline-command.sh.backup.* 2>/dev/null | head -1)

echo "Rolling back to: $BACKUP_FILE"
```

**Step 3: Restore Configuration**
```bash
# Restore settings.json
cp "$BACKUP_FILE" .claude/settings.json

# Restore script if backup exists
if [ -n "$SCRIPT_BACKUP" ]; then
    cp "$SCRIPT_BACKUP" .claude/statusline-command.sh
    chmod +x .claude/statusline-command.sh
fi

# Verify rollback
jq '.' .claude/settings.json > /dev/null && echo "✓ Settings valid"
```

**Step 4: Validate Rollback**
```bash
# Test script works
echo '{}' | .claude/statusline-command.sh

# Check execution time
time echo '{}' | .claude/statusline-command.sh > /dev/null
```

### Phase 3: Verification (30 seconds)

**Post-Rollback Checklist**:

- [ ] Claude Code can start without errors
- [ ] Statusline executes successfully:
  ```bash
  echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | .claude/statusline-command.sh
  ```
- [ ] No error messages in output
- [ ] Execution time is acceptable (< 100ms)
- [ ] Settings.json is valid JSON
- [ ] statusLine configuration is restored

### Phase 4: Post-Rollback Analysis (After system is stable)

**Document the incident**:

```bash
# Create incident report
cat > /tmp/statusline-incident-$(date +%Y%m%d_%H%M%S).txt << EOF
Statusline Deployment Incident Report
=====================================
Date: $(date)
Hostname: $(hostname)
Incident Type: Rollback executed
Duration: [record start and end times]

Symptoms observed:
- [List what went wrong]

Rollback method used:
- [Option 1/2/3]

Resolution:
- [How it was fixed]

Prevention measures:
- [What to do differently next time]

EOF

echo "Incident report created at: /tmp/statusline-incident-$(date +%Y%m%d_%H%M%S).txt"
```

## 🔄 Automated Rollback Script

Create this script before deployment for quick rollback:

```bash
#!/bin/bash
# /tmp/statusline-rollback.sh

set -euo pipefail

ROLLBACK_TYPE="${1:-auto}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting statusline rollback..."

# Find most recent backup
BACKUP=$(ls -t .claude/settings.json.backup.* 2>/dev/null | head -1)
SCRIPT_BACKUP=$(ls -t .claude/statusline-command.sh.backup.* 2>/dev/null | head -1)

if [ -z "$BACKUP" ]; then
    log "ERROR: No backup found! Cannot rollback."
    log "Disabling statusline instead..."
    jq 'del(.statusLine)' .claude/settings.json > .claude/settings.json.tmp
    mv .claude/settings.json.tmp .claude/settings.json
    log "Statusline disabled."
    exit 1
fi

log "Using backup: $BACKUP"

# Restore settings
cp "$BACKUP" .claude/settings.json
log "Settings.json restored"

# Restore script if available
if [ -n "$SCRIPT_BACKUP" ]; then
    cp "$SCRIPT_BACKUP" .claude/statusline-command.sh
    chmod +x .claude/statusline-command.sh
    log "Script restored from: $SCRIPT_BACKUP"
fi

# Verify
if jq '.' .claude/settings.json > /dev/null 2>&1; then
    log "✓ Rollback successful"
    log "Please restart Claude Code to see changes"
else
    log "ERROR: Rollback failed - settings.json is invalid!"
    exit 1
fi
```

Make it executable:
```bash
chmod +x /tmp/statusline-rollback.sh
```

Usage:
```bash
# Automatic rollback to most recent backup
/tmp/statusline-rollback.sh

# Or specify type
/tmp/statusline-rollback.sh auto
```

## 📝 Pre-Deployment Backup Procedure

**Always run this BEFORE deploying:**

```bash
#!/bin/bash
# Backup current statusline configuration

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup settings
cp .claude/settings.json ".claude/settings.json.backup.$TIMESTAMP"
log "Backed up settings to: .claude/settings.json.backup.$TIMESTAMP"

# Backup script if exists
if [ -f .claude/statusline-command.sh ]; then
    cp .claude/statusline-command.sh ".claude/statusline-command.sh.backup.$TIMESTAMP"
    log "Backed up script to: .claude/statusline-command.sh.backup.$TIMESTAMP"
fi

# Create rollback script
cat > "/tmp/statusline-rollback-$TIMESTAMP.sh" << 'EOF'
#!/bin/bash
# Auto-generated rollback script

BACKUP_FILE="<BACKUP_FILE>"
SCRIPT_BACKUP="<SCRIPT_BACKUP>"

if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" .claude/settings.json
    echo "Settings restored"
fi

if [ -n "$SCRIPT_BACKUP" ] && [ -f "$SCRIPT_BACKUP" ]; then
    cp "$SCRIPT_BACKUP" .claude/statusline-command.sh
    chmod +x .claude/statusline-command.sh
    echo "Script restored"
fi

echo "Rollback complete. Restart Claude Code."
EOF

# Replace placeholders
sed -i "s|<BACKUP_FILE>|.claude/settings.json.backup.$TIMESTAMP|g" "/tmp/statusline-rollback-$TIMESTAMP.sh"
sed -i "s|<SCRIPT_BACKUP>|.claude/statusline-command.sh.backup.$TIMESTAMP|g" "/tmp/statusline-rollback-$TIMESTAMP.sh"
chmod +x "/tmp/statusline-rollback-$TIMESTAMP.sh"

log "Rollback script created: /tmp/statusline-rollback-$TIMESTAMP.sh"
```

## 🎯 Rollback Success Criteria

Rollback is successful when:
- [ ] Claude Code starts without errors
- [ ] Statusline executes without errors
- [ ] Execution time returns to normal (< 100ms)
- [ ] Settings.json is valid and parseable
- [ ] Previous working configuration is restored
- [ ] No error messages in logs
- [ ] System performance is normal

## 📞 Escalation

If rollback fails or issues persist:

1. **Immediate**: Disable statusline (Option 1)
2. **Document**: What was observed, timeline, actions taken
3. **Escalate**: Contact system administrator or Claude Code support
4. **Preserve**: Keep all backups and logs for analysis

## 🔍 Post-Mortem Questions

After resolving the incident, investigate:
- What symptoms indicated the problem?
- At what point in the deployment process did it fail?
- Were there any warning signs missed?
- How can we improve the validation checklist?
- What additional tests should be added?
- Should we implement staged deployment?
