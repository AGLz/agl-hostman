# Harbor Container Registry Research for CT182 on aglsrv1
## Comprehensive Best Practices and Implementation Guide

**Research Date:** 2025-10-22
**Target Environment:** Proxmox CT182 (IP: x.x.x.182) on aglsrv1
**Research Agent:** Hive Mind Swarm Researcher
**Session ID:** swarm-1761103289543-v45j2euma

---

## Executive Summary

Harbor is an open-source, enterprise-grade container registry that extends Docker Registry with security, compliance, role-based access control (RBAC), vulnerability scanning, and image signing capabilities. This research provides comprehensive best practices for deploying Harbor in a Proxmox LXC container environment.

### Key Recommendations for CT182:
- **Deployment Method:** LXC container with nested Docker support
- **CPU:** 4 cores (minimum 2)
- **RAM:** 8GB (minimum 4GB)
- **Storage:** 160GB (minimum 40GB) with separate data volume
- **IP Configuration:** Static IP ending in .182
- **Security:** SSL/TLS with proper certificates, vulnerability scanning enabled

---

## 1. System Requirements and Specifications

### 1.1 Recommended Hardware Configuration for CT182

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU Cores** | 2 cores | 4 cores | More cores improve concurrent push/pull performance |
| **Memory (RAM)** | 4 GB | 8 GB | 16GB+ for heavy workloads; registry uses significant memory during large image operations |
| **Disk Space** | 40 GB | 160 GB | Size depends on number and size of container images; consider growth over time |
| **Network** | 1 Gbps | 10 Gbps | Affects image push/pull speeds |

### 1.2 Software Prerequisites

**Operating System:**
- Linux (Ubuntu 18.04+, CentOS 7+, RHEL 7+, Debian 10+)
- **Recommended for CT182:** Ubuntu 22.04 LTS or Debian 12

**Required Software:**
- **Docker Engine:** Version 17.06.0-ce or higher
- **Docker Compose:** Version 1.18.0 or higher
- **OpenSSL:** Latest version for certificate generation

### 1.3 Network Port Requirements

| Port | Protocol | Purpose | Configuration |
|------|----------|---------|---------------|
| **80** | HTTP | Harbor portal and core API | Optional; can redirect to HTTPS |
| **443** | HTTPS | Secure Harbor portal and API | **Required for production** |
| **4443** | HTTPS | Docker Content Trust (Notary) | Only if image signing enabled |

### 1.4 Storage Architecture Recommendations

**Base System Disk:** 16GB minimum for OS and Harbor binaries
**Data Volume:** Separate mount point at `/data/registry` for:
- Container image layers
- Registry data
- Harbor database
- Vulnerability scan data

**Storage Growth Planning:**
- Small deployment (10-50 images): 40-80GB
- Medium deployment (50-200 images): 160-320GB
- Large deployment (200+ images): 500GB+

---

## 2. Proxmox LXC vs VM Deployment Decision

### 2.1 LXC Container (Recommended for CT182)

**Advantages:**
✅ Lightweight with minimal storage footprint
✅ Fast startup and excellent performance (near bare-metal)
✅ Lower memory overhead
✅ Efficient resource utilization on memory-constrained hosts
✅ Modern unprivileged LXC handles Docker daemon smoothly

**Requirements:**
- Enable **nesting** feature (allows Docker to run inside LXC)
- Enable **keyctl** feature (for systemd and container management)
- Map user permissions correctly (user 10000 or respective mapped user)

**Considerations:**
⚠️ Kernel compatibility limitations with certain Docker features
⚠️ May require manual intervention after host reboots
⚠️ Backup complexity higher than VMs

**LXC Configuration for CT182:**
```bash
# Essential LXC features
features: nesting=1,keyctl=1

# Memory allocation
memory: 8192

# CPU allocation
cores: 4

# Storage
rootfs: local-lvm:vm-182-disk-0,size=16G
mp0: /mnt/storage/ct182-data,mp=/data/registry,backup=1
```

### 2.2 VM Alternative (More Robust but Higher Overhead)

**Advantages:**
✅ Full kernel control and complete Docker feature compatibility
✅ Better isolation from host system
✅ Easy backups via Proxmox snapshots
✅ Recommended by Proxmox team for production workloads

**Disadvantages:**
❌ Higher resource consumption
❌ Slower startup times
❌ More storage overhead

