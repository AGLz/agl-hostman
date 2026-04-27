# Proxmox GPU Passthrough Configuration Guide

## Research Summary
**Date**: 2025-10-01
**Sources**: Official Proxmox documentation, community forums, 2025 tutorials
**Applicable to**: Proxmox VE 8.x with modern kernels (6.8+)

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [IOMMU Configuration](#iommu-configuration)
3. [Kernel Module Setup](#kernel-module-setup)
4. [GPU Identification and Isolation](#gpu-identification-and-isolation)
5. [VM Configuration](#vm-configuration)
6. [Verification Commands](#verification-commands)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements
- **CPU**: Intel with VT-x/VT-d OR AMD with AMD-V/AMD-Vi (IOMMU support)
- **Motherboard**: IOMMU/VT-d support in chipset
- **GPU**: UEFI-compatible graphics card (NVIDIA, AMD, or Intel)
- **Monitor**: Physical display connection to passed-through GPU (NoVNC/SPICE will NOT work)

### BIOS/UEFI Configuration
Enable the following settings in your motherboard BIOS:

```
✓ Intel VT-d / AMD IOMMU - ENABLED
✓ Virtualization Technology - ENABLED
✗ Secure Boot - DISABLED
✗ CSM/Legacy Boot - DISABLED (use UEFI)
✗ Resizable BAR / Smart Access Memory - DISABLED (can cause issues)
✗ Above 4G Decoding - DISABLED (if experiencing issues)
```

**Important**: Set integrated GPU as primary display adapter if available, NOT the passthrough GPU.

---

## IOMMU Configuration

### Step 1: Edit GRUB Bootloader Configuration

Edit the GRUB configuration file:
```bash
nano /etc/default/grub
```

Modify the `GRUB_CMDLINE_LINUX_DEFAULT` line based on your CPU:

**For Intel CPUs (older kernels < 6.8):**
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**For AMD CPUs:**
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt"
```

**Note**: On modern kernels (6.8+), IOMMU is enabled by default for both Intel and AMD. The `amd_iommu=on` parameter is deprecated and ignored.

**Optional Performance Parameter:**
- `iommu=pt` - Enables IOMMU passthrough mode for better performance (VMs bypass DMA translation)

**Optional ACS Override (use with caution):**
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"
```
⚠️ Only use `pcie_acs_override` if IOMMU groups are not properly isolated. This can have security implications.

### Step 2: Update GRUB
```bash
update-grub
```

### Step 3: Verify Bootloader
Check which bootloader you're using:
```bash
efibootmgr -v
```

If using systemd-boot instead of GRUB, edit:
```bash
nano /etc/kernel/cmdline
```

---

## Kernel Module Setup

### Step 1: Add VFIO Modules

Edit the modules file:
```bash
nano /etc/modules
```

Add the following VFIO modules:
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**Explanation:**
- `vfio` - Virtual Function I/O framework for device passthrough
- `vfio_iommu_type1` - IOMMU driver for VFIO
- `vfio_pci` - PCI device driver for VFIO
- `vfio_virqfd` - Virtual IRQ file descriptor support (older Proxmox versions)

### Step 2: Blacklist GPU Drivers on Host

The Proxmox host must NOT load GPU drivers. Create blacklist configurations:

**For NVIDIA GPUs:**
```bash
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
echo "blacklist nvidia" > /etc/modprobe.d/blacklist-nvidia.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist-nvidia.conf
```

**For AMD GPUs:**
```bash
echo "blacklist amdgpu" > /etc/modprobe.d/blacklist-amdgpu.conf
echo "blacklist radeon" > /etc/modprobe.d/blacklist-radeon.conf
```

**For Intel GPUs:**
```bash
echo "blacklist i915" > /etc/modprobe.d/blacklist-intel.conf
```

### Step 3: Update Initramfs

After modifying modules, rebuild the initial RAM filesystem:
```bash
update-initramfs -u -k all
```

### Step 4: Reboot
```bash
systemctl reboot
```

---

## GPU Identification and Isolation

### Step 1: Check IOMMU Groups

List all PCI devices with IOMMU groups:
```bash
#!/bin/bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

Save this as `/root/check-iommu-groups.sh` and run:
```bash
chmod +x /root/check-iommu-groups.sh
/root/check-iommu-groups.sh
```

**Expected Output:**
```
IOMMU Group 1:
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:2684]
    01:00.1 Audio device [0403]: NVIDIA Corporation ... [10de:22ba]
```

**Important**: The GPU and its audio device can share the same IOMMU group. This is acceptable.

### Step 2: Identify GPU PCI IDs

List GPUs with vendor/device IDs:
```bash
lspci -nn | grep -E "VGA|3D|Audio"
```

**Example Output:**
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [10de:2684]
01:00.1 Audio device [0403]: NVIDIA Corporation GA102 Audio [10de:22ba]
```

Note the vendor:device IDs (e.g., `10de:2684` and `10de:22ba`).

### Step 3: Bind GPU to VFIO Driver

Create VFIO PCI configuration:
```bash
nano /etc/modprobe.d/vfio.conf
```

Add your GPU's PCI IDs (replace with your actual IDs):
```bash
options vfio-pci ids=10de:2684,10de:22ba disable_vga=1
```

**Parameters Explained:**
- `ids=` - Comma-separated list of PCI IDs to bind to VFIO
- `disable_vga=1` - Disables VGA arbitration (prevents host from using GPU)

**Optional**: Ensure VFIO loads before GPU drivers:
```bash
echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

### Step 4: Update Initramfs and Reboot
```bash
update-initramfs -u -k all
reboot
```

---

## VM Configuration

### Step 1: Create VM with Correct Settings

**Via Proxmox Web UI:**

1. **General**:
   - Name: Your choice
   - Resource Pool: Optional

2. **OS**:
   - ISO: Your OS installation media
   - Type: Linux or Microsoft Windows
   - ✓ QEMU Guest Agent

3. **System**:
   - **BIOS**: OVMF (UEFI) - **REQUIRED for GPU passthrough**
   - **Machine**: q35
   - **Add EFI Disk**: Yes
   - **EFI Storage**: local-lvm
   - ✓ Pre-Enroll keys: NO (disable Secure Boot)

4. **Disks**:
   - Bus/Device: VirtIO SCSI (recommended)
   - Cache: Write back (for better performance)

5. **CPU**:
   - **Type**: host (passes through host CPU features)
   - Cores: Allocate as needed
   - ✓ Enable NUMA

6. **Memory**:
   - Allocate sufficient RAM (8GB+ for gaming/GPU workloads)

7. **Network**:
   - Model: VirtIO (recommended)

### Step 2: Add GPU to VM

**Method 1: Via Web UI**
1. Select VM → Hardware → Add → PCI Device
2. Select your GPU device
3. ✓ All Functions (to include GPU audio)
4. ✓ Primary GPU (x-vga=on)
5. ✓ PCI-Express
6. ✓ ROM-Bar

**Method 2: Via CLI**

Edit VM configuration directly:
```bash
nano /etc/pve/qemu-server/<VMID>.conf
```

Add GPU passthrough line (adjust PCI address to your GPU):
```bash
hostpci0: 01:00,pcie=1,x-vga=1
```

**Parameters Explained:**
- `01:00` - PCI address of GPU (found via `lspci`)
- `pcie=1` - Expose device as PCIe (recommended)
- `x-vga=1` - Enable VGA passthrough (for primary GPU)
- `rombar=1` - Enable ROM bar (required for some GPUs)

**For multi-function devices (GPU + Audio):**
```bash
hostpci0: 01:00,pcie=1,x-vga=1,rombar=1
```

### Step 3: Additional VM Configuration

Add to VM config for better compatibility:
```bash
args: -cpu host,kvm=off,hv_vendor_id=proxmox
machine: q35
bios: ovmf
cpu: host,hidden=1,flags=+pcid
```

**For NVIDIA GPUs** (prevents Error Code 43):
```bash
args: -cpu host,kvm=off,hv_vendor_id=randomstring
```

### Step 4: Configure VM Display

**Important**: After GPU passthrough, NoVNC/SPICE console will show blank screen.

Options:
1. **Physical monitor** connected to passed-through GPU
2. **Remote desktop** software inside guest (Parsec, Sunshine, RDP)
3. **Keep second display device** for emergency console access:
   ```bash
   vga: qxl
   ```

---

## Verification Commands

### Verify IOMMU is Enabled
```bash
dmesg | grep -e DMAR -e IOMMU
```

**Expected output (Intel):**
```
DMAR: IOMMU enabled
```

**Expected output (AMD):**
```
AMD-Vi: AMD IOMMUv2 loaded and initialized
```

### Verify Interrupt Remapping
```bash
dmesg | grep 'remapping'
```

**Expected output:**
```
AMD-Vi: Interrupt remapping enabled
```
OR
```
DMAR-IR: Enabled IRQ remapping in x2apic mode
```

### Verify VFIO Modules Loaded
```bash
lsmod | grep vfio
```

**Expected output:**
```
vfio_pci               16384  1
vfio_pci_core          86016  1 vfio_pci
vfio_iommu_type1       49152  0
vfio                   65536  3 vfio_pci_core,vfio_iommu_type1,vfio_pci
```

### Verify GPU Bound to VFIO
```bash
lspci -nnk -d 10de:
```

**Expected output:**
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:2684]
    Kernel driver in use: vfio-pci
    Kernel modules: nouveau, nvidia
```

**Critical**: Must show `Kernel driver in use: vfio-pci`

### Check PCI Device Assignment
```bash
pvesh get /nodes/<nodename>/hardware/pci --pci-class-blacklist ""
```

### Verify VM Configuration
```bash
cat /etc/pve/qemu-server/<VMID>.conf | grep -E "hostpci|bios|machine|cpu|args"
```

### Check IOMMU Groups (Detailed Script)
```bash
#!/bin/bash
# Save as /root/check-iommu-groups.sh

shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

---

## Troubleshooting

### Issue 1: IOMMU Not Enabled

**Symptoms:**
```bash
dmesg | grep IOMMU
# No output
```

**Solutions:**
1. Enable VT-d/IOMMU in BIOS
2. Verify kernel parameters in `/etc/default/grub`
3. Run `update-grub` and reboot
4. Check CPU supports IOMMU: `cat /proc/cpuinfo | grep -E "vmx|svm"`

### Issue 2: GPU Not Bound to VFIO

**Symptoms:**
```bash
lspci -nnk -d 10de:
Kernel driver in use: nouveau  # Wrong - should be vfio-pci
```

**Solutions:**
1. Verify GPU IDs in `/etc/modprobe.d/vfio.conf`
2. Check blacklist files exist in `/etc/modprobe.d/`
3. Rebuild initramfs: `update-initramfs -u -k all`
4. Reboot
5. Check driver loading order:
   ```bash
   dmesg | grep -i vfio
   dmesg | grep -i nouveau
   ```

### Issue 3: Windows Error Code 43 (NVIDIA)

**Symptoms:**
- GPU detected in Device Manager
- Yellow exclamation mark with "Code 43"
- Driver fails to load

**Solutions:**

1. Add KVM hiding to VM config:
   ```bash
   args: -cpu host,kvm=off,hv_vendor_id=randomid
   cpu: host,hidden=1
   ```

2. Use UEFI BIOS (OVMF):
   ```bash
   bios: ovmf
   ```

3. Set machine type to q35:
   ```bash
   machine: q35
   ```

4. Ensure PCIe mode enabled:
   ```bash
   hostpci0: 01:00,pcie=1,x-vga=1
   ```

5. For some GPUs, disable x-vga:
   ```bash
   hostpci0: 01:00,pcie=1
   ```

6. Update GPU firmware/vBIOS if needed

### Issue 4: No Display Output After Driver Installation

**Symptoms:**
- Display works during OS installation
- Screen goes black after GPU driver installation
- VM still running

**Solutions:**

1. **Check physical monitor connection** - ensure correct input selected
2. **Verify GPU is set as primary in VM**:
   ```bash
   hostpci0: 01:00,x-vga=1,pcie=1
   ```

3. **Disable integrated graphics in guest OS**
4. **For Windows VMs**, install VirtIO guest drivers first
5. **Check VM display settings**:
   ```bash
   # Remove or set to none
   vga: none
   ```

6. **Install fresh GPU drivers** inside VM (not from Windows Update)

### Issue 5: Poor Performance / Stuttering

**Symptoms:**
- Low FPS in games
- Stuttering graphics
- High latency

**Solutions:**

1. **Enable IOMMU passthrough mode**:
   ```bash
   # In /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
   ```

2. **Set CPU type to host**:
   ```bash
   cpu: host
   ```

3. **Enable CPU pinning** for better performance:
   ```bash
   # In VM config
   cpu: host
   affinity: 0,1,2,3  # Pin to specific cores
   ```

4. **Use VirtIO SCSI for disks**:
   ```bash
   scsi0: local-lvm:vm-100-disk-0,cache=writeback,discard=on,iothread=1,size=100G
   ```

5. **Enable hugepages** on host:
   ```bash
   echo "vm.nr_hugepages = 4096" >> /etc/sysctl.conf
   sysctl -p
   ```

6. **Disable Resizable BAR in BIOS** (known to cause issues)

### Issue 6: VM Won't Start with GPU Attached

**Symptoms:**
```
kvm: -device vfio-pci: vfio error: failed getting region info for device
```

**Solutions:**

1. **Verify IOMMU groups are isolated**:
   ```bash
   /root/check-iommu-groups.sh
   ```

2. **Check GPU is bound to VFIO**:
   ```bash
   lspci -nnk | grep -A 3 VGA
   ```

3. **Ensure no other process using GPU**:
   ```bash
   lsof | grep vfio
   ```

4. **Verify VM config syntax**:
   ```bash
   cat /etc/pve/qemu-server/<VMID>.conf
   ```

5. **Check Proxmox logs**:
   ```bash
   journalctl -xe | grep kvm
   tail -f /var/log/syslog
   ```

### Issue 7: Proxmox 8.2+ Passthrough Regression

**Symptoms:**
- GPU passthrough worked on Proxmox 8.0/8.1
- Stopped working after updating to 8.2+

**Solutions:**

1. **Check kernel version**:
   ```bash
   uname -r
   ```

2. **Try alternate kernel**:
   ```bash
   # In Proxmox boot menu, select older kernel
   ```

3. **Verify IOMMU still enabled** after update:
   ```bash
   dmesg | grep IOMMU
   ```

4. **Rebuild initramfs**:
   ```bash
   update-initramfs -u -k all
   ```

5. **Check if VFIO modules changed**:
   ```bash
   lsmod | grep vfio
   ```

### Issue 8: AMD GPU Reset Bug

**Symptoms:**
- VM works first time
- Subsequent VM starts fail
- "Device or resource busy" errors

**Solutions:**

1. **Install vendor-reset kernel module**:
   ```bash
   apt install pve-headers-$(uname -r)
   git clone https://github.com/gnif/vendor-reset.git
   cd vendor-reset
   make
   make install
   echo "vendor-reset" >> /etc/modules
   update-initramfs -u -k all
   reboot
   ```

2. **Alternative**: Use VFIO soft-reset:
   ```bash
   echo "options vfio-pci disable_vga=1 disable_idle_d3=1" > /etc/modprobe.d/vfio.conf
   ```

### Issue 9: IOMMU Groups Not Isolated

**Symptoms:**
```bash
/root/check-iommu-groups.sh
# Shows GPU in same group with many other devices
```

**Solutions:**

1. **Enable ACS override** (use with caution):
   ```bash
   # In /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"
   update-grub
   reboot
   ```

2. **Move GPU to different PCIe slot** (check motherboard manual for IOMMU grouping)

3. **Pass entire IOMMU group** to VM (include all devices in group)

### Issue 10: Cannot Access Proxmox Console After GPU Passthrough

**Symptoms:**
- Proxmox host uses GPU for console
- After blacklisting drivers, no host console access

**Solutions:**

1. **Set integrated GPU as primary in BIOS**

2. **Keep secondary display device in VM**:
   ```bash
   # In VM config
   vga: qxl
   hostpci0: 01:00,pcie=1
   ```

3. **Access via SSH**:
   ```bash
   ssh root@proxmox-ip
   ```

4. **Use serial console**:
   ```bash
   # Add to /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet console=tty0 console=ttyS0,115200n8"
   ```

---

## Configuration Files Summary

### `/etc/default/grub`
```bash
# Intel CPUs (older kernels)
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# AMD CPUs
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt"

# With ACS override (if needed)
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"
```

### `/etc/modules`
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

### `/etc/modprobe.d/blacklist-nvidia.conf`
```bash
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
```

### `/etc/modprobe.d/blacklist-amd.conf`
```bash
blacklist amdgpu
blacklist radeon
```

### `/etc/modprobe.d/vfio.conf`
```bash
options vfio-pci ids=10de:2684,10de:22ba disable_vga=1
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
softdep amdgpu pre: vfio-pci
softdep radeon pre: vfio-pci
```

### `/etc/pve/qemu-server/<VMID>.conf` (Example)
```bash
args: -cpu host,kvm=off,hv_vendor_id=proxmox
bios: ovmf
boot: order=scsi0;ide2;net0
cores: 8
cpu: host,hidden=1,flags=+pcid
hostpci0: 01:00,pcie=1,x-vga=1,rombar=1
machine: q35
memory: 16384
name: gaming-vm
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0
numa: 1
ostype: win11
scsi0: local-lvm:vm-100-disk-0,cache=writeback,discard=on,iothread=1,size=100G
scsihw: virtio-scsi-pci
sockets: 1
vga: none
```

---

## Complete Implementation Checklist

- [ ] **BIOS Configuration**
  - [ ] Enable VT-d/IOMMU
  - [ ] Enable Virtualization
  - [ ] Disable Secure Boot
  - [ ] Disable CSM/Legacy Boot
  - [ ] Set integrated GPU as primary (if available)
  - [ ] Disable Resizable BAR

- [ ] **Proxmox Host Configuration**
  - [ ] Edit `/etc/default/grub` with IOMMU parameters
  - [ ] Run `update-grub`
  - [ ] Add VFIO modules to `/etc/modules`
  - [ ] Create GPU driver blacklist files
  - [ ] Create `/etc/modprobe.d/vfio.conf` with GPU IDs
  - [ ] Run `update-initramfs -u -k all`
  - [ ] Reboot system

- [ ] **Verification**
  - [ ] Verify IOMMU enabled: `dmesg | grep IOMMU`
  - [ ] Verify VFIO loaded: `lsmod | grep vfio`
  - [ ] Check GPU bound to VFIO: `lspci -nnk`
  - [ ] Review IOMMU groups: `/root/check-iommu-groups.sh`

- [ ] **VM Configuration**
  - [ ] Create VM with UEFI (OVMF) BIOS
  - [ ] Set machine type to q35
  - [ ] Set CPU type to host
  - [ ] Add GPU via hostpci with pcie=1,x-vga=1
  - [ ] Configure VM args for KVM hiding (NVIDIA)
  - [ ] Install OS
  - [ ] Install GPU drivers in guest

- [ ] **Testing**
  - [ ] VM boots successfully
  - [ ] GPU detected in guest OS
  - [ ] GPU drivers install without Code 43
  - [ ] Physical display shows output
  - [ ] GPU performance acceptable

---

## Quick Reference Commands

### Essential Commands
```bash
# Check IOMMU status
dmesg | grep -e DMAR -e IOMMU

# List VFIO modules
lsmod | grep vfio

# Find GPU PCI IDs
lspci -nn | grep -E "VGA|3D|Audio"

# Check GPU driver binding
lspci -nnk -d 10de:  # NVIDIA
lspci -nnk -d 1002:  # AMD

# Update GRUB
update-grub

# Rebuild initramfs
update-initramfs -u -k all

# Check VM config
cat /etc/pve/qemu-server/<VMID>.conf

# View Proxmox logs
journalctl -xe
tail -f /var/log/syslog
```

### IOMMU Group Check Script
```bash
#!/bin/bash
# /root/check-iommu-groups.sh

shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

---

## Additional Resources

### Official Documentation
- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Proxmox PCI(e) Passthrough](https://pve.proxmox.com/wiki/PCI(e)_Passthrough)

### Community Resources
- Proxmox Forum GPU Passthrough Section
- r/Proxmox Reddit Community
- Level1Techs GPU Passthrough Guides

### GPU-Specific Notes

**NVIDIA GPUs:**
- Consumer cards (GeForce) may require hiding KVM hypervisor
- Use open-source drivers for RTX 40-series (570+)
- Some laptops have GPU lockdowns preventing passthrough

**AMD GPUs:**
- Generally better passthrough support
- Watch for reset bug (requires vendor-reset module)
- RDNA2/RDNA3 have good compatibility

**Intel GPUs:**
- Arc GPUs support passthrough
- Integrated graphics can be passed through
- GVT-g allows GPU sharing (SR-IOV)

---

## Research Notes

### Sources Analyzed
- Official Proxmox VE 8.x documentation (primary source)
- Proxmox community forum tutorials (2025 updates)
- GitHub community guides and scripts
- Medium technical articles on GPU passthrough

### Key Findings
1. Modern kernels (6.8+) enable IOMMU by default on both Intel and AMD
2. The `amd_iommu=on` parameter is deprecated and ignored
3. NVIDIA requires KVM hiding to prevent Error Code 43
4. UEFI (OVMF) BIOS is mandatory for GPU passthrough
5. Resizable BAR can cause compatibility issues and should be disabled
6. Physical monitor connection is required (NoVNC/SPICE won't work)
7. Proxmox 8.2+ may have regressions requiring kernel downgrades

### Common Pitfalls
- Not enabling VT-d/IOMMU in BIOS (most common issue)
- Using BIOS instead of UEFI for VM
- Forgetting to update initramfs after configuration changes
- Not blacklisting GPU drivers on host
- Improper PCI ID configuration in vfio.conf
- IOMMU groups not properly isolated
- Using GPU as host primary display

---

**Document Version**: 1.0
**Last Updated**: 2025-10-01
**Tested On**: Proxmox VE 8.x with kernels 6.2+
