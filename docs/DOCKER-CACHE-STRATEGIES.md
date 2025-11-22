# Docker Cache Strategies - Technical Deep Dive

> **Last Updated**: 2025-11-21 | **Version**: 1.0.0
> **Phase**: 4.1 - Build Pipeline Optimization

---

## 📋 Table of Contents

1. [Understanding Docker Layer Caching](#-understanding-docker-layer-caching)
2. [BuildKit Cache Types](#-buildkit-cache-types)
3. [Advanced Caching Techniques](#-advanced-caching-techniques)
4. [Registry Cache](#-registry-cache)
5. [Performance Optimization](#-performance-optimization)
6. [Troubleshooting](#-troubleshooting)

---

## 🎯 Understanding Docker Layer Caching

### How Docker Caching Works

Docker builds images in layers. Each instruction in a Dockerfile creates a new layer:

```dockerfile
FROM php:8.4-fpm-alpine      # Layer 1
RUN apk add git curl         # Layer 2
COPY composer.json ./        # Layer 3
RUN composer install         # Layer 4
COPY . .                     # Layer 5
```

**Key Principles**:

1. **Cache Invalidation**: If a layer changes, all subsequent layers are invalidated
2. **Layer Reuse**: Unchanged layers are reused from cache
3. **Order Matters**: Most stable instructions should come first

### Cache Hit vs Cache Miss

**Cache Hit** (Fast):
```
Step 2/5 : RUN apk add git curl
 ---> Using cache
 ---> abc123def456
```

**Cache Miss** (Slow):
```
Step 2/5 : RUN apk add git curl
 ---> Running in xyz789abc123
```

### Optimal Layer Ordering

```dockerfile
# ✅ OPTIMAL ORDER (from most stable to most volatile)

# 1. Base image (rarely changes)
FROM php:8.4-fpm-alpine

# 2. System dependencies (changes infrequently)
RUN apk add --no-cache git curl zip

# 3. PHP extensions (changes infrequently)
RUN docker-php-ext-install pdo_mysql opcache

# 4. Dependency manifests (changes occasionally)
COPY composer.json composer.lock ./

# 5. Install dependencies (benefits from above cache)
RUN composer install

# 6. Application code (changes frequently)
COPY . .

# ❌ BAD ORDER (invalidates cache constantly)

FROM php:8.4-fpm-alpine
COPY . .                    # Changes frequently - invalidates everything below
RUN apk add git curl
RUN composer install        # Always runs, even if composer.json unchanged
```

---

## 🚀 BuildKit Cache Types

### 1. Inline Cache

Stores cache metadata directly in the image.

**Enable**:
```dockerfile
# syntax=docker/dockerfile:1.4
```

**Build**:
```bash
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --tag harbor.aglz.io:5000/app:latest \
  .
```

**Use**:
```bash
docker build \
  --cache-from harbor.aglz.io:5000/app:latest \
  .
```

**Pros**:
- Cache metadata travels with image
- No separate cache management
- Works across build machines

**Cons**:
- Slightly larger image size
- Limited to single stage

### 2. Registry Cache

Stores cache as separate layers in registry.

**Export to Registry**:
```bash
docker build \
  --cache-to type=registry,ref=harbor.aglz.io:5000/app:buildcache,mode=max \
  .
```

**Import from Registry**:
```bash
docker build \
  --cache-from type=registry,ref=harbor.aglz.io:5000/app:buildcache \
  .
```

**Pros**:
- Supports multi-stage builds
- Better cache granularity
- Smaller production images

**Cons**:
- Requires separate cache storage
- More complex setup

### 3. Local Cache

Stores cache on local filesystem.

**Export**:
```bash
docker build \
  --cache-to type=local,dest=/tmp/docker-cache \
  .
```

**Import**:
```bash
docker build \
  --cache-from type=local,src=/tmp/docker-cache \
  .
```

**Pros**:
- Fastest for single machine
- No network overhead

**Cons**:
- Doesn't work in CI/CD
- Lost on machine rebuild

### 4. Mount Cache (BuildKit)

Persistent cache mounts that survive across builds.

```dockerfile
# Composer cache
RUN --mount=type=cache,target=/root/.composer,id=composer-cache \
    composer install

# NPM cache
RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    npm ci

# Apt cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && apt-get install -y git
```

**Pros**:
- Dependencies download once
- Survives docker system prune
- Shared across related builds

**Cons**:
- Requires BuildKit
- Cache fills up over time

---

## 🔧 Advanced Caching Techniques

### 1. Split Dependencies from Code

**Pattern**: Copy dependency manifests before application code

```dockerfile
# ✅ GOOD - Dependencies cached separately
COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader

COPY . .
RUN composer dump-autoload

# ❌ BAD - Code changes invalidate dependency cache
COPY . .
RUN composer install
```

**Impact**: 90% faster builds when only code changes

### 2. Use Multi-Stage Builds

**Pattern**: Build in separate stages, copy only needed artifacts

```dockerfile
# Stage 1: Install all dependencies
FROM node:20-alpine AS builder
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production runtime (smaller, faster)
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

**Benefits**:
- Final image 90% smaller
- Build stages cached independently
- Security (no build tools in production)

### 3. Leverage Cache Mounts

**Pattern**: Mount cache directories during build

```dockerfile
# Without cache mount (downloads every time)
RUN composer install                    # 2 minutes

# With cache mount (cached after first run)
RUN --mount=type=cache,target=/root/.composer \
    composer install                    # 30 seconds
```

**Supported Tools**:
- Composer: `/root/.composer/cache`
- NPM: `/root/.npm`
- Pip: `/root/.cache/pip`
- Go: `/go/pkg/mod`
- Maven: `/root/.m2`

### 4. Wildcard Copies for Stability

**Pattern**: Use wildcards to copy only necessary files

```dockerfile
# ✅ GOOD - Only copy manifests
COPY package*.json ./
COPY composer.* ./

# ❌ BAD - Copies everything
COPY . .
```

### 5. .dockerignore for Build Context

**Purpose**: Reduce build context sent to Docker daemon

```
# .dockerignore
node_modules/
vendor/
.git/
tests/
*.md
.env
```

**Impact**:
- 10x faster context upload
- Prevents cache invalidation
- Smaller builds

---

## 📦 Registry Cache

### Harbor as Proxy Cache

**Setup Flow**:

1. **Configure Harbor**:
   ```
   Harbor → Administration → Registries
   Add Endpoint: Docker Hub (registry-1.docker.io)
   Create Project: dockerhub-proxy (with proxy cache)
   ```

2. **Update Dockerfile**:
   ```dockerfile
   # Before
   FROM php:8.4-fpm-alpine

   # After
   FROM harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
   ```

3. **First Pull** (populates cache):
   ```
   docker pull harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
   # Downloads from Docker Hub → Caches in Harbor
   ```

4. **Subsequent Pulls** (from cache):
   ```
   docker pull harbor.aglz.io:5000/dockerhub-proxy/library/php:8.4-fpm-alpine
   # Served from Harbor (10x faster)
   ```

### Performance Comparison

| Operation | Docker Hub | Harbor Cache | Improvement |
|-----------|------------|--------------|-------------|
| php:8.4-fpm-alpine | 180s | 18s | 90% |
| node:20-alpine | 120s | 12s | 90% |
| composer:2.7 | 60s | 6s | 90% |
| **Total** | **360s** | **36s** | **90%** |

### Registry Cache in GitHub Actions

```yaml
- name: Build with registry cache
  uses: docker/build-push-action@v5
  with:
    context: ./src
    cache-from: |
      type=registry,ref=harbor.aglz.io:5000/app:buildcache
      type=registry,ref=harbor.aglz.io:5000/app:latest
    cache-to: type=registry,ref=harbor.aglz.io:5000/app:buildcache,mode=max
```

**Mode Options**:
- `mode=min`: Export only final stage
- `mode=max`: Export all stages (recommended)

---

## ⚡ Performance Optimization

### Cache Hit Rate Calculation

```bash
# Monitor cache hits
docker build --progress=plain . 2>&1 | grep -c "Using cache"
docker build --progress=plain . 2>&1 | grep -c "RUN"

# Calculate hit rate
Hit Rate = (Using cache count / Total RUN count) × 100
```

**Target**: 80%+ cache hit rate

### Optimize for Cache Reuse

**1. Group Related Changes**:
```dockerfile
# ✅ GOOD
RUN apk add --no-cache git curl zip unzip

# ❌ BAD (separate layers)
RUN apk add git
RUN apk add curl
RUN apk add zip
```

**2. Use Explicit Versions**:
```dockerfile
# ✅ GOOD
FROM php:8.4.0-fpm-alpine
COPY --from=composer:2.7.0 /usr/bin/composer

# ❌ BAD (breaks cache unpredictably)
FROM php:8-fpm-alpine
COPY --from=composer:latest /usr/bin/composer
```

**3. Separate Build and Runtime**:
```dockerfile
# Build stage (cached separately)
FROM node:20-alpine AS build
RUN npm install
RUN npm run build

# Runtime stage (smaller, faster)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

### Monitor Build Performance

```bash
# Time build
time docker build -t app .

# Check layer sizes
docker history app

# Analyze cache usage
docker builder prune --dry-run
```

---

## 🔍 Troubleshooting

### Cache Not Working

**Symptom**: Builds always run all steps

**Check 1: BuildKit enabled**
```bash
docker buildx version
# Should show version, not error
```

**Check 2: Cache source exists**
```bash
docker pull harbor.aglz.io:5000/app:buildcache
# Should succeed
```

**Check 3: Syntax directive**
```dockerfile
# Must be first line
# syntax=docker/dockerfile:1.4
```

### Slow Dependency Downloads

**Symptom**: npm/composer downloads take minutes

**Solution**: Use cache mounts
```dockerfile
# Before
RUN composer install          # 2 minutes every time

# After
RUN --mount=type=cache,target=/root/.composer \
    composer install          # 30 seconds
```

### Large Image Size

**Symptom**: Final image > 500MB

**Solution 1: Multi-stage build**
```dockerfile
FROM node:20 AS build         # 1GB
RUN npm run build

FROM nginx:alpine             # 25MB
COPY --from=build /app/dist .
```

**Solution 2: Minimize layers**
```dockerfile
# ✅ GOOD (1 layer)
RUN apk add git && \
    git clone repo && \
    apk del git

# ❌ BAD (3 layers)
RUN apk add git
RUN git clone repo
RUN apk del git
```

### Cache Miss on Unchanged Files

**Symptom**: COPY instruction invalidates cache despite no changes

**Cause**: .dockerignore not configured

**Solution**:
```
# .dockerignore
.git/
node_modules/
*.log
```

---

## 📊 Best Practices Summary

### DO ✅

- Use BuildKit (syntax=docker/dockerfile:1.4)
- Copy dependency files before source code
- Use cache mounts for package managers
- Leverage multi-stage builds
- Use registry cache in CI/CD
- Monitor cache hit rates
- Use specific image tags (not latest)

### DON'T ❌

- Copy entire project before installing deps
- Use `latest` tags
- Skip .dockerignore
- Mix build and runtime dependencies
- Ignore cache hit rate metrics
- Use `--no-cache` in CI/CD

---

## 📚 Related Documentation

- **[BUILD-OPTIMIZATION-GUIDE.md](BUILD-OPTIMIZATION-GUIDE.md)** - Complete optimization guide
- **[HARBOR-PROXY-SETUP.md](HARBOR-PROXY-SETUP.md)** - Harbor proxy cache configuration
- **[BuildKit Documentation](https://docs.docker.com/build/buildkit/)** - Official BuildKit docs

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-21
**Maintainer**: Claude Code (agl-hostman project)
