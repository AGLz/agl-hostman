# Harbor Registry Skill

**Category**: Container Registry Management
**Based on**: `/src/app/Services/HarborApiClient.php`
**API Reference**: https://goharbor.io/docs/2.10.0/swagger-api-definitions/

## Overview

Expert in integrating with Harbor Container Registry, implementing circuit breaker patterns, retry logic, HTTP authentication, and managing container images, projects, repositories, and artifacts.

## Core Capabilities

### 1. Client Initialization

```php
use App\Services\HarborApiClient;

// From configuration
$harbor = new HarborApiClient();

// With explicit credentials
$harbor = new HarborApiClient(
    baseUrl: 'https://harbor.aglz.io',
    username: env('HARBOR_USERNAME'),
    password: env('HARBOR_PASSWORD')
);
```

### 2. Authentication

Uses HTTP Basic Authentication:

```php
// Automatically handled by the client
$http = Http::withBasicAuth($this->username, $this->password)
    ->timeout($this->timeout)
    ->acceptJson()
    ->asJson();
```

### 3. Circuit Breaker Pattern

Prevents cascading failures:

```php
$circuitBreaker = [
    'failures' => 0,
    'last_failure' => null,
    'threshold' => 5,      // Open after 5 failures
    'timeout' => 60,       // Retry after 60 seconds
];
```

Check circuit breaker status:
```php
$status = $harbor->getCircuitBreakerStatus();
// Returns:
// [
//     'is_open' => false,
//     'failures' => 2,
//     'threshold' => 5,
//     'last_failure' => null,
// ]
```

### 4. HTTP Methods

#### GET Request
```php
$response = $harbor->get('/api/v2.0/projects', [
    'page' => 1,
    'page_size' => 20,
]);

if ($response->isSuccess()) {
    $projects = $response->data;
}
```

#### POST Request
```php
$response = $harbor->post('/api/v2.0/projects', [
    'name' => 'my-project',
    'public' => false,
    'metadata' => [
        'public' => 'false',
    ],
]);
```

#### PUT Request
```php
$response = $harbor->put("/api/v2.0/projects/{$projectId}/scanner", [
    'scanner' => 'Trivy',
]);
```

#### DELETE Request
```php
$response = $harbor->delete("/api/v2.0/projects/{$projectId}");
```

### 5. Retry Logic

Automatic retry with exponential backoff:

```php
// Configuration
protected int $maxRetries = 3;

// Retry logic
while ($attempt < $this->maxRetries) {
    try {
        $response = $this->executeRequest(...);
        if ($response->successful()) {
            $this->resetCircuitBreaker();
            return $response;
        }
    } catch (Exception $e) {
        $attempt++;
        if ($attempt < $this->maxRetries) {
            usleep(500000 * $attempt);  // 0.5s, 1s, 1.5s
        }
    }
}
```

### 6. Connection Testing

Verify Harbor connectivity:

```php
if ($harbor->testConnection()) {
    echo "Harbor is accessible";
} else {
    Log::error('Harbor connection failed');
}
```

### 7. Common API Endpoints

#### Projects
```php
// List projects
$projects = $harbor->get('/api/v2.0/projects');

// Get project details
$project = $harbor->get("/api/v2.0/projects/{$projectId}");

// Create project
$harbor->post('/api/v2.0/projects', [
    'name' => 'new-project',
    'public' => false,
]);

// Delete project
$harbor->delete("/api/v2.0/projects/{$projectId}");
```

#### Repositories
```php
// List repositories in project
$repos = $harbor->get("/api/v2.0/projects/{$projectId}/repositories");

// Get repository details
$repo = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}");
```

#### Artifacts (Images)
```php
// List artifacts
$artifacts = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts");

// Get artifact details
$artifact = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}");

// Delete artifact
$harbor->delete("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}");
```

#### Tags
```php
// Get tags
$tags = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}/tags");
```

#### Vulnerability Scanning
```php
// Trigger scan
$harbor->post("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}/scan");

// Get scan results
$scan = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}");
```

#### System Info
```php
$info = $harbor->get('/api/v2.0/systeminfo');
// Returns version, storage info, etc.
```

### 8. Response Handling

```php
$response = $harbor->get('/api/v2.0/projects');

// Check success
if ($response->isSuccess()) {
    $data = $response->data;
}

// Check status code
if ($response->statusCode === 200) {
    // OK
}

// Handle error
if (!$response->isSuccess()) {
    $error = $response->error;
    Log::error('Harbor API error', ['error' => $error]);
}
```

