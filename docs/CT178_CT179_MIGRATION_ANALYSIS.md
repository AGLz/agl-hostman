# CT179 → CT178 Mount Points Migration Analysis

**Date**: 2025-10-14
**Task**: Add CT179 mount points and device permissions to CT178

---

## Container Overview

### CT179 (agldv03) - Source
- **Status**: Running
- **Cores**: 16
- **Memory**: 49152 MB (48 GB)
- **Swap**: 8192 MB
- **RootFS**: local-zfs:subvol-179-disk-0 (240G)
- **IP**: 192.168.0.179 / 192.168.1.179 (dual network)
- **Purpose**: Development container with GPU access

### CT178 (aglfs1) - Target
- **Status**: Running
- **Cores**: 4
- **Memory**: 2048 MB (2 GB)
- **Swap**: 2048 MB
- **RootFS**: local-zfs:subvol-178-disk-0 (32G)
- **IP**: 192.168.0.178
- **Purpose**: File server container
- **Current Config**: Privileged mode (`lxc.cgroup2.devices.allow: a`, `lxc.cap.drop:`)

---

## Mount Points to Add

### CT179 Current Mount Points:
```
mp0: /mnt/shares,mp=/mnt/shares
mp1: /overpower/base,mp=/mnt/overpower
mp2: /spark/base,mp=/mnt/power
mp5: /mnt/storage,mp=/mnt/storage
mp6: /mnt/storage/Extracted,mp=/mnt/disks/gd/BB/Extracted
mp7: /mnt/storage/Extracted,mp=/mnt/pve/common/media/Extracted
mp8: /mnt/storage/Extracted_New,mp=/mnt/disks/gd/BB/Extracted_New
mp9: /mnt/storage/Extracted_New,mp=/mnt/pve/common/media/Extracted_New
```

### CT178 Current Mount Points:
```
(None - no mount points currently configured)
```

---

## Device Permissions to Add

### CT179 Current Device Permissions:

#### 1. DRI Devices (for GPU rendering)
```
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir 0 0
```

#### 2. NVIDIA GPU Devices
```
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 236:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file 0 0
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file 0 0
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file 0 0
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file 0 0
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file 0 0
lxc.mount.entry: /usr/local/nvidia/lib64 usr/local/nvidia/lib64 none bind,optional,create=dir,ro 0 0
```

#### 3. VFIO Device
```
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.mount.entry: /dev/vfio/vfio dev/vfio/vfio none bind,optional,create=file 0 0
```

#### 4. TUN Device (for VPN/networking)
```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

---

## Migration Strategy

### ⚠️ Important Considerations

1. **CT178 is Already Privileged**
   - Current config: `lxc.cgroup2.devices.allow: a` (allows all devices)
   - This means device permissions are already open
   - Adding specific device permissions is redundant BUT safer for documentation

2. **Resource Compatibility**
   - CT178 has only 2GB RAM vs CT179's 48GB
   - May need resource adjustment depending on usage
   - CT178 has only 32GB rootfs vs CT179's 240GB

3. **GPU Access Consideration**
   - CT178 is a file server, may not need GPU access
   - GPU devices should only be added if required
   - Question: Does CT178 need GPU/NVIDIA access?

4. **Network Differences**
   - CT179 has dual network (vmbr0 + vmbr1)
   - CT178 has single network (vmbr0)

---

## Recommended Approach

### Option 1: Add Only Mount Points (Recommended for File Server)
**Rationale**: CT178 is a file server, likely doesn't need GPU access

**Changes**:
- ✅ Add all 8 mount points (mp0-mp9)
- ❌ Skip GPU/NVIDIA device bindings
- ✅ Add TUN device (useful for file server with VPN)
- ❌ Skip DRI/VFIO (not needed for file serving)

### Option 2: Full Replication (Development Container Clone)
**Rationale**: If CT178 needs to replicate CT179 functionality exactly

**Changes**:
- ✅ Add all 8 mount points
- ✅ Add all GPU/NVIDIA device bindings
- ✅ Add DRI devices
- ✅ Add VFIO devices
- ✅ Add TUN device
- ⚠️ Consider increasing CT178 resources to match workload

---

## Proposed Configuration Changes (Option 1 - File Server Focus)

### Mount Points to Add:
```bash
pct set 178 -mp0 /mnt/shares,mp=/mnt/shares
pct set 178 -mp1 /overpower/base,mp=/mnt/overpower
pct set 178 -mp2 /spark/base,mp=/mnt/power
pct set 178 -mp5 /mnt/storage,mp=/mnt/storage
pct set 178 -mp6 /mnt/storage/Extracted,mp=/mnt/disks/gd/BB/Extracted
pct set 178 -mp7 /mnt/storage/Extracted,mp=/mnt/pve/common/media/Extracted
pct set 178 -mp8 /mnt/storage/Extracted_New,mp=/mnt/disks/gd/BB/Extracted_New
pct set 178 -mp9 /mnt/storage/Extracted_New,mp=/mnt/pve/common/media/Extracted_New
```

### Additional Configuration (Optional - TUN device):
```bash
# Add to /etc/pve/lxc/178.conf:
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

