# Docker Containerization Guide for Laravel

## Overview

This guide covers Docker containerization best practices for Laravel applications, including multi-stage builds, Docker Compose orchestration, volume management, and production-ready container patterns.

## Core Concepts

### Multi-Stage Builds

Multi-stage builds reduce final image size by separating build dependencies from runtime requirements.

```dockerfile
# Stage 1: Base image with dependencies
FROM composer:2.7 AS composer
FROM php:8.3-fpm AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip

# Stage 2: Composer dependencies
FROM base AS dependencies

WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install \
    --no-scripts \
    --no-autoloader \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --optimize-autoloader

# Stage 3: Development environment
FROM base AS development

WORKDIR /app

# Install development dependencies
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --prefer-dist --no-interaction

COPY . .

RUN composer dump-autoload -o && \
    php artisan key:generate && \
    php artisan storage:link

# Stage 4: Production image
FROM base AS production

WORKDIR /app

# Copy dependencies from previous stage
COPY --from=dependencies /app /app

# Copy application files
COPY . .

# Generate optimized autoloader
RUN composer dump-autoload --optimize --classmap-authoritative && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan event:cache

# Set permissions
RUN chown -R www-data:www-data /app \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache

USER www-data

EXPOSE 9000

CMD ["php-fpm"]
```

### Docker Compose Patterns

#### Local Development (docker-compose.yml)

```yaml
version: '3.9'

services:
  # Application service
  app:
    build:
      context: .
      target: development
    container_name: laravel-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    networks:
      - laravel
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE=${DB_DATABASE:-laravel}
      - DB_USERNAME=${DB_USERNAME:-laravel}
      - DB_PASSWORD=${DB_PASSWORD:-secret}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - QUEUE_CONNECTION=redis

  # Nginx service
  nginx:
    image: nginx:1.25-alpine
    container_name: laravel-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_PORT:-80}:80"
      - "${NGINX_SSL_PORT:-443}:443"
    volumes:
      - ./:/app
      - ./docker/nginx/conf.d:/etc/nginx/conf.d
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./storage/logs/nginx:/var/log/nginx
    networks:
      - laravel
    depends_on:
      - app

  # MySQL service
  mysql:
    image: mysql:8.0
    container_name: laravel-mysql
    restart: unless-stopped
    ports:
      - "${MYSQL_PORT:-3306}:3306"
    environment:
      - MYSQL_DATABASE=${DB_DATABASE:-laravel}
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root}
      - MYSQL_USER=${DB_USERNAME:-laravel}
      - MYSQL_PASSWORD=${DB_PASSWORD:-secret}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro
    networks:
      - laravel
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis service
  redis:
    image: redis:7-alpine
    container_name: laravel-redis
    restart: unless-stopped
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
    networks:
      - laravel
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Queue worker
  queue:
    build:
      context: .
      target: development
    container_name: laravel-queue
    restart: unless-stopped
    command: php artisan queue:work --verbose --tries=3 --timeout=90
    volumes:
      - ./:/app
    networks:
      - laravel
    depends_on:
      - app
      - redis

  # Scheduler
  scheduler:
    build:
      context: .
      target: development
    container_name: laravel-scheduler
    restart: unless-stopped
    command: >
      sh -c "
      while true; do
        php artisan schedule:run --verbose --no-interaction &
        sleep 60
      done
      "
    volumes:
      - ./:/app
    networks:
      - laravel
    depends_on:
      - app

networks:
  laravel:
    driver: bridge

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local
```

#### Production Docker Compose (docker-compose.prod.yml)

