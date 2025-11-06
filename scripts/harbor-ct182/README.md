# Harbor CT182 Installation Scripts

Complete automation scripts for deploying Harbor enterprise container registry on Proxmox LXC container.

## Quick Start

```bash
# 1. Create the container
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182
chmod +x *.sh
./create-container.sh

# 2. Setup Docker
./setup-docker.sh

# 3. Configure network
./configure-network.sh

# 4. Install Harbor
./install-harbor.sh

# 5. Configure Harbor
./configure-harbor.sh
```

## Script Overview

### 1. create-container.sh
Creates Proxmox LXC container with proper configuration for Harbor.

**Features:**
- Creates CT182 with 8GB RAM, 4 cores, 100GB storage
- Configures IP: 192.168.1.182/24
- Enables Docker nesting and required features
- Sets up unprivileged container with proper capabilities

**Usage:**
```bash
./create-container.sh
# Prompts for root password
```

### 2. setup-docker.sh
Installs and configures Docker CE and Docker Compose.

**Features:**
- Installs latest Docker CE
- Configures Docker daemon with optimal settings
- Installs Docker Compose v2
- Sets up insecure registry for Harbor
- Creates maintenance scripts

**Usage:**
```bash
./setup-docker.sh
# Can be run from Proxmox host or within container
```

### 3. configure-network.sh
Configures network settings, firewall, and DNS.

**Features:**
- Sets static IP 192.168.1.182
- Configures firewall (ports 22, 80, 443, 5000)
- Sets up DNS resolution
- Configures sysctl for Docker
- Tests connectivity

**Usage:**
```bash
./configure-network.sh
# Restart container after: pct reboot 182
```

### 4. install-harbor.sh
Automated Harbor installation with SSL and Trivy scanner.

**Features:**
- Downloads Harbor v2.11.1
- Generates self-signed SSL certificates
- Configures Harbor with Trivy vulnerability scanning
- Installs Chart Museum for Helm charts
- Creates data volumes and directories

**Usage:**
```bash
./install-harbor.sh
# Prompts for Harbor admin password
```

### 5. configure-harbor.sh
Post-installation Harbor configuration via API.

**Features:**
- Creates projects (library, development, production)
- Configures vulnerability scanning policies
- Sets up garbage collection schedule
- Creates robot accounts for CI/CD
- Configures retention policies

**Usage:**
```bash
./configure-harbor.sh
# Prompts for Harbor admin password
```

### 6. backup-restore.sh
Comprehensive backup and restore functionality.

**Features:**
- Full Harbor backup (database, data, config, SSL)
- Point-in-time restore
- Backup listing and cleanup
- 30-day retention policy

**Usage:**
```bash
# Create backup
./backup-restore.sh backup

# List backups
./backup-restore.sh list

# Restore from backup
./backup-restore.sh restore /var/backups/harbor/harbor-backup-TIMESTAMP.tar.gz

# Cleanup old backups
./backup-restore.sh cleanup
```

### 7. maintenance.sh
Daily/weekly maintenance tasks.

**Features:**
- Health checks (API, disk, memory)
- Log rotation
- Database maintenance (vacuum, reindex)
- Docker cleanup (containers, images, volumes)
- Security scanning
- Performance metrics
- Maintenance reports

**Usage:**
```bash
# Health check only
./maintenance.sh health

# Database maintenance
./maintenance.sh database

# Docker cleanup
./maintenance.sh cleanup

# All maintenance tasks
./maintenance.sh all

# Full maintenance (includes deep cleaning)
./maintenance.sh full

# Generate report
./maintenance.sh report
```

## Installation Order

1. **create-container.sh** - Creates the LXC container
2. **setup-docker.sh** - Installs Docker and dependencies
3. **configure-network.sh** - Configures networking
4. **install-harbor.sh** - Installs Harbor
5. **configure-harbor.sh** - Configures Harbor projects and policies

## Maintenance Schedule

### Daily
```bash
./maintenance.sh health
./backup-restore.sh backup
```

