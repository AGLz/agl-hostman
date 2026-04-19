# TASK-006: Multi-Database Configuration

> **Status**: ⚠️ IN PROGRESS - Docker permission issues identified
> **Assignee**: Claude
> **Priority**: HIGH
> **Created**: 2025-12-29
> **Updated**: 2025-12-29

---

## 📋 Objective

Configure multi-database setup for AGL HostMan:
- **Primary Database**: MySQL 8.0 (user data, business logic)
- **Cache/Queue**: Redis 7 (caching, sessions, queue)
- **Development**: SQLite (local development fallback)

---

## 🔍 Current Status

### ✅ Working
- **Redis**: Configured and testable (connection works)
- **Configuration Files**: All Laravel configs in place
- **Test Suite**: Database connection tests created

### ❌ Blocked
- **MySQL Container**: Permission error (exit code 126)
  ```
  Error: permission denied (sysctl net.ipv4.ip_unprivileged_port_start)
  Container: agl-admin-mysql
  Status: Exited for 4 weeks
  ```

- **Redis Container**: Same permission issue
  ```
  Container: agl-admin-redis
  Status: Exited for 4 weeks
  ```

### 📊 Test Results

```php
// src/tests/DatabaseTest.php

✅ Redis: CONNECTED
❌ MySQL: FAILED - getaddrinfo for mysql failed
```

---

## 🔧 Configuration Files

### `.env` (Current Configuration)
```bash
# MySQL
DB_CONNECTION=mysql
DB_HOST=mysql              # Docker container name
DB_PORT=3306
DB_DATABASE=agl_admin
DB_USERNAME=agl_admin
DB_PASSWORD=AglAdmin2025!

# Redis
REDIS_CLIENT=predis
REDIS_HOST=127.0.0.1      # Works (localhost)
REDIS_PASSWORD=null
REDIS_PORT=6379

# Queue
QUEUE_CONNECTION=redis     # Configured and ready
```

### Docker Containers (Status)
| Container | Image | Status | Issue |
|-----------|-------|--------|-------|
| agl-admin-mysql | mysql:8.0 | Exited (126) | Permission denied |
| agl-admin-redis | redis:alpine | Exited (126) | Permission denied |

---

## 🚧 Issue Root Cause

**Problem**: Docker permission error when starting containers
```
OCI runtime create failed: runc create failed: unable to start container process:
error during container init: open sysctl net.ipv4.ip_unprivileged_port_start file:
reopen fd 8: permission denied
```

**Likely Causes**:
1. Running as root without proper Docker socket permissions
2. AppArmor/SELinux restrictions
3. Docker daemon security policies
4. Container runtime compatibility issue

**Environment**: LXC container (CT179 - agldv03)

---

## ✅ Solutions Proposed

### Option 1: Use External Database Services ⭐ RECOMMENDED

**For Development (CT179)**:
```bash
# Use SQLite for simplicity
DB_CONNECTION=sqlite
DB_DATABASE=/path/to/database.sqlite

# Use local Redis (if available)
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
```

**For Production (AGLSRV1)**:
```bash
# Deploy MySQL in Proxmox VM
# Connect via WireGuard: 10.6.0.X
DB_HOST=10.6.0.X
DB_PORT=3306
```

### Option 2: Fix Docker Permissions

```bash
# Try fixing Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or run Docker without sudo
sudo usermod -aG docker $USER
```

**Note**: May not work in LXC container environment

### Option 3: Use Dokploy Database Services

Dokploy (CT180) supports managed databases:
- **MySQL**: Create via Dokploy UI
- **PostgreSQL**: Native support
- **Redis**: Create via Dokploy

**Access**: https://dok.aglz.io

---

## 📝 Implementation Steps

### Phase 1: Development Setup (SQLite + Redis)

1. **Update `.env` for local development**
```bash
# .env
DB_CONNECTION=sqlite
DB_DATABASE=database/database.sqlite

# Keep Redis as-is (working)
REDIS_HOST=127.0.0.1
QUEUE_CONNECTION=redis
```

2. **Create SQLite database**
```bash
touch src/database/database.sqlite
php src/artisan migrate
```

3. **Test connections**
```bash
php src/vendor/bin/phpunit src/tests/DatabaseTest.php
```

### Phase 2: Production Setup (External MySQL)

1. **Deploy MySQL server on AGLSRV1**
   - Create Proxmox VM or LXC container
   - Install MySQL 8.0
   - Configure WireGuard access

2. **Configure remote MySQL**
```bash
# .env.production
DB_CONNECTION=mysql
DB_HOST=10.6.0.XX        # WireGuard IP
DB_PORT=3306
DB_DATABASE=agl_hostman_prod
DB_USERNAME=agl_hostman
DB_PASSWORD=secure_password
```

3. **Setup SSL/TLS for remote connections**
```bash
# Require SSL for production
MYSQL_ATTR_SSL_CA=/path/to/ca.pem
```

### Phase 3: Redis Configuration

**Option A**: Use existing Redis (if available)
```bash
# Check for Redis on network
redis-cli -h 10.6.0.XX ping
```

**Option B**: Deploy Redis via Dokploy
```bash
# Create Redis service via Dokploy UI
# Configure environment variables
REDIS_HOST=redis.dok.aglz.io
REDIS_PASSWORD=secure_redis_password
```

---

## 🧪 Testing Checklist

- [ ] SQLite migration: `php artisan migrate`
- [ ] SQLite seeding: `php artisan db:seed`
- [ ] Redis connection: `Cache::store('redis')->put('test', 'ok')`
- [ ] Queue worker: `php artisan queue:work`
- [ ] Test suite: `php artisan test`

---

## 📊 Success Criteria

- ✅ All database migrations run successfully
- ✅ Redis caching functional
- ✅ Queue jobs process correctly
- ✅ Test suite passes (219+ tests)
- ✅ Zero permission errors

---

## 🔗 Related Documentation

- **DEPLOYMENT-GUIDE.md**: Full deployment procedures
- **INFRA.md**: Infrastructure overview
- **DOKPLOY.md**: Dokploy database setup
- **TOPOLOGY.md**: Network architecture

---

## 🎯 Next Steps

1. **Immediate**: Switch to SQLite for development
2. **Short-term**: Test queue system with Redis
3. **Medium-term**: Deploy MySQL to production environment
4. **Long-term**: Setup database replication/HA

---

## 📝 Notes

- **Why SQLite?**: Simplest solution for LXC development environment
- **Why not Docker?**: Permission issues in LXC containers are complex to fix
- **Production Ready**: External MySQL/Redis is better for scalability
- **Migration Path**: Laravel supports multiple databases seamlessly

**Last Updated**: 2025-12-29 21:45 UTC
**Status**: ⚠️ Awaiting decision on Option 1 (SQLite)
