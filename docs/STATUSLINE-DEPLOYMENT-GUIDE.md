# Statusline Multi-Host Deployment Guide

**Task ID**: 756e6dca-7b1a-4d99-a640-bd6a5568f643
**Project**: FGSRV6 Statusline Deployment (e61f909a-bfee-486c-8f11-22a2fd9cbf6f)
**Created**: 2026-02-08
**Status**: Production Ready

---

## Overview

This deployment script extends the statusline deployment from FGSRV6 to other infrastructure hosts. It reuses the proven `copy-statusline-to-fgsrv6.sh` template with enhanced features for multi-host deployment.

---

## Quick Start

### Deploy to All Predefined Hosts
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./scripts/deploy-statusline-to-hosts.sh
```

### Deploy to Specific Hosts
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts
```

### Parallel Deployment (Faster)
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts,ct183-ts --parallel
```

### Dry Run (Test Without Changes)
```bash
./scripts/deploy-statusline-to-hosts.sh --dry-run
```

---

## Predefined Hosts

| Hostname | IP Address | Target Directory | Description | Network |
|----------|------------|------------------|-------------|---------|
| **aglsrv1** | 192.168.0.245 | /root/.claude | Main Proxmox Host | LAN |
| **aglsrv6-ts** | 100.98.108.66 | /root/.claude | Remote Proxmox Host | Tailscale |
| **ct179-ts** | 100.94.221.87 | /root/.claude | agldv03 Development | Tailscale |
| **ct180-ts** | 100.80.30.60 | /root/.claude | Dokploy Platform | Tailscale |
| **ct183-ts** | 100.80.30.59 | /root/.claude | Archon MCP Server | Tailscale |
| **fgsrv6-ts** | 100.83.51.9 | /root/.claude | WireGuard Hub | Tailscale |

---

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--help` | Show usage information |
| `--hosts HOST1,HOST2` | Comma-separated list of hosts to deploy |
| `--parallel` | Enable parallel deployment mode |
| `--dry-run` | Show what would be done without making changes |
| `--skip-jq-check` | Skip jq dependency verification |
| `--force` | Deploy even if statusline already exists |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IDENTITY_FILE` | ~/.ssh/fg_srv.pem | SSH private key file |
| `TARGET_USER` | root | SSH user for deployment |

---

## Deployment Process

The script follows a comprehensive deployment process:

### 1. Pre-Deployment Validation
- ✓ Validate source file exists and is readable
- ✓ Parse host specifications
- ✓ Display deployment plan

### 2. Per-Host Deployment
For each host, the script:
- ✓ Tests SSH connection (10s timeout)
- ✓ Verifies jq dependency (installs if missing)
- ✓ Creates timestamped backup
- ✓ Transfers statusline-command.sh
- ✓ Sets executable permissions
- ✓ Validates deployment with test execution

### 3. Error Handling
- ✓ Automatic rollback on validation failure
- ✓ Comprehensive error logging
- ✓ Deployment status tracking

### 4. Post-Deployment
- ✓ Generates deployment report (Markdown)
- ✓ Provides next steps
- ✓ Documents rollback procedures

---

## jq Dependency Management

The script automatically verifies and installs jq on target hosts:

### Automatic Installation
If jq is missing, the script attempts:
```bash
apt-get update -qq && apt-get install -y jq
```

### Manual Installation
If automatic installation fails:
```bash
ssh root@<host> 'apt-get update && apt-get install -y jq'
```

### Skip jq Check
For hosts where jq is already verified:
```bash
./scripts/deploy-statusline-to-hosts.sh --skip-jq-check
```

---

## Custom Host Deployment

Deploy to a host not in the predefined list:

```bash
./scripts/deploy-statusline-to-hosts.sh \
  --hosts myhost:192.168.1.100:/root/.claude
