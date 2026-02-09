# Installation Guide

This guide will walk you through the installation of AGL Hostman on your system.

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 20.04 LTS or newer
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 100GB+ free space
- **Network**: Internet connection for package installation

### Software Dependencies
- **Docker**: 20.10+ (if using Docker setup)
- **Docker Compose**: 1.29+ (if using Docker setup)
- **Python**: 3.8+ (for MkDocs)
- **Git**: 2.30+ (for version control)

### Network Requirements
- **Tailscale**: Must be installed on all hosts
- **Open Ports**:
  - TCP 2049 (NFS)
  - TCP 873 (Rsync)
  - TCP 6443 (Proxmox API)
  - Custom ports for iSCSI configuration

## Installation Methods

### Method 1: Package Installation (Recommended)

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git python3 python3-pip curl wget

# Install MkDocs and plugins
pip3 install mkdocs-material mkdocs-mermaid2-plugin mkdocs-swagger-ui-tag

# Clone repository
git clone https://github.com/aglhostman/agl-hostman.git
cd agl-hostman

# Run installation script
chmod +x scripts/install.sh
./scripts/install.sh
```

### Method 2: Docker Installation

```bash
# Clone repository
git clone https://github.com/aglhostman/agl-hostman.git
cd agl-hostman

# Start services with Docker Compose
docker-compose up -d

# Initialize the system
docker-compose exec agl-hostman npm run initialize
```

### Method 3: Manual Installation

```bash
# Create system user
sudo useradd -m -s /bin/bash aglhostman
sudo usermod -aG sudo aglhostman

# Install system dependencies
sudo apt install -y python3 python3-pip git curl wget

# Install MkDocs
pip3 install mkdocs-material mkdocs-mermaid2-plugin mkdocs-swagger-ui-tag

# Clone repository
sudo -u aglhostman git clone https://github.com/aglhostman/agl-hostman.git /home/aglhostman/agl-hostman
sudo chown -R aglhostman:aglhostman /home/aglhostman/agl-hostman

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install project dependencies
cd /home/aglhostman/agl-hostman
npm install
```

## Post-Installation Setup

### 1. Configuration

```bash
# Copy configuration template
cp config/config.example.json config/config.json

# Edit configuration
nano config/config.json
```

Key configuration settings:

```json
{
  "storage": {
    "nfs": {
      "server": "aglsrv1.local",
      "base_path": "/mnt/aglsrv1/data"
    },
    "iscsi": {
      "target": "iqn.2025-10.com.aglhostman:storage"
    }
  },
  "monitoring": {
    "enabled": true,
    "port": 9090
  },
  "backups": {
    "schedule": "daily",
    "retention": 30
  }
}
```

### 2. Network Setup

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Login to Tailscale
tailscale up

# Verify connection
tailscale status
```

### 3. Storage Configuration

```bash
# Create storage directories
sudo mkdir -p /mnt/aglsrv1/data/{nfs,iscsi,backups}
sudo chown -R aglhostman:aglhostman /mnt/aglsrv1/data

# Configure NFS
sudo mount -t nfs aglsrv1.local:/export /mnt/aglsrv1/data/nfs

# Add to fstab
echo "aglsrv1.local:/export /mnt/aglsrv1/data/nfs nfs defaults 0 0" | sudo tee -a /etc/fstab
```

### 4. Service Initialization

```bash
# Start services
sudo systemctl start agl-hostman
sudo systemctl enable agl-hostman

# Check status
sudo systemctl status agl-hostman

# Enable monitoring
sudo systemctl start prometheus grafana loki
sudo systemctl enable prometheus grafana loki
```

## Verification

### 1. Check Service Status

```bash
# Check all services
agl-hostman status

# Check individual services
agl-hostman service nfs status
agl-hostman service iscsi status
agl-hostman service backup status
```

### 2. Verify Storage

```bash
# List NFS mounts
mount | grep nfs

# Check disk space
df -h /mnt/aglsrv1/data

# Check iSCSI connections
iscsiadm -m session
```

### 3. Test Connectivity

```bash
# Test Tailscale connectivity
ping aglsrv1.local
ping aglsrv6.local
ping fgserver5.local

# Test API connectivity
curl -H "Authorization: Bearer $TOKEN" \
     https://api.aglhostman.local/status
```

## Troubleshooting

### Common Issues

#### 1. Permission Denied
```bash
# Check permissions
ls -la /mnt/aglsrv1/data

# Fix permissions
sudo chown -R aglhostman:aglhostman /mnt/aglsrv1/data
```

#### 2. NFS Connection Issues
```bash
# Test NFS mount manually
sudo mount -t nfs aglsrv1.local:/export /tmp/test_nfs
umount /tmp/test_nfs

# Check NFS service
systemctl status nfs-server
```

#### 3. Tailscale Connection Issues
```bash
# Reset Tailscale
tailscale down
tailscale up

# Check logs
journalctl -u tailscale
```

#### 4. Service Not Starting
```bash
# Check logs
journalctl -u agl-hostman

# Check configuration
agl-hostman config validate
```

### Log Locations

- System logs: `/var/log/agl-hostman/`
- Application logs: `/var/log/agl-hostman/app.log`
- Error logs: `/var/log/agl-hostman/error.log`
- Access logs: `/var/log/agl-hostman/access.log`

## Next Steps

1. [Initial Setup](initial-setup.md) - Configure initial system settings
2. [Architecture Overview](../architecture/overview.md) - Learn about system architecture
3. [Configuration](configuration.md) - Advanced configuration options
4. [Storage Management](../storage/nfs.md) - Configure storage protocols

---

*Need help? Check the [troubleshooting guide](../troubleshooting/common.md) or create an issue on [GitHub](https://github.com/aglhostman/agl-hostman/issues).*