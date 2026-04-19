---
name: docker-container-orchestration
description: "Multi-container Docker orchestration including networking, volumes, compose configurations, service discovery, and production deployment patterns. Use when running multi-container applications, microservices, or complex Docker setups."
category: devops
priority: P1
tags: [docker, orchestration, compose, networking, microservices]
---

# Docker Container Orchestration

Multi-container Docker orchestration with networking, volumes, health checks, and production deployment patterns for scalable microservices architecture.

## Overview

Docker orchestration manages multiple containers as a cohesive system, handling service discovery, load balancing, scaling, and inter-service communication. This skill covers Docker Compose patterns, custom networking, volume management, health checks, and production-ready deployments with blue-green strategies.

### Key Concepts

- **Service Orchestration**: Coordinating multiple containers into a working application
- **Service Discovery**: Containers finding and communicating with each other
- **Network Isolation**: Segregating services with custom networks
- **Volume Persistence**: Managing state across container lifecycle
- **Health Monitoring**: Ensuring services are running correctly
- **Resource Management**: CPU and memory constraints per service

## Multi-Container Setup

### Docker Compose Architecture

Docker Compose is the primary tool for multi-container orchestration, defining services, networks, and volumes in a declarative YAML format.

```yaml
version: '3.9'

services:
  # Application service
  app:
    build:
      context: ./src
      dockerfile: Dockerfile
      target: production
    image: myapp:${VERSION:-latest}
    container_name: myapp-app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network
    environment:
      - DB_HOST=db
      - REDIS_HOST=redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Database service
  db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: unless-stopped
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Cache service
  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - app-network

  # Web server
  nginx:
    image: nginx:1.25-alpine
    container_name: myapp-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/conf.d:/etc/nginx/conf.d:ro
      - ./docker/nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    networks:
      - app-network

  # Queue worker
  worker:
    image: myapp:${VERSION:-latest}
    container_name: myapp-worker
    restart: unless-stopped
    command: php artisan queue:work --sleep=3 --tries=3
    depends_on:
      - db
      - redis
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  db-data:
    driver: local
  redis-data:
    driver: local
```

### Service Dependencies

Control startup order and dependencies between services:

```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  worker:
    depends_on:
      - app
      - redis
```

### Multiple Compose Files

Use multiple compose files for different environments:

```bash
# Development
docker compose -f docker-compose.yml up

# Production
docker compose -f docker-compose.yml -f docker-compose.production.yml up

# Override file
docker compose -f docker-compose.yml -f docker-compose.override.yml up
```

## Networking

### Network Drivers

Docker supports multiple network drivers for different use cases:

| Driver | Description | Use Case |
|--------|-------------|----------|
| bridge | Single-host network | Default for compose |
| overlay | Multi-host network | Swarm mode |
| host | Host network | High performance |
| none | No network | Isolated containers |
| macvlan | MAC-based network | Direct host access |

### Custom Bridge Networks

```yaml
networks:
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
    driver_opts:
      com.docker.network.bridge.name: frontend_br

  backend:
    driver: bridge
    internal: true  # No external access
    ipam:
      config:
        - subnet: 172.20.1.0/24
```

### Service Discovery and DNS

```yaml
services:
  app:
    networks:
      frontend:
        aliases:
          - app.internal
          - api.internal
      backend:
        aliases:
          - app.backend

  db:
    networks:
      backend:
        aliases:
          - db.internal
          - postgres.internal
```

Containers can reach each other by service name or alias:

```bash
# From app container
curl http://db.internal:5432
redis-cli -h redis.internal
```

### Network Isolation

Separate frontend and backend networks:

```yaml
services:
  nginx:
    networks:
      - frontend

  app:
    networks:
      - frontend
      - backend

  db:
    networks:
      - backend
```

### External Networks

Connect to existing Docker networks:

```yaml
networks:
  external-network:
    external: true
    name: production-network
```

