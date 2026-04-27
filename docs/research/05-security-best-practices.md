# Security Best Practices for Container Infrastructure

> **Research Date**: 2025-10-28
> **Status**: Comprehensive Security Guidelines
> **Focus**: Container images, registries, deployment pipelines, and infrastructure security

---

## Executive Summary

Securing a containerized infrastructure requires a multi-layered approach spanning the entire software supply chain: from image building and vulnerability scanning, through registry access control, to runtime security and network isolation. This document compiles enterprise-grade security best practices for the `agl-hostman` deployment pipeline.

**Security Principles**:
1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimum necessary permissions
3. **Shift Left**: Security early in the development lifecycle
4. **Zero Trust**: Never trust, always verify
5. **Immutability**: Containers should not be modified post-deployment

---

## Container Image Security

### 1. Base Image Selection

**✅ Best Practices**:

**Use Minimal Base Images**:
```dockerfile
# ✅ GOOD: Alpine Linux (5MB)
FROM node:20-alpine
# Minimal attack surface, fewer vulnerabilities

# ✅ GOOD: Distroless (Google)
FROM gcr.io/distroless/nodejs20-debian12
# No shell, package manager, or unnecessary binaries

# ❌ AVOID: Full OS images
FROM node:20
# 900MB+ with unnecessary packages
```

**Pin Specific Versions**:
```dockerfile
# ✅ GOOD: Specific version with digest
FROM node:20.11.1-alpine@sha256:abc123...
# Immutable reference, reproducible builds

# ⚠️  ACCEPTABLE: Specific version tag
FROM node:20.11.1-alpine
# Reproducible but tag could be updated

# ❌ AVOID: Latest or major version only
FROM node:latest
FROM node:20-alpine
# Unpredictable, breaks reproducibility
```

**Verify Image Provenance**:
```bash
# Use Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker pull node:20-alpine
# Only pulls signed images

# Verify image signatures manually
cosign verify --key cosign.pub node:20-alpine
```

### 2. Multi-Stage Builds

**Separate Build and Runtime Environments**:

```dockerfile
# ===== BUILD STAGE =====
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production \
  && npm cache clean --force

# Build application
COPY . .
RUN npm run build

# ===== RUNTIME STAGE =====
FROM node:20-alpine AS runtime

# Create non-root user
RUN addgroup -g 1001 -S nodejs \
  && adduser -S nodejs -u 1001

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Switch to non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node healthcheck.js || exit 1

# Expose port (informational)
EXPOSE 3000

CMD ["node", "dist/index.js"]
```

**Benefits**:
- ✅ 70-90% smaller final image
- ✅ No build tools in production image
- ✅ Reduced attack surface
- ✅ Faster deployments

### 3. Dependency Management

**Scan Dependencies for Vulnerabilities**:

```bash
# NPM audit (Node.js)
npm audit --audit-level=high
npm audit fix

# Safety check (Python)
safety check --file requirements.txt

# Trivy filesystem scan
trivy fs --severity HIGH,CRITICAL .

# Snyk (comprehensive)
snyk test --severity-threshold=high
```

**Pin Dependency Versions**:

```json
// package.json - ✅ GOOD
{
  "dependencies": {
    "express": "4.18.2",
    "lodash": "4.17.21"
  }
}

// package.json - ❌ AVOID
{
  "dependencies": {
    "express": "^4.0.0",  // Range allows automatic updates
    "lodash": "*"         // Any version
  }
}
```

**Use Lock Files**:
```bash
# Commit these files to version control
package-lock.json    # NPM
yarn.lock            # Yarn
poetry.lock          # Python Poetry
Gemfile.lock         # Ruby
go.sum               # Go

# Ensure CI/CD uses lock files
npm ci               # Not npm install
pip install -r requirements.txt --require-hashes
```

### 4. Secrets Management

**❌ NEVER Hardcode Secrets**:

```dockerfile
# ❌ TERRIBLE: Hardcoded credentials
ENV DB_PASSWORD=supersecret123
ENV API_KEY=sk_live_abc123xyz

# ❌ BAD: Build-time secrets exposed in layers
ARG DATABASE_URL
RUN echo $DATABASE_URL > /app/config.txt

# ❌ BAD: Secrets in environment variables in image
COPY .env /app/.env
```

