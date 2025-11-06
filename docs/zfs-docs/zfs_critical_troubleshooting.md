# 🔴 CRITICAL ZFS Troubleshooting Session
**Server**: Proxmox at 100.69.9.111
**Issue**: Boot failure after rpool expansion attempt
**Hardware Change**: 3x 500GB NVMe → 3x 1TB NVMe drives
**Error**: "one or more devices is currently unavailable"
**Priority**: CRITICAL - Server won't boot, data recovery needed

## 📋 Troubleshooting Task List

### Phase 1: System Assessment & SSH Access ⏳
- [ ] Establish SSH connection to 100.69.9.111
- [ ] Check system boot status and rescue mode availability
- [ ] Verify hardware detection of new NVMe drives
- [ ] Document current system state

### Phase 2: ZFS Pool Status Analysis
- [ ] Check zpool status for rpool
- [ ] Identify which devices are showing as unavailable
- [ ] Verify device paths and UUIDs
- [ ] Check for any corruption or metadata issues
- [ ] Document current pool configuration

### Phase 3: Hardware & Device Validation
- [ ] Verify all 3x 1TB NVMe drives are detected by system
- [ ] Check /dev/disk/by-id/ for device persistence
- [ ] Validate drive health with smartctl
- [ ] Confirm no hardware failures

### Phase 4: ZFS Recovery Strategy
- [ ] Assess if pool can be imported with missing devices
- [ ] Determine if pool is degraded but recoverable
- [ ] Plan device replacement/re-silvering approach
- [ ] Create recovery checkpoint before changes

### Phase 5: Pool Recovery Execution
- [ ] Replace unavailable devices in pool configuration
- [ ] Re-silver degraded pool to restore redundancy
- [ ] Verify pool integrity and bootability
- [ ] Test system boot process

### Phase 6: Validation & Documentation
- [ ] Confirm successful boot to Proxmox
- [ ] Verify all VMs and containers operational
- [ ] Document resolution steps
- [ ] Create preventive measures plan

## 🎯 Success Criteria
- ✅ System boots successfully to Proxmox
- ✅ ZFS rpool healthy and fully redundant
- ✅ No data loss
- ✅ All VMs/containers operational

## ⚠️ Critical Safety Notes
- **NO destructive operations without explicit confirmation**
- **Always verify commands before execution**
- **Maintain data integrity as top priority**
- **Create recovery points before major changes**

---
*Session started: 2025-09-25*
*Status: Initializing SSH connection*