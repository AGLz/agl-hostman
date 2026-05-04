# GitHub Actions CI/CD Guide for Laravel

## Overview

This guide covers setting up production-ready CI/CD pipelines for Laravel applications using GitHub Actions, including automated testing, code quality checks, security scanning, and deployment workflows.

## Core Concepts

### Workflow Structure

GitHub Actions workflows are defined in YAML files in `.github/workflows/`:

```yaml
name: Workflow Name
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      - name: Step name
        uses: actions/checkout@v4
```

### Continuous Integration (CI)

#### Basic CI Workflow (.github/workflows/ci.yml)

```yaml
name: Continuous Integration

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    name: Tests on PHP ${{ matrix.php-versions }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        php-versions: ['8.2', '8.3']
        dependency-version: [prefer-lowest, prefer-stable]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php-versions }}
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite, bcmath, soap, intl, gd, exif, iconv, imagick
          coverage: xdebug
          tools: composer:v2

      - name: Get composer cache directory
        id: composer-cache
        run: echo "dir=$(composer config cache-files-dir)" >> $GITHUB_OUTPUT

      - name: Cache composer dependencies
        uses: actions/cache@v4
        with:
          path: ${{ steps.composer-cache.outputs.dir }}
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: ${{ runner.os }}-composer-

      - name: Install dependencies
        run: |
          composer update --${{ matrix.dependency-version }} --prefer-dist --no-interaction --no-progress
          composer require --dev mockery/mockery --with-all-dependencies

      - name: Prepare Laravel Application
        run: |
          cp .env.example .env
          php artisan key:generate
          mkdir -p storage/framework/{sessions,views,cache}
          mkdir -p storage/logs
          touch storage/database.sqlite

      - name: Run Tests
        run: vendor/bin/pest --coverage --min=80
        env:
          DB_CONNECTION: sqlite

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.xml
          flags: unittests
          name: codecov-umbrella
          fail_ci_if_error: false

  code-quality:
    name: Code Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite, bcmath, soap, intl, gd, exif, iconv
          tools: composer:v2, phpstan, php-cs-fixer

      - name: Cache composer dependencies
        uses: actions/cache@v4
        with:
          path: vendor/
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: ${{ runner.os }}-composer-

      - name: Install dependencies
        run: composer install --prefer-dist --no-interaction --no-progress

      - name: Run PHP CS Fixer (dry-run)
        run: ./vendor/bin/php-cs-fixer fix --dry-run --diff

      - name: Run Pint
        run: ./vendor/bin/pint --test

      - name: Run PHPStan
        run: ./vendor/bin/phpstan analyse --memory-limit=2G

      - name: Run Larastan
        run: ./vendor/bin/phpstan analyse --memory-limit=2G

  security:
    name: Security Vulnerability Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist --no-interaction --no-progress

      - name: Run Composer audit
        run: composer audit --no-dev

      - name: Run Enlightn Security Checker
        run: |
          composer require --dev enlightn/security-checker
          ./vendor/bin/security-checker security:check

      - name: Run Snyk Security Scan
        uses: snyk/actions/php@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

### Continuous Deployment (CD)

#### Staging Deployment (.github/workflows/deploy-staging.yml)

```yaml
name: Deploy to Staging

on:
  push:
    branches: [develop]

jobs:
  deploy:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, mysql, bcmath, soap, intl, gd, exif
          tools: composer:v2

      - name: Install dependencies
        run: composer install --no-dev --prefer-dist --no-interaction --no-progress

      - name: Optimize Laravel
        run: |
          php artisan config:cache
          php artisan route:cache
          php artisan view:cache
        env:
          APP_ENV: staging
          APP_KEY: ${{ secrets.STAGING_APP_KEY }}

      - name: Deploy to Dokploy
        run: |
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_STAGING }}" \
            -H "Content-Type: application/json" \
            -d '{"ref":"${{ github.ref }}","sha":"${{ github.sha }}"}'

      - name: Run Migrations
        run: |
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_STAGING }}/migrate" \
            -H "Authorization: Bearer ${{ secrets.DOKPLOY_API_TOKEN }}"

      - name: Notify Slack
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Staging deployment completed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        if: always()
```

#### Production Deployment (.github/workflows/deploy-production.yml)

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, mysql, bcmath, soap, intl, gd, exif
          coverage: xdebug
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist --no-interaction --no-progress

      - name: Run tests
        run: ./vendor/bin/pest --min=90

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Harbor Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.HARBOR_REGISTRY }}
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Extract tag name
        id: tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.HARBOR_REGISTRY }}/laravel-app:latest
            ${{ secrets.HARBOR_REGISTRY }}/laravel-app:${{ steps.tag.outputs.tag }}
          cache-from: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache
          cache-to: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache,mode=max
          target: production

  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production
      url: https://app.example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to Dokploy
        run: |
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_PROD }}" \
            -H "Content-Type: application/json" \
            -d '{"ref":"${{ github.ref }}","sha":"${{ github.sha }}"}'

      - name: Run Migrations
        run: |
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_PROD }}/migrate" \
            -H "Authorization: Bearer ${{ secrets.DOKPLOY_API_TOKEN }}"

      - name: Health Check
        run: |
          sleep 30
          response=$(curl -s -o /dev/null -w "%{http_code}" https://app.example.com/api/health)
          if [ $response -ne 200 ]; then
            echo "Health check failed"
            exit 1
          fi

      - name: Rollback on failure
        if: failure()
        run: |
          curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_PROD }}/rollback" \
            -H "Authorization: Bearer ${{ secrets.DOKPLOY_API_TOKEN }}"

      - name: Notify deployment
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Production deployment completed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        if: always()
```

