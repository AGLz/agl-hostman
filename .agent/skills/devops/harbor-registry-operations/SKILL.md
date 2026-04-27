---
name: harbor-registry-operations
description: "Complete Harbor container registry operations including deployment, vulnerability scanning, robot accounts, retention policies, and CI/CD integration. Use when managing container images, configuring scanners, or setting up CI/CD pipelines."
category: devops
priority: P0
tags: [harbor, registry, containers, cicd, security]
---

# Harbor Registry Operations

Complete operations guide for Harbor Container Registry - enterprise-grade container image management with vulnerability scanning, RBAC, and CI/CD integration.

## Overview

Harbor is an open source container registry that secures artifacts with policies and role-based access control (RBAC), ensures images are scanned and free of vulnerabilities, and signs images as trusted.

### Key Capabilities

- **Container Image Registry** - Docker and OCI compliant image storage
- **Vulnerability Scanning** - Trivy integration for CVE detection
- **Security Policies** - Block vulnerable images from deployment
- **Robot Accounts** - Service accounts for CI/CD pipelines
- **Retention Policies** - Automated cleanup of old images
- **Replication** - Multi-registry synchronization
- **Webhook Support** - Deployment automation triggers
- **RBAC** - Fine-grained access control

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Harbor Portal/UI                         │
├─────────────────────────────────────────────────────────────────┤
│                        Harbor API (v2.0)                        │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   Registry  │   Trivy     │   Notary    │   Database/Redis     │
│  (Storage)  │  (Scanner)  │  (Signing)  │    (Metadata)        │
└─────────────┴─────────────┴─────────────┴──────────────────────┘
```

## Deployment

### Prerequisites

```bash
# Hardware Requirements
- CPU: 2 cores minimum, 4 cores recommended
- RAM: 4GB minimum, 8GB recommended
- Storage: 100GB minimum for production

# Software Requirements
- Docker: 20.10+
- Docker Compose: 2.0+
- SSL Certificate (for production)
```

### Quick Install

```bash
# Download Harbor installer
wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
tar -xzf harbor-offline-installer-v2.10.0.tgz
cd harbor

# Generate configuration
cp harbor.yml.tmpl harbor.yml
vi harbor.yml

# Install with Notary and Trivy
sudo ./install.sh --with-trivy --with-notary
```

### Docker Compose Deployment

Use `templates/harbor-compose.yml` for containerized deployment.

```bash
# Set environment variables
export HARBOR_VERSION=v2.10.0
export HARBOR_HOST=harbor.example.com
export HARBOR_ADMIN_PASSWORD=changeme
export DATA_VOLUME=/data/harbor

# Deploy
docker-compose -f templates/harbor-compose.yml up -d
```

### Initial Configuration

```bash
# Set admin password
curl -X PUT "https://${HARBOR_HOST}/api/v2.0/users/1/password" \
  -u "admin:Harbor12345" \
  -H "Content-Type: application/json" \
  -d '{"new_password": "secure_password"}'

# Configure storage
curl -X PATCH "https://${HARBOR_HOST}/api/v2.0/configurations" \
  -u "admin:secure_password" \
  -H "Content-Type: application/json" \
  -d '{
    "storage.provider_name": "s3",
    "storage.s3.region": "us-east-1",
    "storage.s3.bucket": "harbor-registry"
  }'
```

## Project Management

Harbor projects isolate images and control access. Each project has its own RBAC policies.

### Create Project

```bash
# Create public project
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myapp",
    "public": true,
    "metadata": {
      "public": "true"
    }
  }'

# Create private project
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myapp-private",
    "public": false
  }'
```

### Configure Project

```bash
# Set vulnerability policy (block high+ severity)
curl -X PUT "https://${HARBOR_HOST}/api/v2.0/projects/myapp/retrieve_policy" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": 1,
    "type": "native",
    "scope": {
      "level": "project",
      "ref": "myapp"
    },
    "schedule": {
      "type": "Manual"
    },
    "criteria": {
      "vendor_id": "Trivy",
      "severity": "high"
    },
    "action": "prevent"
  }'

# Enable content trust (signing)
curl -X PUT "https://${HARBOR_HOST}/api/v2.0/projects/myapp" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myapp",
    "metadata": {
      "enable_content_trust": "true",
      "prevent_vul": "true"
    }
  }'
```

## Robot Accounts

Robot accounts are service accounts for CI/CD pipelines, automated deployments, and external integrations.

### Create Robot Account

```bash
# Create robot account with push/pull permissions
curl -X POST "https://${HARBOR_HOST}/api/v2.0/robots" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ci-cd-bot",
    "description": "CI/CD pipeline service account",
    "duration": 90,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "myapp",
        "access": [
          {
            "resource": "repository",
            "action": "push"
          },
          {
            "resource": "repository",
            "action": "pull"
          }
        ]
      }
    ]
  }'
