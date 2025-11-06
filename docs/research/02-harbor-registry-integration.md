# Harbor Container Registry Integration Analysis

> **Research Date**: 2025-10-28
> **Status**: Enterprise Registry Strategy
> **Focus**: Security, multi-environment workflows, and Dokploy integration

---

## Executive Summary

Harbor is a **CNCF Graduated** open-source container registry that provides enterprise-grade security, policy management, and replication capabilities. As a trusted cloud-native registry project, Harbor secures artifacts with policies and role-based access control, ensures images are scanned and free from vulnerabilities, and signs images as trusted.

**Key Statistics**:
- CNCF Graduated Project (highest maturity level)
- Used by enterprises worldwide
- RESTful API for easy integration
- Multi-cloud and Kubernetes-native

---

## Core Architecture

### Harbor Components

```
┌─────────────────────────────────────────────────────────┐
│                Harbor Registry Platform                  │
├─────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │  Web UI │  │   API   │  │  Auth   │  │  RBAC   │   │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ Image Scanning  │  │  Signature   │  │ Retention │ │
│  │  (Trivy/Clair)  │  │  (Notary)    │  │  Policies │ │
│  └─────────────────┘  └──────────────┘  └───────────┘ │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │         Registry Storage (S3/MinIO/Local)       │   │
│  └─────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │        Replication to Remote Registries         │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Integration Points

**Upstream Systems**:
- CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins)
- Developer workstations (Docker CLI)
- Build systems (Docker, Buildah, Kaniko)

**Downstream Consumers**:
- Kubernetes clusters (image pulls)
- Dokploy deployment platform
- Docker Swarm services
- Container runtimes (containerd, CRI-O)

---

## Enterprise Security Features

### 1. Vulnerability Scanning

**Built-in Scanners**:
- **Trivy** (recommended): Fast, accurate CVE detection
- **Clair**: Static vulnerability analysis
- Integration with Anchore Enterprise for advanced scanning

**Scanning Policies**:
```yaml
scan_policy:
  # Automatic scanning on push
  scan_on_push: true

  # Prevent vulnerable images from being pulled
  prevent_vulnerable_images: true

  # Severity threshold
  vulnerability_severity: "HIGH"

  # CVE whitelist for known false positives
  cve_whitelist:
    - "CVE-2024-12345"  # Example: fixed in upstream
```

**Best Practices**:
- ✅ Enable automatic scanning on image push
- ✅ Set severity thresholds (block HIGH and CRITICAL)
- ⚠️ **Caution**: Don't block pulls in production (may cause service disruption)
- ✅ Use scanning results in CI/CD quality gates
- ✅ Regular CVE database updates

### 2. Image Signing (Content Trust)

**Docker Content Trust with Notary**:
```bash
# Enable content trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://harbor.example.com:4443

# Push signed image
docker push harbor.example.com/prod/app:v1.0.0
# Signature automatically generated and stored

# Pull verification
docker pull harbor.example.com/prod/app:v1.0.0
# Signature verified before pull completes
```

**Policy Enforcement**:
- Require signatures for production projects
- Allow unsigned images in development
- Audit trail for all signature operations
- Role-based signing permissions

### 3. Access Control (RBAC)

**Project-Level Roles**:

| Role | Permissions |
|------|------------|
| **Project Admin** | Full control (push, pull, delete, scan, replicate) |
| **Developer** | Push and pull images |
| **Guest** | Pull images only |
| **Limited Guest** | Pull specific tagged images only |

**Robot Accounts** (Recommended for Automation):
```bash
# Create robot account for Dokploy
# Project: agl-hostman-prod
# Name: robot$dokploy-deployer
# Permissions: Pull only
# Expiration: 90 days (auto-rotate)

# Use in Dokploy registry configuration
username: robot$dokploy-deployer
password: <generated-token>
```

**Identity Integration**:
- OIDC (Okta, Auth0, Keycloak)
- Active Directory / LDAP
- OAuth 2.0 providers
- Local user database

### 4. Audit Logging

**Tracked Operations**:
- Image push/pull events
- Project access changes
- Policy modifications
- Replication activities
- Scan results
- User authentication attempts

**Compliance Benefits**:
- SOC 2 audit trail requirements
- GDPR data access logging
- Container supply chain transparency
- Security incident investigation

---

## Multi-Environment Workflow Design

### Project-Based Environment Isolation

**Recommended Structure**:
```
Harbor Projects:
├── agl-hostman-dev       (Development builds)
│   ├── hostman:dev-latest
│   ├── hostman:dev-20251028-abc123
│   └── hostman:dev-feature-xyz
│
├── agl-hostman-qa        (QA validated images)
│   ├── hostman:qa-v1.2.3
│   └── hostman:qa-20251028-abc123
│
├── agl-hostman-uat       (User acceptance testing)
│   ├── hostman:uat-v1.2.3
│   └── hostman:uat-rc1
│
└── agl-hostman-prod      (Production releases)
    ├── hostman:v1.2.3    (Semantic version)
    ├── hostman:stable    (Current production)
    └── hostman:v1.2.2    (Previous version for rollback)