**✅ Use External Secret Management**:

```dockerfile
# ✅ GOOD: Secrets injected at runtime
# No secrets in image

# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
USER nodejs
CMD ["node", "index.js"]

# docker-compose.yaml
services:
  app:
    image: app:latest
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key

secrets:
  db_password:
    external: true
  api_key:
    external: true
```

**Best Practices for Secret Injection**:

1. **Docker Secrets** (Docker Swarm):
```bash
echo "my_secret_password" | docker secret create db_password -
docker service create --secret db_password my_app
```

2. **Kubernetes Secrets**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db-password: <base64-encoded>
  api-key: <base64-encoded>

---
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: app:latest
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-password
```

3. **HashiCorp Vault**:
```bash
# Application fetches secrets at runtime
vault kv get secret/app/database

# Vault Agent sidecar injects secrets
# No secrets in application code or images
```

4. **Environment-Specific Injection** (Dokploy):
```yaml
# Dokploy application environment variables
# Set via UI or API, not in image
environment:
  - DB_PASSWORD=${VAULT_DB_PASSWORD}
  - API_KEY=${VAULT_API_KEY}
```

### 5. Image Scanning

**Automated Vulnerability Scanning**:

**Trivy** (Fast, accurate):
```bash
# Scan image before pushing to registry
trivy image --severity HIGH,CRITICAL app:latest

# Fail CI/CD if vulnerabilities found
trivy image --exit-code 1 --severity CRITICAL app:latest

# Scan filesystem during build
trivy fs --severity HIGH,CRITICAL /app

# Output JSON for further processing
trivy image -f json -o scan-results.json app:latest
```

**Harbor Registry** (Integrated scanning):
```yaml
# Harbor project configuration
project:
  name: agl-hostman-prod
  auto_scan: true
  prevent_vulnerable_images: true
  severity_threshold: HIGH

# Policy: Block pulls of images with HIGH or CRITICAL CVEs
```

**GitHub Actions Integration**:
```yaml
name: Image Security Scan

on:
  push:
    branches: [main, dev]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:latest .

      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Fail on critical vulnerabilities
        run: |
          trivy image --exit-code 1 --severity CRITICAL app:latest
```

**Continuous Scanning**:
```bash
# Re-scan existing images regularly (weekly)
# New CVEs discovered daily

# Cron job or scheduled GitHub Action
0 2 * * 0 trivy image --severity HIGH,CRITICAL harbor.aglz.io/prod/app:v1.2.3
```

---

## Container Registry Security

### 1. Access Control (RBAC)

**Harbor Project Roles**:

```yaml
# Project: agl-hostman-prod
members:
  - username: "ops-team"
    role: "projectAdmin"      # Full control

  - username: "robot$ci-deployer"
    role: "developer"          # Push images

  - username: "robot$dokploy-puller"
    role: "guest"              # Pull only

  - username: "qa-team"
    role: "limitedGuest"       # Pull specific tags only
```

**Robot Accounts** (Recommended for Automation):

```bash
# Create robot account in Harbor UI or API
# Project: agl-hostman-prod
# Name: robot$dokploy-deployer
# Permissions: Pull only
# Expiration: 90 days

# Use in Dokploy
docker login harbor.aglz.io \
  -u "robot\$dokploy-deployer" \
  -p "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Rotate tokens every 90 days
