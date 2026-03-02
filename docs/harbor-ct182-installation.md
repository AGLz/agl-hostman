# Harbor CT182 Installation Guide

Complete guide for deploying Harbor enterprise container registry on aglsrv1 using Proxmox LXC container CT182.

## Overview

Harbor is an open-source, enterprise-class container registry that extends Docker Distribution by adding functionality such as security, identity management, and workflow automation. This guide covers the complete installation and configuration process.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Proxmox Host (aglsrv1)                 │
│  ┌───────────────────────────────────────────────┐  │
│  │         Harbor CT182 (192.168.1.182)          │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │          Harbor Core Services           │  │  │
│  │  │  • Nginx (Reverse Proxy)                │  │  │
│  │  │  • Core API                             │  │  │
│  │  │  • Job Service                          │  │  │
│  │  │  • Registry (Distribution)              │  │  │
│  │  │  • PostgreSQL (Database)                │  │  │
│  │  │  • Redis (Cache)                        │  │  │
│  │  │  • Trivy (Vulnerability Scanner)        │  │  │
│  │  │  • Chart Museum (Helm Charts)           │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

- Proxmox VE 7.0 or later
- Available IP: 192.168.1.182
- Minimum requirements:
  - 4 CPU cores
  - 8GB RAM
  - 100GB storage
  - Network connectivity

## Installation Steps

### Phase 1: Container Creation

1. **Run container creation script:**
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182
chmod +x *.sh
./create-container.sh
```

2. **Verify container creation:**
```bash
pct status 182
pct list | grep 182
```

### Phase 2: Docker Installation

1. **Install Docker and Docker Compose:**
```bash
./setup-docker.sh
```

2. **Verify Docker installation:**
```bash
pct exec 182 -- docker --version
pct exec 182 -- docker-compose --version
pct exec 182 -- docker ps
```

### Phase 3: Network Configuration

1. **Configure network settings:**
```bash
./configure-network.sh
```

2. **Restart container:**
```bash
pct reboot 182
```

3. **Verify network configuration:**
```bash
pct exec 182 -- ip addr show
pct exec 182 -- ping -c 3 google.com
```

### Phase 4: Harbor Installation

1. **Install Harbor:**
```bash
./install-harbor.sh
```

This will:
- Download Harbor v2.11.1
- Generate SSL certificates
- Configure Harbor
- Install with Trivy scanner and Chart Museum
- Start all services

2. **Verify Harbor installation:**
```bash
pct exec 182 -- docker ps
pct exec 182 -- curl -k https://192.168.1.182/api/v2.0/health
```

### Phase 5: Harbor Configuration

1. **Configure Harbor projects and policies:**
```bash
./configure-harbor.sh
```

This creates:
- Library project (public)
- Development project (private, auto-scan)
- Production project (private, content trust)
- Robot accounts for CI/CD
- Vulnerability scanning policies
- Garbage collection schedule
- Retention policies

2. **Access Harbor UI:**
```
URL: https://192.168.1.182
Username: admin
Password: [as set during installation]
```

## Post-Installation Configuration

### 1. SSL Certificate Configuration

For production use, replace self-signed certificates:

```bash
# Option A: Let's Encrypt (recommended)
pct exec 182 -- apt-get install -y certbot
pct exec 182 -- certbot certonly --standalone -d harbor.yourdomain.com

# Copy certificates to Harbor
pct exec 182 -- cp /etc/letsencrypt/live/harbor.yourdomain.com/fullchain.pem /opt/harbor/ssl/harbor.crt
pct exec 182 -- cp /etc/letsencrypt/live/harbor.yourdomain.com/privkey.pem /opt/harbor/ssl/harbor.key

# Update harbor.yml
pct exec 182 -- sed -i 's|certificate:.*|certificate: /opt/harbor/ssl/harbor.crt|' /opt/harbor/harbor.yml
pct exec 182 -- sed -i 's|private_key:.*|private_key: /opt/harbor/ssl/harbor.key|' /opt/harbor/harbor.yml

# Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down && docker-compose up -d"
```

### 2. User Management

**Create users via UI:**
1. Login to Harbor
2. Go to Administration → Users
3. Click "+ NEW USER"
4. Fill in details and assign to projects

**Via API:**
```bash
curl -k -X POST "https://192.168.1.182/api/v2.0/users" \
  -u "admin:yourpassword" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "developer",
    "email": "dev@example.com",
    "realname": "Developer",
    "password": "SecurePass123!",
    "comment": "Development team member"
  }'
