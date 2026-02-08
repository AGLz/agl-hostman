# Laravel Environment Configuration Guide

## Overview

This guide covers managing Laravel environment configuration across multiple environments with secure secret management, configuration validation, and production-ready patterns.

## Core Concepts

### The Twelve-Factor App Methodology

Laravel follows the twelve-factor app methodology for configuration:

1. **Config is separate from code**: Never commit secrets to git
2. **Environment-specific configs**: Different settings per environment
3. **Use .env files**: For local development and simple deployments
4. **Environment variables**: For production (more secure)
5. **Config caching**: Use `config:cache` in production

### Environment Hierarchy

```
┌─────────────────────────────────────────────────┐
│              Production (Live)                  │
│  - Real API keys                                │
│  - Production database                          │
│  - Debug mode OFF                               │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│              Staging (QA)                       │
│  - Test API keys                                │
│  - Staging database                             │
│  - Debug mode mixed                             │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│              Local (Development)                │
│  - Local services                               │
│  - SQLite/Local MySQL                           │
│  - Debug mode ON                                │
└─────────────────────────────────────────────────┘
```

## .env File Structure

### Production Environment (.env.production)

```bash
# Application
APP_NAME="Laravel Application"
APP_ENV=production
APP_KEY=base64:generated-key-here
APP_DEBUG=false
APP_URL=https://app.example.com

# Logging
LOG_CHANNEL=stack
LOG_LEVEL=warning

# Database (MySQL)
DB_CONNECTION=mysql
DB_HOST=mysql.production.internal
DB_PORT=3306
DB_DATABASE=production_db
DB_USERNAME=production_user
DB_PASSWORD=secure_password_here
DB_CHARSET=utf8mb4
DB_COLLATION=utf8mb4_unicode_ci

# Redis
REDIS_HOST=redis.production.internal
REDIS_PASSWORD=redis_password_here
REDIS_PORT=6379
REDIS_CACHE_DB=0
REDIS_QUEUE_DB=1

# Cache Configuration
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Session
SESSION_LIFETIME=120
SESSION_ENCRYPT=false

# Queue
QUEUE_FAILED_DRIVER=mysql

# Mail
MAIL_MAILer=smtp
MAIL_HOST=smtp.postmarkapp.com
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=api-key-here
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME="${APP_NAME}"

# AWS S3 (File Storage)
FILESYSTEM_DISK=s3
AWS_ACCESS_KEY_ID=aws-access-key
AWS_SECRET_ACCESS_KEY=aws-secret-key
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=production-bucket
AWS_URL=https://production-bucket.s3.amazonaws.com

# Third-Party Services
STRIPE_KEY=pk_live_xxxxx
STRIPE_SECRET=sk_live_xxxxx
SENTRY_LARAVEL_DSN=https://xxx@sentry.io/xxx

# Security
SANCTUM_STATEFUL_DOMAINS=app.example.com
SESSION_DOMAIN=.example.com

# Performance
OPCACHE_ENABLE=1
```

### Staging Environment (.env.staging)

```bash
# Application
APP_NAME="Laravel Application [Staging]"
APP_ENV=staging
APP_KEY=base64:generated-key-here
APP_DEBUG=true
APP_URL=https://staging.example.com

# Logging
LOG_CHANNEL=stack
LOG_LEVEL=debug

# Database
DB_CONNECTION=mysql
DB_HOST=mysql.staging.internal
DB_PORT=3306
DB_DATABASE=staging_db
DB_USERNAME=staging_user
DB_PASSWORD=staging_password
DB_CHARSET=utf8mb4
DB_COLLATION=utf8mb4_unicode_ci

# Redis
REDIS_HOST=redis.staging.internal
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_CACHE_DB=0
REDIS_QUEUE_DB=1

# Cache
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail (Mailtrap for testing)
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=mailtrap_username
MAIL_PASSWORD=mailtrap_password
MAIL_ENCRYPTION=null

# File Storage (Local or staging S3)
FILESYSTEM_DISK=local
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...

# Third-Party Services (Test keys)
STRIPE_KEY=pk_test_xxxxx
STRIPE_SECRET=sk_test_xxxxx

# Security
SANCTUM_STATEFUL_DOMAINS=staging.example.com
SESSION_DOMAIN=.staging.example.com
```