# Set calendar reminder for rotation
```

**Principle of Least Privilege**:

| Actor | Environment | Permission | Rationale |
|-------|------------|------------|-----------|
| CI/CD | Dev | Push, Pull | Needs to build and test |
| CI/CD | QA/UAT/Prod | Pull only | No direct push to higher envs |
| Dokploy (Dev) | Dev | Pull only | Only deploys pre-built images |
| Dokploy (Prod) | Prod | Pull only | Only deploys signed, approved images |
| Developers | Dev | Push, Pull | Active development |
| Developers | QA/UAT/Prod | Pull only | View only, no direct push |
| QA Team | QA | Pull only | Testing only |

### 2. Authentication Methods

**LDAP/Active Directory**:
```yaml
# Harbor LDAP configuration
auth:
  ldap:
    url: "ldaps://ldap.aglz.io:636"
    base_dn: "ou=users,dc=aglz,dc=io"
    filter: "(objectClass=person)"
    uid: "uid"
    scope: 2  # Subtree

    # Group-based access
    group_base_dn: "ou=groups,dc=aglz,dc=io"
    group_filter: "(objectClass=groupOfNames)"
```

**OIDC (OpenID Connect)**:
```yaml
# Harbor OIDC configuration (Keycloak, Okta, Auth0)
auth:
  oidc:
    name: "Keycloak"
    endpoint: "https://keycloak.aglz.io/auth/realms/agl"
    client_id: "harbor"
    client_secret: "${OIDC_CLIENT_SECRET}"
    scope: "openid,profile,email"
    verify_cert: true

    # Auto-create user accounts
    auto_onboard: true
    user_claim: "preferred_username"
```

**API Token Authentication**:
```bash
# Generate CLI secret for Harbor API
# User Profile → Generate CLI Secret

export HARBOR_USERNAME="admin"
export HARBOR_CLI_SECRET="abc123def456..."

# Use in API calls
curl -u "$HARBOR_USERNAME:$HARBOR_CLI_SECRET" \
  "https://harbor.aglz.io/api/v2.0/projects"
```

### 3. Image Signing (Content Trust)

**Enable Docker Content Trust**:

```bash
# Generate signing keys
docker trust key generate my-key

# Initialize repository
docker trust signer add --key my-key.pub my-signer harbor.aglz.io/prod/app

# Sign and push image
export DOCKER_CONTENT_TRUST=1
docker trust sign harbor.aglz.io/prod/app:v1.2.3

# Verification on pull
export DOCKER_CONTENT_TRUST=1
docker pull harbor.aglz.io/prod/app:v1.2.3
# Fails if signature invalid or missing
```

**Harbor Notary Integration**:

```yaml
# Harbor project: agl-hostman-prod
project_policy:
  content_trust: true  # Require signed images

# Deployment policy
deployment:
  prevent_unsigned_images: true
  severity: "CRITICAL"  # Fail deployment

# Webhook notification on unsigned image push
webhooks:
  - name: "Unsigned Image Alert"
    event: "PUSH_ARTIFACT"
    enabled: true
    targets:
      - type: "slack"
        address: "https://hooks.slack.com/services/xxx"
        skip_cert_verify: false
```

**CI/CD Signing Workflow**:

```yaml
# .github/workflows/build-and-sign.yaml
name: Build, Sign, and Push

on:
  push:
    tags:
      - 'v*'

jobs:
  build-sign-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build -t harbor.aglz.io/prod/app:${{ github.ref_name }} .

      - name: Login to Harbor
        run: |
          echo "${{ secrets.HARBOR_PASSWORD }}" | \
            docker login harbor.aglz.io -u "${{ secrets.HARBOR_USERNAME }}" --password-stdin

      - name: Sign and push image
        env:
          DOCKER_CONTENT_TRUST: 1
          DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE: ${{ secrets.SIGNING_PASSPHRASE }}
        run: |
          docker trust sign harbor.aglz.io/prod/app:${{ github.ref_name }}
          docker push harbor.aglz.io/prod/app:${{ github.ref_name }}

      - name: Verify signature
        run: |
          docker trust inspect harbor.aglz.io/prod/app:${{ github.ref_name }}
```

### 4. Network Security

**Registry Network Isolation**:

```yaml
# Harbor should be on isolated network
# Only accessible via:
# 1. WireGuard mesh (internal)
# 2. Reverse proxy with authentication (external)

version: '3.8'

services:
  harbor:
    image: goharbor/harbor-core:latest
    networks:
      - harbor_internal      # Backend services
      - harbor_frontend      # Reverse proxy only

  nginx:
    image: nginx:alpine
    networks:
      - harbor_frontend      # Connect to Harbor
      - wireguard_network    # Accessible via WireGuard
    ports:
      - "10.6.0.21:443:443"  # Only on WireGuard interface

