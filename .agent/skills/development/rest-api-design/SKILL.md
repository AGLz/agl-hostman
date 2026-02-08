---
name: rest-api-design
description: RESTful API conventions, API versioning, error handling standards, and rate limiting for Laravel APIs
category: development
tags: [api, rest, laravel, http, design]
when_to_use: |
  Use this skill when:
  - Designing new REST API endpoints
  - Implementing API versioning strategies
  - Creating consistent error responses
  - Setting up rate limiting and throttling
  - Writing API documentation
---

# REST API Design

This skill covers REST API design patterns used in the agl-hostman project.

## RESTful Conventions

### URL Structure

```
GET    /api/containers              # List all containers
GET    /api/containers/{id}         # Get specific container
POST   /api/containers              # Create new container
PUT    /api/containers/{id}         # Update entire container
PATCH  /api/containers/{id}         # Partial update
DELETE /api/containers/{id}         # Delete container

# Nested resources
GET    /api/servers/{id}/containers # Containers for specific server
POST   /api/servers/{id}/containers # Create container on server

# Actions (non-CRUD)
POST   /api/containers/{id}/start   # Start container
POST   /api/containers/{id}/stop    # Stop container
POST   /api/containers/{id}/restart # Restart container
```

### HTTP Methods

| Method | Safe | Idempotent | Usage |
|--------|------|------------|-------|
| GET    | Yes  | Yes        | Retrieve resources |
| POST   | No   | No         | Create resources, trigger actions |
| PUT    | No   | Yes        | Replace entire resource |
| PATCH  | No   | No         | Partial update |
| DELETE | No   | Yes        | Delete resource |

### Status Codes

```php
// Success responses
200 OK                  // Request succeeded
201 Created             // Resource created
204 No Content          // Success, no response body

// Client errors
400 Bad Request         // Invalid input
401 Unauthorized        // Authentication required
403 Forbidden           // Insufficient permissions
404 Not Found           // Resource doesn't exist
409 Conflict            // Resource conflict
422 Unprocessable Entity  // Validation failed
429 Too Many Requests   // Rate limit exceeded

// Server errors
500 Internal Server Error // Unexpected error
503 Service Unavailable   // Service temporarily down
```

## API Versioning

### URL-Based Versioning

```php
// routes/api.php
Route::prefix('v1')->group(function () {
    Route::apiResource('containers', ContainerController::class);
    Route::apiResource('servers', ServerController::class);
});

Route::prefix('v2')->group(function () {
    // New API version with breaking changes
    Route::apiResource('containers', V2\ContainerController::class);
});
```

### Header-Based Versioning

```php
// Middleware to detect version
class ApiVersion
{
    public function handle(Request $request, Closure $next)
    {
        $version = $request->header('API-Version', 'v1');
        $request->attributes->set('api_version', $version);
        return $next($request);
    }
}
```

### Versioning Strategy

```
# URL-based (recommended for public APIs)
/api/v1/containers
/api/v2/containers

# Query parameter (not recommended)
/api/containers?version=1
```

## Controller Pattern

### Example API Controller

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreContainerRequest;
use App\Http\Resources\ContainerResource;
use App\Http\Resources\ContainerCollection;
use App\Repositories\ProxmoxContainerRepository;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use OpenApi\Annotations as OA;

class ContainerController extends Controller
{
    public function __construct(
        private ProxmoxContainerRepository $repository
    ) {}

    /**
     * @OA\Get(
     *     path="/api/containers",
     *     tags={"Containers"},
     *     summary="List all containers",
     *     description="Returns a paginated list of containers",
     *     @OA\Response(
     *         response=200,
     *         description="Successful operation",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(ref="#/components/schemas/Container"))
     *         )
     *     )
     * )
     */
    public function index(Request $request): ContainerCollection
    {
        $node = $request->query('node', 'pve1');
        $containers = $this->repository->getAllContainers($node);

        return new ContainerCollection($containers);
    }

    public function store(StoreContainerRequest $request): JsonResponse
    {
        $container = $this->repository->create(
            $request->validated()
        );

        return (new ContainerResource($container))
            ->response()
            ->setStatusCode(201);
    }

    public function show(int $id): ContainerResource
    {
        $container = $this->repository->findOrFail($id);
        return new ContainerResource($container);
    }

    public function update(UpdateContainerRequest $request, int $id): ContainerResource
    {
        $container = $this->repository->update(
            $id,
            $request->validated()
        );

        return new ContainerResource($container);
    }

    public function destroy(int $id): JsonResponse
    {
        $this->repository->delete($id);

        return response()->json(null, 204);
    }
}
```

## Error Handling Standards

### Consistent Error Response Format

```php
// Validation error (422)
{
    "error": "Validation failed",
    "message": "The given data was invalid.",
    "errors": {
        "name": ["The name field is required."],
        "cores": ["The cores must be at least 1."]
    }
}

// Authentication error (401)
{
    "error": "Unauthenticated",
    "message": "API key required"
}

// Authorization error (403)
{
    "error": "Forbidden",
    "message": "You do not have permission to perform this action"
}

// Not found (404)
{
    "error": "Resource not found",
    "message": "Container with ID 999 not found"
}

// Rate limit (429)
{
    "error": "Rate limit exceeded",
    "message": "Too many requests. Try again in 30 seconds.",
    "retry_after": 30
}