```

### 3. Project Configuration

**Add members to projects:**
```bash
# Get user ID
USER_ID=$(curl -k -s -u "admin:yourpassword" \
  "https://192.168.1.182/api/v2.0/users/search?username=developer" | jq -r '.[0].user_id')

# Add user to project as developer
curl -k -X POST "https://192.168.1.182/api/v2.0/projects/development/members" \
  -u "admin:yourpassword" \
  -H "Content-Type: application/json" \
  -d "{
    \"role_id\": 2,
    \"member_user\": {
      \"user_id\": $USER_ID
    }
  }"
```

**Role IDs:**
- 1: Project Admin
- 2: Developer
- 3: Guest
- 4: Maintainer

### 4. Replication Setup

For disaster recovery or multi-site deployments:

1. Go to Administration → Registries
2. Click "+ NEW ENDPOINT"
3. Configure destination registry
4. Create replication rule in Administration → Replications

### 5. Vulnerability Scanning Configuration

**Configure scanning policies:**
```bash
# Enable automatic scanning for new pushes
curl -k -X PUT "https://192.168.1.182/api/v2.0/projects/production" \
  -u "admin:yourpassword" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {
      "auto_scan": "true",
      "severity": "high",
      "prevent_vul": "true"
    }
  }'
```

**Trigger manual scan:**
```bash
curl -k -X POST "https://192.168.1.182/api/v2.0/projects/library/repositories/myimage/artifacts/latest/scan" \
  -u "admin:yourpassword"
```

## Docker Client Configuration

### Linux/Mac Clients

```bash
# Trust Harbor certificate
sudo mkdir -p /etc/docker/certs.d/192.168.1.182
sudo scp root@192.168.1.182:/opt/harbor/ssl/harbor.crt \
  /etc/docker/certs.d/192.168.1.182/ca.crt

# Login
docker login 192.168.1.182

# Tag and push
docker tag myapp:latest 192.168.1.182/library/myapp:v1.0
docker push 192.168.1.182/library/myapp:v1.0

# Pull
docker pull 192.168.1.182/library/myapp:v1.0
```

### Windows Clients

```powershell
# Trust certificate
# 1. Copy harbor.crt from server
# 2. Import to Trusted Root Certification Authorities

# Or via Docker Desktop settings:
# Settings → Docker Engine → Edit daemon.json
{
  "insecure-registries": ["192.168.1.182"]
}

# Login
docker login 192.168.1.182
```

## CI/CD Integration

### GitLab CI Example

```yaml
# .gitlab-ci.yml
variables:
  HARBOR_REGISTRY: "192.168.1.182"
  HARBOR_PROJECT: "library"
  IMAGE_NAME: "$HARBOR_REGISTRY/$HARBOR_PROJECT/myapp"

before_script:
  - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_REGISTRY

build:
  stage: build
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
    - docker push $IMAGE_NAME:latest
```

### GitHub Actions Example

```yaml
# .github/workflows/build.yml
name: Build and Push to Harbor

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to Harbor
        uses: docker/login-action@v2
        with:
          registry: 192.168.1.182
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            192.168.1.182/library/myapp:latest
            192.168.1.182/library/myapp:${{ github.sha }}
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any

    environment {
        HARBOR_REGISTRY = '192.168.1.182'
        HARBOR_CREDENTIALS = credentials('harbor-credentials')
    }

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("${HARBOR_REGISTRY}/library/myapp:${env.BUILD_NUMBER}")
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry("https://${HARBOR_REGISTRY}", 'harbor-credentials') {
                        docker.image("${HARBOR_REGISTRY}/library/myapp:${env.BUILD_NUMBER}").push()
                        docker.image("${HARBOR_REGISTRY}/library/myapp:${env.BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
    }
}
```

## Maintenance

### Daily Tasks
```bash
# Health check
./maintenance.sh health

# Backup
./backup-restore.sh backup
```

### Weekly Tasks
```bash
# Full maintenance
./maintenance.sh all

# Cleanup old backups
./backup-restore.sh cleanup
```

### Monthly Tasks
```bash
# Deep maintenance
./maintenance.sh full
```

### Scheduled Maintenance

Add to crontab:
```bash
pct exec 182 -- crontab -e

