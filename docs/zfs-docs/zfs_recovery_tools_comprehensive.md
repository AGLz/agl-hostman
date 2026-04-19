# Comprehensive ZFS Recovery Tools and Techniques Guide

## Table of Contents
1. [Professional/Commercial Recovery Tools](#professional-commercial-recovery-tools)
2. [Open-Source Advanced Recovery Tools](#open-source-advanced-recovery-tools)
3. [Low-Level Recovery Techniques](#low-level-recovery-techniques)
4. [Emergency Recovery Procedures](#emergency-recovery-procedures)
5. [Advanced ZDB Recovery Commands](#advanced-zdb-recovery-commands)
6. [Recovery Best Practices](#recovery-best-practices)

---

## Professional/Commercial Recovery Tools

### 1. UFS Explorer Professional Recovery
**Status**: ✅ Available for Linux (Windows, Mac 10.15 & Linux)
**Price**: Commercial license required
**Website**: https://www.ufsexplorer.com/ufs-explorer-professional-recovery/

**Capabilities**:
- Native ZFS support including BSD/Solaris ZFS and Sun ZFS
- ZFS RAID-Z configuration reconstruction
- Automatic metadata interpretation
- Support for complex RAID configurations (Drobo BeyondRAID, Synology Hybrid RAID, Btrfs-RAID)
- Immediate access to damaged/deleted ZFS pools
- File preview capabilities

**Download**: Available from UFS Explorer website
**Usage**: GUI-based tool with comprehensive ZFS recovery wizards

### 2. Klennet ZFS Recovery
**Status**: ✅ Available (Windows-based, drives must be attached to Windows system)
**Price**: Commercial license required
**Website**: https://www.klennet.com/zfs-recovery/

**Capabilities**:
- Fully automatic pool layout detection
- Automatic RAID level and disk order detection
- Recovery from damaged or deleted ZFS pools
- Rebranded and updated version of Zero Assumption Recovery (ZAR)

**Limitations**:
- No BitLocker encryption support
- No NAS RAID support
- No shadow copy support
- Windows-only (Linux drives must be attached to Windows system)

### 3. R-Studio for Linux
**Status**: ⚠️ Limited ZFS support information available
**Price**: Commercial license required
**Website**: https://www.r-explorer.com/

**Note**: While R-Studio was mentioned in research queries, specific ZFS recovery capabilities for 2025 were not clearly documented in available sources.

### 4. Hetman RAID Recovery
**Status**: ✅ Available
**Price**: Commercial license required

**Capabilities**:
- Successfully recovered all data in testing scenarios
- Preserved disk structure during recovery
- Windows-based recovery tool

### 5. Recovery Explorer Professional
**Status**: ✅ Available
**Price**: Commercial license required
**Website**: https://www.r-explorer.com/recovery-explorer-professional/

**Capabilities**:
- Professional data recovery features
- Multiple file system support including ZFS
- Advanced RAID reconstruction capabilities

---

## Open-Source Advanced Recovery Tools

### 1. Sanoid/Syncoid
**Repository**: https://github.com/jimsalterjrs/sanoid
**Platform**: Linux, FreeBSD
**License**: GPL

**Sanoid Features**:
- Policy-driven snapshot management
- Automatic snapshot creation and pruning
- Configuration via `/usr/local/etc/sanoid.conf`
- Template-based configuration for multiple datasets
- Customizable retention policies (hourly, daily, monthly snapshots)

**Syncoid Features**:
- Asynchronous incremental replication
- Recursive replication support
- Resumable send/receive streams
- mbuffer buffering, lzop compression, pv progress bars
- ZFS bookmark creation for recovery points

**Installation & Usage**:
```bash
# Installation (example for Ubuntu/Debian)
git clone https://github.com/jimsalterjrs/sanoid.git
cd sanoid
sudo make install

# Configuration
sudo vim /usr/local/etc/sanoid.conf

# Recovery usage
syncoid source/dataset target/dataset
```

### 2. Znapzend
**Website**: https://www.znapzend.org/
**Platform**: Cross-platform
**License**: Open source

**Features**:
- Built-in ZFS snapshot functionality
- Configuration stored in ZFS properties
- Continuous service operation
- Built-in scheduling (no cron required)
- mbuffer and SSH support for remote replication

**Installation**:
```bash
# Install from package manager or compile from source
# Configuration stored in ZFS properties
```

### 3. Zrepl
**Platform**: Cross-platform
**License**: Open source

**Features**:
- Configuration file-based setup
- Pre/post-script hooks
- Continuous service with built-in scheduling
- Bandwidth limiting for network operations
- Most powerful of the snapshot/replication tools
- Version control friendly configuration

**Usage**: Requires configuration file setup with comprehensive policy definitions

### 4. zfs-auto-snapshot
**Platform**: Linux, Solaris, FreeBSD
**License**: Open source

**Features**:
- Automatic snapshot creation
- Cron-based scheduling
- Configurable retention policies
- Integration with system package managers

### 5. Pyznap
**Platform**: Cross-platform Python
**License**: Open source

**Features**:
- Single cron invocation
- Configuration file-based dataset policies
- Snapshot frequency and retention control
- Python-based implementation

### 6. Labelfix Utility
**Repository**: https://gist.github.com/jjwhitney/baaa63144da89726e482
**Platform**: Linux/Unix
**License**: Unofficial utility
**Original Author**: Jeff Bonwick (ZFS inventor)

**Features**:
- Repair corrupted ZFS labels
- Make unimportable pools importable
- Rewrite invalid labels on offline/detached drives
- Recovery of intact pools with label issues

**Usage**:
```bash
# Compile and use labelfix utility
git clone https://gist.github.com/jjwhitney/baaa63144da89726e482
cd labelfix
make
./labelfix /dev/device
```

**⚠️ Warning**: Unofficial utility, use with extreme caution

---

## Low-Level Recovery Techniques

### 1. Direct Disk Access Methods

#### Label Analysis and Recovery
ZFS stores 4 labels per device: 2 at the beginning, 2 at the end
```bash
# Examine device labels
zdb -l /dev/device

# Check label validity (returns 0 if valid, 1 if error, 2 if no valid labels)
zdb -l /dev/device; echo $?
```

#### Raw Device Access
```bash
# Direct examination of pool metadata
zdb -e /dev/device

# Export pool metadata to files for analysis
zdb -e -C pool_name > pool_config.txt
```

### 2. Manual Metadata Reconstruction

#### Pool Configuration Backup
```bash
# Save pool configuration before attempting recovery
zpool status pool_name > pool_config_backup.txt
zpool get all pool_name > pool_properties_backup.txt
zfs get all > dataset_properties_backup.txt
```

#### Vdev Reconstruction Process
1. Identify missing or corrupted vdevs
2. Determine pool topology from available metadata
3. Use zdb to validate metadata consistency
4. Attempt reconstruction with available devices

### 3. Transaction Group (TXG) Analysis

#### Finding Available TXGs
```bash
# List all uberblocks with transaction IDs
zdb -ul /dev/device

# List uberblocks with dates and TXG values for imported pool
zdb -e pool_name -ul

# Get comprehensive TXG information
zdb -hh pool_name
```

#### TXG Validation
```bash
# Test pool integrity at specific TXG
zdb -AAA -L -t <TXG> -bcdmu pool_name

# Less strict checking for damaged pools
zdb -AA -L -t <TXG> pool_name
```

### 4. Uberblock Manipulation

#### Uberblock Selection
```bash
# Manual uberblock selection during import
zpool import -N -o readonly=on -f -R /recovery -F -T <TXG> pool_name

# Force import with extreme transaction rewind
zpool import -F -X pool_name
```

#### Recovery Mode Setup
```bash
# Enable ZFS recovery mode (FreeBSD)
echo 'vfs.zfs.recover=1' >> /boot/loader.conf

# Linux equivalent - adjust kernel parameters
echo "1" > /sys/module/zfs/parameters/zfs_max_missing_tvds
```

---

## Emergency Recovery Procedures

### 1. Recovery from Backup Labels

#### Force Import with Label Recovery
```bash
# Test recovery possibility (dry run)
zpool import -F -n pool_name

# Force import with potential data loss
zpool import -F pool_name

# Force import in read-only mode
zpool import -F -o readonly=on pool_name
```

#### Manual Device Specification
```bash
# Import with specific device paths
zpool import -f -d /dev/sda3 -d /dev/sdb3 -d /dev/sdc3 -o readonly=on pool_name

# Import all devices from directory
zpool import -d /dev/disk/by-id/ pool_name
```

### 2. Pool Import with Missing Devices

#### Adjust Missing Device Tolerance
```bash
# Allow import with missing devices (Linux)
echo "1" | sudo tee /sys/module/zfs/parameters/zfs_max_missing_tvds

# Import degraded pool
zpool import -f -m -o readonly=on pool_name
```

#### Recovery Steps for Missing Devices
1. Identify missing devices: `zpool status pool_name`
2. Adjust system parameters for missing device tolerance
3. Import in read-only mode
4. Copy critical data to safe location
5. Attempt pool reconstruction or device replacement

### 3. Forced Imports and Risks

#### Standard Force Import
```bash
# Basic force import
zpool import -f pool_name

# Force import with recovery attempt
zpool import -F pool_name
```

#### Extreme Recovery Options
```bash
# Extreme transaction rewind (high risk)
zpool import -F -X pool_name

# Recovery with specific TXG
zpool import -F -T <TXG> pool_name
```

**⚠️ Risks of Forced Import**:
- Potential data loss from recent transactions
- Pool corruption if metadata is severely damaged
- Risk of making recovery impossible if import fails
- Split-brain scenarios in multi-host environments

### 4. Emergency Pool Reconstruction

#### Complete Pool Rebuild Process
1. **Assessment Phase**:
   ```bash
   zdb -e /path/to/devices/
   zpool import -d /path/to/devices/
   ```

2. **Configuration Backup**:
   ```bash
   zpool status > emergency_config.txt
   zfs list -r -o all > emergency_datasets.txt
   ```

3. **Reconstruction Attempt**:
   ```bash
   zpool import -F -o readonly=on reconstructed_pool
   ```

4. **Data Recovery**:
   ```bash
   # Mount datasets read-only
   zfs mount -o ro dataset_name

   # Copy critical data
   rsync -av /recovery_mount/ /safe_location/
   ```

---

## Advanced ZDB Recovery Commands

### 1. Pool Analysis Commands

#### Basic Pool Information
```bash
# Display pool configuration and status
zdb pool_name

# Verbose pool analysis
zdb -v pool_name

# Block-level analysis
zdb -bb pool_name
```

#### Dataset and Object Analysis
```bash
# Analyze specific dataset
zdb pool_name/dataset

# Object-level analysis
zdb -ddddd pool_name/dataset

# Metadata dump
zdb -m pool_name
```

### 2. Recovery-Specific ZDB Options

#### Panic Recovery Mode
```bash
# Enable panic recovery (demote fatal errors to warnings)
zdb -AA pool_name

# Maximum panic recovery
zdb -AAA pool_name
```

#### Transaction Analysis
```bash
# Specify highest transaction to search
zdb -t <TXG> pool_name

# Extreme transaction rewind
zdb -X pool_name

# Attempt all reconstruction combinations
zdb -Y pool_name
```

#### Block Reconstruction
```bash
# Attempt indirect split block reconstruction
zdb -Y pool_name

# Disable I/O deadman timer for reconstruction
zdb -Y -G pool_name
```

### 3. Advanced Diagnostic Commands

#### Uberblock and Label Analysis
```bash
# Display all uberblocks
zdb -u pool_name

# Display labels from specific device
zdb -l /dev/device

# Combined uberblock and label analysis
zdb -ul /dev/device
```

#### Error and Corruption Detection
```bash
# Check for corruption
zdb -cc pool_name

# Verbose corruption checking
zdb -ccc pool_name

# Block checksum verification
zdb -b pool_name
```

### 4. Automated Recovery with ZDB

#### Recovery Script Template
```bash
#!/bin/bash
POOL_NAME="$1"
DEVICE_PATH="$2"

echo "Starting ZFS recovery for pool: $POOL_NAME"

# Step 1: Analyze available TXGs
echo "Available TXGs:"
zdb -ul "$DEVICE_PATH"

# Step 2: Test latest TXG
LATEST_TXG=$(zdb -ul "$DEVICE_PATH" | grep "txg" | tail -1 | awk '{print $2}')
echo "Testing TXG: $LATEST_TXG"

if zdb -AAA -L -t "$LATEST_TXG" -bcdmu "$POOL_NAME" &>/dev/null; then
    echo "TXG $LATEST_TXG appears valid"

    # Step 3: Attempt import
    echo "Attempting pool import..."
    zpool import -N -o readonly=on -f -F -T "$LATEST_TXG" "$POOL_NAME"
else
    echo "TXG $LATEST_TXG failed, trying older TXGs..."
    # Try progressively older TXGs
fi
```

---

## Recovery Best Practices

### 1. Pre-Recovery Preparation

#### Always Create Backups First
```bash
# Create bit-for-bit copies of devices before recovery attempts
dd if=/dev/source_device of=/backup/device_image.dd bs=1M

# Verify backup integrity
sha256sum /dev/source_device > /backup/device_checksum.txt
sha256sum /backup/device_image.dd >> /backup/device_checksum.txt
```

#### Document Current State
```bash
# Capture current pool status
zpool status -v > recovery_initial_status.txt
zpool history > recovery_history.txt
dmesg | grep -i zfs > recovery_dmesg.txt
```

### 2. Recovery Process Guidelines

#### Systematic Approach
1. **Never work on original devices** - Always use copies
2. **Start with least invasive methods** - readonly imports first
3. **Progress gradually** - from -F to -X to manual reconstruction
4. **Document everything** - Keep detailed logs of all attempts
5. **Test each step** - Validate before proceeding to next level

#### Risk Assessment Matrix
- **Low Risk**: Read-only imports, zdb analysis
- **Medium Risk**: Force imports with -F
- **High Risk**: Extreme rewind (-X), manual metadata modification
- **Critical Risk**: Writing to original devices, labelfix on live data

### 3. Success Validation

#### Data Integrity Verification
```bash
# Verify pool integrity after recovery
zpool scrub recovered_pool
zpool status recovered_pool

# Check dataset accessibility
zfs list -r recovered_pool
zfs mount recovered_pool/dataset

# Validate file integrity
find /recovered_mount -type f -exec sha256sum {} \; > recovery_checksums.txt
```

### 4. Post-Recovery Actions

#### Immediate Steps After Successful Recovery
1. **Copy critical data immediately** to separate storage
2. **Create new snapshots** of recovered state
3. **Run comprehensive scrub** to identify any remaining issues
4. **Plan for pool reconstruction** if recovery was partial

#### Long-term Recommendations
- Implement automated snapshot strategies using sanoid/syncoid
- Set up off-site replication using zrepl or znapzend
- Regular testing of recovery procedures
- Maintain updated recovery documentation and procedures

### 5. When to Call Professionals

#### Indicators for Professional Recovery Services
- Multiple device failures in RAID-Z configuration
- Physical device damage or clicking sounds
- Repeated recovery attempts have failed
- Critical business data with high recovery value
- Time constraints requiring guaranteed recovery

#### Recommended Professional Services
- Data recovery specialists with ZFS experience
- Services that work with ZFS metadata reconstruction
- Companies offering clean room facilities for physical recovery

---

## Conclusion

ZFS recovery requires a methodical approach combining multiple tools and techniques. Start with the least invasive methods (read-only imports, zdb analysis) and progress to more aggressive techniques only when necessary. Professional commercial tools like UFS Explorer often succeed where native ZFS tools fail, but open-source tools like sanoid/syncoid provide excellent preventive measures.

Remember: **The best recovery is prevention** - implement comprehensive snapshot and replication strategies before you need them.

---

**⚠️ Critical Warning**: All recovery operations should be performed on copies of original data whenever possible. ZFS recovery can potentially make data unrecoverable if performed incorrectly.

**Last Updated**: Based on 2025 research and current ZFS implementations.