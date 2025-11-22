# syntax=docker/dockerfile:1.4

#############################################
# Stage 1: Base PHP Image with Extensions
#############################################
FROM php:8.4-fpm-alpine AS php-base

# Install system dependencies (cached layer)
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    postgresql-dev \
    icu-dev \
    nodejs \
    npm \
    libzip-dev \
    supervisor \
    nginx

# Install PHP extensions (cached layer)
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

# Install Redis extension
RUN apk add --no-cache pcre-dev $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del pcre-dev $PHPIZE_DEPS

# Install Composer (use official installer)
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Configure OPcache for production
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=16" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=0" >> /usr/local/etc/php/conf.d/opcache.ini

#############################################
# Stage 2: Node.js Build (Frontend Assets)
#############################################
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files first (cached if unchanged)
COPY package.json package-lock.json ./

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit

# Copy source files
COPY . .

# Build frontend assets
RUN --mount=type=cache,target=/app/.vite \
    npm run build

#############################################
# Stage 3: Composer Dependencies
#############################################
FROM php-base AS composer-builder

WORKDIR /app

# Copy composer files first (cached if unchanged)
COPY composer.json composer.lock ./

# Install PHP dependencies with cache
RUN --mount=type=cache,target=/root/.composer \
    composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# Copy application files
COPY . .

# Generate optimized autoloader
RUN composer dump-autoload --optimize --classmap-authoritative

#############################################
# Stage 4: Production Image
#############################################
FROM php-base AS production

# Create user for Laravel
ARG user=laravel
ARG uid=1000

RUN adduser -D -u $uid -h /home/$user $user \
    && addgroup $user www-data

WORKDIR /var/www/html

# Copy PHP dependencies from composer-builder
COPY --from=composer-builder --chown=$user:www-data /app/vendor ./vendor

# Copy built assets from node-builder
COPY --from=node-builder --chown=$user:www-data /app/public/build ./public/build

# Copy application code
COPY --chown=$user:www-data . .

# Copy PHP configuration
COPY docker/php/local.ini /usr/local/etc/php/conf.d/local.ini

# Set permissions
RUN mkdir -p storage bootstrap/cache \
    && chown -R $user:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Create necessary directories
RUN mkdir -p /var/log/supervisor \
    && chown -R $user:www-data /var/log/supervisor

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan octane:status || exit 1

# Use www-data user
USER $user

CMD ["php-fpm"]

#############################################
# Stage 5: Development Image (Optional)
#############################################
FROM production AS development

USER root

# Install development dependencies
RUN apk add --no-cache \
    vim \
    bash \
    git

# Install Xdebug
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del $PHPIZE_DEPS

# Configure Xdebug
RUN echo "xdebug.mode=debug,coverage" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini

USER $user

#############################################
# Stage 6: Test Image
#############################################
FROM composer-builder AS test

# Install dev dependencies
RUN --mount=type=cache,target=/root/.composer \
    composer install \
    --prefer-dist \
    --optimize-autoloader

# Copy test files
COPY --chown=$user:www-data tests ./tests
COPY --chown=$user:www-data phpunit.xml ./
COPY --chown=$user:www-data Pest.php ./

# Run tests
RUN php artisan test