```

### Robot Account Best Practices

```bash
# Use expires for temporary access
curl -X POST "https://${HARBOR_HOST}/api/v2.0/robots" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "deploy-bot",
    "duration": 7,
    "expire_at": 1704067200
  }'

# Limit to specific project
"level": "project",
"permissions": [{
  "namespace": "myapp"
}]

# Read-only for staging
"access": [{
  "resource": "repository",
  "action": "pull"
}]
```

### Using Robot Accounts

```bash
# Login with robot account
docker login harbor.example.com -u robot$ci-cd-bot -p <secret>

# Push image
docker push harbor.example.com/myapp/api:v1.0.0

# Pull image
docker pull harbor.example.com/myapp/api:v1.0.0
```

## Vulnerability Scanning

Harbor integrates with Trivy for comprehensive vulnerability scanning.

### Scanner Configuration

```bash
# Check scanner status
curl -X GET "https://${HARBOR_HOST}/api/v2.0/scanners" \
  -u "admin:password"

# Configure Trivy scanner
curl -X POST "https://${HARBOR_HOST}/api/v2.0/scanners" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Trivy",
    "description": "Trivy vulnerability scanner",
    "url": "http://trivy:8080",
    "adapter": "trivy",
    "auth": "",
    "skip_cert_verify": false
  }'
```

### Manual Scanning

```bash
# Scan specific artifact
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects/myapp/repositories/api/artifacts/v1.0.0/scan" \
  -u "admin:password"

# Scan all images in project
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects/myapp/scanall" \
  -u "admin:password"
```

### Vulnerability Reports

```bash
# Get scan results
curl -X GET "https://${HARBOR_HOST}/api/v2.0/projects/myapp/repositories/api/artifacts/v1.0.0?with_scan_overview=true" \
  -u "admin:password" | jq '.scan_overview'

# Filter by severity
curl -X GET "https://${HARBOR_HOST}/api/v2.0/projects/myapp/repositories/api/artifacts/v1.0.0?with_scan_overview=true" \
  -u "admin:password" | jq '.scan_overview["application/vnd.security.vulnerability.report; version=1.1"] | .vulnerabilities[] | select(.severity == "Critical")'
```

### Automated Scanning

Configure scan triggers in project settings:
- **On Push** - Automatically scan when image is pushed
- **Scheduled** - Daily/weekly scans of all images
- **Manual** - Trigger scans via API or UI

## Retention Policies

Automatically clean up old images to save storage and maintain compliance.

### Create Retention Policy

```bash
# Keep last 10 tags, purge older daily
curl -X POST "https://${HARBOR_HOST}/api/v2.0/retentions" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "algorithm": "or",
    "rules": [
      {
        "disabled": false,
        "action": "retain",
        "scope_selectors": {
          "repository": [
            {
              "kind": "doublestar",
              "decoration": "repoMatches",
              "pattern": "**"
            }
          ]
        },
        "tag_selectors": [
          {
            "kind": "doublestar",
            "decoration": "matches",
            "pattern": "**"
          }
        ],
        "params": {
          "latestPushedK": 10
        },
        "templates": [
          {
            "n_days_since_last_push": 30,
            "latest_pushed_k": 10
          }
        ]
      }
    ],
    "trigger": {
      "kind": "Schedule",
      "settings": {
        "cron": "0 0 * * *"
      },
      "reference": "cron"
    },
    "scope": {
      "level": "project",
      "ref": 1
    }
  }'
```

### Retention Policy Examples

```bash
# Keep last 5 tags per repository
"params": {
  "latestPushedK": 5
}

# Delete images older than 90 days
"templates": [{
  "n_days_since_last_pull": 90
}]

# Keep all production tags (prod-*)
"tag_selectors": [{
  "kind": "doublestar",
  "decoration": "matches",
  "pattern": "prod-*",
  "exemption": true
}]
```

### Execute Retention

```bash
# Run retention policy manually
curl -X POST "https://${HARBOR_HOST}/api/v2.0/retentions/executions" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": false}'

# View retention execution history
curl -X GET "https://${HARBOR_HOST}/api/v2.0/retentions/executions" \
  -u "admin:password"
