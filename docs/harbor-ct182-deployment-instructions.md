# Harbor CT182 Deployment Instructions

**Deployment Date**: 2025-10-22
**Target Host**: aglsrv1 (Proxmox Host)
**Container**: CT182
**IP Address**: 192.168.0.182
**Hostname**: harbor.agl.local

---

## 🎯 Overview

This document provides step-by-step instructions for deploying Harbor Container Registry to Proxmox CT182 on the aglsrv1 host.

## 📋 Prerequisites

### Environment Information
- **Current Location**: agldv03 (192.168.0.179)
- **Target Host**: aglsrv1 (Proxmox server)
- **Network**: 192.168.0.0/24
- **Gateway**: 192.168.0.1
- **DNS**: 192.168.0.102 (pihole)

### Required Access
- SSH access to aglsrv1 as root
- Network connectivity from agldv03 to aglsrv1
- Sufficient storage on aglsrv1 (150GB for CT182)

## 🚀 Deployment Methods

### Method 1: Remote Deployment (Recommended)

Use the automated remote deployment script that transfers all files to aglsrv1 and executes the installation:

```bash
# From agldv03 (current location)
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182

# Execute remote deployment
./deploy-remote.sh aglsrv1

# Or if you know the IP address:
./deploy-remote.sh 192.168.0.XXX
```

The script will:
1. Verify connectivity to aglsrv1
2. Check SSH access
3. Verify Proxmox environment
4. Transfer all deployment scripts
5. Optionally execute the deployment

### Method 2: Manual SSH Deployment

If you prefer manual control:

#### Step 1: Find aglsrv1 IP Address

```bash
# Try resolving hostname
nslookup aglsrv1
# OR
host aglsrv1

# If not in DNS, check ARP table
arp -a | grep -i aglsrv

# Or scan the network (if needed)
nmap -sn 192.168.0.0/24 | grep -B 2 "aglsrv"
```

#### Step 2: Transfer Scripts to aglsrv1

```bash
# Set the aglsrv1 IP (replace XXX with actual IP)
AGLSRV1_IP="192.168.0.XXX"

# Create temp directory on aglsrv1
ssh root@$AGLSRV1_IP "mkdir -p /tmp/harbor-deploy"

# Transfer all scripts
scp -r /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/*.sh \
    root@$AGLSRV1_IP:/tmp/harbor-deploy/

# Transfer config files
scp -r /mnt/overpower/apps/dev/agl/agl-hostman/config/harbor-ct182 \
    root@$AGLSRV1_IP:/tmp/harbor-deploy/config/
```

#### Step 3: Execute Deployment on aglsrv1

```bash
# Connect to aglsrv1
ssh root@$AGLSRV1_IP

# Navigate to deployment directory
cd /tmp/harbor-deploy

# Make scripts executable
chmod +x *.sh

# Run master deployment script
./deploy-harbor.sh --hostname harbor.agl.local --ip-address 192.168.0.182
```

### Method 3: Direct Connection to aglsrv1

If you have direct console access to aglsrv1:

```bash
# 1. Copy scripts to aglsrv1 via USB/shared storage
# 2. Login to aglsrv1 console
# 3. Execute deployment:

cd /path/to/harbor-scripts
./deploy-harbor.sh --hostname harbor.agl.local --ip-address 192.168.0.182
```

## 📝 Deployment Script Options

The master deployment script supports various options:

```bash
./deploy-harbor.sh [OPTIONS]

Options:
  --ct-id <ID>              Container ID (default: 182)
  --hostname <FQDN>         Harbor hostname (default: harbor.agl.local)
  --ip-address <IP>         Static IP (default: 192.168.0.182)
  --data-volume <PATH>      Data path (default: /data/registry)
  --skip-ct-creation        Skip container creation (if CT exists)
  --skip-ssl                Skip SSL generation (provide own certs)
  --production              Production mode (use corporate certificates)
  --help                    Show help
```

### Example Commands

```bash
# Full automated deployment
./deploy-harbor.sh --hostname harbor.agl.local --ip-address 192.168.0.182

# Deploy to existing container
./deploy-harbor.sh --skip-ct-creation

# Production deployment with corporate certs
./deploy-harbor.sh --production --hostname harbor.prod.agl.local
```

## 🔍 Pre-Deployment Verification

Before running the deployment, verify the environment:

```bash
# On aglsrv1, check:

# 1. Proxmox version
pveversion

# 2. Available storage
pvesm status

# 3. Network configuration
ip addr show vmbr0

# 4. Available templates
pveam available | grep ubuntu-22.04

# 5. CT182 doesn't exist
pct status 182  # Should fail if doesn't exist

# 6. Available resources
free -h
df -h
```

## 📊 Deployment Timeline

**Estimated Total Time**: 20-25 minutes