**When to Choose VM:**
- Mission-critical production deployments
- Compliance requirements for complete isolation
- Need for maximum kernel compatibility
- Available resources are not constrained

### 2.3 Final Recommendation for CT182

**Deploy as LXC container** given:
- Performance benefits for container registry workloads
- Resource efficiency on Proxmox host
- Proven success with Harbor in LXC (as documented in recent 2025 implementations)
- Modern LXC unprivileged containers handle Docker well

---

## 3. Installation Best Practices

### 3.1 Pre-Installation Checklist

**Step 1: Prepare Proxmox LXC Container**
```bash
# Create LXC container CT182 via Proxmox web UI or CLI
pct create 182 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname harbor-registry \
  --cores 4 \
  --memory 8192 \
  --swap 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=x.x.x.182/24,gw=x.x.x.1 \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --rootfs local-lvm:16

# Start container
pct start 182
```

**Step 2: Configure Storage Mount Point**
```bash
# On Proxmox host - mount NAS/storage to container
pct set 182 -mp0 /mnt/storage/harbor-data,mp=/data/registry

# Inside CT182 - verify permissions
chown -R 10000:10000 /data/registry
chmod 755 /data/registry
```

**Step 3: Install Docker and Docker Compose**
```bash
# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y ca-certificates curl gnupg lsb-release

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

### 3.2 Harbor Installation Process

**Step 1: Download Harbor Installer**
```bash
# Navigate to installation directory
cd /root

# Download latest Harbor (check https://github.com/goharbor/harbor/releases)
wget https://github.com/goharbor/harbor/releases/download/v2.12.2/harbor-online-installer-v2.12.2.tgz

# Extract installer
tar xzvf harbor-online-installer-v2.12.2.tgz
cd harbor
```

**Step 2: Configure Harbor**
```bash
# Copy template configuration
cp harbor.yml.tmpl harbor.yml

# Edit configuration
nano harbor.yml
```

**Critical Configuration Parameters for CT182:**
```yaml
# Hostname - use FQDN that resolves to .182 IP
hostname: harbor.yourdomain.com

# HTTPS configuration (production recommended)
https:
  port: 443
  certificate: /data/secrets/cert/server.crt
  private_key: /data/secrets/cert/server.key

# Harbor admin password
harbor_admin_password: [STRONG_PASSWORD_HERE]

# Data directory (on separate volume)
data_volume: /data/registry

# Database configuration (using internal PostgreSQL)
database:
  password: [DATABASE_PASSWORD_HERE]
  max_idle_conns: 100
  max_open_conns: 900

# Storage configuration
storage_service:
  ca_bundle:
  filesystem:
    maxthreads: 100
```

**Step 3: Generate SSL Certificates**
```bash
# Create certificate directory
mkdir -p /data/secrets/cert

# Option 1: Self-signed certificate (testing only)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /data/secrets/cert/server.key \
  -x509 -days 365 -out /data/secrets/cert/server.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=harbor.yourdomain.com"

# Option 2: Corporate/Let's Encrypt certificate (production)
# Copy your corporate-signed or Let's Encrypt certificates
cp /path/to/cert.crt /data/secrets/cert/server.crt
cp /path/to/cert.key /data/secrets/cert/server.key

# Set proper permissions
chmod 644 /data/secrets/cert/server.crt
chmod 600 /data/secrets/cert/server.key
```

**Step 4: Run Harbor Installer**
```bash
# Install with Trivy vulnerability scanner
./install.sh --with-trivy

# Verify installation
docker compose ps
```

### 3.3 Post-Installation Configuration

**Configure Docker Registry Proxy Cache (Optional but Recommended):**
1. Log into Harbor web UI: https://harbor.yourdomain.com
2. Navigate to Projects → Create Project
3. Enable "Proxy Cache" option
4. Set Docker Hub or GitHub Container Registry as endpoint
5. Configure retention policy (e.g., "keep top 10 recently pulled tags")

**Set Up Automated Container Restart (Critical for LXC):**
```bash
# Create restart script
cat > /root/restart-harbor-containers.sh << 'EOF'
#!/bin/bash
# Restart any stopped Harbor containers
for container in $(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "harbor|nginx|registry"); do
    echo "Restarting $container"
    docker restart $container
done
EOF

