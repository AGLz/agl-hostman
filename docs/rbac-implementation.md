# RBAC Implementation Guide

**Project:** AGL Infrastructure Admin Platform
**Version:** 1.0.0
**Date:** 2026-02-10

---

## Overview

This document describes the Role-Based Access Control (RBAC) implementation for the AGL Infrastructure, including role definitions, permission mappings, secrets management, and MCP server access control.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Role Definitions](#role-definitions)
3. [Permission System](#permission-system)
4. [Secrets Management](#secrets-management)
5. [MCP Server Access Control](#mcp-server-access-control)
6. [Implementation Guide](#implementation-guide)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Architecture

### Components

```
+-------------------+     +-------------------+     +-------------------+
|   RBAC Config     |---->|   RBAC Middleware |---->|   MCP Server      |
|  (rbac.yaml)      |     |   (McpRbac.php)   |     |   Endpoints       |
+-------------------+     +-------------------+     +-------------------+
                                |                           ^
                                v                           |
                        +-------------------+     +-------------------+
                        | Secrets Service   |<----|   API Keys        |
                        | (SecretsManager)  |     +-------------------+
                        +-------------------+
                                |
                                v
                        +-------------------+
                        |   Audit Log       |
                        | (SecurityAudit)   |
                        +-------------------+
```

### Technology Stack

- **RBAC Package:** Spatie Laravel Permission
- **Configuration:** YAML-based (config/rbac.yaml)
- **Encryption:** Laravel AES-256-GCM
- **Caching:** Redis for secret caching
- **Audit:** SecurityAuditLog model

---

## Role Definitions

### Role Hierarchy

| Role | Level | Description |
|------|-------|-------------|
| **admin** | 100 | Full system access |
| **operator** | 75 | Day-to-day operations |
| **auditor** | 50 | Audit and compliance |
| **viewer** | 25 | Read-only access |

### Role: Administrator (admin)

**Description:** Full administrative access to all system resources.

**Capabilities:**
- Create, edit, delete users
- Assign roles and permissions
- Manage all infrastructure components
- Deploy and rollback applications
- Configure security settings
- Manage API keys and secrets
- Access all MCP server tools

**Use Cases:**
- System initialization
- User account management
- Security configuration
- Emergency operations

### Role: Operator (operator)

**Description:** Operational access for managing deployments and infrastructure.

**Capabilities:**
- View user information (read-only)
- Manage containers and Proxmox servers
- Create and manage deployments
- Create and restore backups
- View audit logs and security events
- Access operational MCP tools

**Use Cases:**
- Daily deployment operations
- Container management
- Backup operations
- Infrastructure monitoring

**Restrictions:**
- Cannot delete infrastructure
- Cannot manage users
- Cannot modify security settings

### Role: Viewer (viewer)

**Description:** Read-only access for monitoring and status checks.

**Capabilities:**
- View dashboards and metrics
- Read infrastructure status
- View deployment history
- Access read-only MCP tools

**Use Cases:**
- Status monitoring
- Reporting
- Read-only analytics

**Restrictions:**
- No write operations
- No configuration changes
- Limited secret access

### Role: Auditor (auditor)

**Description:** Audit and compliance access with enhanced logging capabilities.

**Capabilities:**
- Full read access to audit logs
- View compliance reports
- Export audit data
- Access security event history
- View system logs

**Use Cases:**
- Compliance auditing
- Security investigations
- Report generation
- Log analysis

**Restrictions:**
- No write operations
- Secret access requires approval
- Cannot modify configurations

---

## Permission System

### Permission Format

Permissions follow a `<module>.<action>` naming convention:

```
<module>.<action>

Examples:
- dashboard.view
- users.create
- infrastructure.manage-containers
- deployments.rollback
```

### Permission Modules

| Module | Permissions |
|--------|-------------|
| **dashboard** | view-dashboard, access-admin-panel |
| **users** | view-users, create-users, edit-users, delete-users, manage-user-roles |
| **infrastructure** | view-infrastructure, manage-proxmox, manage-containers |
| **deployments** | view-deployments, create-deployments, rollback-deployments |
| **backups** | view-backups, create-backups, restore-backups |
| **security** | view-audit-logs, manage-api-keys, manage-secrets |
| **monitoring** | view-metrics, configure-alerts |
| **mcp** | access-mcp-server, manage-mcp-tools |

### Checking Permissions in Code

#### In Controllers

```php
// Check single permission
if ($user->hasPermissionTo('create-users')) {
    // Allow action
}

// Check multiple permissions (any)
if ($user->hasAnyPermission(['create-users', 'edit-users'])) {
    // Allow action
}

// Check multiple permissions (all)
if ($user->hasAllPermissions(['create-users', 'assign-roles'])) {
    // Allow action
}
```

#### Using Middleware

```php
// Single role
Route::middleware('role:admin')->group(function () {
    // Admin only routes
});

// Multiple roles (any)
Route::middleware('role:admin,operator|any')->group(function () {
    // Admin or operator
});

// Single permission
Route::middleware('permission:create-users')->group(function () {
    // Requires create-users permission
});

// Multiple permissions (all)
Route::middleware('permission:create-users,assign-roles|all')->group(function () {
    // Requires both permissions
});
```

#### In Blade Templates

```blade
@role('admin')
    <!-- Admin only content -->
@endrole

@permission('manage-users')
    <!-- Users with manage-users permission -->
@endpermission

@anyrole(['admin', 'operator'])
    <!-- Admin or operator -->
@endanyrole
```

---

## Secrets Management

### Overview

The SecretsManagementService provides secure storage and retrieval of sensitive credentials:

- **Encryption at rest:** AES-256-GCM
- **Automatic caching:** 1-hour TTL
- **Secret rotation:** Version tracking
- **Audit logging:** All access logged
- **Role-based access:** Controlled by RBAC

### Secret Access by Role

| Role | Create | Read | Update | Delete | Rotate | Allowed Secrets |
|------|--------|------|--------|--------|--------|-----------------|
| **admin** | Yes | Yes | Yes | Yes | Yes | * (all) |
| **operator** | No | Yes | No | No | No | deployment.*, container.* |
| **viewer** | No | No | No | No | No | (none) |
| **auditor** | No | Yes* | No | No | No | (requires approval) |

*Auditors can read secrets only for audit purposes with explicit approval.

### Using Secrets Management

#### Storing a Secret

```php
use App\Services\SecretsManagementService;

$secrets = app(SecretsManagementService::class);

$secrets->store('database.primary.password', 'secure-password-123', [
    'description' => 'Primary database password',
    'rotation_schedule' => '30d',
    'tags' => ['database', 'production'],
]);
```

#### Retrieving a Secret

```php
// Get with role check
$password = $secrets->get('database.primary.password', 'admin');

// Get without role check (for system use)
$password = $secrets->get('database.primary.password');
```

#### Rotating a Secret

```php
$secrets->rotate('database.primary.password', 'new-password-456', true);
```

#### Validating Secret Complexity

```php
$result = $secrets->validate('MySecureP@ssw0rd', [
    'min_length' => 16,
    'require_uppercase' => true,
    'require_lowercase' => true,
    'require_number' => true,
    'require_special' => true,
]);

if (!$result['valid']) {
    foreach ($result['errors'] as $error) {
        echo $error . "\n";
    }
}
```

#### Generating Secure Secrets

```php
// Generate 32-byte base64 secret
$secret = $secrets->generate(32);

// Generate 64-character hex secret
$secret = $secrets->generate(32, true);
```

### Secret Naming Convention

Follow a hierarchical naming convention:

```
<category>.<subcategory>.<item>

Examples:
- database.primary.password
- database.primary.username
- api.stripe.secret_key
- deployment.frontend.env_vars
```

---

## MCP Server Access Control

### MCP Tool Access by Role

| Role | Access Level | Allowed Tools | Rate Limit |
|------|-------------|---------------|------------|
| **admin** | full | * (all) | 1000/hour |
| **operator** | operational | container.*, deployment.*, backup.*, proxmox.* | 500/hour |
| **viewer** | read-only | *.get, *.list, metrics.* | 100/hour |
| **auditor** | audit | audit.*, log.*, metrics.*, compliance.* | 200/hour |

### MCP RBAC Middleware

The `McpRbac` middleware enforces access control on MCP server endpoints:

1. **Identity Resolution:** User or API key
2. **Role Determination:** Primary role from RBAC
3. **Tool Access Check:** Validates tool access for role
4. **Rate Limiting:** Role-based rate limits
5. **Audit Logging:** All access logged

#### Configuration

```php
// routes/api.php

Route::middleware(['auth', 'mcp.rbac'])->group(function () {
    Route::post('/mcp/tools/call', [McpController::class, 'callTool']);
    Route::get('/mcp/tools/list', [McpController::class, 'listTools']);
});
```

#### API Key Roles

API keys are mapped to roles:

```php
'mcp_role_mapping' => [
    'laravel_boost' => 'operator',
    'shadcn' => 'viewer',
    'ruv_swarm' => 'admin',
]
```

---

## Implementation Guide

### 1. Initial Setup

#### Install Dependencies

```bash
# Spatie Laravel Permission
composer require spatie/laravel-permission

# Publish configuration
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"

# Run migrations
php artisan migrate
```

#### Run RBAC Seeder

```bash
php artisan db:seed --class=RbacSeeder
```

This creates:
- All defined roles (admin, operator, viewer, auditor)
- All permissions
- Default admin user (admin@agl.local / admin123)

### 2. Assign Roles to Users

```php
use App\Models\User;
use Spatie\Permission\Models\Role;

$user = User::find(1);
$adminRole = Role::findByName('admin');
$user->assignRole($adminRole);
```

### 3. Assign Direct Permissions (Optional)

```php
use Spatie\Permission\Models\Permission;

$permission = Permission::findByName('manage-secrets');
$user->givePermissionTo($permission);
```

### 4. Configure Environment

```bash
# .env

# MCP Server Keys (generate with: openssl rand -base64 64)
MCP_LARAVEL_BOOST_KEY=your-secure-key-here
MCP_SHADCN_KEY=your-secure-key-here
MCP_RUV_SWARM_KEY=your-secure-key-here

# Secret Encryption Key
MCP_ENCRYPTION_KEY=your-encryption-key-here

# Rate Limiting
MCP_RATE_LIMITING_ENABLED=true
```

### 5. Testing

```bash
# Test RBAC seeder
php artisan db:seed --class=RbacSeeder

# Test middleware
php artisan test --filter=RbacTest

# Verify roles
php artisan tinker
>>> Role::all()->pluck('name')
=> ["admin", "operator", "viewer", "auditor"]

# Verify permissions
>>> Permission::count()
=> 45
```

---

## Security Best Practices

### 1. Secret Management

- **Never commit secrets to version control**
- Use environment variables for all secrets
- Rotate secrets regularly (critical: 30 days, high: 90 days)
- Use strong, randomly generated secrets
- Enable audit logging for all secret access

### 2. Role Assignment

- Apply principle of least privilege
- Use roles instead of direct permissions when possible
- Regularly audit role assignments
- Remove access immediately when users leave
- Document role assignments

### 3. API Key Security

- Store API keys encrypted in database
- Include expiration dates on API keys
- Implement rate limiting per API key
- Revoke unused API keys
- Log all API key usage

### 4. Audit Logging

- Enable comprehensive audit logging
- Include request context (IP, user-agent, timestamp)
- Log both successful and denied access
- Regularly review audit logs
- Set up alerts for suspicious activity

### 5. Session Management

- Use short session timeouts (2 hours maximum)
- Enable secure, HTTP-only cookies
- Implement session fixation protection
- Invalidate sessions on role changes
- Support session revocation

---

## Troubleshooting

### Issue: Permission Not Working

**Symptoms:** User has role but permission check fails.

**Solutions:**

1. Clear permission cache:
```bash
php artisan cache:forget spatie.permission.cache
php artisan config:clear
```

2. Verify role assignment:
```php
$user->load('roles');
dd($user->roles);
```

3. Check permission sync:
```php
$user->syncPermissions($permissions);
```

### Issue: Secret Not Accessible

**Symptoms:** `SecretsManagementService::get()` returns null.

**Solutions:**

1. Verify secret exists:
```php
$secrets->exists('your.secret.key');
```

2. Check role permissions:
```php
$allowed = $secrets->listForRole('operator');
```

3. Check cache:
```bash
php artisan cache:clear
```

### Issue: MCP Access Denied

**Symptoms:** 403 error when calling MCP tools.

**Solutions:**

1. Verify user role:
```php
dd(auth()->user()->roles->pluck('name'));
```

2. Check tool access pattern:
```php
// Tool names must match patterns in rbac.yaml
// e.g., "container.start" matches "container.*"
```

3. Verify middleware order:
```php
// Ensure McpRbac runs after authentication
Route::middleware(['auth', 'mcp.rbac'])
```

### Issue: Rate Limit Exceeded

**Symptoms:** 429 error from MCP server.

**Solutions:**

1. Check rate limits by role:
```php
// See rbac.yaml mcp_role_mapping
// admin: 1000/hour
// operator: 500/hour
// viewer: 100/hour
```

2. Clear rate limits (for testing):
```php
use Illuminate\Support\Facades\RateLimiter;
RateLimiter::clear('mcp:rbac:' . $role . ':' . $ip);
```

---

## API Reference

### SecretsManagementService

```php
interface SecretsManagementService
{
    public function store(string $key, string $value, array $metadata = []): bool;
    public function get(string $key, ?string $role = null): ?string;
    public function exists(string $key): bool;
    public function delete(string $key): bool;
    public function rotate(string $key, string $newValue, bool $revokeOld = true): bool;
    public function listForRole(string $role): array;
    public function getMetadata(string $key): ?array;
    public function generate(int $length = 32, bool $hex = false): string;
    public function validate(string $secret, array $rules = []): array;
}
```

### User Model (RBAC Methods)

```php
interface UserRbacMethods
{
    public function hasPermissionTo(string $permission): bool;
    public function hasAnyPermission(array $permissions): bool;
    public function hasAllPermissions(array $permissions): bool;
    public function hasRole($role): bool;
    public function hasAnyRole($roles): bool;
    public function hasAllRoles(array $roles): bool;
    public function isSuperAdmin(): bool;
    public function canAccessDashboard(): bool;
    public function canManageUsers(): bool;
    public function canManageRoles(): bool;
}
```

---

## Appendices

### A. Default Credentials

After running the RBAC seeder:

| User | Password | Role | Note |
|------|----------|------|------|
| admin@agl.local | admin123 | admin | **Change immediately** |

### B. Configuration Files

| File | Purpose |
|------|---------|
| config/rbac.yaml | Role and permission definitions |
| config/security/mcp-security.php | MCP server security settings |
| .env.example.security | Security environment variables template |

### C. Database Tables

| Table | Purpose |
|-------|---------|
| roles | Role definitions |
| permissions | Permission definitions |
| model_has_roles | User-role assignments |
| model_has_permissions | User-permission assignments |
| role_has_permissions | Role-permission mappings |
| security_audit_logs | Security event logging |

---

**Document Version:** 1.0.0
**Last Updated:** 2026-02-10
**Next Review:** 2026-05-10