### Local Environment (.env)

```bash
# Application
APP_NAME="Laravel Application"
APP_ENV=local
APP_KEY=base64:generated-key-here
APP_DEBUG=true
APP_URL=http://localhost:8000

# Logging
LOG_CHANNEL=stack
LOG_LEVEL=debug

# Database (MySQL or SQLite)
DB_CONNECTION=mysql
# DB_CONNECTION=sqlite
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_local
DB_USERNAME=root
DB_PASSWORD=

# Redis (local)
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Cache (local)
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

# Mail (Mailhog)
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

# File Storage (local)
FILESYSTEM_DISK=local

# Broadcasting
BROADCAST_DRIVER=log
```

### Environment Template (.env.example)

```bash
# Copy this file to .env and fill in your values
# DO NOT commit .env files with real credentials

# Application
APP_NAME="Laravel Application"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=

# Redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Cache
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="${APP_NAME}"

# AWS S3
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_URL=

# Stripe
STRIPE_KEY=
STRIPE_SECRET=

# Sentry
SENTRY_LARAVEL_DSN=

# Security
SANCTUM_STATEFUL_DOMAINS=
SESSION_DOMAIN=
```

## Configuration Files

### Environment-Specific Config (config/app.php)

```php
<?php

return [

    'env' => env('APP_ENV', 'production'),

    'debug' => (bool) env('APP_DEBUG', false),

    'url' => env('APP_URL', 'http://localhost'),

    'timezone' => 'UTC',

    'locale' => 'en',

    'fallback_locale' => 'en',

    'key' => env('APP_KEY'),

    'cipher' => 'AES-256-CBC',

    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE'),
    ],

];
```

### Database Config (config/database.php)

```php
<?php

return [

    'default' => env('DB_CONNECTION', 'mysql'),

    'connections' => [
        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DATABASE_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'forge'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],
    ],

];
```

### Logging Config (config/logging.php)

```php
<?php

return [

    'default' => env('LOG_CHANNEL', 'stack'),

    'channels' => [
        'stack' => [
            'driver' => 'stack',
            'channels' => array_filter([
                'daily',
                env('APP_ENV') === 'production' ? 'sentry' : null,
            ]),
            'ignore_exceptions' => false,
        ],
        'daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/laravel.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'days' => env('LOG_DAYS', 14),
        ],
        'sentry' => [
            'driver' => 'sentry',
            'level' => 'error',
            'bubble' => true,
        ],
    ],

];
```

## Environment Validation

### Create Validation Rule (app/Rules/EnvironmentConfig.php)

```php
<?php

namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class EnvironmentConfig implements Rule
{
    protected $message = '';

    public function passes($attribute, $value)
    {
        // Check APP_KEY is set
        if (empty(config('app.key')) || config('app.key') === 'base64:') {
            $this->message = 'APP_KEY is not set';
            return false;
        }

        // Check database connection
        try {
            DB::connection()->getPdo();
        } catch (\Exception $e) {
            $this->message = 'Database connection failed: ' . $e->getMessage();
            return false;
        }

        // Check Redis connection
        if (config('cache.default') === 'redis') {
            try {
                Redis::connection()->ping();
            } catch (\Exception $e) {
                $this->message = 'Redis connection failed: ' . $e->getMessage();
                return false;
            }
        }

        // Check required AWS credentials for S3
        if (config('filesystems.default') === 's3') {
            if (empty(config('filesystems.disks.s3.key'))) {
                $this->message = 'AWS credentials are not configured';
                return false;
            }
        }

        return true;
    }

    public function message()
    {
        return $this->message;
    }
}
```

