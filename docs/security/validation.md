# Input Validation and Authorization

Comprehensive guide for implementing secure input validation and authorization in AGL Hostman.

## Table of Contents

- [Overview](#overview)
- [Form Request Validation](#form-request-validation)
- [Custom Validation Rules](#custom-validation-rules)
- [Rate Limiting](#rate-limiting)
- [Security Headers](#security-headers)
- [Authorization Patterns](#authorization-patterns)
- [Input Sanitization](#input-sanitization)
- [Best Practices](#best-practices)

## Overview

AGL Hostman implements a multi-layered security approach:

1. **Form Request Validation** - Structured validation layer for all API endpoints
2. **Custom Validation Rules** - Business logic specific validation
3. **Rate Limiting** - Prevent API abuse and brute force attacks
4. **Security Headers** - Protect against common web vulnerabilities
5. **Authorization** - Role-based access control (RBAC)

### Security Features

- **Input Sanitization**: Automatic trimming and null conversion
- **Rate Limiting**: Per-user and per-IP throttling
- **SSRF Protection**: URL validation preventing internal network access
- **Strong Password Requirements**: Configurable password policies
- **Security Headers**: CSP, HSTS, XSS protection
- **API Response Caching**: Integrated with validation layer

## Form Request Validation

### BaseFormRequest

All form requests extend `BaseFormRequest` for consistent behavior:

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class BaseFormRequest extends FormRequest
{
    /**
     * Prepare input before validation
     */
    protected function prepareForValidation(): void
    {
        $this->sanitizeInputs();
    }

    /**
     * Sanitize input data
     */
    protected function sanitizeInputs(): void
    {
        $input = $this->all();

        // Trim all string values
        $input = array_map(function ($value) {
            return is_string($value) ? trim($value) : $value;
        }, $input);

        // Convert empty strings to null
        $input = array_map(function ($value) {
            return $value === '' ? null : $value;
        }, $input);

        $this->merge($input);
    }

    /**
     * Get consistent error format
     */
    protected function failedValidation(\Illuminate\Contracts\Validation\Validator $validator)
    {
        if ($this->expectsJson()) {
            $response = response()->json([
                'error' => 'Validation failed',
                'message' => 'The given data was invalid.',
                'errors' => $validator->errors()->toArray(),
            ], 422);

            throw new \Illuminate\Validation\ValidationException($validator, $response);
        }

        parent::failedValidation($validator);
    }

    /**
     * Helper for pagination rules
     */
    protected function getPaginationRules(): array
    {
        return [
            'page' => 'nullable|integer|min:1',
            'per_page' => 'nullable|integer|min:1|max:100',
            'sort_by' => 'nullable|string',
            'sort_order' => 'nullable|in:asc,desc',
        ];
    }

    /**
     * Helper for boolean rules
     */
    protected function getBooleanRule(string $field): string
    {
        return $field . '|boolean';
    }
}
```

### Creating Form Requests

**Example: Store Container Request**

```php
<?php

namespace App\Http\Requests;

class StoreContainerRequest extends BaseFormRequest
{
    public function authorize(): bool
    {
        return auth()->user()?->can('create', LxcContainer::class) ?? false;
    }

    public function rules(): array
    {
        return [
            // Proxmox VMID validation
            'vmid' => 'required|integer|min:100|max:999999999|unique:lxc_containers,vmid',

            // Container name (alphanumeric, dash, underscore)
            'name' => 'required|string|max:255|regex:/^[a-zA-Z0-9-_]+$/',

            // Hostname validation
            'hostname' => ['nullable', 'string', 'max:255', new ValidHostname()],

            // Resource allocation
            'cores' => 'required|integer|min:1|max:16',
            'memory_mb' => 'required|integer|min:512|max:32768|multiple_of:256',
            'disk_gb' => 'required|integer|min:10|max:1000',

            // Network configuration
            'ip_address' => ['nullable', new ValidIPAddress(allowCidr: false)],
            'gateway' => ['nullable', 'ip'],
            'subnet_mask' => ['nullable', 'ip'],

            // Template selection
            'template_id' => 'required|exists:container_templates,id',

            // Target server
            'proxmox_server_id' => 'required|exists:proxmox_servers,id',
        ];
    }
}
```

**Using in Controller:**

```php
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreContainerRequest;
use App\Models\LxcContainer;

class ContainerController extends Controller
{
    public function store(StoreContainerRequest $request)
    {
        // Validation already passed, data is sanitized
        $container = LxcContainer::create($request->validated());

        return response()->json([
            'message' => 'Container created successfully',
            'data' => $container,
        ], 201);
    }
}
```

## Custom Validation Rules

### Available Custom Rules

#### 1. ValidVmid

Validates Proxmox VMID format (100-999999999).

```php
use App\Rules\ValidVmid;

$rules = [
    'vmid' => ['required', new ValidVmid()],
];
```

**Validation Logic:**
- VMID must be numeric
- VMID must be between 100 and 999999999
- Used for LXC containers and VMs

#### 2. ValidHostname

Validates hostname according to RFC 1123.

```php
use App\Rules\ValidHostname;

$rules = [
    'hostname' => ['nullable', new ValidHostname()],
];
```

**Validation Logic:**
- Allows alphanumeric characters, hyphens, and dots
- Each label max 63 characters
- Total max 253 characters
- Does not start or end with hyphen

#### 3. ValidIPAddress

Validates IP addresses with optional CIDR notation and range checking.

```php
use App\Rules\ValidIPAddress;

// Basic IP validation
$rules = [
    'ip_address' => ['required', new ValidIPAddress()],
];

// Allow CIDR notation
$rules = [
    'network' => ['required', new ValidIPAddress(allowCidr: true)],
];

// Restrict to allowed ranges
$rules = [
    'ip_address' => ['required', new ValidIPAddress(
        allowCidr: false,
        allowedRanges: ['192.168.1.0/24', '10.0.0.0/8']
    )],
];
```

**Features:**
- IPv4 and IPv6 support
- Optional CIDR notation
- IP range validation
- Private network detection

#### 4. StrongPassword

Validates password strength requirements.

```php
use App\Rules\StrongPassword;

// Default requirements (12+ chars, uppercase, lowercase, number, special)
$rules = [
    'password' => ['required', 'confirmed', new StrongPassword()],
];

// Custom requirements
$rules = [
    'password' => ['required', new StrongPassword(
        minLength: 16,
        requireUppercase: true,
        requireLowercase: true,
        requireNumber: true,
        requireSpecialChar: true
    )],
];
```

**Default Requirements:**
- Minimum 12 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

#### 5. SafeUrl

Validates URLs and prevents SSRF attacks.

```php
use App\Rules\SafeUrl;

// Block internal networks
$rules = [
    'webhook_url' => ['nullable', new SafeUrl()],
];

// Allow only specific hosts
$rules = [
    'api_url' => ['required', new SafeUrl(
        allowedHosts: ['api.example.com', 'cdn.example.com']
    )],
];
```

**Security Features:**
- URL format validation
- Private IP detection (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Blocks localhost (127.0.0.0/8)
- Blocks link-local (169.254.0.0/16)
- Prevents file:// protocol

#### 6. ValidJson

Validates JSON strings.

```php
use App\Rules\ValidJson;

$rules = [
    'metadata' => ['nullable', new ValidJson()],
];
```

### Creating Custom Rules

**Example: Port Number Validation**

```php
<?php

namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;

class ValidPort implements Rule
{
    public function passes($attribute, $value): bool
    {
        if (!is_numeric($value)) {
            return false;
        }

        $port = (int) $value;

        return $port >= 1 && $port <= 65535;
    }

    public function message(): string
    {
        return 'The :attribute must be a valid port number (1-65535).';
    }
}
```

**Using Custom Rule:**

```php
$rules = [
    'port' => ['required', new ValidPort()],
];
```

## Rate Limiting

### Rate Limit Middleware

Rate limiting is implemented via `RateLimiting` middleware with configurable limits.

### Rate Limit Types

| Type | Max Attempts | Decay Period | Use Case |
|------|--------------|--------------|----------|
| `default` | 60 | 1 minute | Standard API requests |
| `strict` | 5 | 1 minute | Expensive operations |
| `api` | 100 | 1 minute | General API access |
| `auth` | 5 | 15 minutes | Authentication endpoints |

### Applying Rate Limits

**In Routes:**

```php
// routes/api.php

// Default rate limit (60/min)
Route::middleware('throttle')->group(function () {
    Route::apiResource('containers', ContainerController::class);
});

// Strict rate limit (5/min)
Route::middleware('throttle:strict')->group(function () {
    Route::post('/containers/{container}/deploy', [DeploymentController::class, 'store']);
});

// Authentication rate limit (5/15min)
Route::middleware('throttle:auth')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/password/reset', [AuthController::class, 'resetPassword']);
});
```

**Rate Limit Key Structure:**

```
rate_limit:{type}:{user_id|ip}
```

Examples:
- `rate_limit:default:user_123`
- `rate_limit:strict:ip_192.168.1.100`
- `rate_limit:auth:user_456`

### Response Headers

All rate-limited responses include headers:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1704100800
```

### Rate Limit Exceeded Response

**JSON:**

```json
{
  "error": "Too many attempts",
  "message": "Rate limit exceeded. Please try again later.",
  "retry_after": 60
}
```

**HTTP Status:** 429 Too Many Requests

### Custom Rate Limits

**Creating Custom Rate Limit:**

```php
<?php

namespace App\Http\Middleware;

class CustomRateLimiting extends RateLimiting
{
    private array $rateLimits = [
        'webhook' => [
            'max_attempts' => 1000,
            'decay_minutes' => 60,
        ],
    ];
}
```

**Using Custom Limit:**

```php
Route::middleware('throttle:webhook')->group(function () {
    Route::post('/webhooks/harbor', [WebhookController::class, 'harbor']);
});
```

## Security Headers

### Security Headers Middleware

All responses include security headers via `SecurityHeaders` middleware.

### Implemented Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME type sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-XSS-Protection` | `1; mode=block` | XSS protection |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Force HTTPS |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer information |
| `Permissions-Policy` | `geolocation=(self), microphone=()` | Feature policy |
| `X-Permitted-Cross-Domain-Policies` | `none` | Cross-domain policies |
| `Content-Security-Policy` | Dynamic | XSS and injection protection |

### Content Security Policy

**For API Requests:**

```
default-src 'self';
script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline';
img-src 'self' data: https:;
font-src 'self' data:;
connect-src 'self';
frame-ancestors 'none';
```

**Removing Server Information:**

```php
$response->headers->remove('X-Powered-By');
$response->headers->remove('Server');
```

### Applying Security Headers

Security headers are automatically applied to all routes via `bootstrap/app.php`:

```php
$middleware->api(prepend: [
    \App\Http\Middleware\SecurityHeaders::class,
]);

$middleware->web(prepend: [
    \App\Http\Middleware\SecurityHeaders::class,
]);
```

### Customizing Security Headers

**Custom CSP for Specific Routes:**

```php
<?php

namespace App\Http\Middleware;

class CustomSecurityHeaders extends SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = parent::handle($request, $next);

        // Allow specific CDN for images
        if ($request->is('api/images/*')) {
            $csp = $response->headers->get('Content-Security-Policy');
            $csp = str_replace('img-src \'self\'', 'img-src \'self\' https://cdn.example.com', $csp);
            $response->headers->set('Content-Security-Policy', $csp);
        }

        return $response;
    }
}
```

## Authorization Patterns

### Role-Based Access Control (RBAC)

AGL Hostman uses Spatie Permission for RBAC.

**Available Roles:**

- `admin` - Full system access
- `advanced` - Advanced operations (deploy, manage)
- `common` - Basic operations (view only)

**Available Permissions:**

- `view containers` - View container list
- `create containers` - Create new containers
- `update containers` - Edit container configuration
- `delete containers` - Remove containers
- `deploy containers` - Trigger deployments
- `manage users` - User management
- `manage system` - System configuration

### Authorization in Form Requests

```php
public function authorize(): bool
{
    // User can update their own profile or admins can update any user
    $userId = $this->route('user');
    $currentUser = auth()->user();

    return $currentUser && (
        $currentUser->id == $userId ||
        $currentUser->hasRole('admin')
    ) && $currentUser->isActive();
}
```

### Authorization in Controllers

```php
<?php

namespace App\Http\Controllers;

use App\Models\LxcContainer;
use Illuminate\Http\Request;

class ContainerController extends Controller
{
    public function __construct()
    {
        $this->middleware('permission:view containers')->only(['index', 'show']);
        $this->middleware('permission:create containers')->only(['store']);
        $this->middleware('permission:update containers')->only(['update']);
        $this->middleware('permission:delete containers')->only(['destroy']);
    }

    public function update(Request $request, LxcContainer $container)
    {
        $this->authorize('update', $container);

        // Update logic
    }
}
```

### Authorization in Policies

```php
<?php

namespace App\Policies;

use App\Models\LxcContainer;
use App\Models\User;

class ContainerPolicy
{
    public function view(User $user, LxcContainer $container): bool
    {
        return $user->can('view containers');
    }

    public function create(User $user): bool
    {
        return $user->can('create containers') && $user->isActive();
    }

    public function update(User $user, LxcContainer $container): bool
    {
        return $user->can('update containers') && $user->isActive();
    }

    public function delete(User $user, LxcContainer $container): bool
    {
        return $user->can('delete containers') && $user->isActive();
    }

    public function deploy(User $user, LxcContainer $container): bool
    {
        return $user->can('deploy containers') &&
               $user->isActive() &&
               $container->status === 'running';
    }
}
```

### Location-Based Authorization

**Middleware:**

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CheckLocationAccess
{
    public function handle(Request $request, Closure $next)
    {
        $user = auth()->user();
        $locationId = $request->route('location');

        if (!$user->locations()->where('id', $locationId)->exists()) {
            return response()->json([
                'error' => 'Access denied',
                'message' => 'You do not have access to this location.',
            ], 403);
        }

        return $next($request);
    }
}
```

**Using Location Middleware:**

```php
Route::middleware('location')->group(function () {
    Route::apiResource('locations.containers', ContainerController::class);
});
```

## Input Sanitization

### Automatic Sanitization

`BaseFormRequest` automatically sanitizes all inputs:

1. **Trim Strings**: Removes whitespace from string values
2. **Empty to Null**: Converts empty strings to null

```php
// Raw input: ["name" => "  container-01  ", "description" => ""]
// Sanitized: ["name" => "container-01", "description" => null]
```

### Manual Sanitization

**Using Sanitizers in Form Requests:**

```php
<?php

namespace App\Http\Requests;

class StoreContainerRequest extends BaseFormRequest
{
    protected function prepareForValidation(): void
    {
        parent::prepareForValidation();

        $input = $this->all();

        // Convert hostname to lowercase
        if (isset($input['hostname'])) {
            $input['hostname'] = strtolower($input['hostname']);
        }

        // Normalize IP address format
        if (isset($input['ip_address']) && filter_var($input['ip_address'], FILTER_VALIDATE_IP)) {
            $input['ip_address'] = trim($input['ip_address']);
        }

        $this->merge($input);
    }
}
```

### HTML and XSS Sanitization

**Using HTMLPurifier:**

```bash
composer require stevegrunwell/html-purifier
```

```php
<?php

namespace App\Http\Requests;

use Stevegrunwell\HTMLPurifier\Purifier;

class UpdateContentRequest extends BaseFormRequest
{
    protected function prepareForValidation(): void
    {
        parent::prepareForValidation();

        $input = $this->all();

        // Sanitize HTML content
        if (isset($input['description'])) {
            $input['description'] = Purifier::clean($input['description']);
        }

        $this->merge($input);
    }
}
```

## Best Practices

### 1. Always Use Form Requests

**❌ Bad: Validation in Controller**

```php
public function store(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string',
        // Bad: Hard to test, hard to reuse
    ]);
}
```

**✅ Good: Form Request Class**

```php
public function store(StoreContainerRequest $request)
{
    // Validation and authorization already handled
    $container = LxcContainer::create($request->validated());
}
```

### 2. Use Custom Rules for Complex Validation

**❌ Bad: Complex Regex in Rules**

```php
$rules = [
    'hostname' => 'required|regex:/^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])\.)*([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])$/',
];
```

**✅ Good: Reusable Custom Rule**

```php
$rules = [
    'hostname' => ['required', new ValidHostname()],
];
```

### 3. Implement Rate Limiting

**❌ Bad: No Rate Limiting**

```php
Route::post('/webhooks/harbor', [WebhookController::class, 'handle']);
```

**✅ Good: Rate Limited**

```php
Route::middleware('throttle:api')->post('/webhooks/harbor', [WebhookController::class, 'handle']);
```

### 4. Use Authorization Policies

**❌ Bad: Authorization in Controller**

```php
public function update(Request $request, $id)
{
    $container = LxcContainer::findOrFail($id);

    if (auth()->user()->cannot('update', $container)) {
        abort(403);
    }
}
```

**✅ Good: Policy Middleware**

```php
public function update(UpdateContainerRequest $request, LxcContainer $container)
{
    $this->authorize('update', $container);

    // Update logic
}
```

### 5. Validate and Sanitize Early

**❌ Bad: Validation Late in Flow**

```php
public function store(Request $request)
{
    $container = new LxcContainer();
    $container->name = $request->input('name'); // Not validated!

    $validated = $request->validate([...]);
}
```

**✅ Good: Validation Before Anything**

```php
public function store(StoreContainerRequest $request)
{
    // All inputs validated and sanitized
    $container = LxcContainer::create($request->validated());
}
```

### 6. Use Type Declarations

**❌ Bad: No Type Hints**

```php
public function store(Request $request)
{
    $data = $request->validated();
    return $data;
}
```

**✅ Good: Strict Types**

```php
public function store(StoreContainerRequest $request): JsonResponse
{
    $container = LxcContainer::create($request->validated());

    return response()->json([
        'message' => 'Container created',
        'data' => $container,
    ], 201);
}
```

### 7. Provide Clear Error Messages

**❌ Bad: Generic Errors**

```php
$rules = [
    'vmid' => 'required|integer',
];
```

**✅ Good: Specific Messages**

```php
public function messages(): array
{
    return [
        'vmid.required' => 'The VMID is required to create a container.',
        'vmid.integer' => 'The VMID must be a valid integer.',
        'vmid.min' => 'The VMID must be at least 100.',
    ];
}
```

### 8. Log Security Events

```php
<?php

namespace App\Http\Middleware;

use Illuminate\Support\Facades\Log;

class RateLimiting
{
    private function isRateLimited(Request $request, string $key, array $limit): bool
    {
        if ($attempts >= $limit['max_attempts']) {
            Log::warning('Rate limit exceeded', [
                'key' => $key,
                'attempts' => $attempts,
                'ip' => $request->ip(),
                'user_id' => auth()->id(),
            ]);

            return true;
        }

        return false;
    }
}
```

## Testing Validation

### Testing Form Requests

```php
<?php

namespace Tests\Feature;

use App\Models\User;
use Tests\TestCase;

class StoreContainerRequestTest extends TestCase
{
    public function test_validation_requires_vmid()
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->postJson('/api/containers', [
                'name' => 'test-container',
                // Missing vmid
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['vmid']);
    }

    public function test_validation_rejects_invalid_vmid()
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->postJson('/api/containers', [
                'vmid' => 99, // Too low
                'name' => 'test-container',
            ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['vmid']);
    }

    public function test_validation_accepts_valid_data()
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->postJson('/api/containers', [
                'vmid' => 100,
                'name' => 'test-container',
                'cores' => 2,
                'memory_mb' => 2048,
                'disk_gb' => 50,
                'template_id' => 1,
                'proxmox_server_id' => 1,
            ]);

        $response->assertStatus(201);
    }
}
```

### Testing Custom Rules

```php
<?php

namespace Tests\Unit;

use App\Rules\ValidVmid;
use Tests\TestCase;

class ValidVmidTest extends TestCase
{
    public function test_valid_vmid_passes()
    {
        $rule = new ValidVmid();

        $this->assertTrue($rule->passes('vmid', 100));
        $this->assertTrue($rule->passes('vmid', 999999999));
    }

    public function test_invalid_vmid_fails()
    {
        $rule = new ValidVmid();

        $this->assertFalse($rule->passes('vmid', 99));
        $this->assertFalse($rule->passes('vmid', 1000000000));
        $this->assertFalse($rule->passes('vmid', 'abc'));
    }
}
```

## Security Checklist

- [ ] All API endpoints use Form Request validation
- [ ] Sensitive operations have strict rate limits
- [ ] All routes have security headers
- [ ] Authorization is enforced via policies
- [ ] Inputs are sanitized before validation
- [ ] Custom rules for business logic
- [ ] Password strength requirements
- [ ] URL validation prevents SSRF
- [ ] Security events are logged
- [ ] Tests cover validation scenarios
- [ ] Error messages don't leak information

## Related Documentation

- [Authentication](/docs/api/authentication.md)
- [Caching Strategy](/docs/performance/caching.md)
- [Database Optimization](/docs/performance/database.md)
- [Rate Limiting](/docs/api/rate-limiting.md)

## Additional Resources

- [Laravel Validation](https://laravel.com/docs/validation)
- [Laravel Authorization](https://laravel.com/docs/authorization)
- [Spatie Permission](https://spatie.be/docs/laravel-permission)
- [OWASP Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