## API Response DTO

```php
namespace App\DTOs;

class ApiResponse
{
    public function __construct(
        public readonly bool $success,
        public readonly array $data,
        public readonly string $error,
        public readonly int $statusCode
    ) {}

    public function isSuccess(): bool
    {
        return $this->success && $this->statusCode >= 200 && $this->statusCode < 300;
    }
}
```

## Configuration

```env
HARBOR_BASE_URL=https://harbor.aglz.io
HARBOR_USERNAME=admin
HARBOR_PASSWORD=secret
HARBOR_TIMEOUT=30
```

## Integration with Redis Cache

Cache Harbor responses to reduce API load:

```php
use App\Services\RedisCacheStrategy;

$cache = app(RedisCacheStrategy::class);

$repositories = $cache->cacheHarborResponse(
    resource: 'repositories',
    identifier: $projectId,
    callback: fn() => $harbor->get("/api/v2.0/projects/{$projectId}/repositories"),
    ttl: 'long'  // Harbor data changes less frequently
);
```

## Error Handling

### Circuit Breaker Open
```php
$response = $harbor->get('/api/v2.0/projects');
if (!$response->isSuccess() && $response->statusCode === 503) {
    Log::warning('Harbor circuit breaker open - using cached data');
    return Cache::get('harbor_projects_backup');
}
```

### Authentication Failure
```php
if ($response->statusCode === 401) {
    Log::error('Harbor authentication failed - check credentials');
    // Alert administrators
}
```

### Rate Limiting
```php
if ($response->statusCode === 429) {
    Log::warning('Harbor rate limit hit - backing off');
    sleep(5);
}
```

## Security Best Practices

### 1. Use Service Accounts
Create dedicated Harbor service accounts with appropriate permissions:

```php
// Regular user - limited access
$harbor = new HarborApiClient(
    username: env('HARBOR_READONLY_USER'),
    password: env('HARBOR_READONLY_PASSWORD')
);

// Admin - full access (use sparingly)
$adminHarbor = new HarborApiClient(
    username: env('HARBOR_ADMIN_USER'),
    password: env('HARBOR_ADMIN_PASSWORD')
);
```

### 2. Credential Management
```php
// NEVER hardcode credentials
// AVOID
$harbor = new HarborApiClient('https://harbor.example.com', 'admin', 'password123');

// PREFER
$harbor = new HarborApiClient(
    baseUrl: env('HARBOR_BASE_URL'),
    username: env('HARBOR_USERNAME'),
    password: env('HARBOR_PASSWORD')
);
```

### 3. Webhook Security
When setting up Harbor webhooks:
- Use HTTPS endpoints
- Validate webhook signatures
- Implement idempotency

### 4. Vulnerability Management
```php
// Check scan results before deployment
$artifact = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$tag}");

if (!empty($artifact['scan_overview'])) {
    $severity = $artifact['scan_overview']['severity'];
    if ($severity === 'Critical') {
        Alert::create([
            'type' => 'critical',
            'title' => 'Critical Vulnerabilities in Image',
            'message' => "Image {$repoName}:{$tag} has critical vulnerabilities",
            'alert_type' => 'security',
            'severity' => 90,
        ]);
    }
}
```

## Common Tasks

### List all projects
```php
$projects = $harbor->get('/api/v2.0/projects');
foreach ($projects->data as $project) {
    echo $project['name'] . "\n";
}
```

### Get image tags
```php
$tags = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}/tags");
$latest = $tags->data[0]['name'];
```

### Trigger vulnerability scan
```php
$harbor->post("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$reference}/scan");

// Wait for scan to complete
while (true) {
    $artifact = $harbor->get(...);
    if ($artifact['scan_status'] === 'Success') {
        break;
    }
    sleep(5);
}
```

### Delete old images
```php
$artifacts = $harbor->get("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts");

foreach ($artifacts->data as $artifact) {
    $pushedAt = Carbon::parse($artifact['pushed_at']);
    if ($pushedAt->lt(now()->subDays(30))) {
        $harbor->delete("/api/v2.0/projects/{$projectId}/repositories/{$repoName}/artifacts/{$artifact['digest']}");
    }
}
```

## Integration Points

- **Redis Caching**: Cache Harbor API responses
- **Alert Management**: Alert on vulnerabilities
- **Performance Monitoring**: Track image pull times
- **Query Optimizer**: Optimize registry queries

## See Also

- `redis-caching` - Cache Harbor responses
- `alert-management` - Vulnerability alerts
- `performance-monitoring` - Registry metrics
