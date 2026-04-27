# Deployment Overview

## Introduction

AGL Hostman provides a comprehensive deployment automation system built on top of Dokploy, enabling seamless container deployments across multiple environments with approval gates, rollback capabilities, and real-time progress tracking.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AGL Hostman                              │
│                  Deployment Orchestrator                     │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├──► Laravel Backend (API, Events, Queues)
               │
               ├──► Dokploy Integration
               │     ├──► Docker & Docker Compose
               │     ├──► Git Integration
               │     └── Traefik Reverse Proxy
               │
               └──► WebSocket Events (Real-time Updates)
                     ├──► Deployment Progress
                     ├──► Container Status
                     └── System Metrics
```

## Supported Deployment Types

### 1. Docker Compose Deployments
Multi-container applications with Docker Compose configuration.

**Use cases:**
- Full-stack applications (frontend + backend + database)
- Microservices architectures
- Applications with multiple dependencies

**Configuration:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    image: node:18-alpine
    ports:
      - "3000:3000"
  database:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
```

### 2. Docker Image Deployments
Single-container deployments from Docker registry.

**Use cases:**
- Simple applications
- Stateless services
- API endpoints
- Background workers

**Configuration:**
```json
{
  "image": "registry.agl.io/myapp:latest",
  "ports": ["8080:8080"],
  "environment": {
    "NODE_ENV": "production"
  }
}
```

### 3. Git-Based Deployments
Deploy directly from Git repository with automatic builds.

**Use cases:**
- CI/CD pipelines
- Automated deployments
- Development workflows

**Configuration:**
```json
{
  "repository": "github.com/agl/myapp.git",
  "branch": "main",
  "buildCommand": "npm run build",
  "startCommand": "npm start"
}
```

## Environments

### Development (dev)
- **Purpose:** Active development and testing
- **Access:** All team members
- **Auto-deploy:** Enabled on feature branches
- **Resources:** Minimal (1 CPU, 512MB RAM)
- **Domain:** `*.dev.agl.io`

### Quality Assurance (qa)
- **Purpose:** Integration testing and QA
- **Access:** Developers + QA team
- **Auto-deploy:** Pull request merge to develop
- **Resources:** Medium (2 CPU, 2GB RAM)
- **Domain:** `*.qa.agl.io`

### User Acceptance Testing (uat)
- **Purpose:** Pre-production validation
- **Access:** Limited stakeholders
- **Auto-deploy:** Manual promotion from QA
- **Resources:** Production-like (4 CPU, 4GB RAM)
- **Domain:** `*.uat.agl.io`

### Production (production)
- **Purpose:** Live production environment
- **Access:** DevOps leads only
- **Auto-deploy:** Manual promotion from UAT
- **Resources:** High (8 CPU, 16GB RAM)
- **Domain:** `*.agl.io`

## Deployment Flow

### 1. Trigger Deployment
```bash
# Via API
POST /api/deployments
{
  "applicationId": "app_123",
  "environment": "production",
  "version": "v1.2.3",
  "config": { ... }
}

# Via Web UI
Dashboard → Application → Deploy Button
```

### 2. Build Phase
- Pull latest code from Git
- Build Docker image (if applicable)
- Run tests (configured in application)
- Tag image with version
- Push to Harbor registry

### 3. Deployment Phase
- Schedule deployment on target node
- Pull latest image from registry
- Stop existing containers (graceful shutdown)
- Start new containers
- Update Traefik routes
- Health check validation

### 4. Verification Phase
- Container health checks
- HTTP endpoint validation
- Smoke tests execution
- Performance metrics collection

### 5. Completion
- Update deployment status
- Trigger WebSocket events
- Send notifications
- Log deployment metrics

## WebSocket Events

### DeploymentProgressUpdated
Real-time deployment progress updates.

**Channel:** `deployments.{deploymentId}`

**Event Data:**
```javascript
{
  deploymentId: "dep_123",
  status: "deploying", // building, deploying, success, failed
  progress: 65, // 0-100
  currentStep: "Pulling Docker image",
  logs: "Pulling image from registry...",
  startedAt: "2026-01-16T10:00:00Z",
  estimatedCompletion: "2026-01-16T10:05:00Z"
}
```

**Subscription Example:**
```javascript
Echo.channel(`deployments.${deploymentId}`)
  .listen('.deployment.progress.updated', (data) => {
    console.log(`Progress: ${data.progress}% - ${data.currentStep}`);
  });
```

## Monitoring & Observability

### Deployment Metrics
- **Duration:** Total deployment time
- **Success Rate:** Percentage of successful deployments
- **Failure Rate:** Percentage of failed deployments
- **Rollback Rate:** Percentage of rollbacks triggered
- **Mean Time to Recovery (MTTR):** Average recovery time

### Real-Time Monitoring
```javascript
// Use the deployment progress hook
const { progress, lastUpdate, error } = useDeploymentProgress(
  deploymentId,
  (data) => {
    console.log('Deployment updated:', data);
  }
);
```

### Logs & Debugging
- Application logs: `docker logs <container>`
- Traefik logs: `/var/log/traefik/access.log`
- Deployment logs: Laravel logs `/storage/logs/deployment.log`

## Security Considerations

### Access Control
- Role-based deployment permissions (admin, advanced, common)
- API token authentication required
- Approval gates for production deployments
- Audit logging for all deployments

### Secrets Management
- Environment variables encrypted at rest
- Secrets stored in Laravel configuration
- No secrets in Git repository
- Automatic secret injection during deployment

### Network Security
- Traefik SSL/TLS termination
- Internal network isolation
- Firewall rules between environments
- VPN access for production servers

## Performance Optimization

### Deployment Strategies
- **Blue-Green:** Zero-downtime deployments
- **Rolling:** Gradual replacement of instances
- **Canary:** Test with subset of traffic
- **A/B Testing:** Run multiple versions simultaneously

### Resource Optimization
- Container resource limits (CPU, memory)
- Automatic horizontal scaling
- Load balancing with Traefik
- CDN for static assets

### Caching Strategy
- Redis cache for deployment status
- CDN for application artifacts
- Image layer caching in Docker
- Build cache reuse

## Troubleshooting

See [Troubleshooting Guide](./troubleshooting.md) for:
- Common deployment issues
- Health check failures
- Network connectivity problems
- Performance bottlenecks

## Related Documentation

- [Promotion Process](./promotion-process.md) - Environment promotion workflow
- [Rollbacks](./rollbacks.md) - Rollback procedures and strategies
- [API Documentation](../api/overview.md) - Deployment API reference
- [WebSocket Events](../websocket/events.md) - Real-time event reference

## Support

For deployment issues or questions:
- Check deployment logs in Dashboard
- Review troubleshooting guide
- Contact DevOps team via Slack #deployments
- Create issue in Linear (AGL Hostman project)
