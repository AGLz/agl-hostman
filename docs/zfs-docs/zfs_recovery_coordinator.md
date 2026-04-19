# 🔴 ZFS Recovery Coordination Plan

## Current Status: INITIALIZING

### ⚡ IMMEDIATE ACTIONS REQUIRED

1. **Test SSH Connectivity**
   ```bash
   # Execute this command to test connection:
   ssh PROXMOX-ZFS
   ```

2. **Run Initial Diagnostic**
   ```bash
   # Copy diagnostic script to server and execute:
   scp /root/zfs_diagnostic.sh PROXMOX-ZFS:/tmp/
   ssh PROXMOX-ZFS "chmod +x /tmp/zfs_diagnostic.sh && /tmp/zfs_diagnostic.sh"
   ```

3. **Emergency Access Scenarios**
   - If SSH works: Continue with ZFS commands
   - If SSH fails: Need console access (IPMI, iLO, or physical)
   - If system in rescue mode: Boot from rescue media

### 🎯 PRIMARY OBJECTIVES

**CRITICAL PATH:**
1. Establish access to server (SSH or console)
2. Identify unavailable ZFS devices
3. Replace/re-attach devices to pool
4. Restore pool redundancy via resilver
5. Fix bootloader configuration
6. Test successful boot

### ⚠️ SAFETY PROTOCOLS

- **NO DESTRUCTIVE COMMANDS** without explicit confirmation
- **BACKUP CRITICAL DATA** before major changes
- **VERIFY EACH STEP** before proceeding
- **DOCUMENT ALL CHANGES** for rollback capability

### 🔧 RECOVERY TOOLS READY

- ZFS diagnostic script: `/root/zfs_diagnostic.sh`
- SSH config updated with PROXMOX-ZFS host
- Session logging active in `/root/zfs_session_log.md`
- Task tracking in `/root/todo_zfs_troubleshooting.md`

### 📊 SUCCESS METRICS

- ✅ SSH connection established
- ✅ ZFS rpool status visible
- ✅ Device unavailability identified
- ✅ Pool recovery initiated
- ✅ System boot restored
- ✅ Proxmox services operational

---

## 🚨 EXECUTE FIRST COMMAND NOW:

```bash
ssh PROXMOX-ZFS
```

**If connection succeeds:** Run diagnostic script
**If connection fails:** Escalate to console access

---
**Coordinator**: Queen Coordinator Agent
**Priority**: MAXIMUM
**Time Sensitivity**: CRITICAL - Server down