## Volume Management

### Volume Types

1. **Named Volumes**: Managed by Docker, persistent across containers
2. **Bind Mounts**: Host files/directories mounted into containers
3. **Tmpfs Mounts**: Stored in memory, not persisted

### Named Volumes

```yaml
volumes:
  # Database data
  db-data:
    driver: local
    name: myapp-db-data

  # Redis persistence
  redis-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/redis

  # Application storage
  app-storage:
    driver: local
```

### Bind Mounts

```yaml
services:
  app:
    volumes:
      # Development: Live code reload
      - ./src:/app:cached

      # Configuration files (read-only)
      - ./config/app.conf:/etc/app/app.conf:ro

      # Logs directory
      - ./logs:/var/log/app

      # Uploads directory
      - ./uploads:/app/public/uploads
```

### Volume Drivers

```yaml
volumes:
  # Local driver (default)
  data:
    driver: local

  # NFS driver for network storage
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,rw
      device: ":/path/to/nfs/share"

  # Cloud storage drivers (require plugins)
  s3-data:
    driver: vieux/sshfs
    driver_opts:
      sshcmd: "user@host:/path"
      password: "password"
```

### Backup and Restore

```bash
# Backup a volume
docker run --rm \
  -v myapp-db-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/db-backup.tar.gz /data

# Restore a volume
docker run --rm \
  -v myapp-db-data:/data \
  -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/db-backup.tar.gz --strip 1"
```

## Service Discovery

### DNS Resolution

Docker's embedded DNS server provides automatic service discovery:

```yaml
services:
  api:
    # Reachable as: api, api.network_name
    networks:
      - backend

  frontend:
    environment:
      - API_URL=http://api:8080
    networks:
      - backend
```

### Health Check Dependencies

Wait for services to be healthy before starting dependent services:

```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Custom Health Check Endpoint

Create a health endpoint in your application:

```php
// Laravel: routes/api.php
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toIso8601String(),
        'services' => [
            'database' => DB::connection()->getPdo() ? 'up' : 'down',
            'redis' => Redis::ping() ? 'up' : 'down',
            'storage' => is_writable(storage_path()) ? 'up' : 'down',
        ],
    ]);
});
```

## Health Checks

### Container Health Checks

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s      # Time between checks
      timeout: 10s       # Timeout per check
      retries: 3         # Consecutive failures to mark unhealthy
      start_period: 40s  # Grace period on startup
```

### Health Check Commands

```yaml
# HTTP endpoint
test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]

# TCP connection
test: ["CMD", "nc", "-z", "localhost", "8080"]

# Process check
test: ["CMD-SHELL", "pgrep -f 'php-fpm' || exit 1"]

# Database connection
test: ["CMD-SHELL", "pg_isready -U postgres"]

# Redis connection
test: ["CMD", "redis-cli", "ping"]
```

### In-Dockerfile Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

### Monitoring Health Status

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# Inspect health details
docker inspect --format='{{.State.Health.Status}}' container-name

# Watch health changes
docker events --filter 'type=health_status'
```

## Resource Limits

### CPU Constraints

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'      # Maximum 2 CPU cores
        reservations:
          cpus: '0.5'      # Reserve 0.5 CPU cores
```

### Memory Constraints

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 2G       # Maximum 2GB RAM
        reservations:
          memory: 512M     # Reserve 512MB RAM
```

### Combined Resources

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M

  worker:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M

  db:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### Swap Memory

```yaml
services:
  app:
    mem_limit: 1g
    memswap_limit: 2g  # Total memory + swap
```

## Log Management

### Logging Drivers

```yaml
services:
  app:
    logging:
      driver: json-file  # Default
      options:
        max-size: "10m"
        max-file: "3"

  app-json:
    logging:
      driver: json-file
      options:
        labels: "environment,stage"
        tag: "{{.Name}}/{{.ID}}"

  app-syslog:
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://192.168.0.42:514"
        tag: "myapp"

  app-none:
    logging:
      driver: none  # Disable logging