```

## CI/CD Integration

### GitHub Actions

```yaml
# See templates/harbor-cicd-config.yml
name: Build and Push to Harbor

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to Harbor
        run: |
          docker login harbor.example.com \
            -u ${{ secrets.HARBOR_USERNAME }} \
            -p ${{ secrets.HARBOR_PASSWORD }}

      - name: Build image
        run: |
          docker build -t harbor.example.com/myapp/api:${{ github.sha }} .

      - name: Push to Harbor
        run: |
          docker push harbor.example.com/myapp/api:${{ github.sha }}

      - name: Scan image
        run: |
          curl -X POST "https://harbor.example.com/api/v2.0/projects/myapp/repositories/api/artifacts/${{ github.sha }}/scan" \
            -u "${{ secrets.HARBOR_USERNAME }}:${{ secrets.HARBOR_PASSWORD }}"
```

### Docker Login

```bash
# Command line
docker login harbor.example.com -u robot$ci-cd-bot -p <token>

# Kubernetes secret
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.example.com \
  --docker-username=robot$ci-cd-bot \
  --docker-password=<token>
```

### CI Variables

```bash
# Required environment variables
export HARBOR_URL="harbor.example.com"
export HARBOR_PROJECT="myapp"
export HARBOR_USERNAME="robot$ci-cd-bot"
export HARBOR_PASSWORD="secret_token"
export IMAGE_TAG="${CI_COMMIT_SHA}"
export IMAGE_NAME="${HARBOR_URL}/${HARBOR_PROJECT}/api:${IMAGE_TAG}"

# Build and push
docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

# Wait for scan
sleep 30

# Check scan status
SCAN_RESULT=$(curl -s -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
  "https://${HARBOR_URL}/api/v2.0/projects/${HARBOR_PROJECT}/repositories/api/artifacts/${IMAGE_TAG}?with_scan_overview=true" | \
  jq -r '.scan_overview."application/vnd.security.vulnerability.report; version=1.1".scan_status')

if [ "$SCAN_RESULT" != "Success" ]; then
  echo "Vulnerability scan failed"
  exit 1
fi
```

## Webhook Configuration

Configure webhooks to trigger deployments, notifications, or custom actions.

### Create Webhook

```bash
# HTTP webhook for image push events
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects/myapp/webhooks/policies" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Deploy on Push",
    "description": "Trigger deployment when new image is pushed",
    "project_id": 1,
    "targets": [
      {
        "type": "http",
        "address": "https://deploy.example.com/harbor-webhook",
        "auth_header": "Bearer ${DEPLOY_TOKEN}",
        "skip_cert_verify": false
      }
    ],
    "event_types": [
      "PUSH_ARTIFACT",
      "SCAN_FAILED"
    ],
    "enabled": true
  }'
```

### Webhook Events

```bash
# Available event types
"PUSH_ARTIFACT" - Image pushed to registry
"PULL_ARTIFACT" - Image pulled from registry
"DELETE_ARTIFACT" - Image deleted
"SCANNING_COMPLETED" - Vulnerability scan completed
"SCAN_FAILED" - Scan failed
"POST_QUOTA_EXCEED" - Quota exceeded
"QUOTA_EXCEED" - About to exceed quota
```

### Webhook Payload

```json
{
  "type": "PUSH_ARTIFACT",
  "occur_at": 1672531200,
  "operator": "robot$ci-cd-bot",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:abc123...",
        "tag": "v1.0.0",
        "resource_url": "harbor.example.com/myapp/api:v1.0.0"
      }
    ],
    "repository": {
      "name": "api",
      "namespace": "myapp",
      "full_name": "myapp/api"
    }
  }
}
```

## Troubleshooting

### Common Issues

#### Cannot login to Harbor

```bash
# Check Harbor is running
docker ps | grep harbor

# Check Harbor logs
docker-compose -f harbor-compose.yml logs -f core

# Verify credentials
curl -u "admin:password" "https://harbor.example.com/api/v2.0/users/current"

# Reset admin password
docker-compose -f harbor-compose.yml exec core /./reset_admin_pwd.sh
```

#### Vulnerability scan not working

```bash
# Check Trivy scanner status
docker ps | grep trivy

# View scanner logs
docker-compose -f harbor-compose.yml logs -f trivy-adapter

# Reconfigure scanner
curl -X PUT "https://${HARBOR_HOST}/api/v2.0/scanners/1" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{"url": "http://trivy:8080"}'

# Trigger manual scan
curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects/myapp/repositories/api/artifacts/v1.0.0/scan" \
  -u "admin:password"
```

#### Storage full

```bash
# Check disk usage
df -h /data/harbor

# Run retention policy manually
curl -X POST "https://${HARBOR_HOST}/api/v2.0/retentions/1/executions" \
  -u "admin:password"

# Clean garbage collection
docker-compose -f harbor-compose.yml exec registry \
  bin/registry garbage-collect /etc/registry/config.yml

