---
name: qemu-agl
description: >
  Manage QEMU/KVM virtual machines on AGL infrastructure. Use when working with QEMU VMs,
  AGLWK45 (VM104 on AGLSRV1), libvirt domains, virtual machine snapshots, clones, or
  QEMU guest agent configuration. Covers VM creation, start/stop, console access,
  disk management, and integration with Proxmox (pct for LXC, qm for QEMU VMs).
---
# QEMU/KVM AGL Virtual Machines

## AGL QEMU VMs

| VMID | Host     | Name     | Role                          | Tailscale IP   |
|------|----------|----------|-------------------------------|----------------|
| 104  | AGLSRV1  | aglwk45  | OpenClaw worker (Windows)     | Via 192.168.0.245 |

## Access

```bash
# AGLSRV1 (Proxmox host with QEMU/KVM)
ssh AGLSRV1  # 192.168.0.245 (LAN) or 100.107.113.33 (Tailscale)
```

## QEMU VM Operations (via qm)

### List all VMs
```bash
ssh AGLSRV1 "qm list"
```

### Start/Stop VM
```bash
# Start
ssh AGLSRV1 "qm start 104"

# Stop (ACPI shutdown)
ssh AGLSRV1 "qm shutdown 104"

# Force stop
ssh AGLSRV1 "qm stop 104"

# Reboot
ssh AGLSRV1 "qm reboot 104"
```

### VM Status
```bash
ssh AGLSRV1 "qm status 104"
ssh AGLSRV1 "qm list | grep 104"
```

### Console Access
```bash
# VNC console (get VNC port)
ssh AGLSRV1 "qm vncproxy 104"

# Serial console (if configured)
ssh AGLSRV1 "qm terminal 104"
```

### Snapshots
```bash
# Create snapshot
ssh AGLSRV1 "qm snapshot 104 pre-update"

# List snapshots
ssh AGLSRV1 "qm listsnapshot 104"

# Rollback (VM must be stopped)
ssh AGLSRV1 "qm stop 104 && qm rollback 104 pre-update && qm start 104"

# Delete snapshot
ssh AGLSRV1 "qm delsnapshot 104 pre-update"
```

### Clone VM
```bash
# Full clone
ssh AGLSRV1 "qm clone 104 <new-vmid> --name <new-name> --full"

# Linked clone (faster, depends on source)
ssh AGLSRV1 "qm clone 104 <new-vmid> --name <new-name>"
```

### Resource Configuration
```bash
# Set memory
ssh AGLSRV1 "qm set 104 --memory 8192"

# Set CPU cores
ssh AGLSRV1 "qm set 104 --cores 4"

# Set network bridge
ssh AGLSRV1 "qm set 104 --net0 virtio,bridge=vmbr0"
```

## QEMU Guest Agent

### Install (inside VM)
```bash
# Windows
# Install qemu-ga from VirtIO drivers ISO

# Linux
apt install qemu-guest-agent  # Debian/Ubuntu
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent
```

### Enable in Proxmox
```bash
ssh AGLSRV1 "qm set 104 --agent enabled=1"
```

### Use guest agent
```bash
# Get VM info via guest agent
ssh AGLSRV1 "qm guest exec 104 -- ip a"

# Get network interfaces
ssh AGLSRV1 "qm guest exec 104 -- ip -j addr show" | jq

# Run command inside VM
ssh AGLSRV1 "qm guest exec 104 -- systemctl status openclaw-gateway"

# Freeze filesystem (for snapshots)
ssh AGLSRV1 "qm guest cmd 104 fsfreeze-freeze"
ssh AGLSRV1 "qm guest cmd 104 fsfreeze-thaw"
```

## Disk Management

### List disks
```bash
ssh AGLSRV1 "qm config 104 | grep virtio"
```

### Resize disk
```bash
ssh AGLSRV1 "qm resize 104 virtio0 +10G"
```

### Move disk
```bash
# Move to different storage
ssh AGLSRV1 "qm move-disk 104 virtio0 local-lvm"
```

## AGLWK45 (VM104) Specific

### OpenClaw on AGLWK45
```bash
# Verify OpenClaw status via guest exec
ssh AGLSRV1 "qm guest exec 104 -- powershell -Command 'Get-Service openclaw'"

# Or via Tailscale from inside VM
ssh AGLSRV1 "qm guest exec 104 -- tailscale status"
```

### Verification Script
```bash
# Run the verification script from the repo
./scripts/verify-aglwk45-fgsrv06.sh
```

## QEMU Direct (non-Proxmox)

For standalone QEMU usage:

```bash
# Start QEMU VM
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 4 \
  -drive file=disk.qcow2,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -serial mon:stdio \
  -nographic

# With VNC
qemu-system-x86_64 -enable-kvm -m 4096 -vnc :0 disk.qcow2

# With Tailscale (inside VM)
# Install tailscale in VM for remote access
```

## Troubleshooting

### VM won't start
```bash
# Check if locked
ssh AGLSRV1 "qm status 104"

# Check storage space
ssh AGLSRV1 "pvesm status"

# Check logs
ssh AGLSRV1 "qm start 104 2>&1"
```

### Guest agent not responding
```bash
# Check if enabled
ssh AGLSRV1 "qm config 104 | grep agent"

# Check inside VM
ssh AGLSRV1 "qm guest exec 104 -- systemctl status qemu-guest-agent"
```

### Network issues
```bash
# Check bridge
ssh AGLSRV1 "brctl show"

# Check VM network config
ssh AGLSRV1 "qm guest exec 104 -- ip a"
```

## Notes
- AGLWK45 (VM104) runs OpenClaw gateway — avoid restarting during active sessions
- QEMU VMs use `qm` commands in Proxmox (vs `pct` for LXC containers)
- Guest agent enables file copy, command exec, and fsfreeze from Proxmox host
- Always snapshot before major changes
