# Dokploy Integration Guide

## Overview

AGL Hostman integrates with Dokploy for application deployment automation, enabling continuous delivery workflows, Docker/Docker Compose deployments, and seamless git-based deployments.

## Architecture

```mermaid
graph LR
    A[AGL Hostman] -->|API| B[Dokploy]
    B -->|Docker| C[Docker Engine]
    C --> D[Containers]

    B -->|Git Integration| E[Git Repositories]
    E --> F[GitHub/GitLab]

    B -->|Traefik| G[Traefik Proxy]
    G --> H[HTTPS Routing]

    style A fill:#4A90E2
    style B fill:#9B59B6
    style C fill:#2496ED
    style D fill:#50C878
    style E fill:#F05032
    style G fill:#E94B3C
```

## Prerequisites

### Dokploy Setup
1. **Dokploy Instance:** Deployed and accessible
2. **Docker:** Docker and Docker Compose installed
3. **Git:** Access to application repositories
4. **Domain:** Wildcard DNS configured for Traefik

### Required Permissions
```properties
Dokploy User Permissions:
- Application: Create, Read, Update, Delete
- Deployment: Deploy, Restart, Stop, Delete
- Settings: Read
- Compose: Create, Read, Update, Delete
- Domain: Create, Read, Update, Delete
```

## Configuration

### Environment Variables
```env
# Dokploy API Configuration
DOKPLOY_HOST=https://dokploy.agl.io
DOKPLOY_API_TOKEN=your-dokploy-api-token-here
DOKPLOY_TIMEOUT=120

# Docker Registry (if using private registry)
DOCKER_REGISTRY=harbor.agl.io
DOCKER_REGISTRY_USERNAME=agl-hostman
DOCKER_REGISTRY_PASSWORD=your-registry-password

# Git Configuration (if using private repos)
GIT_SSH_PRIVATE_KEY=path/to/private/key
GIT_USERNAME=agl-deploy
GIT_TOKEN=github-pat-token
```

### API Token Creation
```bash
# 1. Login to Dokploy web UI
# 2. Settings → API Tokens
# 3. Click "Generate Token"
# 4. Name: AGL Hostman Integration
# 5. Permissions: Application (Read/Write), Deployment (Execute)
# 6. Copy token (shown only once!)
# 7. Add to AGL Hostman .env file
```

### Service Configuration
```php
// config/dokploy.php
return [
    'host' => env('DOKPLOY_HOST'),
    'api_token' => env('DOKPLOY_API_TOKEN'),
    'timeout' => env('DOKPLOY_TIMEOUT', 120),

    'docker' => [
        'registry' => env('DOCKER_REGISTRY'),
        'username' => env('DOCKER_REGISTRY_USERNAME'),
        'password' => env('DOCKER_REGISTRY_PASSWORD'),
    ],

    'git' => [
        'ssh_key' => env('GIT_SSH_PRIVATE_KEY'),
        'username' => env('GIT_USERNAME'),
        'token' => env('GIT_TOKEN'),
    ],
];
```

## API Usage

### Service Initialization
```php
use App\Services\DokployService;

class DeploymentController extends Controller
{
    protected $dokploy;

    public function __construct(DokployService $dokploy)
    {
        $this->dokploy = $dokploy;
    }
}
```

### Common Operations

#### 1. List All Applications
```php
public function index()
{
    $applications = $this->dokploy->getApplications();

    return response()->json([
        'data' => $applications,
        'count' => count($applications)
    ]);
}
```

#### 2. Get Application Details
```php
public function show($applicationId)
{
    $application = $this->dokploy->getApplication($applicationId);

    // Get deployments history
    $deployments = $this->dokploy->getApplicationDeployments($applicationId);

    // Get application domains
    $domains = $this->dokploy->getApplicationDomains($applicationId);

    return response()->json([
        'data' => [
            'application' => $application,
            'deployments' => $deployments,
            'domains' => $domains
        ]
    ]);
}
```

#### 3. Create Application
```php
public function store(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string|unique:applications,name',
        'type' => 'required|in:docker,compose,dockerfile,git',
        'repository' => 'nullable|string',  // For git-based deployments
        'branch' => 'nullable|string',  // Default: main
        'build_command' => 'nullable|string',
        'start_command' => 'nullable|string',
        'environment_variables' => 'nullable|array',
        'ports' => 'nullable|array',
        'domains' => 'nullable|array',
        'compose_config' => 'nullable|array',  // For compose applications
    ]);

    $application = $this->dokploy->createApplication($validated);

    return response()->json([
        'data' => $application,
        'message' => 'Application created successfully'
    ], 201);
}
```