```

**Project Configuration**:

**Development Project**:
```yaml
project: agl-hostman-dev
access: Public (within organization)
vulnerability_scanning: Enabled
prevent_vulnerable_images: false  # Allow for rapid iteration
auto_scan: true
retention_policy:
  keep_most_recent: 10
  keep_days: 30
```

**QA Project**:
```yaml
project: agl-hostman-qa
access: Private (QA team only)
vulnerability_scanning: Enabled
prevent_vulnerable_images: true   # Block HIGH and CRITICAL
severity_threshold: HIGH
auto_scan: true
retention_policy:
  keep_most_recent: 20
  keep_days: 60
```

**UAT Project**:
```yaml
project: agl-hostman-uat
access: Private (stakeholders only)
vulnerability_scanning: Enabled
prevent_vulnerable_images: true
content_trust: Recommended
severity_threshold: HIGH
retention_policy:
  keep_most_recent: 15
  keep_days: 90
```

**Production Project**:
```yaml
project: agl-hostman-prod
access: Private (ops team only)
vulnerability_scanning: Enabled
prevent_vulnerable_images: true
content_trust: Required          # Enforce signed images
severity_threshold: CRITICAL
immutable_tags: true             # Prevent tag overwriting
retention_policy:
  keep_all_versions: true        # Never auto-delete
  manual_cleanup: true           # Explicit deletion only
```

---

## Image Promotion Workflow

### Automated Promotion Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                  CI/CD Pipeline Flow                     │
└─────────────────────────────────────────────────────────┘

Step 1: Build & Push to Dev
┌─────────────────────────────┐
│  GitHub Actions (dev branch)│
│  1. Build image             │
│  2. Tag: dev-${GIT_SHA}     │
│  3. Push to harbor/dev      │
│  4. Scan automatically      │
└─────────────────────────────┘
           │
           ▼
Step 2: Promote to QA (Manual Trigger or Auto on Success)
┌─────────────────────────────┐
│  Promotion Workflow         │
│  1. Pull from dev project   │
│  2. Re-tag: qa-v${VERSION}  │
│  3. Push to harbor/qa       │
│  4. Verify scan results     │
│  5. Notify QA team          │
└─────────────────────────────┘
           │
           ▼
Step 3: Promote to UAT (After QA Approval)
┌─────────────────────────────┐
│  Stakeholder Validation     │
│  1. Pull from qa project    │
│  2. Re-tag: uat-v${VERSION} │
│  3. Push to harbor/uat      │
│  4. Sign image (optional)   │
│  5. Deploy to UAT env       │
└─────────────────────────────┘
           │
           ▼
Step 4: Promote to Production (After UAT Sign-off)
┌─────────────────────────────┐
│  Production Release         │
│  1. Pull from uat project   │
│  2. Re-tag: v${VERSION}     │
│  3. Push to harbor/prod     │
│  4. Sign image (required)   │
│  5. Immutable tag           │
│  6. Deploy to production    │
└─────────────────────────────┘
```

### GitHub Actions Implementation

**Promotion Workflow Example**:
```yaml
name: Promote to QA

on:
  workflow_dispatch:
    inputs:
      source_tag:
        description: 'Dev tag to promote'
        required: true
        type: string
      target_version:
        description: 'QA version (e.g., v1.2.3)'
        required: true
        type: string

jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - name: Login to Harbor
        uses: docker/login-action@v3
        with:
          registry: harbor.aglz.io
          username: ${{ secrets.HARBOR_ROBOT_USER }}
          password: ${{ secrets.HARBOR_ROBOT_TOKEN }}

      - name: Pull from Dev
        run: |
          docker pull harbor.aglz.io/agl-hostman-dev/hostman:${{ inputs.source_tag }}

      - name: Re-tag for QA
        run: |
          docker tag \
            harbor.aglz.io/agl-hostman-dev/hostman:${{ inputs.source_tag }} \
            harbor.aglz.io/agl-hostman-qa/hostman:${{ inputs.target_version }}

      - name: Push to QA
        run: |
          docker push harbor.aglz.io/agl-hostman-qa/hostman:${{ inputs.target_version }}

      - name: Verify Scan Results
        run: |
          # Use Harbor API to check vulnerability scan
          curl -u "${{ secrets.HARBOR_API_USER }}:${{ secrets.HARBOR_API_TOKEN }}" \
            "https://harbor.aglz.io/api/v2.0/projects/agl-hostman-qa/repositories/hostman/artifacts/${{ inputs.target_version }}/scan_overview"

      - name: Notify QA Team
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '🚀 Image promoted to QA: `${{ inputs.target_version }}`\nReady for testing!'
            })
```

