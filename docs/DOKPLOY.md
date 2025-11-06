# Dokploy Platform Configuration Guide

> **Last Updated**: 2025-10-28 | **Version**: 1.0.0
> **Reference**: Complete guide for Dokploy deployment platform integration

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Infrastructure Setup](#-infrastructure-setup)
3. [Initial Configuration](#-initial-configuration)
4. [Harbor Registry Integration](#-harbor-registry-integration)
5. [Application Deployment](#-application-deployment)
6. [CI/CD Webhook Setup](#-cicd-webhook-setup)
7. [Monitoring & Management](#-monitoring--management)
8. [Troubleshooting](#-troubleshooting)

---

## 🌐 Overview

**Dokploy** is the deployment platform for the AGL infrastructure, providing Docker-based application deployment, monitoring, and management capabilities.

### Platform Information

| Property | Value |
|----------|-------|
| **Container** | CT180 (dokploy) |
| **Host** | AGLSRV1 (192.168.0.245) |
| **LAN IP** | 192.168.0.180 |
| **Public URL** | https://dok.aglz.io |
| **Alternative Access** | http://192.168.0.180:3000 (local) |
| **Technology** | Docker-based deployment platform |

### Key Features

- Docker container deployment
- Application management dashboard
- Built-in monitoring
- Git integration support
- Environment variable management
- Custom domain support
- Health check configuration
- Zero-downtime deployments

---

## 🏗️ Infrastructure Setup

### Network Configuration

**From CT179 (Development)**:
```bash
# LAN access (fastest)
curl http://192.168.0.180:3000

# Public access (with SSL)
curl https://dok.aglz.io
```

**From WSL2 (Remote)**:
```bash
# Tailscale access (if configured)
# Or use public URL
curl https://dok.aglz.io
```

### Container Specifications

**CT180 (dokploy)** on AGLSRV1:
- **OS**: Ubuntu/Debian (LXC container)
- **Docker**: Installed via Dokploy installer
- **Network**: LAN (192.168.0.180)
- **Storage**: Local container storage
- **Cloudflare**: Proxied via dok.aglz.io

**Key Services**:
- Dokploy web interface: Port 3000
- Docker daemon: Standard Docker socket
- PostgreSQL: Embedded (for Dokploy metadata)
- Traefik: Reverse proxy (optional)

---

## ⚙️ Initial Configuration

### Step 1: Access Dokploy UI

1. **Open Dokploy**:
   ```bash
   # From browser
   https://dok.aglz.io
   ```

2. **Login**:
   - First-time setup will prompt for admin account creation
   - Existing installation: Use admin credentials
   - Password reset: See [Password Recovery](#password-recovery)

### Step 2: System Settings

Navigate to **Settings** → **General**:

1. **Server Configuration**:
   - Server name: `AGLSRV1-Dokploy`
   - Domain: `dok.aglz.io`
   - Enable SSL: Yes (Cloudflare handles this)

2. **Docker Settings**:
   - Docker socket: `/var/run/docker.sock`
   - Default network: `bridge`
   - Prune policy: Weekly cleanup

3. **Resource Limits**:
   - Default CPU limit: 0.5 (50%)
   - Default memory limit: 512MB
   - Can be overridden per application

---

## 🐳 Harbor Registry Integration

### Harbor Registry Configuration

**Harbor Instance**:
- **URL**: https://harbor.aglz.io
- **Registry**: harbor.aglz.io:5000
- **Credentials**: admin / SecurePass2025!
- **Status**: Currently returning 502 (needs investigation)

### Configure Registry in Dokploy

1. **Add Registry**:
   - Go to **Settings** → **Registries**
   - Click **Add Registry**

2. **Registry Details**:
   ```yaml
   Registry Type: Docker Registry
   Name: AGL Harbor
   URL: https://harbor.aglz.io:5000
   Username: admin
   Password: SecurePass2025!
   Verify SSL: No (if self-signed cert)
   ```

3. **Test Connection**:
   ```bash
   # From CT180 or CT179
   docker login harbor.aglz.io:5000
   # Username: admin
   # Password: SecurePass2025!

   docker pull harbor.aglz.io:5000/dev/agl-hostman:latest
   ```

### Harbor Project Structure

```
harbor.aglz.io:5000/
├── dev/
│   ├── agl-hostman:latest
│   ├── agl-hostman:v1.0.0
│   └── test-app:latest
├── staging/
│   └── agl-hostman:staging
└── production/
    └── agl-hostman:prod
```

---

## 🚀 Application Deployment

### Method 1: Docker Image from Harbor

#### Create Application

1. **Navigate to Applications**:
   - Click **Create Application**
   - Select **Docker Image**

2. **Basic Configuration**:
   ```yaml
   Application Name: agl-hostman-dev
   Description: AGL Infrastructure Management Dashboard
   Environment: Development
   ```

3. **Image Configuration**:
   ```yaml
   Image: harbor.aglz.io:5000/dev/agl-hostman:latest
   Registry: AGL Harbor (from dropdown)
   Pull Policy: Always
   ```

4. **Port Configuration**:
   ```yaml
   Container Port: 3000
   Host Port: 3001 (or auto-assign)
   Protocol: HTTP
   ```

5. **Health Check**:
   ```yaml
   Type: HTTP
   Path: /health
   Port: 3000
   Interval: 30s
   Timeout: 5s
   Retries: 3
   Start Period: 10s
   ```

6. **Environment Variables**:
   ```bash
   NODE_ENV=development
   PROXMOX_API_URL=https://192.168.0.245:8006/api2/json
   PROXMOX_API_TOKEN_ID=<token_id>
   PROXMOX_API_TOKEN=<token_secret>
   WIREGUARD_INTERFACE=wg0
   LOG_LEVEL=info
   ```

7. **Resource Limits**:
   ```yaml
   CPU Limit: 0.5 (50%)
   Memory Limit: 512MB
   Memory Reservation: 256MB
   ```

8. **Restart Policy**:
   ```yaml
   Policy: Always
   Max Retries: 3
   ```

9. **Volume Mounts** (Optional):
   ```yaml
   # Logs
   Host: /var/log/agl-hostman
   Container: /app/logs

   # Data
   Host: /var/lib/agl-hostman
   Container: /app/data
   ```

#### Deploy Application

1. Click **Create & Deploy**
2. Monitor deployment in **Logs** tab
3. Check status in **Overview**
4. Access application via configured domain/port

### Method 2: Docker Compose

#### Create Compose Application

1. **Navigate to Applications**:
   - Click **Create Application**
   - Select **Docker Compose**

2. **Basic Configuration**:
   ```yaml
   Application Name: agl-hostman-stack
   Description: AGL Infrastructure Management Stack
   ```

3. **Compose Configuration**:
   ```yaml
   version: '3.8'

   services:
     app:
       image: harbor.aglz.io:5000/dev/agl-hostman:latest
       container_name: agl-hostman-dev
       ports:
         - "3001:3000"
       environment:
         - NODE_ENV=development
         - PROXMOX_API_URL=https://192.168.0.245:8006/api2/json
         - PROXMOX_API_TOKEN_ID=${PROXMOX_TOKEN_ID}
         - PROXMOX_API_TOKEN=${PROXMOX_TOKEN}
         - WIREGUARD_INTERFACE=wg0
       volumes:
         - app-logs:/app/logs
         - app-data:/app/data
       restart: always
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
         interval: 30s
         timeout: 5s
         retries: 3
         start_period: 10s
       deploy:
         resources:
           limits:
             cpus: '0.5'
             memory: 512M
           reservations:
             memory: 256M

   volumes:
     app-logs:
       driver: local
     app-data:
       driver: local
   ```

4. **Environment Variables** (separate tab):
   ```bash
   PROXMOX_TOKEN_ID=<your_token_id>
   PROXMOX_TOKEN=<your_token_secret>
   ```

5. Deploy and monitor as before

### Method 3: Git Repository

#### Coming Soon
Deploy directly from Git repository with automatic builds:
- GitHub integration
- GitLab integration
- Bitbucket integration
- Automatic webhook triggers

---

## 🔗 CI/CD Webhook Setup

### Harbor Webhook Configuration

Configure Harbor to trigger Dokploy deployments on image push.

#### Step 1: Get Dokploy Webhook URL

1. In Dokploy, go to application **Settings**
2. Navigate to **Webhooks** tab
3. Copy webhook URL:
   ```
   https://dok.aglz.io/api/webhook/trigger/<app-id>/<webhook-secret>
   ```

#### Step 2: Configure Harbor Webhook

1. **Login to Harbor**:
   ```
   https://harbor.aglz.io
   ```

2. **Navigate to Project**:
   - Select project (e.g., `dev`)
   - Go to **Webhooks** tab

3. **Add Webhook**:
   ```yaml
   Name: Dokploy Deploy - agl-hostman-dev
   Endpoint URL: https://dok.aglz.io/api/webhook/trigger/<app-id>/<webhook-secret>
   Auth Header: (leave empty or add token)
   ```

4. **Select Events**:
   - ✅ Artifact pushed
   - ✅ Artifact deleted (optional)
   - ❌ Scanning completed (optional)

5. **Test Webhook**:
   - Click **Test** button
   - Verify successful response

#### Step 3: Test Automated Deployment

```bash
# From development machine
cd /path/to/agl-hostman

# Build and tag image
docker build -t harbor.aglz.io:5000/dev/agl-hostman:latest .

# Push to Harbor (triggers webhook)
docker push harbor.aglz.io:5000/dev/agl-hostman:latest

# Monitor deployment in Dokploy
# Should automatically pull and restart application
```

### Webhook Payload Example

Harbor sends this payload to Dokploy:

```json
{
  "type": "PUSH_ARTIFACT",
  "occur_at": 1698765432,
  "operator": "admin",
  "event_data": {
    "resources": [{
      "resource_url": "harbor.aglz.io:5000/dev/agl-hostman:latest",
      "tag": "latest"
    }],
    "repository": {
      "name": "agl-hostman",
      "namespace": "dev",
      "repo_full_name": "dev/agl-hostman"
    }
  }
}
```

---

## 📊 Monitoring & Management

### Application Monitoring

#### Dokploy Dashboard

1. **Overview Tab**:
   - Container status (running/stopped)
   - Resource usage (CPU/Memory)
   - Uptime
   - Health check status

2. **Logs Tab**:
   - Real-time container logs
   - Filter by level (info/warn/error)
   - Download logs
   - Log retention: 7 days

3. **Metrics Tab** (if enabled):
   - CPU usage over time
   - Memory usage over time
   - Network I/O
   - Disk I/O

#### Docker Commands

From CT180 or CT179:

```bash
# List Dokploy-managed containers
docker ps --filter label=com.dokploy.managed=true

# View logs
docker logs -f <container-name>

# Check resource usage
docker stats <container-name>

# Inspect container
docker inspect <container-name>
```

### Application Management

#### Start/Stop/Restart

**Via Dokploy UI**:
1. Navigate to application
2. Use control buttons:
   - ▶️ Start
   - ⏸️ Stop
   - 🔄 Restart

**Via Docker**:
```bash
docker stop <container-name>
docker start <container-name>
docker restart <container-name>
```

#### Update Application

**Manual Update**:
```bash
# Pull latest image
docker pull harbor.aglz.io:5000/dev/agl-hostman:latest

# Via Dokploy UI: Click "Redeploy"
# Or via Docker:
docker-compose up -d --force-recreate
```

**Automatic Update** (webhook):
- Push to Harbor triggers automatic deployment
- See [CI/CD Webhook Setup](#cicd-webhook-setup)

#### Rollback

1. Navigate to application in Dokploy
2. Go to **Deployments** tab
3. View deployment history
4. Click **Rollback** on previous version

Or via Docker:
```bash
docker pull harbor.aglz.io:5000/dev/agl-hostman:v1.0.0
docker-compose up -d --force-recreate
```

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Cannot Access Dokploy UI

**Symptoms**:
- Cannot connect to https://dok.aglz.io
- Timeout or connection refused

**Solutions**:

1. **Check Container Status**:
   ```bash
   ssh root@192.168.0.245 'pct status 180'
   ```

2. **Check Dokploy Service**:
   ```bash
   ssh root@192.168.0.180 'docker ps | grep dokploy'
   ```

3. **Restart Container**:
   ```bash
   ssh root@192.168.0.245 'pct restart 180'
   ```

4. **Check Cloudflare**:
   - Verify DNS points to correct IP
   - Check proxy status (should be orange cloud)

#### Issue 2: Cannot Pull from Harbor

**Symptoms**:
- `docker pull` fails
- "unauthorized" or "certificate" errors

**Solutions**:

1. **Login to Registry**:
   ```bash
   docker login harbor.aglz.io:5000
   # Username: admin
   # Password: SecurePass2025!
   ```

2. **Check Harbor Status**:
   ```bash
   curl -k https://harbor.aglz.io/api/v2.0/health
   ```

3. **Verify Network Connectivity**:
   ```bash
   ping harbor.aglz.io
   curl -I https://harbor.aglz.io
   ```

4. **Check Docker Credentials**:
   ```bash
   cat ~/.docker/config.json
   ```

#### Issue 3: Application Won't Start

**Symptoms**:
- Container exits immediately
- Health check failing
- Error in logs

**Solutions**:

1. **Check Logs**:
   ```bash
   docker logs <container-name>
   ```

2. **Verify Environment Variables**:
   - Check all required vars are set
   - Verify credentials are correct

3. **Test Health Endpoint**:
   ```bash
   curl http://localhost:3000/health
   ```

4. **Check Resource Limits**:
   - Increase memory limit if OOM
   - Check CPU usage

5. **Manual Container Test**:
   ```bash
   docker run -it --rm \
     -p 3001:3000 \
     -e NODE_ENV=development \
     harbor.aglz.io:5000/dev/agl-hostman:latest
   ```

#### Issue 4: Webhook Not Triggering

**Symptoms**:
- Push to Harbor doesn't trigger deployment
- No activity in Dokploy logs

**Solutions**:

1. **Test Webhook Manually**:
   ```bash
   curl -X POST https://dok.aglz.io/api/webhook/trigger/<app-id>/<secret>
   ```

2. **Check Harbor Webhook Logs**:
   - Login to Harbor
   - Go to project → Webhooks
   - View execution history

3. **Verify Webhook URL**:
   - Ensure URL is correct
   - Check if app-id and secret match

4. **Check Network Access**:
   - Harbor must be able to reach dok.aglz.io
   - Check firewall rules

#### Issue 5: High Resource Usage

**Symptoms**:
- Container using excessive CPU/memory
- Host performance degraded

**Solutions**:

1. **Check Resource Usage**:
   ```bash
   docker stats <container-name>
   ```

2. **Adjust Resource Limits**:
   - Edit application in Dokploy
   - Increase/decrease limits as needed

3. **Check for Memory Leaks**:
   - Monitor over time
   - Restart container periodically
   - Review application logs

4. **Optimize Application**:
   - Enable production mode
   - Review code for inefficiencies

### Diagnostic Commands

```bash
# Check Dokploy system status
curl -k http://192.168.0.180:3000/api/health

# List all containers
docker ps -a

# Check Docker logs
docker logs dokploy

# Verify network connectivity
ping 192.168.0.180
curl http://192.168.0.180:3000

# Check Docker daemon
systemctl status docker

# View Docker events
docker events --since 1h

# Check disk space
df -h /var/lib/docker
```

### Password Recovery

If you lose admin password:

1. **SSH to CT180**:
   ```bash
   ssh root@192.168.0.180
   ```

2. **Reset via Dokploy CLI**:
   ```bash
   dokploy admin reset-password
   ```

3. **Or via Docker**:
   ```bash
   docker exec -it dokploy sh
   # Follow prompts to reset password
   ```

### Logs Location

**Dokploy Logs**:
```bash
# Container logs
docker logs dokploy

# Application logs
docker logs <app-container-name>

# Docker daemon logs
journalctl -u docker -f
```

---

## 🎯 Next Steps

### Recommended Setup Sequence

1. ✅ **Phase 1: Initial Setup** (Current)
   - Access Dokploy UI
   - Configure Harbor registry
   - Review system settings

2. 🔄 **Phase 2: Test Deployment**
   - Deploy simple test application (nginx)
   - Verify health checks work
   - Test start/stop/restart

3. 📦 **Phase 3: Deploy agl-hostman**
   - Build Docker image
   - Push to Harbor
   - Deploy via Dokploy
   - Configure environment variables

4. 🔗 **Phase 4: CI/CD Integration**
   - Configure Harbor webhooks
   - Test automated deployments
   - Set up monitoring alerts

5. 🚀 **Phase 5: Production Ready**
   - Configure custom domains
   - Set up SSL certificates
   - Enable monitoring/alerting
   - Document runbooks

### Quick Test Deployment

Deploy nginx to verify everything works:

```bash
# In Dokploy UI, create new application
Name: test-nginx
Image: nginx:alpine
Port: 80 → 8080
Health Check: GET / (port 80)

# Deploy and verify
curl http://192.168.0.180:8080
```

---

## 📚 Resources

### Official Documentation
- **Dokploy**: https://docs.dokploy.com
- **Docker**: https://docs.docker.com
- **Harbor**: https://goharbor.io/docs/

### Internal Documentation
- **INFRA.md**: Infrastructure overview and network topology
- **ARCHON.md**: Archon MCP integration
- **WORKFLOWS.md**: Development workflows

### Support
- **Dokploy Discord**: https://discord.com/invite/2tBnJ3jDJc
- **Dokploy GitHub**: https://github.com/dokploy/dokploy
- **Internal**: File issues in agl-hostman repository

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: Claude Code (agl-hostman project)
**Status**: Ready for testing