networks:
  harbor_internal:
    driver: bridge
    internal: true           # No external access

  harbor_frontend:
    driver: bridge

  wireguard_network:
    external: true
```

**TLS/SSL Configuration**:

```yaml
# Harbor TLS settings
# Use Let's Encrypt or internal CA

harbor:
  tls:
    enabled: true
    cert_path: "/data/cert/server.crt"
    key_path: "/data/cert/server.key"

    # Client certificate verification (optional)
    client_cert_verify: false

    # Minimum TLS version
    min_tls_version: "TLS1.2"

    # Cipher suites (strong only)
    cipher_suites:
      - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
```

**IP Whitelisting**:

```yaml
# Restrict registry access to known IPs
# Via reverse proxy (Nginx, Traefik)

# Nginx config
location /v2/ {
    # Allow WireGuard network
    allow 10.6.0.0/24;

    # Allow Tailscale network
    allow 100.64.0.0/10;

    # Deny all other IPs
    deny all;

    proxy_pass https://harbor-backend;
}
```

---

## Deployment Pipeline Security

### 1. CI/CD Security

**GitHub Actions Security**:

```yaml
# .github/workflows/deploy.yaml
name: Secure Deploy

on:
  push:
    branches: [main]

# Required permissions (least privilege)
permissions:
  contents: read
  packages: write
  id-token: write  # For OIDC authentication

jobs:
  deploy:
    runs-on: ubuntu-latest

    # Environment protection rules
    environment:
      name: production
      url: https://app.aglz.io

    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false  # Don't persist GitHub token

      - name: Authenticate to Harbor via OIDC
        uses: docker/login-action@v3
        with:
          registry: harbor.aglz.io
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_TOKEN }}

      - name: Build with security scanning
        run: |
          docker build -t app:latest .
          trivy image --exit-code 1 --severity CRITICAL app:latest

      - name: Sign image
        run: |
          cosign sign --key cosign.key harbor.aglz.io/prod/app:v1.2.3

      - name: Deploy
        run: |
          # Deploy only if all security checks passed
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_URL }}" \
            -H "Authorization: Bearer ${{ secrets.DOKPLOY_TOKEN }}"
```

**Secret Management in CI/CD**:

```yaml
# GitHub repository settings → Secrets and variables

# Environment-specific secrets
Secrets:
  HARBOR_USERNAME          # Robot account
  HARBOR_TOKEN             # 90-day rotation
  DOKPLOY_WEBHOOK_URL      # Per-environment
  DOKPLOY_TOKEN            # API authentication
  SIGNING_KEY              # Image signing (encrypted)
  SIGNING_PASSPHRASE       # Key passphrase

# Best practices:
# - Use environment-specific secrets (dev, qa, prod)
# - Rotate tokens every 90 days
# - Least privilege (read-only where possible)
# - Audit secret access logs
```

### 2. Deployment Verification

**Pre-Deployment Checks**:

```bash
#!/bin/bash
# pre-deploy-checks.sh

set -e

IMAGE=$1
ENV=$2

echo "🔍 Running pre-deployment security checks..."

# 1. Verify image signature
echo "✓ Verifying image signature..."
cosign verify --key cosign.pub $IMAGE || {
  echo "❌ Image signature verification failed"
  exit 1
}

# 2. Check vulnerability scan results
echo "✓ Checking vulnerability scan..."
SCAN_RESULTS=$(curl -s -u "$HARBOR_USER:$HARBOR_TOKEN" \
  "https://harbor.aglz.io/api/v2.0/projects/${ENV}/repositories/app/artifacts/${TAG}/scan_overview")

CRITICAL_COUNT=$(echo $SCAN_RESULTS | jq '.summary.critical')
if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "❌ Image has $CRITICAL_COUNT CRITICAL vulnerabilities"
  exit 1
fi

# 3. Verify image is from correct environment
echo "✓ Verifying promotion path..."
# Dev → QA → UAT → Prod (no skipping)