#### 4. Create Docker Application
```php
public function createDockerApplication(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string',
        'image' => 'required|string',  // e.g., 'nginx:latest'
        'environment_variables' => 'nullable|array',
        'ports' => 'nullable|array',  // ['80:80', '443:443']
        'volumes' => 'nullable|array',  // ['/host/path:/container/path']
        'domains' => 'nullable|array',  // ['app1.agl.io']
    ]);

    $application = $this->dokploy->createDockerApplication($validated);

    return response()->json([
        'data' => $application
    ], 201);
}
```

#### 5. Create Docker Compose Application
```php
public function createComposeApplication(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string',
        'compose_file' => 'required|string',  // YAML content or URL
        'type' => 'in:file,git',  // Compose file type
        'repository' => 'nullable|string',  // If type=git
        'branch' => 'nullable|string',  // Default: main
        'environment_variables' => 'nullable|array',
    ]);

    $application = $this->dokploy->createComposeApplication($validated);

    return response()->json([
        'data' => $application
    ], 201);
}
```

#### 6. Create Git-Based Application
```php
public function createGitApplication(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string',
        'repository' => 'required|string',  // e.g., 'github.com/agl/myapp.git'
        'branch' => 'required|string',  // e.g., 'main', 'develop'
        'build_command' => 'required|string',  // e.g., 'npm run build'
        'start_command' => 'required|string',  // e.g., 'npm start'
        'environment_variables' => 'nullable|array',
        'domains' => 'nullable|array',
        'install_command' => 'nullable|string',  // e.g., 'npm install'
        'dockerfile' => 'nullable|string',  // Custom Dockerfile path
    ]);

    $application = $this->dokploy->createGitApplication($validated);

    return response()->json([
        'data' => $application
    ], 201);
}
```

#### 7. Trigger Deployment
```php
public function deploy(Request $request, $applicationId)
{
    $validated = $request->validate([
        'type' => 'in:manual,git,webhook',
        'branch' => 'nullable|string',
        'commit_hash' => 'nullable|string',
        'environment_variables' => 'nullable|array',
    ]);

    $deployment = $this->dokploy->createDeployment(
        $applicationId,
        $validated
    );

    return response()->json([
        'data' => $deployment,
        'message' => 'Deployment initiated'
    ], 202);
}
```

#### 8. Get Deployment Status
```php
public function deploymentStatus($deploymentId)
{
    $status = $this->dokploy->getDeploymentStatus($deploymentId);

    return response()->json([
        'data' => [
            'deployment_id' => $deploymentId,
            'status' => $status['status'],  // building, deploying, success, failed
            'progress' => $status['progress'],  // 0-100
            'current_step' => $status['current_step'],
            'logs' => $status['logs'],
            'started_at' => $status['started_at'],
            'completed_at' => $status['completed_at'],
            'duration' => $status['duration'],
        ]
    ]);
}
```

#### 9. Get Deployment Logs
```php
public function deploymentLogs($deploymentId)
{
    $logs = $this->dokploy->getDeploymentLogs($deploymentId);

    return response()->json([
        'data' => [
            'deployment_id' => $deploymentId,
            'logs' => $logs,
        ]
    ]);
}
```

#### 10. Stop Application
```php
public function stop($applicationId)
{
    try {
        $this->dokploy->stopApplication($applicationId);

        return response()->json([
            'message' => 'Application stopped successfully'
        ], 200);
    } catch (\Exception $e) {
        return response()->json([
            'error' => 'Failed to stop application',
            'message' => $e->getMessage()
        ], 500);
    }
}
```

#### 11. Restart Application
```php
public function restart($applicationId)
{
    try {
        $this->dokploy->restartApplication($applicationId);

        return response()->json([
            'message' => 'Application restart initiated'
        ], 202);
    } catch (\Exception $e) {
        return response()->json([
            'error' => 'Failed to restart application',
            'message' => $e->getMessage()
        ], 500);
    }
}
```

#### 12. Delete Application
```php
public function destroy($applicationId)
{
    try {
        // Stop application first
        $this->dokploy->stopApplication($applicationId);

        // Delete application
        $this->dokploy->deleteApplication($applicationId);

        return response()->json([
            'message' => 'Application deleted successfully'
        ], 200);
    } catch (\Exception $e) {
        return response()->json([
            'error' => 'Failed to delete application',
            'message' => $e->getMessage()
        ], 500);
    }
}
```

## Real-Time Updates

### WebSocket Events
AGL Hostman broadcasts real-time deployment progress via WebSocket.

### Event: DeploymentProgressUpdated
**Channel:** `deployments.{deploymentId}`

**Event Data:**
```javascript
{
  eventType: "deployment.progress.updated",
  deploymentId: "dep_123",
  applicationId: "app_456",
  status: "deploying",  // building, deploying, success, failed
  progress: 65,  // 0-100
  currentStep: "Pulling Docker image",
  logs: "Pulling image from registry...",
  startedAt: "2026-01-16T10:00:00Z",
  estimatedCompletion: "2026-01-16T10:05:00Z",
  environment: "production",
  branch: "main",
  commitHash: "abc123def456"
}
```