| Phase | Duration | Description |
|-------|----------|-------------|
| Container Creation | 2 min | Create CT182 with Ubuntu 22.04 |
| Docker Installation | 5 min | Install Docker & Docker Compose |
| Storage Configuration | 1 min | Setup data directories |
| SSL Certificate Generation | 1 min | Generate self-signed certs |
| Harbor Download | 3 min | Download Harbor v2.12.2 |
| Harbor Configuration | 1 min | Configure harbor.yml |
| Harbor Installation | 5 min | Run Harbor installer with Trivy |
| Automation Setup | 2 min | Configure backups & monitoring |
| Verification | 2 min | Test deployment |

## ✅ Post-Deployment Verification

After deployment completes:

### 1. Verify Container Status

```bash
# On aglsrv1
pct status 182
pct exec 182 -- docker ps
```

### 2. Test Network Connectivity

```bash
# From any machine on the network
ping 192.168.0.182
curl -k https://192.168.0.182
```

### 3. Run Automated Tests

```bash
# From agldv03
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182

# Pre-installation validation (if not run yet)
./pre-installation-validation.sh --ctid 182

# Installation verification
./installation-verification.sh --ctid 182 --harbor-ip 192.168.0.182

# Functional tests (requires admin password)
./functional-tests.sh --harbor-ip 192.168.0.182 --admin-password "PASSWORD"

# Performance benchmarks
./performance-benchmarks.sh --harbor-ip 192.168.0.182 --admin-password "PASSWORD"

# Security validation
./security-validation.sh --harbor-ip 192.168.0.182 --admin-password "PASSWORD"
```

### 4. Access Harbor Web UI

```bash
# Open in browser:
https://192.168.0.182
# OR
https://harbor.agl.local  # After DNS is configured

# Default credentials:
Username: admin
Password: [Check deployment output or .harbor-credentials file]
```

## 🔧 Troubleshooting

### Cannot Connect to aglsrv1

```bash
# Verify network connectivity
ping 192.168.0.1  # Gateway

# Check SSH service
ssh -v root@aglsrv1

# Verify SSH keys
ssh-copy-id root@aglsrv1
```

### Container Creation Fails

```bash
# Check available storage
pvesm status

# Check template availability
pveam available | grep ubuntu

# Download template if needed
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

### Harbor Installation Fails

```bash
# Check logs
pct exec 182 -- journalctl -u docker -n 50

# Verify Docker is running
pct exec 182 -- systemctl status docker

# Check Harbor installation logs
pct exec 182 -- cat /root/harbor/install.log
```

### Network Issues in Container

```bash
# Verify network config
pct config 182

# Check container network
pct exec 182 -- ip addr show

# Test DNS resolution
pct exec 182 -- nslookup google.com
```

## 📚 Related Documentation

- **Research Document**: `/docs/research/harbor-ct182-comprehensive-research.md`
- **Infrastructure Analysis**: `/docs/analysis/harbor-ct182-infrastructure-analysis.md`
- **Implementation Summary**: `/docs/harbor-ct182-implementation-summary.md`
- **Quick Reference**: `/docs/harbor-ct182-quick-reference.md`
- **Test Plan**: `/tests/harbor-ct182-test-plan.md`

## 🎯 Next Steps After Deployment

1. **Configure DNS**
   ```bash
   # Add to pihole (192.168.0.102)
   A record: harbor.agl.local → 192.168.0.182
   ```

2. **Change Admin Password**
   - Login to Harbor web UI
   - Navigate to User Profile
   - Change default password

3. **Configure Authentication**
   - Setup LDAP or OIDC if needed
   - Configure user management

4. **Create Projects**
   - Create first project
   - Configure retention policies
   - Setup replication if needed

5. **Configure Docker Clients**
   ```bash
   # On client machines
   sudo mkdir -p /etc/docker/certs.d/192.168.0.182
   sudo scp root@192.168.0.182:/data/registry/secrets/cert/server.crt \
       /etc/docker/certs.d/192.168.0.182/ca.crt
   docker login 192.168.0.182
   ```

6. **Integration with CI/CD**
   - Configure GitLab CI
   - Setup GitHub Actions
   - Configure Jenkins
   - Setup Kubernetes ImagePullSecrets

## ⚠️ Important Notes

1. **IP Address Correction**: All scripts have been updated to use **192.168.0.182** (not 192.168.1.182)
2. **DNS Configuration**: Use **192.168.0.102** (pihole) as primary DNS
3. **Storage**: Requires ~150GB available on aglsrv1
4. **Backup**: Automated daily backups configured at 2 AM
5. **Monitoring**: Health checks run every 10 minutes

## 🔒 Security Considerations

- SSL certificates are self-signed by default (replace with corporate certs for production)
- Firewall configured with minimal open ports (22, 80, 443, 5000)
- Regular security scans enabled via Trivy
- Automated backup with 30-day retention
- Root access required for deployment

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review deployment logs: `/var/log/harbor-deploy-*.log`
3. Check Harbor logs: `pct exec 182 -- docker compose logs -f`
4. Review test results in `/tests/harbor-ct182/`

---

**Deployment Status**: Ready for Execution
**Last Updated**: 2025-10-22
**Prepared by**: Hive Mind Coder Agent (Swarm ID: swarm-1761131660305-65la2tiid)
