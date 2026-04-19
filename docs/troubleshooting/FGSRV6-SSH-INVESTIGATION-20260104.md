# FGSRV6 SSH Diagnostic Comparison Report
**Date**: 2026-01-04
**Investigation**: Session 16 - Root Cause Analysis

---

## Executive Summary

**ROOT CAUSE IDENTIFIED**: SSH service on FGSRV6 is NOT responding with protocol banners after TCP connection establishment.

**Impact**: Cannot deploy statusline to FGSRV6 via SSH until SSH daemon is repaired/restarted on the server.

---

## Network Connectivity Comparison

### External IP: 186.202.57.120
**TCP Connection**: ❌ **FAILED**
- All connection attempts timeout (15+ seconds)
- Port 22 not reachable at network layer
- Likely network routing issue or server firewall blocking external access

**Test Results**:
```
1. TCP test with nc: [TIMEOUT - no response]
2. SSH banner test: [TIMEOUT - no response]
3. Bash TCP test: [TIMEOUT - no response]
4. Protocol negotiation: [TIMEOUT - no response]
```

**Conclusion**: External IP is completely unreachable, not just SSH issue.

---

### Tailscale IP: 10.6.0.5
**TCP Connection**: ✅ **SUCCESS**
- Port 22 accepts TCP connections immediately
- Connection established within 1 second

**SSH Protocol**: ❌ **FAILED**
- Server does NOT send SSH version banner
- No "SSH-2.0-..." string received
- SSH clients timeout waiting for banner

**Test Results**:
```
1. TCP test with nc: ✅ Connection to 10.6.0.5 22 port [tcp/ssh] succeeded!
2. SSH banner test: ❌ [NO OUTPUT - no banner received]
3. Bash TCP test: ❌ [NO OUTPUT - no banner received]
4. Protocol negotiation: ❌ [NO RESPONSE to client version string]
```

**Conclusion**: TCP works but SSH daemon not sending protocol banner.

---

## Technical Analysis

### SSH Connection Phases
1. **TCP Handshake**: ✅ SUCCESS on 10.6.0.5
2. **Banner Exchange**: ❌ **FAILURE POINT** - Server doesn't send "SSH-2.0-OpenSSH_X.X"
3. **Key Exchange**: Never reached (blocked at phase 2)
4. **Authentication**: Never reached (blocked at phase 2)

### Banner Exchange Protocol
**Expected Behavior**:
```
Client connects → Server immediately sends "SSH-2.0-OpenSSH_8.9p1 Ubuntu-3" → Client responds with version → Continue to key exchange
```

**Actual Behavior on 10.6.0.5**:
```
Client connects → [NOTHING] → Client waits indefinitely → Timeout after 10-20 seconds
```

### Identity File Investigation (Sessions 12-16)
**PROVEN NOT THE CAUSE**:
- Session 12 (with `-i ~/.ssh/fg_srv.pem`): Banner exchange timeout
- Session 15 (without `-i`, using default keys): Banner exchange timeout WITH valid keys found
- Both tests fail at same phase regardless of key configuration
- Banner exchange happens BEFORE authentication, so keys are irrelevant

---

## Possible Root Causes

### Most Likely: SSH Daemon Not Running
**Symptoms**: TCP accepts but no protocol response
**Indicators**:
- Port 22 is open (something is listening)
- No SSH banner sent
- No response to protocol negotiation
**Fix**: Restart sshd on server or check if it crashed

### Port Forwarding to Wrong Service
**Symptoms**: TCP succeeds but wrong protocol
**Indicators**:
- Tailscale might be forwarding port 22 to wrong internal port/service
- Some other service listening on port 22 (not SSH)
**Fix**: Check Tailscale configuration and server port mappings

### SSH Daemon Misconfiguration
**Symptoms**: Daemon running but not sending banner
**Indicators**:
- Banner directive in sshd_config set to "none"
- Custom SSH daemon with broken banner implementation
**Fix**: Check /etc/ssh/sshd_config for Banner settings

### TCP Wrapper Interception
**Symptoms**: Connection accepted but not proxied
**Indicators**:
- tcpd or similar intercepting but not forwarding to sshd
- hosts.allow/hosts.deny blocking after TCP accept
**Fix**: Check /etc/hosts.allow and /etc/hosts.deny

---

## Network Topology Analysis

