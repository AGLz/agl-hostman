# Harbor Container Registry - Comprehensive Research Report
## CT182 Deployment on aglsrv1 Proxmox Infrastructure

**Research Date:** 2025-10-22
**Researcher:** Hive Mind Researcher Agent
**Swarm ID:** swarm-1761131660305-65la2tiid
**Status:** Complete

---

## Executive Summary

This comprehensive research report provides detailed findings for deploying Harbor container registry (version 2.12.0) on Proxmox LXC container CT182 within the aglsrv1 infrastructure. Harbor is an open-source, enterprise-grade container registry that provides vulnerability scanning, role-based access control, image replication, and comprehensive security features.

### Key Recommendations

- **Deployment Method:** Docker Compose with offline installer
- **Harbor Version:** 2.12.0 (latest stable, released 2025)
- **Base OS:** Ubuntu 22.04 LXC (privileged container)
- **Hardware:** 4 CPU cores, 8GB RAM, 100GB system + 500GB data storage
- **Network:** Static IP 192.168.1.182, hostname harbor.agl.local
- **SSL:** Internal CA with 10-year certificates
- **Features:** Trivy vulnerability scanning, proxy cache, RBAC

---

## Table of Contents

1. [Harbor Overview](#harbor-overview)
2. [Version Recommendations](#version-recommendations)
3. [Hardware & Software Requirements](#hardware--software-requirements)
4. [Deployment Patterns](#deployment-patterns)
5. [Proxmox LXC Considerations](#proxmox-lxc-considerations)
6. [Storage Configuration](#storage-configuration)
7. [Security Best Practices](#security-best-practices)
8. [High Availability Architecture](#high-availability-architecture)
9. [Backup & Disaster Recovery](#backup--disaster-recovery)
10. [CI/CD Integration](#cicd-integration)
11. [Proxy Cache Configuration](#proxy-cache-configuration)
12. [Installation Workflow](#installation-workflow)
13. [CT182 Deployment Recommendation](#ct182-deployment-recommendation)
14. [Integration with aglsrv1](#integration-with-aglsrv1)
15. [Monitoring & Performance](#monitoring--performance)
16. [Common Use Cases](#common-use-cases)
17. [Troubleshooting Guide](#troubleshooting-guide)
18. [Sources](#sources)

---

## Harbor Overview

Harbor is an open-source cloud-native registry that stores, signs, and scans container images for vulnerabilities. It extends the Docker Distribution by adding enterprise-grade features including:

- **Security:** Vulnerability scanning, content trust, image signing
- **Management:** RBAC, LDAP/AD integration, project quotas
- **Replication:** Multi-registry replication, geo-distribution
- **Compliance:** Audit logging, retention policies, immutable tags
- **Performance:** Proxy cache for public registries, image acceleration

### Core Components

Harbor 2.12.0 ships with:
- PostgreSQL 15.12 (database)
- Redis 7.2.6 (caching and sessions)
- Distribution 2.8.3 (OCI registry)
- Trivy (vulnerability scanner)
- Nginx (reverse proxy)

---

## Version Recommendations

### Recommended Version: Harbor 2.12.0

**Release Date:** 2025
**Support Lifecycle:** ~9 months
**Stability:** Latest stable release

#### Key Features in 2.12.0

1. **Enhanced Robot Accounts**
   - Improved CI/CD automation capabilities
   - Better access control configuration
   - Enhanced security management

2. **Proxy Cache Speed Limits**
   - Control network speed for proxy cache projects
   - Better bandwidth management
   - Rate limiting capabilities

3. **Improved LDAP Performance**
   - Enhanced user login performance
   - Optimized authentication processes
   - Smoother user experience

4. **ACR & ACR EE Replication**
   - Seamless Azure Container Registry integration
   - Enhanced interoperability
   - Flexible registry federation

5. **SBOM Generation** (from 2.11)
   - Automatic/manual Software Bill of Materials
   - Enhanced transparency and security
   - Compliance support

6. **OCI Distribution Spec v1.1.0**
   - Latest container distribution standards
   - Improved compatibility
   - Future-proof architecture

#### Version Support Policy

- Latest 3 minor releases receive support
- Each minor release maintained ~9 months
- Upgrades only supported from n-2 releases
- Example: 2.9 → 2.11 supported, 2.8 → 2.11 not supported

---

## Hardware & Software Requirements

### Hardware Requirements

| Resource | Minimum | Recommended Production | CT182 Specification |
|----------|---------|----------------------|-------------------|
| CPU | 2 cores | 4 cores | **4 cores** |
| Memory | 4 GB | 8 GB | **8 GB** |
| Storage (System) | 40 GB | 100 GB | **100 GB** |
| Storage (Data) | - | 160 GB+ | **500 GB** |

**Notes:**
- Registry uses significant memory during large image push/pull operations
- Actual storage needs vary based on image count, size, and workload
- Consider S3/Ceph for large-scale deployments (1000+ images)

### Software Prerequisites

| Software | Version Required | Purpose |
|----------|-----------------|---------|
| Docker Engine | 17.06.0-ce+ (20.10.10-ce+ recommended) | Container runtime |
| Docker Compose | 1.18.0+ (latest recommended) | Multi-container orchestration |
| OpenSSL | Latest | Certificate and key generation |
| Operating System | Any Docker-compatible Linux | Ubuntu 22.04 recommended |

### Network Port Requirements

| Port | Protocol | Purpose | Production Recommendation |
|------|----------|---------|--------------------------|
| 80 | HTTP | Portal and API | **Disable or redirect to 443** |
| 443 | HTTPS | Secure portal and API | **Required** |
| 4443 | HTTPS | Docker Content Trust (Notary) | Optional |

---

## Deployment Patterns

### 1. Standalone Docker Compose (Recommended for CT182)

**Method:** Offline or online installer with docker-compose
**Best For:** Single-node deployments, LXC containers, SMB environments

**Advantages:**
- Simple installation and management
- Lower resource requirements
- Perfect for Proxmox LXC deployment
- Easy backup and restoration
- Minimal dependencies

**Components:**
- All Harbor services in Docker containers
- Internal PostgreSQL database
- Internal Redis cache
- Filesystem storage backend

**Management:**
```bash
cd /opt/harbor
docker-compose up -d     # Start Harbor
docker-compose down      # Stop Harbor
docker-compose ps        # Check status
docker-compose logs -f   # View logs
```

**Installer Types:**
- **Offline Installer:** Air-gapped environments, includes all images
- **Online Installer:** Downloads images during installation

### 2. Kubernetes with Helm (Not Recommended for CT182)

**Method:** Helm chart deployment on Kubernetes
**Best For:** Large-scale production, multi-node HA, enterprise environments

**Advantages:**
- High availability
- Auto-scaling
- Cloud-native architecture
- Kubernetes integration

**Requirements:**
- Kubernetes cluster
- External PostgreSQL database
- External Redis cluster
- Persistent storage (PVC or S3)

**Rationale for Not Using:**
- Overkill for single-server deployment
- Adds complexity without benefits
- Requires Kubernetes infrastructure

---

## Proxmox LXC Considerations

### Container Configuration

**Container Type:** Privileged LXC (required for Docker-in-LXC)

**Critical Settings:**
```
Features: nesting=1, keyctl=1
Unprivileged: 0 (must be privileged)
Startup: onboot=1 (auto-start)
```

### Docker-in-LXC Requirements

1. **Nesting Enabled**
   - Allows Docker containers inside LXC
   - Critical for Harbor deployment

2. **User Mapping**
   - Ensure `/data` writable by user 10000 (or mapped UID)
   - Critical for Harbor data persistence
   - Command: `chown -R 10000:10000 /opt/harbor-data`

3. **Storage Considerations**
   - `/data/registry` is primary image storage (largest volume)
   - Use dedicated mount point or expanded root disk
   - SSD storage recommended for performance

### Successful Deployment Evidence

Documented community cases show Harbor running successfully in Proxmox LXC containers with:
- Proper user permissions (UID 10000)
- Nesting enabled
- Adequate storage allocation
- Ubuntu/Debian base templates

### Recommended LXC Base

**Template:** Ubuntu 22.04 Standard
**Rationale:**
- Excellent Docker support
- Long-term support (LTS)
- Comprehensive package ecosystem
- Well-documented Harbor deployments

---

## Storage Configuration

### Default: Filesystem Storage

**Type:** Local filesystem
**Location:** `/data/registry`
**Suitability:** Small to medium deployments

**Configuration in harbor.yml:**
```yaml
storage_service:
  filesystem:
    rootdirectory: /data/registry
    maxthreads: 100
```

**Advantages:**
- Simple to configure
- No external dependencies
- Good performance with SSD
- Easy backup

**Disadvantages:**
- Limited scalability
- Single point of failure
- No geographic distribution

### External Storage Options

#### Amazon S3
```yaml
storage_service:
  s3:
    region: us-west-1
    bucket: harbor-registry
    accesskey: AKIAIOSFODNN7EXAMPLE
    secretkey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### Azure Blob Storage
```yaml
storage_service:
  azure:
    accountname: accountname
    accountkey: accountkey
    container: registry
```

#### Google Cloud Storage
```yaml
storage_service:
  gcs:
    bucket: harbor-registry
    keyfile: /path/to/keyfile.json
```

#### Ceph RADOS
```yaml
storage_service:
  rados:
    poolname: harbor
    username: admin
    chunksize: 4194304
```

### CT182 Storage Recommendation

**Primary Approach:** Filesystem with dedicated Proxmox storage mount

**Configuration:**
1. Create 500GB storage volume in Proxmox
2. Mount as `/mnt/harbor-data` in CT182
3. Configure Harbor to use this location
4. Implement regular backups

**Rationale:**
- Simple and reliable
- Adequate for initial deployment
- Easy to expand if needed
- Straightforward backup process

**Growth Path:**
- Monitor storage usage monthly
- Plan migration to S3/Ceph if exceeding 80% capacity
- Consider external storage at 1000+ images

---

## Security Best Practices

### SSL/TLS Configuration

**Requirement:** HTTPS mandatory for production

**Certificate Options:**

1. **Internal CA (Recommended for CT182)**
   - Generate root CA and issue Harbor certificate
   - 10-year validity period
   - Full control over certificate lifecycle
   - No external dependencies

2. **Let's Encrypt**
   - Free automated certificates
   - 90-day validity (auto-renewal required)
   - Requires public DNS and port 80 access

3. **Commercial CA**
   - Trusted by all browsers/clients
   - Expensive for internal services
   - Annual renewal costs

**Internal TLS:**
- Enable service-to-service TLS encryption
- Protects internal Harbor component communication
- Recommended for production security

### Access Control

**Role-Based Access Control (RBAC):**
- Project Admin: Full project control
- Developer: Push and pull images
- Guest: Pull images only
- Limited Guest: Pull signed images only

**Best Practices:**
1. Create robot accounts for CI/CD (not user credentials)
2. Implement project-level permissions
3. Regular permission audits
4. Remove inactive users/accounts
5. Use LDAP/AD for centralized authentication

### Vulnerability Scanning

**Trivy Scanner (Recommended):**
- Integrated with Harbor 2.12.0
- Comprehensive CVE database
- Automatic daily updates
- No additional licensing

**Scanning Policies:**
1. **Automatic Scan on Push:** Scan all images immediately
2. **Scheduled Scans:** Daily/weekly rescans for new CVEs
3. **Block Deployment:** Prevent vulnerable images (configurable severity)

**Configuration:**
```yaml
# In Web UI: Configuration → Scanners
- Enable Trivy as default scanner
- Configure auto-scan on push
- Set CVE whitelist if needed
- Configure severity thresholds
```

### Image Signing and Content Trust

**Docker Content Trust (Notary):**
- Cryptographic image signing
- Verify image authenticity
- Prevent tampering

**Implementation:**
1. Enable Notary during installation: `./install.sh --with-notary`
2. Configure Content Trust in projects
3. Sign production images
4. Enforce signature verification

### Network Security

**Firewall Rules:**
```
Allow: Internal network → 443/tcp (HTTPS)
Deny:  Public internet → 443/tcp
Allow: Admin network → 22/tcp (SSH to CT182)
Redirect: 80/tcp → 443/tcp (or block entirely)
```

**Additional Measures:**
- Reverse proxy (nginx/HAProxy) for additional layer
- Rate limiting to prevent DoS
- IP whitelisting for administrative access
- VPN requirement for remote access

### Harbor-Specific Security Considerations

**CRITICAL:** Harbor does NOT have secure-by-default settings

**Required Actions:**
1. Change default admin password immediately
2. Disable HTTP access completely
3. Configure RBAC explicitly
4. Enable vulnerability scanning
5. Implement retention policies
6. Enable audit logging
7. Configure strong database passwords
8. Regular security updates (9-month support window)

### Audit Logging

**Enable comprehensive logging:**
- All user actions
- API calls
- Image push/pull operations
- Configuration changes
- Authentication events

**Log Retention:**
- Minimum 90 days for compliance
- Export to SIEM for long-term retention
- Regular log review for anomalies

---

## High Availability Architecture

### HA Overview

Harbor can be deployed in high availability configuration for enterprise production environments requiring 99.9%+ uptime.

### Stateless vs Stateful Components

**Stateless (Scale Horizontally):**
- Portal (Web UI)
- Core (API and business logic)
- Registry (Image distribution)
- Job Service (Background tasks)

**Stateful (Requires External HA Setup):**
- PostgreSQL database
- Redis cache
- Image storage (S3/Ceph/PVC)

### Kubernetes HA Pattern (Not for CT182)

**Architecture:**
```
┌─────────────────────────────────────┐
│  Kubernetes Ingress/Load Balancer   │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────┐           ┌───▼────┐
│Harbor  │           │Harbor  │
│Pod 1   │    ...    │Pod N   │
│(3x rep)│           │(3x rep)│
└───┬────┘           └───┬────┘
    │                     │
    └──────────┬──────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────────┐    ┌──────▼────┐
│External    │    │External   │
│PostgreSQL  │    │Redis      │
│HA Cluster  │    │Cluster    │
└────────────┘    └───────────┘
        │
┌───────▼──────────┐
│  S3/Ceph         │
│  Object Storage  │
└──────────────────┘
```

**Components:**
- Multiple Harbor pod replicas (3-5)
- External PostgreSQL cluster (primary + replicas)
- External Redis cluster (sentinel/cluster mode)
- Shared object storage (S3/Ceph)
- Load balancer for traffic distribution

### VM-Based HA Pattern

**Architecture:**
```
┌─────────────────────────┐
│  HAProxy + Keepalived   │
│  (Active-Passive VIP)   │
└──────────┬──────────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐     ┌──▼────┐
│Harbor │     │Harbor │
│VM 1   │     │VM 2   │
└───┬───┘     └──┬────┘
    │             │
    └──────┬──────┘
           │
┌──────────▼──────────┐
│  PostgreSQL HA      │
│  (Patroni/pgpool)   │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  Shared Storage     │
│  (NFS/Ceph)         │
└─────────────────────┘
```

**Components:**
- 2+ Harbor VMs with identical configuration
- HAProxy for load balancing (active-passive)
- Keepalived for VIP failover
- PostgreSQL HA cluster (Patroni/Repmgr)
- Shared storage for registry data

### CT182 Recommendation: Single-Node with DR

**Rationale:**
- High availability adds significant complexity
- CT182 is internal development/staging registry
- HA typically needed for business-critical production
- Single-node with good backup/DR is cost-effective

**Disaster Recovery Strategy:**
1. Daily Proxmox CT snapshots
2. Daily PostgreSQL dumps to network storage
3. Weekly full backup to offsite location
4. Documented restoration procedure
5. Quarterly DR drill/testing
6. 4-hour RTO (Recovery Time Objective)
7. 24-hour RPO (Recovery Point Objective)

**Future HA Path:**
If Harbor becomes business-critical:
1. Deploy second Harbor instance on different Proxmox node
2. Configure replication between instances
3. Implement DNS-based failover
4. Add load balancer for active-active setup

---

## Backup & Disaster Recovery

### Backup Strategy for Docker Compose Deployments

#### Components to Backup

**Critical Data:**
1. `/data/database` - PostgreSQL data directory
2. `/data/registry` - Container image storage (LARGEST)
3. `/data/secret` - Encryption keys and secrets
4. `/data/ca_download` - CA certificates
5. `/opt/harbor/harbor.yml` - Configuration file
6. `/opt/certs/` - SSL certificates and keys

**Optional Data:**
1. `/data/redis` - Cache data (can be regenerated)
2. `/var/log/harbor/` - Log files (if retained)

#### Backup Methods

**Method 1: Proxmox LXC Snapshots (Recommended)**

**Advantages:**
- Instant snapshot creation
- Minimal downtime
- Point-in-time recovery
- Storage-efficient (copy-on-write)

**Process:**
```bash
# Pre-upgrade snapshot
pct snapshot 182 pre-harbor-upgrade-$(date +%Y%m%d)

# Scheduled snapshots via Proxmox backup jobs
# Daily snapshots, 7-day retention
```

**Limitations:**
- Snapshots stored on same storage (not offsite)
- Large storage requirements if many snapshots
- Not application-consistent (crash-consistent)

**Method 2: PostgreSQL Logical Backup**

**Advantages:**
- Application-consistent database backup
- Small file size (compressed SQL)
- Easy to restore to different versions
- Can restore specific tables/data

**Process:**
```bash
# Backup script
docker exec harbor-db pg_dumpall -U postgres | gzip > /backup/harbor-db-$(date +%Y%m%d).sql.gz

# Restore process
gunzip < harbor-db-20251022.sql.gz | docker exec -i harbor-db psql -U postgres
```

**Method 3: Filesystem Backup**

**Advantages:**
- Complete data backup
- No database-specific tools needed
- Easy to understand

**Process:**
```bash
# Stop Harbor for consistency
cd /opt/harbor && docker-compose down

# Backup data directory
tar -czf /backup/harbor-data-$(date +%Y%m%d).tar.gz /opt/harbor-data

# Backup configuration
tar -czf /backup/harbor-config-$(date +%Y%m%d).tar.gz /opt/harbor /opt/certs

# Restart Harbor
cd /opt/harbor && docker-compose up -d
```

**Method 4: Docker Volume Backup**

**Process:**
```bash
# List volumes
docker volume ls | grep harbor

# Backup each volume
docker run --rm -v harbor_database:/data -v /backup:/backup \
  alpine tar -czf /backup/harbor-db-volume.tar.gz /data
```

#### Recommended Backup Schedule for CT182

**Daily (Automated):**
- 02:00 AM - PostgreSQL pg_dumpall backup
- 03:00 AM - Incremental Proxmox snapshot
- Retention: 7 days local

**Weekly (Automated):**
- Sunday 01:00 AM - Full filesystem backup to NAS
- Sunday 02:00 AM - Full Proxmox snapshot
- Retention: 4 weeks local, 12 weeks offsite

**Monthly (Automated):**
- 1st of month - Full backup to offsite storage
- Retention: 12 months

**Pre/Post-Maintenance (Manual):**
- Before upgrades - Full snapshot
- Before configuration changes - Configuration backup
- Retention: Until verified successful

### Disaster Recovery Procedures

#### Scenario 1: CT182 Container Corruption

**Recovery Steps:**
1. Restore from latest Proxmox snapshot
2. Verify Harbor services start correctly
3. Test image pull/push operations
4. Review logs for errors

**RTO:** 15 minutes
**RPO:** Last snapshot (max 24 hours)

#### Scenario 2: Database Corruption

**Recovery Steps:**
1. Stop Harbor: `cd /opt/harbor && docker-compose down`
2. Remove corrupted database: `rm -rf /opt/harbor-data/database`
3. Restore from pg_dump:
   ```bash
   cd /opt/harbor && docker-compose up -d database
   gunzip < /backup/harbor-db-latest.sql.gz | docker exec -i harbor-db psql -U postgres
   ```
4. Restart all services: `docker-compose up -d`
5. Verify functionality

**RTO:** 30 minutes
**RPO:** Last pg_dump (max 24 hours)

#### Scenario 3: Complete Hardware Failure

**Recovery Steps:**
1. Provision new Proxmox node or restore hardware
2. Create new CT182 container with same specifications
3. Install Docker and Docker Compose
4. Restore Harbor installation from backup
5. Restore data from latest full backup
6. Update DNS/IP if necessary
7. Verify and test

**RTO:** 4 hours
**RPO:** Last full backup (max 7 days)

#### Scenario 4: Accidental Image Deletion

**Recovery Steps:**
1. Check if image still in blob storage (soft delete)
2. If available, restore via Harbor API
3. If not, restore from latest backup
4. Alternative: Re-push image from source/CI/CD

**RTO:** Varies (minutes to hours)
**RPO:** Last backup or source rebuild

### Backup Best Practices

**Security:**
- Encrypt backups at rest (GPG/LUKS)
- Encrypt backups in transit (SCP/SFTP/S3-SSE)
- Protect backup credentials (separate from Harbor)
- Test encryption/decryption regularly

**Storage:**
- Store backups on different physical storage than source
- Offsite backup mandatory (different building/datacenter)
- Use immutable backup storage if available
- Monitor backup storage capacity

**Testing:**
- Quarterly restoration test (complete DR drill)
- Monthly restore test (database only)
- Document restore time and issues
- Update runbook based on tests

**Monitoring:**
- Alert on backup job failures
- Alert on backup storage capacity
- Alert on backup age exceeding threshold
- Dashboard for backup status

### Kubernetes Backup (Reference Only)

For Kubernetes deployments, use **Velero**:

**Backup Methods:**
1. **Restic Integration:** Long-term persistent volume backup
2. **CSI Snapshots:** Short-term volume snapshots
3. **Namespace Backup:** Complete Harbor namespace backup

**Important Limitations:**
- Backups are crash-consistent (not application-consistent)
- Redis data NOT backed up (sessions lost)
- External databases NOT backed up automatically
- Read-only mode recommended before backup

**Process:**
```bash
# Enable read-only mode in Harbor UI
# Take backup
velero backup create harbor-backup --include-namespaces harbor

# Restore
velero restore create --from-backup harbor-backup
```

---

## CI/CD Integration

### Supported Platforms

#### GitLab CI/CD

**Integration Type:** Native Harbor integration
**Authentication:** Robot accounts (recommended) or personal credentials

**Configuration:**
```yaml
# .gitlab-ci.yml
variables:
  HARBOR_HOST: harbor.agl.local
  HARBOR_PROJECT: library
  HARBOR_USERNAME: robot$cicd-pusher
  HARBOR_PASSWORD: $CI_HARBOR_TOKEN
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

stages:
  - build
  - scan
  - deploy

build:
  stage: build
  script:
    - docker login $HARBOR_HOST -u $HARBOR_USERNAME -p $HARBOR_PASSWORD
    - docker build -t $HARBOR_HOST/$HARBOR_PROJECT/myapp:$IMAGE_TAG .
    - docker push $HARBOR_HOST/$HARBOR_PROJECT/myapp:$IMAGE_TAG

scan:
  stage: scan
  script:
    - curl -u $HARBOR_USERNAME:$HARBOR_PASSWORD \
      "https://$HARBOR_HOST/api/v2.0/projects/$HARBOR_PROJECT/repositories/myapp/artifacts/$IMAGE_TAG/scan"
```

**GitLab Harbor Integration (Native):**
1. Navigate to Settings → Integrations → Harbor
2. Enter Harbor URL and credentials
3. Enable Container Scanning integration
4. View vulnerability results in Merge Requests

#### Jenkins

**Integration Type:** Docker Pipeline plugins
**Authentication:** Robot accounts or credentials plugin

**Jenkinsfile Example:**
```groovy
pipeline {
    agent any

    environment {
        HARBOR_URL = 'harbor.agl.local'
        HARBOR_CREDENTIALS = credentials('harbor-robot-account')
        IMAGE_NAME = "${HARBOR_URL}/library/myapp"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry("https://${HARBOR_URL}", 'harbor-robot-account') {
                        docker.image("${IMAGE_NAME}:${IMAGE_TAG}").push()
                        docker.image("${IMAGE_NAME}:${IMAGE_TAG}").push('latest')
                    }
                }
            }
        }

        stage('Scan') {
            steps {
                sh """
                    curl -u \${HARBOR_CREDENTIALS} -X POST \\
                    "https://${HARBOR_URL}/api/v2.0/projects/library/repositories/myapp/artifacts/${IMAGE_TAG}/scan"
                """
            }
        }
    }
}
```

#### GitHub Actions

**Integration Type:** Docker login action
**Authentication:** Robot accounts via GitHub Secrets

**Workflow Example:**
```yaml
name: Build and Push to Harbor

on:
  push:
    branches: [ main ]

env:
  HARBOR_URL: harbor.agl.local
  HARBOR_PROJECT: library
  IMAGE_NAME: myapp

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to Harbor
        uses: docker/login-action@v2
        with:
          registry: ${{ env.HARBOR_URL }}
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          push: true
          tags: |
            ${{ env.HARBOR_URL }}/${{ env.HARBOR_PROJECT }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.HARBOR_URL }}/${{ env.HARBOR_PROJECT }}/${{ env.IMAGE_NAME }}:latest
```

### Common CI/CD Workflow

**Standard Pipeline:**
```
1. Code Commit
   ↓
2. Build Docker Image
   ↓
3. Tag with version/commit hash
   ↓
4. Login to Harbor (robot account)
   ↓
5. Push image to Harbor project
   ↓
6. Trigger Harbor vulnerability scan
   ↓
7. Wait for scan results
   ↓
8. Check CVE severity threshold
   ↓
9. Sign image (optional - Notary)
   ↓
10. Deploy to environment
```

### Best Practices

**Robot Accounts:**
1. Create separate robot accounts per CI/CD pipeline
2. Grant minimum required permissions (push/pull specific projects)
3. Set expiration dates (or "never" for stable pipelines)
4. Rotate credentials annually
5. Name clearly: `robot$gitlab-myapp-pusher`

**Project Organization:**
```
/development  - Auto-cleanup, short retention
/staging      - 30-day retention, vulnerability scanning
/production   - Immutable tags, content trust, indefinite retention
```

**Image Tagging Strategy:**
```
Commit SHA:     myapp:abc123def
Semantic:       myapp:1.2.3
Environment:    myapp:staging, myapp:production
Latest:         myapp:latest (development only)
```

**Vulnerability Management:**
1. Scan all images automatically on push
2. Fail pipeline if critical CVEs detected
3. Maintain CVE allowlist for acceptable risks
4. Weekly rescan for new vulnerabilities
5. Block deployment of vulnerable images

**Retention Policies:**
```yaml
Development:
  - Keep latest 10 tags
  - Delete untagged artifacts immediately
  - Auto-cleanup older than 30 days

Staging:
  - Keep latest 20 tags
  - Retain for 90 days
  - Keep all tagged artifacts

Production:
  - Keep ALL tagged artifacts indefinitely
  - Enable tag immutability
  - Require image signing
```

---

## Proxy Cache Configuration

### Overview

Harbor proxy cache allows Harbor to act as a pull-through cache for public container registries, mitigating rate limits and improving performance.

### Benefits

1. **Avoid Docker Hub Rate Limits**
   - Docker Hub: 100 pulls/6hrs (anonymous), 200 pulls/6hrs (free account)
   - Harbor caches images locally after first pull
   - Subsequent pulls served from Harbor

2. **Reduce Bandwidth Costs**
   - Public registry pulls consume internet bandwidth
   - Cached images pulled from local Harbor (LAN speed)
   - Significant savings for large teams

3. **Improve Performance**
   - LAN speeds vs internet speeds
   - No external latency
   - Consistent availability even if upstream down

4. **Offline Availability**
   - Cached images available without internet
   - Useful for air-gapped networks
   - Disaster recovery scenarios

### Supported Registries

- **Docker Hub** (hub.docker.com)
- **Quay.io** (quay.io)
- **Google Container Registry** (gcr.io)
- **Azure Container Registry** (ACR)
- **Custom/Private Registries**

### Configuration Steps

#### 1. Create Registry Endpoint

**Web UI Path:** Administration → Registries → + New Endpoint

**Configuration:**
```
Provider: Docker Hub
Name: dockerhub-endpoint
Endpoint URL: https://hub.docker.com
Access ID: (Docker Hub username - optional)
Access Secret: (Docker Hub password/token - optional)
Verify Remote Cert: Yes (for HTTPS registries)
```

**Note:** Providing Docker Hub credentials increases rate limits from 100 to 200 pulls/6hrs.

#### 2. Create Proxy Cache Project

**Web UI Path:** Projects → + New Project

**Configuration:**
```
Project Name: dockerhub
Registry Type: Proxy Cache
Registry: dockerhub-endpoint (from step 1)
Public: No (recommended for internal use)
Proxy Cache:
  - Enable proxy cache
  - Bandwidth limit: (optional, new in 2.12)
```

#### 3. Pull Images Through Proxy Cache

**Format:** `harbor.agl.local/<proxy-project>/<image-path>:<tag>`

**Examples:**

**Official Images (require 'library' namespace):**
```bash
# Instead of: docker pull nginx:latest
docker pull harbor.agl.local/dockerhub/library/nginx:latest

# Instead of: docker pull redis:alpine
docker pull harbor.agl.local/dockerhub/library/redis:alpine
```

**User/Org Images:**
```bash
# Instead of: docker pull gitlab/gitlab-ce:latest
docker pull harbor.agl.local/dockerhub/gitlab/gitlab-ce:latest

# Instead of: docker pull bitnami/postgresql:14
docker pull harbor.agl.local/dockerhub/bitnami/postgresql:14
```

### Important Limitations

**Cannot Use as Transparent Docker Mirror:**

Docker's `registry-mirrors` configuration expects only a hostname, not a project path. This means you CANNOT configure:

```json
# This does NOT work
{
  "registry-mirrors": ["https://harbor.agl.local/dockerhub"]
}
```

**Workaround:** Users must explicitly use Harbor prefix in pull commands or update Dockerfiles/deployment manifests.

### Speed Limits (Harbor 2.12+)

**New Feature:** Control network speed for proxy cache projects

**Use Cases:**
- Limit bandwidth consumption during business hours
- Prevent proxy cache from saturating network
- Fair bandwidth allocation across services

**Configuration:**
```
Project Settings → Proxy Cache → Speed Limit
- Set KB/s or MB/s limit
- Applied per pull request
- Useful for large images
```

### Best Practices

**1. Multiple Proxy Cache Projects:**
```
/dockerhub     - Docker Hub proxy
/quay          - Quay.io proxy
/gcr           - Google Container Registry proxy
/ghcr          - GitHub Container Registry proxy
```

**2. Pre-populate Common Images:**
```bash
# Pull frequently used images to warm cache
docker pull harbor.agl.local/dockerhub/library/nginx:latest
docker pull harbor.agl.local/dockerhub/library/postgres:15
docker pull harbor.agl.local/dockerhub/library/redis:alpine
```

**3. Update Base Images:**
```dockerfile
# Update Dockerfiles to use Harbor proxy
FROM harbor.agl.local/dockerhub/library/node:18-alpine
# Instead of: FROM node:18-alpine
```

**4. Retention Policies:**
- Set retention to keep commonly used images
- Cleanup rarely used images to save space
- Balance between storage and re-pull costs

**5. Monitoring:**
- Track cache hit rate
- Monitor storage usage
- Review most pulled images
- Adjust retention based on usage

---

## Installation Workflow

See detailed installation steps in separate document: `harbor-ct182-installation-steps.md`

**Quick Overview:**
1. Create Proxmox LXC CT182 (privileged, 4 cores, 8GB RAM, 600GB storage)
2. Install Ubuntu 22.04 and updates
3. Install Docker and Docker Compose
4. Generate SSL certificates (internal CA)
5. Download Harbor 2.12.0 offline installer
6. Configure harbor.yml (hostname, HTTPS, storage, passwords)
7. Run installer with Trivy: `./install.sh --with-trivy`
8. Create systemd service for auto-start
9. Access Web UI and complete post-installation configuration
10. Create projects, robot accounts, retention policies
11. Configure backup automation
12. Test image push/pull operations

---

## CT182 Deployment Recommendation

### Recommended Configuration

**Deployment Method:** Docker Compose with offline installer
**Harbor Version:** 2.12.0 (latest stable)
**Base OS:** Ubuntu 22.04 LXC (privileged container)

### LXC Container Specifications

```
Container ID: 182
Hostname: harbor-ct182
OS Template: Ubuntu 22.04 Standard

Resources:
  CPU Cores: 4
  Memory: 8192 MB
  Swap: 4096 MB
  Root Disk: 100 GB (local-lvm)
  Data Storage: 500 GB (dedicated mount or expanded root)

Network:
  Bridge: vmbr0
  IP Address: 192.168.1.182/24 (static)
  Gateway: 192.168.1.1
  Hostname: harbor.agl.local

Features:
  nesting: 1 (enabled - required for Docker)
  keyctl: 1 (enabled - required for Docker)

Options:
  unprivileged: 0 (privileged container required)
  onboot: 1 (auto-start on Proxmox boot)
```

### Harbor Configuration

**Installer Type:** Offline installer (air-gapped capable)

**Enabled Components:**
- Core Harbor services (Portal, Core, Registry, Database, Redis)
- Trivy vulnerability scanner (`--with-trivy`)
- Notary (optional, for image signing: `--with-notary`)
- ChartMuseum (optional, for Helm charts: `--with-chartmuseum`)

**Storage Backend:** Filesystem (local)
**Database:** Internal PostgreSQL 15.12 (bundled with Harbor)
**Cache:** Internal Redis 7.2.6 (bundled with Harbor)

**SSL Configuration:**
- Internal CA (10-year root certificate)
- Harbor certificate (10-year validity)
- Subject Alternative Names: harbor.agl.local, harbor-ct182.agl.local, 192.168.1.182

### Initial Projects

**1. library (General Purpose)**
```
Access: Private
Vulnerability Scanning: Enabled
Auto-scan on push: Yes
Retention: Keep latest 20 tags
CVE Allowlist: None
Storage Quota: 100 GB
```

**2. dockerhub (Proxy Cache)**
```
Type: Proxy Cache
Registry: Docker Hub (https://hub.docker.com)
Access: Private
Vulnerability Scanning: Enabled
Speed Limit: Unlimited (or set as needed)
Storage Quota: 200 GB
```

**3. production (Production Images)**
```
Access: Private
Vulnerability Scanning: Enabled
Auto-scan on push: Yes
Prevent vulnerable images: Critical/High
Content Trust: Enabled (if using Notary)
Tag Immutability: Enabled
Retention: Keep all tags indefinitely
Storage Quota: 100 GB
```

**4. development (Development Images)**
```
Access: Private
Vulnerability Scanning: Enabled
Auto-scan on push: Yes
Retention: Keep latest 10 tags, delete >30 days
Auto-cleanup: Enabled
Storage Quota: 100 GB
```

### Backup Strategy

**Daily (Automated via cron):**
- 02:00 - PostgreSQL pg_dumpall backup
- 02:30 - Incremental files backup
- Retention: 7 days local

**Weekly (Automated):**
- Sunday 01:00 - Proxmox CT182 snapshot
- Sunday 02:00 - Full data backup to NAS
- Retention: 4 weeks local, 12 weeks NAS

**Pre-Maintenance (Manual):**
- Before upgrades: Full Proxmox snapshot
- Before config changes: Configuration backup

### Monitoring

**Built-in Harbor Metrics:**
- Prometheus endpoint: `https://harbor.agl.local/metrics`
- Dashboard: Harbor Web UI (Statistics page)

**Key Metrics to Monitor:**
- Storage usage (alert at 80%)
- Pull/push operations per day
- Vulnerability scan status
- Database size and growth
- Container health status

**Optional Integration:**
- Prometheus + Grafana for advanced metrics
- ELK/Loki for log aggregation
- Email alerts for critical events

### Future Scaling Path

**When to Consider Scaling:**
- Storage approaching 80% capacity (400GB used)
- 1000+ unique images in registry
- 100+ daily pull operations
- Multiple teams/projects requiring isolation
- High availability requirements

**Scaling Options:**
1. **Storage:** Migrate to S3/Ceph object storage
2. **Database:** Migrate to external PostgreSQL cluster
3. **Caching:** Migrate to external Redis cluster
4. **Compute:** Add CPU/RAM to CT182
5. **High Availability:** Deploy second Harbor instance with replication

---

## Integration with aglsrv1

### DNS Configuration

**Primary Hostname:** harbor.agl.local
**Alternative:** harbor-ct182.agl.local
**IP Address:** 192.168.1.182

**DNS Entry (if DNS server available):**
```
A record: harbor.agl.local → 192.168.1.182
A record: harbor-ct182.agl.local → 192.168.1.182
```

**Alternative (/etc/hosts on clients):**
```
192.168.1.182  harbor.agl.local harbor-ct182
```

### Firewall Rules

**Proxmox Firewall (if enabled):**
```
# Allow HTTPS from internal network
IN ACCEPT -p tcp -dport 443 -source 192.168.1.0/24

# Allow SSH for management
IN ACCEPT -p tcp -dport 22 -source 192.168.1.0/24

# Redirect or block HTTP
IN REJECT -p tcp -dport 80
```

**iptables (within CT182):**
```bash
# Redirect HTTP to HTTPS
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 443

# Or block HTTP entirely
iptables -A INPUT -p tcp --dport 80 -j REJECT
```

### Authentication Integration

**Option 1: Local Users (Initial Deployment)**
- Built-in Harbor user database
- Simple user/password authentication
- Suitable for small teams (<20 users)

**Option 2: LDAP/Active Directory (Recommended)**

**Configuration (if AD/LDAP available):**
```yaml
# In Web UI: Configuration → Authentication

Auth Mode: LDAP
LDAP URL: ldap://dc.agl.local:389
LDAP Search DN: CN=harborservice,CN=Users,DC=agl,DC=local
LDAP Search Password: (service account password)
LDAP Base DN: DC=agl,DC=local
LDAP Filter: (objectClass=user)
LDAP UID: sAMAccountName
LDAP Scope: Subtree
LDAP Group Base DN: DC=agl,DC=local
LDAP Group Filter: (objectClass=group)
LDAP Group GID: cn
LDAP Group Admin DN: CN=Harbor-Admins,CN=Groups,DC=agl,DC=local
```

**Benefits:**
- Centralized user management
- Single sign-on experience
- Group-based access control
- Automatic user provisioning

### Docker Client Configuration

**Trust Harbor CA Certificate:**
```bash
# On Ubuntu/Debian Docker hosts
sudo mkdir -p /etc/docker/certs.d/harbor.agl.local
sudo cp harbor.cert /etc/docker/certs.d/harbor.agl.local/
sudo cp harbor.key /etc/docker/certs.d/harbor.agl.local/
sudo cp ca.crt /etc/docker/certs.d/harbor.agl.local/
sudo systemctl restart docker
```

**System-wide CA Trust:**
```bash
# On Ubuntu/Debian
sudo cp ca.crt /usr/local/share/ca-certificates/agl-harbor-ca.crt
sudo update-ca-certificates

# On RHEL/CentOS
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/agl-harbor-ca.crt
sudo update-ca-trust
```

### Kubernetes Integration

**Create Image Pull Secret:**
```bash
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.agl.local \
  --docker-username=robot$k8s-puller \
  --docker-password=<robot-token> \
  --docker-email=admin@agl.local \
  -n default
```

**Use in Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      imagePullSecrets:
        - name: harbor-registry
      containers:
        - name: myapp
          image: harbor.agl.local/production/myapp:1.0.0
```

### Backup Integration

**Network Storage Mount:**
```bash
# In CT182, mount NAS for backups
mkdir -p /mnt/nas-backups
mount -t nfs nas.agl.local:/backups/harbor /mnt/nas-backups

# Add to /etc/fstab for persistence
nas.agl.local:/backups/harbor /mnt/nas-backups nfs defaults 0 0
```

### Monitoring Integration

**Prometheus Scrape Configuration:**
```yaml
# If Prometheus available on aglsrv1
scrape_configs:
  - job_name: 'harbor'
    static_configs:
      - targets: ['harbor.agl.local:443']
    scheme: https
    tls_config:
      ca_file: /etc/prometheus/certs/agl-ca.crt
    metrics_path: /metrics
```

### Certificate Management

**Use Same CA as Other Services:**
- Consistent trust model across aglsrv1 infrastructure
- Single CA certificate to distribute
- Simplified client configuration
- Easier troubleshooting

**Certificate Renewal Process:**
```bash
# Harbor certificates valid for 10 years
# Plan renewal 6 months before expiration
# Update certificates without downtime:

cd /opt/certs
# Generate new certificates (same process as initial)
# Copy to Harbor directory
cp harbor.crt harbor.key /opt/harbor/data/cert/
# Reload nginx
docker exec harbor-nginx nginx -s reload
```

---

## Monitoring & Performance

### Built-in Metrics

**Prometheus Endpoint:** `https://harbor.agl.local/metrics`

**Available Metrics:**
- Registry pull/push operations (count, duration)
- Image blob storage (size, count)
- Database connection pool (active, idle)
- Redis cache (hit rate, memory usage)
- Scan job status (running, completed, failed)
- Replication job status (if configured)

### Key Performance Indicators

**Storage Metrics:**
```
harbor_storage_total_bytes - Total storage used
harbor_storage_free_bytes - Free storage available
harbor_project_storage_bytes{project="library"} - Per-project storage
```

**Operation Metrics:**
```
harbor_registry_api_request_total - Total API requests
harbor_registry_api_request_duration_seconds - Request latency
harbor_image_pull_total{project="library"} - Pull operations
harbor_image_push_total{project="library"} - Push operations
```

**Scan Metrics:**
```
harbor_scan_total{status="success"} - Successful scans
harbor_scan_total{status="failed"} - Failed scans
harbor_scan_duration_seconds - Scan duration
```

### Recommended Alerts

**Critical Alerts:**
```yaml
- alert: HarborStorageAlmostFull
  expr: harbor_storage_free_bytes / harbor_storage_total_bytes < 0.2
  for: 5m
  severity: critical
  message: "Harbor storage is 80% full"

- alert: HarborDatabaseDown
  expr: up{job="harbor", container="harbor-db"} == 0
  for: 1m
  severity: critical
  message: "Harbor database container is down"

- alert: HarborScanJobsFailing
  expr: rate(harbor_scan_total{status="failed"}[5m]) > 0.5
  for: 10m
  severity: critical
  message: "Harbor scan jobs failing at high rate"
```

**Warning Alerts:**
```yaml
- alert: HarborHighPushLatency
  expr: harbor_registry_api_request_duration_seconds{method="PUT"} > 10
  for: 5m
  severity: warning
  message: "Harbor image push operations are slow"

- alert: HarborCertificateExpiringSoon
  expr: (harbor_ssl_certificate_expiry_seconds - time()) / 86400 < 30
  for: 1h
  severity: warning
  message: "Harbor SSL certificate expires in less than 30 days"
```

### Performance Optimization

**1. Database Tuning (PostgreSQL)**

**Edit `/opt/harbor-data/database/postgresql.conf`:**
```ini
# Memory settings (adjust based on available RAM)
shared_buffers = 2GB                # 25% of system RAM
effective_cache_size = 6GB          # 75% of system RAM
work_mem = 64MB                     # For complex queries
maintenance_work_mem = 512MB        # For VACUUM, CREATE INDEX

# Connection settings
max_connections = 200               # Based on expected load

# Checkpoint settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Query planner
random_page_cost = 1.1              # For SSD storage
effective_io_concurrency = 200      # For SSD storage
```

**2. Redis Tuning**

**Edit `/opt/harbor/common/config/redis/redis.conf`:**
```ini
# Memory settings
maxmemory 1gb
maxmemory-policy allkeys-lru

# Persistence (optional - can disable for pure cache)
save ""                              # Disable RDB snapshots
appendonly no                        # Disable AOF

# Performance
tcp-backlog 511
timeout 300
```

**3. Storage Optimization**

**Use SSD Storage:**
- Significantly improves image push/pull performance
- Faster database operations
- Better concurrent user experience

**Filesystem Choices:**
- **ext4:** Excellent general performance
- **XFS:** Better for large files (images)
- **ZFS:** Advanced features (snapshots, compression) with overhead

**Mount Options for Performance:**
```bash
# /etc/fstab entry for image storage
/dev/mapper/data /opt/harbor-data ext4 noatime,nodiratime,data=writeback 0 2
```

**4. Network Optimization**

**Nginx Buffer Tuning:**

**Edit `/opt/harbor/common/config/nginx/nginx.conf`:**
```nginx
# Increase buffer sizes for large images
client_body_buffer_size 256k;
client_max_body_size 0;           # No limit for large images
proxy_buffering off;              # For large file uploads
proxy_request_buffering off;
```

**5. Docker Daemon Tuning**

**/etc/docker/daemon.json:**
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
```

### Monitoring Tools

**Option 1: Harbor Built-in Dashboard**
- Web UI → Statistics
- Basic metrics and charts
- No additional setup required

**Option 2: Prometheus + Grafana**
- Comprehensive metrics collection
- Custom dashboards
- Advanced alerting
- Historical trend analysis

**Option 3: ELK Stack (Logging)**
- Centralized log aggregation
- Log search and analysis
- Audit trail visualization
- Security event monitoring

### Capacity Planning

**Storage Growth Estimation:**
```
Base install: ~8 GB
Per image: 50-500 MB average
Per project: 10-100 GB typical

Example:
- 100 images × 200 MB avg = 20 GB
- 500 images × 200 MB avg = 100 GB
- 1000 images × 200 MB avg = 200 GB

Recommendation: 500 GB allows for 1500-2000 images
```

**Performance Baselines:**
- Image push (100 MB): 5-30 seconds (depends on network)
- Image pull (100 MB): 5-20 seconds (cached: <5 seconds)
- Vulnerability scan: 30-120 seconds per image
- Web UI response: <1 second per page

---

## Common Use Cases

### Use Case 1: Private Container Registry

**Scenario:** Organization needs secure, private storage for proprietary container images.

**Configuration:**
- Create project per team/application
- Enable RBAC with team-based permissions
- Configure vulnerability scanning on all images
- Implement retention policies to manage storage

**Benefits:**
- Complete control over image lifecycle
- Security scanning before deployment
- Audit trail for compliance
- No external dependencies

### Use Case 2: Docker Hub Proxy Cache

**Scenario:** Development team frequently pulls public images, hitting Docker Hub rate limits.

**Configuration:**
- Create proxy cache project for Docker Hub
- Optionally provide Docker Hub credentials for higher limits
- Pre-populate common base images (node, python, nginx, etc.)
- Configure reasonable retention (keep frequently used images)

**Benefits:**
- Avoid Docker Hub rate limits (100/6hrs anonymous)
- Faster pulls (LAN vs internet speed)
- Offline availability of cached images
- Reduced bandwidth costs

**Example Images to Pre-cache:**
```bash
# Base images
harbor.agl.local/dockerhub/library/node:18-alpine
harbor.agl.local/dockerhub/library/python:3.11-slim
harbor.agl.local/dockerhub/library/nginx:alpine
harbor.agl.local/dockerhub/library/postgres:15
harbor.agl.local/dockerhub/library/redis:alpine

# Popular tools
harbor.agl.local/dockerhub/library/ubuntu:22.04
harbor.agl.local/dockerhub/library/alpine:latest
```

### Use Case 3: Multi-Environment Image Promotion

**Scenario:** Application images need controlled promotion through dev → staging → production environments.

**Configuration:**
- Separate projects: `/development`, `/staging`, `/production`
- Tag immutability enabled in production
- Content trust (signing) required for production
- Replication or manual promotion between projects

**Workflow:**
```
1. Build & push to /development
   harbor.agl.local/development/myapp:feature-123

2. Test in dev environment

3. Promote to staging (re-tag or replicate)
   docker pull harbor.agl.local/development/myapp:feature-123
   docker tag harbor.agl.local/development/myapp:feature-123 \
              harbor.agl.local/staging/myapp:1.2.3-rc1
   docker push harbor.agl.local/staging/myapp:1.2.3-rc1

4. Test in staging environment

5. Promote to production (with signing)
   docker pull harbor.agl.local/staging/myapp:1.2.3-rc1
   docker tag harbor.agl.local/staging/myapp:1.2.3-rc1 \
              harbor.agl.local/production/myapp:1.2.3
   export DOCKER_CONTENT_TRUST=1
   docker push harbor.agl.local/production/myapp:1.2.3
```

### Use Case 4: CI/CD Artifact Repository

**Scenario:** Jenkins/GitLab CI builds Docker images and needs secure storage with automated scanning.

**Configuration:**
- Create robot accounts for CI/CD (not user credentials)
- Project per application or per team
- Automatic vulnerability scanning on push
- Webhook notifications to CI/CD on scan completion
- Retention policies to cleanup old builds

**GitLab CI Example:**
```yaml
build:
  stage: build
  script:
    - docker login harbor.agl.local -u robot$gitlab-ci -p $HARBOR_TOKEN
    - docker build -t harbor.agl.local/library/myapp:$CI_COMMIT_SHA .
    - docker push harbor.agl.local/library/myapp:$CI_COMMIT_SHA
    - |
      # Wait for scan to complete
      while true; do
        STATUS=$(curl -s -u robot$gitlab-ci:$HARBOR_TOKEN \
          "https://harbor.agl.local/api/v2.0/projects/library/repositories/myapp/artifacts/$CI_COMMIT_SHA" \
          | jq -r '.scan_overview.scan_status')
        if [ "$STATUS" = "Success" ]; then
          break
        fi
        sleep 10
      done
    - |
      # Check for critical CVEs
      CRITICAL=$(curl -s -u robot$gitlab-ci:$HARBOR_TOKEN \
        "https://harbor.agl.local/api/v2.0/projects/library/repositories/myapp/artifacts/$CI_COMMIT_SHA" \
        | jq '.scan_overview.summary.critical // 0')
      if [ "$CRITICAL" -gt 0 ]; then
        echo "Critical vulnerabilities found!"
        exit 1
      fi
```

### Use Case 5: Kubernetes Private Registry

**Scenario:** Kubernetes cluster needs to pull images from private Harbor registry.

**Configuration:**
- Create robot account with pull-only access
- Generate Kubernetes image pull secret
- Reference secret in pod/deployment specs
- Optional: Configure Harbor as Helm chart repository

**Setup:**
```bash
# Create image pull secret
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.agl.local \
  --docker-username=robot$k8s-puller \
  --docker-password=<token> \
  --docker-email=admin@agl.local \
  -n production

# Use in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  template:
    spec:
      imagePullSecrets:
        - name: harbor-registry
      containers:
        - name: myapp
          image: harbor.agl.local/production/myapp:1.2.3
```

**Helm Chart Repository (if ChartMuseum enabled):**
```bash
# Add Harbor as Helm repo
helm repo add harbor https://harbor.agl.local/chartrepo/library \
  --username robot$helm \
  --password <token>

# Push chart to Harbor
helm push mychart-1.0.0.tgz harbor

# Install from Harbor
helm install myapp harbor/mychart
```

### Use Case 6: Multi-Registry Replication

**Scenario:** Disaster recovery or geo-distributed teams require image replication to multiple registries.

**Configuration:**
- Configure replication rules in Harbor
- Set up remote registry endpoints
- Choose push-based or pull-based replication
- Schedule replication or trigger on events

**Example Replication Rule:**
```yaml
Name: prod-to-dr
Source Registry: Local (harbor.agl.local)
Source Project: production
Destination Registry: DR Harbor (harbor-dr.agl.local)
Destination Namespace: production
Trigger Mode: Manual / Scheduled / Event-based
Filters:
  - Tag: production-*
  - Label: release=stable
Schedule: Daily at 02:00 AM
```

---

## Troubleshooting Guide

### Problem: Cannot Login to Harbor Web UI

**Symptoms:**
- Login page loads but authentication fails
- "Incorrect username or password" error

**Possible Causes & Solutions:**

1. **Wrong Credentials**
   - Default: `admin` / `Harbor12345` (or configured password)
   - Check harbor.yml for configured password
   - Solution: Reset admin password via database

2. **Database Connection Issue**
   - Check database container: `docker ps | grep harbor-db`
   - View logs: `docker logs harbor-db`
   - Solution: Restart database or entire Harbor stack

3. **LDAP Misconfiguration (if using LDAP)**
   - Check LDAP settings in Web UI
   - Test LDAP connection
   - Solution: Temporarily switch to local authentication

**Reset Admin Password:**
```bash
docker exec -it harbor-db psql -U postgres -d registry
UPDATE harbor_user SET password='<bcrypt-hash>', salt='<random-salt>' WHERE username='admin';
```

### Problem: Docker Login Fails

**Symptoms:**
```
Error response from daemon: Get "https://harbor.agl.local/v2/": x509: certificate signed by unknown authority
```

**Cause:** Docker doesn't trust Harbor's SSL certificate

**Solution:**
```bash
# Trust the CA certificate
sudo mkdir -p /etc/docker/certs.d/harbor.agl.local
sudo cp ca.crt /etc/docker/certs.d/harbor.agl.local/
sudo cp harbor.cert /etc/docker/certs.d/harbor.agl.local/
sudo cp harbor.key /etc/docker/certs.d/harbor.agl.local/
sudo systemctl restart docker
```

**Alternative (insecure, not recommended for production):**
```json
// /etc/docker/daemon.json
{
  "insecure-registries": ["harbor.agl.local"]
}
```

### Problem: Docker Push/Pull is Very Slow

**Symptoms:**
- Image push takes minutes instead of seconds
- Pull operations timeout

**Possible Causes & Solutions:**

1. **Network Bottleneck**
   - Check network connectivity: `ping harbor.agl.local`
   - Test bandwidth: `iperf3` between client and Harbor
   - Solution: Upgrade network infrastructure

2. **Storage I/O Bottleneck**
   - Check disk I/O: `iostat -x 1`
   - High %util indicates bottleneck
   - Solution: Move to SSD storage, optimize filesystem

3. **Insufficient Resources**
   - Check CPU/RAM: `top`, `free -h`
   - Harbor containers OOMKilled: `dmesg | grep oom`
   - Solution: Increase CT182 resources

4. **Large Image Layers**
   - Multi-GB layers take time to transfer
   - Solution: Optimize Dockerfile (smaller layers, multi-stage builds)

5. **PostgreSQL Slow Queries**
   - Check database logs: `docker logs harbor-db`
   - Solution: Tune PostgreSQL configuration

### Problem: Vulnerability Scanning Fails

**Symptoms:**
- Scan status shows "Error"
- Scan never completes (stuck in "Pending")

**Possible Causes & Solutions:**

1. **Trivy Database Update Failed**
   - Check Trivy logs: `docker logs harbor-trivy-adapter`
   - Error: "failed to download vulnerability DB"
   - Solution: Check internet connectivity, proxy settings

2. **Insufficient Disk Space**
   - Trivy CVE database requires space
   - Check: `df -h /opt/harbor-data`
   - Solution: Cleanup old data, expand storage

3. **Scanner Configuration Issue**
   - Check scanner configuration in Web UI
   - Verify scanner endpoint URL
   - Solution: Reconfigure scanner

**Manual Scan Trigger:**
```bash
# Via API
curl -u admin:Harbor12345 -X POST \
  "https://harbor.agl.local/api/v2.0/projects/library/repositories/myapp/artifacts/latest/scan"
```

### Problem: Harbor Containers Keep Restarting

**Symptoms:**
```
docker ps shows containers constantly restarting
Status: Restarting (1) 10 seconds ago
```

**Diagnosis:**
```bash
# Check which container is restarting
docker ps -a | grep Restarting

# View container logs
docker logs <container-name>

# Check Docker events
docker events --since '10m'
```

**Common Causes:**

1. **Out of Memory (OOM)**
   - Symptom: Container killed by OOM killer
   - Check: `dmesg | grep -i oom`
   - Solution: Increase CT182 memory allocation

2. **Database Connection Failure**
   - Symptom: Core/JobService can't connect to PostgreSQL
   - Check: Database container running, correct credentials
   - Solution: Verify database connection string in harbor.yml

3. **Port Conflict**
   - Symptom: "address already in use"
   - Check: `netstat -tulpn | grep :80`
   - Solution: Stop conflicting service or change Harbor ports

4. **Corrupted Configuration**
   - Symptom: "invalid configuration"
   - Check: Configuration logs in container
   - Solution: Restore harbor.yml from backup

### Problem: Cannot Access Harbor Web UI (Connection Refused)

**Symptoms:**
- Browser shows "Connection refused" or "Unable to connect"
- `curl https://harbor.agl.local` fails

**Diagnosis Steps:**
```bash
# 1. Check Harbor containers running
docker ps | grep harbor

# 2. Check nginx container specifically
docker ps | grep nginx

# 3. Check port listening
netstat -tulpn | grep :443

# 4. Check nginx logs
docker logs harbor-nginx

# 5. Test from localhost
curl -k https://localhost
```

**Solutions:**

1. **Nginx Container Not Running**
   - Restart Harbor: `cd /opt/harbor && docker-compose restart`

2. **Firewall Blocking**
   - Check iptables: `iptables -L -n`
   - Check Proxmox firewall for CT182

3. **Certificate Issue**
   - Check certificate validity: `openssl s_client -connect harbor.agl.local:443`
   - Regenerate if expired/invalid

4. **DNS Resolution Failure**
   - Check: `nslookup harbor.agl.local`
   - Solution: Add to /etc/hosts or fix DNS

### Problem: High Storage Usage

**Symptoms:**
- Harbor storage at 80%+ capacity
- "No space left on device" errors

**Diagnosis:**
```bash
# Overall storage
df -h /opt/harbor-data

# Per-directory breakdown
du -sh /opt/harbor-data/*

# Largest directories
du -h /opt/harbor-data | sort -rh | head -20
```

**Solutions:**

1. **Run Garbage Collection**
   ```bash
   # Set Harbor to read-only mode (Web UI)

   # Run garbage collection
   docker exec harbor-registry registry garbage-collect \
     --delete-untagged /etc/registry/config.yml

   # Disable read-only mode
   ```

2. **Implement Retention Policies**
   - Navigate to Projects → (project) → Policy
   - Example: "Keep latest 10 tags, delete untagged"
   - Run policy manually or schedule

3. **Delete Unused Projects/Images**
   - Review projects for unused images
   - Delete via Web UI or API

4. **Expand Storage**
   ```bash
   # Proxmox: Resize CT182 storage
   pct resize 182 rootfs +100G

   # Inside CT182: Resize filesystem
   resize2fs /dev/mapper/pve-vm--182--disk--0
   ```

### Problem: Replication Jobs Failing

**Symptoms:**
- Replication status shows "Failed"
- Images not appearing in destination registry

**Diagnosis:**
```bash
# Check replication job logs (Web UI)
Administration → Replications → (rule) → Executions → (execution) → Logs

# Common errors:
# - "unauthorized: authentication required"
# - "connection refused"
# - "dial tcp: lookup failed"
```

**Solutions:**

1. **Authentication Failure**
   - Verify destination registry credentials
   - Test credentials manually: `docker login <destination>`
   - Update registry endpoint with correct credentials

2. **Network Connectivity**
   - Test connection: `ping <destination-registry>`
   - Check firewall rules
   - Verify DNS resolution

3. **Certificate Issues**
   - Destination registry SSL certificate not trusted
   - Solution: Add certificate to trusted CAs or disable verification (not recommended)

4. **Tag Conflict**
   - Tag already exists in destination (if not overwriting)
   - Solution: Enable "Override" or delete conflicting tags

### Problem: LDAP Authentication Not Working

**Symptoms:**
- LDAP users cannot login
- "Invalid credentials" for known-good AD/LDAP accounts

**Diagnosis:**
```bash
# Test LDAP connection from Harbor container
docker exec -it harbor-core ldapsearch \
  -H ldap://dc.agl.local:389 \
  -D "CN=harborservice,CN=Users,DC=agl,DC=local" \
  -w <password> \
  -b "DC=agl,DC=local" \
  "(sAMAccountName=testuser)"
```

**Solutions:**

1. **Incorrect LDAP Configuration**
   - Verify all LDAP settings in Web UI
   - Test with LDAP admin tool (like Apache Directory Studio)
   - Common issues:
     - Wrong Base DN
     - Incorrect UID attribute (sAMAccountName vs uid)
     - Invalid search filter

2. **Service Account Permissions**
   - LDAP service account needs read permissions
   - Verify account not locked/expired

3. **SSL/TLS Issues**
   - If using LDAPS (ldaps://), certificate must be trusted
   - Solution: Add LDAP server certificate to Harbor

4. **Firewall Blocking**
   - LDAP port 389 or LDAPS port 636 blocked
   - Solution: Allow traffic from CT182 to LDAP server

---

## Sources

**Official Harbor Documentation:**
- https://goharbor.io/docs/2.12.0/
- https://goharbor.io/docs/2.11.0/
- https://github.com/goharbor/harbor
- https://github.com/goharbor/harbor/releases

**Deployment Guides:**
- https://medium.com/@salwan.mohamed/harbor-on-kubernetes-building-your-enterprise-container-registry-from-zero-to-production-part-1-3-122018da35a3
- https://medium.com/@angsaer.devops/building-enterprise-container-registry-infrastructure-with-harbor-a-multi-environment-journey-b805a2409fdd
- https://ikod.medium.com/deploy-harbor-container-registry-in-production-89352fb1a114

**Proxmox & LXC:**
- https://pve.proxmox.com/wiki/Linux_Container
- https://tech-tales.blog/en/posts/2025/02-install-goharbor-on-lxc/
- Community forums and deployment case studies

**CI/CD Integration:**
- https://medium.com/@tanmaybhandge/how-to-build-and-deploy-application-on-kubernetes-with-ci-cd-pipeline-using-jenkins-docker-harbor-45ade4fee59b
- https://docs.gitlab.com/user/project/integrations/harbor/
- https://v2-0.docs.kubesphere.io/docs/quick-start/pipeline-git-harbor/

**Security & Best Practices:**
- https://github.com/goharbor/harbor/security/policy
- https://anchore.com/blog/docker-security-best-practices-a-complete-guide/
- Docker security documentation

**High Availability:**
- https://goharbor.io/docs/1.10/install-config/harbor-ha-helm/
- https://github.com/goharbor/harbor-helm/blob/main/docs/High%20Availability.md
- https://blog.serdarcanb.dev/harbor-container-registry-ha-architecture-setup

**Backup & Disaster Recovery:**
- https://goharbor.io/docs/main/administration/backup-restore/
- https://tonylixu.medium.com/harbor-project-backup-and-restore-90fdc7fe1739
- PostgreSQL backup documentation

---

## Appendix: Quick Reference Commands

### Harbor Management

```bash
# Start Harbor
cd /opt/harbor && docker-compose up -d

# Stop Harbor
cd /opt/harbor && docker-compose down

# Restart Harbor
cd /opt/harbor && docker-compose restart

# Check status
docker-compose ps

# View logs
docker-compose logs -f
docker logs harbor-core
docker logs harbor-db

# Restart specific service
docker-compose restart nginx
```

### Backup Commands

```bash
# PostgreSQL backup
docker exec harbor-db pg_dumpall -U postgres | gzip > harbor-db-$(date +%Y%m%d).sql.gz

# Full data backup
tar -czf harbor-data-backup.tar.gz /opt/harbor-data

# Configuration backup
tar -czf harbor-config-backup.tar.gz /opt/harbor /opt/certs
```

### Troubleshooting Commands

```bash
# Container resource usage
docker stats

# Disk usage
df -h
du -sh /opt/harbor-data/*

# Network connectivity
curl -v https://harbor.agl.local
telnet harbor.agl.local 443

# Certificate validation
openssl s_client -connect harbor.agl.local:443 -showcerts

# Database connection
docker exec -it harbor-db psql -U postgres -d registry
```

### API Examples

```bash
# Login and get session (API v2.0)
curl -u admin:Harbor12345 -X POST https://harbor.agl.local/api/v2.0/session

# List projects
curl -u admin:Harbor12345 https://harbor.agl.local/api/v2.0/projects

# Trigger vulnerability scan
curl -u admin:Harbor12345 -X POST \
  "https://harbor.agl.local/api/v2.0/projects/library/repositories/myapp/artifacts/latest/scan"

# Check scan results
curl -u admin:Harbor12345 \
  "https://harbor.agl.local/api/v2.0/projects/library/repositories/myapp/artifacts/latest"
```

---

**END OF RESEARCH REPORT**

*For detailed installation steps, see: `harbor-ct182-installation-steps.md`*
*All research findings stored in Hive Mind memory: `hive/research/harbor-comprehensive-findings`*