# 4. Check required approvals (production only)
if [ "$ENV" == "prod" ]; then
  echo "✓ Verifying required approvals..."
  # Query GitHub API for PR approvals
fi

echo "✅ All pre-deployment checks passed"
exit 0
```

**Post-Deployment Verification**:

```bash
#!/bin/bash
# post-deploy-verify.sh

ENVIRONMENT=$1
EXPECTED_VERSION=$2

echo "🔍 Verifying deployment..."

# 1. Check deployed version matches expected
ACTUAL_VERSION=$(curl -s "https://api-$ENVIRONMENT.aglz.io/version" | jq -r '.version')

if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "❌ Version mismatch: expected $EXPECTED_VERSION, got $ACTUAL_VERSION"
  # Rollback
  exit 1
fi

# 2. Health check
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "https://api-$ENVIRONMENT.aglz.io/health")
if [ "$HEALTH" != "200" ]; then
  echo "❌ Health check failed: HTTP $HEALTH"
  exit 1
fi

# 3. Smoke tests
echo "✓ Running smoke tests..."
# Run critical path tests

echo "✅ Deployment verification passed"
```

---

## Runtime Security

### 1. Container Runtime Configuration

**Security Options**:

```yaml
services:
  app:
    image: harbor.aglz.io/prod/app:v1.2.3

    # Run as non-root user
    user: "1001:1001"

    # Read-only root filesystem
    read_only: true
    tmpfs:
      - /tmp
      - /var/run

    # Drop all capabilities, add only required
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to port <1024

    # Security options
    security_opt:
      - no-new-privileges:true  # Prevent privilege escalation
      - seccomp:unconfined      # Or custom seccomp profile
      - apparmor:docker-default # Or custom AppArmor profile

    # Resource limits (prevent DoS)
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

    # Restart policy
    restart: unless-stopped

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Dockerfile Security Hardening**:

```dockerfile
FROM node:20-alpine

# Install security updates
RUN apk update && apk upgrade

# Create non-root user
RUN addgroup -g 1001 -S nodejs \
  && adduser -S nodejs -u 1001 \
  && mkdir -p /app \
  && chown -R nodejs:nodejs /app

WORKDIR /app

# Copy files with correct ownership
COPY --chown=nodejs:nodejs package*.json ./
RUN npm ci --only=production \
  && npm cache clean --force

COPY --chown=nodejs:nodejs . .

# Remove unnecessary packages (reduce attack surface)
RUN apk del apk-tools

# Switch to non-root user
USER nodejs

# Use non-root port
EXPOSE 3000

# Run with explicit command (not shell form)
CMD ["node", "index.js"]
```

### 2. Network Policies

**Docker Network Isolation**:

```yaml
# Separate networks for different trust levels
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

services:
  web:
    networks:
      - frontend
      - backend  # Can talk to API

  api:
    networks:
      - backend  # Can talk to DB, but not internet

  database:
    networks:
      - backend
    # Completely isolated from internet
```

**Kubernetes Network Policies** (if applicable):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Only allow traffic from web frontend
    - from:
      - podSelector:
          matchLabels:
            app: web
      ports:
        - protocol: TCP
          port: 3000

  egress:
    # Only allow traffic to database
    - to:
      - podSelector:
          matchLabels:
            app: database
      ports:
        - protocol: TCP
          port: 5432
```

### 3. Monitoring & Logging

**Security Audit Logging**:

```yaml
# Log all security-relevant events
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
    labels: "security,audit"

# Centralized logging
# Forward logs to Grafana Loki or ELK stack

# Monitor for:
# - Failed authentication attempts
# - Privilege escalation attempts
# - Unauthorized API calls
# - Container escape attempts
# - Network policy violations
```

**Alerting Rules** (Prometheus):

```yaml
# alert-rules.yaml
groups:
  - name: security
    interval: 30s
    rules:
      - alert: ContainerRunningAsRoot
        expr: |
          container_running_as_root == 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Container running as root user"

      - alert: HighVulnerabilityCount
        expr: |
          harbor_vulnerability_count{severity="critical"} > 0
        labels:
          severity: critical
        annotations:
          summary: "Critical vulnerabilities detected in image"

      - alert: UnauthorizedImagePull
        expr: |
          rate(harbor_unauthorized_attempts_total[5m]) > 5
        labels:
          severity: warning
        annotations:
          summary: "Multiple unauthorized registry access attempts"