```
Local Client (CT131)
    ↓
    ├─→ External IP: 186.202.57.120:22 → ❌ UNREACHABLE (TCP timeout)
    │
    └─→ Tailscale VPN: 10.6.0.5:22 → ✅ TCP SUCCESS → ❌ SSH BANNER FAIL
                                            ↓
                                        [Something listening on port 22]
                                            ↓
                                        [Not responding with SSH protocol]
```

---

## Diagnostic Evidence Summary

### Session 12: Initial SSH Verbose Test (with `-i`)
```
debug1: Connecting to 10.6.0.5 [10.6.0.5] port 22.
debug1: Connection established.
debug1: identity file /root/.ssh/fg_srv.pem type -1
debug1: Local version string SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u7
Connection timed out during banner exchange
```

### Session 15: SSH Test Without Identity File
```
debug1: Connection established.
debug1: identity file /root/.ssh/id_rsa type 0
debug1: identity file /root/.ssh/id_ed25519 type 3
debug1: Local version string SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u7
Connection timed out during banner exchange
```
**Key Finding**: Found valid keys but same failure → proves not key issue

### Session 16: Server Protocol Diagnostics
```
Test 1 (TCP): Connection to 10.6.0.5 22 port [tcp/ssh] succeeded! ✅
Test 2 (Banner): [NO OUTPUT] ❌
Test 3 (Telnet): [NO OUTPUT] ❌
Test 4 (Negotiation): [NO OUTPUT] ❌
```
**Key Finding**: TCP works, SSH protocol doesn't

---

## Recommended Actions

### Immediate Next Steps (Require Server Access)
1. **Check SSH daemon status on FGSRV6**:
   ```bash
   # Via console or alternative access method
   systemctl status sshd
   journalctl -u sshd -n 50
   ```

2. **Restart SSH daemon**:
   ```bash
   systemctl restart sshd
   systemctl status sshd
   ```

3. **Verify SSH is listening**:
   ```bash
   netstat -tlnp | grep :22
   ss -tlnp | grep :22
   ```

4. **Check sshd configuration**:
   ```bash
   cat /etc/ssh/sshd_config | grep -i banner
   sshd -t  # Test configuration
   ```

### Alternative Access Methods
- **Physical console access** to FGSRV6
- **IPMI/iLO/remote management** interface
- **Proxmox VE console** if FGSRV6 is a VM
- **Alternative SSH port** if configured
- **Serial console** via Tailscale or direct connection

### Verification After Fix
```bash
# Test from CT131 after server-side fix
timeout 10 nc 10.6.0.5 22 < /dev/null
# Should see: SSH-2.0-OpenSSH_X.X

ssh -v root@10.6.0.5 "echo 'Connection OK'"
# Should complete banner exchange and reach authentication
```

---

## Deployment Status

**Current Status**: ⚠️ **BLOCKED** - Cannot deploy until SSH service responds

**Deliverables Ready**:
- ✅ `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/copy-statusline-to-fgsrv6.sh` (325 lines)
- ✅ `/mnt/overpower/apps/dev/agl/agl-hostman/docs/FGSRV6-STATUSLINE-DEPLOYMENT.md` (307 lines)
- ✅ Source file validated: `.claude/statusline-command.sh` (177 lines, 6239 bytes)

**Blocked On**:
- SSH daemon on FGSRV6 not sending protocol banners
- Requires server-side investigation and fix

**Ready to Deploy When**:
- SSH service on 10.6.0.5 responds with banner
- Connection test passes: `ssh root@10.6.0.5 "echo OK"`

---

## Files Created This Investigation

1. `/tmp/server-diagnostic.sh` - Tailscale IP diagnostics
2. `/tmp/server-diagnostic.log` - Tailscale IP results
3. `/tmp/external-ip-diagnostic.sh` - External IP diagnostics
4. `/tmp/external-ip-diagnostic.log` - External IP results
5. `/tmp/ssh-no-identity-test.log` - SSH without `-i` flag test (Session 15)
6. `/tmp/ssh-diagnostic-comparison.md` - This comprehensive report

---

**Report Version**: 1.0
**Last Updated**: 2026-01-04 (Session 16)
**Investigation Status**: ROOT CAUSE IDENTIFIED - Server-side SSH daemon issue
**Action Required**: Server access needed to restart/repair SSH daemon on FGSRV6
