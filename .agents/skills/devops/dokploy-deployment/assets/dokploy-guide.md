# Dokploy Deployment Guide for Laravel

## Overview

This guide covers deploying Laravel applications using Dokploy, a self-hosted PaaS platform built on Docker Compose, with application configuration, health monitoring, rollback capabilities, and production-ready deployment strategies.

## Core Concepts

### What is Dokploy?

Dokploy is a self-hosted Platform as a Service (PaaS) that simplifies deploying applications using Docker Compose. Key features:

- **Git-based Deployments**: Auto-deploy on git push
- **Docker Compose Native**: Use existing compose files
- **Environment Management**: Secure secret management
- **SSL/TLS Support**: Automatic HTTPS with Let's Encrypt
- **Health Monitoring**: Built-in health checks and alerts
- **Easy Rollbacks**: One-click version rollback
- **Multi-Application**: Deploy multiple apps on one server

### Dokploy Architecture

```
┌─────────────────────────────────────────────────┐
│                   Dokploy                       │
├─────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐           │
│  │   Laravel    │  │   Queue      │           │
│  │  (Compose)   │  │  Worker      │           │
│  └──────────────┘  └──────────────┘           │
│         │                  │                   │
│  ┌────────────────────────────────┐            │
│  │         Services               │            │
│  │  MySQL | Redis | Nginx         │            │
│  └────────────────────────────────┘            │
│         │                                      │
│  ┌────────────────────────────────┐            │
│  │       Docker Engine            │            │
│  └────────────────────────────────┘            │
└─────────────────────────────────────────────────┘
```

## Application Setup

### Creating a New Application

```bash
# Via Dokploy CLI
dokploy app:create laravel-app \
  --type docker-compose \
  --repo https://github.com/username/laravel-app \
  --branch main
```

### Docker Compose Configuration

#### Basic Laravel Compose for Dokploy

```yaml
version: '3.9'

services:
  app:
    image: ${REGISTRY_URL}/laravel-app:${IMAGE_TAG:-latest}
    restart: always
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE=${DB_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - QUEUE_CONNECTION=redis
    volumes:
      - app_storage:/app/storage
      - app_bootstrap:/app/bootstrap/cache
    networks:
      - laravel
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  nginx:
    image: nginx:1.25-alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    networks:
      - laravel
    depends_on:
      app:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - laravel
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - laravel
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  queue:
    image: ${REGISTRY_URL}/laravel-app:${IMAGE_TAG:-latest}
    restart: always
    command: php artisan queue:work --daemon --sleep=3 --tries=3
    environment:
      - APP_ENV=production
      - DB_HOST=mysql
      - REDIS_HOST=redis
    volumes:
      - app_storage:/app/storage
    networks:
      - laravel
    depends_on:
      - mysql
      - redis

  scheduler:
    image: ${REGISTRY_URL}/laravel-app:${IMAGE_TAG:-latest}
    restart: always
    command: >
      sh -c "while true; do
        php artisan schedule:run --verbose --no-interaction &
        sleep 60
      done"
    environment:
      - APP_ENV=production
      - DB_HOST=mysql
    volumes:
      - app_storage:/app/storage
    networks:
      - laravel

networks:
  laravel:
    driver: bridge

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local
  app_storage:
    driver: local
  app_bootstrap:
    driver: local
  nginx_logs:
    driver: local
```

### Environment Configuration

#### Environment Variables in Dokploy

```bash
# Via CLI
dokploy env:set laravel-app APP_ENV production
dokploy env:set laravel-app APP_DEBUG false
dokploy env:set laravel-app DB_HOST mysql
dokploy env:set laravel-app DB_PASSWORD <secret>

# Or via dokploy-compose.yml
environment:
  - APP_ENV=production
  - APP_DEBUG=false
  - DB_HOST=mysql
  - DB_PASSWORD=${DB_PASSWORD}
```

### Domain Configuration

#### Custom Domain Setup

```bash
# Add domain
dokploy domain:add laravel-app app.example.com

# Enable SSL
dokploy domain:ssl laravel-app app.example.com --enable

# Configure domain settings
dokploy domain:config laravel-app app.example.com \
  --redirect-www \
  --hsts-enable \
  --compress-enable
```

### Health Checks

#### Application Health Endpoint

```php
// routes/api.php
Route::get('/health', function () {
    $checks = [
        'database' => DB::connection()->getPdo() ? 'up' : 'down',
        'redis' => Redis::ping() ? 'up' : 'down',
        'storage' => is_writable(storage_path()) ? 'up' : 'down',
    ];

    $isHealthy = collect($checks)->every(fn ($status) => $status === 'up');

    return response()->json([
        'status' => $isHealthy ? 'healthy' : 'unhealthy',
        'timestamp' => now()->toIso8601String(),
        'checks' => $checks,
    ], $isHealthy ? 200 : 503);
});
```

#### Dokploy Health Check Configuration

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:9000/api/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

## Deployment Strategies

### Git-Based Auto-Deploy

```bash
# Configure git repository
dokploy app:config laravel-app \
  --repo https://github.com/username/laravel-app \
  --branch main \
  --auto-deploy

# Set up webhook
dokploy webhook:create laravel-app \
  --secret <webhook-secret>
```