```

---

## Incident Response

### Security Incident Runbook

**1. Compromised Container Detected**:

```bash
#!/bin/bash
# incident-response.sh

# Step 1: Isolate container
docker network disconnect bridge <container_id>

# Step 2: Capture forensics
docker inspect <container_id> > container-forensics.json
docker logs <container_id> > container-logs.txt
docker export <container_id> > container-filesystem.tar

# Step 3: Stop container
docker stop <container_id>

# Step 4: Scan image
trivy image --severity CRITICAL,HIGH <image>

# Step 5: Notify security team
# Send alerts via Slack, PagerDuty, etc.

# Step 6: Review access logs
# Check Harbor audit logs for unauthorized access
# Review Proxmox/Docker API logs

# Step 7: Rotate credentials
# Invalidate all API tokens
# Rotate robot account credentials
# Change passwords

# Step 8: Root cause analysis
# Analyze forensics data
# Determine entry point
# Document findings
```

**2. Vulnerability Response**:

```bash
# New critical CVE discovered in production image

# Step 1: Assess severity and exploitability
trivy image harbor.aglz.io/prod/app:v1.2.3

# Step 2: Check if actively exploited (external threat intel)
# Query security feeds, CISA KEV catalog

# Step 3: Determine patch availability
# Check upstream base image updates

# Step 4: Emergency patch process
# Build patched image
docker build -t harbor.aglz.io/prod/app:v1.2.4-security-patch .

# Fast-track through environments
# Dev (auto-deploy) → QA (quick test) → Production (emergency change)

# Step 5: Deploy patch
# Use emergency deployment process
# Bypass normal change window if critical

# Step 6: Verify patch
trivy image harbor.aglz.io/prod/app:v1.2.4-security-patch
# Confirm CVE no longer present

# Step 7: Post-incident review
# Document timeline
# Update runbooks
# Improve detection
```

---

## Compliance & Auditing

### Compliance Requirements

**GDPR (Data Protection)**:
- [ ] Log all access to personal data
- [ ] Encrypt data at rest and in transit
- [ ] Implement right to be forgotten (data deletion)
- [ ] Document data processing activities

**SOC 2 (Security Controls)**:
- [ ] Multi-factor authentication for admin access
- [ ] Audit logging of all privileged operations
- [ ] Regular vulnerability assessments
- [ ] Incident response procedures documented
- [ ] Change management process enforced

**PCI-DSS** (if handling payment data):
- [ ] Network segmentation (payment services isolated)
- [ ] Encryption of cardholder data
- [ ] Regular security scanning
- [ ] Restricted access to cardholder data

### Audit Trail Requirements

**What to Log**:
```yaml
audit_events:
  authentication:
    - login_attempts (success and failure)
    - token_creation and revocation
    - password_changes
    - mfa_events

  authorization:
    - role_assignments
    - permission_changes
    - access_denied_events

  container_operations:
    - image_push and image_pull
    - container_start and container_stop
    - privileged_container_creation
    - volume_mounts

  security_events:
    - vulnerability_scan_results
    - image_signature_verification
    - policy_violations
    - suspicious_activity

  data_access:
    - database_queries (if sensitive data)
    - file_access (if personal data)
    - api_calls (with request/response)
```

**Log Retention**:
```yaml
retention_policy:
  security_logs: 365 days
  audit_logs: 7 years (compliance requirement)
  application_logs: 90 days
  debug_logs: 30 days
