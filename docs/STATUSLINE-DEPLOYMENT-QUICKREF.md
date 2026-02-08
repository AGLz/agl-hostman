# Statusline Deployment Quick Reference

**Task ID**: 756e6dca-7b1a-4d99-a640-bd6a5568f643
**Project**: FGSRV6 Statusline Deployment (e61f909a-bfee-486c-8f11-22a2fd9cbf6f)

---

## Scripts Created

| Script | Purpose | Location |
|--------|---------|----------|
| **deploy-statusline-to-hosts.sh** | Main deployment script | `/scripts/deploy-statusline-to-hosts.sh` |
| **verify-statusline-hosts.sh** | Verification script | `/scripts/verify-statusline-hosts.sh` |
| **Deployment Guide** | Complete documentation | `/docs/STATUSLINE-DEPLOYMENT-GUIDE.md` |
| **Quick Reference** | This file | `/docs/STATUSLINE-DEPLOYMENT-QUICKREF.md` |

---

## Common Commands

### Deploy to All Hosts
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/deploy-statusline-to-hosts.sh
```

### Deploy to Specific Hosts
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts,ct183-ts
```

### Parallel Deployment (Fast)
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts --parallel
```

### Dry Run (Test)
```bash
./scripts/deploy-statusline-to-hosts.sh --dry-run
```

### Verify Deployment
```bash
./scripts/verify-statusline-hosts.sh
```

### Force Re-deployment
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1 --force
```

---

## Available Hosts

| Hostname | IP | Description |
|----------|-----|-------------|
| **aglsrv1** | 192.168.0.245 | Main Proxmox Host |
| **aglsrv6-ts** | 100.98.108.66 | Remote Proxmox (Tailscale) |
| **ct179-ts** | 100.94.221.87 | agldv03 Dev (Tailscale) |
| **ct180-ts** | 100.80.30.60 | Dokploy (Tailscale) |
| **ct183-ts** | 100.80.30.59 | Archon MCP (Tailscale) |
| **fgsrv6-ts** | 100.83.51.9 | WireGuard Hub (Tailscale) |

---

## jq Dependency Verification

The deployment script **automatically verifies and installs jq** on all target hosts.

### What Gets Checked:
- ✓ jq existence (`which jq`)
- ✓ Automatic installation if missing
- ✓ Version reporting
- ✓ Installation error handling

### Manual jq Installation:
```bash
ssh root@<host> 'apt-get update && apt-get install -y jq'
```

### Skip jq Check:
```bash
./scripts/deploy-statusline-to-hosts.sh --skip-jq-check
```

---

## Deployment Process Flow

```
1. Parse host specifications
   ↓
2. Validate source file
   ↓
3. For each host:
   a. Test SSH connection
   b. Verify jq dependency (install if needed)
   c. Create timestamped backup
   d. Transfer statusline-command.sh
   e. Set executable permissions
   f. Validate with test execution
   ↓
4. Generate deployment report
   ↓
5. Display summary and next steps
```

---

## What Gets Deployed

**Source**: `/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh`

**Target**: `/root/.claude/statusline-command.sh` on each host

**Backup**: `/root/.claude/statusline-command.sh.backup.YYYYMMDD_HHMMSS`

---

## Post-Deployment Steps

### 1. Restart Claude Code
```bash
ssh root@<host>
# Restart Claude Code service/process
```

### 2. Verify Configuration
```bash
ssh root@<host> 'cat .claude/settings.json'
```

Expected:
```json
{
  "statusLine": {
    "type": "command",
    "command": ".claude/statusline-command.sh"
  }
}
```

### 3. Test Statusline
```bash
ssh root@<host> 'echo "{\"model\": {\"display_name\": \"Test\"}, \"workspace\": {\"current_dir\": \"/root\"}}" | .claude/statusline-command.sh'
```

---

## Rollback

### Automatic Rollback
Happens automatically if validation fails.

### Manual Rollback
```bash
ssh root@<host> 'ls -t .claude/statusline-command.sh.backup.* | head -1 | xargs -I {} cp {} .claude/statusline-command.sh'
```

---

## Reports

### Deployment Report
**Location**: `/docs/statusline-deployment-report-<timestamp>.md`

**Contains**:
- Executive summary
- Per-host deployment details
- Success/failure counts
- Next steps
- Rollback procedures

### Verification Report
**Location**: `/docs/statusline-verification-report-<timestamp>.md`

**Contains**:
- Per-host status
- File information
- Dependency status
- Execution test results
- Recommendations

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SSH connection failed | Check `~/.ssh/fg_srv.pem` key, verify host reachable |
| jq installation failed | Install manually: `apt-get install -y jq` |
| File transfer failed | Check disk space, network connectivity |
| Validation failed | Check file exists, executable, test manually |
| Statusline not showing | Restart Claude Code, check settings.json |

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `IDENTITY_FILE` | ~/.ssh/fg_srv.pem | SSH private key |
| `TARGET_USER` | root | SSH user |

**Usage**:
```bash
IDENTITY_FILE=~/.ssh/my_key.pem ./scripts/deploy-statusline-to-hosts.sh
```

---

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--help` | Show usage information |
| `--hosts HOSTS` | Comma-separated host list |
| `--parallel` | Enable parallel deployment |
| `--dry-run` | Test without changes |
| `--skip-jq-check` | Skip jq verification |
| `--force` | Overwrite existing files |

---

## Deployment Modes

### Sequential (Default)
- One host at a time
- Easier debugging
- Better for production
- **Use**: `./scripts/deploy-statusline-to-hosts.sh`

### Parallel
- All hosts simultaneously
- Faster deployment
- Harder debugging
- **Use**: `./scripts/deploy-statusline-to-hosts.sh --parallel`

---

## Custom Host Deployment

Deploy to host not in predefined list:

```bash
./scripts/deploy-statusline-to-hosts.sh \
  --hosts myhost:192.168.1.100:/root/.claude
```

**Format**: `hostname:ip:target_dir`

---

## Key Features

✓ **Automatic jq verification and installation**
✓ **Backup and rollback capabilities**
✓ **Comprehensive validation**
✓ **Parallel deployment support**
✓ **Detailed reporting**
✓ **Dry-run mode for testing**
✓ **Error handling and recovery**

---

## Files Reference

| File | Purpose |
|------|---------|
| `/scripts/deploy-statusline-to-hosts.sh` | Main deployment script |
| `/scripts/verify-statusline-hosts.sh` | Verification script |
| `/scripts/copy-statusline-to-fgsrv6.sh` | Original template |
| `/docs/STATUSLINE-DEPLOYMENT-GUIDE.md` | Complete guide |
| `/docs/STATUSLINE-DEPLOYMENT-QUICKREF.md` | This quick reference |
| `/.claude/statusline-command.sh` | Source statusline script |

---

## Success Criteria

Deployment successful when:
- ✓ All hosts reachable via SSH
- ✓ jq installed on all hosts
- ✓ Statusline script transferred
- ✓ Files executable
- ✓ Validation tests pass
- ✓ Report generated

---

## Getting Help

1. **Check logs**: `/tmp/statusline-deploy-*.log`
2. **Check reports**: `/docs/statusline-*-report-*.md`
3. **Test manually**: SSH to host and run statusline
4. **Review documentation**: `/docs/STATUSLINE-DEPLOYMENT-GUIDE.md`

---

**Version**: 1.0.0
**Created**: 2026-02-08
**Task**: 756e6dca-7b1a-4d99-a640-bd6a5568f643