---

## High Availability & Replication

### Replication Strategies

**Use Cases**:

1. **Load Balancing**:
   - Replicate to multiple Harbor instances
   - Geographic distribution (AGLSRV1 → AGLSRV6)
   - Reduce latency for remote sites

2. **Disaster Recovery**:
   - Primary registry failure protection
   - Automatic failover capability
   - Data redundancy

3. **Multi-Datacenter Deployment**:
   - Hybrid cloud scenarios
   - Edge computing deployments
   - Air-gapped environments

**Replication Configuration**:
```yaml
replication_rule:
  name: "AGLSRV1 to AGLSRV6"
  source_registry: "Harbor-AGLSRV1"
  destination_registry: "Harbor-AGLSRV6"

  # Filter configuration
  filters:
    - type: "project"
      value: "agl-hostman-prod"  # Only production images
    - type: "tag"
      value: "v*"                # Only semantic versions

  # Trigger settings
  trigger:
    type: "scheduled"
    cron: "0 2 * * *"  # Daily at 2 AM

  # Options
  deletion: true       # Delete at destination if deleted at source
  override: false      # Don't overwrite existing tags
```

**Proxy Cache** (Alternative to Replication):
```yaml
# For frequently accessed external images
proxy_cache:
  name: "Docker Hub Proxy"
  endpoint: "https://registry-1.docker.io"

  retention_policy:
    keep_days: 30
    keep_most_recent: 100

  # Reduces external requests for common base images
  cached_images:
    - "node:20-alpine"
    - "nginx:latest"
    - "postgres:16"
```

---

## Storage Optimization

### Retention Policies

**Development Environment**:
```yaml
retention_policy:
  # Keep only recent builds
  rule_1:
    keep_most_recent: 10
    repositories: "hostman-*"

  # Time-based cleanup
  rule_2:
    keep_days: 30
    repositories: "*"

  # Always keep tagged releases
  rule_3:
    keep_always:
      tag_pattern: "v*.*.*"
```

**Production Environment**:
```yaml
retention_policy:
  # Never auto-delete production versions
  rule_1:
    keep_always:
      tag_pattern: "v*"

  # Manual cleanup only for production
  manual_cleanup: true

  # Keep last 3 major versions
  rule_2:
    keep_most_recent: 3
    tag_pattern: "v[0-9]+.*"
```

### Storage Backend Options

**S3-Compatible Storage** (Recommended):
```yaml
storage:
  type: "s3"
  config:
    bucket: "harbor-registry"
    region: "us-east-1"
    accesskey: "AKIAIOSFODNN7EXAMPLE"
    secretkey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

    # For MinIO (self-hosted S3)
    regionendpoint: "https://minio.aglz.io"
    secure: true

    # Encryption
    encrypt: true

    # Multipart upload
    chunksize: 33554432  # 32MB
```

**Benefits**:
- Unlimited scalability
- Automatic redundancy
- Lower cost than block storage
- Easy backup and replication

---

## Dokploy Integration

### Registry Configuration in Dokploy

**Step 1: Add Harbor as Custom Registry**
```javascript
// Dokploy Server Settings → Registries → Add Registry
{
  "name": "Harbor Production",
  "url": "https://harbor.aglz.io",
  "username": "robot$dokploy-deployer",
  "password": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "ssl_verify": true
}
```

**Step 2: Configure Application to Use Harbor**
```yaml
# Dokploy Application Settings
application:
  name: "hostman-prod"
  source: "registry"
  registry: "Harbor Production"
  image: "harbor.aglz.io/agl-hostman-prod/hostman:v1.2.3"

  # Pull policy
  image_pull_policy: "Always"  # Check for updates

  # Authentication
  image_pull_secrets:
    - name: "harbor-prod-secret"
```