chmod +x /root/restart-harbor-containers.sh

# Add cron job (runs every 10 minutes)
crontab -e
# Add line:
*/10 * * * * /root/restart-harbor-containers.sh >> /var/log/harbor-restart.log 2>&1
```

---

## 4. Network Configuration for CT182

### 4.1 Static IP Assignment

**Proxmox LXC Network Configuration:**
```bash
# In CT182 configuration (/etc/pve/lxc/182.conf)
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=XX:XX:XX:XX:XX:XX,ip=192.168.x.182/24,type=veth

# Inside CT182 (/etc/network/interfaces)
auto eth0
iface eth0 inet static
    address 192.168.x.182
    netmask 255.255.255.0
    gateway 192.168.x.1
    dns-nameservers 192.168.x.1 8.8.8.8
```

**Verify Network Configuration:**
```bash
# Check IP assignment
ip addr show eth0

# Test connectivity
ping -c 4 8.8.8.8

# Verify DNS resolution
nslookup harbor.yourdomain.com
```

### 4.2 DNS Configuration

**A Record Configuration:**
```
harbor.yourdomain.com    A    192.168.x.182
```

**Firewall Rules (if applicable):**
```bash
# Allow HTTP (port 80)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS (port 443)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow Docker Content Trust (port 4443) - if using Notary
iptables -A INPUT -p tcp --dport 4443 -j ACCEPT

# Save rules
netfilter-persistent save
```

### 4.3 High Availability Considerations

For production environments requiring HA:
- Deploy load balancer with Virtual IP (VIP)
- Configure active-passive load balancer structure
- Use policy-based replication to secondary Harbor instance
- Implement external PostgreSQL database for shared state

---

## 5. Security Best Practices

### 5.1 Authentication and Access Control

**1. Enable Corporate Authentication:**
```yaml
# In harbor.yml - configure LDAP/AD or OIDC
auth_mode: ldap_auth  # or oidc_auth

# LDAP configuration example
ldap:
  url: ldaps://ldap.yourdomain.com
  search_dn: cn=admin,dc=yourdomain,dc=com
  search_password: [PASSWORD]
  base_dn: ou=users,dc=yourdomain,dc=com
  filter: (objectClass=person)
  uid: uid
  scope: 2
```

**2. Implement Role-Based Access Control (RBAC):**
- **Project Admin:** Full control over project resources
- **Developer:** Push and pull images, create tags
- **Guest:** Pull images only (read-only access)
- **Limited Guest:** Pull limited images based on policy

**3. Enable Single Sign-On (SSO):**
- Configure OpenID Connect (OIDC) with corporate OAuth provider
- Integrate with Active Directory for centralized user management

### 5.2 SSL/TLS Configuration

**Production Requirements:**
✅ Use corporate-signed certificates (not self-signed)
✅ Configure TLS 1.2 minimum (disable TLS 1.0/1.1)
✅ Enable HTTP to HTTPS redirect
✅ Implement certificate renewal automation

**Certificate Deployment:**
```bash
# Place certificates in Harbor-accessible location
cp corporate-cert.crt /data/secrets/cert/server.crt
cp corporate-cert.key /data/secrets/cert/server.key

# Update harbor.yml with certificate paths
# Restart Harbor
cd /root/harbor
docker compose down
docker compose up -d
```

### 5.3 Vulnerability Scanning

**Enable Trivy Scanner (Already enabled in installation):**
- Automatic scanning on every image push
- Configurable scan policies per project
- Severity levels: Critical, High, Medium, Low

**Configure Scan Policies:**
1. Navigate to Project → Configuration → Vulnerability Scanning
2. Enable "Automatically scan images on push"
3. Set prevention policy:
   - **Testing environments:** Allow all severities (log warnings)
   - **Production environments:** Block Critical and High vulnerabilities

**Important Production Warning:**
⚠️ Be cautious with strict prevention policies in production. If an image has vulnerabilities and your orchestrator tries to pull it for auto-scaling, the pull may be blocked, causing service instability.

### 5.4 Image Signing and Content Trust

**Enable Docker Content Trust (Notary):**
```bash
# Install with Notary support
./install.sh --with-notary --with-trivy

# Client-side Docker configuration
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://harbor.yourdomain.com:4443

