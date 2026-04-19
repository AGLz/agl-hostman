# Proxmox Kernel Downgrade Issue Report

## Current Situation
- **Time**: 2025-09-26 13:18
- **Issue**: Server not accessible after reboot with kernel 6.2.16-5-pve
- **Last Known State**: Kernel 6.14.8-2-pve was running
- **Action Taken**: Configured boot to use kernel 6.2.16-5-pve and rebooted

## Troubleshooting Steps Attempted
1. Installed kernel 6.2.16-5-pve successfully
2. Pinned kernel using: `proxmox-boot-tool kernel pin 6.2.16-5-pve`
3. Refreshed boot configuration: `proxmox-boot-tool refresh`
4. Initiated reboot at approximately 13:13
5. Server has been offline for 5+ minutes

## Possible Issues
1. Kernel 6.2.16-5-pve may be incompatible with server hardware
2. Boot process may be stuck waiting for console input
3. Network configuration may have changed after reboot
4. Kernel may be too old for current Proxmox configuration

## Recovery Options

### Option 1: Physical/Console Access
- Access server via physical console or IPMI/iDRAC
- Select kernel 6.14.8-2-pve from boot menu
- Remove kernel pin: `proxmox-boot-tool kernel unpin`

### Option 2: Alternative Kernel Version
If server comes back online, try a different kernel:
```bash
# Check available kernels
apt-cache search pve-kernel | grep "6\.[58]"

# Try kernel 6.5 or 6.8 series instead
apt-get install pve-kernel-6.5.13-6-pve
proxmox-boot-tool kernel pin 6.5.13-6-pve
proxmox-boot-tool refresh
```

### Option 3: NVIDIA Driver Alternative
Instead of downgrading kernel, try:
1. Keep kernel 6.14.8-2-pve
2. Build NVIDIA driver from source
3. Or use nouveau driver temporarily
4. Or wait for NVIDIA driver update

## Files Created Before Issue
- `/root/prepare-nvidia.sh` - Script to install NVIDIA drivers after reboot
- `/root/proxmox-optimization/` - Complete optimization suite
- Container 200 configured for Ollama

## Next Steps
1. Wait for potential delayed boot (up to 10 minutes)
2. Try alternate IP addresses if DHCP changed
3. Request physical/console access if needed
4. Consider alternative approaches to GPU passthrough