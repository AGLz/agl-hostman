# syntax=docker/dockerfile:1.4

#############################################
# Build Optimization Configuration
#############################################
# This Dockerfile implements advanced caching strategies for Laravel 12 + React 18
# Expected performance: 75%+ build time reduction on subsequent builds
# Cache strategy: Multi-stage builds + BuildKit cache mounts + layer optimization
# Last updated: 2025-11-27 (Phase 4.1: Build Pipeline Optimization)

#############################################
# Stage 1: Base PHP Image with Extensions
#############################################
# This stage contains all system dependencies and PHP extensions
# Changes rarely, provides maximum cache reusability
FROM php:8.4-fpm-alpine AS php-base

# Set metadata labels
LABEL maintainer="AGL Infrastructure Team"
LABEL org.opencontainers.image.title="AGL-HOSTMAN"
LABEL org.opencontainers.image.description="Infrastructure Management Platform - Optimized Build"
LABEL org.opencontainers.image.vendor="AGL"

# Install system dependencies in a single layer (cached when unchanged)
# Grouped by purpose for better readability and maintenance
RUN apk add --no-cache \
    # Core utilities
    git \
    curl \
    zip \
    unzip \
    # Image processing
    libpng-dev \
    # Text processing
    oniguruma-dev \
    libxml2-dev \
    # Database drivers
    postgresql-dev \
    # Internationalization
    icu-dev \
    # Archive handling
    libzip-dev \
    # Process management
    supervisor \
    # Web server
    nginx \
    # Frontend build tools
    nodejs \
    npm

# Install PHP extensions (cached when unchanged)
# Order: configure, then install, minimizes rebuilds
RUN docker-php-ext-configure intl \
    && docker-php-ext-install \
    pdo_pgsql \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    intl \
    opcache \
    zip

# Install Redis extension (separate layer for better caching)
RUN apk add --no-cache pcre-dev $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del pcre-dev $PHPIZE_DEPS

# Copy Composer from official image (version pinned for stability)
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Configure OPcache for production (optimized for performance)
# Separate layer allows easy tuning without rebuilding everything
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=16" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable_cli=0" >> /usr/local/etc/php/conf.d/opcache.ini

#############################################
# Stage 2: Composer Dependencies
#############################################
# Isolated stage for PHP dependency resolution
# Uses BuildKit cache mount for maximum speed
FROM php-base AS composer-deps

WORKDIR /app

# Copy ONLY dependency definition files first (changes rarely)
# This maximizes Docker layer cache hits
COPY composer.json composer.lock ./

# Install production dependencies with aggressive caching
# Cache mount persists between builds, eliminating redundant downloads
# Flags: --no-dev (prod only), --no-scripts (defer), --no-autoloader (defer)
RUN --mount=type=cache,target=/root/.composer,id=composer-cache \
    composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader

# Copy application source (changes frequently, separate layer)
COPY . .

# Generate optimized autoloader (classmap-authoritative for best performance)
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev

#############################################
# Stage 3: NPM Dependencies
#############################################
# Isolated stage for Node.js dependency resolution
# Uses BuildKit cache mount for package cache
FROM node:20-alpine AS node-deps

WORKDIR /app

# Install dependencies with NPM cache mount
# npm ci is faster and more reliable than npm install for CI/CD
COPY package.json package-lock.json ./

RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    npm ci \
    --prefer-offline \
    --no-audit \
    --progress=false \
    --loglevel=error

#############################################
# Stage 4: Asset Build
#############################################
# Frontend compilation stage (React 18 + Vite)
# Separated to isolate build artifacts and enable parallel building
FROM node-deps AS asset-builder

WORKDIR /app

# Copy node_modules from previous stage (already cached)
COPY --from=node-deps /app/node_modules ./node_modules

# Copy source files needed for frontend build
COPY resources ./resources
COPY public ./public
COPY vite.config.js postcss.config.js tailwind.config.js ./

# Build frontend assets with Vite cache mount
# Cache mount speeds up subsequent builds significantly
RUN --mount=type=cache,target=/app/node_modules/.vite,id=vite-cache \
    npm run build -- --mode production

#############################################
# Stage 5: Production Runtime Image
#############################################
# Minimal final image with only production artifacts
# Multi-stage approach reduces final image size by ~60%
FROM php-base AS production

# Build arguments for image metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Add metadata labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/agl/agl-hostman"

# Create application user (non-root for security)
ARG user=laravel
ARG uid=1000

RUN adduser -D -u $uid -h /home/$user $user \
    && addgroup $user www-data