```yaml
version: '3.9'

services:
  app:
    build:
      context: .
      target: production
    image: ${REGISTRY_URL}/laravel-app:${IMAGE_TAG:-latest}
    restart: always
    networks:
      - laravel
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - LOG_CHANNEL=stack
    healthcheck:
      test: ["CMD-SHELL", "php-fpm-healthcheck || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  nginx:
    image: nginx:1.25-alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/conf.d/production.conf:/etc/nginx/conf.d/default.conf:ro
      - ./docker/nginx/ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    networks:
      - laravel
    depends_on:
      app:
        condition: service_healthy

  queue:
    image: ${REGISTRY_URL}/laravel-app:${IMAGE_TAG:-latest}
    restart: always
    command: php artisan queue:work --daemon --sleep=3 --tries=3 --max-time=3600
    networks:
      - laravel
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

networks:
  laravel:
    driver: bridge

volumes:
  nginx_logs:
    driver: local
```

### Volume Management

#### Named Volumes

```yaml
volumes:
  # Database persistence
  mysql_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/mysql

  # Redis persistence
  redis_data:
    driver: local

  # Application storage
  storage_app:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /app/storage/app

  # File uploads
  storage_uploads:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /app/storage/app/uploads
```

#### Bind Mounts for Development

```yaml
volumes:
  # Live code reloading
  - ./:/app:cached

  # PHP configuration
  - ./docker/php/php.ini:/usr/local/etc/php/conf.d/custom.ini:ro

  # Nginx configuration
  - ./docker/nginx/conf.d:/etc/nginx/conf.d:ro

  # Logs
  - ./storage/logs:/app/storage/logs
```

### Container Networking

#### Custom Network Configuration

```yaml
networks:
  laravel:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
    driver_opts:
      com.docker.network.bridge.name: laravel_br
```

#### Service Discovery

```yaml
services:
  app:
    networks:
      laravel:
        aliases:
          - app.internal
          - api.internal

  mysql:
    networks:
      laravel:
        aliases:
          - db.internal
          - mysql.internal
```

### Health Checks

#### PHP-FPM Health Check

```dockerfile
# In Dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD php-fpm-healthcheck || exit 1
```

```bash
#!/bin/sh
# php-fpm-healthcheck script
SCRIPT_NAME=/ping \
SCRIPT_FILENAME=/ping \
REQUEST_METHOD=GET \
cgi-fcgi -bind -connect 127.0.0.1:9000
```

#### Application Health Check

```php
// routes/api.php - Add health check endpoint
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toIso8601String(),
        'services' => [
            'database' => DB::connection()->getPdo() ? 'up' : 'down',
            'redis' => Redis::ping() ? 'up' : 'down',
            'storage' => is_writable(storage_path()) ? 'up' : 'down',
        ],
    ]);
})->name('health');
```

## Best Practices

### Layer Caching Optimization

```dockerfile
# ❌ BAD - No caching benefits
COPY . .
RUN composer install

# ✅ GOOD - Leverages layer cache
COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader
COPY . .
RUN composer dump-autoload
```

### Environment-Specific Builds

```dockerfile
# Development target
FROM base AS development
# ... dev tools, hot reload, etc.

# Production target
FROM base AS production
# ... optimized, minimal
```

### Security Best Practices

```dockerfile
# Run as non-root user
RUN addgroup --system --gid 1000 www-data && \
    adduser --system --uid 1000 --gid 1000 www-data
USER www-data

# Use specific version tags
FROM php:8.3-fpm-alpine3.19

# Scan for vulnerabilities
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Minimal base image
FROM php:8.3-fpm-alpine
```

### Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## Common Commands

```bash
# Build and start services
docker-compose up -d --build

# View logs
docker-compose logs -f app

# Execute commands in container
docker-compose exec app php artisan migrate

# Run tests
docker-compose exec app php artisan test

# Stop all services
docker-compose down -v

# Clean up unused resources
docker system prune -a --volumes
```

## Troubleshooting

### Permission Issues

```bash
# Fix storage permissions
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache

# Fix uploaded files permissions
docker-compose exec app chmod -R 775 storage/app/public
```

### Container Networking Debug

```bash
# Test connectivity between containers
docker-compose exec app ping mysql
docker-compose exec app nc -zv redis 6379

# View container network details
docker network inspect ls
docker network inspect <network_id>
```

### Volume Debug

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect mysql_data

# Backup volume
docker run --rm -v mysql_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/mysql-backup.tar.gz /data
```