### Frontend Subscription
```javascript
import Echo from 'laravel-echo';

// Subscribe to deployment updates
Echo.channel(`deployments.${deploymentId}`)
  .listen('.deployment.progress.updated', (data) => {
    console.log(`Deployment ${data.deploymentId}: ${data.progress}%`);
    console.log(`Current step: ${data.currentStep}`);

    // Update UI
    updateDeploymentProgress(data.deploymentId, {
      progress: data.progress,
      status: data.status,
      currentStep: data.currentStep,
      logs: data.logs
    });
  });
```

## Application Types

### 1. Docker Image Deployment
**Use case:** Simple containerized applications

**Configuration:**
```json
{
  "name": "nginx-server",
  "type": "docker",
  "image": "nginx:latest",
  "ports": ["80:80", "443:443"],
  "environment_variables": {
    "NGINX_HOST": "app.agl.io"
  },
  "domains": ["app.agl.io"]
}
```

### 2. Docker Compose Deployment
**Use case:** Multi-container applications

**Compose File:**
```yaml
version: '3.8'
services:
  app:
    image: node:18-alpine
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    depends_on:
      - database

  database:
    image: postgres:15
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=secret
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

**API Request:**
```json
{
  "name": "fullstack-app",
  "type": "compose",
  "compose_file": "<yaml_content_or_url>",
  "compose_type": "file"
}
```

### 3. Git-Based Deployment
**Use case:** Applications built from source

**Configuration:**
```json
{
  "name": "react-app",
  "type": "git",
  "repository": "github.com/agl/react-app.git",
  "branch": "main",
  "build_command": "npm run build",
  "start_command": "npm start",
  "install_command": "npm install",
  "environment_variables": {
    "NODE_ENV": "production",
    "API_URL": "https://api.agl.io"
  },
  "domains": ["react.agl.io"]
}
```

## Domain & Routing

### Add Custom Domain
```php
public function addDomain(Request $request, $applicationId)
{
    $validated = $request->validate([
        'domain' => 'required|string',
        'port' => 'nullable|integer',
        'certificate_id' => 'nullable|string',  // For SSL
    ]);

    $domain = $this->dokploy->addApplicationDomain(
        $applicationId,
        $validated
    );

    return response()->json([
        'data' => $domain
    ], 201);
}
```

### Configure SSL/TLS
```php
public function configureSSL(Request $request, $applicationId)
{
    $validated = $request->validate([
        'domain' => 'required|string',
        'email' => 'required|email',  // For Let's Encrypt
        'provider' => 'in:letsencrypt,custom',
    ]);

    $ssl = $this->dokploy->configureDomainSSL(
        $applicationId,
        $validated
    );

    return response()->json([
        'data' => $ssl,
        'message' => 'SSL configuration initiated'
    ], 202);
}
```

## Webhook Integration

### GitHub Webhook
```php
// Route: /api/webhooks/dokploy/github
public function handleGitHubWebhook(Request $request)
{
    $payload = $request->all();
    $repository = $payload['repository']['full_name'];
    $branch = str_replace('refs/heads/', '', $payload['ref']);
    $commitHash = $payload['after'];

    // Find application by repository
    $application = Application::where('repository', 'like', "%{$repository}%")
        ->first();

    if ($application) {
        // Trigger deployment
        $this->dokploy->createDeployment($application->id, [
            'type' => 'webhook',
            'branch' => $branch,
            'commit_hash' => $commitHash
        ]);
    }

    return response()->json(['status' => 'success']);
}
```

### GitLab Webhook
```php
// Route: /api/webhooks/dokploy/gitlab
public function handleGitLabWebhook(Request $request)
{
    $payload = $request->all();
    $repository = $payload['project']['git_http_url'];
    $branch = $payload['ref'];
    $commitHash = $payload['after'];

    // Similar to GitHub webhook handler
    // ...

    return response()->json(['status' => 'success']);
}
```

## Environment Variables

### Set Application Environment Variables
```php
public function updateEnvironmentVariables(Request $request, $applicationId)
{
    $validated = $request->validate([
        'environment_variables' => 'required|array',
        'environment_variables.*.key' => 'required|string',
        'environment_variables.*.value' => 'required|string',
    ]);

    $env = $this->dokploy->updateApplicationEnvironment(
        $applicationId,
        $validated['environment_variables']
    );

    return response()->json([
        'data' => $env
    ]);
}
```

### Mask Sensitive Variables
```php
// Mask sensitive variables in logs
$maskedEnv = [
    'key' => 'DATABASE_URL',
    'value' => 'postgresql://user:***@host:5432/db',
    'masked' => true
];
```

## Deployment Strategies

### Blue-Green Deployment
```php
public function blueGreenDeploy(Request $request, $applicationId)
{
    // Deploy to green environment
    $greenDeployment = $this->dokploy->createDeployment($applicationId, [
        'environment_variables' => [
            'DEPLOY_COLOR' => 'green'
        ]
    ]);

    // Wait for green to be healthy
    $this->waitForHealthy($greenDeployment['id']);

    // Switch traffic to green
    $this->switchTraffic($applicationId, 'green');

    return response()->json([
        'message' => 'Blue-green deployment successful'
    ]);
}
```

### Rolling Deployment
```php
public function rollingDeploy(Request $request, $applicationId)
{
    $instances = $this->dokploy->getApplicationInstances($applicationId);

    foreach ($instances as $instance) {
        // Update instance one by one
        $this->dokploy->updateInstance($instance['id']);
        $this->waitForHealthy($instance['id']);
    }

    return response()->json([
        'message' => 'Rolling deployment successful'
    ]);
}
```

## Troubleshooting

### Common Issues

#### Issue: Build Failures
**Error:** `Build failed with exit code 1`

**Solutions:**
1. Check build logs for specific errors
2. Verify build command is correct
3. Check if dependencies are installable
4. Verify Dockerfile syntax (if using custom Dockerfile)

```php
// Get detailed build logs
$logs = $this->dokploy->getDeploymentLogs($deploymentId, 'build');
```

#### Issue: Deployment Timeout
**Error:** `Deployment timed out after 120 seconds`

**Solutions:**
1. Increase deployment timeout
2. Check application startup time
3. Verify health check configuration
4. Add explicit health check endpoint

```php
// Increase timeout for specific application
$this->dokploy->setDeploymentTimeout($applicationId, 300); // 5 minutes
```

#### Issue: Container Keeps Restarting
**Error:** `Container exited with code 1`

**Solutions:**
1. Check container logs for errors
2. Verify start command is correct
3. Check environment variables
4. Verify port bindings

```bash
# Get container logs
docker logs <container_id> --tail=100

