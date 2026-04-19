# FGSRV6 Statusline Deployment - Readiness Checklist

**Status**: ⚠️ BLOCKED - Awaiting SSH Service Repair on FGSRV6
**Last Updated**: 2026-01-04
**Investigation Sessions**: 1-17

---

## Executive Summary

All deployment artifacts are complete and validated. Deployment is blocked due to SSH daemon on FGSRV6 not responding with protocol banners after TCP connection establishment.

**Root Cause Identified**: Server at 10.6.0.5 (Tailscale IP) accepts TCP connections on port 22 but does not send SSH version banner ("SSH-2.0-..."), causing connection timeout during banner exchange phase.

---

## Pre-Deployment Verification

### ✅ Completed Client-Side Preparations

1. **Deployment Script**: `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/copy-statusline-to-fgsrv6.sh`
   - Status: ✅ Complete (325 lines)
   - Validation: Passed `bash -n` syntax check
   - Features: Backup, rollback, validation, comprehensive error handling
   - Dry-run tested: Session 3

2. **Source File**: `/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh`
   - Status: ✅ Validated (177 lines, 6239 bytes)
   - Permissions: Ready for deployment
   - Dependencies: jq, bc, git

3. **Documentation**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/FGSRV6-STATUSLINE-DEPLOYMENT.md`
   - Status: ✅ Complete (307 lines)
   - Contents: 6 deployment phases, troubleshooting guide, rollback procedures

4. **SSH Identity File**: `~/.ssh/fg_srv.pem`
   - Status: ✅ Validated (4096-bit RSA, PEM format)
   - Permissions: 600 (correct)
   - Format validation: Passed ssh-keygen and openssl checks
   - Fingerprint: SHA256:ySQxzy/hmaNts4law5lTr5Zvw+nT//gli05bVtpH1yA

5. **Investigation Documentation**:
   - Root cause analysis: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/troubleshooting/FGSRV6-SSH-INVESTIGATION-20260104.md`
   - Diagnostic evidence: Multiple test logs confirming TCP success but SSH banner failure

---

## ⚠️ Server-Side Issues (BLOCKING DEPLOYMENT)

### Issue 1: Tailscale IP (10.6.0.5) - SSH Daemon Not Responding

**Symptoms:**
- TCP connection succeeds immediately: `Connection to 10.6.0.5 22 port [tcp/ssh] succeeded!`
- Server never sends SSH version banner
- SSH clients timeout after 10-20 seconds waiting for banner
- Failure occurs BEFORE authentication phase (identity files irrelevant)

**Diagnostic Evidence:**
```bash
# Test 1: TCP Connection
$ timeout 10 nc -vz 10.6.0.5 22
Connection to 10.6.0.5 22 port [tcp/ssh] succeeded!  ✅

# Test 2: Banner Exchange
$ timeout 5 nc 10.6.0.5 22 < /dev/null
[NO OUTPUT - no banner received]  ❌

# Test 3: Protocol Negotiation
$ echo "SSH-2.0-TestClient" | timeout 5 nc 10.6.0.5 22
[NO OUTPUT - no response]  ❌
```

**Possible Root Causes:**
1. SSH daemon (sshd) not running or crashed
2. SSH daemon misconfigured (Banner directive disabled)
3. Port forwarding issue (Tailscale forwarding to wrong service)
4. TCP wrapper blocking after connection acceptance
5. Non-SSH service listening on port 22

**Required Actions (Server Access Needed):**
```bash
# 1. Check SSH daemon status
systemctl status sshd
journalctl -u sshd -n 50 --no-pager

# 2. Verify SSH process listening
ps aux | grep sshd
netstat -tlnp | grep :22

# 3. Test SSH configuration
sshd -t

# 4. Restart SSH daemon
systemctl restart sshd
systemctl status sshd

# 5. Check firewall/Tailscale routing
tailscale status
iptables -L -n -v | grep 22
```

### Issue 2: External IP (186.202.57.120) - Network Unreachable

**Symptoms:**
- All TCP connection attempts timeout after 15+ seconds
- Port 22 completely unreachable at network layer
- No response to any connection attempts

**Diagnostic Evidence:**
```bash
# All tests produced no output and timed out
$ timeout 15 nc -vz 186.202.57.120 22
[TIMEOUT - no connection]  ❌
```

