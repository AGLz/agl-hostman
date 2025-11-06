# Docker Deployment Guide - agl-hostman

> **Version**: 1.0.0 | **Last Updated**: 2025-10-28

Complete guide for deploying the agl-hostman dashboard using Docker, docker-compose, Dokploy, and Harbor registry.

---

## 📑 Table of Contents

1. [Quick Start](#-quick-start)
2. [Docker Architecture](#-docker-architecture)
3. [Local Development](#-local-development)
4. [Production Deployment](#-production-deployment)
5. [Dokploy Deployment](#-dokploy-deployment)
6. [Harbor Registry](#-harbor-registry)
7. [Configuration](#-configuration)
8. [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### Prerequisites
- Docker 20.10+ and Docker Compose 2.0+
- Node.js 18+ (for local development)
- Proxmox API token or credentials

### 1. Clone and Configure
```bash
# Clone repository
cd /root/agl-hostman

# Copy environment template
cp .env.example .env

# Edit with your Proxmox credentials
vim .env
```

### 2. Start Development Environment
```bash
# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f dashboard-dev

# Access dashboard
open http://localhost:3000
```

### 3. Test Production Build
```bash
# Start production service
docker-compose --profile production up -d dashboard-prod

# Access production dashboard
open http://localhost:3001
```

---

## 🏗️ Docker Architecture

### Multi-Stage Build Strategy

The production Dockerfile uses a two-stage build:

**Stage 1: Builder**
- Base: `node:20-alpine`
- Installs build dependencies
- Runs `npm ci` for reproducible builds
- Prunes dev dependencies

**Stage 2: Production**
- Base: `node:20-alpine`
- Minimal runtime dependencies
- Non-root user (appuser:1001)
- Tini init system for proper signal handling
- Health check endpoint

### Image Size Optimization

| Stage | Size | Notes |
|-------|------|-------|
| Builder | ~450 MB | Build-time only |
| Production | ~150 MB | Deployed image |
| With all deps | ~180 MB | Final size with volumes |

### Security Features

✅ **Non-root user** (appuser:1001)
✅ **Minimal base image** (Alpine Linux)
✅ **No secrets in image** (environment variables)
✅ **Health checks** (automatic restart on failure)
✅ **Tini init system** (proper signal handling)
✅ **Read-only mounts** (source code)

---

## 💻 Local Development

### Development Environment

```bash
# Start development container with hot reloading
docker-compose up -d dashboard-dev

# View real-time logs
docker-compose logs -f dashboard-dev

# Access debugger
# Node.js debugger available on port 9229
```

**Features:**
- 🔄 Hot reloading with nodemon
- 🐛 Node.js debugger (port 9229)
- 📝 Volume mounts for instant code changes
- 🔍 Debug logging enabled

### Development Commands

```bash
# Restart service
docker-compose restart dashboard-dev

# Rebuild image
docker-compose build dashboard-dev

# Shell access
docker-compose exec dashboard-dev sh

# View environment
docker-compose exec dashboard-dev env

# Check health
curl http://localhost:3000/health
```

### Volume Mounts

```yaml
volumes:
  - ./src:/app/src:ro              # Source code (read-only)
  - ./config:/app/config:ro        # Configuration (read-only)
  - ./logs:/app/logs               # Logs (read-write)
  - node_modules:/app/node_modules # Named volume
```

**Why read-only?**
- Prevents accidental file corruption
- Ensures container doesn't modify source
- Better security posture

---

## 🏭 Production Deployment

### Build Production Image

```bash
# Build production image
docker build -t agl-hostman:latest -f docker/production/Dockerfile .

# Or use npm script
npm run docker:build

# Tag for Harbor registry
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:latest
```

### Run Production Container

```bash
# Using docker-compose (recommended)
docker-compose --profile production up -d dashboard-prod

# Or using docker run
docker run -d \
  --name agl-hostman \
  -p 3000:3000 \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/data:/app/data \
  --env-file .env \
  --restart unless-stopped \
  agl-hostman:latest
```

### Production Best Practices

✅ **Use environment variables** (not .env files in container)
✅ **Mount persistent volumes** (logs, data)
✅ **Set resource limits** (memory, CPU)
✅ **Enable health checks** (automatic restart)
✅ **Use secrets management** (Docker secrets or vault)
✅ **Monitor logs** (centralized logging)

---

## 🚢 Dokploy Deployment

### Overview

Dokploy is deployed on **CT180** (192.168.0.180) and provides:
- Git integration
- Automatic builds
- Rolling updates
- Health monitoring
- Domain management

### Deployment Steps

#### 1. Configure Dokploy Project

```bash
# Access Dokploy
open http://192.168.0.180:3000

# Or via SSH tunnel
ssh -L 3000:localhost:3000 root@192.168.0.180
```

#### 2. Import Configuration

Upload `config/dokploy.json` to Dokploy:
- Project name: `agl-hostman`
- Repository: Git URL or local path
- Dockerfile: `docker/production/Dockerfile`

#### 3. Set Environment Variables

In Dokploy UI, configure:
```
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=<your-token-id>
PROXMOX_TOKEN_SECRET=<your-token-secret>
```

**⚠️ Never commit secrets to Git!**

#### 4. Deploy

```bash
# Via Dokploy UI
Click "Deploy" → Monitor build logs → Verify health check

# Or via CLI (if available)
dokploy deploy agl-hostman
```

### Dokploy Configuration Explained

```json
{
  "buildConfig": {
    "dockerfile": "docker/production/Dockerfile",
    "context": ".",
    "target": "production"
  },
  "healthCheck": {
    "path": "/health",
    "interval": 30,
    "retries": 3
  },
  "resources": {
    "limits": {
      "memory": "512M",
      "cpu": "0.5"
    }
  }
}
```

**Resource Limits:**
- Memory: 512 MB (suitable for monitoring dashboard)
- CPU: 0.5 cores (half a CPU)
- Adjust based on load

### Accessing Deployed Application

```bash
# Via domain (if configured)
open https://hostman.aglz.io

# Via CT180 IP
open http://192.168.0.180:3000

# Via WireGuard (from CT179)
curl http://192.168.0.180:3000/health
```

---

## 🐳 Harbor Registry

### Overview

Harbor is a secure Docker registry for AGL infrastructure:
- **URL**: https://harbor.aglz.io
- **Purpose**: Store and version Docker images
- **Projects**: `agl/hostman`

### Push to Harbor

```bash
# 1. Login to Harbor
docker login harbor.aglz.io
Username: admin
Password: <harbor-password>

# 2. Tag image
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:latest
docker tag agl-hostman:latest harbor.aglz.io/agl/hostman:1.0.0

# 3. Push image
docker push harbor.aglz.io/agl/hostman:latest
docker push harbor.aglz.io/agl/hostman:1.0.0

# 4. Verify
docker pull harbor.aglz.io/agl/hostman:latest
```

### Automated Push (CI/CD)

Add to `.github/workflows/docker-build.yml`:
```yaml
- name: Push to Harbor
  run: |
    docker login harbor.aglz.io -u ${{ secrets.HARBOR_USERNAME }} -p ${{ secrets.HARBOR_PASSWORD }}
    docker push harbor.aglz.io/agl/hostman:latest
```

### Harbor Best Practices

✅ **Use semantic versioning** (`1.0.0`, `1.1.0`)
✅ **Tag with `latest`** for production
✅ **Tag with git SHA** for traceability
✅ **Scan images** for vulnerabilities
✅ **Set up webhooks** for deployment

---

## ⚙️ Configuration

### Environment Variables

#### Required
```bash
NODE_ENV=production
PORT=3000
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=<token-id>
PROXMOX_TOKEN_SECRET=<token-secret>
```

#### Optional
```bash
# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Network monitoring
WIREGUARD_ENABLED=true
TAILSCALE_ENABLED=true

# Dashboard
REFRESH_INTERVAL=30000
ENABLE_REALTIME_UPDATES=true

# Secondary Proxmox host
PROXMOX_SECONDARY_HOST=10.6.0.12
```

### Proxmox API Token Setup

**Create API token in Proxmox:**

```bash
# 1. Access Proxmox web UI
open https://192.168.0.245:8006

# 2. Navigate to:
Datacenter → Permissions → API Tokens

# 3. Create token:
User: root@pam
Token ID: dashboard-token
Privilege Separation: No (for full access)

# 4. Copy token secret immediately
```

**Configure permissions:**
```bash
# Grant necessary permissions
pveum acl modify / -user root@pam -role PVEAuditor
```

### Docker Compose Override

Create `docker-compose.override.yml` for local customization:
```yaml
version: '3.8'

services:
  dashboard-dev:
    ports:
      - "8080:3000"  # Custom port
    environment:
      - LOG_LEVEL=trace  # More verbose logging
```

**Override is gitignored** - safe for local changes.

---

## 🔧 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs dashboard-dev

# Common issues:
# 1. Port already in use
sudo lsof -i :3000
docker ps | grep 3000

# 2. Missing environment variables
docker-compose config

# 3. Permission issues
ls -la logs/
sudo chown -R 1001:1001 logs/
```

### Health Check Failing

```bash
# Manual health check
curl http://localhost:3000/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2025-10-28T...",
  "uptime": 123.45
}

# If failing:
# 1. Check application logs
docker-compose logs dashboard-dev | grep error

# 2. Check Proxmox connectivity
docker-compose exec dashboard-dev curl https://192.168.0.245:8006/api2/json/version
```

### Proxmox API Errors

```bash
# Test Proxmox connectivity
curl -k https://192.168.0.245:8006/api2/json/version

# Test API token
curl -k \
  -H "Authorization: PVEAPIToken=root@pam!<token-id>=<token-secret>" \
  https://192.168.0.245:8006/api2/json/nodes

# Common issues:
# 1. Invalid credentials
# 2. Network connectivity (check WireGuard/Tailscale)
# 3. API token expired
```

### Image Build Fails

```bash
# Clear build cache
docker-compose build --no-cache dashboard-dev

# Check Dockerfile syntax
docker build -f docker/production/Dockerfile .

# Common issues:
# 1. Missing dependencies in package.json
# 2. Build context too large (.dockerignore)
# 3. Network issues during npm install
```

### Container Running but Dashboard Not Loading

```bash
# Check if service is listening
docker-compose exec dashboard-dev netstat -tuln | grep 3000

# Check application status
docker-compose exec dashboard-dev ps aux

# Check for Node.js errors
docker-compose logs dashboard-dev --tail 100

# Test internal connectivity
docker-compose exec dashboard-dev curl http://localhost:3000/health
```

### Performance Issues

```bash
# Check resource usage
docker stats agl-hostman-dev

# Increase resource limits
docker-compose up -d --scale dashboard-dev=1 --memory=1g --cpus=1

# Check logs for bottlenecks
docker-compose logs dashboard-dev | grep -i "slow\|timeout"
```

---

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Check health endpoint
curl http://localhost:3000/health

# Monitor health over time
watch -n 5 'curl -s http://localhost:3000/health | jq'

# Check Docker health status
docker inspect --format='{{.State.Health.Status}}' agl-hostman-dev
```

### Log Management

```bash
# View logs
docker-compose logs -f --tail 100 dashboard-dev

# Filter errors
docker-compose logs dashboard-dev | grep -i error

# Export logs
docker-compose logs dashboard-dev > logs/docker-export.log

# Rotate logs (if using Docker logging driver)
docker-compose exec dashboard-dev logrotate /etc/logrotate.conf
```

### Updates

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose build dashboard-dev
docker-compose up -d dashboard-dev

# Verify deployment
curl http://localhost:3000/health
```

---

## 🔗 Related Documentation

- **Main Configuration**: `CLAUDE.md` - Project overview
- **Infrastructure Map**: `docs/INFRA.md` - Network topology
- **Coding Standards**: `docs/RULES.md` - Development rules
- **Workflows**: `docs/WORKFLOWS.md` - SPARC methodology

---

## 🤝 Support

**Issues**: Report via GitHub Issues or Archon MCP
**Documentation**: Keep this doc updated with deployments
**Contact**: AGL Infrastructure Team

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (agl-hostman project)
