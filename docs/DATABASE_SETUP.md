# Multi-Database Setup Guide

## Overview

AGL Hostman supports multiple database configurations for different use cases:

- **SQLite** - Testing and local development (default)
- **MySQL 8.0** - Production primary database
- **PostgreSQL** - Alternative production database
- **Redis 7** - Caching, queues, and sessions

## Quick Start

### 1. Using SQLite (Default)

No additional setup required. SQLite is configured by default for local development.

```bash
# Create the database file
touch src/database/database.sqlite

# Run migrations
cd src
php artisan migrate
```

### 2. Using MySQL 8.0

Start MySQL with Docker Compose:

```bash
# Start MySQL alongside base services
docker compose -f docker-compose.yml -f docker-compose.mysql.yml up -d mysql

# Access phpMyAdmin at http://localhost:8083
```

Environment configuration in `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3307
DB_DATABASE=agl_hostman
DB_USERNAME=agl_user
DB_PASSWORD=secret
```

### 3. Using PostgreSQL

PostgreSQL is included in the base docker-compose.yml:

```bash
# Start PostgreSQL
docker compose up -d db

# Access Adminer at http://localhost:8081
```

Environment configuration in `.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=agl_hostman
DB_USERNAME=agl_user
DB_PASSWORD=secret
```

### 4. Using Redis 7

Redis is included in the base docker-compose.yml:

```bash
# Start Redis
docker compose up -d redis

# Access Redis Commander at http://localhost:8082
```

For enhanced Redis configuration:

```bash
docker compose -f docker-compose.yml -f docker-compose.redis.yml up -d redis-enhanced

# Access Redis Insight at http://localhost:8001
```

## Docker Compose Overlays

The project uses Docker Compose overlay pattern for flexible configurations:

- **docker-compose.yml** - Base services (PostgreSQL, Redis, Nginx)
- **docker-compose.mysql.yml** - MySQL 8.0 overlay
- **docker-compose.redis.yml** - Enhanced Redis 7 overlay

### Starting All Services

```bash
# Full stack with MySQL
docker compose -f docker-compose.yml -f docker-compose.mysql.yml up -d

# Full stack with enhanced Redis
docker compose -f docker-compose.yml -f docker-compose.redis.yml up -d

# Everything
docker compose -f docker-compose.yml -f docker-compose.mysql.yml -f docker-compose.redis.yml up -d
```

## Database Connections

### Multiple Connections

You can use multiple databases simultaneously:

```php
// Use default connection
DB::table('users')->get();

// Use MySQL connection
DB::connection('mysql')->table('logs')->get();

// Use PostgreSQL connection
DB::connection('pgsql')->table('analytics')->get();

// Use SQLite for testing
DB::connection('sqlite')->table('test_data')->get();
```

### Connection Configuration

Database connections are configured in `src/config/database.php`:

```php
'connections' => [
    'sqlite' => [...],
    'mysql' => [...],
    'pgsql' => [...],
]
```

## Redis Usage

### Cache

```env
CACHE_STORE=redis
REDIS_CACHE_CONNECTION=cache
```

### Sessions

```env
SESSION_DRIVER=redis
REDIS_SESSION_DB=2
```

### Queues

```env
QUEUE_CONNECTION=redis
REDIS_QUEUE_DB=3
```

## Performance Tuning

### MySQL 8.0

Configuration in `docker/mysql/my.cnf`:

- `max_connections = 1000`
- `innodb_buffer_pool_size = 1G`
- `innodb_log_file_size = 256M`

### Redis 7

Configuration in `docker/redis/redis.conf`:

- `maxmemory = 2gb`
- `maxmemory-policy = allkeys-lru`
- Append-only file enabled

## Management Tools

| Tool | URL | Purpose |
|------|-----|---------|
| phpMyAdmin | http://localhost:8083 | MySQL management |
| Adminer | http://localhost:8081 | PostgreSQL management |
| Redis Commander | http://localhost:8082 | Redis basic management |
| Redis Insight | http://localhost:8001 | Redis advanced analytics |

## Troubleshooting

### Connection Issues

1. Verify containers are running:
   ```bash
   docker compose ps
   ```

2. Check container logs:
   ```bash
   docker compose logs mysql
   docker compose logs redis
   ```

3. Test database connection:
   ```bash
   # MySQL
   docker exec -it agl-hostman-mysql mysql -u agl_user -psecret

   # PostgreSQL
   docker exec -it agl-hostman-db psql -U agl_user -d agl_hostman

   # Redis
   docker exec -it agl-hostman-redis redis-cli
   ```

### Port Conflicts

Default ports can be changed in `.env`:

```env
MYSQL_PORT=3307
REDIS_PORT=6379
PHPMYADMIN_PORT=8083
ADMINER_PORT=8081
REDIS_COMMANDER_PORT=8082
REDIS_INSIGHT_PORT=8001
```

### Performance Issues

1. Check Redis memory usage:
   ```bash
   docker exec agl-hostman-redis redis-cli INFO memory
   ```

2. Monitor MySQL connections:
   ```bash
   docker exec agl-hostman-mysql mysql -u root -psecret -e "SHOW PROCESSLIST;"
   ```

3. View Laravel cache stats:
   ```bash
   php artisan cache:stats
   ```

## Backup and Restore

### MySQL Backup

```bash
# Backup
docker exec agl-hostman-mysql mysqldump -u agl_user -psecret agl_hostman > backup.sql

# Restore
docker exec -i agl-hostman-mysql mysql -u agl_user -psecret agl_hostman < backup.sql
```

### PostgreSQL Backup

```bash
# Backup
docker exec agl-hostman-db pg_dump -U agl_user agl_hostman > backup.sql

# Restore
docker exec -i agl-hostman-db psql -U agl_user agl_hostman < backup.sql
```

### Redis Backup

```bash
# Trigger RDB snapshot
docker exec agl-hostman-redis redis-cli BGSAVE

# Copy RDB file
docker cp agl-hostman-redis:/data/dump.rdb ./redis-backup.rdb
```
