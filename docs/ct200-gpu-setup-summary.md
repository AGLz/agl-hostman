# CT200 (ollama) - GPU Setup Summary

**Date**: 2025-10-27
**Host**: AGLSRV1 (192.168.0.245)
**Container**: CT200 - ollama (192.168.0.200)
**GPU**: NVIDIA GeForce GTX 1650 (4GB VRAM)
**Status**: ✅ Fully Operational

---

## Configuration Journey

### Initial Problem
- CT200 was stopped with broken VFIO GPU passthrough configuration
- GPU devices (`/dev/nvidia*`) did not exist in container
- VFIO modules were loaded but GPU was not accessible

### Solution Approach
**Option B Selected**: NVIDIA Container Runtime in LXC (not VM conversion)

---

## Host Configuration (AGLSRV1)

### 1. NVIDIA Driver Installation
- **Driver Version**: 550.127.05
- **Installation Method**: Official NVIDIA runfile installer
- **Download**: `NVIDIA-Linux-x86_64-550.127.05.run`
- **Installation Command**: `sh NVIDIA-Linux-x86_64-550.127.05.run --no-questions --ui=none`

### 2. Disabled VFIO Passthrough
```bash
# Renamed/disabled files:
/etc/modprobe.d/vfio.conf → vfio.conf.disabled
/etc/modprobe.d/blacklist-nvidia.conf → blacklist-nvidia.conf.disabled
/etc/modules-load.d/vfio.conf → vfio.conf.disabled

# Removed blacklist from:
/etc/modprobe.d/pve-blacklist.conf (removed "blacklist nvidia" line)
```

### 3. Kernel Parameters (PCI BAR Fix)
**Issue**: 64-bit BAR mapped above 4GB - Linux kernel bug
**Fix**: Added `pci=realloc` to kernel cmdline

**File**: `/etc/kernel/cmdline`
```
root=ZFS=rpool/ROOT/pve-1 boot=zfs mitigations=auto pci=noaer pcie_aspm=force pci=realloc
```

**Applied with**:
```bash
proxmox-boot-tool refresh
update-initramfs -u -k all
reboot
```

### 4. Host Verification
```bash
nvidia-smi
# Shows: NVIDIA-SMI 550.127.05, Driver Version: 550.127.05, CUDA Version: 12.4
```

---

## Container Configuration (CT200)

### 1. LXC Configuration
**File**: `/etc/pve/lxc/200.conf`

```ini
#Ollama AI container with GPU passthrough via NVIDIA Container Runtime
arch: amd64
cores: 8
features: nesting=1,keyctl=1
hostname: ollama
memory: 16384
nameserver: 192.168.0.102
net0: name=eth0,bridge=vmbr0,gw=192.168.0.1,hwaddr=BC:24:11:BA:72:22,ip=192.168.0.200/24,type=veth
onboot: 1
ostype: ubuntu
rootfs: local-zfs:subvol-200-disk-0,size=32G
searchdomain: localdomain
swap: 0

# Device permissions
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 10:200 rwm

# NVIDIA device bind mounts
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/nvidia-caps dev/nvidia-caps none bind,optional,create=dir
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### 2. Resolved Issues

#### Issue 1: resolv.conf Immutable
**Error**: "close (rename) atomic file '/etc/resolv.conf' failed: Operation not permitted"
**Fix**:
```bash
chattr -i /var/lib/lxc/200/rootfs/etc/resolv.conf
rm /var/lib/lxc/200/rootfs/etc/resolv.conf
```

#### Issue 2: NVIDIA Version Mismatch
**Problem**: Container had nvidia-utils 550.163.01, host driver was 550.127.05
**Error**: "Driver/library version mismatch"
**Fix**: Downgraded to matching version
```bash
apt-get install -y --allow-downgrades \
  nvidia-utils-550=550.127.05-0ubuntu1 \
  libnvidia-compute-550:amd64=550.127.05-0ubuntu1
```

#### Issue 3: Old NVIDIA Package Remnants
**Fix**: Purged old packages
```bash
dpkg --purge libnvidia-compute-535 libnvidia-compute-580 nvidia-dkms-580 \
  nvidia-kernel-common-580 nvidia-persistenced nvidia-settings
