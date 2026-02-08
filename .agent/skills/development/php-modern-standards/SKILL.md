---
name: php-modern-standards
description: Modern PHP 8+ features including typed properties, named arguments, enums, PSR standards compliance, and static analysis tools
category: development
tags: [php, php8, typing, psr, static-analysis]
when_to_use: |
  Use this skill when:
  - Writing new PHP code with modern features
  - Reviewing code for PHP 8+ compatibility
  - Setting up static analysis tools
  - Ensuring PSR compliance
  - Refactoring legacy PHP code
---

# Modern PHP Standards

This skill covers PHP 8+ features and standards used in the agl-hostman project.

## PHP 8+ Features

### Declare Strict Types

Always use strict types at the top of files:

```php
<?php

declare(strict_types=1);

namespace App\Services;

class MyService
{
    // All function calls are now strictly typed
}
```

### Constructor Property Promotion

```php
<?php

// Before PHP 8
class UserService
{
    private string $email;
    private string $name;

    public function __construct(string $email, string $name)
    {
        $this->email = $email;
        $this->name = $name;
    }
}

// PHP 8+ - Constructor Property Promotion
class UserService
{
    public function __construct(
        private readonly string $email,
        private readonly string $name,
    ) {}
}
```

### Named Arguments

```php
<?php

// Function definition
function createContainer(
    string $name,
    int $cores = 1,
    int $memory = 1024,
    int $disk = 20,
    bool $autoStart = false,
) {
    // ...
}

// Positional arguments (order matters)
createContainer('web-01', 4, 4096, 80, true);

// Named arguments (order doesn't matter, more readable)
createContainer(
    name: 'web-01',
    cores: 4,
    memory: 4096,
    autoStart: true,
);
```

### Enums

```php
<?php

namespace App\Enums;

enum ContainerStatus: string
{
    case RUNNING = 'running';
    case STOPPED = 'stopped';
    case PAUSED = 'paused';
    case SUSPENDED = 'suspended';

    public function isOperational(): bool
    {
        return $this === self::RUNNING || $this === self::PAUSED;
    }

    public function label(): string
    {
        return match($this) {
            self::RUNNING => 'Running',
            self::STOPPED => 'Stopped',
            self::PAUSED => 'Paused',
            self::SUSPENDED => 'Suspended',
        };
    }
}

// Usage
$status = ContainerStatus::RUNNING;
if ($status->isOperational()) {
    echo $status->label();
}
```

### Backed Enums (with database)

```php
<?php

enum Environment: string
{
    case DEVELOPMENT = 'development';
    case STAGING = 'staging';
    case PRODUCTION = 'production';
}

// In migration
$table->enum('environment', array_column(Environment::cases(), 'value'));

// In model
protected $casts = [
    'environment' => Environment::class,
];
```

### Match Expression

```php
<?php

// Instead of switch
$message = match ($status) {
    ContainerStatus::RUNNING => 'Container is running',
    ContainerStatus::STOPPED => 'Container is stopped',
    ContainerStatus::PAUSED => 'Container is paused',
    default => 'Unknown status',
};

// With conditions
$result = match ($statusCode) {
    200, 201, 204 => 'success',
    301, 302 => 'redirect',
    400, 401, 403, 404 => 'client error',
    500, 502, 503 => 'server error',
    default => 'unknown',
};

// With multiple conditions
$action = match (true) {
    $user->isAdmin() => 'redirect_admin',
    $user->isGuest() => 'redirect_login',
    $user->isActive() => 'redirect_dashboard',
    default => 'redirect_home',
};
```

### Readonly Properties

```php
<?php

class Configuration
{
    public function __construct(
        public readonly string $apiKey,
        public readonly string $apiUrl,
        public readonly array $options,
    ) {}
}

$config = new Configuration('key123', 'https://api.example.com', ['timeout' => 30]);
// $config->apiKey = 'new-key'; // Error: Cannot modify readonly property
```

### Union Types

```php
<?php

function processInput(string|int $input): string|int|float
{
    if (is_string($input)) {
        return strlen($input);
    }
    return $input * 1.5;
}

// In class properties
class Container
{
    private string|int|null $hostname = null;
}
```

### Nullsafe Operator

```php
<?php

// Before PHP 8
$country = null;
if ($session !== null) {
    $user = $session->user;
    if ($user !== null) {
        $address = $user->address;
        if ($address !== null) {
            $country = $address->country;
        }
    }
}

// PHP 8+ - Nullsafe operator
$country = $session?->user?->address?->country;

// With method calls
$length = $user?->getAddress()?->getStreet()?->length();
```

### Attributes

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Routing\Controllers\HasMiddleware;

// Custom attribute
#[Attribute]
class RateLimited
{
    public function __construct(
        public readonly int $requests = 60,
        public readonly int $seconds = 60,
    ) {}
}

