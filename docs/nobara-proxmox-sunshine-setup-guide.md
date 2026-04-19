# Nobara Linux VM Setup on Proxmox for Game Streaming with Sunshine

**Research Date**: October 1, 2025
**Target Environment**: Proxmox VE 8.x with Nobara Linux 42
**Purpose**: Gaming VM with remote streaming via Sunshine server

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Download Nobara Linux ISO](#download-nobara-linux-iso)
3. [Proxmox Host Configuration](#proxmox-host-configuration)
4. [Create Nobara VM in Proxmox](#create-nobara-vm-in-proxmox)
5. [Install Nobara Linux](#install-nobara-linux)
6. [Post-Installation Configuration](#post-installation-configuration)
7. [Install and Configure Sunshine](#install-and-configure-sunshine)
8. [Configure Auto-Start Services](#configure-auto-start-services)
9. [Firewall Configuration](#firewall-configuration)
10. [Performance Optimization](#performance-optimization)

---

## Prerequisites

### Hardware Requirements
- CPU with VT-d (Intel) or AMD-d (AMD) for GPU passthrough
- Minimum 16GB RAM (leave 2GB for Proxmox host)
- SSD storage recommended for gaming performance
- Dedicated GPU for passthrough (optional but recommended for gaming)
- Secondary GPU for Proxmox host if using GPU passthrough

### Software Requirements
- Proxmox VE 8.x installed and configured
- Access to Proxmox web interface or SSH
- Network connectivity for downloading ISO and packages

---

## Download Nobara Linux ISO

### Official Download Source
Visit: **https://nobaraproject.org/download-nobara/**

### Available Versions (Nobara 42 - 2025-09-25)

**Standard Editions:**
- `Nobara-42-Official-2025-09-25.iso` - Default (recommended for most users)
- `Nobara-42-GNOME-2025-09-25.iso` - GNOME desktop
- `Nobara-42-KDE-2025-09-25.iso` - KDE Plasma desktop
- `Nobara-42-Steam-HTPC-2025-09-25.iso` - Optimized for TV/couch gaming
- `Nobara-42-Steam-Handheld-2025-09-25.iso` - For handheld devices

**NVIDIA Pre-configured Editions (with drivers pre-installed):**
- `Nobara-42-Official-NV-2025-09-25.iso`
- `Nobara-42-GNOME-NV-2025-09-25.iso`
- `Nobara-42-KDE-NV-2025-09-25.iso`
- `Nobara-42-Steam-HTPC-NV-2025-09-25.iso`

### Recommended Choice
- **For NVIDIA GPU passthrough**: Use `Nobara-42-Official-NV-2025-09-25.iso` or `Nobara-42-KDE-NV-2025-09-25.iso`
- **For AMD GPU or no GPU passthrough**: Use `Nobara-42-Official-2025-09-25.iso` or `Nobara-42-KDE-2025-09-25.iso`
- **For streaming/HTPC**: Use `Nobara-42-Steam-HTPC-NV-2025-09-25.iso` (if using NVIDIA)

### Download Steps

1. **Download ISO:**
   ```bash
   cd /var/lib/vz/template/iso
   wget https://download.nobaraproject.org/Nobara-42-Official-NV-2025-09-25.iso
   ```

2. **Verify checksum (recommended):**
   ```bash
   # Download SHA256 checksum from official site
   sha256sum -c Nobara-42-Official-NV-2025-09-25.iso.sha256
   ```

3. **Alternative: Upload via Proxmox Web UI:**
   - Navigate to: Datacenter → Storage → local → ISO Images
   - Click "Upload" and select downloaded ISO

---

## Proxmox Host Configuration

### Enable IOMMU for GPU Passthrough

#### For Intel Systems:

1. **Edit GRUB configuration:**
   ```bash
   nano /etc/default/grub
   ```

2. **Modify kernel parameters:**
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
   ```

3. **Update GRUB:**
   ```bash
   update-grub
   ```

#### For AMD Systems:

1. **Edit GRUB configuration:**
   ```bash
   nano /etc/default/grub
   ```

2. **Modify kernel parameters:**
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
   ```

   **Note**: On modern AMD systems, `amd_iommu=on` is default and can be omitted:
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet initcall_blacklist=sysfb_init"
   ```

3. **Update GRUB:**
   ```bash
   update-grub
   ```

### Load VFIO Modules

1. **Edit modules file:**
   ```bash
   nano /etc/modules
   ```

2. **Add VFIO modules:**
   ```
   vfio
   vfio_iommu_type1
   vfio_pci
   ```

   **Note**: `vfio_virqfd` is no longer needed in Proxmox VE 8 (kernel 6.2+)

3. **Update initramfs:**
   ```bash
   update-initramfs -u -k all
   ```

4. **Reboot Proxmox host:**
   ```bash
   reboot
   ```

### Verify IOMMU is Enabled

After reboot, verify IOMMU:
```bash
dmesg | grep -e DMAR -e IOMMU
```

Expected output should include:
```
DMAR: IOMMU enabled
```

### Identify GPU for Passthrough

1. **List PCI devices:**
   ```bash
   lspci -nn | grep -i vga
   ```

2. **Note the PCI ID** (e.g., `01:00.0`)

3. **Get device IDs:**
   ```bash
   lspci -n -s 01:00.0
   ```

4. **Record vendor:device IDs** (e.g., `10de:1b80` for NVIDIA GTX 1080)

---

## Create Nobara VM in Proxmox

### Recommended VM Specifications for Gaming/Streaming

| Resource | Minimum | Recommended | High-End |
|----------|---------|-------------|----------|
| CPU Cores | 4 | 6-8 | 10-14 |
| RAM | 8 GB | 16 GB | 24-32 GB |
| Disk Size | 60 GB | 120 GB | 256+ GB |
| Disk Type | VirtIO SCSI | VirtIO SCSI (SSD) | VirtIO SCSI (NVMe) |
| Network | VirtIO | VirtIO | VirtIO |
| Machine Type | q35 | q35 | q35 |
| BIOS | OVMF (UEFI) | OVMF (UEFI) | OVMF (UEFI) |

### Method 1: Web UI Creation

1. **Access Proxmox Web Interface**
   - Navigate to your Proxmox host IP: `https://PROXMOX_IP:8006`

2. **Create VM:**
   - Click "Create VM" button
   - **General Tab:**
     - VM ID: `100` (or next available)
     - Name: `nobara-gaming`
     - Start at boot: ☑ (optional)

   - **OS Tab:**
     - ISO Image: Select uploaded Nobara ISO
     - Guest OS Type: Linux
     - Version: 6.x - 2.6 Kernel

   - **System Tab:**
     - Machine: q35
     - BIOS: OVMF (UEFI)
     - Add EFI Disk: ☑
     - EFI Storage: local-lvm
     - SCSI Controller: VirtIO SCSI single
     - Qemu Agent: ☑ (enable)

   - **Disks Tab:**
     - Bus/Device: SCSI 0
     - Storage: local-lvm (or your SSD storage)
     - Disk size: 120 GB
     - Cache: Write back (for performance)
     - IO thread: ☑
     - Discard: ☑
     - SSD emulation: ☑ (if using SSD storage)

   - **CPU Tab:**
     - Sockets: 1
     - Cores: 8
     - Type: host (for maximum performance)
     - Enable NUMA: ☐ (unless you need it)

   - **Memory Tab:**
     - Memory (MiB): 16384 (16 GB)
     - Minimum memory (MiB): 4096
     - Ballooning Device: ☑

   - **Network Tab:**
     - Bridge: vmbr0
     - Model: VirtIO (paravirtualized)
     - Firewall: ☑ (optional)

3. **Add GPU Passthrough (if applicable):**
   - Select VM → Hardware → Add → PCI Device
   - Select GPU device
   - All Functions: ☑
   - Primary GPU: ☑ (if this is the only GPU for the VM)
   - PCI-Express: ☑
   - ROM-Bar: ☑

### Method 2: Command-Line Creation

```bash
# Set variables
VMID=100
VM_NAME="nobara-gaming"
ISO_PATH="local:iso/Nobara-42-Official-NV-2025-09-25.iso"
STORAGE="local-lvm"
CORES=8
MEMORY=16384
DISK_SIZE=120G

# Create VM
qm create $VMID \
  --name $VM_NAME \
  --memory $MEMORY \
  --cores $CORES \
  --sockets 1 \
  --cpu host \
  --ostype l26 \
  --machine q35 \
  --bios ovmf \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 \
  --onboot 1 \
  --agent 1

# Add EFI disk
qm set $VMID --efidisk0 $STORAGE:1,efitype=4m,pre-enrolled-keys=1

# Add main disk
qm set $VMID --scsi0 $STORAGE:$DISK_SIZE,iothread=1,cache=writeback,discard=on,ssd=1

# Attach ISO
qm set $VMID --ide2 $ISO_PATH,media=cdrom

# Set boot order
qm set $VMID --boot order=scsi0

# Optional: Add GPU passthrough (replace with your GPU PCI ID)
# qm set $VMID --hostpci0 01:00,pcie=1,x-vga=1
```

### Configure CPU Pinning (Advanced - Optional)

For best performance, pin vCPUs to physical cores:

```bash
# Get CPU topology
lscpu -e

# Example: Pin 8 vCPUs to physical cores 2-9
qm set $VMID --vcpus 8
qm set $VMID --affinity 2,3,4,5,6,7,8,9
```

---

## Install Nobara Linux

### Start VM and Begin Installation

1. **Start the VM:**
   ```bash
   qm start 100
   ```

2. **Access VM Console:**
   - Web UI: Select VM → Console
   - Or use noVNC console from web interface

3. **Boot from ISO:**
   - Select "Install Nobara Linux" from boot menu
   - Press Enter

### Installation Steps

1. **Language Selection:**
   - Choose your preferred language
   - Click "Continue"

2. **Installation Summary:**

   **Keyboard Layout:**
   - Select your keyboard layout

   **Time & Date:**
   - Set your timezone

   **Installation Destination:**
   - Select the virtual disk (120 GB VirtIO disk)
   - Storage Configuration: "Automatic"
   - Encryption: Optional (note: may impact performance)
   - Click "Done"

   **Network & Hostname:**
   - Enable network connection
   - Set hostname: `nobara-gaming` (or preferred name)
   - Click "Done"

   **Software Selection:**
   - For KDE: "Nobara KDE Plasma Desktop"
   - For GNOME: "Nobara GNOME Desktop"
   - For HTPC: Pre-selected Steam interface
   - Click "Done"

3. **Begin Installation:**
   - Click "Begin Installation"

4. **User Creation:**
   - Set Root Password (strong password recommended)
   - Create User:
     - Full name: Your name
     - Username: your_username
     - Make this user administrator: ☑
     - Set password
   - Wait for installation to complete

5. **Reboot:**
   - Click "Reboot System"
   - Remove installation media if prompted

### First Boot Configuration

1. **Initial Setup Wizard:**
   - Language and keyboard confirmation
   - Online accounts (optional)
   - Privacy settings

2. **Login:**
   - Use the user account created during installation

---

## Post-Installation Configuration

### Update System

```bash
# Update all packages
sudo dnf update -y

# Reboot if kernel was updated
sudo reboot
```

### Install QEMU Guest Agent

The QEMU Guest Agent improves VM management from Proxmox:

```bash
# Install qemu-guest-agent
sudo dnf install -y qemu-guest-agent

# Enable and start service
sudo systemctl enable --now qemu-guest-agent

# Verify status
sudo systemctl status qemu-guest-agent
```

### Configure GPU Drivers (NVIDIA)

If using NVIDIA GPU passthrough:

1. **Open Nobara Welcome App:**
   - Should launch automatically on first login
   - Or search for "Nobara Welcome" in application menu

2. **Install NVIDIA Drivers:**
   - Click "Launch" under "Open Driver Manager"
   - Select "nvidia-driver" (should show as available)
   - Click "Install"
   - Optional: Install "cuda-devel" if needed for compute tasks
   - Reboot after installation

3. **Verify NVIDIA driver:**
   ```bash
   nvidia-smi
   ```

4. **For older NVIDIA cards (GTX 10xx series or older):**
   - These cards lack GSP firmware and need closed-source driver
   - If default open-source driver doesn't work, switch to closed-source:
   ```bash
   # This should be handled by Driver Manager, but can be done manually if needed
   sudo dnf install -y nvidia-driver-latest-dkms
   ```

### Configure GPU Drivers (AMD/Intel)

AMD and Intel drivers are included by default. Optional optimizations:

```bash
# Install mesa Vulkan drivers (git version for latest features - optional)
# Available through Nobara Welcome App → Driver Manager → mesa-vulkan-drivers-git
```

### Install Additional Gaming Tools

Nobara comes pre-configured with many gaming tools, but you can add more:

```bash
# Install additional gaming utilities
sudo dnf install -y gamemode mangohud goverlay

# Install Steam (if not already installed)
sudo dnf install -y steam

# Install Lutris for non-Steam games
sudo dnf install -y lutris

# Install ProtonUp-Qt for Proton management
sudo dnf install -y protonup-qt
```

### Configure Display Settings

For X11 (recommended for Sunshine):

```bash
# Check if X11 is available
echo $XDG_SESSION_TYPE

# If running Wayland, switch to X11:
# For KDE: System Settings → Startup and Shutdown → Login Screen (SDDM) → Behavior → Session → X11
# For GNOME: Edit /etc/gdm/custom.conf and uncomment WaylandEnable=false
```

**Note**: Sunshine works better with X11 than Wayland for game streaming.

### Set Up Auto-Login (Optional - for headless streaming)

For KDE:
```bash
# Edit SDDM config
sudo nano /etc/sddm.conf.d/autologin.conf

# Add:
[Autologin]
User=your_username
Session=plasmax11
```

For GNOME:
```bash
# Edit GDM config
sudo nano /etc/gdm/custom.conf

# Under [daemon] section:
AutomaticLoginEnable=true
AutomaticLogin=your_username
```

---

## Install and Configure Sunshine

### Installation Methods

Nobara is based on Fedora, so you have several installation options:

#### Method 1: Flatpak (Recommended)

```bash
# Add Flathub repository (should be pre-configured on Nobara)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Sunshine
flatpak install -y flathub dev.lizardbyte.app.Sunshine

# Run additional setup for Flatpak
flatpak run --command=additional-install.sh dev.lizardbyte.app.Sunshine
```

#### Method 2: RPM Package (from GitHub)

```bash
# Download latest RPM from GitHub releases
cd ~/Downloads
wget https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-fedora-40-amd64.rpm

# Install RPM
sudo dnf install -y ./sunshine-fedora-40-amd64.rpm

# Remove downloaded file
rm sunshine-fedora-40-amd64.rpm
```

#### Method 3: COPR Repository (NOT recommended for Nobara)

**Warning**: COPR repos may cause conflicts during Nobara version upgrades.

```bash
# NOT RECOMMENDED - can cause package conflicts
# sudo dnf copr enable mavit/sunshine
# sudo dnf install -y sunshine
```

### Post-Installation Configuration

#### Configure Permissions

1. **For X11 capture (recommended):**
   ```bash
   sudo setcap -r $(readlink -f $(which sunshine))
   ```

2. **For KMS/Wayland capture (if using Wayland):**
   ```bash
   sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
   ```

#### Add User to Input Group

For proper controller/input support:
```bash
sudo usermod -a -G input $USER
```

**Log out and back in** for group changes to take effect.

### Initial Sunshine Configuration

1. **Start Sunshine manually (first time):**
   ```bash
   # For native package:
   sunshine

   # For Flatpak:
   flatpak run dev.lizardbyte.app.Sunshine
   ```

2. **Access Web UI:**
   - Open browser and navigate to: `https://localhost:47990`
   - Accept self-signed certificate warning
   - This is normal for first setup

3. **Create Admin Account:**
   - Username: Choose admin username
   - Password: Strong password
   - Click "Create Account"

4. **Configure Basic Settings:**

   **Audio/Video Tab:**
   - Encoder: NVENC (for NVIDIA), VAAPI (for AMD/Intel)
   - Resolution: Match your client device
   - FPS: 60 (or higher if supported)
   - Bitrate: 20000 kbps (adjust based on network)

   **Input Tab:**
   - Enable controller support
   - Configure keyboard/mouse settings

   **Network Tab:**
   - Leave defaults unless you have specific requirements

   **Advanced Tab:**
   - For Flatpak installations, prepend commands with:
     ```
     flatpak-spawn --host
     ```

5. **Add Applications:**
   - Go to "Applications" tab
   - Add games/applications you want to stream
   - Examples:
     - Steam: `/usr/bin/steam`
     - Desktop: `/usr/bin/startplasma-x11` (KDE) or `/usr/bin/gnome-session` (GNOME)

6. **Save Configuration:**
   - Click "Save" at bottom of each tab
   - Restart Sunshine for changes to take effect

---

## Configure Auto-Start Services

### Enable Sunshine Systemd Service

#### For Native Package Installation:

```bash
# Enable user service (recommended)
systemctl --user enable sunshine

# Start service
systemctl --user start sunshine

# Verify status
systemctl --user status sunshine

# View logs
journalctl --user -u sunshine -f
```

#### For Flatpak Installation:

Create a systemd user service:

```bash
# Create user systemd directory
mkdir -p ~/.config/systemd/user

# Create service file
nano ~/.config/systemd/user/sunshine.service
```

Add the following content:
```ini
[Unit]
Description=Sunshine Streaming Server (Flatpak)
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/flatpak run dev.lizardbyte.app.Sunshine
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

Enable and start the service:
```bash
# Reload systemd
systemctl --user daemon-reload

# Enable service
systemctl --user enable sunshine.service

# Start service
systemctl --user start sunshine.service

# Verify status
systemctl --user status sunshine.service
```

### Enable Lingering (Important for headless operation)

This ensures user services start even without login:

```bash
sudo loginctl enable-linger $USER
```

Verify lingering is enabled:
```bash
loginctl show-user $USER | grep Linger
```

Should output: `Linger=yes`

### Troubleshooting Auto-Start

If Sunshine doesn't start automatically:

1. **Check service status:**
   ```bash
   systemctl --user status sunshine
   ```

2. **View logs:**
   ```bash
   journalctl --user -u sunshine -n 50
   ```

3. **Common issues:**
   - **Display not available**: Ensure auto-login is configured
   - **Permission denied**: Re-run setcap commands
   - **Service fails on boot**: Check lingering is enabled

4. **Alternative workaround** (if systemd service fails):
   Create autostart entry:
   ```bash
   mkdir -p ~/.config/autostart

   nano ~/.config/autostart/sunshine.desktop
   ```

   Add:
   ```ini
   [Desktop Entry]
   Type=Application
   Name=Sunshine
   Exec=sunshine
   Hidden=false
   NoDisplay=false
   X-GNOME-Autostart-enabled=true
   ```

---

## Firewall Configuration

### Open Required Ports for Sunshine

Sunshine requires the following ports:

| Port | Protocol | Purpose |
|------|----------|---------|
| 47984 | TCP | HTTPS Web UI |
| 47989 | TCP | HTTP Web UI |
| 47990 | TCP | HTTPS Web UI (default) |
| 48010 | TCP | Control |
| 5353 | UDP | mDNS/Avahi discovery |
| 47998 | UDP | Control |
| 47999 | UDP | Control |
| 48000 | UDP | Video stream |
| 48002 | UDP | Audio stream |
| 48010 | UDP | Control |

### Configure Firewalld

Nobara uses firewalld by default:

```bash
# Add all required ports permanently
sudo firewall-cmd --permanent --zone=public --add-port=47984/tcp
sudo firewall-cmd --permanent --zone=public --add-port=47989/tcp
sudo firewall-cmd --permanent --zone=public --add-port=47990/tcp
sudo firewall-cmd --permanent --zone=public --add-port=48010/tcp
sudo firewall-cmd --permanent --zone=public --add-port=5353/udp
sudo firewall-cmd --permanent --zone=public --add-port=47998/udp
sudo firewall-cmd --permanent --zone=public --add-port=47999/udp
sudo firewall-cmd --permanent --zone=public --add-port=48000/udp
sudo firewall-cmd --permanent --zone=public --add-port=48002/udp
sudo firewall-cmd --permanent --zone=public --add-port=48010/udp

# Reload firewall
sudo firewall-cmd --reload

# Verify ports are open
sudo firewall-cmd --list-ports
```

### Alternative: Create Firewalld Service

Create a custom Sunshine service definition:

```bash
# Create service file
sudo nano /etc/firewalld/services/sunshine.xml
```

Add the following content:
```xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Sunshine</short>
  <description>Sunshine Game Streaming Server</description>
  <port protocol="tcp" port="47984"/>
  <port protocol="tcp" port="47989"/>
  <port protocol="tcp" port="47990"/>
  <port protocol="tcp" port="48010"/>
  <port protocol="udp" port="5353"/>
  <port protocol="udp" port="47998"/>
  <port protocol="udp" port="47999"/>
  <port protocol="udp" port="48000"/>
  <port protocol="udp" port="48002"/>
  <port protocol="udp" port="48010"/>
</service>
```

Enable the service:
```bash
# Reload firewalld
sudo firewall-cmd --reload

# Add sunshine service
sudo firewall-cmd --permanent --zone=public --add-service=sunshine

# Reload firewall
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-services
```

### Proxmox Firewall (Optional)

If Proxmox firewall is enabled on the VM:

1. **Access Proxmox Web UI**
2. **Navigate to:** VM → Firewall → Add
3. **Add rules for each port:**
   - Direction: in
   - Action: ACCEPT
   - Protocol: TCP/UDP (as needed)
   - Dest port: port number
   - Enable: ☑

Or via command line on Proxmox host:
```bash
# Edit VM firewall config
nano /etc/pve/firewall/<VMID>.fw

# Add rules
[RULES]
IN ACCEPT -p tcp -dport 47984
IN ACCEPT -p tcp -dport 47989
IN ACCEPT -p tcp -dport 47990
IN ACCEPT -p tcp -dport 48010
IN ACCEPT -p udp -dport 5353
IN ACCEPT -p udp -dport 47998
IN ACCEPT -p udp -dport 47999
IN ACCEPT -p udp -dport 48000
IN ACCEPT -p udp -dport 48002
IN ACCEPT -p udp -dport 48010
```

---

## Performance Optimization

### VM Performance Tuning

#### CPU Optimization

1. **Set CPU type to 'host'** (already done in VM creation):
   ```bash
   qm set 100 --cpu host
   ```

2. **Enable CPU flags for better performance:**
   ```bash
   qm set 100 --cpu host,flags=+pcid
   ```

3. **Configure CPU governor in guest:**
   ```bash
   # Install cpupower
   sudo dnf install -y kernel-tools

   # Set performance governor
   sudo cpupower frequency-set -g performance

   # Make permanent
   echo 'GOVERNOR="performance"' | sudo tee /etc/sysconfig/cpupower
   sudo systemctl enable cpupower
   ```

#### Memory Optimization

1. **Disable memory ballooning for gaming VM:**
   ```bash
   qm set 100 --balloon 0
   ```

2. **Enable huge pages (advanced):**
   On Proxmox host:
   ```bash
   # Calculate huge pages (for 16GB VM)
   echo 8192 > /proc/sys/vm/nr_hugepages

   # Make permanent
   echo "vm.nr_hugepages = 8192" >> /etc/sysctl.conf
   ```

#### Disk I/O Optimization

1. **Enable IO thread** (already done in VM creation):
   ```bash
   qm set 100 --scsi0 local-lvm:vm-100-disk-0,iothread=1
   ```

2. **Set optimal cache mode:**
   ```bash
   qm set 100 --scsi0 local-lvm:vm-100-disk-0,cache=writeback
   ```

3. **Enable discard/TRIM:**
   ```bash
   qm set 100 --scsi0 local-lvm:vm-100-disk-0,discard=on
   ```

#### Network Optimization

1. **Enable multiqueue (match vCPU count):**
   ```bash
   qm set 100 --net0 virtio,bridge=vmbr0,queues=8
   ```

2. **Increase network buffer sizes in guest:**
   ```bash
   # Add to /etc/sysctl.conf
   sudo tee -a /etc/sysctl.conf <<EOF
   net.core.rmem_max = 134217728
   net.core.wmem_max = 134217728
   net.ipv4.tcp_rmem = 4096 87380 67108864
   net.ipv4.tcp_wmem = 4096 65536 67108864
   EOF

   # Apply
   sudo sysctl -p
   ```

### Gaming-Specific Optimizations

#### Enable GameMode

```bash
# Install gamemode (should be pre-installed on Nobara)
sudo dnf install -y gamemode

# Test gamemode
gamemoded -t

# Use with games
gamemoderun %command%  # Add to Steam launch options
```

#### Configure MangoHud (FPS overlay)

```bash
# Install mangohud (should be pre-installed on Nobara)
sudo dnf install -y mangohud

# Configure
mkdir -p ~/.config/MangoHud
nano ~/.config/MangoHud/MangoHud.conf

# Add basic config:
fps
frame_timing
gpu_stats
cpu_stats
```

#### Disable Compositor (KDE)

For lower latency:
```bash
# Create script to disable compositor
mkdir -p ~/.local/bin
nano ~/.local/bin/game-mode.sh

# Add:
#!/bin/bash
qdbus org.kde.KWin /Compositor suspend

# Make executable
chmod +x ~/.local/bin/game-mode.sh
```

### Sunshine Encoding Optimization

Optimize Sunshine settings for best performance:

1. **Access Sunshine Web UI**: `https://localhost:47990`

2. **Video Settings:**
   - Encoder:
     - NVIDIA: `nvenc` (best)
     - AMD: `vaapi` or `amf`
     - Intel: `vaapi` or `qsv`
   - Codec: `h264` or `hevc` (if supported by client)
   - Bitrate: Start with 20000 kbps, adjust as needed
   - Resolution: Match client display or scale down
   - FPS: 60 (or 120 if network permits)

3. **Advanced Settings:**
   - Min FEC Percentage: 10
   - FEC Percentage: 20
   - Encoder Preset: `p1` to `p4` for NVENC (lower = faster)

---

## Verification and Testing

### Verify Sunshine is Running

```bash
# Check service status
systemctl --user status sunshine

# Check if ports are listening
sudo ss -tulpn | grep -E '47984|47989|47990|48010'

# Check Sunshine logs
journalctl --user -u sunshine -f
```

### Test Streaming

1. **Install Moonlight client** on your streaming device:
   - Windows: https://github.com/moonlight-stream/moonlight-qt/releases
   - Android: Play Store
   - iOS: App Store
   - Linux: `flatpak install moonlight`

2. **Pair device:**
   - Open Moonlight
   - Select your Sunshine server
   - Enter PIN displayed in Sunshine Web UI

3. **Start streaming:**
   - Select application
   - Test latency and quality
   - Adjust settings as needed

### Benchmark Performance

```bash
# CPU performance
sysbench cpu --cpu-max-prime=20000 run

# Disk I/O
fio --name=random-read --ioengine=libaio --rw=randread --bs=4k --numjobs=4 --size=1G --runtime=60 --group_reporting

# Network throughput
iperf3 -c PROXMOX_IP
```

---

## Troubleshooting

### Common Issues

#### Sunshine Won't Start

**Check logs:**
```bash
journalctl --user -u sunshine -n 100
```

**Common fixes:**
- Verify display is available (auto-login configured)
- Check permissions: Re-run `setcap` commands
- Ensure user is in `input` group

#### Black Screen on Stream

**Solutions:**
- Switch to X11 if using Wayland
- Check GPU drivers are properly installed
- Verify encoder is correctly selected in Sunshine

#### High Latency

**Optimizations:**
- Reduce resolution/bitrate
- Use wired connection
- Disable compositor
- Enable GameMode
- Check CPU/GPU aren't throttling

#### GPU Not Detected in VM

**Verify passthrough:**
```bash
lspci | grep -i vga
lspci | grep -i nvidia  # or AMD
```

**Check Proxmox configuration:**
- IOMMU enabled in GRUB
- GPU properly added to VM hardware
- ROM-Bar enabled

#### Firewall Blocking Connections

**Verify ports:**
```bash
sudo firewall-cmd --list-all
sudo ss -tulpn | grep sunshine
```

**Test from client:**
```bash
telnet NOBARA_VM_IP 47990
```

---

## Additional Resources

### Documentation
- **Nobara Wiki**: https://wiki.nobaraproject.org
- **Sunshine Docs**: https://docs.lizardbyte.dev/projects/sunshine
- **Proxmox Wiki**: https://pve.proxmox.com/wiki
- **Moonlight Client**: https://moonlight-stream.org

### Community Support
- **Nobara Discord**: https://discord.gg/nobara
- **Sunshine Discord**: https://discord.gg/LizardByte
- **Proxmox Forums**: https://forum.proxmox.com

### Performance Tuning
- **Linux Gaming Guide**: https://linux-gaming.kwindu.eu
- **Nobara Optimizations**: Built-in via Nobara Welcome App

---

## Summary Checklist

- [ ] Downloaded Nobara Linux ISO
- [ ] Configured Proxmox IOMMU (if using GPU passthrough)
- [ ] Created VM with recommended specifications
- [ ] Installed Nobara Linux
- [ ] Updated system packages
- [ ] Installed QEMU guest agent
- [ ] Configured GPU drivers
- [ ] Installed Sunshine streaming server
- [ ] Configured Sunshine settings
- [ ] Enabled Sunshine auto-start
- [ ] Configured firewall rules
- [ ] Tested streaming with Moonlight client
- [ ] Applied performance optimizations
- [ ] Verified auto-start on reboot

---

## Quick Command Reference

### Proxmox Host
```bash
# List VMs
qm list

# Start VM
qm start 100

# Stop VM
qm stop 100

# VM console
qm terminal 100

# Show VM config
qm config 100
```

### Nobara VM
```bash
# Update system
sudo dnf update

# Restart Sunshine
systemctl --user restart sunshine

# View Sunshine logs
journalctl --user -u sunshine -f

# Check firewall status
sudo firewall-cmd --list-all

# Check GPU
nvidia-smi  # NVIDIA
radeontop   # AMD
```

### Network Testing
```bash
# Test connection to Sunshine
curl -k https://localhost:47990

# Check open ports
sudo ss -tulpn | grep sunshine

# Test from remote
telnet NOBARA_VM_IP 47990
```

---

**Document Version**: 1.0
**Last Updated**: October 1, 2025
**Tested Configuration**: Proxmox VE 8.x + Nobara Linux 42 + Sunshine latest
