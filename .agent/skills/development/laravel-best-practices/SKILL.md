---
name: laravel-best-practices
description: Laravel best practices for service patterns, repository pattern, middleware, request validation, form requests, and API standards
category: development
tags: [laravel, php, architecture, patterns]
when_to_use: |
  Use this skill when:
  - Implementing new features or services in Laravel
  - Creating API endpoints with proper validation
  - Setting up middleware for authentication/authorization
  - Designing service and repository layers
  - Creating form requests for validation
  - Building resource responses for APIs
---

# Laravel Best Practices

This skill encapsulates the Laravel/PHP development patterns used in the agl-hostman project.

## Service Pattern

Services encapsulate business logic and external API interactions. Located in `app/Services/`.

### Example: ProxmoxApiClient

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\DTOs\ProxmoxApiResponse;

/**
 * ProxmoxApiClient - API abstraction layer for Proxmox VE
 *
 * Implements circuit breaker pattern, retry logic, and connection pooling
 */
class ProxmoxApiClient
{
    protected string $baseUrl;
    protected string $username;
    protected string $password;
    protected ?string $apiToken = null;
    protected int $timeout = 30;
    protected int $maxRetries = 3;

    public function __construct(
        string $host,
        int $port = 8006,
        ?string $username = null,
        ?string $password = null,
        bool $verifySSL = false
    ) {
        $this->baseUrl = "https://{$host}:{$port}/api2/json";
        $this->username = $username ?? config('proxmox.username');
        $this->password = $password ?? config('proxmox.password');
    }

    public function getNodes(): ProxmoxApiResponse
    {
        return $this->request('GET', '/nodes');
    }

    protected function request(string $method, string $endpoint, array $params = []): ProxmoxApiResponse
    {
        // Circuit breaker + retry logic
    }
}
```

### Key Service Principles:
- Use constructor property promotion for dependencies
- Return typed DTOs (Data Transfer Objects)
- Implement circuit breaker pattern for external APIs
- Use cached responses where appropriate
- Log errors with context

## Repository Pattern

Repositories provide data access abstraction with caching. Located in `app/Repositories/`.

### Example: ProxmoxContainerRepository

```php
<?php

declare(strict_types=1);

namespace App\Repositories;

use App\DTO\ContainerMetrics;
use App\Services\Proxmox\ProxmoxApiClient;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Psr\Log\LoggerInterface;

class ProxmoxContainerRepository
{
    private const CACHE_TTL = 60;
    private const CACHE_PREFIX = 'proxmox_containers_';

    public function __construct(
        private readonly ProxmoxApiClient $client,
        private readonly LoggerInterface $logger,
    ) {}

    public function getAllContainers(string $node, bool $withMetrics = true): Collection
    {
        $cacheKey = self::CACHE_PREFIX . "{$node}_all";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($node, $withMetrics) {
            $response = $this->client->get("/nodes/{$node}/lxc");
            // Process and return collection
        });
    }
}
```

### Key Repository Principles:
- Use `declare(strict_types=1)` for type safety
- Use readonly constructor properties
- Return typed Collections
- Implement cache invalidation on mutations
- Use PSR-3 LoggerInterface for logging

## Middleware

Middleware handles cross-cutting concerns like authentication, rate limiting, and auditing.

### Example: ApiAuthentication Middleware

```php
<?php

namespace App\Http\Middleware;

use App\Models\ApiKey;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;

class ApiAuthentication
{
    public function handle(Request $request, Closure $next, string $permission = null): Response
    {
        $apiKey = $this->extractApiKey($request);

        if (!$apiKey) {
            return response()->json([
                'error' => 'API key required',
                'message' => 'Please provide an API key via X-API-Key header',
            ], 401);
        }

        // Cache API key lookup
        $cacheKey = 'api_key:' . substr($apiKey, 0, 8);
        $apiKeyModel = Cache::remember($cacheKey, 300, function () use ($apiKey) {
            return ApiKey::where('key', $apiKey)->active()->first();
        });

        // Rate limiting per API key
        $rateLimitKey = 'api_rate:' . $apiKeyModel->id;
        $limit = $apiKeyModel->rate_limit ?: 60;

        if (!RateLimiter::attempt($rateLimitKey, $limit, function() {}, 60)) {
            return response()->json([
                'error' => 'Rate limit exceeded',
                'retry_after' => RateLimiter::availableIn($rateLimitKey),
            ], 429);
        }

        return $next($request);
    }
}
```

## Request Validation with Form Requests

### Creating Form Requests

```bash
php artisan make:request StoreContainerRequest
```

### Example Form Request:

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class StoreContainerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // or implement authorization logic
    }

    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'hostname' => 'nullable|string|max:255',
            'cores' => 'required|integer|min:1|max:16',
            'memory_mb' => 'required|integer|min:512|max:32768',
            'disk_gb' => 'required|integer|min:8|max:500',
            'os_template' => 'nullable|string',
            'network_config' => 'nullable|array',
            'auto_start' => 'boolean',
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Container name is required',
            'cores.min' => 'Minimum 1 core required',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(
            response()->json([
                'error' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422)
        );
    }
}
```

## Resource Responses

Use API Resources for consistent JSON responses.

### Creating Resources

```bash
php artisan make:resource ContainerResource
php artisan make:resource ContainerCollection
```

### Example Resource:

```php
<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class ContainerResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
            'vmid' => $this->vmid,
            'name' => $this->name,
            'hostname' => $this->hostname,
            'status' => $this->status,
            'resources' => [
                'cores' => $this->cores,
                'memory_mb' => $this->memory_mb,
                'disk_gb' => $this->disk_gb,
            ],
            'is_running' => $this->isRunning(),
            'uptime' => $this->getFormattedUptime(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
```

## Controller Patterns

### Best Practice Controller

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreContainerRequest;
use App\Http\Resources\ContainerResource;
use App\Repositories\ProxmoxContainerRepository;
use Illuminate\Http\Request;

class ContainerController extends Controller
{
    public function __construct(
        private ProxmoxContainerRepository $repository
    ) {}

    public function index(Request $request)
    {
        $node = $request->query('node', 'pve1');
        $containers = $this->repository->getAllContainers($node);

        return ContainerResource::collection($containers);
    }

    public function store(StoreContainerRequest $request)
    {
        $container = $this->repository->create(
            $request->validated()
        );

        return new ContainerResource($container);
    }
}
```

## Project-Specific Patterns

### Reference Files:
- Service: `src/app/Services/ProxmoxApiClient.php`
- Repository: `src/app/Repositories/ProxmoxContainerRepository.php`
- Middleware: `src/app/Http/Middleware/ApiAuthentication.php`
- Controller: `src/app/Http/Controllers/Api/InfrastructureController.php`
- Model: `src/app/Models/LxcContainer.php`

### Configuration:
- Config files in `src/config/`
- Environment-specific configs with `.env`
- Use `config()` helper, never hardcoded values

## Common Traits

### Using Enums

```php
enum ContainerStatus: string
{
    case RUNNING = 'running';
    case STOPPED = 'stopped';
    case PAUSED = 'paused';
}
```

### Custom Casts

```php
protected function casts(): array
{
    return [
        'network_config' => AsArrayObject::class,
        'metadata' => 'array',
        'is_template' => 'boolean',
    ];
}
```