// Using attributes
#[RateLimited(requests: 100, seconds: 60)]
class ApiController implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('auth'),
            new Middleware('throttle:api'),
        ];
    }
}
```

### Mixed Type

```php
<?php

function logError(mixed $data): void
{
    error_log(print_r($data, true));
}

// In method return
function getSetting(string $key): mixed
{
    return config($key);
}
```

## PSR Standards Compliance

### PSR-4: Autoloading

```
src/
├── app/
│   ├── Services/
│   │   └── ProxmoxApiClient.php  → App\Services\ProxmoxApiClient
│   ├── Models/
│   │   └── LxcContainer.php       → App\Models\LxcContainer
│   └── Http/
│       └── Controllers/
│           └── Api/
│               └── InfrastructureController.php
```

### PSR-12: Coding Style

```php
<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Class description
 */
class ApiService
{
    private const CACHE_TTL = 3600;
    private const MAX_RETRIES = 3;

    // Properties: camelCase
    private string $baseUrl;
    private array $options;

    // Methods: camelCase
    public function __construct(string $baseUrl)
    {
        $this->baseUrl = $baseUrl;
        $this->options = [];
    }

    // Constants: UPPER_CASE
    public function getTimeout(): int
    {
        return $this->options['timeout'] ?? 30;
    }

    // Arguments: camelCase
    public function setOption(string $key, mixed $value): self
    {
        $this->options[$key] = $value;
        return $this;
    }
}
```

## Type System

### Return Types

```php
<?php

class ContainerRepository
{
    // Always declare return types
    public function find(int $id): ?Container
    {
        return Container::find($id);
    }

    public function getAll(): Collection
    {
        return Container::all();
    }

    public function create(array $data): Container
    {
        return Container::create($data);
    }

    public function exists(int $id): bool
    {
        return Container::where('id', $id)->exists();
    }

    // Void for no return
    public function clearCache(): void
    {
        Cache::forget('containers:all');
    }

    // Never for terminating functions
    public function abortOnFailure(): never
    {
        abort(500, 'Operation failed');
    }

    // Static for same type as class
    public static function fromConfig(array $config): static
    {
        return new static($config);
    }
}
```

### Property Types

```php
<?php

class Metrics
{
    public string $name;
    protected int $count;
    private array $data;
    private readonly string $id;

    // Casts in models
    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'config' => AsArrayObject::class,
            'enabled' => 'boolean',
            'created_at' => 'datetime',
        ];
    }
}
```

## Static Analysis Tools

### PHPStan

Install PHPStan:

```bash
composer require --dev phpstan/phpstan
```

Configuration (`phpstan.neon`):

```neon
parameters:
    level: 8
    paths:
        - src/app
    checkGenericClassUsageNonGenericObjectType: false
    checkMissingIterableValueType: false
```

Run analysis:

```bash
vendor/bin/phpstan analyse
```

### Psalm

Install Psalm:

```bash
composer require --dev vimeo/psalm
```

Configuration (`psalm.xml`):

```xml
<?xml version="1.0"?>
<psalm
    errorLevel="5"
    findUnusedPsalmSuppress="false"
    findUnusedBaselineEntry="false"
    findUnusedCode="false"
>
    <projectFiles>
        <directory name="src/app" />
    </projectFiles>
</psalm>
```

Run analysis:

```bash
vendor/bin/psalm --show-info=true
```

### Larastan

Laravel-specific PHPStan rules:

```bash
composer require --dev larastan/larastan
```

Configuration:

```neon
includes:
    - ./vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - src/app
    level: 5
```

## Modern Array Functions

```php
<?php

// Instead of array_map + array_filter
$items = ['apple', '', 'banana', null, 'cherry'];

// Filter out empty values
$filtered = array_filter($items, fn($item) => !empty($item));

// Map to uppercase
$mapped = array_map(fn($item) => strtoupper($item), $items);

// Both combined
$result = array_filter(
    array_map(fn($item) => strtoupper($item), $items),
    fn($item) => !empty($item)
);

// Using arrow functions with arrays
$sum = array_reduce([1, 2, 3, 4], fn($carry, $item) => $carry + $item, 0);
```

## Reference Files

- Service Example: `src/app/Services/ProxmoxApiClient.php`
- Repository Example: `src/app/Repositories/ProxmoxContainerRepository.php`
- Model Example: `src/app/Models/LxcContainer.php`
- Middleware Example: `src/app/Http/Middleware/ApiAuthentication.php`

## Type Safety Checklist

- [ ] Always use `declare(strict_types=1)`
- [ ] Declare all parameter types
- [ ] Declare all return types
- [ ] Use readonly properties for immutable data
- [ ] Use enums for fixed value sets
- [ ] Use match expressions instead of switch
- [ ] Use constructor property promotion
- [ ] Run PHPStan before committing
- [ ] Follow PSR-12 coding standards