# Sign and push image
docker trust sign harbor.yourdomain.com/project/image:tag
```

### 5.5 Security Hardening Checklist

- [ ] Change default admin password to strong password
- [ ] Disable HTTP access (HTTPS only)
- [ ] Configure firewall rules to restrict access
- [ ] Enable audit logging
- [ ] Implement regular security updates
- [ ] Configure webhook notifications for security events
- [ ] Set up vulnerability scanning automation
- [ ] Restrict registry access to specific IP ranges (optional)
- [ ] Enable robot accounts for CI/CD (not personal credentials)
- [ ] Implement image retention policies to remove old/vulnerable images

---

## 6. Enterprise Use Cases and Deployment Patterns

### 6.1 Common Use Cases for Harbor

**1. On-Premises Private Registry**
- Host proprietary container images internally
- Maintain complete control over image storage
- Comply with data sovereignty requirements

**2. Docker Hub Mirror/Proxy Cache**
- Reduce external bandwidth consumption
- Improve image pull performance
- Provide resilience against Docker Hub outages
- Navigate Docker Hub rate limits

**3. Multi-Datacenter Image Distribution**
- Policy-based replication across sites
- Achieve high availability
- Support hybrid cloud deployments

**4. Air-Gapped Environment Registry**
- Deploy in environments without internet access
- Maintain offline image repository
- Support disconnected development/production environments

**5. CI/CD Pipeline Integration**
- Store build artifacts from Jenkins/GitLab CI/GitHub Actions
- Automated vulnerability scanning before deployment
- Implement image promotion workflows (dev → staging → prod)

**6. Kubernetes/Container Platform Registry**
- Serve as primary registry for Kubernetes clusters
- Integrate with Rancher, OpenShift, Tanzu
- Support multi-tenant container platforms

### 6.2 Enterprise Deployment Patterns

**Pattern 1: Single-Site Deployment**
```
[Developers] → [Harbor CT182] ← [Kubernetes Cluster]
                     ↓
            [Vulnerability Scanner]
                     ↓
              [Audit Logs]
```

**Pattern 2: Multi-Site with Replication**
```
[Primary Harbor - Site A] ←→ [Secondary Harbor - Site B]
         ↓                              ↓
   [K8s Cluster A]                [K8s Cluster B]
```

**Pattern 3: Hub-and-Spoke**
```
         [Central Harbor Registry]
                    ↓
        ┌───────────┼───────────┐
        ↓           ↓           ↓
   [Edge Site 1] [Edge Site 2] [Edge Site 3]
```

**Pattern 4: Hybrid Cloud**
```
[On-Prem Harbor CT182] ←→ [Azure Container Registry]
         ↓                          ↓
   [Private K8s]             [Azure K8s Service]
```

### 6.3 Integration Points

**Version Control Systems:**
- GitHub/GitLab webhook integration
- Automated builds on code commit
- PR-based image builds and scanning

**CI/CD Platforms:**
- Jenkins pipeline integration
- GitLab CI/CD runners
- GitHub Actions workflows
- CircleCI, Travis CI, Drone

**Kubernetes Platforms:**
- Native Kubernetes ImagePullSecrets
- Rancher integration
- OpenShift image streams
- Tanzu Kubernetes Grid

**Security Tools:**
- Anchore Engine for deep scanning
- Clair integration
- Aqua Security integration
- Twistlock/Prisma Cloud

---

## 7. Backup and Disaster Recovery

### 7.1 Critical Backup Components

**Components to Back Up:**
1. **PostgreSQL Database** (`harbor-db` container)
   - User accounts and RBAC settings
   - Project configurations
   - Scan reports and audit logs

2. **Configuration Files**
   - `/root/harbor/harbor.yml`
   - `/root/harbor/common/config/`

3. **Image Storage** (`/data/registry`)
   - Container image layers
   - Chart repository data (if using Helm charts)

4. **SSL Certificates**
   - `/data/secrets/cert/`

**Not Backed Up (Acceptable):**
- Redis sessions (users will need to re-login)
- Temporary cache data

### 7.2 Backup Strategies

**Strategy 1: Database Dump + Filesystem Backup**
```bash
#!/bin/bash
# Harbor backup script

BACKUP_DIR="/mnt/backup/harbor/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL database
docker exec harbor-db pg_dumpall -U postgres > "$BACKUP_DIR/harbor-db.sql"