---

## Backup Strategy

### Before Changes:
```bash
# 1. Backup CT178 configuration
cp /etc/pve/lxc/178.conf /etc/pve/lxc/178.conf.backup-$(date +%Y%m%d-%H%M%S)

# 2. Create snapshot (if space allows)
pct snapshot 178 pre-mount-migration
```

---

## Verification Steps

### After Adding Mount Points:

1. **Verify Configuration**
   ```bash
   pct config 178 | grep "^mp"
   ```

2. **Restart Container**
   ```bash
   pct stop 178
   sleep 5
   pct start 178
   ```

3. **Verify Mounts Inside Container**
   ```bash
   pct exec 178 -- df -h
   pct exec 178 -- ls -la /mnt/shares /mnt/overpower /mnt/power /mnt/storage
   ```

4. **Check for Mount Errors**
   ```bash
   journalctl -u pve-container@178.service --since "5 minutes ago" | grep -i error
   ```

---

## Risk Assessment

### Low Risk:
- ✅ Adding mount points (read-only or existing directories)
- ✅ Container is already privileged
- ✅ Both containers are running (source data available)

### Medium Risk:
- ⚠️ Mount point conflicts (if paths already exist in CT178)
- ⚠️ Permission issues on mounted directories
- ⚠️ Resource contention if multiple containers access same paths

### Mitigation:
- ✅ Backup configuration before changes
- ✅ Test mount accessibility after changes
- ✅ Monitor for errors during restart
- ✅ Have rollback plan ready

---

## Questions to Confirm

Before proceeding, please confirm:

1. **Purpose Alignment**: Should CT178 remain a file server, or become a dev container like CT179?

2. **GPU Access**: Does CT178 need GPU/NVIDIA access?
   - ❌ No → Use Option 1 (mount points only)
   - ✅ Yes → Use Option 2 (full replication)

3. **Resource Adjustment**: Should CT178 resources be increased?
   - Current: 4 cores, 2GB RAM, 32GB disk
   - CT179 level: 16 cores, 48GB RAM, 240GB disk

4. **Network Requirements**: Does CT178 need dual network like CT179?
   - Current: Single network (192.168.0.178)
   - CT179: Dual network (192.168.0.179 + 192.168.1.179)

---

## Execution Plan (Awaiting Confirmation)

**Recommended: Option 1 - File Server with Mount Points**

1. ✅ Backup CT178 configuration
2. ✅ Stop CT178
3. ✅ Add 8 mount points (mp0-mp9)
4. ✅ Add TUN device (optional, for VPN)
5. ✅ Start CT178
6. ✅ Verify all mounts accessible
7. ✅ Test file server functionality
8. ✅ Document changes

**Estimated Time**: 10-15 minutes
**Downtime**: 5-10 minutes (during restart)

---

*Analysis prepared - awaiting user confirmation on approach*
