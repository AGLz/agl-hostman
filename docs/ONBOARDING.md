# AGL-HOSTMAN Platform Onboarding Guide

> **Welcome to the Team!** This guide will help you get up to speed with the AGL-HOSTMAN infrastructure management platform.

## Table of Contents

1. [Platform Overview](#platform-overview)
2. [Development Environment Setup](#development-environment-setup)
3. [Architecture & Components](#architecture--components)
4. [Common Workflows](#common-workflows)
5. [Code Review Guidelines](#code-review-guidelines)
6. [Security Best Practices](#security-best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Resources & Support](#resources--support)

---

## Platform Overview

### What is AGL-HOSTMAN?

AGL-HOSTMAN is a comprehensive infrastructure management platform built on Laravel 12 and React 18, designed to:

- **Manage Infrastructure**: Proxmox VE hosts, containers, and VMs
- **Deploy Applications**: Multi-environment CI/CD via Dokploy
- **Monitor Systems**: Real-time metrics, alerts, and health checks
- **Track Performance**: DORA metrics and deployment analytics
- **Auto-Scale**: Intelligent resource scaling based on metrics

### Technology Stack

**Backend:**
- Laravel 12 (PHP 8.4)
- PostgreSQL 17
- Redis 7
- Laravel Reverb (WebSockets)

**Frontend:**
- React 18
- Inertia.js
- Tailwind CSS 3
- Chart.js

**Infrastructure:**
- Proxmox VE 8
- Dokploy (Deployment Platform)
- Harbor Registry
- WireGuard Mesh Network

**CI/CD:**
- GitHub Actions
- Automated testing (219 tests, 87%+ coverage)
- Multi-environment deployment
- Automated rollbacks

### Key Features

✅ **Smart Test Detection** - Run only affected tests (70% faster PRs)
✅ **Auto-Scaling** - Dynamic resource allocation
✅ **DORA Metrics** - Elite-tier DevOps performance tracking
✅ **Smart Notifications** - Context-aware alerts (Slack, PagerDuty)
✅ **Real-time Monitoring** - Live dashboards and metrics
✅ **Health Checks** - Automated production validation

---

## Development Environment Setup

### Prerequisites

- **PHP 8.4+** with extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql, redis, pcov
- **Node.js 20+** and npm
- **PostgreSQL 17+**
- **Redis 7+**
- **Git** with SSH keys configured
- **Docker** (optional, for local services)

### Step 1: Clone Repository

\`\`\`bash
git clone git@github.com:your-org/agl-hostman.git
cd agl-hostman/src
\`\`\`

### Step 2: Install Dependencies

\`\`\`bash
# PHP dependencies
composer install

# Node dependencies
npm install
\`\`\`

### Step 3: Environment Configuration

\`\`\`bash
# Copy environment file
cp .env.example .env

# Generate application key
php artisan key:generate

# Configure database
# Edit .env:
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=agl_hostman
DB_USERNAME=your_user
DB_PASSWORD=your_password
\`\`\`

### Step 4: Database Setup

\`\`\`bash
# Create database
createdb agl_hostman

# Run migrations
php artisan migrate

# Seed test data (optional)
php artisan db:seed
\`\`\`

### Step 5: Build Frontend Assets

\`\`\`bash
# Development build
npm run dev

# Or production build
npm run build
\`\`\`

### Step 6: Start Development Server

\`\`\`bash
# Laravel server
php artisan serve

# Vite dev server (in separate terminal)
npm run dev

# Queue worker (in separate terminal)
php artisan queue:work

# WebSocket server (in separate terminal)
php artisan reverb:start
\`\`\`

### Step 7: Verify Installation

\`\`\`bash
# Run tests
vendor/bin/phpunit

# Check code style
vendor/bin/pint --test

# Run health checks
php artisan health:check
\`\`\`

---

## Architecture & Components

### Directory Structure

\`\`\`
src/
├── app/
│   ├── Console/Commands/       # Artisan commands
│   ├── Http/Controllers/       # API and Web controllers
│   ├── Models/                 # Eloquent models
│   ├── Services/              # Business logic
│   │   ├── Deployment/
│   │   ├── Monitoring/
│   │   ├── Metrics/
│   │   ├── Scaling/
│   │   └── Health/
│   └── Repositories/          # Data access layer
├── config/                    # Configuration files
├── database/
│   ├── migrations/            # Database migrations
│   └── seeders/               # Database seeders
├── resources/
│   ├── js/                    # React components
│   │   ├── Components/
│   │   ├── Layouts/
│   │   └── Pages/
│   └── views/                 # Blade templates
├── routes/
│   ├── api.php                # API routes
│   └── web.php                # Web routes
├── tests/
│   ├── Unit/                  # Unit tests
│   └── Feature/               # Feature tests
└── scripts/                   # Utility scripts
\`\`\`

### Core Services

**DeploymentService** - Manages application deployments
- Multi-environment support (dev, qa, uat, prod)
- Automated rollbacks
- Health checks
- Deployment history

**MetricsCollector** - Collects and aggregates metrics
- CPU, memory, network metrics
- Request rate and response time
- Queue length and error rates
- Custom metrics support

**AutoScalingService** - Intelligent resource scaling
- CPU/memory/traffic-based triggers
- Gradual scaling with cooldowns
- Consensus-based decisions
- Health check validation

**DORAMetricsService** - DevOps performance tracking
- Deployment frequency
- Lead time for changes
- Mean time to recovery (MTTR)
- Change failure rate

**NotificationService** - Smart alerting
- Multi-channel support (Slack, PagerDuty, email)
- Noise reduction and grouping
- Severity-based routing
- Alert correlation

---

## Common Workflows

### Making Code Changes

1. **Create Feature Branch**
   \`\`\`bash
   git checkout -b feature/your-feature-name
   \`\`\`

2. **Make Changes**
   - Follow coding standards (see Code Review Guidelines)
   - Write tests for new functionality
   - Update documentation as needed

3. **Run Tests Locally**
   \`\`\`bash
   vendor/bin/phpunit
   \`\`\`

4. **Commit Changes**
   \`\`\`bash
   git add .
   git commit -m "feat: add your feature description"
   \`\`\`

5. **Push and Create PR**
   \`\`\`bash
   git push origin feature/your-feature-name
   # Create PR on GitHub
   \`\`\`

6. **Address Review Comments**
   - Make requested changes
   - Push updates to same branch
   - Re-request review when ready

### Running Tests

**All Tests:**
\`\`\`bash
vendor/bin/phpunit
\`\`\`

**Specific Test Suite:**
\`\`\`bash
vendor/bin/phpunit --testsuite=Unit
vendor/bin/phpunit --testsuite=Feature
\`\`\`

**Single Test File:**
\`\`\`bash
vendor/bin/phpunit tests/Unit/Services/Deployment/DeploymentServiceTest.php
\`\`\`

**With Coverage:**
\`\`\`bash
vendor/bin/phpunit --coverage-html coverage
\`\`\`

**Affected Tests Only (PRs):**
\`\`\`bash
./scripts/detect-affected-tests.sh
\`\`\`

### Database Migrations

**Create Migration:**
\`\`\`bash
php artisan make:migration create_table_name_table
\`\`\`

**Run Migrations:**
\`\`\`bash
php artisan migrate
\`\`\`

**Rollback:**
\`\`\`bash
php artisan migrate:rollback
\`\`\`

**Fresh Migration (dev only):**
\`\`\`bash
php artisan migrate:fresh --seed
\`\`\`

### Working with Frontend

**Start Dev Server:**
\`\`\`bash
npm run dev
\`\`\`

**Build for Production:**
\`\`\`bash
npm run build
\`\`\`

**Run Linter:**
\`\`\`bash
npm run lint
\`\`\`

**Format Code:**
\`\`\`bash
npm run format
\`\`\`

---

## Code Review Guidelines

### What Reviewers Look For

✅ **Functionality**
- Code works as intended
- Edge cases handled
- Error handling implemented

✅ **Tests**
- New code has tests
- Tests are meaningful
- Coverage maintained/improved

✅ **Code Quality**
- Follows Laravel conventions
- PSR-12 compliant
- DRY principles applied
- Single responsibility

✅ **Performance**
- No N+1 queries
- Efficient algorithms
- Appropriate caching
- Database indexes

✅ **Security**
- Input validation
- SQL injection prevention
- XSS protection
- CSRF tokens

✅ **Documentation**
- Docblocks for public methods
- README updates if needed
- Complex logic explained

### Review Process

1. **Author Creates PR**
   - Clear title and description
   - Links to related issues
   - Screenshots for UI changes

2. **Automated Checks**
   - Tests must pass
   - Code style must pass
   - Coverage must not decrease

3. **Peer Review**
   - At least 1 approval required
   - Address all comments
   - No unresolved discussions

4. **Merge**
   - Squash and merge (preferred)
   - Delete branch after merge

---

## Security Best Practices

### Authentication & Authorization

- Always use Laravel's authentication
- Implement proper authorization checks
- Use policies for complex permissions
- Never bypass authentication in production

### Input Validation

\`\`\`php
// Always validate user input
$validated = $request->validate([
    'email' => 'required|email',
    'name' => 'required|string|max:255',
]);
\`\`\`

### Database Security

\`\`\`php
// ✅ Good - Parameterized query
User::where('email', $email)->first();

// ❌ Bad - SQL injection risk
DB::select("SELECT * FROM users WHERE email = '$email'");
\`\`\`

### API Security

- Use API tokens
- Rate limit endpoints
- Validate all inputs
- Use HTTPS only

### Secrets Management

- Never commit secrets to Git
- Use `.env` for sensitive data
- Rotate credentials regularly
- Use different credentials per environment

---

## Troubleshooting

### Common Issues

**Issue: Tests failing locally**
\`\`\`bash
# Clear and rebuild
php artisan config:clear
php artisan cache:clear
composer dump-autoload
vendor/bin/phpunit
\`\`\`

**Issue: Database connection errors**
\`\`\`bash
# Check PostgreSQL is running
systemctl status postgresql

# Verify credentials in .env
php artisan tinker
>>> DB::connection()->getPdo();
\`\`\`

**Issue: NPM build errors**
\`\`\`bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
\`\`\`

**Issue: Queue jobs not processing**
\`\`\`bash
# Restart queue worker
php artisan queue:restart
php artisan queue:work --queue=default,high,low
\`\`\`

---

## Resources & Support

### Documentation

- **API Documentation**: `/docs/API-DOCUMENTATION.md`
- **Deployment Guide**: `/docs/DEPLOYMENT-GUIDE.md`
- **Monitoring Guide**: `/docs/MONITORING-GUIDE.md`
- **Infrastructure Docs**: `/docs/INFRA.md`

### Getting Help

- **Slack**: #agl-hostman channel
- **GitHub Issues**: Report bugs and feature requests
- **Weekly Standup**: Mondays 10am
- **Code Review**: Ask in #code-review

### Useful Commands

\`\`\`bash
# List all Artisan commands
php artisan list

# Interactive shell
php artisan tinker

# Check application status
php artisan health:check

# Calculate DORA metrics
php artisan dora:calculate

# View logs
tail -f storage/logs/laravel.log
\`\`\`

---

**Welcome aboard! Happy coding! 🚀**