# Backup configuration
cp -r /root/harbor/harbor.yml "$BACKUP_DIR/"
cp -r /root/harbor/common/config "$BACKUP_DIR/"

# Backup image data (can be large - consider incremental)
rsync -av --progress /data/registry/ "$BACKUP_DIR/registry/"

# Backup certificates
cp -r /data/secrets "$BACKUP_DIR/"

# Create tarball
tar czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"

# Clean up old backups (keep 30 days)
find /mnt/backup/harbor/ -name "*.tar.gz" -mtime +30 -delete
```

**Strategy 2: Velero-Based Backup (Kubernetes Deployments)**
- Use Velero with restic or CSI snapshots
- Set Harbor to ReadOnly mode during backup
- Back up PersistentVolumes containing registry data
- Schedule daily backups with 30-day retention

**Strategy 3: LXC Container Snapshot (Proxmox)**
```bash
# Create snapshot of CT182
pct snapshot 182 backup-$(date +%Y%m%d) --description "Pre-upgrade backup"

# List snapshots
pct listsnapshot 182

# Rollback if needed
pct rollback 182 backup-20251022
```

### 7.3 Disaster Recovery Procedures

**Recovery Scenario 1: Database Corruption**
```bash
# Stop Harbor
cd /root/harbor
docker compose down

# Restore database dump
docker compose up -d database
sleep 10
docker exec -i harbor-db psql -U postgres < /backup/harbor-db.sql

# Restart all services
docker compose up -d
```

**Recovery Scenario 2: Complete System Failure**
```bash
# 1. Restore LXC container from Proxmox snapshot OR
# 2. Create new CT182 and restore from backup

# Restore configuration
cp /backup/harbor.yml /root/harbor/
cp -r /backup/config /root/harbor/common/

# Restore registry data
rsync -av /backup/registry/ /data/registry/

# Restore database
docker compose up -d database
docker exec -i harbor-db psql -U postgres < /backup/harbor-db.sql

# Start all services
docker compose up -d
```

**Recovery Scenario 3: Multi-Site Failover**
- Promote secondary Harbor instance to primary
- Update DNS records to point to backup site
- Reconfigure replication from new primary to recovered original site
- Validate image availability and user access

### 7.4 Disaster Recovery Best Practices

✅ **Test restores regularly** (quarterly minimum)
✅ **Document recovery procedures** with runbooks
✅ **Store backups off-site** (separate from Proxmox host)
✅ **Encrypt backup data** at rest and in transit
✅ **Monitor backup job success** with alerting
✅ **Implement versioned backups** for point-in-time recovery
✅ **Coordinate with image replication** for geographic redundancy

---

## 8. Performance Optimization

### 8.1 Resource Tuning

**PostgreSQL Optimization:**
```yaml
# In harbor.yml
database:
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0
```

**Registry Storage Optimization:**
```yaml
# In harbor.yml
storage_service:
  filesystem:
    maxthreads: 100  # Adjust based on CPU cores