### Blue-Green Deployment

```bash
# Create blue environment
dokploy app:create laravel-blue --type docker-compose

# Deploy to blue
dokploy deploy laravel-blue --tag v1.0.0

# Test blue environment
# ... run tests against blue ...

# Switch traffic to blue
dokploy app:switch laravel-app laravel-blue

# Keep green as rollback
dokploy app:keep laravel-green
```

### Zero-Downtime Deployment

```yaml
# docker-compose.yml with health checks
services:
  app:
    image: ${REGISTRY}/laravel-app:${IMAGE_TAG}
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 30s
        failure_action: rollback
        order: start-first
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

## Rollback Strategies

### Version Rollback

```bash
# List available versions
dokploy versions:list laravel-app

# Rollback to specific version
dokploy rollback laravel-app --version v1.0.5

# Quick rollback to previous version
dokploy rollback laravel-app --previous
```

### Database Migration Rollback

```php
// Create rollback command
// app/Console/Commands/RollbackDeployment.php

public function handle()
{
    // Rollback migrations
    $this->call('migrate:rollback', ['--step' => 1]);

    // Re-enable maintenance mode
    $this->call('down', ['--refresh' => 15]);

    $this->info('Rollback completed successfully');
}
```

### Automatic Rollback on Failure

```yaml
# docker-compose.yml
deploy:
  update_config:
    failure_action: rollback
  rollback_config:
    parallelism: 0
    order: stop-first
```

## Hooks and Scripts

### Pre-Deploy Hook

```bash
#!/bin/bash
# .dokploy/hooks/pre-deploy.sh

echo "Running pre-deploy checks..."

# Check environment
php artisan env:check

# Backup database
php artisan db:backup

# Clear caches
php artisan cache:clear
php artisan config:clear

echo "Pre-deploy checks completed"
```

### Post-Deploy Hook

```bash
#!/bin/bash
# .dokploy/hooks/post-deploy.sh

echo "Running post-deploy tasks..."

# Run migrations
php artisan migrate --force

# Clear and cache configs
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Restart queue workers
php artisan queue:restart

# Clear opcache
php artisan opcache:clear

echo "Post-deploy tasks completed"
```

### Health Check Script

```bash
#!/bin/bash
# .dokploy/hooks/health-check.sh

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if curl -f http://localhost/api/health; then
    echo "Health check passed"
    exit 0
  fi

  ATTEMPT=$((ATTEMPT+1))
  sleep 2
done

echo "Health check failed after $MAX_ATTEMPTS attempts"
exit 1
```

## Monitoring and Logging

### Application Logs

```bash
# View real-time logs
dokploy logs:tail laravel-app

# View logs for specific service
dokploy logs:tail laravel-app --service app

# View logs with filtering
dokploy logs:tail laravel-app --tail 100 --since 1h

# Export logs
dokploy logs:export laravel-app --output logs.tar.gz
```

### Metrics and Monitoring

```php
// app/Http/Metrics/ApplicationMetrics.php

class ApplicationMetrics
{
    public static function record(): array
    {
        return [
            'memory' => memory_get_usage(true),
            'memory_peak' => memory_get_peak_usage(true),
            'request_time' => microtime(true) - LARAVEL_START,
            'queries' => DB::getQueryLog(),
            'cache_hits' => Cache::getHits(),
            'cache_misses' => Cache::getMisses(),
        ];
    }
}
```

### Alert Configuration

```yaml
# dokploy-alerts.yml
alerts:
  - name: High Error Rate
    condition: error_rate > 5%
    duration: 5m
    action:
      type: webhook
      url: https://hooks.slack.com/services/xxx

  - name: High Response Time
    condition: response_time > 2s
    duration: 10m
    action:
      type: email
      to: ops@example.com

  - name: High Memory Usage
    condition: memory_usage > 90%
    duration: 5m
    action:
      type: restart
      service: app
```

## Scaling

### Horizontal Scaling

```yaml
# docker-compose.yml
services:
  app:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

```bash
# Scale via CLI
dokploy scale laravel-app app --replicas 5
dokploy scale laravel-app queue --replicas 3
```

### Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
dokploy logs:tail laravel-app

# Check container status
dokploy ps

# Inspect container
dokploy inspect laravel-app

# Restart container
dokploy restart laravel-app
```

### Permission Issues

```bash
# Fix storage permissions
dokploy exec laravel-app chown -R www-data:www-data storage

# Fix bootstrap cache permissions
dokploy exec laravel-app chmod -R 775 bootstrap/cache
```

### Database Connection Issues

```bash
# Test database connection
dokploy exec laravel-app php artisan db:test

# Check database service
dokploy logs:tail laravel-app --service mysql

# Restart database service
dokploy restart laravel-app mysql
```

## Best Practices

1. **Always use health checks** for all services
2. **Implement rollback procedures** before going to production
3. **Monitor logs regularly** for errors and warnings
4. **Use separate environments** for staging and production
5. **Implement blue-green deployments** for zero downtime
6. **Set up alerts** for critical failures
7. **Regular backups** of database and storage
8. **Document deployment procedures** and runbooks
9. **Test deployments in staging** before production
10. **Use secrets management** for sensitive data