```

**Host Format**: `hostname:ip:target_dir`

---

## Deployment Modes

### Sequential Mode (Default)
Deploys to hosts one at a time:
- **Pros**: Easier to debug, sequential output
- **Cons**: Slower for multiple hosts
- **Use**: Production deployments, troubleshooting

```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts
```

### Parallel Mode
Deploys to all hosts simultaneously:
- **Pros**: Much faster for multiple hosts
- **Cons**: Harder to debug, interleaved output
- **Use**: Bulk deployments, trusted hosts

```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1,ct179-ts,ct183-ts --parallel
```

---

## Validation and Testing

### Automated Validation
The script automatically validates:
1. File exists at target location
2. File is executable (chmod +x)
3. File size matches source
4. Script executes without errors

### Manual Testing
After deployment, test manually:

```bash
# Test statusline execution
ssh root@<host> 'echo "{\"model\": {\"display_name\": \"Test\"}, \"workspace\": {\"current_dir\": \"/root\"}}" | .claude/statusline-command.sh'

# Verify configuration
ssh root@<host> 'cat .claude/settings.json'
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

---

## Rollback Procedures

### Automatic Rollback
If validation fails, the script automatically:
1. Detects validation failure
2. Finds latest backup file
3. Restores from backup
4. Logs rollback action

### Manual Rollback
```bash
# SSH into host
ssh root@<host>

# List available backups
ls -lht .claude/statusline-command.sh.backup.*

# Restore from specific backup
cp .claude/statusline-command.sh.backup.20260208_143022 .claude/statusline-command.sh

# Verify restoration
echo '{"model": {"display_name": "Test"}, "workspace": {"current_dir": "/root"}}' | .claude/statusline-command.sh
```

---

## Troubleshooting

### SSH Connection Failed
**Symptoms**: `Cannot connect to root@<ip>`

**Solutions**:
1. Check host is reachable: `ping <ip>`
2. Verify SSH key: `ls -la ~/.ssh/fg_srv.pem`
3. Test SSH manually: `ssh -i ~/.ssh/fg_srv.pem root@<ip> echo OK`
4. Check firewall rules
5. Verify user has SSH access

### jq Installation Failed
**Symptoms**: `Failed to install jq on <hostname>`

**Solutions**:
1. Install jq manually: `ssh root@<host> 'apt-get install -y jq'`
2. Check apt repository: `ssh root@<host> 'apt-get update'`
3. Verify sudo permissions: `ssh root@<host> 'sudo -v'`

### File Transfer Failed
**Symptoms**: `File transfer failed to <hostname>`

**Solutions**:
1. Check disk space: `ssh root@<host> 'df -h'`
2. Verify target directory: `ssh root@<host> 'ls -ld /root/.claude'`
3. Check network connectivity: `ping <host>`
4. Try manual copy: `scp .claude/statusline-command.sh root@<host>:/root/.claude/`

### Validation Failed
**Symptoms**: `Validation failed on <hostname>`

**Solutions**:
1. Check file exists: `ssh root@<host> 'ls -lh .claude/statusline-command.sh'`
2. Verify permissions: `ssh root@<host> 'test -x .claude/statusline-command.sh && echo OK'`
3. Test execution manually (see Validation section above)
4. Check dependencies: `ssh root@<host> 'which jq bash git'`
5. Review deployment log: `cat /tmp/statusline-deploy-*.log`

### Statusline Not Displaying
**Symptoms**: Statusline doesn't appear after deployment

**Solutions**:
1. Restart Claude Code on the host
2. Verify settings.json configuration (see Validation section)
3. Check file permissions: `ssh root@<host> 'ls -la .claude/statusline-command.sh'`
4. Test manual execution (see Validation section above)

---

## Deployment Reports

After each deployment, a detailed report is generated:

**Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/statusline-deployment-report-<timestamp>.md`

**Report Contents**:
- Executive summary (total hosts, success rate)
- Per-host deployment details
- Next steps for verification
- Rollback procedures
- Dependency verification status

---

## Logging

All deployment operations are logged:

**Log Location**: `/tmp/statusline-deploy-<timestamp>.log`

**Log Contents**:
- Timestamp for each operation
- Color-coded output (INFO, SUCCESS, WARNING, ERROR)
- SSH command outputs
- Validation results
- Error messages and stack traces

---

## Best Practices

### 1. Pre-Deployment Checklist
- [ ] Verify SSH access to all target hosts
- [ ] Confirm jq can be installed (or pre-install)
- [ ] Check disk space on target hosts
- [ ] Test with --dry-run first
- [ ] Backup existing configurations

### 2. Deployment Strategy
- **Start Small**: Deploy to 1-2 hosts first
- **Test Thoroughly**: Verify statusline works correctly
- **Scale Up**: Deploy to remaining hosts
- **Monitor**: Check for issues in logs

### 3. Production Deployments
- Use --dry-run for testing
- Deploy to non-critical hosts first
- Have rollback plan ready
- Document any custom configurations
- Monitor post-deployment

### 4. Security Considerations
- Use SSH key authentication (no passwords)
- Verify SSH key permissions: `chmod 600 ~/.ssh/fg_srv.pem`
- Use Tailscale IPs when possible (more secure)
- Limit SSH access to necessary users only
- Review deployment logs for security issues

---

## Advanced Usage

### Deploy with Custom SSH Key
```bash
IDENTITY_FILE=~/.ssh/my_key.pem ./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1
```

### Deploy to Non-Root User
```bash
TARGET_USER=ubuntu ./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1
```

### Force Re-deployment
```bash
./scripts/deploy-statusline-to-hosts.sh --hosts aglsrv1 --force
```

### Deploy to Hosts from File
```bash
# Create hosts file
cat > hosts.txt <<EOF
aglsrv1:192.168.0.245:/root/.claude
ct179-ts:100.94.221.87:/root/.claude
ct183-ts:100.80.30.59:/root/.claude
EOF

# Deploy (requires reading file)
HOSTS=$(cat hosts.txt | tr '\n' ',')
./scripts/deploy-statusline-to-hosts.sh --hosts "${HOSTS%,}"
```

---

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Deploy Statusline

on:
  workflow_dispatch:
    inputs:
      hosts:
        description: 'Hosts to deploy (comma-separated)'
        required: true
        default: 'aglsrv1,ct179-ts'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy statusline
        env:
          IDENTITY_FILE: ${{ secrets.SSH_PRIVATE_KEY }}
        run: |
          ./scripts/deploy-statusline-to-hosts.sh \
            --hosts ${{ github.event.inputs.hosts }} \
            --parallel
```

---

## Related Documentation

- **Statusline Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/deployment-package/fgsrv6/STATUSLINE_DOCUMENTATION.md`
- **FGSRV6 Deployment**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/FGSRV6-STATUSLINE-DEPLOYMENT.md`
- **Infrastructure Status**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRASTRUCTURE-STATUS.md`
- **SSH Configuration**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/SSH-CONFIG.md`

---

## Support and Maintenance

### Script Maintenance
- **Location**: `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/deploy-statusline-to-hosts.sh`
- **Version**: 1.0.0
- **Last Updated**: 2026-02-08
- **Maintainer**: Deployment Engineering Team

### Getting Help
1. Review deployment logs: `/tmp/statusline-deploy-*.log`
2. Check deployment reports: `/docs/statusline-deployment-report-*.md`
3. Consult troubleshooting section above
4. Review infrastructure documentation

---

## Success Criteria

Deployment is considered successful when:
1. All selected hosts are reachable via SSH
2. jq is verified/installed on all hosts
3. Statusline script is transferred to all hosts
4. Files are executable on all hosts
5. Validation tests pass on all hosts
6. No errors in deployment logs
7. Deployment report is generated

---

**Document Version**: 1.0.0
**Last Updated**: 2026-02-08
**Status**: Production Ready