```

### View Logs

```bash
# Follow logs
docker compose logs -f

# Specific service
docker compose logs -f app

# Last 100 lines
docker compose logs --tail=100 app

# Since timestamp
docker compose logs --since=2024-01-01T00:00:00 app

# Multiple services
docker compose logs -f app worker
```

### Log Aggregation

```yaml
# ELK Stack integration
services:
  app:
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://logstash:5000"
        tag: "app"

  logstash:
    image: logstash:8.0
    ports:
      - "5000:5000"
```

## Production Patterns

### Blue-Green Deployment

Zero-downtime deployment with two identical environments:

```yaml
# Blue environment (current)
app-blue:
  image: myapp:${VERSION_BLUE}
  deploy:
    replicas: 3

# Green environment (new)
app-green:
  image: myapp:${VERSION_GREEN}
  deploy:
    replicas: 3
  profiles:
    - green
```

**Deployment process:**

1. Deploy green version alongside blue
2. Test green environment
3. Switch load balancer to green
4. Monitor for issues
5. Keep blue for rollback or decommission

### Reverse Proxy Configuration

```yaml
services:
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app-blue
      - app-green
```

```nginx
# nginx.conf
upstream backend {
    least_conn;
    server app-blue:9000 max_fails=3 fail_timeout=30s;
    server app-green:9000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### SSL/TLS Termination

```yaml
services:
  nginx:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/ssl.conf:/etc/nginx/conf.d/ssl.conf:ro
```

```nginx
# SSL configuration
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://backend;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    return 301 https://$host$request_uri;
}
```

### Horizontal Scaling

```yaml
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3  # Run 3 instances
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 5s
```

### Docker Swarm Mode

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml myapp

# Scale services
docker service scale myapp_app=5

# Update service
docker service update --image myapp:v2 myapp_app

# Rollback
docker service rollback myapp_app
```

## Troubleshooting

### Container Not Starting

```bash
# Check container status
docker ps -a

# View container logs
docker logs container-name

# Inspect container
docker inspect container-name

# Check resource usage
docker stats
```

### Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect network-name

# Test connectivity
docker exec container-name ping other-container
docker exec container-name nc -zv hostname port

# DNS debug
docker exec container-name nslookup service-name
```

### Volume Problems

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect volume-name

# Check volume usage
docker system df -v

# Clean up unused volumes
docker volume prune
```

### Health Check Failures

```bash
# Test health command manually
docker exec container-name curl -f http://localhost/health

# Check health status
docker inspect --format='{{json .State.Health}}' container-name | jq

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' container-name
```

### Resource Exhaustion

```bash
# Check resource usage
docker stats --no-stream

# View resource limits
docker inspect --format='{{.HostConfig.Memory}}' container-name

# Adjust limits in docker-compose.yml
```

### Cleanup Commands

```bash
# Stop all containers
docker compose down

# Remove volumes
docker compose down -v

# Remove images
docker rmi $(docker images -q)

# Full cleanup
docker system prune -a --volumes

# Remove unused resources
docker image prune
docker container prune
docker volume prune
docker network prune
```

## Best Practices

1. **Always use specific version tags** for images, avoid `latest`
2. **Implement health checks** for all services
3. **Set resource limits** to prevent resource exhaustion
4. **Use named volumes** for persistent data
5. **Separate environments** with multiple compose files
6. **Run as non-root user** for security
7. **Use .env files** for configuration, never commit secrets
8. **Implement logging strategy** with size limits
9. **Test rollback procedures** before production
10. **Monitor container metrics** in production

## Related Skills

- `ci-cd-pipelines`: CI/CD integration for container deployments
- `kubernetes-orchestration`: Advanced orchestration at scale
- `security-hardening`: Container security best practices
- `monitoring-observability`: Container metrics and logging