### Weekly
```bash
./maintenance.sh all
./backup-restore.sh cleanup
```

### Monthly
```bash
./maintenance.sh full
```

## Automated Cron Jobs

Add to container crontab:

```bash
# Edit crontab
pct exec 182 -- crontab -e

# Add these lines:
# Daily health check and backup
0 2 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh health
0 3 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/backup-restore.sh backup

# Weekly full maintenance
0 4 * * 0 /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh all

# Weekly backup cleanup
0 5 * * 0 /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/backup-restore.sh cleanup

# Monthly deep maintenance
0 6 1 * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh full
```

## Configuration Details

### Container Specifications
- **CTID:** 182
- **Hostname:** harbor
- **IP:** 192.168.1.182/24
- **Gateway:** 192.168.1.1
- **Memory:** 8192 MB
- **Swap:** 4096 MB
- **Cores:** 4
- **Disk:** 100 GB
- **OS:** Debian 12

### Harbor Configuration
- **Version:** v2.11.1
- **HTTP Port:** 80
- **HTTPS Port:** 443
- **Registry Port:** 5000
- **Data Volume:** /var/harbor
- **Install Directory:** /opt/harbor

### Projects
1. **library** - Public, auto-scan enabled
2. **development** - Private, medium severity threshold
3. **production** - Private, high severity, content trust enabled

### Firewall Rules
- Port 22: SSH
- Port 80: HTTP (redirect to HTTPS)
- Port 443: HTTPS (Harbor UI)
- Port 5000: Docker Registry

## Docker Client Configuration

To use Harbor from other machines:

```bash
# Trust Harbor certificate
sudo mkdir -p /etc/docker/certs.d/192.168.1.182
sudo scp root@192.168.1.182:/opt/harbor/ssl/harbor.crt /etc/docker/certs.d/192.168.1.182/ca.crt

# Login to Harbor
docker login 192.168.1.182
# Username: admin
# Password: [your-password]

# Tag and push image
docker tag myimage:latest 192.168.1.182/library/myimage:latest
docker push 192.168.1.182/library/myimage:latest

# Pull image
docker pull 192.168.1.182/library/myimage:latest
```

## Troubleshooting

### Container won't start
```bash
# Check container status
pct status 182

# View logs
pct enter 182
journalctl -xe
```

### Harbor services not running
```bash
# Check Docker status
pct exec 182 -- docker ps

# Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down && docker-compose up -d"

# View Harbor logs
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose logs -f"
```

### Network issues
```bash
# Test connectivity
pct exec 182 -- ping -c 3 google.com

# Check firewall
pct exec 182 -- iptables -L -n

# Verify IP configuration
pct exec 182 -- ip addr show
```

### Disk space issues
```bash
# Check disk usage
pct exec 182 -- df -h

# Run cleanup
./maintenance.sh cleanup

# Run garbage collection
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose exec -T registry registry garbage-collect /etc/registry/config.yml"
```

## Security Considerations

1. **Change default passwords** immediately after installation
2. **Use proper SSL certificates** instead of self-signed (Let's Encrypt recommended)
3. **Enable LDAP/AD integration** for user management
4. **Configure vulnerability scanning** policies appropriately
5. **Set up replication** for disaster recovery
6. **Regular backups** are essential
7. **Keep Harbor updated** to latest stable version
8. **Monitor security scan** results regularly

## Performance Tuning

For production environments, consider:

- Increase memory to 16GB
- Increase disk to 200GB+
- Use SSD storage for better I/O
- Configure external PostgreSQL and Redis
- Enable CDN for image distribution
- Set up load balancing for HA

## Support

- Harbor Documentation: https://goharbor.io/docs/
- GitHub Issues: https://github.com/goharbor/harbor/issues
- Community Slack: https://cloud-native.slack.com/messages/harbor

## License

These scripts are provided as-is for use with Harbor deployment. Harbor itself is licensed under Apache 2.0.