```

---

## Security Checklist

### Development Phase
- [ ] Use minimal base images (Alpine, Distroless)
- [ ] Pin specific image versions with digests
- [ ] Implement multi-stage builds
- [ ] Run containers as non-root users
- [ ] Use read-only root filesystem where possible
- [ ] Scan dependencies for vulnerabilities
- [ ] Remove unnecessary packages and files
- [ ] Never hardcode secrets in images
- [ ] Implement health checks

### Build Phase
- [ ] Automated vulnerability scanning (Trivy)
- [ ] Dependency scanning (npm audit, safety)
- [ ] SAST (static application security testing)
- [ ] Secret scanning (detect leaked credentials)
- [ ] Fail build on critical vulnerabilities
- [ ] Generate SBOM (Software Bill of Materials)

### Registry Phase
- [ ] Enable automatic image scanning on push
- [ ] Configure vulnerability severity thresholds
- [ ] Implement image signing (Notary)
- [ ] Set up RBAC (robot accounts for automation)
- [ ] Enable audit logging
- [ ] Configure retention policies
- [ ] Restrict network access (WireGuard only)
- [ ] Use HTTPS with valid certificates
- [ ] Implement IP whitelisting

### Deployment Phase
- [ ] Verify image signatures before deployment
- [ ] Check vulnerability scan results
- [ ] Validate promotion path (no skipping environments)
- [ ] Require approvals for production deployments
- [ ] Implement pre-deployment security checks
- [ ] Use secrets management (not env vars in images)
- [ ] Configure resource limits (CPU, memory)
- [ ] Enable network policies (isolation)
- [ ] Implement health checks and readiness probes
- [ ] Set up monitoring and alerting

### Runtime Phase
- [ ] Monitor container behavior (anomaly detection)
- [ ] Log security events (centralized logging)
- [ ] Regular security scans of running containers
- [ ] Network traffic monitoring
- [ ] Rotate credentials regularly (90 days max)
- [ ] Review access logs
- [ ] Patch vulnerabilities promptly
- [ ] Test disaster recovery procedures

### Audit & Compliance
- [ ] Maintain audit logs (minimum 365 days)
- [ ] Document security procedures
- [ ] Regular security assessments
- [ ] Penetration testing (annually)
- [ ] Incident response plan documented and tested
- [ ] Compliance reviews (GDPR, SOC 2, etc.)
- [ ] Security training for team members

---

## Tools Summary

### Vulnerability Scanning
- **Trivy**: Fast, accurate, local scanning
- **Grype**: Syft-based vulnerability scanner
- **Snyk**: Comprehensive (commercial)
- **Anchore**: Enterprise-grade scanning

### Image Signing
- **Cosign**: Simple, keyless signing
- **Notary**: Docker Content Trust
- **Harbor**: Integrated Notary support

### Secret Management
- **HashiCorp Vault**: Industry standard
- **Docker Secrets**: Built-in (Swarm)
- **Kubernetes Secrets**: Built-in (K8s)
- **External Secrets Operator**: Kubernetes integration

### Compliance & Auditing
- **Falco**: Runtime security monitoring
- **Open Policy Agent (OPA)**: Policy enforcement
- **Grafana Loki**: Centralized logging
- **Prometheus**: Metrics and alerting

---

## Conclusion

Security is **not a one-time effort** but a **continuous process** spanning the entire container lifecycle. The `agl-hostman` project should adopt a **defense-in-depth** approach with multiple layers of security controls:

1. **Build Time**: Secure base images, dependency scanning, no hardcoded secrets
2. **Registry**: Vulnerability scanning, image signing, RBAC, audit logging
3. **Deployment**: Signature verification, promotion validation, security checks
4. **Runtime**: Non-root users, resource limits, network isolation, monitoring

**Key Principles**:
- ✅ Shift security left (early in development)
- ✅ Automate security checks (CI/CD integration)
- ✅ Least privilege everywhere (RBAC, IAM)
- ✅ Immutable infrastructure (no runtime modifications)
- ✅ Continuous monitoring and improvement

**Implementation Timeline**: Phased approach over 8 weeks, starting with critical controls (image scanning, RBAC) and progressively adding advanced features (signing, network policies, compliance logging).

---

**Research Completed**: 2025-10-28
**Researcher**: Hive Mind Research Agent
**Final Document**: Executive Summary and Recommendations
