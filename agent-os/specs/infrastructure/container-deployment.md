# LXC Container Deployment with Docker Support

**Type**: Infrastructure Deployment
**Category**: Container Management
**Estimated Time**: 20-30 minutes

## Overview

Deploy a new LXC container on Proxmox with proper configuration for Docker workloads, multi-network access (LAN/WireGuard/Tailscale), and resource allocation.

## Prerequisites

- [ ] Proxmox host is accessible (AGLSRV1, AGLSRV6)
- [ ] Available VMID number
- [ ] Container template is downloaded (Ubuntu 22.04 recommended)
- [ ] IP addresses allocated for each network interface
- [ ] Storage space available

## Specification

### Step 1: Select Container Template
```bash
# On Proxmox host
pveam update
pveam available | grep ubuntu

# Download Ubuntu 22.04 template
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

### Step 2: Create Container with Docker Features
```bash
# Basic container creation
VMID=183
HOSTNAME="archon"
STORAGE="local-zfs"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
IP_LAN="192.168.0.183/24"
GATEWAY="192.168.0.1"

pct create $VMID $TEMPLATE \
  --hostname $HOSTNAME \
  --storage $STORAGE \
  --memory 8192 \
  --swap 4096 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=$IP_LAN,gw=$GATEWAY \
  --features keyctl=1,nesting=1 \
  --unprivileged 1 \
  --onboot 1
```

**Critical Docker Requirements**:
- `--features keyctl=1,nesting=1` - **REQUIRED** for Docker
- `--unprivileged 1` - Security best practice (privileged only if needed)

### Step 3: Configure Advanced Features
```bash
# Edit container config directly
vim /etc/pve/lxc/$VMID.conf

# Add these lines for Docker support:
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw cgroup:rw

# For GPU passthrough (optional, e.g., CT200 Ollama):
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```

### Step 4: Start Container and Install Docker
```bash
# Start container
pct start $VMID

# Enter container
pct enter $VMID

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Enable Docker service
systemctl enable docker
systemctl start docker

# Verify Docker
docker --version
docker ps

# Install docker compose v2
apt install docker-compose-plugin
docker compose version
```

### Step 5: Configure Multiple Network Interfaces (Optional)

**For Dual LAN** (eth0 + eth1):
```bash
# Stop container first
pct stop $VMID

# Add second network interface
pct set $VMID --net1 name=eth1,bridge=vmbr1,ip=192.168.1.183/24

# Start and verify
pct start $VMID
pct enter $VMID
ip addr show
```

**For WireGuard Access**:
Follow [WireGuard Peer Setup](./wireguard-peer-setup.md) workflow

**For Tailscale Access**:
```bash
# Inside container
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --accept-routes

# Get Tailscale IP
tailscale ip -4
```

### Step 6: Resource Allocation Guidelines

**Development Containers** (CT179, CT108):
- Memory: 48GB (heavy workloads)
- Cores: 8-12
- Storage: 500GB+

**Service Containers** (CT183 Archon, CT200 Ollama):
- Memory: 8-16GB
- Cores: 4-6
- Storage: 100-200GB

**Utility Containers** (CT102 PiHole, CT120 WireGuard):
- Memory: 2-4GB
- Cores: 2
- Storage: 32-64GB

### Step 7: Storage Mount (Optional)
```bash
# Mount NFS storage inside container
apt install nfs-common

# Add to container's /etc/fstab
cat >> /etc/fstab <<'EOF'
10.6.0.5:/  /mnt/fgsrv6-wg  nfs vers=4.2,_netdev 0 0
EOF

mkdir -p /mnt/fgsrv6-wg
mount -a
```

### Step 8: Configure Service Ports

**Port Standardization**:
- UI: 3xxx (e.g., 3737 for Archon)
- API: 8xxx (e.g., 8181 for Archon)
- MCP: 805x (e.g., 8051 for Archon)
- nginx proxy: 8080

Example docker-compose.yml with standard ports:
```yaml
version: '3.8'
services:
  ui:
    ports:
      - "3737:3737"

  api:
    ports:
      - "8181:8181"

  mcp:
    ports:
      - "8051:8051"

  nginx:
    ports:
      - "8080:8080"
```

## Security Configuration

### Step 9: Configure Authentication

**For Public Services**:
- Use Basic Auth on nginx reverse proxy
- Example: Archon with `admin / ArchonPass2025`

**For VPN-Only Services**:
- No authentication required (trusted network)
- Accessible only via LAN/WireGuard/Tailscale

### Step 10: Setup Firewall (Optional)
```bash
# Install ufw
apt install ufw

# Allow SSH
ufw allow 22/tcp

# Allow service ports
ufw allow 3737/tcp  # UI
ufw allow 8181/tcp  # API
ufw allow 8051/tcp  # MCP

# Enable firewall
ufw --force enable
ufw status
```

## Verification

### Step 11: Health Checks
```bash
# Container status
pct list | grep $VMID

# Docker status
pct exec $VMID -- docker ps

# Network connectivity
pct exec $VMID -- ping -c 3 1.1.1.1  # Internet
pct exec $VMID -- ping -c 3 192.168.0.245  # Host
pct exec $VMID -- ping -c 3 10.6.0.5  # WireGuard (if configured)

# Resource usage
pct exec $VMID -- free -h
pct exec $VMID -- df -h
```

## Documentation

### Step 12: Update Infrastructure Docs
Update these files:
- [ ] `docs/INFRA.md` - Add container to infrastructure map
- [ ] `CLAUDE.md` - Update key containers list if significant
- [ ] Git commit: `git commit -m "feat: deploy CT$VMID ($HOSTNAME)"`

Add container details:
- VMID and hostname
- IP addresses (LAN, WireGuard, Tailscale)
- Purpose and services
- Resource allocation
- Special configuration notes

## Troubleshooting

### Docker Fails to Start
**Symptom**: `docker ps` fails or daemon won't start
**Cause**: Missing container features
**Fix**:
```bash
# Check container config has:
grep "features" /etc/pve/lxc/$VMID.conf
# Should show: features: keyctl=1,nesting=1

# If missing, add and restart:
pct stop $VMID
echo "features: keyctl=1,nesting=1" >> /etc/pve/lxc/$VMID.conf
pct start $VMID
```

### AppArmor Blocks Docker Operations
**Symptom**: Docker operations fail with permission errors
**Fix**: Set AppArmor to unconfined in container config (shown in Step 3)

### Network Not Accessible
**Symptom**: Container can't reach internet or other networks
**Fix**:
```bash
# Check IP configuration
pct exec $VMID -- ip addr show

# Check default route
pct exec $VMID -- ip route show

# Verify DNS
pct exec $VMID -- cat /etc/resolv.conf
```

## Success Criteria

- [ ] Container starts successfully (`pct start` succeeds)
- [ ] Docker is running (`docker ps` works)
- [ ] Network connectivity verified (internet + LAN)
- [ ] Resource allocation is appropriate
- [ ] Services are accessible on configured ports
- [ ] Documentation updated in git
- [ ] Backup strategy defined

## Related Workflows

- [WireGuard Peer Setup](./wireguard-peer-setup.md)
- [Service Deployment](./service-deployment.md)
- [NFS Storage Mount](./nfs-storage-mount.md)
- [Monitoring Setup](./monitoring-setup.md)