```

**Garbage Collection Scheduling:**
```bash
# Schedule during low-traffic periods
# Removes unreferenced image layers
# Configure in Harbor UI: Administration → Garbage Collection
# Recommended: Weekly at 2 AM
```

### 8.2 Image Push/Pull Performance

**Client-Side Optimizations:**
- Use multi-stage Docker builds to reduce image sizes
- Implement layer caching strategies
- Use `.dockerignore` to exclude unnecessary files

**Server-Side Optimizations:**
- Enable Redis caching for metadata
- Use SSD storage for `/data/registry`
- Implement CDN or proxy cache for frequently pulled images
- Configure retention policies to limit stored artifacts

### 8.3 Monitoring and Metrics

**Key Metrics to Monitor:**
- Image push/pull success rate
- API response times
- Database connection pool utilization
- Storage utilization and growth rate
- Vulnerability scan queue depth
- Container health status

**Monitoring Tools Integration:**
- Prometheus metrics endpoint (built-in)
- Grafana dashboards for visualization
- AlertManager for threshold alerting
- Harbor audit logs for security monitoring

---

## 9. Common Pitfalls and How to Avoid Them

### 9.1 Installation Mistakes

❌ **Installing Docker directly on Proxmox host**
- Causes network conflicts and complicates updates
- ✅ **Solution:** Always use VM or LXC container

❌ **Insufficient storage planning**
- Registry fills up quickly with large images
- ✅ **Solution:** Separate data volume, monitor growth, implement retention policies

❌ **Using self-signed certificates in production**
- Causes trust issues with Docker clients
- ✅ **Solution:** Use corporate-signed or Let's Encrypt certificates

❌ **Not enabling LXC nesting/keyctl features**
- Docker daemon fails to start
- ✅ **Solution:** Enable `features: nesting=1,keyctl=1` in LXC config

### 9.2 Configuration Mistakes

❌ **Weak admin password**
- Security vulnerability
- ✅ **Solution:** Use strong password, integrate with corporate auth

❌ **No backup strategy**
- Data loss risk
- ✅ **Solution:** Automated daily backups with off-site storage

❌ **Misconfigured user permissions on /data**
- Container failures due to permission denied errors
- ✅ **Solution:** Ensure `/data` writable by user 10000 (LXC unprivileged)

❌ **Missing DNS configuration**
- Harbor inaccessible by hostname
- ✅ **Solution:** Create proper A record pointing to .182 IP

### 9.3 Operational Mistakes

❌ **No monitoring or alerting**
- Issues discovered too late
- ✅ **Solution:** Implement Prometheus/Grafana monitoring

❌ **Strict vulnerability prevention in production**
- Can cause service instability during auto-scaling
- ✅ **Solution:** Use "warn" mode, not "block" mode for production

❌ **Ignoring garbage collection**
- Storage bloat from unreferenced layers
- ✅ **Solution:** Schedule weekly garbage collection

❌ **No container restart automation in LXC**
- Services fail to recover after host reboot
- ✅ **Solution:** Implement cron-based container restart monitoring

---

## 10. Recommended Configuration for CT182

### 10.1 Complete Specification

```yaml
# Proxmox LXC Configuration
CT ID: 182
Hostname: harbor-registry
IP Address: 192.168.x.182/24
Gateway: 192.168.x.1
DNS: 192.168.x.1, 8.8.8.8

# Resources
CPU Cores: 4
Memory: 8192 MB
Swap: 2048 MB

# Storage
Root Disk: 16 GB (local-lvm)
Data Volume: 200 GB mounted at /data/registry

# Features
Nesting: Enabled
Keyctl: Enabled
Unprivileged: Yes

# Network
Static IP: Enabled
Firewall: Enabled (ports 80, 443, 4443)
```

### 10.2 Harbor Configuration Template

```yaml
# /root/harbor/harbor.yml

hostname: harbor.yourdomain.com

https:
  port: 443
  certificate: /data/secrets/cert/server.crt
  private_key: /data/secrets/cert/server.key

harbor_admin_password: [STRONG_PASSWORD]

database:
  password: [DATABASE_PASSWORD]
  max_idle_conns: 100
  max_open_conns: 900

data_volume: /data/registry

trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  insecure: false

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