**Possible Root Causes:**
1. Network routing issue
2. Firewall blocking external access
3. Server interface not listening on external IP
4. ISP blocking port 22

---

## When SSH is Restored - Deployment Steps

### Step 1: Verify SSH Connectivity

```bash
# Quick connection test
ssh -i ~/.ssh/fg_srv.pem -o ConnectTimeout=10 root@10.6.0.5 "echo 'SSH OK'"

# Should output: SSH OK
# If this succeeds, proceed to deployment
```

### Step 2: Execute Deployment Script

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman

# Deploy using Tailscale IP
./scripts/copy-statusline-to-fgsrv6.sh --tailscale

# Expected output:
# [✓] SSH connection successful
# [✓] Backup created: /root/.claude/statusline-command.sh.backup-YYYYMMDD_HHMMSS
# [✓] Source file validated (177 lines, 6239 bytes)
# [✓] File transferred successfully (6239 bytes)
# [✓] Permissions set correctly (755)
# [✓] DEPLOYMENT COMPLETE
```

### Step 3: Verify Deployment

```bash
# Test statusline on remote server
ssh -i ~/.ssh/fg_srv.pem root@10.6.0.5 ".claude/statusline-command.sh"

# Should output formatted status with:
# - Model information
# - Git branch
# - System metrics
# - Performance data
```

### Step 4: Confirm Integration

```bash
# Check settings.json on FGSRV6
ssh -i ~/.ssh/fg_srv.pem root@10.6.0.5 "cat .claude/settings.json | grep statuslineCommand"

# Should contain: "statuslineCommand": "/root/.claude/statusline-command.sh"
```

---

## Rollback Procedure (If Needed)

```bash
# Execute rollback
./scripts/copy-statusline-to-fgsrv6.sh --tailscale --rollback

# Manually restore from SSH
ssh -i ~/.ssh/fg_srv.pem root@10.6.0.5
cd ~/.claude
ls -la statusline-command.sh.backup-*
mv statusline-command.sh.backup-TIMESTAMP statusline-command.sh
chmod 755 statusline-command.sh
```

---

## Alternative Deployment Methods (If SSH Issues Persist)

### Option 1: Physical/Console Access
1. Access FGSRV6 server console directly
2. Copy file from USB/network share
3. Manually install to `/root/.claude/statusline-command.sh`

### Option 2: Proxmox VE Console
```bash
# If FGSRV6 is a VM, use Proxmox console
# Copy via clipboard or mount shared storage
```

### Option 3: Alternative SSH Port
```bash
# If SSH configured on non-standard port
./scripts/copy-statusline-to-fgsrv6.sh --tailscale --port <PORT>
```

### Option 4: Remote Management Interface
- IPMI/iLO/iDRAC interface
- Serial console via Tailscale

---

## Success Criteria

**Deployment Successful When:**
- ✅ SSH connection established and authenticated
- ✅ Original file backed up with timestamp
- ✅ New file transferred (exactly 6239 bytes)
- ✅ Permissions set to 755 (executable)
- ✅ statusline-command.sh produces valid output on FGSRV6
- ✅ Claude Code can retrieve statusline from FGSRV6

---

## Investigation Archive

**Complete diagnostic reports:**
- `/mnt/overpower/apps/dev/agl/agl-hostman/docs/troubleshooting/FGSRV6-SSH-INVESTIGATION-20260104.md`
- Investigation spanned 17 sessions
- Root cause definitively identified through systematic elimination
- External IP vs Tailscale IP comparison completed

**Key Diagnostic Logs (Temporary):**
- `/tmp/server-diagnostic.log` - Tailscale IP testing
- `/tmp/ssh-no-identity-test.log` - Identity file comparison test
- `/tmp/external-ip-diagnostic.log` - External IP testing

---

## Contact Points

**When SSH is Restored:**
1. Run verification test: `ssh root@10.6.0.5 "echo OK"`
2. Execute deployment: `./scripts/copy-statusline-to-fgsrv6.sh --tailscale`
3. Verify output: `ssh root@10.6.0.5 ".claude/statusline-command.sh"`

**For Server-Side Investigation:**
- Console/remote management access required
- Check SSH daemon status and configuration
- Review Tailscale routing and port forwarding
- Verify firewall rules on FGSRV6

---

**Document Version**: 1.0
**Created**: 2026-01-04
**Mission Sessions**: 1-17
**Status**: Ready for deployment once SSH service restored
