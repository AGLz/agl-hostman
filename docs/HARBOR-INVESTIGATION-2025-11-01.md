# Harbor Registry Investigation - 2025-11-01

**Container**: CT182
**IP Address**: 192.168.0.182
**Domain**: harbor.aglz.io
**Status**: ⚠️ PARTIALLY WORKING

---

## 🔍 Investigation Summary

### Trigger
Hive-mind analysis from previous session reported:
> "Harbor Registry Down (502 errors)" - **P0 Blocker**

### Findings

**✅ WORKING Components**:
1. **Harbor Web UI** (Port 80/443)
   - Status: ✅ **200 OK**
   - Endpoint: https://192.168.0.182
   - Response: Valid HTML (785 bytes)

2. **Harbor API** (Port 443/api)
   - Status: ✅ **OPERATIONAL**
   - Endpoint: https://192.168.0.182/api/v2.0/systeminfo
   - Version: **v2.12.2-73072d0d**
   - Auth Mode: `db_auth`
   - Self Registration: `false`

**🔴 NOT WORKING Components**:
1. **Harbor Registry** (Port 5000)
   - Status: 🔴 **TIMEOUT**
   - Endpoint: http://harbor.aglz.io:5000/v2/
   - Error: `Connection timed out after 5000 milliseconds`
   - Impact: Cannot push/pull Docker images

---

## 📊 Test Results

### Network Connectivity
```bash
# Ping test
ping 192.168.0.182
✅ PASS - 0% packet loss (0.338ms avg)

# HTTPS Web UI
curl -I https://192.168.0.182
✅ PASS - HTTP/1.1 200 OK

# Harbor API
curl https://192.168.0.182/api/v2.0/systeminfo
✅ PASS - Valid JSON response

# Registry endpoint
curl http://harbor.aglz.io:5000/v2/
🔴 FAIL - Connection timeout (5000ms)
```

### SSH Access
```bash
# Direct SSH attempt
ssh root@192.168.0.182
🔴 FAIL - Permission denied (publickey,password)

# WireGuard mesh
wg show | grep 182
🔴 NOT FOUND - CT182 not in WireGuard mesh
```

---

## 🔧 Root Cause Analysis

### Problem 1: Registry Port Not Accessible
**Symptom**: Port 5000 timeout
**Likely Causes**:
1. Harbor registry container not running
2. Docker registry service failed
3. Port 5000 not exposed/mapped correctly
4. Firewall blocking port 5000

### Problem 2: SSH Access Denied
**Symptom**: Permission denied on SSH
**Causes**:
1. No SSH key configured for this container
2. Password authentication may be disabled
3. Not in WireGuard mesh (no direct network path)

### Problem 3: Missing Infrastructure Documentation
**Symptom**: CT182 not in INFRA.md
**Causes**:
- Container exists but not documented
- May have been deployed after last documentation update
- No WireGuard configuration

---

## 💡 Diagnosis

Harbor **Web UI and API are working perfectly**, but the **Docker registry service** (port 5000) is not accessible. This suggests:

1. **Nginx reverse proxy** is running and healthy (serves UI and API)
2. **Harbor Core** services are operational (API responds correctly)
3. **Registry container** is either:
   - Not running
   - Running but port not exposed
   - Running but misconfigured

---

## ✅ Recommended Actions

### Immediate (Requires CT182 Access)
1. **SSH into CT182** (need credentials or key setup)
   ```bash
   ssh root@192.168.0.182  # Get credentials from admin
   ```

2. **Check Harbor container status**
   ```bash
   docker ps --filter "name=harbor"
   docker logs harbor-registry
   ```

3. **Verify port mappings**
   ```bash
   docker port harbor-registry
   netstat -tulpn | grep 5000
   ```

4. **Check Harbor configuration**
   ```bash
   cat /data/harbor/harbor.yml | grep -A 5 "port:"
   ```

### Short Term
1. **Add CT182 to WireGuard mesh** for reliable connectivity
2. **Update INFRA.md** with CT182 details
3. **Restart registry container** if found stopped
   ```bash
   docker restart harbor-registry
   ```

### Long Term
1. **Monitor Harbor logs** for recurring issues
2. **Set up automated health checks** for registry endpoint
3. **Document recovery procedures** in runbook
4. **Configure alerting** for registry downtime

---

## 📝 Hive-Mind Report Correction

**Previous Report**: "Harbor Registry Down (502 errors)"
**Actual Status**: Harbor Web UI and API are **operational**. Only the Docker registry service (port 5000) is inaccessible.

**Error Classification**:
- Previous: 🔴 **P0 Blocker** - "Harbor completely down"
- Corrected: ⚠️ **P1 Issue** - "Registry service unavailable, UI/API working"

**Impact**:
- ✅ Can access Harbor Web UI
- ✅ Can use Harbor API
- 🔴 Cannot push/pull Docker images

---

## 🎯 Next Steps

**Priority**: **HIGH** (but not P0 blocker)

**Who**: Infrastructure admin with CT182 access

**Steps**:
1. Obtain SSH credentials for CT182
2. SSH into container
3. Run diagnostic commands (see Recommended Actions)
4. Restart registry service if needed
5. Update documentation
6. Verify docker push/pull works

**Time Estimate**: 30-60 minutes (assuming simple service restart)

---

## 📞 Support Information

**Container**: CT182
**Host**: AGLSRV1 (192.168.0.245)
**Owner**: Infrastructure team
**Contacts**: See internal wiki

---

**Investigation Date**: 2025-11-01
**Investigator**: Claude Code (agl-hostman project)
**Session ID**: session-1761972102758-qp6xdsu86
**Status**: ⏸️ Investigation complete, awaiting SSH access for remediation

🤖 Generated with [Claude Code](https://claude.com/claude-code)
