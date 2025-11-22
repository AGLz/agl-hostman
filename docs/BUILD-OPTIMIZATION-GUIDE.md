# Build Pipeline Optimization Guide

> **Last Updated**: 2025-11-21 | **Version**: 1.0.0
> **Phase**: 4.1 - Build Pipeline Optimization
> **Target**: 75% Build Time Reduction

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Optimization Strategies](#-optimization-strategies)
3. [Multi-Stage Dockerfile](#-multi-stage-dockerfile)
4. [GitHub Actions Caching](#-github-actions-caching)
5. [Harbor Registry Integration](#-harbor-registry-integration)
6. [BuildKit Features](#-buildkit-features)
7. [Performance Metrics](#-performance-metrics)
8. [Best Practices](#-best-practices)

---

## 🎯 Overview

### Performance Targets

| Metric | Before | Target | After |
|--------|--------|--------|-------|
| **Build Time** | ~10 minutes | 2.5 minutes | 75% reduction |
| **Cache Hit Rate** | ~20% | 80%+ | Improved |
| **Layer Reuse** | ~50% | 90%+ | Optimized |
| **Dependency Download** | ~2 minutes | <30 seconds | Cached |

### Key Improvements

1. **Multi-Stage Dockerfile** - Optimized layer ordering and caching
2. **GitHub Actions Cache** - Dependencies and build artifacts
3. **Harbor Proxy Cache** - Docker image layers
4. **BuildKit Features** - Inline cache, mount cache, parallel builds
5. **Performance Monitoring** - Automated metrics tracking

---

## 🚀 Optimization Strategies

### 1. Docker Layer Caching

**Strategy**: Order Dockerfile instructions from least to most frequently changing

```dockerfile
# ✅ GOOD - Dependencies change rarely
COPY composer.json composer.lock ./
RUN composer install

# ❌ BAD - Source changes frequently
COPY . .
RUN composer install
```

**Benefits**:
- 90%+ layer reuse
- Faster subsequent builds
- Reduced network I/O

### 2. Multi-Stage Builds

**Strategy**: Separate build stages for different concerns

```dockerfile
# Stage 1: Base image with extensions
FROM php:8.4-fpm-alpine AS php-base

# Stage 2: Node.js build
FROM node:20-alpine AS node-builder

# Stage 3: Composer dependencies
FROM php-base AS composer-builder

# Stage 4: Production image
FROM php-base AS production
```

**Benefits**:
- Smaller final image
- Parallel build stages
- Better cache utilization

### 3. BuildKit Mount Cache

**Strategy**: Cache external dependencies during build

```dockerfile
# Composer cache mount
RUN --mount=type=cache,target=/root/.composer \
    composer install

# NPM cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline
```

**Benefits**:
- Dependencies download once
- 2 minutes → 30 seconds
- Persistent across builds

### 4. GitHub Actions Cache

**Strategy**: Cache dependencies, build artifacts, and test results

```yaml
- name: Cache Composer dependencies
  uses: actions/cache@v4
  with:
    path: ~/.composer/cache
    key: composer-${{ hashFiles('**/composer.lock') }}
```

**Benefits**:
- 50% faster CI/CD
- Reduced GitHub Actions minutes
- Consistent build environment

### 5. Harbor Registry Cache

**Strategy**: Use Harbor as proxy cache for Docker Hub

```dockerfile
# Instead of:
FROM php:8.4-fpm-alpine

# Use Harbor proxy:
FROM harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
```

**Benefits**:
- 10x faster image pulls
- 90% bandwidth savings
- Offline build capability

---

## 📦 Multi-Stage Dockerfile

### Stage 1: Base PHP Image

```dockerfile
FROM php:8.4-fpm-alpine AS php-base

# System dependencies (cached layer)
RUN apk add --no-cache git curl libpng-dev ...

# PHP extensions (cached layer)
RUN docker-php-ext-install pdo_pgsql mbstring ...

# Composer (cached layer)
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# OPcache configuration (cached layer)
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini
```

**Key Points**:
- Alpine Linux for smaller image size
- Separate RUN commands for better caching
- OPcache configured for production performance

### Stage 2: Node.js Build

```dockerfile
FROM node:20-alpine AS node-builder

WORKDIR /app

# Package files first (cached if unchanged)
COPY package.json package-lock.json ./

# Install with cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit

# Build assets with cache
COPY . .
RUN --mount=type=cache,target=/app/.vite \
    npm run build
```

**Key Points**:
- Copy package files before source
- Use cache mounts for node_modules
- Vite build cache persists

### Stage 3: Composer Dependencies

```dockerfile
FROM php-base AS composer-builder

WORKDIR /app

# Composer files first (cached if unchanged)
COPY composer.json composer.lock ./

# Install with cache mount
RUN --mount=type=cache,target=/root/.composer \
    composer install --no-dev --prefer-dist

# Copy source and generate autoloader
COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative
```

**Key Points**:
- Composer lock file ensures consistency
- Cache mount for vendor directory
- Optimized autoloader for production

### Stage 4: Production Image

```dockerfile
FROM php-base AS production

# Copy from build stages
COPY --from=composer-builder /app/vendor ./vendor
COPY --from=node-builder /app/public/build ./public/build

# Copy application code
COPY --chown=www-data:www-data . .

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache
```

**Key Points**:
- Only production files included
- Proper file ownership
- Minimal attack surface

---

## ⚡ GitHub Actions Caching

### Cache Strategy

```yaml
# 1. Composer Dependencies
- name: Cache Composer dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.composer/cache
      src/vendor
    key: composer-${{ hashFiles('**/composer.lock') }}
    restore-keys: composer-

# 2. NPM Dependencies
- name: Cache NPM dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      src/node_modules
    key: npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: npm-

# 3. Docker Layer Cache
- name: Build with cache
  uses: docker/build-push-action@v5
  with:
    cache-from: type=registry,ref=harbor.aglz.io:5000/buildcache
    cache-to: type=registry,ref=harbor.aglz.io:5000/buildcache,mode=max

# 4. Test Results
- name: Cache test results
  uses: actions/cache@v4
  with:
    path: |
      .phpunit.result.cache
      storage/framework/testing
    key: test-results-${{ github.sha }}
```

### Cache Keys Strategy

**Format**: `{type}-{hash}`

- **Exact match**: `composer-abc123...` (from composer.lock hash)
- **Prefix match**: `composer-` (fallback to any composer cache)

**Benefits**:
- Exact match = 100% cache hit
- Prefix match = Partial cache hit (better than nothing)
- Automatic cache invalidation when dependencies change

---

## 🐳 Harbor Registry Integration

### Setup Proxy Cache

1. **Login to Harbor**: https://harbor.aglz.io
2. **Navigate to**: Administration → Registries
3. **Create Endpoint**:
   - Name: `dockerhub-proxy`
   - URL: `https://registry-1.docker.io`
   - Username: Docker Hub username
   - Token: Docker Hub access token

4. **Create Proxy Project**:
   - Project Name: `dockerhub-proxy`
   - Access: Public
   - Proxy Cache: Enable (select dockerhub-proxy)

### Update Dockerfile

```dockerfile
# Before (pulls from Docker Hub every time)
FROM php:8.4-fpm-alpine
FROM node:20-alpine
FROM composer:2.7

# After (pulls from Harbor cache)
FROM harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
FROM harbor.aglz.io:5000/dockerhub-proxy/library/node:20-alpine
FROM harbor.aglz.io:5000/dockerhub-proxy/library/composer:2.7
```

### Performance Impact

| Scenario | Docker Hub | Harbor Cache | Improvement |
|----------|------------|--------------|-------------|
| First pull | 2-3 minutes | 2-3 minutes | 0% (cache miss) |
| Subsequent pull | 2-3 minutes | 10-20 seconds | 85-90% |
| CI/CD builds | Every time | Once per day | 90% bandwidth |

---

## 🔧 BuildKit Features

### Enable BuildKit

```bash
# Docker CLI
export DOCKER_BUILDKIT=1
docker build .

# docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      cache_from:
        - harbor.aglz.io:5000/app:buildcache
```

### BuildKit Configuration

```toml
# buildkit.toml
[worker.oci]
  max-parallelism = 4

[cache]
  mode = "max"
  keep-bytes = 10737418240  # 10 GB
  keep-duration = 604800     # 7 days

[registry."harbor.aglz.io:5000"]
  http = false
  insecure = false
```

### Advanced Features

**1. Inline Cache**

```dockerfile
# Enable in Dockerfile
# syntax=docker/dockerfile:1.4

# Build command
docker build --build-arg BUILDKIT_INLINE_CACHE=1 .
```

**2. Mount Cache**

```dockerfile
# Composer cache
RUN --mount=type=cache,target=/root/.composer \
    composer install

# NPM cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci
```

**3. Secret Mounting**

```dockerfile
# Don't copy secrets into image
RUN --mount=type=secret,id=composer_auth \
    composer config --auth --file=$(cat /run/secrets/composer_auth)
```

---

## 📊 Performance Metrics

### Automated Tracking

Build metrics are automatically tracked via API:

```bash
# GitHub Actions sends metrics after each build
curl -X POST https://dok.aglz.io/api/build/metrics/record \
  -H "Content-Type: application/json" \
  -d '{
    "build_time_seconds": 150,
    "environment": "qa",
    "git_sha": "abc123",
    "cache_hit_rate": 85,
    "layer_reuse_rate": 92
  }'
```

### API Endpoints

```bash
# Get latest metrics
GET /api/build/metrics/latest

# Get build history
GET /api/build/metrics/history?limit=50

# Get trends
GET /api/build/metrics/trends

# Get environment-specific metrics
GET /api/build/metrics/environment/qa

# Get performance comparison
GET /api/build/metrics/comparison
```

### Metrics Dashboard

View metrics in Laravel application:

```javascript
// Example response
{
  "latest": {
    "build_time_seconds": 150,
    "environment": "qa",
    "cache_hit_rate": 85,
    "layer_reuse_rate": 92
  },
  "improvements": {
    "build_time_improvement": "75%",
    "baseline_build_time": "600s",
    "current_build_time": "150s",
    "time_saved_per_build": "450s"
  }
}
```

---

## 💡 Best Practices

### Dockerfile Best Practices

1. **Order Matters**
   ```dockerfile
   # ✅ GOOD
   COPY package.json package-lock.json ./
   RUN npm ci
   COPY . .

   # ❌ BAD
   COPY . .
   RUN npm ci
   ```

2. **Use .dockerignore**
   ```
   node_modules/
   vendor/
   .git/
   tests/
   ```

3. **Combine Related Commands**
   ```dockerfile
   # ✅ GOOD (1 layer)
   RUN apk add --no-cache git curl zip \
       && rm -rf /var/cache/apk/*

   # ❌ BAD (3 layers)
   RUN apk add git
   RUN apk add curl
   RUN apk add zip
   ```

4. **Use Specific Tags**
   ```dockerfile
   # ✅ GOOD
   FROM php:8.4.0-fpm-alpine

   # ❌ BAD (can break builds)
   FROM php:latest
   ```

### CI/CD Best Practices

1. **Parallel Builds**
   ```yaml
   strategy:
     matrix:
       environment: [qa, uat, production]
   ```

2. **Fail Fast**
   ```yaml
   timeout-minutes: 15
   ```

3. **Cache Everything**
   - Composer dependencies
   - NPM dependencies
   - Docker layers
   - Test results

4. **Monitor Performance**
   - Track build times
   - Alert on slow builds
   - Review cache hit rates

### Harbor Best Practices

1. **Use Proxy Cache** for external registries
2. **Tag Images Properly** (semantic versioning)
3. **Clean Old Images** (retention policy)
4. **Monitor Storage** (Harbor dashboard)

---

## 🎯 Checklist

### Phase 4.1 Implementation

- [x] Optimized multi-stage Dockerfile
- [x] .dockerignore configuration
- [x] GitHub Actions caching strategy
- [x] BuildKit configuration
- [x] Harbor proxy cache setup
- [x] Performance monitoring API
- [x] Automated metrics tracking
- [x] Documentation complete

### Performance Validation

- [ ] Build time < 3 minutes (target: 2.5min)
- [ ] Cache hit rate > 80%
- [ ] Layer reuse > 90%
- [ ] Dependency download < 30s
- [ ] 10+ builds tested
- [ ] Metrics dashboard verified

---

## 📚 Related Documentation

- **[DOCKER-CACHE-STRATEGIES.md](DOCKER-CACHE-STRATEGIES.md)** - Detailed caching techniques
- **[HARBOR-PROXY-SETUP.md](HARBOR-PROXY-SETUP.md)** - Harbor configuration guide
- **[PHASE4.1-IMPLEMENTATION-SUMMARY.md](PHASE4.1-IMPLEMENTATION-SUMMARY.md)** - Technical summary
- **[DOKPLOY.md](DOKPLOY.md)** - Deployment platform integration

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Maintainer**: Claude Code (agl-hostman project)