### Create Validation Command

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use App\Rules\EnvironmentConfig;

class ValidateEnvironment extends Command
{
    protected $signature = 'env:validate';
    protected $description = 'Validate environment configuration';

    public function handle()
    {
        $this->info('Validating environment configuration...');

        $validator = Validator::make([], [
            'env' => ['required', new EnvironmentConfig],
        ]);

        if ($validator->fails()) {
            $this->error('Environment validation failed:');
            foreach ($validator->errors()->all() as $error) {
                $this->error("  - $error");
            }
            return 1;
        }

        $this->info('✓ Environment configuration is valid');
        return 0;
    }
}
```

## Secret Management

### HashiCorp Vault Integration

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;

class VaultService
{
    protected $client;
    protected $vaultUrl;
    protected $vaultToken;

    public function __construct()
    {
        $this->vaultUrl = config('services.vault.url');
        $this->vaultToken = config('services.vault.token');
    }

    public function getSecret(string $path): ?array
    {
        return Cache::remember("vault:$path", 300, function () use ($path) {
            $response = $this->client->get("{$this->vaultUrl}/v1/secret/data/$path", [
                'headers' => [
                    'X-Vault-Token' => $this->vaultToken,
                ],
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return $data['data']['data'] ?? null;
            }

            return null;
        });
    }

    public function loadSecretsToEnv(): void
    {
        $secrets = $this->getSecret('laravel/app');

        if ($secrets) {
            foreach ($secrets as $key => $value) {
                $_ENV[$key] = $value;
                putenv("$key=$value");
            }
        }
    }
}
```

### AWS Secrets Manager Integration

```php
<?php

namespace App\Services;

use Aws\SecretsManager\SecretsManagerClient;

class AwsSecretsService
{
    protected $client;

    public function __construct()
    {
        $this->client = new SecretsManagerClient([
            'version' => 'latest',
            'region' => config('services.secrets.region'),
            'credentials' => [
                'key' => config('services.secrets.key'),
                'secret' => config('services.secrets.secret'),
            ],
        ]);
    }

    public function getSecret(string $secretName): ?array
    {
        try {
            $result = $this->client->getSecretValue([
                'SecretId' => $secretName,
            ]);

            $secret = $result['SecretString'];
            return json_decode($secret, true);
        } catch (\Exception $e) {
            return null;
        }
    }
}
```

## Config Caching

### Production Config Caching

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class CacheProductionConfig extends Command
{
    protected $signature = 'config:prod-cache';
    protected $description = 'Cache configuration for production';

    public function handle()
    {
        if (config('app.env') !== 'production') {
            $this->warn('This command should only be run in production');
            if (!$this->confirm('Continue anyway?')) {
                return 0;
            }
        }

        $this->call('config:cache');
        $this->call('route:cache');
        $this->call('view:cache');
        $this->call('event:cache');

        $this->info('Production configuration cached successfully');
        return 0;
    }
}
```

## Best Practices

1. **Never commit .env files** to version control
2. **Use .env.example** as a template for required variables
3. **Document all environment variables** in team documentation
4. **Use different APP_KEY** for each environment
5. **Validate configs at startup** with `env:validate`
6. **Cache configs in production** with `config:cache`
7. **Use secret managers** for production secrets (Vault, AWS Secrets Manager)
8. **Rotate secrets regularly** every 90 days
9. **Use different databases** for staging and production
10. **Keep production keys** out of staging environments

## Security Checklist

- [ ] APP_DEBUG is false in production
- [ ] APP_KEY is unique per environment
- [ ] Database passwords are strong (20+ characters)
- [ ] API keys are not committed to git
- [ ] .env files are in .gitignore
- [ ] Secrets are encrypted at rest
- [ ] SSL/TLS is enabled for all services
- [ ] S3 buckets have proper ACLs
- [ ] CORS is configured correctly
- [ ] Session cookies are HTTP-only and Secure