ldconfig
```

#### Issue 4 (2026-04-19): Ollama só CPU — `total_vram=0 B` apesar de `nvidia-smi` OK
**Causa**: faltava `lxc.cgroup2.devices.allow: c 509:* rwm` no `/etc/pve/lxc/200.conf` em produção. O major **509** é o dispositivo **`/dev/nvidia-uvm`**; sem permissão no cgroup v2 o bind mount existe mas o runtime CUDA não inicializa → descoberta de GPU devolve lista vazia (`initial_count=0`) e o Ollama cai para CPU.

**Correção**:
```ini
lxc.cgroup2.devices.allow: c 509:* rwm
```
Reiniciar o CT (`pct reboot 200`). Opcional no serviço Ollama: `OLLAMA_LLM_LIBRARY=cuda_v12` quando coexistem `cuda_v12` e `cuda_v13` no bundle.

**Verificação**: `journalctl -u ollama` deve mostrar `library=CUDA` e `total_vram="4.0 GiB"`; `ollama ps` com modelo carregado → `100% GPU`.

### 3. Container Verification
```bash
# Inside CT200
nvidia-smi
# Output: NVIDIA-SMI 550.127.05, GeForce GTX 1650, 4096 MiB

ls -la /dev/nvidia*
# All devices present with correct permissions (crw-rw-rw-)
```

---

## Ollama Configuration

### 1. Service Status
- **Version**: 0.12.2
- **Status**: Active (running)
- **Port**: 11434
- **Service File**: `/etc/systemd/system/ollama.service`

### 2. GPU Detection
```
inference compute:
  id: GPU-3e24bb75-e10e-4faf-039d-87ad16731997
  library: cuda
  variant: v12
  compute: 7.5
  driver: 12.4
  name: "NVIDIA GeForce GTX 1650"
  total: "3.8 GiB"
  available: "3.8 GiB"
```

### 3. Models Installed
- **llama3.2:1b** (1.3 GB, Q8_0 quantization)

### 4. Inference Test
```bash
ollama run llama3.2:1b "Say hello in one word"
# Response: "Hi."
# GPU Memory Usage: 1737 MiB
```

---

## Performance Notes

- ⚠️ **GPU Temperature**: Running at 80°C (fan at 88% - acceptable for GTX 1650)
- ℹ️ **Low VRAM Mode**: Activated automatically (threshold 20GB, available 3.8GB)
- ⚠️ **CUDA Driver Warning**: "old CUDA driver" message is informational, does not affect functionality

---

## Maintenance Commands

### Host (AGLSRV1)
```bash
# Check NVIDIA driver
nvidia-smi

# Check container status
pct list | grep 200
pct status 200

# Start container
pct start 200

# Enter container console
pct enter 200
```

### Container (CT200)
```bash
# Check GPU access
nvidia-smi

# Check Ollama status
systemctl status ollama

# List models
ollama list

# Test inference
ollama run llama3.2:1b "test prompt"

# Check logs
journalctl -u ollama -f
```

---

## Troubleshooting

### GPU Not Detected
1. Verify host driver: `nvidia-smi` on host
2. Check device mounts: `ls -la /dev/nvidia*` in container
3. Verify permissions in `/etc/pve/lxc/200.conf`
4. Restart container: `pct stop 200 && pct start 200`

### Version Mismatch
1. Check versions:
   - Host: `nvidia-smi` (driver version)
   - Container: `dpkg -l | grep nvidia-utils`
2. If mismatch, downgrade container packages to match host

### Ollama Not Using GPU
1. Check Ollama logs: `journalctl -u ollama -n 50`
2. Look for "looking for compatible GPUs"
3. Verify library cache: `ldconfig` in container
4. Restart Ollama: `systemctl restart ollama`

---

## Key Success Factors

1. ✅ Used official NVIDIA runfile installer (not Debian packages)
2. ✅ Applied `pci=realloc` kernel parameter for PCI BAR issue
3. ✅ Completely disabled VFIO (no hybrid configuration)
4. ✅ Matched NVIDIA driver versions between host and container
5. ✅ Proper device cgroups and bind mounts in LXC config
6. ✅ Cleaned up old/conflicting NVIDIA package remnants

---

## References

- **PCI BAR Issue**: Known Linux kernel bug with 64-bit BARs above 4GB
- **NVIDIA Driver**: [https://www.nvidia.com/Download/index.aspx](https://www.nvidia.com/Download/index.aspx)
- **Ollama**: [https://ollama.com/](https://ollama.com/)
- **LXC GPU Passthrough**: Proxmox VE documentation

---

**Last Updated**: 2025-10-27
**Configuration Verified**: ✅ Working
**Tested By**: Claude Code Agent