_version: 2.12.2
```

### 10.3 Post-Installation Checklist

- [ ] CT182 created with correct specifications
- [ ] Static IP .182 configured and tested
- [ ] DNS A record created for harbor.yourdomain.com
- [ ] Data volume mounted at /data/registry with correct permissions
- [ ] Docker and Docker Compose installed
- [ ] SSL certificates generated/deployed
- [ ] Harbor installed with Trivy scanner
- [ ] Admin password changed from default
- [ ] LDAP/OIDC authentication configured
- [ ] First project created with proxy cache enabled
- [ ] Retention policies configured
- [ ] Vulnerability scanning tested
- [ ] Backup script created and scheduled
- [ ] Container restart cron job configured
- [ ] Monitoring configured (optional but recommended)
- [ ] Firewall rules configured
- [ ] Documentation updated with CT182 details

---

## 11. Next Steps and Action Items

### 11.1 Immediate Actions (for Implementation Agent)

1. **Create CT182 in Proxmox** with recommended specifications
2. **Configure network** with static IP ending in .182
3. **Set up storage** with separate data volume
4. **Install Docker** and Docker Compose inside container
5. **Download and configure Harbor** with security best practices

### 11.2 Phase 2 Actions

1. **Integration testing** with Kubernetes cluster
2. **Configure replication** to secondary Harbor instance (if HA required)
3. **Set up monitoring** with Prometheus and Grafana
4. **Implement CI/CD integration** with GitLab/GitHub
5. **User training** on Harbor usage and best practices

### 11.3 Ongoing Maintenance

1. **Weekly:** Review vulnerability scan results
2. **Weekly:** Run garbage collection during maintenance window
3. **Monthly:** Review storage utilization and cleanup old images
4. **Monthly:** Test backup restoration procedures
5. **Quarterly:** Update Harbor to latest stable version
6. **Quarterly:** Review and update access control policies
7. **Annually:** Certificate renewal (if not automated)

---

## 12. References and Resources

### Official Documentation
- **Harbor Documentation:** https://goharbor.io/docs/
- **Harbor GitHub:** https://github.com/goharbor/harbor
- **Proxmox LXC Documentation:** https://pve.proxmox.com/wiki/Linux_Container

### Community Resources
- **Harbor Community:** https://goharbor.io/community/
- **Proxmox Forum:** https://forum.proxmox.com/
- **Docker Documentation:** https://docs.docker.com/

### Security Resources
- **Trivy Scanner:** https://github.com/aquasecurity/trivy
- **Docker Content Trust:** https://docs.docker.com/engine/security/trust/
- **CIS Docker Benchmark:** https://www.cisecurity.org/benchmark/docker

### Implementation Guides Referenced
- Setting up Goharbor Container Registry (Tech Tales Blog, 2025)
- How to Run Docker on Proxmox the Right Way (Virtualization Howto, 2025)
- Harbor Installation Prerequisites (Official Docs)
- Deploying Harbor Container Registry in Production (Medium)

---

## Appendix A: Troubleshooting Common Issues

### Issue 1: Harbor containers exit after CT reboot
**Symptom:** Containers show as "exited" after Proxmox host or CT restart
**Cause:** Dependency resolution issues in Docker Compose
**Solution:** Implement automated restart script via cron (see Section 3.3)

### Issue 2: Permission denied errors in /data
**Symptom:** Harbor fails to write to /data/registry
**Cause:** User mapping mismatch in unprivileged LXC
**Solution:** `chown -R 10000:10000 /data/registry`

### Issue 3: Cannot access Harbor via hostname
**Symptom:** DNS resolution fails for harbor.yourdomain.com
**Cause:** Missing or incorrect DNS A record
**Solution:** Verify DNS configuration and propagation

### Issue 4: Self-signed certificate warnings
**Symptom:** Docker clients reject self-signed certificates
**Cause:** Certificate not trusted by client
**Solution:**
- Production: Use corporate-signed certificate
- Testing: Add CA to Docker daemon's trusted CAs

### Issue 5: Vulnerability scanning not working
**Symptom:** Images show "Not Scanned" status
**Cause:** Trivy database update failed
**Solution:** Check internet connectivity, manually update Trivy DB

### Issue 6: High memory usage
**Symptom:** CT182 consumes more than 8GB RAM
**Cause:** Large concurrent image operations
**Solution:** Increase RAM allocation or limit concurrent operations

---

## Appendix B: Quick Reference Commands

```bash
# Harbor Management
cd /root/harbor
docker compose ps                    # Check container status
docker compose logs -f               # View logs
docker compose down                  # Stop Harbor
docker compose up -d                 # Start Harbor
docker compose restart               # Restart all containers

# Database Backup
docker exec harbor-db pg_dumpall -U postgres > backup.sql

# Database Restore
docker exec -i harbor-db psql -U postgres < backup.sql

# View specific service logs
docker compose logs -f registry      # Registry logs
docker compose logs -f core          # Core API logs
docker compose logs -f jobservice    # Job service logs

# Trivy Database Update
docker exec harbor-trivy /home/scanner/bin/trivy image --download-db-only

# Garbage Collection (manual)
docker exec harbor-core /harbor/harbor_core gc

# Check disk usage
du -sh /data/registry/*
df -h /data/registry

# Network diagnostics
ping -c 4 192.168.x.182
curl -k https://harbor.yourdomain.com

# Container resource usage
docker stats --no-stream

# Proxmox LXC Management
pct start 182
pct stop 182
pct status 182
pct snapshot 182 backup-name
pct enter 182                        # Console access
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-22
**Maintained By:** Hive Mind Research Swarm
**Review Schedule:** Quarterly or upon major Harbor releases