### Docker Build Workflow (.github/workflows/docker-build.yml)

```yaml
name: Docker Build and Push

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build Docker Image
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Harbor
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.HARBOR_REGISTRY }}
          username: ${{ secrets.HARBOR_USERNAME }}
          password: ${{ secrets.HARBOR_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.HARBOR_REGISTRY }}/laravel-app
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache
          cache-to: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache,mode=max
          target: production

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.HARBOR_REGISTRY }}/laravel-app:latest
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

### Security Scanning Workflow (.github/workflows/security-scan.yml)

```yaml
name: Security Scanning

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  composer-audit:
    name: Composer Audit
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist --no-interaction

      - name: Run Composer audit
        run: composer audit --no-dev

      - name: Run Snyk
        uses: snyk/actions/php@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  docker-scan:
    name: Docker Image Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build image
        run: docker build -t laravel-app:latest .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'laravel-app:latest'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'

  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: php, javascript

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

## GitHub Secrets Configuration

### Required Secrets

```bash
# Application
APP_KEY                    # Laravel APP_KEY

# Harbor Registry
HARBOR_REGISTRY            # Harbor registry URL (e.g., harbor.example.com)
HARBOR_USERNAME            # Harbor username
HARBOR_PASSWORD            # Harbor password or token

# Dokploy
DOKPLOY_WEBHOOK_STAGING    # Staging deployment webhook
DOKPLOY_WEBHOOK_PROD       # Production deployment webhook
DOKPLOY_API_TOKEN          # Dokploy API token

# Security
SNYK_TOKEN                 # Snyk API token

# Notifications
SLACK_WEBHOOK              # Slack webhook URL
```

### Environment Secrets

You can also use environment-specific secrets in GitHub Actions:

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://app.example.com
    env:
      APP_ENV: ${{ vars.APP_ENV }}
```

## Best Practices

### 1. Caching Dependencies

```yaml
- name: Cache composer dependencies
  uses: actions/cache@v4
  with:
    path: vendor/
    key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
    restore-keys: ${{ runner.os }}-composer-
```

### 2. Parallel Jobs

```yaml
jobs:
  test:
    strategy:
      matrix:
        php: ['8.2', '8.3']
        laravel: ['10.*', '11.*']
```

### 3. Conditional Steps

```yaml
- name: Deploy
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: ./deploy.sh
```

### 4. Deployment Protection

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://app.example.com
    # Requires manual approval
```

### 5. Rollback Strategy

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.DOKPLOY_WEBHOOK_PROD }}/rollback" \
      -H "Authorization: Bearer ${{ secrets.DOKPLOY_API_TOKEN }}"
```

## Common Workflow Patterns

### Manual Trigger

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production
```

### Matrix Testing

```yaml
strategy:
  matrix:
    php-version: ['8.2', '8.3']
    database: ['mysql', 'pgsql']
    laravel: ['10.*', '11.*']
```

### Docker Layer Caching

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    cache-from: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache
    cache-to: type=registry,ref=${{ secrets.HARBOR_REGISTRY }}/laravel-app:buildcache,mode=max
```

## Troubleshooting

### Debug Workflow

```yaml
- name: Debug
  run: |
    echo "GitHub ref: ${{ github.ref }}"
    echo "GitHub sha: ${{ github.sha }}"
    env
```

### Retry Failed Steps

```yaml
- name: Deploy with retry
  uses: nick-fields/retry@v3
  with:
    timeout_minutes: 10
    max_attempts: 3
    command: ./deploy.sh
```

### Artifact Upload

```yaml
- name: Upload logs
  uses: actions/upload-artifact@v4
  with:
    name: logs
    path: storage/logs/
    retention-days: 30
```
