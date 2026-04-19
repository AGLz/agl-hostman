# 🔴 CRITICAL ZFS Troubleshooting Tasks

## Server Info
- **Host**: 100.69.9.111 (PROXMOX-ZFS)
- **Issue**: Boot failure after rpool expansion
- **Hardware**: 3x 500GB NVMe → 3x 1TB NVMe drives
- **Error**: "one or more devices is currently unavailable"

## Task List

### ⏳ Phase 1: System Access & Assessment
- [ ] Test SSH connectivity to 100.69.9.111
- [ ] Identify if system is in rescue/emergency mode
- [ ] Check if we can access Proxmox rescue shell/console
- [ ] Verify system responds to ping/network connectivity

### 🔍 Phase 2: Hardware & Device Discovery
- [ ] List all NVMe devices with `lsblk -o NAME,SIZE,MODEL,SERIAL`
- [ ] Check device paths in `/dev/disk/by-id/`
- [ ] Verify device health with `smartctl -a` on all drives
- [ ] Compare old vs new device identifiers

### 📊 Phase 3: ZFS Pool Status Analysis
- [ ] Run `zpool status` to see current pool state
- [ ] Check `zpool import -a` for importable pools
- [ ] Examine pool history with `zpool history rpool`
- [ ] Review ZFS logs in `/var/log/` or `dmesg`

### 🛠️ Phase 4: ZFS Recovery Strategy
- [ ] Identify which specific devices are unavailable
- [ ] Determine if pool can be imported with `-f` (force)
- [ ] Plan device replacement strategy (replace vs re-create)
- [ ] Create recovery plan with rollback steps

### 🔧 Phase 5: Recovery Execution
- [ ] Execute device replacement in ZFS pool
- [ ] Re-silver pool to restore redundancy
- [ ] Update bootloader configuration
- [ ] Test pool integrity with `zpool scrub`

### ✅ Phase 6: Validation & Boot Testing
- [ ] Verify pool shows healthy status
- [ ] Test system boot process
- [ ] Confirm Proxmox services start correctly
- [ ] Validate VM/container accessibility

## 🎯 Success Criteria
- ✅ ZFS rpool shows healthy status
- ✅ System boots to Proxmox successfully
- ✅ No data loss confirmed
- ✅ All VMs/containers operational

---
**Status**: 🚨 CRITICAL - Server won't boot
**Started**: 2025-09-25
**Priority**: MAXIMUM