// Server error (500)
{
    "error": "Internal server error",
    "message": "An unexpected error occurred. Please try again later."
}
```

### Form Request Validation

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
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'cores' => 'required|integer|min:1|max:16',
            'memory_mb' => 'required|integer|min:512|max:32768',
            'disk_gb' => 'required|integer|min:8|max:500',
            'os_template' => 'nullable|string',
            'network_config' => 'nullable|array',
            'auto_start' => 'boolean',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(
            response()->json([
                'error' => 'Validation failed',
                'message' => 'The given data was invalid.',
                'errors' => $validator->errors(),
            ], 422)
        );
    }
}
```

### Global Exception Handler

```php
// app/Exceptions/Handler.php

public function register(): void
{
    $this->renderable(function (ValidationException $e, Request $request) {
        if ($request->expectsJson()) {
            return response()->json([
                'error' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }
    });

    $this->renderable(function (ModelNotFoundException $e, Request $request) {
        if ($request->expectsJson()) {
            return response()->json([
                'error' => 'Resource not found',
                'message' => 'The requested resource was not found.',
            ], 404);
        }
    });

    $this->renderable(function (AuthenticationException $e, Request $request) {
        if ($request->expectsJson()) {
            return response()->json([
                'error' => 'Unauthenticated',
                'message' => 'API key is required.',
            ], 401);
        }
    });
}
```

## Rate Limiting

### Route-Based Rate Limiting

```php
// routes/api.php

// Global rate limit (60 requests per minute)
Route::middleware(['throttle:api'])->group(function () {
    Route::apiResource('containers', ContainerController::class);
});

// Custom rate limits per route
Route::middleware('throttle:60,1')->group(function () {
    // 60 requests per minute
    Route::get('/containers', [ContainerController::class, 'index']);
});

Route::middleware('throttle:10,1')->group(function () {
    // 10 requests per minute (strict)
    Route::post('/containers', [ContainerController::class, 'store']);
});
```

### Dynamic Rate Limiting

```php
// app/Providers/RouteServiceProvider.php

protected function configureRateLimiting(): void
{
    RateLimiter::for('api', function (Request $request) {
        return Limit::perMinute(60)
            ->by($request->user()?->id ?: $request->ip())
            ->response(function () {
                return response()->json([
                    'error' => 'Rate limit exceeded',
                    'message' => 'Too many requests.',
                    'retry_after' => 60,
                ], 429);
            });
    });

    // Per-user rate limits
    RateLimiter::for('premium', function (Request $request) {
        $user = $request->user();

        if ($user && $user->isPremium()) {
            return Limit::perMinute(1000);
        }

        return Limit::perMinute(60);
    });
}
```

### Middleware-Based Rate Limiting

```php
// From ApiAuthentication middleware
$rateLimitKey = 'api_rate:' . $apiKeyModel->id;
$limit = $apiKeyModel->rate_limit ?: 60;

if (!RateLimiter::attempt($rateLimitKey, $limit, function() {}, 60)) {
    $seconds = RateLimiter::availableIn($rateLimitKey);

    return response()->json([
        'error' => 'Rate limit exceeded',
        'retry_after' => $seconds,
    ], 429)->header('Retry-After', $seconds);
}
```

## API Response Standards

### Response Headers

```php
// Successful response
return response()->json($data)
    ->header('X-API-Version', 'v1')
    ->header('X-RateLimit-Limit', '60')
    ->header('X-RateLimit-Remaining', '55')
    ->header('X-Request-ID', $requestId);

// Error response
return response()->json([
    'error' => 'Not Found',
    'message' => 'Resource not found',
], 404)
    ->header('X-Request-ID', $requestId)
    ->header('Retry-After', '60');
```

### Pagination

```php
// In controller
public function index(Request $request): ContainerCollection
{
    $containers = Container::paginate(15);
    return new ContainerCollection($containers);
}

// Response format
{
    "data": [...],
    "links": {
        "first": "https://api.example.com/containers?page=1",
        "last": "https://api.example.com/containers?page=5",
        "prev": null,
        "next": "https://api.example.com/containers?page=2"
    },
    "meta": {
        "current_page": 1,
        "from": 1,
        "last_page": 5,
        "per_page": 15,
        "to": 15,
        "total": 75
    }
}
```

## API Documentation

### OpenAPI/Swagger Annotations

```php
<?php

namespace App\Http\Controllers\Api;

use OpenApi\Annotations as OA;

class ContainerController extends Controller
{
    /**
     * @OA\Get(
     *     path="/api/containers/{id}",
     *     tags={"Containers"},
     *     summary="Get container by ID",
     *     description="Returns a single container",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Successful",
     *         @OA\JsonContent(ref="#/components/schemas/Container")
     *     ),
     *     @OA\Response(response=404, description="Not found")
     * )
     */
    public function show(int $id)
    {
        // ...
    }
}
```

Generate docs:

```bash
php artisan l5-swagger:generate
```

Access at: `https://your-domain.com/api/documentation`

## Reference Files

- Controller Example: `src/app/Http/Controllers/Api/InfrastructureController.php`
- Middleware Example: `src/app/Http/Middleware/ApiAuthentication.php`
- API Routes: `src/routes/api.php`
- Documentation: `src/app/Http/Controllers/Api/Documentation/ApiDocumentationController.php`

## Best Practices Checklist

- [ ] Use noun-based URLs (not verbs)
- [ ] Use plural nouns for collections
- [ ] Return appropriate HTTP status codes
- [ ] Provide consistent error response format
- [ ] Implement rate limiting
- [ ] Use API versioning for breaking changes
- [ ] Include request IDs for debugging
- [ ] Document with OpenAPI/Swagger
- [ ] Validate all input with Form Requests
- [ ] Use API resources for JSON responses