**Step 3: Automated Deployment with Harbor Webhooks**
```yaml
# Harbor Webhook Configuration
webhook:
  name: "Trigger Dokploy Deployment"
  endpoint: "https://dokploy.aglz.io/api/webhooks/harbor"

  # Trigger events
  events:
    - "PUSH_ARTIFACT"
    - "SCANNING_COMPLETED"

  # Filter
  filter:
    project: "agl-hostman-prod"
    tag_pattern: "v*"

  # Payload
  headers:
    Authorization: "Bearer ${DOKPLOY_WEBHOOK_TOKEN}"
```

### Complete Integration Workflow

```
Developer Push → GitHub
         │
         ▼
    GitHub Actions
         │
         ├──→ Build Docker Image
         │
         ├──→ Tag: harbor.aglz.io/agl-hostman-dev/hostman:dev-abc123
         │
         ├──→ Push to Harbor Dev Project
         │
         └──→ Harbor: Automatic Vulnerability Scan
                    │
                    ▼ (if passed)
              Harbor Webhook
                    │
                    ▼
           Dokploy Dev Environment
                    │
                    └──→ Auto-deploy to CT179 (dev)

---

Manual QA Promotion Trigger
         │
         ▼
    Pull from Dev → Re-tag for QA → Push to Harbor QA
         │
         ▼
    Harbor Webhook → Dokploy QA Environment (CT179)

---

Manual UAT Promotion Trigger
         │
         ▼
    Pull from QA → Re-tag for UAT → Push to Harbor UAT
         │
         ▼
    Harbor Webhook → Dokploy UAT Environment (CT179)

---

Manual Production Release (Approval Required)
         │
         ▼
    Pull from UAT → Sign Image → Tag v1.2.3 → Push to Harbor Prod
         │
         ▼
    Harbor Webhook → Dokploy Production (CT108/AGLSRV6)
```

---

## Security Best Practices Checklist

### Registry Security
- [ ] Enable HTTPS with valid SSL certificate
- [ ] Use robot accounts for CI/CD (not personal credentials)
- [ ] Implement token expiration and rotation (90-day max)
- [ ] Enable audit logging and review regularly
- [ ] Set up OIDC/LDAP for centralized authentication
- [ ] Configure IP whitelisting for admin access
- [ ] Enable two-factor authentication for admin users

### Image Security
- [ ] Automatic vulnerability scanning on push
- [ ] Block images with HIGH and CRITICAL CVEs in production
- [ ] Require image signatures for production deployments
- [ ] Use minimal base images (Alpine, Distroless)
- [ ] Scan for secrets and sensitive data in images
- [ ] Implement CVE whitelist for false positives
- [ ] Regular base image updates and rebuilds

### Access Control
- [ ] Principle of least privilege for all accounts
- [ ] Separate projects per environment (dev/qa/uat/prod)
- [ ] Read-only access for deployment tools (Dokploy)
- [ ] Quarterly access review and cleanup
- [ ] Revoke access for departed team members immediately
- [ ] Use service accounts for automation, not personal accounts

### Compliance & Auditing
- [ ] Enable and monitor audit logs
- [ ] Document image promotion approval process
- [ ] Maintain inventory of all images and versions
- [ ] Implement retention policies per compliance requirements
- [ ] Regular security scan reports to stakeholders
- [ ] Disaster recovery plan with tested backups
- [ ] Incident response plan for compromised images

---

## Performance Optimization

### Image Size Reduction

**Multi-Stage Builds**:
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage (smaller image)
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

**Benefits**:
- 70-90% smaller final images
- Faster push/pull times
- Reduced storage costs
- Improved security (fewer dependencies)

### Layer Caching Strategy

```dockerfile
# Optimize layer caching
FROM node:20-alpine

# 1. System dependencies (rarely change)
RUN apk add --no-cache git

# 2. Package dependencies (change occasionally)
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# 3. Application code (changes frequently)
COPY . .

# This order maximizes cache reuse
```

### Parallel Push/Pull

```bash
# Enable experimental features for faster transfers
export DOCKER_CLI_EXPERIMENTAL=enabled

# Use buildkit for parallel layer transfers
export DOCKER_BUILDKIT=1

# Configure Harbor for parallel connections
# /etc/docker/daemon.json
{
  "max-concurrent-uploads": 10,
  "max-concurrent-downloads": 10
}
```

---

## Monitoring & Alerting

### Key Metrics to Track

