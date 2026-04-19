# Harbor Container Registry Deployment on CT183 (Archon)

> **Status**: Partial Deployment - Database Authentication Issues in LXC
> **Date**: 2025-10-29
> **Version**: Harbor v2.11.1
> **Container**: CT183 (archon) on AGLSRV1

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Deployment Details](#deployment-details)
3. [Installation Steps](#installation-steps)
4. [Current Status](#current-status)
5. [Known Issues & Workarounds](#known-issues--workarounds)
6. [Access Information](#access-information)
7. [Project Creation](#project-creation)
8. [Troubleshooting](#troubleshooting)

---

## Overview

Harbor is a container registry deployed on CT183 (archon) to provide secure Docker image storage with vulnerability scanning via Trivy.

**Target Configuration:**
- **Hostname**: 192.168.0.183
- **HTTP Port**: 5000
- **HTTPS Port**: 5443
- **Admin Password**: SecurePass2025!
- **Database Password**: HarborDB2025!
- **Projects**: dev, qa, uat, prod (to be created)
- **Features**: Trivy vulnerability scanning, RBAC, webhooks

---

## Deployment Details

### Infrastructure

| Property | Value |
|----------|-------|
| **Container** | CT183 (archon) |
| **Host** | AGLSRV1 (192.168.0.245) |
| **OS** | Ubuntu 24.04 Noble |
| **Docker** | v28.2.2 |
| **Docker Compose** | v2.37.1 |
| **Installation Dir** | /root/harbor |

### Harbor Components

| Component | Container Name | Purpose | Status |
|-----------|---------------|---------|--------|
| **nginx** | nginx | Reverse proxy | ⚠️ Waiting for core |
| **harbor-core** | harbor-core | Core API service | ⚠️ Restarting |
| **harbor-portal** | harbor-portal | Web UI | ✅ Running |
| **harbor-jobservice** | harbor-jobservice | Background jobs | ⚠️ Restarting |
| **registry** | registry | Image storage | ✅ Running |
| **registryctl** | registryctl | Registry controller | ✅ Running |
| **harbor-db** | harbor-db | PostgreSQL database | ✅ Healthy |
| **redis** | redis | Cache/sessions | ✅ Running |
| **trivy-adapter** | trivy-adapter | Vulnerability scanner | ✅ Running |
| **harbor-log** | harbor-log | Log collector | ✅ Healthy |

---

## Installation Steps

### 1. Preparation

```bash
# SSH to CT183
ssh root@192.168.0.245 'pct enter 183'

# Create harbor directory
mkdir -p /root/harbor
cd /root/harbor
```

### 2. Install Docker Compose V2

```bash
apt-get update
apt-get install -y docker-compose-v2
docker compose version  # Verify: 2.37.1+ds1-0ubuntu2~24.04.1
```

### 3. Download Harbor

```bash
# Download Harbor v2.11.1 offline installer (628MB)
curl -L -o harbor-offline-installer.tgz \
  https://github.com/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz

# Extract
tar xzf harbor-offline-installer.tgz
cd harbor
```

### 4. Generate SSL Certificates

```bash
# Create certs directory
mkdir -p /root/harbor/certs
cd /root/harbor/certs

# Generate self-signed certificate
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout harbor.key \
  -x509 -days 365 \
  -out harbor.crt \
  -subj "/C=US/ST=State/L=City/O=AGL/CN=192.168.0.183"
```

### 5. Configure Harbor

```bash
cd /root/harbor/harbor
cp harbor.yml.tmpl harbor.yml

# Edit harbor.yml
sed -i "s/hostname: reg.mydomain.com/hostname: 192.168.0.183/g" harbor.yml
sed -i "s/port: 80$/port: 5000/g" harbor.yml
sed -i "s/port: 443$/port: 5443/g" harbor.yml
sed -i "s|certificate: /your/certificate/path|certificate: /root/harbor/certs/harbor.crt|g" harbor.yml
sed -i "s|private_key: /your/private/key/path|private_key: /root/harbor/certs/harbor.key|g" harbor.yml
sed -i "s/harbor_admin_password: Harbor12345/harbor_admin_password: SecurePass2025!/g" harbor.yml
sed -i "s/password: root123/password: HarborDB2025!/g" harbor.yml
```

### 6. Fix PostgreSQL for LXC

The PostgreSQL container requires special configuration for LXC environments due to Unix socket permission issues.

**Add to docker-compose.yml** (under `harbor-db` service):

```yaml
    security_opt:
      - apparmor=unconfined
    tmpfs:
      - /run/postgresql
```

### 7. Install Harbor with Trivy

```bash
./install.sh --with-trivy
```

**Note**: ChartMuseum has been deprecated in Harbor v2.11+ and is no longer available.

### 8. Set PostgreSQL Password

After installation, set the database password manually:

```bash
docker exec harbor-db psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'HarborDB2025!';"
docker restart harbor-core harbor-jobservice
```

---

## Current Status

### ✅ Successfully Deployed

- Docker Compose V2 installed
- Harbor v2.11.1 downloaded and extracted
- SSL certificates generated
- Configuration files created
- PostgreSQL database running and healthy
- Basic Harbor services started

### ⚠️ Pending Issues

**PostgreSQL Authentication in LXC:**

Harbor-core container experiencing connection issues despite correct password configuration. This is a known issue with PostgreSQL in LXC privileged containers related to authentication methods and Unix socket permissions.

**Symptoms:**
```
[ORM] register db Ping `default`, failed to connect to `host=postgresql user=postgres database=registry`:
failed SASL auth (FATAL: password authentication failed for user "postgres" (SQLSTATE 28P01))
```

**Root Cause:**
- PostgreSQL initialized with trust authentication
- pg_hba.conf requires md5 authentication
- LXC container security restrictions interfere with proper auth setup

---

## Known Issues & Workarounds

### Issue 1: PostgreSQL Unix Sockets in LXC

**Problem**: PostgreSQL cannot create Unix sockets in `/run/postgresql` due to permission denied errors in LXC containers.

**Solution Applied**:
```yaml
# Added to docker-compose.yml under harbor-db
security_opt:
  - apparmor=unconfined
tmpfs:
  - /run/postgresql
```

### Issue 2: Harbor-Core Connection Failures

**Problem**: Harbor-core cannot connect to PostgreSQL despite correct password configuration.

**Recommended Workaround**:

Use external PostgreSQL database instead of containerized one:

1. **Deploy PostgreSQL on AGLSRV1 host** (outside LXC):
   ```bash
   # On AGLSRV1 host
   apt-get install -y postgresql-15
   sudo -u postgres psql
   CREATE USER harbor WITH PASSWORD 'HarborDB2025!';
   CREATE DATABASE registry OWNER harbor;
   \q
   ```

2. **Configure harbor.yml** to use external database:
   ```yaml
   external_database:
     harbor:
       host: 192.168.0.245
       port: 5432
       db_name: registry
       username: harbor
       password: HarborDB2025!
       ssl_mode: disable
   ```

3. **Restart Harbor**:
   ```bash
   cd /root/harbor/harbor
   docker compose down
   docker compose up -d
   ```

### Issue 3: ChartMuseum Deprecated

**Problem**: Installation flag `--with-chartmuseum` is no longer valid in Harbor v2.11+.

**Solution**: ChartMuseum has been removed. Use OCI artifacts for Helm charts instead.

---

## Access Information

### Harbor UI

- **HTTP**: http://192.168.0.183:5000
- **HTTPS**: https://192.168.0.183:5443 (when services are fully running)
- **Admin User**: admin
- **Admin Password**: SecurePass2025!

### Database

- **Host**: postgresql (internal Docker network)
- **Port**: 5432
- **Database**: registry
- **Username**: postgres
- **Password**: HarborDB2025!

### Service Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| HTTP | 5000 | TCP | Harbor web UI (HTTP) |
| HTTPS | 5443 | TCP | Harbor web UI (HTTPS) |
| Registry API | 5443 | TCP | Docker registry API |

---

## Project Creation

Once Harbor is fully operational, create the 4 required projects using the API:

```bash
# Create dev project
curl -k -u admin:SecurePass2025! -X POST \
  "https://192.168.0.183:5443/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "dev",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "high"
    }
  }'

# Create qa project
curl -k -u admin:SecurePass2025! -X POST \
  "https://192.168.0.183:5443/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "qa",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "high"
    }
  }'

# Create uat project
curl -k -u admin:SecurePass2025! -X POST \
  "https://192.168.0.183:5443/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "uat",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "medium"
    }
  }'

# Create prod project
curl -k -u admin:SecurePass2025! -X POST \
  "https://192.168.0.183:5443/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "prod",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "critical"
    }
  }'

# List all projects
curl -k -u admin:SecurePass2025! https://192.168.0.183:5443/api/v2.0/projects
```

---

## Troubleshooting

### Check Harbor Services

```bash
# Check container status
docker ps --filter name=harbor --format 'table {{.Names}}\t{{.Status}}'

# Check specific service logs
docker logs harbor-core
docker logs harbor-db
docker logs nginx

# Follow logs in real-time
docker logs -f harbor-core
```

### Database Connectivity

```bash
# Test database connection
docker exec harbor-db psql -U postgres -d registry -c "SELECT version();"

# Check database users
docker exec harbor-db psql -U postgres -c "\du"

# Check database password
docker exec harbor-db psql -U postgres -c "SELECT usename, passwd IS NOT NULL as has_password FROM pg_shadow WHERE usename = 'postgres';"

# Test connection with password
docker exec harbor-db bash -c 'PGPASSWORD=HarborDB2025! psql -U postgres -h localhost -d registry -c "SELECT 1;"'
```

### Restart Services

```bash
# Restart all Harbor services
cd /root/harbor/harbor
docker compose restart

# Restart specific service
docker restart harbor-core

# Full restart with recreation
docker compose down
docker compose up -d
```

### Check Configuration

```bash
# View harbor.yml
cat /root/harbor/harbor/harbor.yml | grep -E "^hostname:|^  port:|certificate:|private_key:|harbor_admin_password:"

# View database environment
cat /root/harbor/harbor/common/config/db/env

# View core environment
cat /root/harbor/harbor/common/config/core/env | grep POSTGRESQL
```

---

## Docker Image Push/Pull Workflow

Once Harbor is fully operational:

### 1. Configure Docker Client

```bash
# Add Harbor to Docker insecure registries (for self-signed cert)
# Edit /etc/docker/daemon.json
{
  "insecure-registries": ["192.168.0.183:5000", "192.168.0.183:5443"]
}

# Restart Docker
systemctl restart docker
```

### 2. Login to Harbor

```bash
# Login to Harbor
docker login 192.168.0.183:5443
# Username: admin
# Password: SecurePass2025!
```

### 3. Tag and Push Image

```bash
# Tag existing image
docker tag nginx:latest 192.168.0.183:5443/dev/nginx:v1.0

# Push to Harbor
docker push 192.168.0.183:5443/dev/nginx:v1.0
```

### 4. Pull Image

```bash
# Pull from Harbor
docker pull 192.168.0.183:5443/dev/nginx:v1.0
```

---

## Next Steps

1. **Resolve PostgreSQL authentication issue** by implementing external database workaround
2. **Verify all services are healthy** and accessible
3. **Create 4 projects** (dev, qa, uat, prod) via API
4. **Configure Trivy vulnerability scanning** policies
5. **Setup RBAC** and user permissions
6. **Configure webhooks** for CI/CD integration
7. **Test image push/pull** workflow
8. **Document backup/restore** procedures
9. **Configure WireGuard access** (future)
10. **Setup Tailscale access** (future)

---

## Related Documentation

- **Infrastructure Map**: `docs/INFRA.md`
- **Archon Integration**: `docs/ARCHON.md`
- **Docker in LXC**: `docs/docker-in-lxc-apparmor-solution.md`
- **Harbor Official Docs**: https://goharbor.io/docs/2.11.0/

---

## References

- **Harbor Version**: v2.11.1
- **GitHub Repository**: https://github.com/goharbor/harbor
- **Release Notes**: https://github.com/goharbor/harbor/releases/tag/v2.11.1
- **Installation Guide**: https://goharbor.io/docs/2.11.0/install-config/
- **Troubleshooting Guide**: https://goharbor.io/docs/2.11.0/install-config/troubleshoot-installation/

---

**Document Version**: 1.0
**Last Updated**: 2025-10-29
**Deployed By**: Claude Code (Harbor Registry Deployment Specialist)
**Status**: Partial deployment - PostgreSQL authentication issue pending resolution