# Check container status
docker ps -a | grep <application_name>
```

## Best Practices

### 1. Use .dockerignore
```dockerignore
# Exclude unnecessary files from build
node_modules
npm-debug.log
.git
.env
tests
coverage
.vscode
```

### 2. Multi-Stage Builds
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --only=production
CMD ["npm", "start"]
```

### 3. Health Checks
```yaml
# docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 4. Resource Limits
```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### 5. Logging Configuration
```yaml
# docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Monitoring & Metrics

### Application Metrics
```php
// Get application metrics
$metrics = $this->dokploy->getApplicationMetrics($applicationId);

return response()->json([
    'data' => [
        'cpu_usage' => $metrics['cpu'],
        'memory_usage' => $metrics['memory'],
        'network_in' => $metrics['netin'],
        'network_out' => $metrics['netout'],
        'container_count' => $metrics['containers'],
        'uptime' => $metrics['uptime']
    ]
]);
```

### Alerting
```yaml
# config/alerts.yml
dokploy:
  deployments:
    duration_warning: 300  # 5 minutes
    duration_critical: 600  # 10 minutes
  containers:
    restart_threshold: 3  # Alert after 3 restarts
    memory_warning: 80
    memory_critical: 95
```

## API Reference

### Endpoints
```http
# Applications
GET    /api/dokploy/applications
POST   /api/dokploy/applications
GET    /api/dokploy/applications/{id}
PUT    /api/dokploy/applications/{id}
DELETE /api/dokploy/applications/{id}

# Deployments
GET    /api/dokploy/applications/{id}/deployments
POST   /api/dokploy/applications/{id}/deploy
GET    /api/dokploy/deployments/{id}
GET    /api/dokploy/deployments/{id}/logs
POST   /api/dokploy/deployments/{id}/cancel

# Application Control
POST   /api/dokploy/applications/{id}/start
POST   /api/dokploy/applications/{id}/stop
POST   /api/dokploy/applications/{id}/restart

# Domains
GET    /api/dokploy/applications/{id}/domains
POST   /api/dokploy/applications/{id}/domains
DELETE /api/dokploy/applications/{id}/domains/{domain_id}

# Environment Variables
GET    /api/dokploy/applications/{id}/environment
PUT    /api/dokploy/applications/{id}/environment

# Webhooks
POST   /api/webhooks/dokploy/github
POST   /api/webhooks/dokploy/gitlab
```

## Related Documentation

- [Proxmox Integration](./proxmox.md) - Container management
- [Harbor Integration](./harbor.md) - Container registry
- [WebSocket Events](../websocket/events.md) - Real-time deployment events
- [Deployment Overview](../deployments/overview.md) - Deployment strategies