# Add these lines:
0 2 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh health
0 3 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/backup-restore.sh backup
0 4 * * 0 /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh all
0 5 * * 0 /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/backup-restore.sh cleanup
0 6 1 * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/harbor-ct182/maintenance.sh full
```

## Monitoring

### Harbor Metrics

Access Prometheus metrics:
```bash
curl -k https://192.168.1.182/metrics
```

### Grafana Dashboard

Import Harbor Grafana dashboard:
1. Dashboard ID: 13865
2. Prometheus datasource: Harbor metrics endpoint

### Log Monitoring

```bash
# View Harbor logs
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose logs -f"

# View specific service
pct exec 182 -- docker logs harbor-core -f
```

## Backup and Restore

### Create Backup
```bash
./backup-restore.sh backup
```

### Restore from Backup
```bash
# List available backups
./backup-restore.sh list

# Restore specific backup
./backup-restore.sh restore /var/backups/harbor/harbor-backup-TIMESTAMP.tar.gz
```

### Automated Backups

Backups include:
- PostgreSQL database
- Registry data
- Configuration files
- SSL certificates
- Trivy vulnerability database

## Troubleshooting

### Harbor services not starting

```bash
# Check all services
pct exec 182 -- docker ps -a

# Check specific service logs
pct exec 182 -- docker logs harbor-core
pct exec 182 -- docker logs harbor-db

# Restart Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down && docker-compose up -d"
```

### Cannot push/pull images

```bash
# Check firewall
pct exec 182 -- iptables -L -n | grep 443

# Test Harbor API
curl -k https://192.168.1.182/api/v2.0/health

# Verify Docker client certificate
ls -la /etc/docker/certs.d/192.168.1.182/
```

### Database connection issues

```bash
# Check PostgreSQL
pct exec 182 -- docker exec harbor-db psql -U postgres -c "SELECT version();"

# Check database connections
pct exec 182 -- docker exec harbor-db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

### Disk space issues

```bash
# Check disk usage
pct exec 182 -- df -h

# Run garbage collection
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose exec -T registry registry garbage-collect /etc/registry/config.yml"

# Clean Docker system
./maintenance.sh cleanup --full
```

## Security Best Practices

1. **Change default passwords** immediately
2. **Use strong passwords** for all accounts
3. **Enable HTTPS** with valid certificates
4. **Configure LDAP/AD** for centralized authentication
5. **Enable content trust** for production projects
6. **Configure vulnerability** scanning policies
7. **Regular security audits** of images
8. **Implement RBAC** properly
9. **Regular backups** to secure location
10. **Keep Harbor updated** to latest version

## Performance Optimization

### For Production Environments

1. **Increase resources:**
   - 16GB RAM minimum
   - 200GB+ storage
   - SSD/NVMe for better I/O

2. **External databases:**
   - Use dedicated PostgreSQL server
   - Use Redis cluster for caching

3. **Storage optimization:**
   - Use S3-compatible object storage
   - Enable storage driver optimization

4. **Network optimization:**
   - Use CDN for image distribution
   - Enable HTTP/2 and compression

## Upgrading Harbor

```bash
# Backup current installation
./backup-restore.sh backup

# Download new version
VERSION="v2.12.0"
pct exec 182 -- wget https://github.com/goharbor/harbor/releases/download/$VERSION/harbor-offline-installer-$VERSION.tgz

# Stop Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose down"

# Extract new version
pct exec 182 -- tar xzvf harbor-offline-installer-$VERSION.tgz -C /tmp

# Migrate database
pct exec 182 -- /tmp/harbor/prepare --with-trivy --with-chartmuseum

# Start Harbor
pct exec 182 -- bash -c "cd /opt/harbor && docker-compose up -d"
```

## API Reference

### Authentication

```bash
# Get authentication token
TOKEN=$(curl -k -s -X POST "https://192.168.1.182/api/v2.0/users/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"yourpassword"}' | jq -r '.token')
```

### Common API Operations

```bash
# List projects
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.1.182/api/v2.0/projects

# List repositories in project
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.1.182/api/v2.0/projects/library/repositories

# Get artifact details
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.1.182/api/v2.0/projects/library/repositories/myapp/artifacts/v1.0

# Scan artifact
curl -k -X POST -H "Authorization: Bearer $TOKEN" \
  https://192.168.1.182/api/v2.0/projects/library/repositories/myapp/artifacts/v1.0/scan
```

## Support and Resources

- **Harbor Documentation:** https://goharbor.io/docs/
- **GitHub Repository:** https://github.com/goharbor/harbor
- **Community Slack:** https://cloud-native.slack.com/messages/harbor
- **Security Advisories:** https://github.com/goharbor/harbor/security/advisories

## License

Harbor is licensed under Apache License 2.0.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-22
**Author:** AGL Infrastructure Team