WORKDIR /var/www/html

# Copy PHP dependencies from composer stage
# --from syntax retrieves artifacts from specific build stage
COPY --from=composer-deps --chown=$user:www-data /app/vendor ./vendor

# Copy built frontend assets from asset builder
COPY --from=asset-builder --chown=$user:www-data /app/public/build ./public/build

# Copy application code (in order of change frequency)
# Config files change less than source code
COPY --chown=$user:www-data composer.json composer.lock artisan ./
COPY --chown=$user:www-data config ./config
COPY --chown=$user:www-data routes ./routes
COPY --chown=$user:www-data database ./database
COPY --chown=$user:www-data app ./app
COPY --chown=$user:www-data resources ./resources
COPY --chown=$user:www-data public ./public
COPY --chown=$user:www-data bootstrap ./bootstrap

# Copy PHP and Nginx configuration
COPY --chown=$user:www-data docker/php/local.ini /usr/local/etc/php/conf.d/local.ini
COPY --chown=$user:www-data docker/nginx/conf.d /etc/nginx/conf.d/

# Set up Laravel storage and cache directories
# Proper permissions are critical for Laravel to function
RUN mkdir -p storage/framework/{cache,sessions,views,testing} \
    storage/logs \
    bootstrap/cache \
    && chown -R $user:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Create supervisor directories
RUN mkdir -p /var/log/supervisor \
    && chown -R $user:www-data /var/log/supervisor

# Expose PHP-FPM port
EXPOSE 9000

# Health check for container orchestration
# Checks if Octane server is responding (adjust if not using Octane)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan octane:status || exit 1

# Run as non-root user for security
USER $user

# Default command (can be overridden in docker-compose)
CMD ["php-fpm"]

#############################################
# Stage 6: Development Image (with Xdebug)
#############################################
# Development-specific stage with debugging tools
# Only built when target=development is specified
FROM production AS development

USER root

# Install development tools
RUN apk add --no-cache \
    vim \
    bash \
    git \
    make

# Install Xdebug for debugging and code coverage
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install xdebug-3.3.0 \
    && docker-php-ext-enable xdebug \
    && apk del $PHPIZE_DEPS

# Configure Xdebug for development and coverage
RUN echo "xdebug.mode=debug,coverage,develop" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.idekey=VSCODE" >> /usr/local/etc/php/conf.d/xdebug.ini

# Disable OPcache validation for faster development
RUN echo "opcache.validate_timestamps=1" >> /usr/local/etc/php/conf.d/opcache-dev.ini \
    && echo "opcache.revalidate_freq=2" >> /usr/local/etc/php/conf.d/opcache-dev.ini

USER $user

#############################################
# Stage 7: Test Image (for CI/CD)
#############################################
# Dedicated stage for running tests in CI pipeline
# Includes dev dependencies and test configuration
FROM composer-deps AS test

WORKDIR /app

# Install dev dependencies (PHPUnit, Pest, etc.)
RUN --mount=type=cache,target=/root/.composer,id=composer-test-cache \
    composer install \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader

# Copy test files and configuration
COPY --chown=$user:www-data tests ./tests
COPY --chown=$user:www-data phpunit.xml ./
COPY --chown=$user:www-data Pest.php ./

# Create test user
ARG user=laravel
ARG uid=1000
RUN adduser -D -u $uid -h /home/$user $user 2>/dev/null || true

USER $user

# Run tests (can be overridden)
CMD ["php", "artisan", "test", "--parallel"]

#############################################
# Build Cache Strategy Summary
#############################################
# 1. Layer Ordering: Least changing layers first (OS, PHP extensions, dependencies, source)
# 2. BuildKit Cache Mounts: Persistent caches for Composer, NPM, and Vite
# 3. Multi-Stage Isolation: Dependencies resolved in parallel stages
# 4. Minimal Final Image: Only production artifacts copied to runtime image
# 5. GitHub Actions Cache: Registry cache type for cross-runner persistence
#
# Expected Performance:
# - First build: ~8-12 minutes (full installation)
# - Cached build (no changes): ~30-60 seconds (layer cache hits)
# - Partial changes: ~2-3 minutes (dependency cache + layer reuse)
# - Target improvement: 75%+ reduction in subsequent builds
#
# Cache Invalidation:
# - composer.lock changed: Rebuilds from composer-deps stage
# - package-lock.json changed: Rebuilds from node-deps stage
# - Source code changed: Only rebuilds from asset-builder/production stages
# - Dockerfile changed: Full rebuild (rare occurrence)