**Registry Health**:
- Disk space usage and growth rate
- API response times
- Failed authentication attempts
- Database connection pool status
- Replication lag (if configured)

**Image Metrics**:
- Number of images per project
- Image push/pull rates
- Vulnerability scan completion rate
- Average scan duration
- CVE severity distribution

**Security Metrics**:
- Unsigned image pull attempts
- Vulnerability policy violations
- Failed authentication attempts
- Access denied events
- Image deletion events

### Alert Configuration Examples

```yaml
alerts:
  # Storage capacity
  - name: "Low Disk Space"
    condition: "disk_usage > 85%"
    severity: "warning"
    action: "email,slack"

  # Security events
  - name: "Critical Vulnerability Detected"
    condition: "cve_severity == CRITICAL"
    severity: "critical"
    action: "email,pagerduty,block_deployment"

  # Performance
  - name: "High API Latency"
    condition: "api_response_time > 2s"
    severity: "warning"
    action: "slack"

  # Replication
  - name: "Replication Failure"
    condition: "replication_status == failed"
    severity: "critical"
    action: "email,slack"
```

---

## Cost Analysis

### Storage Costs

**S3-Compatible Storage** (MinIO self-hosted):
```
Hardware: Existing infrastructure (CT183)
Storage: 1TB SSD (~$100 one-time)
Monthly Cost: $0 (self-hosted)

vs. AWS S3:
- $0.023/GB/month = $23.55/TB/month
- Savings: ~$283/year for 1TB
```

**Harbor Platform**:
```
Server Requirements:
- 16GB RAM
- 8 CPU cores
- 100GB system disk

Cloud Cost (DigitalOcean): $168/month
Self-Hosted Cost: $0 (using CT183)

Annual Savings: $2,016
```

### Labor Costs

**Initial Setup**: 40-80 hours
**Monthly Maintenance**: 4-8 hours
**Per-Environment Configuration**: 4-8 hours each

**Total Implementation** (4 environments):
- Initial: 56-104 hours
- Monthly ongoing: 4-8 hours

---

## Conclusion & Recommendations

### ✅ Harbor is Strongly Recommended for agl-hostman Project

**Key Advantages**:
1. **Enterprise-Grade Security**: CNCF Graduated, proven track record
2. **Multi-Environment Native**: Project-based isolation perfect for dev/qa/uat/prod
3. **Cost-Effective**: Self-hosted on existing infrastructure (CT183)
4. **Dokploy Compatible**: RESTful API and Docker registry protocol
5. **Comprehensive Features**: Scanning, signing, replication, RBAC

### 🎯 Recommended Implementation Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Harbor (CT183 - AGLSRV1)                   │
│  Projects: dev, qa, uat, prod                           │
│  Storage: MinIO (S3-compatible)                         │
│  Security: Trivy scanning, Notary signing               │
└─────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌────────────┐  ┌────────────┐  ┌────────────┐
│   Dokploy  │  │   Dokploy  │  │  Dokploy   │
│    Dev     │  │   QA/UAT   │  │    Prod    │
│  (CT179)   │  │  (CT179)   │  │  (CT108)   │
└────────────┘  └────────────┘  └────────────┘
```

### 📋 Implementation Checklist

**Phase 1: Harbor Setup (Week 1)**
- [ ] Deploy Harbor on CT183
- [ ] Configure S3 storage (MinIO)
- [ ] Set up SSL certificate (Let's Encrypt)
- [ ] Configure LDAP/OIDC authentication
- [ ] Create projects (dev, qa, uat, prod)

**Phase 2: Security Configuration (Week 1-2)**
- [ ] Enable vulnerability scanning (Trivy)
- [ ] Configure severity thresholds
- [ ] Set up robot accounts for CI/CD
- [ ] Implement image signing (Notary)
- [ ] Configure retention policies

**Phase 3: CI/CD Integration (Week 2-3)**
- [ ] Add Harbor credentials to GitHub Secrets
- [ ] Create image build workflows
- [ ] Implement promotion workflows
- [ ] Configure Harbor webhooks
- [ ] Set up Dokploy registry integration

**Phase 4: Monitoring & Operations (Week 3-4)**
- [ ] Configure monitoring and alerts
- [ ] Document operational procedures
- [ ] Train team on Harbor usage
- [ ] Establish backup and disaster recovery
- [ ] Create runbooks for common issues

---

**Research Completed**: 2025-10-28
**Researcher**: Hive Mind Research Agent
**Next Document**: GitOps Branching Strategy Analysis