# Restart registry
docker-compose -f harbor-compose.yml restart registry
```

#### Robot account authentication failed

```bash
# List robot accounts
curl -X GET "https://${HARBOR_HOST}/api/v2.0/robots" \
  -u "admin:password"

# Check expiration
curl -X GET "https://${HARBOR_HOST}/api/v2.0/robots/1" \
  -u "admin:password" | jq '.expires_at'

# Regenerate secret
curl -X PATCH "https://${HARBOR_HOST}/api/v2.0/robots/1" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{"secret": null}'

# Update permissions
curl -X PUT "https://${HARBOR_HOST}/api/v2.0/robots/1" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{
    "permissions": [{
      "kind": "project",
      "namespace": "myapp",
      "access": [{"resource": "repository", "action": "pull"}]
    }]
  }'
```

#### Image pull slow

```bash
# Check registry health
curl -X GET "https://${HARBOR_HOST}/api/v2.0/systeminfo" \
  -u "admin:password" | jq '.storage.status'

# Configure cache
docker-compose -f harbor-compose.yml exec registry \
  vi /etc/registry/config.yml
# Add:
# cache:
#   blobdescriptor: redis
#   redis:
#     addr: redis:6379
#     password: <password>
#     poolsize: 100

# Restart registry
docker-compose -f harbor-compose.yml restart registry
```

### Performance Tuning

```bash
# Increase worker threads
# In harbor.yml
worker_pool:
  workers: 50

# Optimize Trivy scanning
# In trivy-adapter.env
SCANNER_STORE_REDIS_URL=redis://redis:6379
SCANNER_JOB_QUEUE_REDIS_URL=redis://redis:6379
SCANNER_TRIVY_CACHE_DIR=/cache

# Enable CDN for image pull
# Configure cloud storage backend
storage:
  provider: s3
  s3:
    region: us-east-1
    bucket: harbor-registry
    cdn: https://cdn.example.com
```

### Monitoring Queries

```bash
# Monitor API health
watch -n 5 'curl -s -u "admin:password" "https://harbor.example.com/api/v2.0/systeminfo" | jq .status'

# Monitor recent pushes
curl -s -u "admin:password" "https://harbor.example.com/api/v2.0/projects/myapp/repositories/api/artifacts?page_size=20" | \
  jq '.[] | {tag: .tags[0].name, push_time: .push_time}'

# Monitor scan results
curl -s -u "admin:password" "https://harbor.example.com/api/v2.0/projects/myapp/repositories/api/artifacts?with_scan_overview=true" | \
  jq '.[] | {tag: .tags[0].name, severity: .scan_overoverview."application/vnd.security.vulnerability.report; version=1.1".severity}'

# Monitor storage usage
docker exec harbor-db psql -U postgres -d registry -c "SELECT SUM(size) / 1024 / 1024 / 1024 AS gb FROM blob;"
```

### Log Analysis

```bash
# View error logs
docker-compose -f harbor-compose.yml logs --tail=100 core | grep ERROR

# View scan logs
docker-compose -f harbor-compose.yml logs --tail=100 trivy-adapter | grep -i scan

# View authentication logs
docker-compose -f harbor-compose.yml logs --tail=100 core | grep -i auth

# Export all logs
docker-compose -f harbor-compose.yml logs > harbor-debug.log
```

## Best Practices

1. **Always use HTTPS in production** - Configure SSL certificates
2. **Enable vulnerability scanning** - Block high/critical CVEs
3. **Implement retention policies** - Auto-cleanup old images
4. **Use robot accounts for CI/CD** - Never use admin credentials
5. **Set up webhooks** - Automate deployments on image push
6. **Monitor storage** - Regular garbage collection
7. **Backup database** - Preserve metadata and RBAC
8. **Test disaster recovery** - Practice Harbor reinstallation
9. **Use content trust** - Sign all production images
10. **Audit access logs** - Track who pulled what images

## Security Checklist

- [ ] Change default admin password
- [ ] Enable HTTPS with valid certificates
- [ ] Configure vulnerability scanner
- [ ] Set up blocking policies for critical CVEs
- [ ] Create robot accounts with minimal permissions
- [ ] Enable content trust (image signing)
- [ ] Set up retention policies
- [ ] Configure webhooks for security events
- [ ] Enable audit logging
- [ ] Regular security updates
- [ ] Backup encryption keys
- [ ] Network isolation (VLAN/firewall)
- [ ] RBAC review quarterly

## Additional Resources

- [Harbor API Documentation](https://goharbor.io/docs/2.10.0/swagger-api-definitions/)
- [Harbor Installation Guide](https://goharbor.io/docs/2.10.0/install-config/)
- [Trivy Scanner Docs](https://aquasecurity.github.io/trivy/)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
