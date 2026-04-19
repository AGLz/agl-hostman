# Harbor CT182 Deployment Guide
## Production-Ready Implementation for Proxmox aglsrv1

**Author:** Hive Mind Coder Agent
**Session:** swarm-1761131660305-65la2tiid
**Date:** 2025-10-22
**Version:** 1.0.0
**Target:** Proxmox CT182 on aglsrv1

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start Deployment](#quick-start-deployment)
4. [Script Reference](#script-reference)
5. [Configuration Management](#configuration-management)
6. [Security Hardening](#security-hardening)
7. [Monitoring and Health Checks](#monitoring-and-health-checks)
8. [CI/CD Integration](#cicd-integration)
9. [Backup and Recovery](#backup-and-recovery)
10. [Troubleshooting](#troubleshooting)
11. [Maintenance Procedures](#maintenance-procedures)

---

## Overview

This deployment guide provides comprehensive instructions for deploying Harbor Container Registry on Proxmox CT182 (aglsrv1) using the automated scripts created by the Hive Mind implementation team.

### Key Features

- **Fully Automated Deployment**: One-command deployment from Proxmox host to running Harbor instance
- **Production-Ready Configuration**: Security hardening, SSL/TLS, vulnerability scanning
- **Automated Monitoring**: Health checks, Prometheus metrics, alerting
- **CI/CD Integration**: Pre-configured pipelines for GitLab CI, GitHub Actions, Jenkins
- **Backup Automation**: Daily encrypted backups with 30-day retention
- **LXC Optimization**: Container restart automation, resource management

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Proxmox Host (aglsrv1)                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            LXC Container CT182                        │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │          Harbor Components                      │  │  │
│  │  │  ├─ Nginx (HTTPS Proxy)                         │  │  │
│  │  │  ├─ Harbor Core (API & Web UI)                  │  │  │
│  │  │  ├─ Harbor Portal (Frontend)                    │  │  │
│  │  │  ├─ Registry (OCI Registry)                     │  │  │
│  │  │  ├─ PostgreSQL (Database)                       │  │  │
│  │  │  ├─ Redis (Cache)                               │  │  │
│  │  │  ├─ Trivy (Vulnerability Scanner)               │  │  │
│  │  │  └─ JobService (Async Jobs)                     │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  │  IP: 192.168.x.182                                     │  │
│  │  FQDN: harbor.yourdomain.com                           │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements

- **Proxmox VE**: 7.0 or higher
- **Available Resources**:
  - 4 CPU cores (minimum 2)
  - 8GB RAM (minimum 4GB)
  - 200GB storage (160GB data volume + 16GB root)
  - Network connectivity

### Network Requirements

- **Static IP**: IP address ending in .182 (e.g., 192.168.1.182)
- **DNS**: A record for Harbor FQDN pointing to CT182 IP
- **Firewall**: Ports 80, 443, 4443 (optional) accessible
- **Internet Access**: Required for Docker Hub, Trivy updates

### Knowledge Requirements

- Basic Linux administration
- Docker and Docker Compose concepts
- Proxmox LXC container management
- SSL/TLS certificate management (for production)

---

## Quick Start Deployment

### Option 1: Fully Automated Deployment (Recommended)

Execute from Proxmox host:

```bash
# Navigate to scripts directory
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182

# Make scripts executable
chmod +x *.sh

# Run master deployment script
sudo ./deploy-harbor.sh \
    --hostname harbor.example.com \
    --ip-address 192.168.1.182

# Expected runtime: 15-20 minutes
```

### Option 2: Step-by-Step Deployment

```bash
# Step 1: Create Proxmox container
sudo ./create-container.sh

# Step 2: Install Docker inside container
sudo ./setup-docker.sh

# Step 3: Configure network
sudo ./configure-network.sh

# Step 4: Install Harbor
sudo ./install-harbor.sh

# Step 5: Configure Harbor
sudo ./configure-harbor.sh

# Step 6: Apply security hardening
sudo ./security-hardening.sh

# Step 7: Set up monitoring
sudo ./monitoring-healthcheck.sh --install

# Step 8: Configure backups
sudo ./backup-restore.sh --setup
```

### Option 3: Deploy to Existing Container

```bash
# If CT182 already exists
sudo ./deploy-harbor.sh \
    --skip-ct-creation \
    --hostname harbor.example.com
```

### Post-Deployment Verification

```bash
# Check container status
pct status 182

# Verify Harbor containers
pct exec 182 -- docker compose -f /root/harbor/docker-compose.yml ps

# Test web access
curl -k https://192.168.1.182

# Run health check
pct exec 182 -- /usr/local/bin/harbor-healthcheck.sh
```

---

## Script Reference

### /scripts/harbor-ct182/deploy-harbor.sh

**Master deployment script** - Orchestrates complete Harbor deployment

**Features:**
- Creates Proxmox LXC container
- Installs Docker and Docker Compose
- Downloads and configures Harbor
- Generates SSL certificates
- Sets up automation (restart, backup)
- Applies security hardening

**Usage:**
```bash
./deploy-harbor.sh [OPTIONS]

Options:
  --ct-id <ID>              Container ID (default: 182)
  --hostname <FQDN>         Harbor FQDN
  --ip-address <IP>         Static IP address
  --data-volume <PATH>      Data volume path
  --skip-ct-creation        Use existing container
  --skip-ssl                Skip certificate generation
  --production              Production mode (manual certificates)
  --help                    Show help
```

**Examples:**
```bash
# Development deployment
./deploy-harbor.sh --hostname harbor.dev.local --ip-address 192.168.1.182

# Production deployment (bring your own certificates)
./deploy-harbor.sh --production --hostname harbor.prod.example.com

# Deploy to existing container
./deploy-harbor.sh --skip-ct-creation --skip-ssl
```

**Output:**
- Container CT182 created and configured
- Harbor installed and running
- Credentials saved to `.harbor-credentials`
- Log file in `/var/log/harbor-deploy-*.log`

---

### /scripts/harbor-ct182/security-hardening.sh

**Security hardening automation** - Implements production security controls

**Features:**
- Configures firewall (iptables)
- Hardens SSL/TLS (TLS 1.2+ only)
- Secures Docker daemon
- Locks down file permissions
- Applies kernel security parameters
- Configures audit logging
- Sets up encrypted backups
- Creates security monitoring

**Usage:**
```bash
./security-hardening.sh

# No options required - detects CT182 automatically
```

**Security Controls Applied:**
- ✓ Restrictive firewall rules (only 22, 80, 443)
- ✓ Strong SSL ciphers and HSTS headers
- ✓ Docker daemon hardening
- ✓ File permission lockdown (600 for secrets)
- ✓ Kernel parameter hardening (SYN flood protection, etc.)
- ✓ Audit log monitoring (hourly)
- ✓ Security report generation (daily at 6 AM)

---

### /scripts/harbor-ct182/monitoring-healthcheck.sh

**Comprehensive health monitoring** - Checks all Harbor components and generates alerts

**Features:**
- Container health checks (all 8 Harbor containers)
- System resource monitoring (CPU, memory, disk)
- Harbor API health verification
- Database connectivity tests
- Redis cache validation
- Storage health checks
- Network connectivity verification
- Trivy scanner status
- Backup verification
- Certificate expiration monitoring
- Prometheus metrics generation

**Usage:**
```bash
# Run health check
./monitoring-healthcheck.sh

# Exit codes:
#   0 = Healthy
#   1 = Warning (non-critical issues)
#   2 = Critical (service degradation)
```

**Scheduled Execution:**
```bash
# Add to cron for automated monitoring
pct exec 182 -- crontab -e

# Run health check every hour
0 * * * * /usr/local/bin/harbor-healthcheck.sh >> /var/log/harbor-health.log
```

**Output:**
- Console output with color-coded status
- Health report in `/var/log/harbor/health-report-*.txt`
- Prometheus metrics in `/var/lib/harbor/prometheus/harbor_metrics.prom`
- Email alerts (if configured)

---

### /scripts/harbor-ct182/cicd-integration.sh

**CI/CD pipeline integration** - Generates configurations for GitLab CI, GitHub Actions, Jenkins

**Features:**
- Robot account creation guide
- GitLab CI/CD pipeline (.gitlab-ci.yml)
- GitHub Actions workflow (.github/workflows/harbor-deploy.yml)
- Jenkins pipeline (Jenkinsfile)
- Docker client configuration
- Kubernetes secret generation
- Webhook configuration guide

**Usage:**
```bash
export HARBOR_PASSWORD="your-admin-password"
./cicd-integration.sh
```

**Generated Files:**
- `.gitlab-ci.yml` - GitLab CI pipeline with build, scan, push stages
- `.github/workflows/harbor-deploy.yml` - GitHub Actions workflow
- `Jenkinsfile` - Jenkins declarative pipeline
- `docker-harbor-config.sh` - Docker login script
- `harbor-k8s-secret.yaml` - Kubernetes ImagePullSecret template
- `create-k8s-secret.sh` - Kubernetes secret creation script
- `harbor-webhook-config.md` - Webhook integration guide

**Next Steps:**
1. Create robot accounts in Harbor UI
2. Configure CI/CD secrets with robot credentials
3. Test pipelines with sample projects

---

### /scripts/harbor-ct182/backup-restore.sh

**Automated backup and recovery** - Database, configuration, and image data backup

**Features:**
- PostgreSQL database dump
- Configuration file backup
- Certificate backup
- Image data backup (optional, large)
- Encrypted backup support
- 30-day retention policy
- Restore functionality

**Usage:**
```bash
# Create backup
./backup-restore.sh --backup

# Restore from backup
./backup-restore.sh --restore --backup-file /path/to/backup.tar.gz

# List backups
./backup-restore.sh --list

# Setup automated daily backups
./backup-restore.sh --setup
```

**Backup Location:**
- `/data/registry/backups/harbor-backup-YYYYMMDD.tar.gz`

**Scheduled Backups:**
- Automatic daily backups at 2:00 AM
- Configured via cron during deployment

---

## Configuration Management

### Harbor Configuration File

**Location:** `/root/harbor/harbor.yml`
**Template:** `/mnt/overpower/apps/dev/agl/agl-hostman/config/harbor-ct182/harbor.yml.template`

**Key Configuration Sections:**

```yaml
# Network
hostname: harbor.yourdomain.com
https:
  port: 443
  certificate: /data/registry/secrets/cert/server.crt
  private_key: /data/registry/secrets/cert/server.key

# Authentication
harbor_admin_password: STRONG_PASSWORD_HERE
auth_mode: db_auth  # or ldap_auth, oidc_auth

# Database
database:
  password: DB_PASSWORD_HERE
  max_idle_conns: 100
  max_open_conns: 900

# Storage
data_volume: /data/registry
storage_service:
  filesystem:
    maxthreads: 100

# Vulnerability Scanning
trivy:
  ignore_unfixed: false
  skip_update: false
```

### Applying Configuration Changes

```bash
# 1. Edit configuration
pct exec 182 -- nano /root/harbor/harbor.yml

# 2. Restart Harbor
pct exec 182 -- bash -c "cd /root/harbor && docker compose down && docker compose up -d"

# 3. Verify changes
pct exec 182 -- docker compose ps
```

### Environment Variables

```bash
# Set environment variables
pct exec 182 -- bash -c 'echo "HARBOR_VAR=value" >> /etc/environment'

# Reload environment
pct exec 182 -- source /etc/environment
```

---

## Security Hardening

### SSL/TLS Certificates

**Production Deployment:**

```bash
# 1. Obtain corporate-signed or Let's Encrypt certificate
# 2. Copy to container
pct push 182 /path/to/cert.crt /data/registry/secrets/cert/server.crt
pct push 182 /path/to/cert.key /data/registry/secrets/cert/server.key

# 3. Set permissions
pct exec 182 -- chmod 644 /data/registry/secrets/cert/server.crt
pct exec 182 -- chmod 600 /data/registry/secrets/cert/server.key

# 4. Restart Harbor
pct exec 182 -- bash -c "cd /root/harbor && docker compose restart nginx"
```

**Certificate Renewal:**

```bash
# Let's Encrypt auto-renewal (if using Certbot)
pct exec 182 -- certbot renew --deploy-hook "cd /root/harbor && docker compose restart nginx"
```

### Firewall Configuration

**Current Rules (applied by security-hardening.sh):**

```bash
# View firewall rules
pct exec 182 -- iptables -L -n -v

# Allow additional port (example: port 8080)
pct exec 182 -- iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
pct exec 182 -- netfilter-persistent save
```

### Authentication Integration

**LDAP/Active Directory:**

```yaml
# In harbor.yml
auth_mode: ldap_auth
ldap:
  url: ldaps://ldap.example.com
  search_dn: cn=admin,dc=example,dc=com
  search_password: LDAP_PASSWORD
  base_dn: ou=users,dc=example,dc=com
  filter: (objectClass=person)
  uid: uid
  scope: 2
```

**OIDC (Single Sign-On):**

```yaml
# In harbor.yml
auth_mode: oidc_auth
oidc:
  name: corporate-sso
  endpoint: https://sso.example.com
  client_id: harbor-client
  client_secret: CLIENT_SECRET
  scope: openid,profile,email
  auto_onboard: true
```

---

## Monitoring and Health Checks

### Manual Health Check

```bash
# Run comprehensive health check
pct exec 182 -- /usr/local/bin/harbor-healthcheck.sh

# Quick status check
pct exec 182 -- docker compose ps
```

### Automated Monitoring

**Prometheus Integration:**

```bash
# Metrics endpoint
curl http://192.168.1.182:9090/metrics

# Sample metrics:
# - harbor_health_status
# - harbor_containers_running
# - harbor_cpu_usage_percent
# - harbor_memory_usage_percent
# - harbor_disk_usage_percent
```

**Grafana Dashboard:**

```bash
# Import pre-built Harbor dashboard
# Dashboard ID: 8117 (Harbor Overview)
# Data Source: Prometheus

# Grafana URL: http://grafana.example.com
```

### Log Management

```bash
# View Harbor logs
pct exec 182 -- docker compose logs -f

# View specific service logs
pct exec 182 -- docker compose logs -f registry
pct exec 182 -- docker compose logs -f core
pct exec 182 -- docker compose logs -f trivy

# View system logs
pct exec 182 -- tail -f /var/log/harbor/security-alerts.log
pct exec 182 -- tail -f /var/log/harbor-restart.log
```

---

## CI/CD Integration

### Robot Account Setup

**Create Robot Accounts (via Web UI):**

1. Navigate to `Projects → library → Robot Accounts`
2. Click `New Robot Account`
3. Configure:
   - **Name:** `gitlab-ci` (or `github-actions`, `jenkins`, etc.)
   - **Duration:** Never Expires
   - **Permissions:**
     - ✓ Push repository
     - ✓ Pull repository
     - ✓ Delete artifact
4. **Save credentials securely**

### GitLab CI Integration

```bash
# 1. Add generated .gitlab-ci.yml to repository
cp .gitlab-ci.yml /path/to/your/repo/

# 2. Configure GitLab CI/CD variables
# Settings → CI/CD → Variables:
#   HARBOR_ROBOT_USER = robot$gitlab-ci
#   HARBOR_ROBOT_PASSWORD = [password from robot account]

# 3. Push to trigger pipeline
git push origin main
```

### GitHub Actions Integration

```bash
# 1. Add workflow to repository
mkdir -p .github/workflows
cp .github/workflows/harbor-deploy.yml /path/to/your/repo/.github/workflows/

# 2. Configure GitHub Secrets
# Settings → Secrets → Actions:
#   HARBOR_ROBOT_USER = robot$github-actions
#   HARBOR_ROBOT_PASSWORD = [password]

# 3. Push to trigger workflow
git push origin main
```

### Kubernetes Integration

```bash
# Create ImagePullSecret
kubectl create secret docker-registry harbor-registry-secret \
    --docker-server=harbor.example.com \
    --docker-username=robot\$kubernetes \
    --docker-password=[password] \
    --namespace=default

# Use in deployment
spec:
  imagePullSecrets:
    - name: harbor-registry-secret
  containers:
    - name: myapp
      image: harbor.example.com/library/myapp:latest
```

---

## Backup and Recovery

### Automated Backups

**Backup Schedule:**
- Daily at 2:00 AM
- 30-day retention
- Location: `/data/registry/backups/`

**What's Backed Up:**
- PostgreSQL database (user accounts, projects, scan results)
- Harbor configuration files
- SSL certificates
- Audit logs

**NOT Backed Up (by default):**
- Image layers (can be re-pulled or configure manually)
- Redis sessions (ephemeral data)

### Manual Backup

```bash
# Create backup
pct exec 182 -- /usr/local/bin/harbor-backup.sh

# Verify backup
pct exec 182 -- ls -lh /data/registry/backups/
```

### Disaster Recovery

**Scenario 1: Database Corruption**

```bash
# 1. Stop Harbor
pct exec 182 -- bash -c "cd /root/harbor && docker compose down"

# 2. Restore database
pct exec 182 -- bash -c "
    cd /root/harbor
    docker compose up -d database
    sleep 10
    docker exec -i harbor-db psql -U postgres < /data/registry/backups/harbor-backup-20251022/harbor-db.sql
"

# 3. Restart all services
pct exec 182 -- bash -c "cd /root/harbor && docker compose up -d"
```

**Scenario 2: Complete Container Failure**

```bash
# Option A: Restore from Proxmox snapshot
pct snapshot 182 backup-20251022
pct rollback 182 backup-20251022

# Option B: Restore to new container
./deploy-harbor.sh --skip-ct-creation
./backup-restore.sh --restore --backup-file /backups/harbor-backup-20251022.tar.gz
```

**Scenario 3: Proxmox Host Failure**

```bash
# 1. Create new Proxmox CT182 on replacement host
# 2. Mount backup storage
# 3. Run deployment script
./deploy-harbor.sh --hostname harbor.example.com

# 4. Restore data
./backup-restore.sh --restore --backup-file /mnt/backups/harbor-backup-latest.tar.gz
```

---

## Troubleshooting

### Common Issues

**Issue 1: Harbor containers exit after reboot**

**Symptom:** `docker compose ps` shows containers as "Exited"

**Solution:**
```bash
# Automatic restart script should handle this (runs every 10 min)
# Manual restart:
pct exec 182 -- bash -c "cd /root/harbor && docker compose restart"

# Verify restart automation:
pct exec 182 -- crontab -l | grep harbor-restart
```

**Issue 2: Permission denied errors**

**Symptom:** Harbor fails to write to `/data/registry`

**Solution:**
```bash
# Fix permissions for unprivileged LXC
pct exec 182 -- chown -R 10000:10000 /data/registry
pct exec 182 -- chmod 755 /data/registry
```

**Issue 3: SSL certificate errors**

**Symptom:** Docker clients reject self-signed certificates

**Solution:**
```bash
# Option 1: Use corporate-signed certificates (production)
# Follow SSL/TLS section above

# Option 2: Trust self-signed cert on client
# On client machine:
mkdir -p /etc/docker/certs.d/harbor.example.com
scp root@192.168.1.182:/data/registry/secrets/cert/server.crt \
    /etc/docker/certs.d/harbor.example.com/ca.crt
systemctl restart docker
```

**Issue 4: High memory usage**

**Symptom:** Container uses >8GB RAM

**Solution:**
```bash
# Increase container RAM allocation
pct set 182 -memory 12288

# Or optimize Harbor configuration
pct exec 182 -- nano /root/harbor/harbor.yml
# Reduce: database.max_open_conns = 500
# Restart Harbor
```

**Issue 5: Trivy scanner not updating**

**Symptom:** Vulnerability scans fail or show outdated data

**Solution:**
```bash
# Manually update Trivy database
pct exec 182 -- docker exec harbor-trivy /home/scanner/bin/trivy image --download-db-only

# Check internet connectivity
pct exec 182 -- ping -c 4 8.8.8.8
```

### Diagnostic Commands

```bash
# Check container resource usage
pct exec 182 -- docker stats --no-stream

# View recent logs
pct exec 182 -- docker compose logs --tail=100

# Check disk space
pct exec 182 -- df -h

# Network diagnostics
pct exec 182 -- netstat -tuln
pct exec 182 -- curl -k https://localhost

# Database diagnostics
pct exec 182 -- docker exec harbor-db psql -U postgres -c "SELECT version();"
```

---

## Maintenance Procedures

### Weekly Tasks

**1. Review Vulnerability Scan Results**
```bash
# Access Harbor UI: Projects → Library → Repositories
# Review scan results for Critical/High vulnerabilities
```

**2. Run Garbage Collection**
```bash
# Via Harbor UI: Administration → Garbage Collection
# Or manually:
pct exec 182 -- docker exec harbor-core /harbor/harbor_core gc
```

**3. Check Storage Usage**
```bash
pct exec 182 -- du -sh /data/registry/*
pct exec 182 -- df -h /data/registry
```

### Monthly Tasks

**1. Review and Clean Old Images**
```bash
# Configure retention policies via Harbor UI
# Projects → Library → Policy
# Example: Keep only last 10 tags, delete untagged artifacts
```

**2. Test Backup Restoration**
```bash
# Create test backup
pct exec 182 -- /usr/local/bin/harbor-backup.sh

# Verify backup integrity
pct exec 182 -- tar -tzf /data/registry/backups/harbor-backup-$(date +%Y%m%d).tar.gz
```

**3. Review Access Control**
```bash
# Via Harbor UI: Administration → Users
# Via Harbor UI: Projects → Library → Members
# Remove inactive users, audit permissions
```

### Quarterly Tasks

**1. Update Harbor**
```bash
# Check for updates: https://github.com/goharbor/harbor/releases

# Backup before update
pct exec 182 -- /usr/local/bin/harbor-backup.sh

# Download new version
pct exec 182 -- bash -c "
    cd /root
    wget https://github.com/goharbor/harbor/releases/download/v2.x.x/harbor-online-installer-v2.x.x.tgz
    tar xzf harbor-online-installer-v2.x.x.tgz
    cd harbor
    ./install.sh --with-trivy
"
```

**2. Review Security Configuration**
```bash
# Re-run security hardening
./security-hardening.sh

# Review audit logs
pct exec 182 -- tail -100 /var/log/harbor/audit.log
```

**3. Update SSL Certificates** (if not using auto-renewal)
```bash
# Replace certificates
pct push 182 /path/to/new-cert.crt /data/registry/secrets/cert/server.crt
pct push 182 /path/to/new-cert.key /data/registry/secrets/cert/server.key

# Restart Nginx
pct exec 182 -- bash -c "cd /root/harbor && docker compose restart nginx"
```

### Annual Tasks

**1. Disaster Recovery Drill**
```bash
# Test complete restoration procedure
# Document timing and any issues
# Update documentation
```

**2. Security Audit**
```bash
# Run comprehensive security scan
# Review all access controls
# Update security policies
# Re-certify compliance
```

---

## Appendix: File Locations

### Scripts

- `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/deploy-harbor.sh` - Master deployment
- `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/security-hardening.sh` - Security automation
- `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/monitoring-healthcheck.sh` - Health monitoring
- `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/cicd-integration.sh` - CI/CD configuration
- `/mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/backup-restore.sh` - Backup/restore

### Configuration

- `/mnt/overpower/apps/dev/agl/agl-hostman/config/harbor-ct182/harbor.yml.template` - Harbor config template
- `/root/harbor/harbor.yml` (inside CT182) - Active Harbor configuration
- `/data/registry/secrets/cert/` (inside CT182) - SSL certificates

### Data

- `/data/registry/` (inside CT182) - Harbor data volume
  - `registry/` - Image layers
  - `database/` - PostgreSQL data
  - `secrets/` - Certificates and keys
  - `backups/` - Backup archives

### Logs

- `/var/log/harbor/` (inside CT182) - Harbor application logs
- `/var/log/harbor-deploy-*.log` - Deployment logs
- `/var/log/harbor-restart.log` - Container restart log
- `/var/log/harbor-backup.log` - Backup operation log
- `/var/log/harbor/security-alerts.log` - Security event log

---

## Support and Resources

### Documentation

- **Harbor Official Docs**: https://goharbor.io/docs/
- **Research Document**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/harbor-ct182-research.md`
- **This Deployment Guide**: `/mnt/overpower/apps/dev/agl/agl-hostman/docs/harbor-ct182-deployment-guide.md`

### Hive Mind Session

- **Session ID**: swarm-1761131660305-65la2tiid
- **Agents**: Researcher, Analyst, Coder
- **Coordination**: Memory-based task synchronization

### Quick Reference

```bash
# Harbor Management
pct exec 182 -- docker compose -f /root/harbor/docker-compose.yml ps
pct exec 182 -- docker compose -f /root/harbor/docker-compose.yml logs -f
pct exec 182 -- docker compose -f /root/harbor/docker-compose.yml restart

# Health Check
pct exec 182 -- /usr/local/bin/harbor-healthcheck.sh

# Backup
pct exec 182 -- /usr/local/bin/harbor-backup.sh

# Security Check
pct exec 182 -- /usr/local/bin/harbor-security-monitor.sh
```

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-22
**Maintained By:** Hive Mind Coder Agent
**Next Review:** 2026-01-22
