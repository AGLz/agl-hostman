# Multi-stage production Dockerfile for Laravel
# Stage 1: Composer dependencies
FROM composer:2.7.1 AS composer

# Stage 2: Base PHP image
FROM php:8.3-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    zip \
    unzip \
    icu-dev \
    oniguruma-dev \
    bash \
    mysql-client \
    supervisor

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    && docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl \
    opcache

# Install Redis extension
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Install Node.js for asset building
RUN apk add --no-cache nodejs npm

# Stage 3: Development environment
FROM base AS development

WORKDIR /app

# Install Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install \
    --prefer-dist \
    --no-interaction \
    --no-autoloader

# Copy application
COPY . .

# Generate autoload
RUN composer dump-autoload -o

# Create necessary directories
RUN mkdir -p storage/framework/{sessions,views,cache} \
    storage/logs \
    bootstrap/cache

# Set permissions
RUN chown -R www-data:www-data /app

USER www-data

EXPOSE 9000

CMD ["php-fpm"]

# Stage 4: Production image
FROM base AS production

WORKDIR /app

# Copy Composer from build stage
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Copy composer files and install production dependencies
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction

# Copy application files
COPY . .

# Build frontend assets
RUN npm ci && npm run build && rm -rf node_modules

# Generate optimized autoload and cache configs
RUN composer dump-autoload --optimize --classmap-authoritative \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && php artisan event:cache \
    && php artisan migrate --force

# Set proper permissions
RUN chown -R www-data:www-data /app \
    && chmod -R 775 storage bootstrap/cache || true

USER www-data

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD php-fpm-healthcheck || exit 1

CMD ["php-fpm"]
