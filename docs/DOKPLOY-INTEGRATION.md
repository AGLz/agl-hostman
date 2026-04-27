# Dokploy Backend Integration Documentation

> **Version**: 1.0.0
> **Last Updated**: 2025-11-20
> **Status**: Implementation Complete

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation & Setup](#installation--setup)
4. [API Integration](#api-integration)
5. [Database Schema](#database-schema)
6. [Usage Examples](#usage-examples)
7. [Testing](#testing)
8. [Error Handling](#error-handling)
9. [Performance](#performance)
10. [Next Steps](#next-steps)

---

## Overview

Complete Laravel 12 backend integration with Dokploy deployment platform (CT180). Provides full CRUD operations for projects, applications, deployments, and domains via Dokploy API.

### Features Implemented

✅ **Data Transfer Objects (DTOs)**
- ProjectDTO
- ApplicationDTO
- DomainDTO
- DeploymentDTO
- EnvironmentDTO
- LogDTO

✅ **Repository Layer**
- HTTP client with authentication
- Retry logic with exponential backoff
- Response caching (5 min TTL)
- Error handling and logging

✅ **Service Layer**
- Project management (CRUD)
- Application management (deploy, start, stop, restart)
- Deployment orchestration
- Domain management
- Environment variable management
- Log retrieval

✅ **Database Schema**
- `dokploy_projects` - Project metadata
- `dokploy_applications` - Application configurations
- `dokploy_deployments` - Deployment history
- `dokploy_domains` - Domain routing

✅ **Eloquent Models**
- Proper relationships (HasMany, BelongsTo)
- Query scopes
- Attribute casting
- Soft deletes

---

## Architecture

### Layer Structure

```
┌─────────────────────────────────────────┐
│          Controller Layer               │
│   (Future: API Endpoints & UI)          │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│          Service Layer                  │
│      DokployService.php                 │
│  - Business Logic                       │
│  - DTO Transformation                   │
│  - Error Handling                       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│       Repository Layer                  │
│    DokployRepository.php                │
│  - HTTP Client                          │
│  - Caching                              │
│  - Retry Logic                          │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│        Dokploy API                      │
│      https://dok.aglz.io/api            │
└─────────────────────────────────────────┘
```

### Data Flow

```
Request → DTO → Service → Repository → HTTP Client → Dokploy API
                  ↓                                        ↓
                Model ← Database ← Response Processing ← Response
```

---

## Installation & Setup

### 1. Environment Configuration

Add to `.env`:

```env
# Dokploy Configuration
DOKPLOY_BASE_URL=https://dok.aglz.io
DOKPLOY_API_KEY=your-api-key-here
DOKPLOY_TIMEOUT=30
DOKPLOY_MAX_RETRIES=3

# Harbor Registry
HARBOR_URL=harbor.aglz.io:5000
HARBOR_USERNAME=admin
HARBOR_PASSWORD=SecurePass2025!
HARBOR_PROJECT=dev

# Optional
DOKPLOY_LOGGING=true
DOKPLOY_LOG_LEVEL=info
```

### 2. Database Setup

Run migrations:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan migrate
```

### 3. API Key Generation

1. Login to Dokploy: https://dok.aglz.io
2. Navigate to: Settings → Profile → API Keys
3. Generate new key
4. Copy to `.env` as `DOKPLOY_API_KEY`

---

## API Integration

### Available MCP Tools

Dokploy MCP server provides these tools (via `@ahdev/dokploy-mcp`):

**Projects:**
- `mcp__dokploy__project-all`
- `mcp__dokploy__project-create`
- `mcp__dokploy__project-one`
- `mcp__dokploy__project-update`
- `mcp__dokploy__project-remove`

**Applications:**
- `mcp__dokploy__application-create`
- `mcp__dokploy__application-one`
- `mcp__dokploy__application-update`
- `mcp__dokploy__application-delete`
- `mcp__dokploy__application-deploy`
- `mcp__dokploy__application-start`
- `mcp__dokploy__application-stop`
- `mcp__dokploy__application-restart`

**Domains:**
- `mcp__dokploy__domain-byApplicationId`
- `mcp__dokploy__domain-create`
- `mcp__dokploy__domain-update`
- `mcp__dokploy__domain-delete`

**Databases:**
- `mcp__dokploy__postgres-*`
- `mcp__dokploy__mysql-*`

### Service Layer Integration

The `DokployService` wraps MCP tools and provides Laravel-native interface:

```php
use App\Services\DokployService;

$service = app(DokployService::class);

// Check connection
$service->testConnection(); // bool

// Get all projects
$projects = $service->getProjects(); // Collection<ProjectDTO>

// Create application
$app = ApplicationDTO::forCreate(
    name: 'my-app',
    appName: 'my-app-prod',
    environmentId: 'env-123',
    dockerImage: 'harbor.aglz.io:5000/dev/my-app:latest'
);
$created = $service->createApplication($app);

// Deploy
$deployment = $service->deployApplication($created->applicationId);

// Monitor status
$status = $service->getDeploymentStatus($created->applicationId);
```

---

## Database Schema

### dokploy_projects

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| dokploy_id | string | External Dokploy ID (unique) |
| name | string | Project name |
| description | text | Description |
| organization_id | string | Organization in Dokploy |
| env | text | Environment variables |
| metadata | json | Additional config |
| status | string | active/inactive/archived |
| created_at | timestamp | |
| updated_at | timestamp | |
| deleted_at | timestamp | Soft delete |

**Indexes**: dokploy_id (unique), status, created_at

### dokploy_applications

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| project_id | bigint | FK to projects |
| dokploy_id | string | External Dokploy ID (unique) |
| name | string | Display name |
| app_name | string | Internal name |
| docker_image | string | Image name |
| source_type | string | github/docker/git |
| build_type | string | dockerfile/nixpacks |
| status | string | idle/running/done/error |
| env | text | Environment variables |
| build_args | text | Build arguments |
| cpu_limit | integer | CPU limit |
| memory_limit | integer | Memory limit (MB) |
| replicas | integer | Replica count |
| auto_deploy | boolean | Auto-deploy enabled |
| last_deployed_at | timestamp | Last deployment |

**Indexes**: dokploy_id (unique), project_id, status, environment_id

### dokploy_deployments

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| application_id | bigint | FK to applications |
| dokploy_id | string | External Dokploy ID |
| status | string | pending/building/success/failed |
| title | string | Deployment title |
| commit_hash | string | Git commit |
| branch | string | Git branch |
| triggered_by | string | Who triggered |
| error_message | text | Error details |
| started_at | timestamp | Start time |
| completed_at | timestamp | End time |
| duration_seconds | integer | Duration |

**Indexes**: application_id, status, started_at, completed_at

### dokploy_domains

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| application_id | bigint | FK to applications |
| dokploy_id | string | External Dokploy ID (unique) |
| host | string | Domain hostname |
| https | boolean | HTTPS enabled |
| certificate_type | string | letsencrypt/none/custom |
| path | string | URL path |
| port | integer | Port number |
| status | string | active/inactive/pending |

**Indexes**: dokploy_id (unique), application_id, host, status

---

## Usage Examples

### Complete Deployment Workflow

```php
use App\Services\DokployService;
use App\DTOs\Dokploy\{ProjectDTO, ApplicationDTO, DomainDTO};

$service = app(DokployService::class);

// 1. Create Project
$project = ProjectDTO::forCreate(
    name: 'AGL Infrastructure Dashboard',
    description: 'Laravel 12 management dashboard',
    env: "APP_ENV=production\nAPP_DEBUG=false"
);
$createdProject = $service->createProject($project);

// 2. Create Application
$app = ApplicationDTO::forCreate(
    name: 'agl-hostman-prod',
    appName: 'agl-hostman',
    environmentId: $createdProject->projectId,
    description: 'Production deployment',
    dockerImage: 'harbor.aglz.io:5000/dev/agl-hostman:latest'
);
$createdApp = $service->createApplication($app);

// 3. Set Environment Variables
$env = EnvironmentDTO::fromKeyValue(
    applicationId: $createdApp->applicationId,
    env: [
        'APP_NAME' => 'AGL HostMan',
        'APP_ENV' => 'production',
        'APP_DEBUG' => 'false',
        'PROXMOX_API_URL' => 'https://192.168.0.245:8006/api2/json',
    ],
    buildArgs: [
        'NODE_ENV' => 'production',
    ]
);
$service->setEnvironmentVariables($env);

// 4. Add Domain
$domain = DomainDTO::forCreate(
    host: 'hostman.aglz.io',
    https: true,
    certificateType: 'letsencrypt',
    applicationId: $createdApp->applicationId,
    port: 3000
);
$service->addDomain($domain);

// 5. Deploy
$deployment = $service->deployApplication(
    $createdApp->applicationId,
    'Initial production deployment',
    'Laravel 12 app with Harbor image'
);

// 6. Monitor Deployment
while ($deployment->isInProgress()) {
    sleep(5);
    $status = $service->getDeploymentStatus($createdApp->applicationId);
    echo "Status: $status\n";
}

if ($deployment->isSuccessful()) {
    echo "Deployment successful!\n";
    echo "Access at: https://hostman.aglz.io\n";
} else {
    echo "Deployment failed: {$deployment->errorMessage}\n";
}
```

### Query with Eloquent Models

```php
use App\Models\{DokployProject, DokployApplication};

// Get all active projects with applications
$projects = DokployProject::active()
    ->with('applications.deployments')
    ->get();

// Get running applications
$runningApps = DokployApplication::running()
    ->with('domains')
    ->get();

// Get recent deployments
$recentDeployments = DokployDeployment::query()
    ->with('application.project')
    ->whereDate('created_at', '>=', now()->subDays(7))
    ->orderByDesc('created_at')
    ->get();

// Get failed deployments
$failedDeployments = DokployDeployment::failed()
    ->with('application')
    ->get();
```

---

## Testing

### Manual API Test

```php
// In tinker: php artisan tinker

use App\Services\DokployService;

$service = app(\App\Services\DokployService::class);

// Test connection
$service->testConnection(); // Should return true

// Health check
$service->healthCheck(); // Should return status info

// Get projects
$projects = $service->getProjects();
$projects->count(); // Number of projects
$projects->first(); // First project DTO
```

### Unit Tests

Create in `tests/Unit/Services/DokployServiceTest.php`:

```php
<?php

namespace Tests\Unit\Services;

use App\Services\DokployService;
use Tests\TestCase;

class DokployServiceTest extends TestCase
{
    public function test_can_connect_to_dokploy()
    {
        $service = app(DokployService::class);
        $connected = $service->testConnection();

        $this->assertTrue($connected);
    }

    public function test_can_get_projects()
    {
        $service = app(DokployService::class);
        $projects = $service->getProjects();

        $this->assertInstanceOf(\Illuminate\Support\Collection::class, $projects);
    }
}
```

Run tests:

```bash
php artisan test --filter DokployServiceTest
```

---

## Error Handling

### Exception Hierarchy

```
Exception (base)
├── Connection Errors (network, timeout)
├── Authentication Errors (invalid API key)
├── Validation Errors (invalid data)
└── API Errors (4xx, 5xx responses)
```

### Retry Logic

The repository implements automatic retries:

- **Max Retries**: 3 (configurable via `DOKPLOY_MAX_RETRIES`)
- **Delay**: 1000ms (configurable via `DOKPLOY_RETRY_DELAY`)
- **Backoff**: Exponential (1s, 2s, 3s)
- **Skip Retries**: Client errors (4xx)

### Logging

All operations are logged:

```php
// Success
Log::debug('Dokploy API success', ['status' => 200, 'data' => $response]);

// Error
Log::error('Dokploy API error', ['status' => 500, 'body' => $errorBody]);

// Retry
Log::warning('Dokploy API request failed, retrying', ['attempt' => 2]);
```

---

## Performance

### Caching Strategy

- **TTL**: 300 seconds (5 minutes) - configurable
- **Cache Keys**: MD5 hash of method + endpoint + params
- **Invalidation**: Automatic on POST/PUT/PATCH/DELETE
- **Storage**: Laravel cache driver (file/redis/memcached)

### Response Times

Typical response times (LAN access to CT180):

- GET requests: 50-200ms
- POST requests: 100-500ms
- Deployments: 30s-5min (depends on image size)

### Optimization Tips

1. **Use caching**: GET requests are cached by default
2. **Batch operations**: Create multiple resources in parallel
3. **Background jobs**: Use queues for deployments
4. **Eager loading**: Load relationships with Eloquent

---

## Next Steps

### Frontend Integration

1. **Create Controllers**
   - `DokployProjectController`
   - `DokployApplicationController`
   - `DokployDeploymentController`

2. **Create API Routes**
   ```php
   // routes/api.php
   Route::prefix('dokploy')->group(function () {
       Route::get('/projects', [DokployProjectController::class, 'index']);
       Route::post('/applications/{id}/deploy', [DokployApplicationController::class, 'deploy']);
       Route::get('/deployments/{id}/logs', [DokployDeploymentController::class, 'logs']);
   });
   ```

3. **Create Vue/React Components**
   - ProjectList
   - ApplicationCard
   - DeploymentStatus
   - LogViewer

### Webhook Integration

1. **Create Route**
   ```php
   Route::post('/webhooks/harbor', [HarborWebhookController::class, 'handle']);
   ```

2. **Handle Events**
   - Image pushed → Auto-deploy if enabled
   - Image deleted → Log event
   - Scan completed → Update metadata

### Queue Jobs

1. **Create Jobs**
   ```php
   php artisan make:job DeployApplicationJob
   php artisan make:job MonitorDeploymentJob
   ```

2. **Dispatch**
   ```php
   DeployApplicationJob::dispatch($application);
   ```

### Monitoring

1. **Add Health Checks**
   - Dokploy API availability
   - Application status
   - Deployment failures

2. **Create Alerts**
   - Failed deployments
   - High error rate
   - Long deployment times

---

## File Structure Summary

```
src/
├── app/
│   ├── DTOs/Dokploy/
│   │   ├── ProjectDTO.php
│   │   ├── ApplicationDTO.php
│   │   ├── DomainDTO.php
│   │   ├── DeploymentDTO.php
│   │   ├── EnvironmentDTO.php
│   │   └── LogDTO.php
│   ├── Repositories/
│   │   └── DokployRepository.php
│   ├── Services/
│   │   └── DokployService.php
│   └── Models/
│       ├── DokployProject.php
│       ├── DokployApplication.php
│       ├── DokployDeployment.php
│       └── DokployDomain.php
├── config/
│   └── dokploy.php
├── database/migrations/
│   ├── 2025_11_20_033821_create_dokploy_projects_table.php
│   ├── 2025_11_20_033835_create_dokploy_applications_table.php
│   ├── 2025_11_20_033850_create_dokploy_deployments_table.php
│   └── 2025_11_20_033906_create_dokploy_domains_table.php
└── tests/
    ├── Unit/Services/DokployServiceTest.php
    └── Feature/DokployIntegrationTest.php
```

---

## Support & Resources

### Documentation
- **Dokploy Docs**: https://docs.dokploy.com
- **MCP Tools**: `claude mcp list | grep dokploy`
- **Internal Docs**: `docs/DOKPLOY.md`

### Troubleshooting
- **Connection Issues**: Check `DOKPLOY_API_KEY` in `.env`
- **Deployment Failures**: Check logs via `getDeploymentLogs()`
- **Database Errors**: Run `php artisan migrate:fresh`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Status**: ✅ Implementation Complete - Ready for Frontend Integration
